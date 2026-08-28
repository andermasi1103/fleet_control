import assert from 'node:assert/strict';
import { randomUUID } from 'node:crypto';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

import type { PoolClient } from 'pg';

import { pool } from '../src/db/pool.js';

type ManagementRow = {
  id: string;
  queue_position: number | null;
  estado: string;
};

async function createUser(
  client: PoolClient,
  name: string,
  username: string,
  companyId: string,
  roleId: string,
): Promise<string> {
  const result = await client.query<{ id: string }>(
    `SELECT public.fleet_control_create_usuario(
       $1::text, $2::text, $3::text, $4::uuid, $5::uuid, true
     ) AS id`,
    [name, username, `test-${randomUUID()}`, companyId, roleId],
  );
  assert.ok(result.rows[0]?.id, 'Fixture user was not created.');
  return result.rows[0].id;
}

async function createOrder(
  client: PoolClient,
  companyId: string,
  locationId: string,
  creatorId: string,
): Promise<string> {
  const result = await client.query<{ id: string }>(
    `INSERT INTO public.pedidos (
       empresa_id, local_id, creado_por_usuario_id, prioridad, estado
     ) VALUES ($1::uuid, $2::uuid, $3::uuid, 'normal', 'pendiente')
     RETURNING id`,
    [companyId, locationId, creatorId],
  );
  assert.ok(result.rows[0]?.id, 'Fixture order was not created.');
  return result.rows[0].id;
}

async function createManagement(
  client: PoolClient,
  orderId: string,
  driverId: string,
  vehicleId: string,
  assignedById: string,
): Promise<ManagementRow> {
  const result = await client.query<ManagementRow>(
    `SELECT id, queue_position, estado
     FROM public.fleet_control_create_gestion(
       $1::uuid, $2::uuid, $3::uuid, $4::uuid
     )`,
    [orderId, driverId, vehicleId, assignedById],
  );
  assert.equal(result.rowCount, 1, 'Management creation did not return one row.');
  return result.rows[0];
}

async function updateStatus(
  client: PoolClient,
  managementId: string,
  status: string,
  driverId: string,
): Promise<void> {
  await client.query(
    `SELECT id FROM public.fleet_control_update_gestion_status(
       $1::uuid, $2::text, $3::uuid
     )`,
    [managementId, status, driverId],
  );
}

async function expectDatabaseError(
  client: PoolClient,
  operation: () => Promise<unknown>,
  code: string,
): Promise<void> {
  await client.query('SAVEPOINT expected_database_error');
  try {
    await assert.rejects(operation, (error: unknown) =>
      error instanceof Error && error.message.includes(code),
    );
  } finally {
    await client.query('ROLLBACK TO SAVEPOINT expected_database_error');
    await client.query('RELEASE SAVEPOINT expected_database_error');
  }
}

async function verifyQueueMigration(client: PoolClient): Promise<void> {
  const functionResult = await client.query<{ definition: string }>(
    `SELECT pg_get_functiondef(p.oid) AS definition
     FROM pg_catalog.pg_proc p
     JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
     WHERE n.nspname = 'public'
       AND p.proname = 'fleet_control_create_gestion'`,
  );
  const definition = functionResult.rows[0]?.definition ?? '';
  assert.match(definition, /queue_position/);
  assert.match(definition, /for update/);
  assert.doesNotMatch(definition, /driver_busy/);

  const indexResult = await client.query<{ found: boolean }>(
    `SELECT EXISTS (
       SELECT 1 FROM pg_catalog.pg_indexes
       WHERE schemaname = 'public'
         AND indexname = 'gestiones_chofer_queue_position_unique'
     ) AS found`,
  );
  assert.equal(indexResult.rows[0]?.found, true, 'Queue uniqueness index is missing.');
}

