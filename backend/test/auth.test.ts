import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import test from 'node:test';

import type { QueryResultRow } from 'pg';

import { buildApp } from '../src/app.js';
import type { Database, DatabaseQueryResult } from '../src/auth/auth.types.js';

const userId = '00000000-0000-0000-0000-000000000001';
const sessionId = '00000000-0000-0000-0000-000000000002';

type FakeLoginRow = QueryResultRow & {
  id: string;
  usuario: string;
  nombre: string;
  empresa_id: string | null;
  rol_id: string;
  rol_codigo: string;
  activo: boolean;
};

type FakeSessionRow = QueryResultRow & {
  session_id: string;
  user_id: string;
  username: string;
  role_id: string;
  company_id: string | null;
  role_code: string;
  expires_at: string;
};

class FakeDatabase implements Database {
  loginRows: FakeLoginRow[] = [];
  sessionRows: FakeSessionRow[] = [];
  passwordIsValid = true;
  insertedSessions: unknown[][] = [];
  revokedSessionIds: string[] = [];
  passwordUpdates: unknown[][] = [];
  lastUsedSessionIds: string[] = [];

  async query<Row extends QueryResultRow = QueryResultRow>(
    text: string,
    values: unknown[] = []
  ): Promise<DatabaseQueryResult<Row>> {
    if (text.includes('public.login_usuario')) return this.result<Row>(this.loginRows);
    if (text.includes('INSERT INTO public.sesiones')) {
      this.insertedSessions.push(values);
      return this.result<Row>([{ id: sessionId }]);
    }
    if (text.includes('FROM public.sesiones s')) return this.result<Row>(this.sessionRows);
    if (text.includes('SET last_used_at = now()')) {
      this.lastUsedSessionIds.push(String(values[0]));
      return this.result<Row>([]);
    }
    if (text.includes('SET revoked_at = now()')) {
      this.revokedSessionIds.push(String(values[0]));
      return this.result<Row>([]);
    }
    if (text.includes('fleet_control_verify_usuario_password')) {
      return this.result<Row>([{ valid: this.passwordIsValid }]);
    }
    if (text.includes('fleet_control_set_usuario_password')) {
      this.passwordUpdates.push(values);
      return this.result<Row>([]);
    }
    if (text.includes('SELECT 1')) return this.result<Row>([{ '?column?': 1 }]);

    throw new Error(`Unexpected query in test: ${text}`);
  }

  private result<Row extends QueryResultRow>(rows: QueryResultRow[]): DatabaseQueryResult<Row> {
    return { rows: rows as Row[], rowCount: rows.length };
  }
}

function activeUser(): FakeLoginRow {
  return {
    id: userId,
    usuario: 'operador',
    nombre: 'Operador Local',
    empresa_id: null,
    rol_id: '00000000-0000-0000-0000-000000000003',
    rol_codigo: 'admin',
    activo: true
  };
}

function activeSession(): FakeSessionRow {
  return {
    session_id: sessionId,
    user_id: userId,
    username: 'operador',
    role_id: '00000000-0000-0000-0000-000000000003',
    company_id: null,
    role_code: 'admin',
    expires_at: '2030-01-01T00:00:00.000Z'
  };
}

async function appWith(database: FakeDatabase) {
  return buildApp({ database });
}

test('login correcto devuelve token raw y guarda únicamente su SHA-256', async () => {
  const database = new FakeDatabase();
  database.loginRows = [activeUser()];
  const app = await appWith(database);

  try {
    const response = await app.inject({
      method: 'POST',
      url: '/api/auth/login',
      payload: { usuario: 'operador', password: 'secreto-seguro' }
    });
    const body = response.json() as { sessionToken: string; user: { id: string; roleId: string; rolCodigo: string } };

    assert.equal(response.statusCode, 200);
    assert.equal(body.user.id, userId);
    assert.equal(body.user.roleId, '00000000-0000-0000-0000-000000000003');
    assert.equal(body.user.rolCodigo, 'admin');
    assert.ok(body.sessionToken.length >= 43);
    assert.equal(database.insertedSessions.length, 1);
    assert.equal(
      database.insertedSessions[0]?.[1],
      createHash('sha256').update(body.sessionToken, 'utf8').digest('hex')
    );
    assert.notEqual(database.insertedSessions[0]?.[1], body.sessionToken);
  } finally {
    await app.close();
  }
});

