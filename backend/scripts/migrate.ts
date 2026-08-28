import { createHash } from 'node:crypto';
import { readdir, readFile } from 'node:fs/promises';
import { resolve } from 'node:path';

import { pool } from '../src/db/pool.js';

const dryRun = process.argv.includes('--dry-run');
const migrationsDirectory = resolve(
  process.env.MIGRATIONS_DIR ?? resolve(process.cwd(), '../database/migrations')
);

type AppliedMigration = { name: string; checksum: string };

async function main(): Promise<void> {
  const files = (await readdir(migrationsDirectory))
    .filter((file) => /^\d+_.+\.sql$/.test(file))
    .sort();

  const client = await pool.connect();
  try {
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
  } finally {
    client.release();
    await pool.end();
  }
}

await main();
