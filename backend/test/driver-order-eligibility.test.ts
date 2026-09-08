import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import test from 'node:test';

import type { QueryResultRow } from 'pg';

import { buildApp } from '../src/app.js';
import type { Database, DatabaseQueryResult } from '../src/auth/auth.types.js';
import { notifyNewOrder } from '../src/notifications/fcm.service.js';

const companyA = '00000000-0000-0000-0000-000000000101';
const companyB = '00000000-0000-0000-0000-000000000102';
const localA1 = '00000000-0000-0000-0000-000000000103';
const orderA1 = '00000000-0000-0000-0000-000000000104';
const managementId = '00000000-0000-0000-0000-000000000105';
const drivers = {
  c1: '00000000-0000-0000-0000-000000000106',
  c2: '00000000-0000-0000-0000-000000000107',
  c3: '00000000-0000-0000-0000-000000000108',
  c4: '00000000-0000-0000-0000-000000000109',
  b1: '00000000-0000-0000-0000-000000000110'
} as const;

type SessionRow = QueryResultRow & {
  session_id: string;
  user_id: string;
  username: string;
  role_id: string;
  role_code: string;
  company_id: string;
  expires_at: string;
};

class DriverOrdersDatabase implements Database {
  readonly availableDriverIds = new Set([drivers.c1, drivers.c3]);
  availableQuery: { text: string; values: unknown[] } | null = null;
  claimParameters: unknown[][] = [];

  constructor(private readonly driverId: string, private readonly companyId: string) {}

  async query<Row extends QueryResultRow = QueryResultRow>(
    text: string,
    values: unknown[] = []
  ): Promise<DatabaseQueryResult<Row>> {
    if (text.includes('FROM public.sesiones s')) return this.result<Row>([this.session()]);
    if (text.includes('SET last_used_at = now()')) return this.result<Row>([]);
    if (text.includes('SELECT p.id AS order_id')) {
      this.availableQuery = { text, values };
      const [driverId, companyId] = values;
      if (driverId !== this.driverId || companyId !== this.companyId) {
        throw new Error('Available orders must be scoped by the authenticated driver and company.');
      }
      return this.result<Row>(this.availableDriverIds.has(this.driverId) && this.companyId === companyA ? [availableOrder()] : []);
    }
    if (text.includes('SELECT * FROM public.pedidos WHERE id')) return this.result<Row>([orderRow()]);
    if (text.includes('FROM public.gestiones WHERE pedido_id')) return this.result<Row>([]);
    if (text.includes('FROM public.usuario_locales') && text.includes('local_id=$2::uuid')) {
      return this.result<Row>(this.availableDriverIds.has(this.driverId) && this.companyId === companyA ? [{ '?column?': 1 }] : []);
    }
    if (text.includes('fleet_control_driver_claim_order')) {
      this.claimParameters.push(values);
      if (!this.availableDriverIds.has(this.driverId) || this.companyId !== companyA) {
        throw new Error('forbidden');
      }
      return this.result<Row>([{ id: managementId }]);
    }
    if (text.includes('FROM public.gestiones g JOIN public.pedidos p')) {
      return this.result<Row>([{ id: managementId, pedido_id: orderA1, estado: 'asignado' }]);
    }

    throw new Error(`Unexpected query in test: ${text}`);
  }

  private session(): SessionRow {
    return {
      session_id: '00000000-0000-0000-0000-000000000111',
      user_id: this.driverId,
      username: 'chofer',
      role_id: '00000000-0000-0000-0000-000000000112',
      role_code: 'chofer',
      company_id: this.companyId,
      expires_at: '2030-01-01T00:00:00.000Z'
    };
  }

  private result<Row extends QueryResultRow>(rows: QueryResultRow[]): DatabaseQueryResult<Row> {
    return { rows: rows as Row[], rowCount: rows.length };
  }
}

class NotificationDatabase implements Database {
  recipientQuery: { text: string; values: unknown[] } | null = null;
  deactivatedDeviceIds: string[] = [];

  constructor(readonly activeDevices: { id: string; token: string }[] = []) {}

  async query<Row extends QueryResultRow = QueryResultRow>(
    text: string,
    values: unknown[] = []
  ): Promise<DatabaseQueryResult<Row>> {
    if (text.includes('FROM public.usuario_locales')) {
      this.recipientQuery = { text, values };
      return this.result<Row>([{ id: drivers.c1 }, { id: drivers.c3 }]);
    }
    if (text.includes('INSERT INTO public.notificaciones')) return this.result<Row>([{ usuario_id: drivers.c1 }, { usuario_id: drivers.c3 }]);
    if (text.includes('FROM public.notification_devices')) return this.result<Row>(this.activeDevices);
    if (text.includes('UPDATE public.notification_devices SET activo=false')) {
      this.deactivatedDeviceIds = values[0] as string[];
      return this.result<Row>([]);
    }
    throw new Error(`Unexpected query in test: ${text}`);
  }

  private result<Row extends QueryResultRow>(rows: QueryResultRow[]): DatabaseQueryResult<Row> {
    return { rows: rows as Row[], rowCount: rows.length };
  }
}

const headers = { authorization: 'Bearer token_valido' };

function availableOrder() {
  return { order_id: orderA1, local: 'A1', prioridad: 'normal', created_at: '2030-01-01T00:00:00.000Z' };
}

function orderRow() {
  return { id: orderA1, empresa_id: companyA, local_id: localA1, estado: 'pendiente' };
}