test('login rechaza credenciales inválidas, usuario inexistente y usuario inactivo', async () => {
  const invalidProfiles: FakeLoginRow[][] = [
    [],
    [{ ...activeUser(), activo: false }]
  ];

  for (const loginRows of invalidProfiles) {
    const database = new FakeDatabase();
    database.loginRows = loginRows;
    const app = await appWith(database);

    try {
      const response = await app.inject({
        method: 'POST',
        url: '/api/auth/login',
        payload: { usuario: 'operador', password: 'incorrecta' }
      });
      assert.equal(response.statusCode, 401);
      assert.deepEqual(response.json(), {
        error: 'invalid_credentials',
        message: 'Usuario o contraseña incorrectos.'
      });
      assert.equal(database.insertedSessions.length, 0);
    } finally {
      await app.close();
    }
  }
});

test('middleware acepta token válido y logout revoca la sesión', async () => {
  const database = new FakeDatabase();
  database.sessionRows = [activeSession()];
  const app = await appWith(database);

  try {
    const response = await app.inject({
      method: 'POST',
      url: '/api/auth/logout',
      headers: { authorization: 'Bearer token_valido' }
    });

    assert.equal(response.statusCode, 200);
    assert.deepEqual(response.json(), { success: true });
    assert.deepEqual(database.revokedSessionIds, [sessionId]);
    assert.deepEqual(database.lastUsedSessionIds, [sessionId]);
  } finally {
    await app.close();
  }
});

test('middleware rechaza sesión ausente, inexistente, revocada o expirada', async () => {
  const database = new FakeDatabase();
  const app = await appWith(database);

  try {
    for (const authorization of [undefined, 'Token token', 'Bearer inexistente', 'Bearer revocado', 'Bearer expirado']) {
      const response = await app.inject({
        method: 'POST',
        url: '/api/auth/logout',
        headers: authorization ? { authorization } : undefined
      });
      assert.equal(response.statusCode, 401);
      assert.deepEqual(response.json(), {
        error: 'invalid_session',
        message: 'Sesión inválida o expirada.'
      });
    }
  } finally {
    await app.close();
  }
});

test('logout repetido es seguro porque una sesión revocada deja de autenticar', async () => {
  const database = new FakeDatabase();
  database.sessionRows = [activeSession()];
  const app = await appWith(database);

  try {
    const first = await app.inject({
      method: 'POST',
      url: '/api/auth/logout',
      headers: { authorization: 'Bearer token_valido' }
    });
    database.sessionRows = [];
    const repeated = await app.inject({
      method: 'POST',
      url: '/api/auth/logout',
      headers: { authorization: 'Bearer token_valido' }
    });

    assert.equal(first.statusCode, 200);
    assert.equal(repeated.statusCode, 401);
  } finally {
    await app.close();
  }
});

test('cambio de contraseña rechaza contraseña actual incorrecta', async () => {
  const database = new FakeDatabase();
  database.sessionRows = [activeSession()];
  database.passwordIsValid = false;
  const app = await appWith(database);

  try {
    const response = await app.inject({
      method: 'POST',
      url: '/api/profile/password',
      headers: { authorization: 'Bearer token_valido' },
      payload: { currentPassword: 'incorrecta', newPassword: 'nueva-clave-segura' }
    });

    assert.equal(response.statusCode, 403);
    assert.equal(database.passwordUpdates.length, 0);
  } finally {
    await app.close();
  }
});

test('cambio de contraseña reutiliza PostgreSQL y exige nuevo login', async () => {
  const database = new FakeDatabase();
  database.sessionRows = [activeSession()];
  const app = await appWith(database);

  try {
    const response = await app.inject({
      method: 'POST',
      url: '/api/profile/password',
      headers: { authorization: 'Bearer token_valido' },
      payload: { currentPassword: 'clave-actual', newPassword: 'nueva-clave-segura' }
    });

    assert.equal(response.statusCode, 200);
    assert.deepEqual(response.json(), { success: true, reauthenticationRequired: true });
    assert.deepEqual(database.passwordUpdates, [[userId, 'nueva-clave-segura']]);
  } finally {
    await app.close();
  }
});
