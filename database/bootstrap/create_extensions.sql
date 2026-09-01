-- MasiTrack extension bootstrap for PostgreSQL 18 / Render.
-- Run manually as the initial Render database credential after create_roles.sql
-- has succeeded and before deploying password-related application functions.

begin;

-- PostgreSQL's standard public schema is the intended home. Do not create the
-- Supabase-specific historical schema named "extensions".
create extension if not exists pgcrypto with schema public;

do $$
declare
  extension_schema text;
begin
  select n.nspname
    into extension_schema
    from pg_extension e
    join pg_namespace n on n.oid = e.extnamespace
   where e.extname = 'pgcrypto';

  if extension_schema is distinct from 'public' then
    raise exception 'pgcrypto must be installed in public, found %', coalesce(extension_schema, '<missing>');
  end if;

  if not exists (select 1 from pg_roles where rolname = 'fleet_owner') then
    raise exception 'fleet_owner must exist before validating pgcrypto';
  end if;

  if to_regprocedure('public.crypt(text,text)') is null
      or to_regprocedure('public.gen_salt(text)') is null
      or to_regprocedure('public.gen_salt(text,integer)') is null then
    raise exception 'pgcrypto password helper functions are missing from public';
  end if;

  if not has_function_privilege('fleet_owner', 'public.crypt(text,text)', 'EXECUTE')
      or not has_function_privilege('fleet_owner', 'public.gen_salt(text)', 'EXECUTE')
      or not has_function_privilege('fleet_owner', 'public.gen_salt(text,integer)', 'EXECUTE') then
    raise exception 'fleet_owner lacks effective EXECUTE on required pgcrypto password helpers';
  end if;
end;
$$;

-- pgcrypto is a trusted extension. On Render its contained functions are owned
-- by the bootstrap superuser, while the installing credential owns only the
-- extension. Do not attempt REVOKE or GRANT on those functions: that cannot
-- change their provider-owned ACLs and only emits operational warnings. PUBLIC
-- EXECUTE is an accepted provider limitation; application RPCs are hardened
-- separately in create_roles.sql and migration scripts.
-- PostgreSQL 18 also provides gen_random_uuid() in core, so this bootstrap does
-- not alter any UUID helper ACL.

commit;
