begin;

-- El esquema existente no tenía código de negocio para locales. Se mantiene
-- nullable para no invalidar locales históricos, pero toda nueva importación
-- exige uno y la unicidad se protege por empresa, sin UUIDs de negocio.
alter table public.locales add column if not exists codigo text;
alter table public.locales add column if not exists descripcion text;

do $$
begin
  if not exists (
    select 1 from pg_constraint
    where conrelid = 'public.locales'::regclass
      and conname = 'locales_codigo_not_empty'
  ) then
    alter table public.locales
      add constraint locales_codigo_not_empty
      check (codigo is null or length(btrim(codigo)) > 0) not valid;
  end if;
end;
$$;

create unique index if not exists locales_empresa_codigo_unique_ci
  on public.locales (empresa_id, lower(btrim(codigo)))
  where codigo is not null;

insert into public.roles (codigo, nombre, descripcion, nivel, activo)
values (
  'local',
  'Local',
  'Usuario de sucursal que crea y consulta pedidos de sus locales asignados.',
  30,
  true
)
on conflict (codigo) do update
set nombre = excluded.nombre,
    descripcion = excluded.descripcion,
    nivel = excluded.nivel,
    activo = true;

with desired(view_code) as (
  values ('home'), ('orders'), ('settings')
)
insert into public.role_views (role_id, view_id, visible)
select roles.id, app_views.id, desired.view_code is not null
from public.roles as roles
cross join public.app_views as app_views
left join desired on desired.view_code = app_views.codigo
where roles.codigo = 'local'
on conflict (role_id, view_id) do update
set visible = excluded.visible,
    updated_at = now();

create or replace function public.fleet_control_import_locations(
  p_empresa_id uuid,
  p_locations jsonb
) returns jsonb
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
  if p_empresa_id is null or jsonb_typeof(p_locations) <> 'array' then
    raise exception 'invalid_request' using errcode = 'P0001';
  end if;
  if jsonb_array_length(p_locations) = 0 or jsonb_array_length(p_locations) > 500 then
    raise exception 'invalid_batch_size' using errcode = 'P0001';
  end if;

  for v_row in select value from jsonb_array_elements(p_locations)
  loop
    v_index := v_index + 1;
    v_code := nullif(btrim(v_row->>'codigo'), '');
    v_name := nullif(btrim(v_row->>'nombre'), '');
    v_description := nullif(btrim(v_row->>'descripcion'), '');
    v_address := nullif(btrim(v_row->>'direccion'), '');
    begin v_latitude := (v_row->>'latitud')::double precision; exception when others then v_latitude := null; end;
    begin v_longitude := (v_row->>'longitud')::double precision; exception when others then v_longitude := null; end;
    begin v_radius := (v_row->>'radio_geocerca_metros')::double precision; exception when others then v_radius := null; end;
    v_active := case
      when v_row ? 'activo' and jsonb_typeof(v_row->'activo') = 'boolean' then (v_row->>'activo')::boolean
      when not (v_row ? 'activo') then true
      else null
    end;

    if v_code is null then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object('row', v_index, 'code', 'required_location_code', 'message', 'El código es obligatorio.'));
    elsif lower(v_code) = any(v_seen_codes) then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object('row', v_index, 'code', 'duplicate_in_file', 'message', format('El código %s está duplicado en el archivo.', v_code)));
    else
      v_seen_codes := array_append(v_seen_codes, lower(v_code));
    end if;
    if v_name is null then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object('row', v_index, 'code', 'required_location_name', 'message', 'El nombre es obligatorio.'));
    end if;
    if v_latitude is null or v_latitude < -90 or v_latitude > 90 then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object('row', v_index, 'code', 'invalid_latitude', 'message', 'La latitud debe estar entre -90 y 90.'));
    end if;
    if v_longitude is null or v_longitude < -180 or v_longitude > 180 then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object('row', v_index, 'code', 'invalid_longitude', 'message', 'La longitud debe estar entre -180 y 180.'));
    end if;
    if v_radius is null or v_radius < 10 or v_radius > 5000 then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object('row', v_index, 'code', 'invalid_geofence_radius', 'message', 'El radio de geocerca debe estar entre 10 y 5000 metros.'));
    end if;
    if v_active is null then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object('row', v_index, 'code', 'invalid_active', 'message', 'Activo debe ser verdadero o falso.'));
    end if;
  end loop;

  for v_row, v_index in
    select value, ordinality::integer
    from jsonb_array_elements(p_locations) with ordinality
  loop
    v_code := nullif(btrim(v_row->>'codigo'), '');
    if v_code is not null and exists (
      select 1 from public.locales
      where empresa_id = p_empresa_id
        and lower(btrim(codigo)) = lower(v_code)
    ) then
      v_errors := v_errors || jsonb_build_array(jsonb_build_object('row', v_index, 'code', 'duplicate_location_code', 'message', format('El código %s ya existe.', v_code)));
    end if;
  end loop;

  if jsonb_array_length(v_errors) > 0 then
    return jsonb_build_object('errors', v_errors);
  end if;

  insert into public.locales (
    empresa_id, codigo, nombre, descripcion, direccion, latitud, longitud, radio_metros, activo
  )
  select
    p_empresa_id,
    btrim(value->>'codigo'),
    btrim(value->>'nombre'),
    nullif(btrim(value->>'descripcion'), ''),
    nullif(btrim(value->>'direccion'), ''),
    (value->>'latitud')::double precision,
    (value->>'longitud')::double precision,
    (value->>'radio_geocerca_metros')::double precision,
    coalesce((value->>'activo')::boolean, true)
  from jsonb_array_elements(p_locations);

  return jsonb_build_object('imported_count', jsonb_array_length(p_locations));
exception
  when unique_violation then
    return jsonb_build_object('errors', jsonb_build_array(jsonb_build_object(
      'row', 0,
      'code', 'duplicate_location_code',
      'message', 'Uno de los códigos de local ya existe.'
    )));
end;
$$;

revoke all on function public.fleet_control_import_locations(uuid, jsonb) from public, anon, authenticated;
grant execute on function public.fleet_control_import_locations(uuid, jsonb) to service_role;

commit;
