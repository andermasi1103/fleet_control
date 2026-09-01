-- Separate device presence from the timestamp of the last GPS capture.

begin;

alter table public.chofer_ubicaciones
  add column if not exists last_seen_at timestamptz;

-- Existing rows only have a confirmed device communication when their GPS
-- sample was received, so captured_at is the safe initial value.
update public.chofer_ubicaciones
set last_seen_at = captured_at
where last_seen_at is null;

alter table public.chofer_ubicaciones
  alter column last_seen_at set not null;

create index if not exists chofer_ubicaciones_last_seen_at_idx
  on public.chofer_ubicaciones (last_seen_at desc);

create or replace function public.fleet_control_update_driver_location(
  p_user_id uuid,
  p_latitude double precision,
  p_longitude double precision,
  p_accuracy double precision,
  p_speed double precision,
  p_heading double precision,
  p_captured_at timestamptz
)
returns public.chofer_ubicaciones
language plpgsql
security definer
set search_path = public
as $$
declare
  v_driver record;
  v_management_id uuid;
  v_vehicle_id uuid;
  v_location public.chofer_ubicaciones;
  v_now timestamptz := now();
begin
  if p_latitude is null or p_latitude < -90 or p_latitude > 90 then
    raise exception 'invalid_location';
  end if;
  if p_longitude is null or p_longitude < -180 or p_longitude > 180 then
    raise exception 'invalid_location';
  end if;
  if p_accuracy is not null and p_accuracy < 0 then
    raise exception 'invalid_location';
  end if;
  if p_speed is not null and p_speed < 0 then
    raise exception 'invalid_location';
  end if;
  if p_heading is not null and (p_heading < 0 or p_heading >= 360) then
    raise exception 'invalid_location';
  end if;
  if p_captured_at is null or p_captured_at > v_now + interval '5 minutes' then
    raise exception 'invalid_captured_at';
  end if;

  select u.id, u.empresa_id, u.activo, r.codigo
    into v_driver
    from public.usuarios as u
    join public.roles as r on r.id = u.rol_id
   where u.id = p_user_id;

  if not found or v_driver.activo is not true or v_driver.codigo <> 'chofer'
      or v_driver.empresa_id is null then
    raise exception 'forbidden';
  end if;

  select g.id, g.vehiculo_id
    into v_management_id, v_vehicle_id
    from public.gestiones as g
   where g.chofer_usuario_id = p_user_id
     and g.estado in ('asignado', 'aceptado', 'en_camino', 'en_gestion')
   order by g.updated_at desc
   limit 1;

  insert into public.chofer_ubicaciones as location (
    empresa_id,
    chofer_usuario_id,
    gestion_id,
    vehiculo_id,
    latitud,
    longitud,
    precision_metros,
    velocidad_mps,
    rumbo_grados,
    captured_at,
    last_seen_at,
    updated_at
  ) values (
    v_driver.empresa_id,
    p_user_id,
    v_management_id,
    v_vehicle_id,
    p_latitude,
    p_longitude,
    p_accuracy,
    p_speed,
    p_heading,
    p_captured_at,
    v_now,
    v_now
  ) on conflict (chofer_usuario_id) do update set
    empresa_id = excluded.empresa_id,
    gestion_id = excluded.gestion_id,
    vehiculo_id = excluded.vehiculo_id,
    latitud = excluded.latitud,
    longitud = excluded.longitud,
    precision_metros = excluded.precision_metros,
    velocidad_mps = excluded.velocidad_mps,
    rumbo_grados = excluded.rumbo_grados,
    captured_at = excluded.captured_at,
    last_seen_at = excluded.last_seen_at,
    updated_at = excluded.updated_at
  returning * into v_location;

  return v_location;
end;
$$;

create or replace function public.fleet_control_touch_driver_presence(
  p_user_id uuid
)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  v_driver record;
  v_last_seen_at timestamptz;
begin
  select u.id, u.empresa_id, u.activo, r.codigo
    into v_driver
    from public.usuarios as u
    join public.roles as r on r.id = u.rol_id
   where u.id = p_user_id;

  if not found or v_driver.activo is not true or v_driver.codigo <> 'chofer'
      or v_driver.empresa_id is null then
    raise exception 'forbidden';
  end if;

  update public.chofer_ubicaciones
     set last_seen_at = now()
   where chofer_usuario_id = p_user_id
   returning last_seen_at into v_last_seen_at;

  return v_last_seen_at;
end;
$$;

alter function public.fleet_control_update_driver_location(
  uuid, double precision, double precision, double precision,
  double precision, double precision, timestamptz
) owner to fleet_owner;
alter function public.fleet_control_touch_driver_presence(uuid)
  owner to fleet_owner;

revoke all on function public.fleet_control_update_driver_location(
  uuid, double precision, double precision, double precision,
  double precision, double precision, timestamptz
) from public;
revoke all on function public.fleet_control_touch_driver_presence(uuid)
  from public;
grant execute on function public.fleet_control_update_driver_location(
  uuid, double precision, double precision, double precision,
  double precision, double precision, timestamptz
) to fleet_app;
grant execute on function public.fleet_control_touch_driver_presence(uuid)
  to fleet_app;

commit;