async function run(): Promise<void> {
  const client = await pool.connect();
  let started = false;

  try {
    await client.query('BEGIN');
    started = true;
    if (process.argv.includes('--apply-migration')) {
      const migration = await readFile(
        resolve(process.cwd(), '../database/migrations/002_fix_management_queue.sql'),
        'utf8',
      );
      const definition = migration
        .replace(/^\s*begin;\s*/i, '')
        .replace(/\s*commit;\s*$/i, '');
      await client.query(definition);
    }
    await verifyQueueMigration(client);

    const fixtures = await client.query<{
      company_id: string;
      admin_role_id: string;
      driver_role_id: string;
    }>(
      `SELECT
         (SELECT id FROM public.empresas WHERE activo = true LIMIT 1) AS company_id,
         (SELECT id FROM public.roles WHERE codigo = 'admin' AND activo = true LIMIT 1) AS admin_role_id,
         (SELECT id FROM public.roles WHERE codigo = 'chofer' AND activo = true LIMIT 1) AS driver_role_id`,
    );
    const fixture = fixtures.rows[0];
    assert.ok(
      fixture?.company_id && fixture.admin_role_id && fixture.driver_role_id,
      'Missing company or active role fixtures.',
    );

    const suffix = randomUUID().replaceAll('-', '').slice(0, 12);
    const adminId = await createUser(
      client,
      'Queue Admin',
      `queue_admin_${suffix}`,
      fixture.company_id,
      fixture.admin_role_id,
    );
    const driverId = await createUser(
      client,
      'Queue Driver',
      `queue_driver_${suffix}`,
      fixture.company_id,
      fixture.driver_role_id,
    );
    const secondDriverId = await createUser(
      client,
      'Queue Driver Two',
      `queue_driver_two_${suffix}`,
      fixture.company_id,
      fixture.driver_role_id,
    );

    const location = await client.query<{ id: string }>(
      `INSERT INTO public.locales (
         empresa_id, nombre, latitud, longitud, radio_metros, activo
       ) VALUES ($1::uuid, $2::text, -25.2867, -57.647, 100, true)
       RETURNING id`,
      [fixture.company_id, `Queue Location ${suffix}`],
    );
    const locationId = location.rows[0]?.id;
    assert.ok(locationId, 'Fixture location was not created.');

    const vehicles = await client.query<{ id: string }>(
      `INSERT INTO public.vehiculos (empresa_id, patente, activo)
       VALUES
         ($1::uuid, $2::text, true),
         ($1::uuid, $3::text, true)
       RETURNING id`,
      [fixture.company_id, `QM-${suffix}-1`, `QM-${suffix}-2`],
    );
    const [vehicleId, secondVehicleId] = vehicles.rows.map((row) => row.id);
    assert.ok(vehicleId && secondVehicleId, 'Fixture vehicles were not created.');

    const orders: string[] = [];
    for (var index = 0; index < 7; index += 1) {
      orders.push(
        await createOrder(client, fixture.company_id, locationId, adminId),
      );
    }

    const first = await createManagement(client, orders[0], driverId, vehicleId, adminId);
    const second = await createManagement(client, orders[1], driverId, vehicleId, adminId);
    const third = await createManagement(client, orders[2], driverId, vehicleId, adminId);
    assert.deepEqual(
      [first.queue_position, second.queue_position, third.queue_position],
      [1, 2, 3],
    );

    await updateStatus(client, first.id, 'aceptado', driverId);
    const fourth = await createManagement(client, orders[3], driverId, vehicleId, adminId);
    assert.equal(fourth.queue_position, 4, 'Queued work must be appended behind active work.');
    await expectDatabaseError(
      client,
      () => updateStatus(client, second.id, 'aceptado', driverId),
      'active_management_exists',
    );

    await updateStatus(client, first.id, 'en_camino', driverId);
    await updateStatus(client, first.id, 'en_gestion', driverId);
    await updateStatus(client, first.id, 'completado', driverId);
    const compacted = await client.query<{ id: string; queue_position: number }>(
      `SELECT id, queue_position
       FROM public.gestiones
       WHERE id = ANY($1::uuid[])
       ORDER BY queue_position`,
      [[second.id, third.id, fourth.id]],
    );
    assert.deepEqual(
      compacted.rows.map((row) => row.queue_position),
      [1, 2, 3],
      'Completing active work must compact the remaining queue.',
    );

    await expectDatabaseError(
      client,
      () => createManagement(client, orders[1], driverId, vehicleId, adminId),
      'active_management',
    );

    const otherDriverManagement = await createManagement(
      client,
      orders[4],
      secondDriverId,
      secondVehicleId,
      adminId,
    );
    await updateStatus(client, otherDriverManagement.id, 'aceptado', secondDriverId);
    await expectDatabaseError(
      client,
      () => createManagement(client, orders[5], driverId, secondVehicleId, adminId),
      'vehicle_busy',
    );

    console.log('management queue integration: passed (transaction will roll back)');
  } finally {
    if (started) await client.query('ROLLBACK');
    client.release();
    await pool.end();
  }
}

await run();
