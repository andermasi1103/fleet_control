import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';

import { buildApp } from '../src/app.js';
import { hashSessionToken } from '../src/auth/auth.service.js';
import { pool } from '../src/db/pool.js';

const client = await pool.connect();
let app: Awaited<ReturnType<typeof buildApp>> | undefined;
let started = false;

async function user(name: string, username: string, companyId: string | null, roleId: string) {
  const result = await client.query<{ id: string }>('SELECT public.fleet_control_create_usuario($1::text,$2::text,$3::text,$4::uuid,$5::uuid,true) AS id', [name, username, `test-${randomUUID()}`, companyId, roleId]);
  assert.ok(result.rows[0]?.id, 'Fixture user was not created.'); return result.rows[0].id;
}
async function session(userId: string, prefix: string) {
  const token = `${prefix}_${randomUUID().replaceAll('-', '')}`;
  await client.query(`INSERT INTO public.sesiones (usuario_id,token_hash,expires_at) VALUES ($1::uuid,$2::text,now()+interval '1 hour')`, [userId, hashSessionToken(token)]);
  return { authorization: `Bearer ${token}` };
}

try {
  await client.query('BEGIN'); started = true;
  const roles = (await client.query<{ code: string; id: string }>(`SELECT codigo AS code,id FROM public.roles WHERE codigo=ANY($1::text[])`, [['super_admin', 'admin', 'supervisor', 'chofer']])).rows;
  const role = (code: string) => { const id = roles.find((item) => item.code === code)?.id; assert.ok(id, `Missing ${code} role.`); return id; };
  const suffix = randomUUID().slice(0, 8);
  const companies = await client.query<{ id: string }>(`INSERT INTO public.empresas (nombre,activo) VALUES ($1::text,true),($2::text,true) RETURNING id`, [`Insights A ${suffix}`, `Insights B ${suffix}`]);
  const [companyA, companyB] = companies.rows.map((row) => row.id); assert.ok(companyA && companyB);
  const adminId = await user('Insights Admin', `insights_admin_${suffix}`, companyA, role('admin'));
  const supervisorId = await user('Insights Supervisor', `insights_supervisor_${suffix}`, companyA, role('supervisor'));
  const driverOnline = await user('Driver Online', `insights_online_${suffix}`, companyA, role('chofer'));
  const driverStale = await user('Driver Stale', `insights_stale_${suffix}`, companyA, role('chofer'));
  const driverOffline = await user('Driver Offline', `insights_offline_${suffix}`, companyA, role('chofer'));
  const driverB = await user('Driver Other', `insights_other_${suffix}`, companyB, role('chofer'));
  const superId = await user('Insights Super', `insights_super_${suffix}`, null, role('super_admin'));
  const [adminHeaders, supervisorHeaders, superHeaders] = await Promise.all([session(adminId, 'admin'), session(supervisorId, 'supervisor'), session(superId, 'super')]);
  await client.query('INSERT INTO public.supervisor_choferes (supervisor_usuario_id,chofer_usuario_id) VALUES ($1::uuid,$2::uuid)', [supervisorId, driverOnline]);
  const [locationA, locationB] = (await client.query<{ id: string }>(`INSERT INTO public.locales (empresa_id,nombre,latitud,longitud,radio_metros,activo) VALUES ($1::uuid,$2::text,-25.2,-57.6,100,true),($3::uuid,$4::text,-25.3,-57.7,100,true) RETURNING id`, [companyA, `Location A ${suffix}`, companyB, `Location B ${suffix}`])).rows.map((row) => row.id);
  const [habitualVehicle, activeVehicle] = (await client.query<{ id: string }>(`INSERT INTO public.vehiculos (empresa_id,patente,tipo_vehiculo,activo) VALUES ($1::uuid,$2::text,'moto',true),($1::uuid,$3::text,'camion',true) RETURNING id`, [companyA, `HV-${suffix}`, `AV-${suffix}`])).rows.map((row) => row.id);
  await client.query('SELECT public.fleet_control_set_user_vehicle($1::uuid,$2::uuid)', [driverOnline, habitualVehicle]);
  const description = (await client.query<{ id: string }>(`INSERT INTO public.pedido_descripciones (empresa_id,nombre,activo) VALUES ($1::uuid,$2::text,true) RETURNING id`, [companyA, `Insights ${suffix}`])).rows[0]?.id; assert.ok(description);
  const order = (await client.query<{ id: string }>(`INSERT INTO public.pedidos (empresa_id,local_id,creado_por_usuario_id,descripcion_tipo_id,prioridad,estado) VALUES ($1::uuid,$2::uuid,$3::uuid,$4::uuid,'normal','pendiente') RETURNING id`, [companyA, locationA, adminId, description])).rows[0]?.id; assert.ok(order);
  const management = (await client.query<{ id: string }>('SELECT id FROM public.fleet_control_create_gestion($1::uuid,$2::uuid,$3::uuid,$4::uuid)', [order, driverOnline, activeVehicle, adminId])).rows[0]?.id; assert.ok(management);
  await client.query(`INSERT INTO public.chofer_ubicaciones (empresa_id,chofer_usuario_id,latitud,longitud,captured_at) VALUES ($1::uuid,$2::uuid,-25.2,-57.6,now()),($1::uuid,$3::uuid,-25.2,-57.6,now()-interval '5 minutes'),($1::uuid,$4::uuid,-25.2,-57.6,now()-interval '20 minutes'),($5::uuid,$6::uuid,-25.3,-57.7,now())`, [companyA, driverOnline, driverStale, driverOffline, companyB, driverB]);
  app = await buildApp({ database: client });
  const adminMap = await app.inject({ method: 'GET', url: '/api/fleet/locations', headers: adminHeaders }); assert.equal(adminMap.statusCode, 200);
  const adminDrivers = (adminMap.json() as { drivers: { driver_user_id: string; connection_status: string; vehicle_plate: string | null }[] }).drivers;
  assert.equal(adminDrivers.length, 3, 'Admin must only see its company.');
  assert.equal(adminDrivers.find((driver) => driver.driver_user_id === driverOnline)?.connection_status, 'online');
  assert.equal(adminDrivers.find((driver) => driver.driver_user_id === driverStale)?.connection_status, 'stale');
  assert.equal(adminDrivers.find((driver) => driver.driver_user_id === driverOffline)?.connection_status, 'offline');
  assert.equal(adminDrivers.find((driver) => driver.driver_user_id === driverOnline)?.vehicle_plate, `AV-${suffix}`, 'Active management vehicle must win over habitual vehicle.');
  const supervisorMap = await app.inject({ method: 'GET', url: '/api/fleet/locations', headers: supervisorHeaders }); assert.equal((supervisorMap.json() as { drivers: unknown[] }).drivers.length, 3, 'Supervisor map scope remains company-wide.');
  const superMap = await app.inject({ method: 'GET', url: '/api/fleet/locations', headers: superHeaders }); assert.ok((superMap.json() as { drivers: { driver_user_id: string }[] }).drivers.some((driver) => driver.driver_user_id === driverB), 'Super admin map must include drivers from other companies.');
  const supervisorDrivers = await app.inject({ method: 'GET', url: '/api/reports/drivers', headers: supervisorHeaders }); assert.equal(supervisorDrivers.statusCode, 200); assert.equal((supervisorDrivers.json() as { rows: unknown[] }).rows.length, 1, 'Supervisor reports must only include assigned drivers.');
  const supervisorLocations = await app.inject({ method: 'GET', url: '/api/reports/locations', headers: supervisorHeaders }); assert.equal(supervisorLocations.statusCode, 403);
  const adminDriversReport = await app.inject({ method: 'GET', url: '/api/reports/drivers', headers: adminHeaders }); assert.equal((adminDriversReport.json() as { rows: unknown[] }).rows.length, 3, 'Admin report must be isolated to its company.');
  await client.query('DELETE FROM public.supervisor_choferes WHERE supervisor_usuario_id=$1::uuid', [supervisorId]);
  const noTeam = await app.inject({ method: 'GET', url: '/api/reports/orders', headers: supervisorHeaders }); assert.equal((noTeam.json() as { rows: unknown[] }).rows.length, 0, 'Supervisor without drivers must not fall back to company data.');
  console.log('fleet map and reports integration: passed (transaction will roll back)');
} finally {
  if (app) await app.close();
  if (started) await client.query('ROLLBACK');
  client.release(); await pool.end();
}
