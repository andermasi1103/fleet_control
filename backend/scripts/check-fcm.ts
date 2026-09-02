import assert from 'node:assert/strict';

import type { QueryResultRow } from 'pg';

import type { Database, DatabaseQueryResult } from '../src/auth/auth.types.js';
import { notifyNewOrder, type FirebaseServiceAccount } from '../src/notifications/fcm.service.js';

class FakeDatabase implements Database {
  created = true;
  invalidated: unknown[] | undefined;
  recipientParameters: unknown[] | undefined;
  async query<Row extends QueryResultRow = QueryResultRow>(text: string, values: unknown[] = []): Promise<DatabaseQueryResult<Row>> {
    if (text.includes('FROM public.usuario_locales')) { this.recipientParameters = values; return this.result<Row>([{ id: '00000000-0000-0000-0000-000000000001' }, { id: '00000000-0000-0000-0000-000000000002' }]); }
    if (text.includes('FROM public.locales')) return this.result<Row>([{ nombre: 'Local Central' }]);
    if (text.includes('INSERT INTO public.notificaciones')) return this.result<Row>(this.created ? [{ usuario_id: '00000000-0000-0000-0000-000000000001' }, { usuario_id: '00000000-0000-0000-0000-000000000002' }] : []);
    if (text.includes('FROM public.notification_devices')) return this.result<Row>([{ id: '00000000-0000-0000-0000-000000000011', token: 'valid' }, { id: '00000000-0000-0000-0000-000000000012', token: 'invalid' }]);
    if (text.includes('UPDATE public.notification_devices')) { this.invalidated = values[0] as unknown[]; return this.result<Row>([]); }
    throw new Error(`Unexpected query: ${text}`);
  }
  private result<Row extends QueryResultRow>(rows: QueryResultRow[]): DatabaseQueryResult<Row> { return { rows: rows as Row[], rowCount: rows.length }; }
}

const account: FirebaseServiceAccount = { client_email: 'test@example.test', private_key: 'unused', project_id: 'test-project' };
const database = new FakeDatabase();
const messages: { token: string; title: string; body: string; data: Record<string, string> }[] = [];
await notifyNewOrder(database, { id: '00000000-0000-0000-0000-000000000099', empresa_id: '00000000-0000-0000-0000-000000000100', local_id: '00000000-0000-0000-0000-000000000101' }, {
  account,
  transport: async (device, message) => { messages.push({ token: device.token, title: message.title, body: message.body, data: message.data }); return { invalidToken: device.token === 'invalid' }; }
});
assert.equal(messages.length, 2, 'One logical notification must reach every active device.');
assert.equal(messages[0]?.title, 'Nuevo pedido disponible');
assert.equal(messages[0]?.body, 'Local Central lanzó un nuevo pedido.');
assert.deepEqual(messages[0]?.data, { type: 'new_order', order_id: '00000000-0000-0000-0000-000000000099', route: '/driver-orders' });
assert.deepEqual(database.recipientParameters, ['00000000-0000-0000-0000-000000000101', '00000000-0000-0000-0000-000000000100']);
assert.deepEqual(database.invalidated, ['00000000-0000-0000-0000-000000000012']);
database.created = false;
await notifyNewOrder(database, { id: '00000000-0000-0000-0000-000000000099', empresa_id: '00000000-0000-0000-0000-000000000100', local_id: '00000000-0000-0000-0000-000000000101' }, { account, transport: async () => { throw new Error('A retry must not send duplicated pushes.'); } });
console.log('fcm notification integration: passed');
