import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

import { Client } from 'pg';

type Mode = 'seed' | 'cleanup' | 'rls';

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing required local environment variable: ${name}`);
  return value;
}

function modeFromArgs(): Mode {
  const value = process.argv[2];
  if (value === 'seed' || value === 'cleanup' || value === 'rls') return value;
  throw new Error('Use "seed", "cleanup", or "rls".');
}

async function main(): Promise<void> {
  const mode = modeFromArgs();
  const client = new Client({
    host: required('UAT_MIGRATOR_HOST'),
    port: Number(process.env.UAT_MIGRATOR_PORT ?? '5432'),
    database: required('UAT_MIGRATOR_DATABASE'),
    user: required('UAT_MIGRATOR_USER'),
    password: required('UAT_MIGRATOR_PASSWORD')
  });
  const password = mode === 'seed' ? required('UAT_FIXTURE_PASSWORD') : null;
  const fixturePath = mode === 'rls'
    ? resolve(process.cwd(), '../database/security/fleet_app_rls.sql')
    : resolve(process.cwd(), `../database/fixtures/uat${mode === 'cleanup' ? '_cleanup' : ''}.sql`);
  const sql = await readFile(fixturePath, 'utf8');

  await client.connect();
  try {
    const identity = await client.query<{ session_user: string }>('SELECT session_user');
    if (identity.rows[0]?.session_user !== 'fleet_migrator') {
      throw new Error('UAT fixture runner requires the fleet_migrator identity.');
    }

    await client.query('BEGIN');
    await client.query('SET LOCAL ROLE fleet_owner');
    const role = await client.query<{ current_user: string }>('SELECT current_user');
    if (role.rows[0]?.current_user !== 'fleet_owner') {
      throw new Error('fleet_migrator cannot assume fleet_owner.');
    }
    if (password) {
      await client.query(
        "SELECT set_config('fleet_control.uat_password', $1::text, true)",
        [password]
      );
    }
    await client.query(sql);
    await client.query('COMMIT');
    console.log(mode === 'rls' ? 'fleet_app RLS policy setup completed.' : `UAT fixture ${mode} completed.`);
  } catch {
    await client.query('ROLLBACK').catch(() => undefined);
    throw new Error(`UAT fixture ${mode} failed. Review only local configuration and database permissions.`);
  } finally {
    await client.end();
  }
}

await main();
