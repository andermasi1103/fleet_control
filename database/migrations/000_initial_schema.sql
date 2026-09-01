-- MasiTrack structural baseline, reconstructed from the local schema-only dump.
-- This is intentionally the state immediately before 001_notifications.sql.
-- Transaction control belongs to backend/scripts/migrate.ts.

create table public.roles (
  id uuid primary key default gen_random_uuid(),
  codigo text not null unique,
  nombre text not null,
  descripcion text,
  nivel integer,
  activo boolean not null default true
);

create table public.empresas (
  id uuid primary key default gen_random_uuid(),
  nombre text not null,
  razon_social text,
  documento text,
  telefono text,
  direccion text,
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.app_views (
  id uuid primary key default gen_random_uuid(),
  codigo text not null unique,
  nombre text not null,
  descripcion text,
  ruta text,
  icono text,
  orden integer not null default 0,
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint app_views_codigo_not_empty check (length(btrim(codigo)) > 0),
  constraint app_views_nombre_not_empty check (length(btrim(nombre)) > 0)
);

create table public.locales (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(id) on delete cascade,
  nombre text not null,
  direccion text,
  latitud double precision not null,
  longitud double precision not null,
  radio_metros double precision not null default 100,
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  codigo text,
  descripcion text,
  constraint locales_latitud_check check (latitud between -90 and 90),
  constraint locales_longitud_check check (longitud between -180 and 180),
  constraint locales_radio_metros_check check (radio_metros > 0),
  constraint locales_codigo_not_empty check (codigo is null or length(btrim(codigo)) > 0)
);

create table public.usuarios (
  id uuid primary key default gen_random_uuid(),
  usuario text not null unique,
  nombre text not null,
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  empresa_id uuid references public.empresas(id),
  rol_id uuid not null references public.roles(id),
  password_hash text
);

create table public.vehiculos (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(id) on delete restrict,
  patente text not null,
  marca text,
  modelo text,
  anio integer,
  descripcion text,
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  tipo_vehiculo text,
  constraint vehiculos_anio_check check (anio is null or anio between 1900 and 2100),
  constraint vehiculos_tipo_vehiculo_check check (
    tipo_vehiculo is null or tipo_vehiculo in ('moto', 'auto', 'camion', 'furgon', 'otro')
  )
);

create table public.sesiones (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references public.usuarios(id) on delete cascade,
  token_hash text not null unique,
  expires_at timestamptz not null,
  revoked_at timestamptz,
  last_used_at timestamptz,
  created_at timestamptz not null default now()
);

create table public.asistencias (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references public.usuarios(id) on delete cascade,
  empresa_id uuid references public.empresas(id) on delete set null,
  tipo text not null default 'entrada',
  fecha_hora timestamptz not null default now(),
  latitud double precision,
  longitud double precision,
  dentro_geocerca boolean,
  created_at timestamptz not null default now(),
  local_id uuid references public.locales(id) on delete set null,
  constraint asistencias_tipo_check check (tipo in ('entrada', 'salida'))
);

create table public.usuario_locales (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references public.usuarios(id) on delete cascade,
  local_id uuid not null references public.locales(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint usuario_locales_usuario_local_unique unique (usuario_id, local_id)
);

create table public.usuario_vehiculos (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null unique references public.usuarios(id) on delete cascade,
  vehiculo_id uuid not null references public.vehiculos(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.supervisor_choferes (
  id uuid primary key default gen_random_uuid(),
  supervisor_usuario_id uuid not null references public.usuarios(id) on delete cascade,
  chofer_usuario_id uuid not null references public.usuarios(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint supervisor_choferes_distinct_users check (supervisor_usuario_id <> chofer_usuario_id),
  constraint supervisor_choferes_unique unique (supervisor_usuario_id, chofer_usuario_id)
);

create table public.pedido_descripciones (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(id) on delete restrict,
  nombre text not null,
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint pedido_descripciones_nombre_no_vacio check (length(btrim(nombre)) > 0)
);

create table public.pedidos (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(id) on delete restrict,
  local_id uuid not null references public.locales(id) on delete restrict,
  creado_por_usuario_id uuid not null references public.usuarios(id) on delete restrict,
  descripcion_tipo_id uuid references public.pedido_descripciones(id) on delete restrict,
  destino text,
  destino_latitud double precision,
  destino_longitud double precision,
  factura_solicitud text,
  numero_contacto text,
  prioridad text not null default 'normal',
  observaciones text,
  estado text not null default 'pendiente',
  cancelado_por_usuario_id uuid references public.usuarios(id) on delete set null,
  cancelado_at timestamptz,
  tracking_token_hash text,
  tracking_enabled boolean not null default false,
  tracking_expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint pedidos_estado_check check (estado in ('pendiente', 'asignado', 'aceptado', 'en_camino', 'en_gestion', 'completado', 'cancelado')),
  constraint pedidos_prioridad_check check (prioridad in ('baja', 'normal', 'urgente')),
  constraint pedidos_destino_coordenadas_check check (
    (destino_latitud is null and destino_longitud is null)
    or (destino_latitud between -90 and 90 and destino_longitud between -180 and 180)
  )
);

-- Queue semantics are already present before the numbered migration series.
create table public.gestiones (
  id uuid primary key default gen_random_uuid(),
  pedido_id uuid not null unique references public.pedidos(id) on delete restrict,
  empresa_id uuid not null references public.empresas(id) on delete restrict,
  local_id uuid not null references public.locales(id) on delete restrict,
  chofer_usuario_id uuid not null references public.usuarios(id) on delete restrict,
  vehiculo_id uuid not null references public.vehiculos(id) on delete restrict,
  estado text not null default 'asignado',
  asignado_por_usuario_id uuid not null references public.usuarios(id) on delete restrict,
  aceptado_at timestamptz,
  en_camino_at timestamptz,
  en_gestion_at timestamptz,
  completado_at timestamptz,
  cancelado_at timestamptz,
  observaciones text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  queue_position integer,
  constraint gestiones_estado_check check (estado in ('asignado', 'aceptado', 'en_camino', 'en_gestion', 'completado', 'cancelado')),
  constraint gestiones_queue_position_positive_check check (queue_position is null or queue_position > 0)
);

create table public.gestion_eventos (
  id uuid primary key default gen_random_uuid(),
  gestion_id uuid not null references public.gestiones(id) on delete restrict,
  usuario_id uuid not null references public.usuarios(id) on delete restrict,
  estado_anterior text,
  estado_nuevo text not null,
  observaciones text,
  created_at timestamptz not null default now(),
  constraint gestion_eventos_estado_check check (estado_nuevo in ('asignado', 'aceptado', 'en_camino', 'en_gestion', 'completado', 'cancelado'))
);

-- Presence was introduced by 003; this is the earlier location shape.
create table public.chofer_ubicaciones (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(id) on delete restrict,
  chofer_usuario_id uuid not null unique references public.usuarios(id) on delete restrict,
  gestion_id uuid references public.gestiones(id) on delete set null,
  vehiculo_id uuid references public.vehiculos(id) on delete set null,
  latitud double precision not null,
  longitud double precision not null,
  precision_metros double precision,
  velocidad_mps double precision,
  rumbo_grados double precision,
  captured_at timestamptz not null,
  updated_at timestamptz not null default now(),
  constraint chofer_ubicaciones_latitud_check check (latitud between -90 and 90),
  constraint chofer_ubicaciones_longitud_check check (longitud between -180 and 180),
  constraint chofer_ubicaciones_precision_check check (precision_metros is null or precision_metros >= 0),
  constraint chofer_ubicaciones_velocidad_check check (velocidad_mps is null or velocidad_mps >= 0),
  constraint chofer_ubicaciones_rumbo_check check (rumbo_grados is null or (rumbo_grados >= 0 and rumbo_grados < 360))
);

create table public.role_views (
  id uuid primary key default gen_random_uuid(),
  role_id uuid not null references public.roles(id) on delete cascade,
  view_id uuid not null references public.app_views(id) on delete cascade,
  visible boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint role_views_role_view_unique unique (role_id, view_id)
);

create index app_views_active_order_idx on public.app_views (activo, orden);
create index asistencias_empresa_fecha_idx on public.asistencias (empresa_id, fecha_hora desc);
create index asistencias_empresa_id_idx on public.asistencias (empresa_id);
create index asistencias_fecha_hora_idx on public.asistencias (fecha_hora desc);
create index asistencias_local_fecha_idx on public.asistencias (local_id, fecha_hora desc);
create index asistencias_local_id_idx on public.asistencias (local_id);
create index asistencias_usuario_fecha_idx on public.asistencias (usuario_id, fecha_hora desc);
create index asistencias_usuario_id_idx on public.asistencias (usuario_id);
create index asistencias_usuario_local_fecha_idx on public.asistencias (usuario_id, local_id, fecha_hora desc);
create index chofer_ubicaciones_captured_at_idx on public.chofer_ubicaciones (captured_at desc);
create index chofer_ubicaciones_empresa_id_idx on public.chofer_ubicaciones (empresa_id);
create index chofer_ubicaciones_gestion_id_idx on public.chofer_ubicaciones (gestion_id);
create index chofer_ubicaciones_updated_at_idx on public.chofer_ubicaciones (updated_at desc);
create index chofer_ubicaciones_vehiculo_id_idx on public.chofer_ubicaciones (vehiculo_id);
create index gestion_eventos_created_at_idx on public.gestion_eventos (created_at desc);
create index gestion_eventos_gestion_id_idx on public.gestion_eventos (gestion_id);
create index gestiones_chofer_estado_queue_position_idx on public.gestiones (chofer_usuario_id, estado, queue_position);
create unique index gestiones_chofer_operativo_unique on public.gestiones (chofer_usuario_id) where estado in ('aceptado', 'en_camino', 'en_gestion');
create unique index gestiones_chofer_queue_position_unique on public.gestiones (chofer_usuario_id, queue_position) where estado in ('asignado', 'aceptado', 'en_camino', 'en_gestion') and queue_position is not null;
create index gestiones_chofer_usuario_id_idx on public.gestiones (chofer_usuario_id);
create index gestiones_created_at_idx on public.gestiones (created_at desc);
create index gestiones_empresa_id_idx on public.gestiones (empresa_id);
create index gestiones_estado_idx on public.gestiones (estado);
create index gestiones_local_id_idx on public.gestiones (local_id);
create index gestiones_vehiculo_id_idx on public.gestiones (vehiculo_id);
create unique index gestiones_vehiculo_operativo_unique on public.gestiones (vehiculo_id) where estado in ('aceptado', 'en_camino', 'en_gestion');
create index locales_activo_idx on public.locales (activo);
create index locales_empresa_activo_idx on public.locales (empresa_id, activo);
create unique index locales_empresa_codigo_unique_ci on public.locales (empresa_id, lower(btrim(codigo))) where codigo is not null;
create index locales_empresa_id_idx on public.locales (empresa_id);
create index locales_empresa_idx on public.locales (empresa_id);
create index pedido_descripciones_empresa_activo_idx on public.pedido_descripciones (empresa_id, activo);
create unique index pedido_descripciones_empresa_nombre_unique on public.pedido_descripciones (empresa_id, lower(btrim(nombre)));
create index pedidos_creado_por_usuario_id_idx on public.pedidos (creado_por_usuario_id);
create index pedidos_created_at_idx on public.pedidos (created_at desc);
create index pedidos_empresa_id_idx on public.pedidos (empresa_id);
create index pedidos_estado_idx on public.pedidos (estado);
create index pedidos_local_id_idx on public.pedidos (local_id);
create index role_views_role_visible_idx on public.role_views (role_id, visible);
create index role_views_view_id_idx on public.role_views (view_id);
create index sesiones_expires_at_idx on public.sesiones (expires_at);
create index sesiones_token_hash_idx on public.sesiones (token_hash);
create index sesiones_usuario_activa_idx on public.sesiones (usuario_id) where revoked_at is null;
create index sesiones_usuario_id_idx on public.sesiones (usuario_id);
create index supervisor_choferes_chofer_usuario_id_idx on public.supervisor_choferes (chofer_usuario_id);
create index usuario_locales_local_id_idx on public.usuario_locales (local_id);
create index usuario_vehiculos_vehiculo_id_idx on public.usuario_vehiculos (vehiculo_id);
create index usuarios_empresa_id_idx on public.usuarios (empresa_id);
create unique index usuarios_usuario_unique on public.usuarios (lower(usuario));
create unique index usuarios_usuario_unique_ci on public.usuarios (lower(usuario));
create index vehiculos_empresa_idx on public.vehiculos (empresa_id);
create unique index vehiculos_empresa_patente_unique_ci on public.vehiculos (empresa_id, lower(patente));

create function public.fleet_control_set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create function public.fleet_control_role_views_set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger fleet_control_empresas_updated_at before update on public.empresas
for each row execute function public.fleet_control_set_updated_at();
create trigger fleet_control_locales_updated_at before update on public.locales
for each row execute function public.fleet_control_set_updated_at();
create trigger fleet_control_vehiculos_updated_at before update on public.vehiculos
for each row execute function public.fleet_control_set_updated_at();
create trigger fleet_control_app_views_updated_at before update on public.app_views
for each row execute function public.fleet_control_role_views_set_updated_at();
create trigger fleet_control_role_views_updated_at before update on public.role_views
for each row execute function public.fleet_control_role_views_set_updated_at();

-- Authentication is self-managed. None of these routines returns password_hash.
create function public.login_usuario(p_usuario text, p_password text)
returns table(id uuid, usuario text, nombre text, empresa_id uuid, rol_id uuid, rol_codigo text, activo boolean)
language plpgsql
security definer
set search_path = public
as $$
begin
  return query
  select u.id, u.usuario, u.nombre, u.empresa_id, u.rol_id, r.codigo, u.activo
  from public.usuarios as u
  left join public.roles as r on r.id = u.rol_id
  where lower(u.usuario) = lower(trim(p_usuario))
    and u.activo is true
    and u.password_hash is not null
    and public.crypt(p_password, u.password_hash) = u.password_hash
  limit 1;
end;
$$;

create function public.fleet_control_create_usuario(
  p_nombre text, p_usuario text, p_password text, p_empresa_id uuid,
  p_rol_id uuid, p_activo boolean default true
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  new_id uuid;
begin
  insert into public.usuarios (nombre, usuario, password_hash, empresa_id, rol_id, activo)
  values (
    p_nombre, p_usuario, public.crypt(p_password, public.gen_salt('bf', 12)),
    p_empresa_id, p_rol_id, p_activo
  )
  returning id into new_id;
  return new_id;
end;
$$;

create function public.fleet_control_set_usuario_password(p_user_id uuid, p_password text)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.usuarios
  set password_hash = public.crypt(p_password, public.gen_salt('bf', 12))
  where id = p_user_id;
  if not found then
    raise exception 'user_not_found';
  end if;
  update public.sesiones
  set revoked_at = now()
  where usuario_id = p_user_id and revoked_at is null;
end;
$$;

create function public.fleet_control_verify_usuario_password(p_user_id uuid, p_password text)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.usuarios
    where id = p_user_id
      and password_hash is not null
      and public.crypt(p_password, password_hash) = password_hash
  );
$$;

create function public.fleet_control_set_user_locations(p_user_id uuid, p_location_ids uuid[])
returns void
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
  select empresa_id, activo into v_empresa_id, v_user_active
  from public.usuarios where id = p_user_id for update;
  if not found then raise exception 'user_not_found' using errcode = 'P0001'; end if;
  if v_empresa_id is null then
    if coalesce(cardinality(v_location_ids), 0) > 0 then raise exception 'invalid_reference' using errcode = 'P0001'; end if;
    delete from public.usuario_locales where usuario_id = p_user_id;
    return;
  end if;
  if v_user_active is not true and coalesce(cardinality(v_location_ids), 0) > 0 then
    raise exception 'invalid_reference' using errcode = 'P0001';
  end if;
  select count(*) into v_location_count from public.locales
  where id = any(v_location_ids) and empresa_id = v_empresa_id;
  if v_location_count <> coalesce(cardinality(v_location_ids), 0) then
    raise exception 'invalid_reference' using errcode = 'P0001';
  end if;
  if exists (
    select 1 from public.locales as local
    where local.id = any(v_location_ids) and local.activo is not true
      and not exists (
        select 1 from public.usuario_locales as current_assignment
        where current_assignment.usuario_id = p_user_id and current_assignment.local_id = local.id
      )
  ) then raise exception 'invalid_reference' using errcode = 'P0001'; end if;
  delete from public.usuario_locales
  where usuario_id = p_user_id and not (local_id = any(v_location_ids));
  insert into public.usuario_locales (usuario_id, local_id)
  select p_user_id, location_id from unnest(v_location_ids) as location_id
  on conflict (usuario_id, local_id) do nothing;
end;
$$;

create function public.fleet_control_set_user_vehicle(p_user_id uuid, p_vehicle_id uuid default null)
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
  select u.* into v_user from public.usuarios as u where u.id = p_user_id and u.activo is true;
  if not found then raise exception 'invalid_user' using errcode = 'P0001'; end if;
  select codigo into v_role_code from public.roles where id = v_user.rol_id;
  if v_role_code <> 'chofer' then raise exception 'invalid_driver' using errcode = 'P0001'; end if;
  if p_vehicle_id is null then
    delete from public.usuario_vehiculos where usuario_id = p_user_id;
    return null;
  end if;
  select * into v_vehicle from public.vehiculos where id = p_vehicle_id and activo is true;
  if not found then raise exception 'invalid_vehicle' using errcode = 'P0001'; end if;
  if v_user.empresa_id is null or v_user.empresa_id <> v_vehicle.empresa_id then
    raise exception 'invalid_company' using errcode = 'P0001';
  end if;
  insert into public.usuario_vehiculos (usuario_id, vehiculo_id)
  values (p_user_id, p_vehicle_id)
  on conflict (usuario_id) do update set vehiculo_id = excluded.vehiculo_id, updated_at = now()
  returning * into v_assignment;
  return v_assignment;
end;
$$;

create function public.fleet_control_set_supervisor_choferes(
  p_supervisor_usuario_id uuid, p_chofer_usuario_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_supervisor_empresa_id uuid;
  v_choferes_validos integer;
  v_choferes_solicitados integer;
begin
  select u.empresa_id into v_supervisor_empresa_id
  from public.usuarios as u join public.roles as r on r.id = u.rol_id
  where u.id = p_supervisor_usuario_id and u.activo is true and r.codigo = 'supervisor';
  if v_supervisor_empresa_id is null then raise exception using errcode = 'P0001', message = 'invalid_supervisor'; end if;
  if exists (select 1 from unnest(coalesce(p_chofer_usuario_ids, '{}'::uuid[])) as requested(id) where requested.id = p_supervisor_usuario_id) then
    raise exception using errcode = 'P0001', message = 'invalid_driver_assignment';
  end if;
  select count(distinct requested.id) into v_choferes_solicitados
  from unnest(coalesce(p_chofer_usuario_ids, '{}'::uuid[])) as requested(id);
  select count(*) into v_choferes_validos
  from public.usuarios as u join public.roles as r on r.id = u.rol_id
  where u.id = any(coalesce(p_chofer_usuario_ids, '{}'::uuid[])) and u.activo is true
    and u.empresa_id = v_supervisor_empresa_id and r.codigo = 'chofer';
  if v_choferes_validos <> v_choferes_solicitados then raise exception using errcode = 'P0001', message = 'invalid_driver_assignment'; end if;
  delete from public.supervisor_choferes where supervisor_usuario_id = p_supervisor_usuario_id;
  insert into public.supervisor_choferes (supervisor_usuario_id, chofer_usuario_id)
  select p_supervisor_usuario_id, requested.id from unnest(coalesce(p_chofer_usuario_ids, '{}'::uuid[])) as requested(id)
  on conflict (supervisor_usuario_id, chofer_usuario_id) do nothing;
end;
$$;

create function public.fleet_control_import_locations(p_empresa_id uuid, p_locations jsonb)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row jsonb;
  v_index integer := 0;
  v_code text;
  v_name text;
  v_description text;
  v_address text;
  v_latitude double precision;
  v_longitude double precision;
  v_radius double precision;
  v_active boolean;
  v_errors jsonb := '[]'::jsonb;
  v_seen_codes text[] := '{}'::text[];
begin
  if p_empresa_id is null or jsonb_typeof(p_locations) <> 'array' then raise exception 'invalid_request' using errcode = 'P0001'; end if;
  if jsonb_array_length(p_locations) = 0 or jsonb_array_length(p_locations) > 500 then raise exception 'invalid_batch_size' using errcode = 'P0001'; end if;
  for v_row in select value from jsonb_array_elements(p_locations) loop
    v_index := v_index + 1;
    v_code := nullif(btrim(v_row->>'codigo'), ''); v_name := nullif(btrim(v_row->>'nombre'), '');
    v_description := nullif(btrim(v_row->>'descripcion'), ''); v_address := nullif(btrim(v_row->>'direccion'), '');
    begin v_latitude := (v_row->>'latitud')::double precision; exception when others then v_latitude := null; end;
    begin v_longitude := (v_row->>'longitud')::double precision; exception when others then v_longitude := null; end;
    begin v_radius := (v_row->>'radio_geocerca_metros')::double precision; exception when others then v_radius := null; end;
    v_active := case when v_row ? 'activo' and jsonb_typeof(v_row->'activo') = 'boolean' then (v_row->>'activo')::boolean when not (v_row ? 'activo') then true else null end;
    if v_code is null then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object('row', v_index, 'code', 'required_location_code', 'message', 'El codigo es obligatorio.'));
    elsif lower(v_code) = any(v_seen_codes) then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object('row', v_index, 'code', 'duplicate_in_file', 'message', format('El codigo %s esta duplicado en el archivo.', v_code)));
    else v_seen_codes := array_append(v_seen_codes, lower(v_code)); end if;
    if v_name is null then v_errors := v_errors || jsonb_build_array(jsonb_build_object('row', v_index, 'code', 'required_location_name')); end if;
    if v_latitude is null or v_latitude < -90 or v_latitude > 90 then v_errors := v_errors || jsonb_build_array(jsonb_build_object('row', v_index, 'code', 'invalid_latitude')); end if;
    if v_longitude is null or v_longitude < -180 or v_longitude > 180 then v_errors := v_errors || jsonb_build_array(jsonb_build_object('row', v_index, 'code', 'invalid_longitude')); end if;
    if v_radius is null or v_radius < 10 or v_radius > 5000 then v_errors := v_errors || jsonb_build_array(jsonb_build_object('row', v_index, 'code', 'invalid_geofence_radius')); end if;
    if v_active is null then v_errors := v_errors || jsonb_build_array(jsonb_build_object('row', v_index, 'code', 'invalid_active')); end if;
  end loop;
  for v_row, v_index in
    select value, ordinality::integer from jsonb_array_elements(p_locations) with ordinality
  loop
    v_code := nullif(btrim(v_row->>'codigo'), '');
    if v_code is not null and exists (
      select 1 from public.locales
      where empresa_id = p_empresa_id and lower(btrim(codigo)) = lower(v_code)
    ) then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object('row', v_index, 'code', 'duplicate_location_code', 'message', format('El codigo %s ya existe.', v_code)));
    end if;
  end loop;
  if jsonb_array_length(v_errors) > 0 then return jsonb_build_object('errors', v_errors); end if;
  insert into public.locales (
    empresa_id, codigo, nombre, descripcion, direccion, latitud, longitud, radio_metros, activo
  )
  select p_empresa_id, btrim(value->>'codigo'), btrim(value->>'nombre'),
    nullif(btrim(value->>'descripcion'), ''), nullif(btrim(value->>'direccion'), ''),
    (value->>'latitud')::double precision, (value->>'longitud')::double precision,
    (value->>'radio_geocerca_metros')::double precision, coalesce((value->>'activo')::boolean, true)
  from jsonb_array_elements(p_locations);
  return jsonb_build_object('imported_count', jsonb_array_length(p_locations));
exception when unique_violation then
  return jsonb_build_object('errors', jsonb_build_array(jsonb_build_object(
    'row', 0, 'code', 'duplicate_location_code', 'message', 'Uno de los codigos de local ya existe.'
  )));
end;
$$;

create function public.fleet_control_driver_claim_order(p_order_id uuid, p_driver_user_id uuid)
returns public.gestiones
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.pedidos%rowtype;
  v_driver public.usuarios%rowtype;
  v_driver_role text;
  v_vehicle public.vehiculos%rowtype;
  v_management public.gestiones%rowtype;
  v_queue_position integer;
  v_constraint_name text;
begin
  select o.* into v_order from public.pedidos as o where o.id = p_order_id for update;
  if not found then raise exception 'not_found' using errcode = 'P0001'; end if;
  if v_order.estado <> 'pendiente' or exists (select 1 from public.gestiones as g where g.pedido_id = v_order.id) then
    raise exception 'order_already_taken' using errcode = 'P0001';
  end if;
  select u.* into v_driver from public.usuarios as u where u.id = p_driver_user_id for update;
  if not found or v_driver.activo is not true then raise exception 'invalid_reference' using errcode = 'P0001'; end if;
  select r.codigo into v_driver_role from public.roles as r where r.id = v_driver.rol_id;
  if v_driver_role <> 'chofer' or v_driver.empresa_id is null or v_driver.empresa_id <> v_order.empresa_id then raise exception 'invalid_reference' using errcode = 'P0001'; end if;
  select v.* into v_vehicle from public.usuario_vehiculos as uv join public.vehiculos as v on v.id = uv.vehiculo_id where uv.usuario_id = v_driver.id for update of uv, v;
  if not found or v_vehicle.activo is not true or v_vehicle.empresa_id <> v_order.empresa_id then raise exception 'driver_vehicle_required' using errcode = 'P0001'; end if;
  if exists (select 1 from public.gestiones as g where g.vehiculo_id = v_vehicle.id and g.chofer_usuario_id <> v_driver.id and g.estado in ('aceptado', 'en_camino', 'en_gestion')) then raise exception 'vehicle_busy' using errcode = 'P0001'; end if;
  select coalesce(max(g.queue_position), 0) + 1 into v_queue_position from public.gestiones as g where g.chofer_usuario_id = v_driver.id and g.estado in ('asignado', 'aceptado', 'en_camino', 'en_gestion');
  begin
    insert into public.gestiones (pedido_id, empresa_id, local_id, chofer_usuario_id, vehiculo_id, asignado_por_usuario_id, queue_position)
    values (v_order.id, v_order.empresa_id, v_order.local_id, v_driver.id, v_vehicle.id, v_driver.id, v_queue_position)
    returning * into v_management;
  exception when unique_violation then
    get stacked diagnostics v_constraint_name = constraint_name;
    if v_constraint_name = 'gestiones_pedido_unique' then raise exception 'order_already_taken' using errcode = 'P0001';
    elsif v_constraint_name = 'gestiones_chofer_queue_position_unique' then raise exception 'queue_position_conflict' using errcode = 'P0001';
    elsif v_constraint_name = 'gestiones_vehiculo_operativo_unique' then raise exception 'vehicle_busy' using errcode = 'P0001'; end if;
    raise;
  end;
  update public.pedidos set estado = 'asignado', updated_at = now() where id = v_order.id;
  insert into public.gestion_eventos (gestion_id, usuario_id, estado_nuevo) values (v_management.id, v_driver.id, 'asignado');
  return v_management;
end;
$$;

-- The pre-002 definition is deliberately retained. 002 replaces it with
-- queue-position allocation for manual assignments.
create function public.fleet_control_create_gestion(
  p_order_id uuid, p_driver_user_id uuid, p_vehicle_id uuid, p_assigned_by_user_id uuid
)
returns public.gestiones
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.pedidos%rowtype;
  v_driver record;
  v_vehicle record;
  v_management public.gestiones%rowtype;
begin
  select * into v_order from public.pedidos where id = p_order_id for update;
  if not found then raise exception 'not_found' using errcode = 'P0001'; end if;
  if v_order.estado <> 'pendiente' then raise exception 'active_management' using errcode = 'P0001'; end if;
  select u.id, u.empresa_id, u.activo, r.codigo into v_driver from public.usuarios as u join public.roles as r on r.id = u.rol_id where u.id = p_driver_user_id;
  if not found or v_driver.activo is not true or v_driver.codigo <> 'chofer' or v_driver.empresa_id <> v_order.empresa_id then raise exception 'invalid_reference' using errcode = 'P0001'; end if;
  select id, empresa_id, activo into v_vehicle from public.vehiculos where id = p_vehicle_id;
  if not found or v_vehicle.activo is not true or v_vehicle.empresa_id <> v_order.empresa_id then raise exception 'invalid_reference' using errcode = 'P0001'; end if;
  if exists (select 1 from public.gestiones where chofer_usuario_id = p_driver_user_id and estado in ('aceptado', 'en_camino', 'en_gestion')) then raise exception 'driver_busy' using errcode = 'P0001'; end if;
  if exists (select 1 from public.gestiones where vehiculo_id = p_vehicle_id and estado in ('aceptado', 'en_camino', 'en_gestion')) then raise exception 'vehicle_busy' using errcode = 'P0001'; end if;
  insert into public.gestiones (pedido_id, empresa_id, local_id, chofer_usuario_id, vehiculo_id, asignado_por_usuario_id)
  values (v_order.id, v_order.empresa_id, v_order.local_id, p_driver_user_id, p_vehicle_id, p_assigned_by_user_id)
  returning * into v_management;
  update public.pedidos set estado = 'asignado', updated_at = now() where id = v_order.id;
  insert into public.gestion_eventos (gestion_id, usuario_id, estado_nuevo) values (v_management.id, p_assigned_by_user_id, 'asignado');
  return v_management;
end;
$$;

create function public.fleet_control_update_gestion_status(p_management_id uuid, p_status text, p_user_id uuid)
returns public.gestiones
language plpgsql
security definer
set search_path = public
as $$
declare
  v_management public.gestiones%rowtype;
  v_timestamp timestamptz := now();
  v_estado_anterior text;
  v_constraint_name text;
begin
  select * into v_management from public.gestiones where id = p_management_id for update;
  if not found then raise exception 'not_found' using errcode = 'P0001'; end if;
  if v_management.chofer_usuario_id <> p_user_id then raise exception 'forbidden' using errcode = 'P0001'; end if;
  if not ((v_management.estado = 'asignado' and p_status = 'aceptado') or (v_management.estado = 'aceptado' and p_status = 'en_camino') or (v_management.estado = 'en_camino' and p_status = 'en_gestion') or (v_management.estado = 'en_gestion' and p_status = 'completado')) then raise exception 'invalid_transition' using errcode = 'P0001'; end if;
  perform 1 from public.usuarios as u where u.id = v_management.chofer_usuario_id for update;
  if p_status = 'aceptado' and exists (select 1 from public.gestiones as g where g.chofer_usuario_id = v_management.chofer_usuario_id and g.id <> v_management.id and g.estado in ('aceptado', 'en_camino', 'en_gestion')) then raise exception 'active_management_exists' using errcode = 'P0001'; end if;
  v_estado_anterior := v_management.estado;
  begin
    update public.gestiones set estado = p_status,
      aceptado_at = case when p_status = 'aceptado' then coalesce(aceptado_at, v_timestamp) else aceptado_at end,
      en_camino_at = case when p_status = 'en_camino' then coalesce(en_camino_at, v_timestamp) else en_camino_at end,
      en_gestion_at = case when p_status = 'en_gestion' then coalesce(en_gestion_at, v_timestamp) else en_gestion_at end,
      completado_at = case when p_status = 'completado' then coalesce(completado_at, v_timestamp) else completado_at end,
      queue_position = case when p_status in ('completado', 'cancelado') then null else queue_position end,
      updated_at = v_timestamp
    where id = v_management.id returning * into v_management;
  exception when unique_violation then
    get stacked diagnostics v_constraint_name = constraint_name;
    if v_constraint_name = 'gestiones_chofer_operativo_unique' then raise exception 'active_management_exists' using errcode = 'P0001';
    elsif v_constraint_name = 'gestiones_vehiculo_operativo_unique' then raise exception 'vehicle_busy' using errcode = 'P0001'; end if;
    raise;
  end;
  update public.pedidos set estado = p_status, updated_at = v_timestamp where id = v_management.pedido_id;
  insert into public.gestion_eventos (gestion_id, usuario_id, estado_anterior, estado_nuevo) values (v_management.id, p_user_id, v_estado_anterior, p_status);
  if p_status in ('completado', 'cancelado') then
    with ranked as (
      select g.id, row_number() over (order by g.queue_position nulls last, g.created_at, g.id)::integer as queue_position
      from public.gestiones as g where g.chofer_usuario_id = v_management.chofer_usuario_id and g.estado = 'asignado'
    ) update public.gestiones as g set queue_position = ranked.queue_position, updated_at = v_timestamp from ranked where g.id = ranked.id;
  end if;
  return v_management;
end;
$$;

-- This is the pre-003 location RPC. 003 adds last_seen_at and replaces it.
create function public.fleet_control_update_driver_location(
  p_user_id uuid, p_latitude double precision, p_longitude double precision,
  p_accuracy double precision, p_speed double precision, p_heading double precision,
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
  v_location public.chofer_ubicaciones%rowtype;
  v_now timestamptz := now();
begin
  if p_latitude is null or p_latitude < -90 or p_latitude > 90 then raise exception 'invalid_location'; end if;
  if p_longitude is null or p_longitude < -180 or p_longitude > 180 then raise exception 'invalid_location'; end if;
  if p_accuracy is not null and p_accuracy < 0 then raise exception 'invalid_location'; end if;
  if p_speed is not null and p_speed < 0 then raise exception 'invalid_location'; end if;
  if p_heading is not null and (p_heading < 0 or p_heading >= 360) then raise exception 'invalid_location'; end if;
  if p_captured_at is null or p_captured_at > v_now + interval '5 minutes' then raise exception 'invalid_captured_at'; end if;
  select u.id, u.empresa_id, u.activo, r.codigo into v_driver
  from public.usuarios as u join public.roles as r on r.id = u.rol_id where u.id = p_user_id;
  if not found or v_driver.activo is not true or v_driver.codigo <> 'chofer' or v_driver.empresa_id is null then raise exception 'forbidden'; end if;
  select id, vehiculo_id into v_management_id, v_vehicle_id from public.gestiones
  where chofer_usuario_id = p_user_id and estado in ('asignado', 'aceptado', 'en_camino', 'en_gestion')
  order by updated_at desc limit 1;
  insert into public.chofer_ubicaciones as location (
    empresa_id, chofer_usuario_id, gestion_id, vehiculo_id, latitud, longitud,
    precision_metros, velocidad_mps, rumbo_grados, captured_at, updated_at
  ) values (
    v_driver.empresa_id, p_user_id, v_management_id, v_vehicle_id, p_latitude,
    p_longitude, p_accuracy, p_speed, p_heading, p_captured_at, v_now
  ) on conflict (chofer_usuario_id) do update set
    empresa_id = excluded.empresa_id, gestion_id = excluded.gestion_id,
    vehiculo_id = excluded.vehiculo_id, latitud = excluded.latitud,
    longitud = excluded.longitud, precision_metros = excluded.precision_metros,
    velocidad_mps = excluded.velocidad_mps, rumbo_grados = excluded.rumbo_grados,
    captured_at = excluded.captured_at, updated_at = excluded.updated_at
  returning * into v_location;
  return v_location;
end;
$$;

alter table public.roles owner to fleet_owner;
alter table public.empresas owner to fleet_owner;
alter table public.app_views owner to fleet_owner;
alter table public.locales owner to fleet_owner;
alter table public.usuarios owner to fleet_owner;
alter table public.vehiculos owner to fleet_owner;
alter table public.sesiones owner to fleet_owner;
alter table public.asistencias owner to fleet_owner;
alter table public.usuario_locales owner to fleet_owner;
alter table public.usuario_vehiculos owner to fleet_owner;
alter table public.supervisor_choferes owner to fleet_owner;
alter table public.pedido_descripciones owner to fleet_owner;
alter table public.pedidos owner to fleet_owner;
alter table public.gestiones owner to fleet_owner;
alter table public.gestion_eventos owner to fleet_owner;
alter table public.chofer_ubicaciones owner to fleet_owner;
alter table public.role_views owner to fleet_owner;

alter function public.fleet_control_set_updated_at() owner to fleet_owner;
alter function public.fleet_control_role_views_set_updated_at() owner to fleet_owner;
alter function public.login_usuario(text, text) owner to fleet_owner;
alter function public.fleet_control_create_usuario(text, text, text, uuid, uuid, boolean) owner to fleet_owner;
alter function public.fleet_control_set_usuario_password(uuid, text) owner to fleet_owner;
alter function public.fleet_control_verify_usuario_password(uuid, text) owner to fleet_owner;
alter function public.fleet_control_set_user_locations(uuid, uuid[]) owner to fleet_owner;
alter function public.fleet_control_set_user_vehicle(uuid, uuid) owner to fleet_owner;
alter function public.fleet_control_set_supervisor_choferes(uuid, uuid[]) owner to fleet_owner;
alter function public.fleet_control_import_locations(uuid, jsonb) owner to fleet_owner;
alter function public.fleet_control_driver_claim_order(uuid, uuid) owner to fleet_owner;
alter function public.fleet_control_create_gestion(uuid, uuid, uuid, uuid) owner to fleet_owner;
alter function public.fleet_control_update_gestion_status(uuid, text, uuid) owner to fleet_owner;
alter function public.fleet_control_update_driver_location(uuid, double precision, double precision, double precision, double precision, double precision, timestamptz) owner to fleet_owner;

revoke all on all tables in schema public from public;
revoke all on all sequences in schema public from public;

grant select on public.roles, public.app_views, public.gestiones, public.gestion_eventos,
  public.usuario_locales, public.usuario_vehiculos, public.supervisor_choferes,
  public.chofer_ubicaciones to fleet_app;
grant select, insert, update on public.empresas, public.locales, public.usuarios,
  public.vehiculos, public.sesiones, public.pedido_descripciones, public.pedidos,
  public.role_views to fleet_app;
grant select, insert on public.asistencias to fleet_app;
grant usage, select, update on all sequences in schema public to fleet_app;

revoke all on function public.login_usuario(text, text) from public;
revoke all on function public.fleet_control_create_usuario(text, text, text, uuid, uuid, boolean) from public;
revoke all on function public.fleet_control_set_usuario_password(uuid, text) from public;
revoke all on function public.fleet_control_verify_usuario_password(uuid, text) from public;
revoke all on function public.fleet_control_set_user_locations(uuid, uuid[]) from public;
revoke all on function public.fleet_control_set_user_vehicle(uuid, uuid) from public;
revoke all on function public.fleet_control_set_supervisor_choferes(uuid, uuid[]) from public;
revoke all on function public.fleet_control_import_locations(uuid, jsonb) from public;
revoke all on function public.fleet_control_driver_claim_order(uuid, uuid) from public;
revoke all on function public.fleet_control_create_gestion(uuid, uuid, uuid, uuid) from public;
revoke all on function public.fleet_control_update_gestion_status(uuid, text, uuid) from public;
revoke all on function public.fleet_control_update_driver_location(uuid, double precision, double precision, double precision, double precision, double precision, timestamptz) from public;

grant execute on function public.login_usuario(text, text),
  public.fleet_control_create_usuario(text, text, text, uuid, uuid, boolean),
  public.fleet_control_set_usuario_password(uuid, text),
  public.fleet_control_verify_usuario_password(uuid, text),
  public.fleet_control_set_user_locations(uuid, uuid[]),
  public.fleet_control_set_user_vehicle(uuid, uuid),
  public.fleet_control_set_supervisor_choferes(uuid, uuid[]),
  public.fleet_control_import_locations(uuid, jsonb),
  public.fleet_control_driver_claim_order(uuid, uuid),
  public.fleet_control_create_gestion(uuid, uuid, uuid, uuid),
  public.fleet_control_update_gestion_status(uuid, text, uuid),
  public.fleet_control_update_driver_location(uuid, double precision, double precision, double precision, double precision, double precision, timestamptz)
to fleet_app;
