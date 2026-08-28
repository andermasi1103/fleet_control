import { pool } from '../src/db/pool.js';
import type { PoolClient } from 'pg';

const requiredTables = [
  'roles',
  'empresas',
  'locales',
  'usuarios',
  'sesiones',
  'asistencias',
  'vehiculos',
  'usuario_locales',
  'usuario_vehiculos',
  'supervisor_choferes',
  'pedido_descripciones',
  'pedidos',
  'gestiones',
  'gestion_eventos',
  'chofer_ubicaciones',
  'app_views',
  'role_views',
  'notification_devices',
  'notificaciones'
] as const;

const requiredFunctions = [
  'login_usuario',
  'fleet_control_create_usuario',
  'fleet_control_set_usuario_password',
  'fleet_control_verify_usuario_password',
  'fleet_control_set_user_locations',
  'fleet_control_set_user_vehicle',
  'fleet_control_import_locations',
  'fleet_control_create_gestion',
  'fleet_control_driver_claim_order',
  'fleet_control_update_gestion_status',
  'fleet_control_update_driver_location',
  'fleet_control_set_supervisor_choferes'
] as const;

type TableRow = { schemaname: string; tablename: string };
type FunctionRow = { schema_name: string; function_name: string; signature: string; identity_arguments: string };

function report(label: string, found: string[], missing: readonly string[]): void {
  console.log(`\n${label}`);
  for (const entry of found) console.log(`  found: ${entry}`);
  for (const entry of missing) console.log(`  missing: ${entry}`);
}

async function checkDatabase(): Promise<void> {
  let client: PoolClient | undefined;

  try {
    const connectedClient = await pool.connect();
    client = connectedClient;
    // Guardrail: every query in this script runs in an explicitly read-only transaction.
    await connectedClient.query('BEGIN READ ONLY');

    const tablesResult = await connectedClient.query<TableRow>(
      `SELECT schemaname, tablename
       FROM pg_catalog.pg_tables
       WHERE tablename = ANY($1::text[])
       ORDER BY tablename, schemaname`,
      [requiredTables]
    );
    const tablesByName = new Map<string, string>();
    for (const row of tablesResult.rows) tablesByName.set(row.tablename, row.schemaname);
    const missingTables = requiredTables.filter((table) => !tablesByName.has(table));
    report('Tables', requiredTables.filter((table) => tablesByName.has(table)).map((table) => `${tablesByName.get(table)}.${table}`), missingTables);

    const functionsResult = await connectedClient.query<FunctionRow>(
      `SELECT n.nspname AS schema_name,
              p.proname AS function_name,
              n.nspname || '.' || p.proname || '(' || pg_get_function_identity_arguments(p.oid) || ')' AS signature,
              pg_get_function_identity_arguments(p.oid) AS identity_arguments
       FROM pg_catalog.pg_proc p
       JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
       WHERE p.proname = ANY($1::text[])
       ORDER BY p.proname, n.nspname, pg_get_function_identity_arguments(p.oid)`,
      [requiredFunctions]
    );
    const functionsByName = new Map<string, FunctionRow[]>();
    for (const row of functionsResult.rows) {
      functionsByName.set(row.function_name, [...(functionsByName.get(row.function_name) ?? []), row]);
    }
    const missingFunctions = requiredFunctions.filter((name) => !functionsByName.has(name));
    const functionSignatures = functionsResult.rows.map((row) => row.signature);
    report('Functions', functionSignatures, missingFunctions);

    const queueResult = await connectedClient.query<{ function_aligned: boolean; index_found: boolean }>(
      `SELECT
         EXISTS (
           SELECT 1
           FROM pg_catalog.pg_proc p
           JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
           WHERE n.nspname = 'public'
             AND p.proname = 'fleet_control_create_gestion'
             AND pg_get_functiondef(p.oid) ILIKE '%queue_position%'
             AND pg_get_functiondef(p.oid) ILIKE '%for update%'
             AND pg_get_functiondef(p.oid) NOT ILIKE '%driver_busy%'
         ) AS function_aligned,
         EXISTS (
           SELECT 1
           FROM pg_catalog.pg_indexes
           WHERE schemaname = 'public'
             AND indexname = 'gestiones_chofer_queue_position_unique'
         ) AS index_found`,
    );
    const queue = queueResult.rows[0];
    console.log(`  management queue create function: ${queue?.function_aligned ? 'aligned' : 'not aligned'}`);
    console.log(`  management queue unique index: ${queue?.index_found ? 'found' : 'missing'}`);

    const notificationIndex = await connectedClient.query<{ found: boolean }>(
      `SELECT EXISTS (
         SELECT 1 FROM pg_catalog.pg_indexes
         WHERE schemaname='public'
           AND indexname='notificaciones_new_order_pedido_usuario_unique'
       ) AS found`
    );
    const notificationIndexFound = notificationIndex.rows[0]?.found === true;
    console.log(`  new_order notification unique index: ${notificationIndexFound ? 'found' : 'missing'}`);

    const loginFunctionResult = await connectedClient.query<{ found: boolean }>(
      `SELECT EXISTS (
         SELECT 1
         FROM pg_catalog.pg_proc p
         JOIN pg_catalog.pg_namespace n ON n.oid = p.pronamespace
         WHERE n.nspname = 'public'
           AND p.proname = 'login_usuario'
           AND p.pronargs = 2
           AND p.proargtypes[0] = 'text'::regtype::oid
           AND p.proargtypes[1] = 'text'::regtype::oid
       ) AS found`
    );
    // pg_get_function_identity_arguments() includes parameter names (for example,
    // "p_usuario text"), so it is suitable for reporting but not exact matching.
    const loginSignatureFound = loginFunctionResult.rows[0]?.found === true;
    console.log(`  login_usuario(text,text): ${loginSignatureFound ? 'found' : 'missing'}`);

    const extensionResult = await connectedClient.query<{ extname: string; schema_name: string }>(
      `SELECT e.extname, n.nspname AS schema_name
       FROM pg_catalog.pg_extension e
       JOIN pg_catalog.pg_namespace n ON n.oid = e.extnamespace
       WHERE e.extname = 'pgcrypto'`
    );
    const extension = extensionResult.rows[0];
    const pgcryptoInExtensions = extension?.schema_name === 'extensions';
    console.log('\nExtensions');
    console.log(extension ? `  pgcrypto: found in schema ${extension.schema_name}` : '  pgcrypto: missing');

    const schemaResult = await connectedClient.query<{ nspname: string }>(
      `SELECT nspname FROM pg_catalog.pg_namespace WHERE nspname = 'extensions'`
    );
    console.log(`  extensions schema: ${schemaResult.rowCount ? 'found' : 'missing'}`);

    await connectedClient.query('COMMIT');

    if (missingTables.length || missingFunctions.length || !queue?.function_aligned || !queue?.index_found || !notificationIndexFound || !loginSignatureFound || !pgcryptoInExtensions || !schemaResult.rowCount) {
      process.exitCode = 1;
    }
  } catch (error) {
    // Intentionally avoid printing database connection details or query payloads.
    const databaseError = error as { name?: string; code?: string };
    console.error(`Database check failed (${databaseError.name ?? 'Error'}${databaseError.code ? `: ${databaseError.code}` : ''}).`);
    process.exitCode = 1;
  } finally {
    client?.release();
    await pool.end();
  }
}

await checkDatabase();
