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

  const [roleResult, companyResult] = await Promise.all([
    client.query(`SELECT id FROM public.roles WHERE codigo = 'chofer' AND activo = true LIMIT 1`),
    client.query('SELECT id FROM public.empresas LIMIT 1')
  ]);
  const roleId = roleResult.rows[0]?.id;
  const companyId = companyResult.rows[0]?.id;
  if (typeof roleId !== 'string' || typeof companyId !== 'string') {
    throw new Error('Missing active chofer role or company fixture.');
  }

  const username = `verify_driver_${randomUUID().replaceAll('-', '').slice(0, 18)}`;
  const password = `Test-${randomUUID()}`;
  const created = await client.query<{ id: string }>(
    `SELECT public.fleet_control_create_usuario(
       $1::text, $2::text, $3::text, $4::uuid, $5::uuid, true
     ) AS id`,
    ['Verify Driver', username, password, companyId, roleId]
  );
  const userId = created.rows[0]?.id;
  if (typeof userId !== 'string') throw new Error('Fixture user was not created.');

  app = await buildApp({ database: client });
  const login = await app.inject({
    method: 'POST',
    url: '/api/auth/login',
    payload: { usuario: username, password }
  });
  if (login.statusCode !== 200) throw new Error(`Login failed with ${login.statusCode}.`);

  const sessionToken = (login.json() as { sessionToken?: unknown }).sessionToken;
  if (typeof sessionToken !== 'string') throw new Error('Login did not return a session token.');

  const createdSession = await client.query<{ revoked_at: Date | null }>(
    `SELECT revoked_at
     FROM public.sesiones
     WHERE token_hash = $1::text`,
    [hashSessionToken(sessionToken)]
  );
  if (createdSession.rows.length !== 1 || createdSession.rows[0]?.revoked_at !== null) {
    throw new Error('Login did not create an active PostgreSQL session.');
  }

  const location = await app.inject({
    method: 'POST',
    url: '/api/driver/location',
    headers: { authorization: `Bearer ${sessionToken}` },
    payload: {
      latitude: -25.2867,
      longitude: -57.647,
      accuracy: 5,
      speed: null,
      heading: null,
      captured_at: new Date().toISOString()
    }
  });
  if (location.statusCode !== 200) {
    throw new Error(`Location update failed with ${location.statusCode}.`);
  }

  const response = location.json() as { location?: { driver_user_id?: unknown } };
  if (response.location?.driver_user_id !== userId) {
    throw new Error('RPC response did not belong to the session user.');
  }

  const persisted = await client.query(
    `SELECT chofer_usuario_id
     FROM public.chofer_ubicaciones
     WHERE chofer_usuario_id = $1::uuid`,
    [userId]
  );
  if (persisted.rows.length !== 1) throw new Error('Location was not written by the RPC.');

  const logout = await app.inject({
    method: 'POST',
    url: '/api/auth/logout',
    headers: { authorization: `Bearer ${sessionToken}` }
  });
  if (logout.statusCode !== 200) throw new Error(`Logout failed with ${logout.statusCode}.`);

  const revokedSession = await client.query<{ revoked_at: Date | null }>(
    `SELECT revoked_at
     FROM public.sesiones
     WHERE token_hash = $1::text`,
    [hashSessionToken(sessionToken)]
  );
  if (revokedSession.rows[0]?.revoked_at === null || !revokedSession.rows[0]?.revoked_at) {
    throw new Error('Logout did not revoke the PostgreSQL session.');
  }

  console.log('auth and driver-location integration: passed (transaction will roll back)');
} finally {
  if (app) await app.close();
  if (transactionStarted) await client.query('ROLLBACK');
  client.release();
  await pool.end();
}
