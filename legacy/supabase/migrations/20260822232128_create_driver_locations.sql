begin;

create table public.chofer_ubicaciones (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(id) on delete restrict,
  chofer_usuario_id uuid not null references public.usuarios(id) on delete restrict,
  gestion_id uuid references public.gestiones(id) on delete set null,
  vehiculo_id uuid references public.vehiculos(id) on delete set null,
  latitud double precision not null,
  longitud double precision not null,
  precision_metros double precision,
  velocidad_mps double precision,
  rumbo_grados double precision,
  captured_at timestamptz not null,
  updated_at timestamptz not null default now(),
  constraint chofer_ubicaciones_chofer_usuario_unique unique (chofer_usuario_id),
  constraint chofer_ubicaciones_latitud_check check (latitud between -90 and 90),
  constraint chofer_ubicaciones_longitud_check check (longitud between -180 and 180),
  constraint chofer_ubicaciones_precision_check check (precision_metros is null or precision_metros >= 0),
  constraint chofer_ubicaciones_velocidad_check check (velocidad_mps is null or velocidad_mps >= 0),
  constraint chofer_ubicaciones_rumbo_check check (rumbo_grados is null or (rumbo_grados >= 0 and rumbo_grados < 360))
);

create index chofer_ubicaciones_empresa_id_idx on public.chofer_ubicaciones(empresa_id);
create index chofer_ubicaciones_gestion_id_idx on public.chofer_ubicaciones(gestion_id);
create index chofer_ubicaciones_vehiculo_id_idx on public.chofer_ubicaciones(vehiculo_id);
create index chofer_ubicaciones_updated_at_idx on public.chofer_ubicaciones(updated_at desc);
create index chofer_ubicaciones_captured_at_idx on public.chofer_ubicaciones(captured_at desc);

alter table public.chofer_ubicaciones enable row level security;
revoke all on table public.chofer_ubicaciones from anon, authenticated;

create or replace function public.fleet_control_update_driver_location(
  p_user_id uuid,
  p_latitude double precision,
  p_longitude double precision,
  p_accuracy double precision,
  p_speed double precision,
  p_heading double precision,
  p_captured_at timestamptz
)
returns public.chofer_ubicaciones language plpgsql security definer set search_path = public as $$
declare
  v_driver record;
  v_management_id uuid;
  v_vehicle_id uuid;
  v_location public.chofer_ubicaciones;
  v_now timestamptz := now();
begin
  if p_latitude is null or p_latitude < -90 or p_latitude > 90 then raise exception 'invalid_location'; end if;
  if p_longitude is null or p_longitude < -180 or p_longitude > 180 then raise exception 'invalid_location'; end if;
  if p_accuracy is not null and p_accuracy < 0 then raise exception 'invalid_location'; end if;
  if p_speed is not null and p_speed < 0 then raise exception 'invalid_location'; end if;
  if p_heading is not null and (p_heading < 0 or p_heading >= 360) then raise exception 'invalid_location'; end if;
  if p_captured_at is null or p_captured_at > v_now + interval '5 minutes' then raise exception 'invalid_captured_at'; end if;

  select u.id, u.empresa_id, u.activo, r.codigo
    into v_driver
    from public.usuarios u
    join public.roles r on r.id = u.rol_id
   where u.id = p_user_id;
  if not found or v_driver.activo is not true or v_driver.codigo <> 'chofer' or v_driver.empresa_id is null then raise exception 'forbidden'; end if;

  select id, vehiculo_id
    into v_management_id, v_vehicle_id
    from public.gestiones
   where chofer_usuario_id = p_user_id
     and estado in ('asignado', 'aceptado', 'en_camino', 'en_gestion')
   order by updated_at desc
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
    updated_at = excluded.updated_at
  returning * into v_location;

  return v_location;
end; $$;

revoke all on function public.fleet_control_update_driver_location(uuid, double precision, double precision, double precision, double precision, double precision, timestamptz) from public;
revoke all on function public.fleet_control_update_driver_location(uuid, double precision, double precision, double precision, double precision, double precision, timestamptz) from anon, authenticated;
grant execute on function public.fleet_control_update_driver_location(uuid, double precision, double precision, double precision, double precision, double precision, timestamptz) to service_role;

commit;
