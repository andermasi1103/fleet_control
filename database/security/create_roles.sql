-- MasiTrack role bootstrap for PostgreSQL 18 / Render.
-- Run manually as the initial database credential with psql -v ON_ERROR_STOP=1.
-- It creates no passwords and does not depend on Supabase's historical
-- "extensions" schema.

begin;

do $$
begin
  if not exists (select 1 from pg_roles where rolname = 'fleet_owner') then
    create role fleet_owner noinherit nologin;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'fleet_migrator') then
    create role fleet_migrator noinherit login;
  end if;
  if not exists (select 1 from pg_roles where rolname = 'fleet_app') then
    create role fleet_app noinherit login;
  end if;
end;
$$;

-- PostgreSQL creates roles without SUPERUSER, CREATEDB, CREATEROLE,
-- REPLICATION, or BYPASSRLS unless explicitly requested. Do not ALTER those
-- attributes: a non-superuser cannot change SUPERUSER, even to NOSUPERUSER.
-- Existing roles are validated rather than reconfigured; passwords are never
-- inspected or changed here.
do $$
declare
  role_state record;
begin
  for role_state in
    select rolname, rolcanlogin, rolinherit, rolsuper, rolcreaterole,
           rolcreatedb, rolreplication, rolbypassrls
    from pg_roles
    where rolname in ('fleet_owner', 'fleet_migrator', 'fleet_app')
  loop
    if role_state.rolsuper or role_state.rolcreaterole or role_state.rolcreatedb
        or role_state.rolreplication or role_state.rolbypassrls then
      raise exception 'Role % has an administrative attribute that this bootstrap will not alter', role_state.rolname
        using hint = 'Use a sufficiently privileged, approved administrative procedure to remediate the existing role.';
    end if;

    -- Expected for every MasiTrack role; membership itself also has INHERIT FALSE.
    if role_state.rolinherit then
      raise exception 'Role % must have NOINHERIT before running this bootstrap', role_state.rolname
        using hint = 'Existing roles are not reconfigured automatically on managed PostgreSQL.';
    end if;

    if (role_state.rolname = 'fleet_owner' and role_state.rolcanlogin)
        or (role_state.rolname in ('fleet_migrator', 'fleet_app') and not role_state.rolcanlogin) then
      raise exception 'Role % has an incompatible LOGIN attribute', role_state.rolname
        using hint = 'Existing roles are not reconfigured automatically on managed PostgreSQL.';
    end if;
  end loop;
end;
$$;

-- Passwords are configured out of band after this script succeeds, for example
-- with \password in psql. Never put them in this file, shell history, or Git.

-- Keep database access to the two login roles. The current database owner
-- retains its implicit access; fleet_owner has no LOGIN and needs no CONNECT.
do $$
begin
  execute format('revoke all on database %I from public', current_database());
  execute format('grant connect on database %I to fleet_migrator, fleet_app', current_database());
end;
$$;

-- The migration runner must explicitly assume ownership. fleet_app is never a
-- member of fleet_owner and cannot grant that membership to anybody else.
do $$
begin
  if exists (
    select 1
    from pg_auth_members m
    join pg_roles granted_role on granted_role.oid = m.roleid
    join pg_roles member_role on member_role.oid = m.member
    where granted_role.rolname = 'fleet_owner'
      and member_role.rolname = 'fleet_app'
  ) then
    revoke fleet_owner from fleet_app;
  end if;
end;
$$;

-- A non-superuser CREATEROLE creator normally has PostgreSQL's implicit
-- bootstrap-superuser grant (ADMIN TRUE, INHERIT FALSE, SET FALSE). Render can
-- also add a creator self-grant according to createrole_self_grant. Neither is
-- runtime access, but the latter is removed below. Use the implicit ADMIN
-- option to create a separate, least-privilege self-grant solely for SET ROLE.
-- session_user is intentionally used: it stays stable across SET LOCAL ROLE
-- and avoids hardcoding a provider login name.
do $$
begin
  if current_user <> session_user then
    raise exception 'Run the bootstrap without a pre-existing SET ROLE'
      using hint = 'Connect directly as the initial credential so current_user and session_user match.';
  end if;

  begin
    execute format(
      'grant fleet_owner to %I with admin false, inherit false, set true',
      session_user
    );
  exception
    when insufficient_privilege then
      raise exception 'Cannot obtain the temporary SET ROLE fleet_owner membership'
        using hint = 'The initial credential needs ADMIN OPTION on fleet_owner. Re-run from a clean PostgreSQL 18 role creation or use the approved role administrator.';
  end;
end;
$$;

-- The migration runner retains the only durable application membership.
grant fleet_owner to fleet_migrator with admin false, inherit false, set true;

-- public is the application schema. Runtime gets name resolution only; DDL is
-- available exclusively after the migration runner has SET ROLE fleet_owner.
revoke all on schema public from public;
grant usage, create on schema public to fleet_owner;
grant usage on schema public to fleet_app;

-- Remove ambient access from any existing application objects. These commands
-- are harmless on a clean database and intentionally do not touch ownership.
revoke all on all tables in schema public from public;
revoke all on all sequences in schema public from public;
revoke all on all functions in schema public from public;

-- Preserve the current, explicit runtime table surface when this bootstrap is
-- applied to an existing database. Missing tables are expected on a clean DB.
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
    if to_regclass(format('public.%I', permission.table_name)) is not null then
      execute format('grant %s on table public.%I to fleet_app', permission.privileges, permission.table_name);
    end if;
  end loop;
