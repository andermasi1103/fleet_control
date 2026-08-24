-- Provisiona las asignaciones Usuario <-> Local para entornos creados con
-- `supabase db push`. Es equivalente al script manual/user_locations.sql.
begin;

create extension if not exists pgcrypto;

create table if not exists public.usuario_locales (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references public.usuarios(id) on delete cascade,
  local_id uuid not null references public.locales(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint usuario_locales_usuario_local_unique unique (usuario_id, local_id)
);

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.usuario_locales'::regclass
      and conname = 'usuario_locales_usuario_local_unique'
  ) then
    alter table public.usuario_locales
      add constraint usuario_locales_usuario_local_unique
      unique (usuario_id, local_id);
  end if;
end;
$$;

create index if not exists usuario_locales_local_id_idx
  on public.usuario_locales (local_id);

alter table public.usuario_locales enable row level security;
revoke all on table public.usuario_locales from anon, authenticated;

create or replace function public.fleet_control_set_user_locations(
  p_user_id uuid,
  p_location_ids uuid[]
) returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_empresa_id uuid;
  v_user_active boolean;
  v_location_ids uuid[] := array(
    select distinct location_id
    from unnest(coalesce(p_location_ids, '{}'::uuid[])) as location_id
  );
  v_location_count integer;
begin
  select empresa_id, activo
  into v_empresa_id, v_user_active
  from public.usuarios
  where id = p_user_id
  for update;

  if not found then
    raise exception 'user_not_found' using errcode = 'P0001';
  end if;

  if v_empresa_id is null then
    if coalesce(cardinality(v_location_ids), 0) > 0 then
      raise exception 'invalid_reference' using errcode = 'P0001';
    end if;
    delete from public.usuario_locales where usuario_id = p_user_id;
    return;
  end if;

  if v_user_active is not true and coalesce(cardinality(v_location_ids), 0) > 0 then
    raise exception 'invalid_reference' using errcode = 'P0001';
  end if;

  select count(*)
  into v_location_count
  from public.locales
  where id = any(v_location_ids)
    and empresa_id = v_empresa_id;

  if v_location_count <> coalesce(cardinality(v_location_ids), 0) then
    raise exception 'invalid_reference' using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.locales as local
    where local.id = any(v_location_ids)
      and local.activo is not true
      and not exists (
        select 1
        from public.usuario_locales as current_assignment
        where current_assignment.usuario_id = p_user_id
          and current_assignment.local_id = local.id
      )
  ) then
    raise exception 'invalid_reference' using errcode = 'P0001';
  end if;

  delete from public.usuario_locales
  where usuario_id = p_user_id
    and not (local_id = any(v_location_ids));

  insert into public.usuario_locales (usuario_id, local_id)
  select p_user_id, location_id
  from unnest(v_location_ids) as location_id
  on conflict (usuario_id, local_id) do nothing;
end;
$$;

revoke all on function public.fleet_control_set_user_locations(uuid, uuid[]) from public;
grant execute on function public.fleet_control_set_user_locations(uuid, uuid[]) to service_role;

commit;
