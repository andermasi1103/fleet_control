-- Ejecutar manualmente una sola vez en el SQL Editor, tras revisar este archivo.
-- Es transaccional: ante cualquier error se revierten todos los cambios.
-- No elimina tablas, filas ni sesiones existentes.
begin;

do $$
declare
  table_name text;
begin
  foreach table_name in array array['empresas', 'locales', 'usuarios', 'roles', 'sesiones', 'asistencias']
  loop
    if to_regclass('public.' || table_name) is null then
      raise exception 'Falta la tabla pública requerida: %', table_name;
    end if;
  end loop;
end;
$$;

create extension if not exists pgcrypto;

-- Sólo añade metadatos administrativos ausentes.
alter table public.empresas add column if not exists activo boolean not null default true;
alter table public.empresas add column if not exists created_at timestamptz not null default now();
alter table public.empresas add column if not exists updated_at timestamptz not null default now();
alter table public.usuarios add column if not exists password_hash text;
alter table public.usuarios alter column empresa_id drop not null;
alter table public.sesiones add column if not exists last_used_at timestamptz;
alter table public.asistencias add column if not exists local_id uuid;

-- Vehículos es la única tabla que puede no existir todavía.
create table if not exists public.vehiculos (
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
  constraint vehiculos_anio_check check (anio is null or anio between 1900 and 2100)
);

-- Completa una tabla de vehículos previa sin reemplazar ni eliminar columnas.
alter table public.vehiculos add column if not exists empresa_id uuid references public.empresas(id) on delete restrict;
alter table public.vehiculos add column if not exists patente text;
alter table public.vehiculos add column if not exists marca text;
alter table public.vehiculos add column if not exists modelo text;
alter table public.vehiculos add column if not exists anio integer;
alter table public.vehiculos add column if not exists descripcion text;
alter table public.vehiculos add column if not exists activo boolean not null default true;
alter table public.vehiculos add column if not exists created_at timestamptz not null default now();
alter table public.vehiculos add column if not exists updated_at timestamptz not null default now();

-- Precondiciones: si hay duplicados, aborta antes de crear índices únicos.
do $$
begin
  if exists (
    select 1 from public.usuarios
    group by lower(usuario) having count(*) > 1
  ) then
    raise exception 'Hay usuarios duplicados sin distinguir mayúsculas/minúsculas';
  end if;
  if exists (
    select 1 from public.vehiculos
    where empresa_id is not null and patente is not null
    group by empresa_id, lower(patente) having count(*) > 1
  ) then
    raise exception 'Hay vehículos duplicados por empresa y patente';
  end if;
end;
$$;

create unique index if not exists usuarios_usuario_unique_ci on public.usuarios (lower(usuario));
create index if not exists usuarios_empresa_id_idx on public.usuarios (empresa_id);
create index if not exists sesiones_token_hash_idx on public.sesiones (token_hash);
create index if not exists sesiones_usuario_activa_idx on public.sesiones (usuario_id) where revoked_at is null;
create index if not exists asistencias_usuario_fecha_idx on public.asistencias (usuario_id, fecha_hora desc);
create index if not exists asistencias_empresa_fecha_idx on public.asistencias (empresa_id, fecha_hora desc);
create index if not exists asistencias_local_fecha_idx on public.asistencias (local_id, fecha_hora desc);
create index if not exists locales_empresa_idx on public.locales (empresa_id);
create unique index if not exists vehiculos_empresa_patente_unique_ci on public.vehiculos (empresa_id, lower(patente));
create index if not exists vehiculos_empresa_idx on public.vehiculos (empresa_id);

-- NOT VALID garantiza las nuevas escrituras sin rechazar datos históricos.
do $$
begin
  if not exists (select 1 from pg_constraint where conrelid = 'public.asistencias'::regclass and conname = 'asistencias_tipo_check') then
    alter table public.asistencias add constraint asistencias_tipo_check check (tipo in ('entrada', 'salida')) not valid;
  end if;
  if not exists (select 1 from pg_constraint where conrelid = 'public.asistencias'::regclass and conname = 'asistencias_local_id_fkey') then
    alter table public.asistencias add constraint asistencias_local_id_fkey foreign key (local_id) references public.locales(id) on delete restrict not valid;
  end if;
  if not exists (select 1 from pg_constraint where conrelid = 'public.locales'::regclass and conname = 'locales_latitud_check') then
    alter table public.locales add constraint locales_latitud_check check (latitud between -90 and 90) not valid;
  end if;
  if not exists (select 1 from pg_constraint where conrelid = 'public.locales'::regclass and conname = 'locales_longitud_check') then
    alter table public.locales add constraint locales_longitud_check check (longitud between -180 and 180) not valid;
  end if;
  if not exists (select 1 from pg_constraint where conrelid = 'public.locales'::regclass and conname = 'locales_radio_metros_check') then
    alter table public.locales add constraint locales_radio_metros_check check (radio_metros > 0) not valid;
  end if;
  if not exists (select 1 from pg_constraint where conrelid = 'public.vehiculos'::regclass and conname = 'vehiculos_anio_check') then
    alter table public.vehiculos add constraint vehiculos_anio_check check (anio is null or anio between 1900 and 2100) not valid;
  end if;
end;
$$;

create or replace function public.fleet_control_set_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists fleet_control_empresas_updated_at on public.empresas;
create trigger fleet_control_empresas_updated_at before update on public.empresas
for each row execute function public.fleet_control_set_updated_at();
drop trigger if exists fleet_control_locales_updated_at on public.locales;
create trigger fleet_control_locales_updated_at before update on public.locales
for each row execute function public.fleet_control_set_updated_at();
drop trigger if exists fleet_control_vehiculos_updated_at on public.vehiculos;
create trigger fleet_control_vehiculos_updated_at before update on public.vehiculos
for each row execute function public.fleet_control_set_updated_at();

create or replace function public.fleet_control_create_usuario(
  p_nombre text, p_usuario text, p_password text, p_empresa_id uuid,
  p_rol_id uuid, p_activo boolean default true
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  new_id uuid;
begin
  insert into public.usuarios (nombre, usuario, password_hash, empresa_id, rol_id, activo)
  values (p_nombre, p_usuario, crypt(p_password, gen_salt('bf', 12)), p_empresa_id, p_rol_id, p_activo)
  returning id into new_id;
  return new_id;
end;
$$;

create or replace function public.fleet_control_set_usuario_password(
  p_user_id uuid, p_password text
) returns void language plpgsql security definer set search_path = public as $$
begin
  update public.usuarios set password_hash = crypt(p_password, gen_salt('bf', 12)) where id = p_user_id;
  if not found then
    raise exception 'user_not_found';
  end if;
  update public.sesiones set revoked_at = now() where usuario_id = p_user_id and revoked_at is null;
end;
$$;

revoke all on function public.fleet_control_create_usuario(text, text, text, uuid, uuid, boolean) from public;
revoke all on function public.fleet_control_set_usuario_password(uuid, text) from public;
grant execute on function public.fleet_control_create_usuario(text, text, text, uuid, uuid, boolean) to service_role;
grant execute on function public.fleet_control_set_usuario_password(uuid, text) to service_role;

alter table public.empresas enable row level security;
alter table public.locales enable row level security;
alter table public.usuarios enable row level security;
alter table public.sesiones enable row level security;
alter table public.asistencias enable row level security;
alter table public.vehiculos enable row level security;

commit;
