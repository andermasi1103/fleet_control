-- Fleet Control production database roles.
-- Execute manually as the current database owner in the target database.
-- This script intentionally never embeds or changes the fleet_app password.

begin;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'fleet_owner') then
    create role fleet_owner noinherit nologin nosuperuser nocreatedb nocreaterole noreplication nobypassrls;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'fleet_app') then
    create role fleet_app noinherit login nosuperuser nocreatedb nocreaterole noreplication nobypassrls password null;
  end if;
end;
$$;

-- Set a strong password out of band after this script succeeds, for example
-- through the secret manager or an interactive psql session. Do not paste it
-- into this file, a migration, or a shell history.

revoke all on database fleet_control_db from public;
grant connect on database fleet_control_db to fleet_owner, fleet_app;

revoke create on schema public from public;
revoke all on schema public from public;
grant usage, create on schema public to fleet_owner;
grant usage on schema public to fleet_app;

-- login_usuario is SECURITY DEFINER and calls pgcrypto through this schema.
grant usage on schema extensions to fleet_owner;

revoke all on all tables in schema public from public;
revoke all on all sequences in schema public from public;
revoke all on all functions in schema public from public;

grant all privileges on all tables in schema public to fleet_owner;
grant all privileges on all sequences in schema public to fleet_owner;
grant all privileges on all functions in schema public to fleet_owner;

-- The runtime account receives only the table operations used by Fastify.
do $$
declare
  permission record;
begin
  for permission in
    select * from (values
      ('sesiones', 'SELECT, INSERT, UPDATE'),
      ('usuarios', 'SELECT, UPDATE'),
      ('roles', 'SELECT'),
      ('empresas', 'SELECT, INSERT, UPDATE'),
      ('locales', 'SELECT, INSERT, UPDATE'),
      ('vehiculos', 'SELECT, INSERT, UPDATE'),
      ('asistencias', 'SELECT, INSERT'),
      ('usuario_locales', 'SELECT'),
      ('pedidos', 'SELECT, INSERT, UPDATE'),
      ('pedido_descripciones', 'SELECT, INSERT, UPDATE'),
      ('gestiones', 'SELECT'),
      ('gestion_eventos', 'SELECT'),
      ('chofer_ubicaciones', 'SELECT'),
      ('role_views', 'SELECT, INSERT, UPDATE'),
      ('app_views', 'SELECT'),
      ('usuario_vehiculos', 'SELECT'),
      ('supervisor_choferes', 'SELECT'),
      ('notification_devices', 'SELECT, INSERT, UPDATE'),
      ('notificaciones', 'SELECT, INSERT, UPDATE')
    ) as required_privileges(table_name, privileges)
  loop
    if to_regclass(format('public.%I', permission.table_name)) is null then
      raise exception 'Missing required table public.%', permission.table_name;
    end if;
    execute format('grant %s on table public.%I to fleet_app', permission.privileges, permission.table_name);
  end loop;
end;
$$;

grant usage, select, update on all sequences in schema public to fleet_app;

revoke all on function public.login_usuario(text, text) from public;
revoke all on function public.fleet_control_verify_usuario_password(uuid, text) from public;
revoke all on function public.fleet_control_set_usuario_password(uuid, text) from public;
revoke all on function public.fleet_control_create_usuario(text, text, text, uuid, uuid, boolean) from public;
revoke all on function public.fleet_control_driver_claim_order(uuid, uuid) from public;
revoke all on function public.fleet_control_create_gestion(uuid, uuid, uuid, uuid) from public;
revoke all on function public.fleet_control_update_gestion_status(uuid, text, uuid) from public;
revoke all on function public.fleet_control_import_locations(uuid, jsonb) from public;
revoke all on function public.fleet_control_set_user_locations(uuid, uuid[]) from public;
revoke all on function public.fleet_control_set_user_vehicle(uuid, uuid) from public;
revoke all on function public.fleet_control_set_supervisor_choferes(uuid, uuid[]) from public;
revoke all on function public.fleet_control_update_driver_location(uuid, double precision, double precision, double precision, double precision, double precision, timestamptz) from public;

