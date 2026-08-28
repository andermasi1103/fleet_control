-- Consultas de inventario: sólo lectura. Ejecutar contra PostgreSQL remoto
-- con un usuario autorizado para leer pg_catalog e information_schema.

select version() as postgresql_version;

select extname, extversion
from pg_extension
order by extname;

select table_schema, table_name, table_type
from information_schema.tables
where table_schema = 'public'
order by table_name;

select table_schema, table_name, column_name, ordinal_position,
       data_type, udt_name, is_nullable, column_default
from information_schema.columns
where table_schema = 'public'
order by table_name, ordinal_position;

select con.conname, con.contype, rel.relname as table_name,
       pg_get_constraintdef(con.oid, true) as definition
from pg_constraint con
join pg_class rel on rel.oid = con.conrelid
join pg_namespace nsp on nsp.oid = rel.relnamespace
where nsp.nspname = 'public'
order by rel.relname, con.conname;

select schemaname, tablename, indexname, indexdef
from pg_indexes
where schemaname = 'public'
order by tablename, indexname;

select n.nspname as schema_name, c.relname as table_name,
       c.relrowsecurity as rls_enabled, c.relforcerowsecurity as rls_forced
from pg_class c
join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relkind in ('r', 'p')
order by c.relname;

select schemaname, tablename, policyname, permissive, roles, cmd, qual,
       with_check
from pg_policies
where schemaname = 'public'
order by tablename, policyname;

select table_schema, table_name, grantee, privilege_type
from information_schema.role_table_grants
where table_schema = 'public'
order by table_name, grantee, privilege_type;

select n.nspname as schema_name, p.proname,
       pg_get_function_identity_arguments(p.oid) as identity_arguments,
       p.prosecdef as security_definer,
       p.proconfig as function_config,
       pg_get_userbyid(p.proowner) as owner,
       pg_get_functiondef(p.oid) as definition
from pg_proc p
join pg_namespace n on n.oid = p.pronamespace
where n.nspname = 'public'
order by p.proname, identity_arguments;

select event_object_schema, event_object_table, trigger_name,
       action_timing, event_manipulation, action_statement
from information_schema.triggers
where event_object_schema = 'public'
order by event_object_table, trigger_name;
