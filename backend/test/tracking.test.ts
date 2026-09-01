import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import test from 'node:test';

import type { QueryResultRow } from 'pg';

import { buildApp } from '../src/app.js';
import type { Database, DatabaseQueryResult } from '../src/auth/auth.types.js';

const userId = '00000000-0000-0000-0000-000000000021';
const roleId = '00000000-0000-0000-0000-000000000022';

type SessionRow = QueryResultRow & {
  session_id: string;
  user_id: string;
  username: string;
  role_id: string;
  role_code: string;
  company_id: string | null;
  expires_at: string;
};

class FakeDatabase implements Database {
  sessionRows: SessionRow[] = [activeSession('chofer')];
  rpcParameters: unknown[][] = [];
  presenceParameters: unknown[][] = [];
  fleetLocationsQuery: string | null = null;

  async query<Row extends QueryResultRow = QueryResultRow>(
    text: string,
    values: unknown[] = []
  ): Promise<DatabaseQueryResult<Row>> {
    if (text.includes('FROM public.sesiones s')) return this.result<Row>(this.sessionRows);
    if (text.includes('SET last_used_at = now()')) return this.result<Row>([]);
    if (text.includes('fleet_control_update_driver_location')) {
      this.rpcParameters.push(values);
      return this.result<Row>([
        {
          chofer_usuario_id: userId,
          empresa_id: '00000000-0000-0000-0000-000000000023',
          gestion_id: null,
          vehiculo_id: null,
          latitud: -25.28,
          longitud: -57.63,
          precision_metros: 4,
          velocidad_mps: null,
          rumbo_grados: 90,
          captured_at: new Date('2030-01-01T00:00:00.000Z')
        }
      ]);
    }
    if (text.includes('fleet_control_touch_driver_presence')) {
      this.presenceParameters.push(values);
      return this.result<Row>([]);
    }
    if (text.includes('FROM public.usuarios u') && text.includes('cl.latitud AS latitude')) {
      this.fleetLocationsQuery = text;
      return this.result<Row>([]);
    }

    throw new Error(`Unexpected query in test: ${text}`);
  }

  private result<Row extends QueryResultRow>(rows: QueryResultRow[]): DatabaseQueryResult<Row> {
    return { rows: rows as Row[], rowCount: rows.length };
  }
}

function activeSession(roleCode: string): SessionRow {
  return {
    session_id: '00000000-0000-0000-0000-000000000024',
    user_id: userId,
    username: 'chofer',
    role_id: roleId,
    role_code: roleCode,
    company_id: '00000000-0000-0000-0000-000000000023',
    expires_at: '2030-01-01T00:00:00.000Z'
  };
}

const authHeaders = { authorization: 'Bearer token_valido' };
const validLocation = {
  latitude: -25.28,
  longitude: -57.63,
  accuracy: 4,
  speed: null,
  heading: 90,
  captured_at: '2030-01-01T00:00:00.000Z'
};

test('chofer actualiza ubicación mediante la RPC con el usuario de su sesión', async () => {
  const database = new FakeDatabase();
  const app = await buildApp({ database });

  try {
    const response = await app.inject({
      method: 'POST',
      url: '/api/driver/location',
      headers: authHeaders,
      payload: validLocation
    });

    assert.equal(response.statusCode, 200);
    assert.deepEqual(database.rpcParameters, [[
      userId,
      -25.28,
      -57.63,
      4,
      null,
      90,
      '2030-01-01T00:00:00.000Z'
    ]]);
    assert.deepEqual(response.json(), {
      location: {
        driver_user_id: userId,
        company_id: '00000000-0000-0000-0000-000000000023',
        management_id: null,
        vehicle_id: null,
        latitude: -25.28,
        longitude: -57.63,
        accuracy: 4,
        speed: null,
        heading: 90,
        captured_at: '2030-01-01T00:00:00.000Z'
      }
    });
  } finally {
    await app.close();
  }
});

test('admin y supervisor no pueden informar ubicación', async () => {
  for (const roleCode of ['admin', 'supervisor']) {
    const database = new FakeDatabase();
    database.sessionRows = [activeSession(roleCode)];
    const app = await buildApp({ database });

    try {
      const response = await app.inject({
        method: 'POST',
        url: '/api/driver/location',
        headers: authHeaders,
        payload: validLocation
      });
      assert.equal(response.statusCode, 403);
      assert.equal(database.rpcParameters.length, 0);
    } finally {
      await app.close();
    }
  }
});

test('una solicitud sin sesión recibe 401', async () => {
  const database = new FakeDatabase();
  const app = await buildApp({ database });

  try {
    const response = await app.inject({
      method: 'POST',
      url: '/api/driver/location',
      payload: validLocation
    });
    assert.equal(response.statusCode, 401);
    assert.equal(database.rpcParameters.length, 0);
  } finally {
    await app.close();
  }
});

