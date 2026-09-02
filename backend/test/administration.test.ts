import assert from 'node:assert/strict';
import test from 'node:test';

import type { QueryResultRow } from 'pg';

import { buildApp } from '../src/app.js';
import type { Database, DatabaseQueryResult } from '../src/auth/auth.types.js';

const companyId = '00000000-0000-0000-0000-000000000101';
const otherCompanyId = '00000000-0000-0000-0000-000000000107';
const userId = '00000000-0000-0000-0000-000000000102';
const otherUserId = '00000000-0000-0000-0000-000000000108';
const superAdminRoleId = '00000000-0000-0000-0000-000000000109';

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
    if (text.includes('FROM public.empresas')) return this.result<Row>([{
      id: companyId, nombre: 'Empresa de prueba', activo: true,
      local_marker_icon: 'storefront', local_marker_color: '#1565C0'
    }]);
    if (text.includes('FROM public.vehiculos v')) return this.result<Row>([{ id: '00000000-0000-0000-0000-000000000105', empresa_id: companyId, patente: 'TEST-1' }]);
    if (text.includes('SELECT id, codigo FROM public.roles WHERE id')) return this.result<Row>([{ id: superAdminRoleId, codigo: 'super_admin' }]);
    if (text.includes('FROM public.roles') && text.includes('ORDER BY nivel,codigo')) {
      const roles = [
        { id: '00000000-0000-0000-0000-000000000110', codigo: 'user', nombre: 'Usuario', activo: true },
        { id: '00000000-0000-0000-0000-000000000111', codigo: 'local', nombre: 'Local', activo: true },
        { id: '00000000-0000-0000-0000-000000000112', codigo: 'chofer', nombre: 'Chofer', activo: true },
        { id: '00000000-0000-0000-0000-000000000113', codigo: 'supervisor', nombre: 'Supervisor', activo: true },
        { id: '00000000-0000-0000-0000-000000000106', codigo: 'admin', nombre: 'Admin', activo: true },
        { id: superAdminRoleId, codigo: 'super_admin', nombre: 'Super admin', activo: true }
      ];
      return this.result<Row>(text.includes("codigo <> 'super_admin'") ? roles.slice(0, -1) : roles);
    }
    if (text.includes('FROM public.usuarios u JOIN public.roles r') && values[0] === otherUserId) return this.result<Row>([{
      id: otherUserId, usuario: 'otro-admin', nombre: 'Otra empresa', activo: true,
      empresa_id: otherCompanyId, rol_id: '00000000-0000-0000-0000-000000000106', rol_codigo: 'admin'
    }]);
    if (text.includes('FROM public.usuarios u JOIN public.roles r')) return this.result<Row>([]);
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
  assert.deepEqual(
    roles.json().roles.map((role: { codigo: string }) => role.codigo),
    ['user', 'local', 'chofer', 'supervisor', 'admin', 'super_admin']
  );
  const protectedView = await app.inject({ method: 'PATCH', url: '/api/role-views', headers, payload: { role_code: 'admin', view_code: 'home', visible: false } });
  assert.equal(protectedView.statusCode, 400);
  await app.close();
});

test('un administrador consulta solo los roles que puede asignar', async () => {
  const database = new FakeDatabase();
  const app = await buildApp({ database });
  const response = await app.inject({ method: 'GET', url: '/api/roles', headers });
  assert.equal(response.statusCode, 200);
  assert.deepEqual(
    response.json().roles.map((role: { codigo: string }) => role.codigo),
    ['user', 'local', 'chofer', 'supervisor', 'admin']
  );
  await app.close();
});

test('un administrador no puede crear un super_admin ni modificar usuarios de otra empresa', async () => {
  const database = new FakeDatabase();
  const app = await buildApp({ database });
  const create = await app.inject({
    method: 'POST', url: '/api/users', headers,
    payload: { nombre: 'Escalada', usuario: 'escalada', password: 'clave-segura', empresa_id: companyId, rol_id: superAdminRoleId }
  });
  assert.equal(create.statusCode, 403);

  const update = await app.inject({
    method: 'PATCH', url: `/api/users/${otherUserId}`, headers,
    payload: { nombre: 'No permitido' }
  });
  assert.equal(update.statusCode, 403);
  assert.equal(database.queries.some((entry) => entry.text.includes('UPDATE public.usuarios')), false);
  await app.close();
});

test('supervisor conserva la lectura de usuarios y los roles operativos no acceden a su administración', async () => {
  for (const roleCode of ['supervisor', 'user', 'chofer', 'local']) {
    const database = new FakeDatabase();
    database.roleCode = roleCode;
    const app = await buildApp({ database });
    const users = await app.inject({ method: 'GET', url: '/api/users', headers });
    assert.equal(users.statusCode, roleCode === 'supervisor' ? 200 : 403);
    const roles = await app.inject({ method: 'GET', url: '/api/roles', headers });
    assert.equal(roles.statusCode, 403);
    await app.close();
  }
});

test('los payloads administrativos son estrictos y no admiten datos de actor', async () => {
  const database = new FakeDatabase();
  const app = await buildApp({ database });
  const response = await app.inject({ method: 'POST', url: '/api/companies', headers, payload: { nombre: 'Prueba', actor_id: userId } });
  assert.equal(response.statusCode, 400);
  await app.close();
});

test('la configuración visual de locales respeta empresa y catálogo cerrado', async () => {
  const database = new FakeDatabase();
  const app = await buildApp({ database });

  const invalid = await app.inject({
    method: 'POST',
    url: '/api/companies',
    headers,
    payload: { nombre: 'Prueba', local_marker_icon: 'arbitrario' }
  });
  assert.equal(invalid.statusCode, 400);

  const companies = await app.inject({ method: 'GET', url: '/api/companies', headers });
  assert.equal(companies.statusCode, 200);
  assert.equal(companies.json().companies[0].local_marker_icon, 'storefront');
  assert.equal(companies.json().companies[0].local_marker_color, '#1565C0');
  const scope = database.queries.find((entry) => entry.text.includes('FROM public.empresas'));
  assert.deepEqual(scope?.values, [companyId]);
  await app.close();
});
