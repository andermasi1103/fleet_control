import { randomUUID } from 'node:crypto';

import { buildApp } from '../src/app.js';
import { hashSessionToken } from '../src/auth/auth.service.js';
import { pool } from '../src/db/pool.js';

const client = await pool.connect();
let app: Awaited<ReturnType<typeof buildApp>> | undefined;
let transactionStarted = false;

try {
  await client.query('BEGIN');
  transactionStarted = true;

  const fixtures = await client.query<{ company_id: string; admin_role_id: string; chofer_role_id: string }>(
    `SELECT (SELECT id FROM public.empresas WHERE activo = true LIMIT 1) AS company_id,
            (SELECT id FROM public.roles WHERE codigo = 'admin' AND activo = true LIMIT 1) AS admin_role_id,
            (SELECT id FROM public.roles WHERE codigo = 'chofer' AND activo = true LIMIT 1) AS chofer_role_id`
  );
  const fixture = fixtures.rows[0];
  if (!fixture?.company_id || !fixture.admin_role_id || !fixture.chofer_role_id) throw new Error('Missing company or active role fixtures.');

  const suffix = randomUUID().replaceAll('-', '').slice(0, 16);
  const createUser = async (nombre: string, usuario: string, roleId: string) => {
    const result = await client.query<{ id: string }>(
      'SELECT public.fleet_control_create_usuario($1::text,$2::text,$3::text,$4::uuid,$5::uuid,true) AS id',
      [nombre, usuario, `Test-${randomUUID()}`, fixture.company_id, roleId]
    );
    const id = result.rows[0]?.id;
    if (!id) throw new Error('Fixture user was not created.');
    return id;
  };
  const adminId = await createUser('Verify Administration', `verify_admin_${suffix}`, fixture.admin_role_id);
  const driverId = await createUser('Verify Driver', `verify_chofer_${suffix}`, fixture.chofer_role_id);
  const token = `admin_${randomUUID().replaceAll('-', '')}`;
  await client.query(
    'INSERT INTO public.sesiones (usuario_id,token_hash,expires_at) VALUES ($1::uuid,$2::text,now() + interval \'1 hour\')',
    [adminId, hashSessionToken(token)]
  );

  app = await buildApp({ database: client });
  const headers = { authorization: `Bearer ${token}` };
  const createdLocation = await app.inject({ method: 'POST', url: '/api/locations', headers, payload: { empresa_id: fixture.company_id, nombre: `Verify Location ${suffix}`, latitud: -25.2867, longitud: -57.647 } });
  if (createdLocation.statusCode !== 201) throw new Error(`Location creation failed with ${createdLocation.statusCode}.`);
  const locationId = (createdLocation.json() as { location?: { id?: string } }).location?.id;
  if (!locationId) throw new Error('Location did not return an id.');
  const importedLocation = await app.inject({ method: 'POST', url: '/api/locations/import', headers, payload: {
    locations: [{ codigo: `IMP${suffix.slice(0, 8)}`, nombre: `Imported ${suffix}`, latitud: -25.287, longitud: -57.648, radio_geocerca_metros: 100 }]
  } });
  if (importedLocation.statusCode !== 201) throw new Error(`Location import failed with ${importedLocation.statusCode}.`);
  const assignment = await app.inject({ method: 'PUT', url: `/api/users/${driverId}/locations`, headers, payload: { location_ids: [locationId] } });
  if (assignment.statusCode !== 200) throw new Error(`Location assignment failed with ${assignment.statusCode}.`);
  const createdVehicle = await app.inject({ method: 'POST', url: '/api/vehicles', headers, payload: { empresa_id: fixture.company_id, patente: `V${suffix.slice(0, 10)}`, tipo_vehiculo: 'auto' } });
  if (createdVehicle.statusCode !== 201) throw new Error(`Vehicle creation failed with ${createdVehicle.statusCode}.`);
  const vehicleId = (createdVehicle.json() as { vehicle?: { id?: string } }).vehicle?.id;
  if (!vehicleId) throw new Error('Vehicle did not return an id.');
  const vehicleAssignment = await app.inject({ method: 'PATCH', url: `/api/users/${driverId}/vehicle`, headers, payload: { vehicle_id: vehicleId } });
  if (vehicleAssignment.statusCode !== 200) throw new Error(`Vehicle assignment failed with ${vehicleAssignment.statusCode}.`);
  if ((vehicleAssignment.json() as { user_vehicle?: { vehiculo_id?: string } | null }).user_vehicle?.vehiculo_id !== vehicleId) {
    throw new Error('Vehicle assignment did not return the assigned vehicle.');
  }
  const assignedVehicle = await app.inject({ method: 'GET', url: `/api/users/${driverId}/vehicle`, headers });
  if (assignedVehicle.statusCode !== 200) throw new Error(`Vehicle lookup failed with ${assignedVehicle.statusCode}.`);
  if ((assignedVehicle.json() as { user_vehicle?: { vehiculo_id?: string } | null }).user_vehicle?.vehiculo_id !== vehicleId) {
    throw new Error('Vehicle lookup did not persist the assigned vehicle.');
  }
  const nonDriverAssignment = await app.inject({ method: 'PATCH', url: `/api/users/${adminId}/vehicle`, headers, payload: { vehicle_id: vehicleId } });
  if (nonDriverAssignment.statusCode !== 404) throw new Error(`Non-driver vehicle assignment must return 404, got ${nonDriverAssignment.statusCode}.`);
  const unknownDriverAssignment = await app.inject({ method: 'PATCH', url: '/api/users/00000000-0000-0000-0000-000000000000/vehicle', headers, payload: { vehicle_id: vehicleId } });
  if (unknownDriverAssignment.statusCode !== 404) throw new Error(`Unknown driver vehicle assignment must return 404, got ${unknownDriverAssignment.statusCode}.`);
  const otherCompany = await client.query<{ id: string }>(
    'INSERT INTO public.empresas (nombre, activo) VALUES ($1::text, true) RETURNING id',
    [`Other Company ${suffix}`]
  );
  const otherCompanyId = otherCompany.rows[0]?.id;
  if (!otherCompanyId) throw new Error('Other company fixture was not created.');
  const otherVehicle = await client.query<{ id: string }>(
    'INSERT INTO public.vehiculos (empresa_id, patente, activo) VALUES ($1::uuid, $2::text, true) RETURNING id',
    [otherCompanyId, `O${suffix.slice(0, 10)}`]
  );
  const otherVehicleId = otherVehicle.rows[0]?.id;
  if (!otherVehicleId) throw new Error('Other company vehicle fixture was not created.');
  const crossCompanyVehicle = await app.inject({ method: 'PATCH', url: `/api/users/${driverId}/vehicle`, headers, payload: { vehicle_id: otherVehicleId } });
  if (crossCompanyVehicle.statusCode !== 400) throw new Error(`Cross-company vehicle assignment must return 400, got ${crossCompanyVehicle.statusCode}.`);
  const unauthorized = await app.inject({ method: 'GET', url: '/api/role-views', headers });
  if (unauthorized.statusCode !== 403) throw new Error(`Role-view isolation failed with ${unauthorized.statusCode}.`);
  console.log('administration integration: passed (transaction will roll back)');
} finally {
  if (app) await app.close();
  if (transactionStarted) await client.query('ROLLBACK');
  client.release();
  await pool.end();
}