grant execute on function public.login_usuario(text, text) to fleet_app;
grant execute on function public.fleet_control_verify_usuario_password(uuid, text) to fleet_app;
grant execute on function public.fleet_control_set_usuario_password(uuid, text) to fleet_app;
grant execute on function public.fleet_control_create_usuario(text, text, text, uuid, uuid, boolean) to fleet_app;
grant execute on function public.fleet_control_driver_claim_order(uuid, uuid) to fleet_app;
grant execute on function public.fleet_control_create_gestion(uuid, uuid, uuid, uuid) to fleet_app;
grant execute on function public.fleet_control_update_gestion_status(uuid, text, uuid) to fleet_app;
grant execute on function public.fleet_control_import_locations(uuid, jsonb) to fleet_app;
grant execute on function public.fleet_control_set_user_locations(uuid, uuid[]) to fleet_app;
grant execute on function public.fleet_control_set_user_vehicle(uuid, uuid) to fleet_app;
grant execute on function public.fleet_control_set_supervisor_choferes(uuid, uuid[]) to fleet_app;
grant execute on function public.fleet_control_update_driver_location(uuid, double precision, double precision, double precision, double precision, double precision, timestamptz) to fleet_app;

-- SECURITY DEFINER routines run with fleet_owner's deliberately limited
-- database privileges, never with the PostgreSQL cluster superuser.
alter function public.login_usuario(text, text) owner to fleet_owner;
alter function public.fleet_control_verify_usuario_password(uuid, text) owner to fleet_owner;
alter function public.fleet_control_set_usuario_password(uuid, text) owner to fleet_owner;
alter function public.fleet_control_create_usuario(text, text, text, uuid, uuid, boolean) owner to fleet_owner;
alter function public.fleet_control_driver_claim_order(uuid, uuid) owner to fleet_owner;
alter function public.fleet_control_create_gestion(uuid, uuid, uuid, uuid) owner to fleet_owner;
alter function public.fleet_control_update_gestion_status(uuid, text, uuid) owner to fleet_owner;
alter function public.fleet_control_import_locations(uuid, jsonb) owner to fleet_owner;
alter function public.fleet_control_set_user_locations(uuid, uuid[]) owner to fleet_owner;
alter function public.fleet_control_set_user_vehicle(uuid, uuid) owner to fleet_owner;
alter function public.fleet_control_set_supervisor_choferes(uuid, uuid[]) owner to fleet_owner;
alter function public.fleet_control_update_driver_location(uuid, double precision, double precision, double precision, double precision, double precision, timestamptz) owner to fleet_owner;

-- fleet_owner must own the existing application objects to run future ALTER
-- migrations. The public schema is Fleet Control's application schema; this
-- deliberately excludes extensions and system schemas.
do $$
declare
  relation record;
  routine record;
begin
  for relation in
    select c.relname, c.relkind
    from pg_class c
    join pg_namespace n on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relkind in ('r', 'p', 'S', 'v', 'm', 'f')
  loop
    execute format(
      'alter %s public.%I owner to fleet_owner',
      case relation.relkind
        when 'S' then 'sequence'
        when 'v' then 'view'
        when 'm' then 'materialized view'
        when 'f' then 'foreign table'
        else 'table'
      end,
      relation.relname
    );
  end loop;

  for routine in
    select p.proname, p.prokind, pg_get_function_identity_arguments(p.oid) as arguments
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
  loop
    execute format(
      'alter %s public.%I(%s) owner to fleet_owner',
      case routine.prokind when 'p' then 'procedure' else 'function' end,
      routine.proname,
      routine.arguments
    );
  end loop;
end;
$$;

alter default privileges for role fleet_owner in schema public revoke execute on functions from public;
alter default privileges for role fleet_owner in schema public revoke all on tables from public;
alter default privileges for role fleet_owner in schema public grant select, insert, update, delete on tables to fleet_app;
alter default privileges for role fleet_owner in schema public grant usage, select, update on sequences to fleet_app;

commit;

-- Run the following ownership transfers separately after validating the grants.
-- They require the current owner and should be executed during a maintenance window:
-- ALTER DATABASE fleet_control_db OWNER TO fleet_owner;