test('Pedidos disponibles aísla los choferes por sus locales asignados', async () => {
  const expected = new Map<string, string[]>([
    [drivers.c1, [orderA1]],
    [drivers.c2, []],
    [drivers.c3, [orderA1]],
    [drivers.c4, []],
    [drivers.b1, []]
  ]);

  for (const [driverId, orderIds] of expected) {
    const database = new DriverOrdersDatabase(driverId, driverId === drivers.b1 ? companyB : companyA);
    const app = await buildApp({ database });
    try {
      const response = await app.inject({ method: 'GET', url: '/api/driver/orders/available', headers });
      assert.equal(response.statusCode, 200);
      assert.deepEqual(response.json().orders.map((order: { order_id: string }) => order.order_id), orderIds);
      assert.match(database.availableQuery?.text ?? '', /JOIN public\.usuario_locales/);
    } finally {
      await app.close();
    }
  }
});

test('un chofer no elegible no puede consultar ni reclamar un pedido por UUID', async () => {
  for (const driverId of [drivers.c2, drivers.c4, drivers.b1]) {
    const database = new DriverOrdersDatabase(driverId, driverId === drivers.b1 ? companyB : companyA);
    const app = await buildApp({ database });
    try {
      const detail = await app.inject({ method: 'GET', url: `/api/orders/${orderA1}`, headers });
      assert.equal(detail.statusCode, 403);

      const claim = await app.inject({ method: 'POST', url: `/api/driver/orders/${orderA1}/claim`, headers, payload: {} });
      assert.equal(claim.statusCode, 403);
      assert.deepEqual(database.claimParameters, [[orderA1, driverId]]);
    } finally {
      await app.close();
    }
  }
});

test('cada chofer asignado puede reclamar y conserva la protección de la RPC', async () => {
  for (const driverId of [drivers.c1, drivers.c3]) {
    const database = new DriverOrdersDatabase(driverId, companyA);
    const app = await buildApp({ database });
    try {
      const claim = await app.inject({ method: 'POST', url: `/api/driver/orders/${orderA1}/claim`, headers, payload: {} });
      assert.equal(claim.statusCode, 201);
      assert.deepEqual(database.claimParameters, [[orderA1, driverId]]);
    } finally {
      await app.close();
    }
  }
});

test('las notificaciones de nuevo pedido se dirigen sólo a choferes asignados al local', async () => {
  const database = new NotificationDatabase();
  await notifyNewOrder(database, { id: orderA1, empresa_id: companyA, local_id: localA1 }, { account: null });

  assert.match(database.recipientQuery?.text ?? '', /FROM public\.usuario_locales/);
  assert.deepEqual(database.recipientQuery?.values, [localA1, companyA]);
});

test('push de pedido usa contenido seguro, data de navegación y desactiva tokens inválidos', async () => {
  const database = new NotificationDatabase([
    { id: 'device-1', token: 'token-no-debe-aparecer-en-logs' },
    { id: 'device-2', token: 'token-invalido' }
  ]);
  const messages: { deviceId: string; title: string; body: string; data: Record<string, string>; androidChannelId: string }[] = [];

  await notifyNewOrder(
    database,
    { id: orderA1, empresa_id: companyA, local_id: localA1 },
    {
      account: {
        client_email: 'firebase@example.test',
        private_key: 'not-a-real-key',
        project_id: 'masitrack-test'
      },
      transport: async (device, message) => {
        messages.push({ deviceId: device.id, ...message });
        return { accepted: device.id === 'device-1', invalidToken: device.id === 'device-2' };
      }
    }
  );

  assert.deepEqual(messages, [
    {
      deviceId: 'device-1',
      title: 'MasiTrack',
      body: 'Nuevo pedido disponible',
      data: { type: 'new_order', order_id: orderA1, route: '/driver-orders' },
      androidChannelId: 'masitrack_orders'
    },
    {
      deviceId: 'device-2',
      title: 'MasiTrack',
      body: 'Nuevo pedido disponible',
      data: { type: 'new_order', order_id: orderA1, route: '/driver-orders' },
      androidChannelId: 'masitrack_orders'
    }
  ]);
  assert.deepEqual(database.deactivatedDeviceIds, ['device-2']);
});

test('007 protege el claim con usuario_locales y conserva la asignación idempotente', async () => {
  const [migration, baseline] = await Promise.all([
    readFile(
      resolve(process.cwd(), '../database/migrations/007_driver_local_eligibility.sql'),
      'utf8'
    ),
    readFile(
      resolve(process.cwd(), '../database/migrations/000_initial_schema.sql'),
      'utf8'
    )
  ]);

  assert.match(migration, /create or replace function public\.fleet_control_driver_claim_order/i);
  assert.match(migration, /from public\.usuario_locales/i);
  assert.match(migration, /usuario_id\s*=\s*v_driver\.id/i);
  assert.match(migration, /local_id\s*=\s*v_order\.local_id/i);
  assert.match(migration, /raise exception 'forbidden'/i);
  assert.match(migration, /create index if not exists usuario_locales_local_usuario_idx/i);
  assert.match(migration, /for update/i);
  assert.match(migration, /gestiones_pedido_unique/i);
  assert.match(migration, /order_already_taken/i);
  assert.match(baseline, /usuario_locales_usuario_local_unique unique \(usuario_id, local_id\)/i);
  assert.match(baseline, /on conflict \(usuario_id, local_id\) do nothing/i);
  assert.match(baseline, /where id = any\(v_location_ids\) and empresa_id = v_empresa_id/i);
  assert.match(baseline, /delete from public\.usuario_locales\s+where usuario_id = p_user_id and not \(local_id = any\(v_location_ids\)\)/i);
  assert.match(migration, /v_driver\.activo is not true/i);
});