test('heartbeat del chofer usa sólo la sesión y no modifica la ubicación GPS', async () => {
  const database = new FakeDatabase();
  const app = await buildApp({ database });

  try {
    const response = await app.inject({
      method: 'POST',
      url: '/api/driver/presence',
      headers: authHeaders,
      payload: {}
    });

    assert.equal(response.statusCode, 204);
    assert.deepEqual(database.presenceParameters, [[userId]]);
    assert.equal(database.rpcParameters.length, 0);
  } finally {
    await app.close();
  }
});

test('heartbeat requiere sesión de chofer y rechaza datos del cliente', async () => {
  const unauthenticated = await buildApp({ database: new FakeDatabase() });
  try {
    const response = await unauthenticated.inject({
      method: 'POST',
      url: '/api/driver/presence',
      payload: {}
    });
    assert.equal(response.statusCode, 401);

    const invalidTokenDatabase = new FakeDatabase();
    invalidTokenDatabase.sessionRows = [];
    const invalidTokenApp = await buildApp({ database: invalidTokenDatabase });
    try {
      const invalidBearer = await invalidTokenApp.inject({
        method: 'POST',
        url: '/api/driver/presence',
        headers: { authorization: 'Bearer invalid-session-token' },
        payload: {}
      });
      assert.equal(invalidBearer.statusCode, 401);
    } finally {
      await invalidTokenApp.close();
    }
  } finally {
    await unauthenticated.close();
  }

  for (const role of ['admin', 'supervisor']) {
    const database = new FakeDatabase();
    database.sessionRows = [activeSession(role)];
    const forbidden = await buildApp({ database });
    try {
      const response = await forbidden.inject({
        method: 'POST',
        url: '/api/driver/presence',
        headers: authHeaders,
        payload: {}
      });
      assert.equal(response.statusCode, 403);
      assert.equal(database.presenceParameters.length, 0);
    } finally {
      await forbidden.close();
    }
  }

  const invalidDatabase = new FakeDatabase();
  const invalid = await buildApp({ database: invalidDatabase });
  try {
    const response = await invalid.inject({
      method: 'POST',
      url: '/api/driver/presence',
      headers: authHeaders,
      payload: { user_id: userId, last_seen_at: '2030-01-01T00:00:00.000Z' }
    });
    assert.equal(response.statusCode, 400);
    assert.equal(invalidDatabase.presenceParameters.length, 0);
  } finally {
    await invalid.close();
  }
});

test('fleet online/offline uses last_seen_at instead of captured_at', async () => {
  const database = new FakeDatabase();
  database.sessionRows = [activeSession('admin')];
  const app = await buildApp({ database });

  try {
    const response = await app.inject({
      method: 'GET',
      url: '/api/fleet/locations',
      headers: authHeaders
    });

    assert.equal(response.statusCode, 200);
    assert.match(database.fleetLocationsQuery ?? '', /WHEN cl\.last_seen_at IS NULL/);
    assert.doesNotMatch(database.fleetLocationsQuery ?? '', /WHEN cl\.captured_at IS NULL/);
  } finally {
    await app.close();
  }
});

test('presence migration preserves the independent GPS and presence timestamps', async () => {
  const migration = await readFile(
    resolve(process.cwd(), '../database/migrations/003_driver_presence.sql'),
    'utf8'
  );
  const presenceFunction = migration.slice(
    migration.indexOf('create or replace function public.fleet_control_touch_driver_presence'),
    migration.indexOf('alter function public.fleet_control_update_driver_location')
  );

  assert.match(migration, /captured_at,\s*last_seen_at,\s*updated_at/);
  assert.match(migration, /p_captured_at,\s*v_now,\s*v_now/);
  assert.match(migration, /captured_at = excluded\.captured_at,\s*last_seen_at = excluded\.last_seen_at/);
  assert.match(presenceFunction, /set last_seen_at = now\(\)/);
  assert.doesNotMatch(presenceFunction, /captured_at\s*=/);
  assert.doesNotMatch(presenceFunction, /latitud\s*=/);
  assert.doesNotMatch(presenceFunction, /longitud\s*=/);
});

test('rechaza latitud, longitud y timestamp inválidos', async () => {
  const invalidPayloads = [
    { ...validLocation, latitude: -90.01 },
    { ...validLocation, longitude: 180.01 },
    { ...validLocation, captured_at: 'fecha-inválida' }
  ];

  for (const payload of invalidPayloads) {
    const database = new FakeDatabase();
    const app = await buildApp({ database });

    try {
      const response = await app.inject({
        method: 'POST',
        url: '/api/driver/location',
        headers: authHeaders,
        payload
      });
      assert.equal(response.statusCode, 400);
      assert.equal(database.rpcParameters.length, 0);
    } finally {
      await app.close();
    }
  }
});

test('rechaza campos de identidad enviados por el cliente', async () => {
  const database = new FakeDatabase();
  const app = await buildApp({ database });

  try {
    const response = await app.inject({
      method: 'POST',
      url: '/api/driver/location',
      headers: authHeaders,
      payload: { ...validLocation, userId: '00000000-0000-0000-0000-000000000025' }
    });
    assert.equal(response.statusCode, 400);
    assert.equal(database.rpcParameters.length, 0);
  } finally {
    await app.close();
  }
});
