-- Render/PostgreSQL privilege diagnostic for MasiTrack preproduction.
-- Run manually as the initial Render database credential after the database is
-- created. It intentionally rolls back; do not run it from the application.
-- It never contains passwords, connection strings, application data, or DDL
-- that survives the session.

begin;

select current_user, session_user;
show createrole_self_grant;

select rolname, rolsuper, rolcreaterole, rolcreatedb
from pg_roles
where rolname = current_user;

do $$
declare
  probe_role constant text := 'masitrack_privilege_probe';
  current_identity text := session_user;
  automatic_membership record;
  automatic_membership_found boolean := false;
begin
  begin
    execute format('create role %I noinherit nologin', probe_role);
    raise notice 'CREATE ROLE: supported';

    for automatic_membership in
      select m.admin_option, m.inherit_option, m.set_option, grantor.rolname as grantor
      from pg_auth_members m
      join pg_roles granted on granted.oid = m.roleid
      join pg_roles member on member.oid = m.member
      join pg_roles grantor on grantor.oid = m.grantor
      where granted.rolname = probe_role
        and member.rolname = current_identity
      order by grantor.rolname
    loop
      automatic_membership_found := true;
      raise notice 'creator self-grant: grantor=%, admin=%, inherit=%, set=%',
        automatic_membership.grantor,
        automatic_membership.admin_option,
        automatic_membership.inherit_option,
        automatic_membership.set_option;
    end loop;

    if not automatic_membership_found then
      raise notice 'creator self-grant: no explicit membership';
    end if;

    execute format('grant %I to %I with admin true, inherit false, set true', probe_role, current_identity);
    raise notice 'GRANT role membership: supported';

    execute format('set local role %I', probe_role);
    if current_user <> probe_role then
      raise exception 'SET ROLE did not assume the probe role';
    end if;
    reset role;
    raise notice 'SET ROLE: supported';

    create temporary table masitrack_owner_probe (id integer);
    execute format('alter table pg_temp.masitrack_owner_probe owner to %I', probe_role);
    raise notice 'ALTER OWNER: supported for an object owned by the initial credential';
  exception
    when others then
      raise notice 'Privilege probe failed: %', sqlerrm;
  end;
end;
$$;

-- Review the installed set; MasiTrack requires pgcrypto compatibility for UUID
-- defaults and password helpers. Its supported location is public, not a
-- Supabase-specific schema named extensions.
select extname, extversion
from pg_extension
order by extname;

rollback;
