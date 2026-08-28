import assert from 'node:assert/strict';
import test from 'node:test';

import type { QueryResultRow } from 'pg';

import { buildApp } from '../src/app.js';
import type { Database, DatabaseQueryResult } from '../src/auth/auth.types.js';

const companyId = '00000000-0000-0000-0000-000000000101';
const userId = '00000000-0000-0000-0000-000000000102';

class FakeDatabase implements Database {
  roleCode = 'admin';
  queries: { text: string; values: unknown[] }[] = [];

  async query<Row extends QueryResultRow = QueryResultRow>(text: string, values: unknown[] = []): Promise<DatabaseQueryResult<Row>> {
    this.queries.push({ text, values });
    if (text.includes('FROM public.sesiones s')) return this.result<Row>([{
      session_id: '00000000-0000-0000-0000-000000000103', user_id: userId, username: 'admin',
      role_id: '00000000-0000-0000-0000-000000000104', role_code: this.roleCode, company_id: companyId,
      expires_at: '2030-01-01T00:00:00.000Z'
    }]);
    if (text.includes('SET last_used_at = now()')) return this.result<Row>([]);
    if (text.includes('FROM public.vehiculos v')) return this.result<Row>([{ id: '00000000-0000-0000-0000-000000000105', empresa_id: companyId, patente: 'TEST-1' }]);
    if (text.includes('FROM public.roles ORDER BY')) return this.result<Row>([{ id: '00000000-0000-0000-0000-000000000106', codigo: 'admin', nombre: 'Admin', activo: true }]);
    throw new Error(`Unexpected query in test: ${text}`);
  }

  private result<Row extends QueryResultRow>(rows: QueryResultRow[]): DatabaseQueryResult<Row> { return { rows: rows as Row[], rowCount: rows.length }; }
}

const headers = { authorization: 'Bearer token_valido' };

test('las rutas administrativas rechazan roles sin permiso antes de consultar datos administrativos', async () => {
  const database = new FakeDatabase(); database.roleCode = 'chofer';
  const app = await buildApp({ database });
  const response = await app.inject({ method: 'GET', url: '/api/users', headers });
  assert.equal(response.statusCode, 403);
  assert.equal(response.json().error, 'forbidden');
  await app.close();
});

test('un administrador solo consulta vehículos de su propia empresa', async () => {
  const database = new FakeDatabase();
  const app = await buildApp({ database });
  const response = await app.inject({ method: 'GET', url: '/api/vehicles', headers });
  assert.equal(response.statusCode, 200);
  assert.equal(response.json().vehicles[0].empresa_id, companyId);
  const vehiclesQuery = database.queries.find((entry) => entry.text.includes('FROM public.vehiculos v'));
  assert.deepEqual(vehiclesQuery?.values, [companyId]);
  await app.close();
});

test('los roles globales y las vistas protegidas solo son administrables por super_admin', async () => {
  const database = new FakeDatabase(); database.roleCode = 'super_admin';
  const app = await buildApp({ database });
  const roles = await app.inject({ method: 'GET', url: '/api/roles', headers });
  assert.equal(roles.statusCode, 200);
  const protectedView = await app.inject({ method: 'PATCH', url: '/api/role-views', headers, payload: { role_code: 'admin', view_code: 'home', visible: false } });
  assert.equal(protectedView.statusCode, 400);
  await app.close();
});

test('los payloads administrativos son estrictos y no admiten datos de actor', async () => {
  const database = new FakeDatabase();
  const app = await buildApp({ database });
  const response = await app.inject({ method: 'POST', url: '/api/companies', headers, payload: { nombre: 'Prueba', actor_id: userId } });
  assert.equal(response.statusCode, 400);
  await app.close();
});
