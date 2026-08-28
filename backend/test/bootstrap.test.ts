import assert from 'node:assert/strict';
import test from 'node:test';

import type { QueryResultRow } from 'pg';

import { buildApp } from '../src/app.js';
import type { Database, DatabaseQueryResult } from '../src/auth/auth.types.js';

const userId = '00000000-0000-0000-0000-000000000011';
const otherUserId = '00000000-0000-0000-0000-000000000012';
const roleId = '00000000-0000-0000-0000-000000000013';
const notificationId = '00000000-0000-0000-0000-000000000014';

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
  sessionRows: SessionRow[] = [activeSession()];
  views: QueryResultRow[] = [{ codigo: 'home' }, { codigo: 'settings' }];
  notifications: QueryResultRow[] = [
    {
      id: notificationId,
      tipo: 'new_order',
      titulo: 'Nuevo pedido',
      mensaje: 'Hay un pedido disponible.',
      entity_type: 'pedido',
      entity_id: '00000000-0000-0000-0000-000000000015',
      ruta: '/orders',
      leida: false,
      created_at: new Date('2030-01-01T00:00:00.000Z'),
      read_at: null
    }
  ];
  markReadRows: QueryResultRow[] = [{ id: notificationId }];
  viewParameters: unknown[] = [];
  notificationListParameters: unknown[] = [];
  markReadParameters: unknown[] = [];
  registeredDevices: unknown[][] = [];
  unregisteredDevices: unknown[][] = [];

  async query<Row extends QueryResultRow = QueryResultRow>(
    text: string,
    values: unknown[] = []
  ): Promise<DatabaseQueryResult<Row>> {
    if (text.includes('FROM public.sesiones s')) return this.result<Row>(this.sessionRows);
    if (text.includes('SET last_used_at = now()')) return this.result<Row>([]);
    if (text.includes('FROM public.role_views rv')) {
      this.viewParameters = values;
      return this.result<Row>(this.views);
    }
    if (text.includes('FROM public.notificaciones')) {
      this.notificationListParameters = values;
      return this.result<Row>(this.notifications);
    }
    if (text.includes('UPDATE public.notificaciones')) {
      this.markReadParameters = values;
      return this.result<Row>(this.markReadRows);
    }
    if (text.includes('INSERT INTO public.notification_devices')) {
      this.registeredDevices.push(values);
      return this.result<Row>([]);
    }
    if (text.includes('UPDATE public.notification_devices')) {
      this.unregisteredDevices.push(values);
      return this.result<Row>([]);
    }

    throw new Error(`Unexpected query in test: ${text}`);
  }

  private result<Row extends QueryResultRow>(rows: QueryResultRow[]): DatabaseQueryResult<Row> {
    return { rows: rows as Row[], rowCount: rows.length };
  }
}

function activeSession(): SessionRow {
  return {
    session_id: '00000000-0000-0000-0000-000000000016',
    user_id: userId,
    username: 'operador',
    role_id: roleId,
    role_code: 'admin',
    company_id: null,
    expires_at: '2030-01-01T00:00:00.000Z'
  };
}

async function appWith(database: FakeDatabase) {
  return buildApp({ database });
}

const authHeaders = { authorization: 'Bearer token_valido' };

test('my-views usa el rol de la sesión y sólo devuelve vistas activas permitidas', async () => {
  const database = new FakeDatabase();
  const app = await appWith(database);

  try {
    const response = await app.inject({ method: 'GET', url: '/api/me/views', headers: authHeaders });

    assert.equal(response.statusCode, 200);
    assert.deepEqual(response.json(), { views: ['home', 'settings'] });
    assert.deepEqual(database.viewParameters, [roleId]);
  } finally {
    await app.close();
  }
});

test('my-views rechaza una sesión cuyo rol ya no es válido', async () => {
  const database = new FakeDatabase();
  database.sessionRows = [];
  const app = await appWith(database);

  try {
    const response = await app.inject({ method: 'GET', url: '/api/me/views', headers: authHeaders });
    assert.equal(response.statusCode, 401);
  } finally {
    await app.close();
  }
});

test('notifications lista únicamente las del usuario autenticado y respeta el límite', async () => {
  const database = new FakeDatabase();
  const app = await appWith(database);

  try {
    const response = await app.inject({ method: 'GET', url: '/api/notifications?limit=25', headers: authHeaders });

    assert.equal(response.statusCode, 200);
    assert.equal(response.json().notifications.length, 1);
    assert.deepEqual(database.notificationListParameters, [userId, 25]);
  } finally {
    await app.close();
  }
});

test('mark read requiere propiedad de la notificación', async () => {
  const database = new FakeDatabase();
  const app = await appWith(database);

  try {
    const own = await app.inject({
      method: 'POST',
      url: `/api/notifications/${notificationId}/read`,
      headers: authHeaders
    });
    assert.equal(own.statusCode, 200);
    assert.deepEqual(database.markReadParameters, [notificationId, userId]);

    database.markReadRows = [];
    const other = await app.inject({
      method: 'POST',
      url: `/api/notifications/${notificationId}/read`,
      headers: authHeaders
    });
    assert.equal(other.statusCode, 404);
  } finally {
    await app.close();
  }
});

test('devices registra y desregistra sólo con el usuario de la sesión', async () => {
  const database = new FakeDatabase();
  const app = await appWith(database);

  try {
    const register = await app.inject({
      method: 'POST',
      url: '/api/notification-devices',
      headers: authHeaders,
      payload: { token: 'device-token', platform: 'android', deviceId: 'android-device' }
    });
    assert.equal(register.statusCode, 200);
    assert.deepEqual(database.registeredDevices, [[userId, 'device-token', 'android', 'android-device']]);

    const unregister = await app.inject({
      method: 'POST',
      url: '/api/notification-devices/unregister',
      headers: authHeaders,
      payload: { token: 'device-token' }
    });
    assert.equal(unregister.statusCode, 200);
    assert.deepEqual(database.unregisteredDevices, [[userId, 'device-token']]);

    const impersonation = await app.inject({
      method: 'POST',
      url: '/api/notification-devices',
      headers: authHeaders,
      payload: { token: 'other-token', platform: 'web', usuario_id: otherUserId }
    });
    assert.equal(impersonation.statusCode, 400);
    assert.equal(database.registeredDevices.length, 1);
  } finally {
    await app.close();
  }
});