end;
$$;

grant usage, select, update on all sequences in schema public to fleet_app;

-- Existing application objects must be owned by fleet_owner for later ALTER
-- migrations. Extension members are deliberately excluded: pgcrypto is an
-- administrative extension, not an application-owned object.
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
      and not exists (
        select 1 from pg_depend d
        where d.classid = 'pg_class'::regclass
          and d.objid = c.oid
          and d.deptype = 'e'
      )
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
      and not exists (
        select 1 from pg_depend d
        where d.classid = 'pg_proc'::regclass
          and d.objid = p.oid
          and d.deptype = 'e'
      )
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

-- Existing SECURITY DEFINER entry points have no PUBLIC execution and receive
-- only their required fleet_app grants when they exist.
do $$
declare
  routine record;
begin
  for routine in
    select * from (values
      ('login_usuario(text, text)', true),
      ('fleet_control_verify_usuario_password(uuid, text)', true),
      ('fleet_control_set_usuario_password(uuid, text)', true),
      ('fleet_control_create_usuario(text, text, text, uuid, uuid, boolean)', true),
      ('fleet_control_driver_claim_order(uuid, uuid)', true),
      ('fleet_control_create_gestion(uuid, uuid, uuid, uuid)', true),
      ('fleet_control_update_gestion_status(uuid, text, uuid)', true),
      ('fleet_control_import_locations(uuid, jsonb)', true),
      ('fleet_control_set_user_locations(uuid, uuid[])', true),
      ('fleet_control_set_user_vehicle(uuid, uuid)', true),
      ('fleet_control_set_supervisor_choferes(uuid, uuid[])', true),
      ('fleet_control_update_driver_location(uuid, double precision, double precision, double precision, double precision, double precision, timestamptz)', true),
      ('fleet_control_touch_driver_presence(uuid)', true)
    ) as required_routines(identity, grant_to_app)
  loop
    if to_regprocedure(format('public.%s', routine.identity)) is not null then
      execute format('revoke all on function public.%s from public', routine.identity);
      if routine.grant_to_app then
        execute format('grant execute on function public.%s to fleet_app', routine.identity);
      end if;
    end if;
  end loop;
end;
$$;

-- pgcrypto is installed separately in public. Its trusted-extension functions
-- are provider-owned on Render, so their ACLs are validated by
-- create_extensions.sql rather than changed here.

-- ALTER DEFAULT PRIVILEGES must be recorded by fleet_owner itself.
set local role fleet_owner;
alter default privileges revoke execute on functions from public;
alter default privileges revoke all on tables from public;
alter default privileges in schema public grant select, insert, update on tables to fleet_app;
alter default privileges in schema public grant usage, select, update on sequences to fleet_app;
reset role;

do $$
declare
begin
  -- REVOKE affects grants made by the current initial credential. It removes
  -- the temporary SET grant and any createrole_self_grant row made by that
  -- credential, while PostgreSQL retains its unrevocable bootstrap-superuser
  -- creator grant (ADMIN TRUE, INHERIT FALSE, SET FALSE), if present.
  execute format('revoke fleet_owner from %I', session_user);

  if not exists (
    select 1
    from pg_auth_members m
    join pg_roles granted_role on granted_role.oid = m.roleid
    join pg_roles member_role on member_role.oid = m.member
    where granted_role.rolname = 'fleet_owner'
      and member_role.rolname = 'fleet_migrator'
  ) or exists (
    select 1
    from pg_auth_members m
    join pg_roles granted_role on granted_role.oid = m.roleid
    join pg_roles member_role on member_role.oid = m.member
    where granted_role.rolname = 'fleet_owner'
      and member_role.rolname = 'fleet_migrator'
      and (m.admin_option or m.inherit_option or not m.set_option)
  ) then
    raise exception 'fleet_migrator membership in fleet_owner does not have the required ADMIN FALSE, INHERIT FALSE, SET TRUE options';
  end if;

  -- No creator self-grant or temporary grant may survive. A PostgreSQL 18
  -- role created by this non-superuser normally retains the immutable
  -- bootstrap-superuser grant; if an existing provider role has none, absence
  -- is safe, but any retained grant must be ADMIN-only and non-runtime.
  if exists (
    select 1
    from pg_auth_members m
    join pg_roles granted_role on granted_role.oid = m.roleid
    join pg_roles member_role on member_role.oid = m.member
    join pg_roles grantor_role on grantor_role.oid = m.grantor
    where granted_role.rolname = 'fleet_owner'
      and member_role.rolname = session_user
      and grantor_role.rolname = session_user
  ) or exists (
    select 1
    from pg_auth_members m
    join pg_roles granted_role on granted_role.oid = m.roleid
    join pg_roles member_role on member_role.oid = m.member
    where granted_role.rolname = 'fleet_owner'
      and member_role.rolname = session_user
      and (not m.admin_option or m.inherit_option or m.set_option)
  ) then
    raise exception 'The initial credential retains an unsafe fleet_owner membership'
      using hint = 'Only PostgreSQL''s immutable ADMIN TRUE, INHERIT FALSE, SET FALSE creator grant may remain.';
  end if;

  if exists (
    select 1
    from pg_auth_members m
    join pg_roles granted_role on granted_role.oid = m.roleid
    join pg_roles member_role on member_role.oid = m.member
    where granted_role.rolname = 'fleet_owner'
      and member_role.rolname = 'fleet_app'
  ) then
    raise exception 'fleet_app must not be a fleet_owner member';
  end if;
end;
$$;

commit;
