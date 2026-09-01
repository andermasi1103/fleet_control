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
type PgcryptoCheck = {
  crypt_exists: boolean;
  gen_salt_exists: boolean;
  gen_salt_rounds_exists: boolean;
  fleet_owner_can_execute: boolean;
};
type ApplicationSecurityDefinerCheck = {
  all_found: boolean;
  all_owned_by_fleet_owner: boolean;
  all_security_definer: boolean;
  all_have_safe_search_path: boolean;
  public_execute_revoked: boolean;
  fleet_app_can_execute: boolean;
};

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
    const pgcryptoInPublic = extension?.schema_name === 'public';
    const pgcryptoFunctionsResult = await connectedClient.query<PgcryptoCheck>(
      `SELECT
         to_regprocedure('public.crypt(text,text)') IS NOT NULL AS crypt_exists,
         to_regprocedure('public.gen_salt(text)') IS NOT NULL AS gen_salt_exists,
         to_regprocedure('public.gen_salt(text,integer)') IS NOT NULL AS gen_salt_rounds_exists,
         has_function_privilege('fleet_owner', 'public.crypt(text,text)', 'EXECUTE')
           AND has_function_privilege('fleet_owner', 'public.gen_salt(text)', 'EXECUTE')
           AND has_function_privilege('fleet_owner', 'public.gen_salt(text,integer)', 'EXECUTE')
           AS fleet_owner_can_execute`
    );
    const pgcryptoFunctions = pgcryptoFunctionsResult.rows[0];
    console.log('\nExtensions');
    console.log(extension ? `  pgcrypto: found in schema ${extension.schema_name}` : '  pgcrypto: missing');
    console.log(`  pgcrypto location: ${pgcryptoInPublic ? 'public (expected)' : 'unexpected'}`);
    console.log(`  pgcrypto password helpers: ${pgcryptoFunctions?.crypt_exists && pgcryptoFunctions.gen_salt_exists && pgcryptoFunctions.gen_salt_rounds_exists ? 'found' : 'missing'}`);
    console.log(`  fleet_owner effective pgcrypto EXECUTE: ${pgcryptoFunctions?.fleet_owner_can_execute ? 'available' : 'missing'}`);

    const securityDefinerResult = await connectedClient.query<ApplicationSecurityDefinerCheck>(
      `WITH required(identity) AS (
         VALUES
           ('login_usuario(text, text)'),
           ('fleet_control_verify_usuario_password(uuid, text)'),
           ('fleet_control_set_usuario_password(uuid, text)'),
           ('fleet_control_create_usuario(text, text, text, uuid, uuid, boolean)')
       ), functions AS (
         SELECT required.identity, p.oid, p.proowner, p.prosecdef, p.proconfig, p.proacl
         FROM required
         LEFT JOIN pg_catalog.pg_proc p
           ON p.oid = to_regprocedure(format('public.%s', required.identity))
       )
       SELECT
         bool_and(functions.oid IS NOT NULL) AS all_found,
         bool_and(owner_role.rolname = 'fleet_owner') AS all_owned_by_fleet_owner,
         bool_and(prosecdef) AS all_security_definer,
         bool_and(coalesce(proconfig, ARRAY[]::text[]) @> ARRAY['search_path=public']) AS all_have_safe_search_path,
         bool_and(NOT EXISTS (
           SELECT 1
           FROM aclexplode(coalesce(proacl, acldefault('f', proowner))) acl
           WHERE acl.grantee = 0 AND acl.privilege_type = 'EXECUTE'
         )) AS public_execute_revoked,
         bool_and(has_function_privilege('fleet_app', functions.oid, 'EXECUTE')) AS fleet_app_can_execute
       FROM functions
       LEFT JOIN pg_catalog.pg_roles owner_role ON owner_role.oid = functions.proowner`
    );
    const securityDefiner = securityDefinerResult.rows[0];
    const securityDefinerHardened = securityDefiner?.all_found
      && securityDefiner.all_owned_by_fleet_owner
      && securityDefiner.all_security_definer
      && securityDefiner.all_have_safe_search_path
      && securityDefiner.public_execute_revoked
      && securityDefiner.fleet_app_can_execute;
    console.log('\nApplication password functions');
    console.log(`  SECURITY DEFINER hardening: ${securityDefinerHardened ? 'verified' : 'incomplete'}`);

    await connectedClient.query('COMMIT');

    if (missingTables.length || missingFunctions.length || !queue?.function_aligned || !queue?.index_found || !notificationIndexFound || !loginSignatureFound || !pgcryptoInPublic || !pgcryptoFunctions?.crypt_exists || !pgcryptoFunctions.gen_salt_exists || !pgcryptoFunctions.gen_salt_rounds_exists || !pgcryptoFunctions.fleet_owner_can_execute || !securityDefinerHardened) {
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
