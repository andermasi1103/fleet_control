begin;

create table public.usuario_vehiculos (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references public.usuarios(id) on delete cascade,
  vehiculo_id uuid not null references public.vehiculos(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint usuario_vehiculos_usuario_id_key unique (usuario_id)
);

create index usuario_vehiculos_vehiculo_id_idx
  on public.usuario_vehiculos (vehiculo_id);

alter table public.usuario_vehiculos enable row level security;

revoke all on table public.usuario_vehiculos from public, anon, authenticated;

create or replace function public.fleet_control_set_user_vehicle(
  p_user_id uuid,
  p_vehicle_id uuid default null
)
returns public.usuario_vehiculos
language plpgsql
security definer
set search_path = public
as $$
declare
  v_user public.usuarios%rowtype;
  v_role_code text;
  v_vehicle public.vehiculos%rowtype;
  v_assignment public.usuario_vehiculos%rowtype;
begin
  select u.*
    into v_user
  from public.usuarios as u
  where u.id = p_user_id
    and u.activo = true;

  if not found then
    raise exception 'invalid_user' using errcode = 'P0001';
  end if;

  select codigo
    into v_role_code
  from public.roles
  where id = v_user.rol_id;

  if v_role_code <> 'chofer' then
    raise exception 'invalid_driver' using errcode = 'P0001';
  end if;

  if p_vehicle_id is null then
    delete from public.usuario_vehiculos where usuario_id = p_user_id;
    return null;
  end if;

  select *
    into v_vehicle
  from public.vehiculos
  where id = p_vehicle_id
    and activo = true;

  if not found then
    raise exception 'invalid_vehicle' using errcode = 'P0001';
  end if;

  if v_user.empresa_id is null or v_user.empresa_id <> v_vehicle.empresa_id then
    raise exception 'invalid_company' using errcode = 'P0001';
  end if;

  insert into public.usuario_vehiculos (usuario_id, vehiculo_id)
  values (p_user_id, p_vehicle_id)
  on conflict (usuario_id) do update
    set vehiculo_id = excluded.vehiculo_id,
        updated_at = now()
  returning * into v_assignment;

  return v_assignment;
end;
$$;

revoke all on function public.fleet_control_set_user_vehicle(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.fleet_control_set_user_vehicle(uuid, uuid)
  to service_role;

commit;
