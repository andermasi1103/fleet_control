import { createHash } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

import { Client } from 'pg';

const dryRun = process.argv.includes('--dry-run');
const migrationsDirectory = resolve(
  process.env.MIGRATIONS_DIR ?? resolve(process.cwd(), '../database/migrations')
);

type AppliedMigration = { name: string; checksum: string };
type DatabaseIdentity = { session_user: string; current_user: string };

function requiredMigrationEnvironmentVariable(name: string): string {
  const value = process.env[name]?.trim();
  if (!value) {
    throw new Error(`Missing required migration environment variable: ${name}`);
  }
  return value;
}

function migrationDatabasePort(): number {
  const value = process.env.MIGRATION_DATABASE_PORT?.trim();
  if (!value) return 5432;

  const port = Number(value);
  if (!Number.isInteger(port) || port < 1 || port > 65_535) {
    throw new Error('Invalid migration environment variable: MIGRATION_DATABASE_PORT');
  }
  return port;
}

function migrationDatabaseBoolean(name: string, fallback: boolean): boolean {
  const value = process.env[name]?.trim();
  if (!value) return fallback;
  if (value === 'true') return true;
  if (value === 'false') return false;
  throw new Error(`Invalid migration environment variable: ${name}`);
}

function migrationDatabaseSsl() {
  if (!migrationDatabaseBoolean('MIGRATION_DATABASE_SSL', false)) {
    return undefined;
  }

  return {
    rejectUnauthorized: migrationDatabaseBoolean(
      'MIGRATION_DATABASE_SSL_REJECT_UNAUTHORIZED',
      true
    ),
    ca: process.env.MIGRATION_DATABASE_SSL_CA?.trim() || undefined
  };
}

async function main(): Promise<void> {
  const files = (await readdir(migrationsDirectory))
    .filter((file) => /^\d+_.+\.sql$/.test(file))
    .sort();

  const user = requiredMigrationEnvironmentVariable('MIGRATION_DATABASE_USER');
  if (user !== 'fleet_migrator') {
    throw new Error('MIGRATION_DATABASE_USER must be fleet_migrator.');
  }

  const client = new Client({
    host: requiredMigrationEnvironmentVariable('MIGRATION_DATABASE_HOST'),
    port: migrationDatabasePort(),
    database: requiredMigrationEnvironmentVariable('MIGRATION_DATABASE_NAME'),
    user,
    password: requiredMigrationEnvironmentVariable('MIGRATION_DATABASE_PASSWORD'),
    ssl: migrationDatabaseSsl()
  });
  let ownerRoleAssumed = false;
  let migrationError: unknown;
  try {
    await client.connect();

    const connectionIdentity = await client.query<DatabaseIdentity>(
      'SELECT session_user, current_user'
    );
    if (
      connectionIdentity.rows[0]?.session_user !== 'fleet_migrator' ||
      connectionIdentity.rows[0]?.current_user !== 'fleet_migrator'
    ) {
      throw new Error('Migration runner requires the fleet_migrator identity.');
    }

    await client.query('SET ROLE fleet_owner');
    ownerRoleAssumed = true;

    const migrationIdentity = await client.query<DatabaseIdentity>(
      'SELECT session_user, current_user'
    );
    if (
      migrationIdentity.rows[0]?.session_user !== 'fleet_migrator' ||
      migrationIdentity.rows[0]?.current_user !== 'fleet_owner'
    ) {
      throw new Error('fleet_migrator cannot assume fleet_owner.');
    }

    await client.query(
      `CREATE TABLE IF NOT EXISTS public.schema_migrations (
         name text PRIMARY KEY,
         checksum text NOT NULL,
         applied_at timestamptz NOT NULL DEFAULT now()
       )`
    );
    const applied = await client.query<AppliedMigration>(
      'SELECT name, checksum FROM public.schema_migrations ORDER BY name'
    );
    const byName = new Map(applied.rows.map((migration) => [migration.name, migration.checksum]));

    for (const name of files) {
      const sql = await readFile(resolve(migrationsDirectory, name), 'utf8');
      const checksum = createHash('sha256').update(sql).digest('hex');
      const recordedChecksum = byName.get(name);
      if (recordedChecksum && recordedChecksum !== checksum) {
        throw new Error(`Migration checksum mismatch for ${name}. Create a new migration instead of editing it.`);
      }
      if (recordedChecksum) continue;

      if (dryRun) {
        console.log(`Would apply ${name}`);
        continue;
      }

      await client.query('BEGIN');
      try {
        await client.query(sql);
        await client.query(
          'INSERT INTO public.schema_migrations (name, checksum) VALUES ($1::text, $2::text)',
          [name, checksum]
        );
        await client.query('COMMIT');
        console.log(`Applied ${name}`);
      } catch (error) {
        await client.query('ROLLBACK');
        throw error;
      }
    }
  } catch (error) {
    migrationError = error;
    throw error;
  } finally {
    try {
      if (ownerRoleAssumed) {
        await client.query('RESET ROLE');
      }
    } catch (resetError) {
      if (!migrationError) throw resetError;
      console.error('Failed to reset the migration database role.', resetError);
    } finally {
      try {
        await client.end();
      } catch (endError) {
        if (!migrationError) throw endError;
        console.error('Failed to close the migration database connection.', endError);
      }
    }
  }
}

await main();
