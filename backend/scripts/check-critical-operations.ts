import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';

import { buildApp } from '../src/app.js';
import { hashSessionToken } from '../src/auth/auth.service.js';
import { pool } from '../src/db/pool.js';

const client = await pool.connect();
let app: Awaited<ReturnType<typeof buildApp>> | undefined;
let transactionStarted = false;

async function createUser(companyId: string, roleId: string, name: string, username: string): Promise<string> {
  const result = await client.query<{ id: string }>(
    'SELECT public.fleet_control_create_usuario($1::text,$2::text,$3::text,$4::uuid,$5::uuid,true) AS id',
    [name, username, `test-${randomUUID()}`, companyId, roleId]
  );
  assert.ok(result.rows[0]?.id, 'Fixture user was not created.');
  return result.rows[0].id;
}

async function createSession(userId: string, prefix: string): Promise<string> {
  const token = `${prefix}_${randomUUID().replaceAll('-', '')}`;
  await client.query(
    `INSERT INTO public.sesiones (usuario_id, token_hash, expires_at)
     VALUES ($1::uuid, $2::text, now() + interval '1 hour')`,
    [userId, hashSessionToken(token)]
  );
  return token;
}

try {
  await client.query('BEGIN');
  transactionStarted = true;
  const fixture = (await client.query<{ company_id: string; admin_role_id: string; driver_role_id: string }>(
    `SELECT (SELECT id FROM public.empresas WHERE activo = true LIMIT 1) AS company_id,
            (SELECT id FROM public.roles WHERE codigo = 'admin' AND activo = true LIMIT 1) AS admin_role_id,
            (SELECT id FROM public.roles WHERE codigo = 'chofer' AND activo = true LIMIT 1) AS driver_role_id`
  )).rows[0];
  assert.ok(fixture?.company_id && fixture.admin_role_id && fixture.driver_role_id, 'Missing active fixture data.');

  const suffix = randomUUID().replaceAll('-', '').slice(0, 12);
  const adminId = await createUser(fixture.company_id, fixture.admin_role_id, 'Critical Admin', `critical_admin_${suffix}`);
  const driverId = await createUser(fixture.company_id, fixture.driver_role_id, 'Critical Driver', `critical_driver_${suffix}`);
  const [adminToken, driverToken] = await Promise.all([createSession(adminId, 'admin'), createSession(driverId, 'driver')]);
  const adminHeaders = { authorization: `Bearer ${adminToken}` };
  const driverHeaders = { authorization: `Bearer ${driverToken}` };

  const location = await client.query<{ id: string }>(
    `INSERT INTO public.locales (empresa_id,nombre,latitud,longitud,radio_metros,activo)
     VALUES ($1::uuid,$2::text,-25.2867,-57.647,100,true) RETURNING id`,
    [fixture.company_id, `Critical Location ${suffix}`]
  );
  const locationId = location.rows[0]?.id;
  assert.ok(locationId, 'Fixture location was not created.');
  const description = await client.query<{ id: string }>(
    `INSERT INTO public.pedido_descripciones (empresa_id,nombre,activo)
     VALUES ($1::uuid,$2::text,true) RETURNING id`,
    [fixture.company_id, `Critical description ${suffix}`]
  );
  const descriptionId = description.rows[0]?.id;
  assert.ok(descriptionId, 'Fixture description was not created.');
  const vehicle = await client.query<{ id: string }>(
    `INSERT INTO public.vehiculos (empresa_id,patente,activo)
     VALUES ($1::uuid,$2::text,true) RETURNING id`,
    [fixture.company_id, `CO-${suffix}`]
  );
  const vehicleId = vehicle.rows[0]?.id;
  assert.ok(vehicleId, 'Fixture vehicle was not created.');
  await client.query('SELECT public.fleet_control_set_user_vehicle($1::uuid,$2::uuid)', [driverId, vehicleId]);

  app = await buildApp({ database: client });
  const attendance = await app.inject({ method: 'POST', url: '/api/attendance', headers: adminHeaders, payload: { local_id: locationId, latitud: -25.2867, longitud: -57.647 } });
  assert.equal(attendance.statusCode, 201, 'Attendance creation failed.');
  const attendanceStatus = await app.inject({ method: 'GET', url: '/api/attendance/status', headers: adminHeaders });
  assert.equal(attendanceStatus.statusCode, 200);
  assert.equal((attendanceStatus.json() as { next_action: string }).next_action, 'salida');
  const outside = await app.inject({ method: 'POST', url: '/api/attendance', headers: adminHeaders, payload: { local_id: locationId, latitud: -25.0, longitud: -57.0 } });
  assert.equal(outside.statusCode, 422, 'Attendance must enforce the geofence.');

  const createOrder = async () => {
    const response = await app!.inject({ method: 'POST', url: '/api/orders', headers: adminHeaders, payload: { local_id: locationId, descripcion_tipo_id: descriptionId, prioridad: 'normal', destino: 'Destino de prueba' } });
    assert.equal(response.statusCode, 201, `Order creation failed with ${response.statusCode}.`);
    const id = (response.json() as { order?: { id?: string } }).order?.id;
    assert.ok(id, 'Order did not return an id.');
    return id;
  };
  const claimedOrderId = await createOrder();
  const manualOrderId = await createOrder();
  const cancelledOrderId = await createOrder();
  const available = await app.inject({ method: 'GET', url: '/api/driver/orders/available', headers: driverHeaders });
  assert.equal(available.statusCode, 200);
  assert.ok((available.json() as { orders: { order_id: string }[] }).orders.some((order) => order.order_id === claimedOrderId));
  const existingManagement = await client.query('SELECT id FROM public.gestiones WHERE pedido_id=$1::uuid', [claimedOrderId]);
  assert.equal(existingManagement.rowCount, 0, 'Fresh order unexpectedly has a management.');
  const claim = await app.inject({ method: 'POST', url: `/api/driver/orders/${claimedOrderId}/claim`, headers: driverHeaders, payload: {} });
  assert.equal(claim.statusCode, 201, `Driver claim failed with ${claim.statusCode}: ${claim.body}`);
  const claimedManagementId = (claim.json() as { management?: { id?: string } }).management?.id;
  assert.ok(claimedManagementId, 'Claim did not return a management.');
  const accepted = await app.inject({ method: 'POST', url: `/api/managements/${claimedManagementId}/status`, headers: driverHeaders, payload: { status: 'aceptado' } });
  assert.equal(accepted.statusCode, 200, `Management acceptance failed with ${accepted.statusCode}.`);
  const manual = await app.inject({ method: 'POST', url: '/api/managements', headers: adminHeaders, payload: { order_id: manualOrderId, driver_user_id: driverId, vehicle_id: vehicleId } });
  assert.equal(manual.statusCode, 201, `Manual management creation failed with ${manual.statusCode}.`);
  assert.equal((manual.json() as { management?: { queue_position?: number } }).management?.queue_position, 2);
  const managements = await app.inject({ method: 'GET', url: '/api/managements?limit=20&offset=0', headers: driverHeaders });
  assert.equal(managements.statusCode, 200);
  assert.ok((managements.json() as { managements: { id: string }[] }).managements.some((management) => management.id === claimedManagementId));
  const cancelled = await app.inject({ method: 'POST', url: `/api/orders/${cancelledOrderId}/cancel`, headers: adminHeaders, payload: {} });
  assert.equal(cancelled.statusCode, 200, `Order cancellation failed with ${cancelled.statusCode}.`);
  const history = await app.inject({ method: 'GET', url: '/api/attendance?limit=20&offset=0', headers: adminHeaders });
  assert.equal(history.statusCode, 200);
  assert.ok((history.json() as { attendances: unknown[] }).attendances.length > 0);
  console.log('critical operations integration: passed (transaction will roll back)');
} finally {
  if (app) await app.close();
  if (transactionStarted) await client.query('ROLLBACK');
  client.release();
  await pool.end();
}
