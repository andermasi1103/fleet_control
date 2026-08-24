begin;

create extension if not exists pgcrypto;

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

create table public.role_views (
  id uuid primary key default gen_random_uuid(),
  role_id uuid not null references public.roles(id) on delete cascade,
  view_id uuid not null references public.app_views(id) on delete cascade,
  visible boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint role_views_role_view_unique unique (role_id, view_id)
);

create index role_views_role_visible_idx on public.role_views (role_id, visible);
create index role_views_view_id_idx on public.role_views (view_id);
create index app_views_active_order_idx on public.app_views (activo, orden);

create or replace function public.fleet_control_role_views_set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger fleet_control_app_views_updated_at
before update on public.app_views
for each row execute function public.fleet_control_role_views_set_updated_at();

create trigger fleet_control_role_views_updated_at
before update on public.role_views
for each row execute function public.fleet_control_role_views_set_updated_at();

alter table public.app_views enable row level security;
alter table public.role_views enable row level security;
revoke all on table public.app_views, public.role_views from public, anon, authenticated;

insert into public.app_views (codigo, nombre, descripcion, ruta, icono, orden)
values
  ('home', 'Inicio', 'Pantalla principal de Fleet Control.', '/home', 'home', 10),
  ('attendance', 'Asistencia', 'Marcación e historial de asistencia.', '/attendance', 'fingerprint', 20),
  ('companies', 'Empresas', 'Administración de empresas.', '/companies', 'business', 30),
  ('locations', 'Locales', 'Administración de locales.', '/locations', 'location_on', 40),
  ('users', 'Usuarios', 'Administración de usuarios.', '/users', 'people', 50),
  ('vehicles', 'Vehículos', 'Administración de vehículos.', '/vehicles', 'local_shipping', 60),
  ('orders', 'Pedidos', 'Gestión de pedidos.', '/orders', 'receipt_long', 70),
  ('driver_orders', 'Pedidos disponibles', 'Pedidos que puede tomar un chofer.', '/driver-orders', 'assignment_turned_in', 80),
  ('managements', 'Gestiones', 'Seguimiento de gestiones.', '/managements', 'assignment', 90),
  ('fleet_map', 'Mapa de Flota', 'Ubicación de la flota.', '/fleet-map', 'map', 100),
  ('settings', 'Configuración', 'Configuración y perfil.', '/settings', 'settings', 110),
  ('role_views_management', 'Roles y vistas', 'Configuración de vistas disponibles por rol.', '/settings/role-views', 'admin_panel_settings', 120)
on conflict (codigo) do nothing;

with desired(role_code, view_code) as (
  values
    ('super_admin', 'home'),
    ('super_admin', 'attendance'),
    ('super_admin', 'companies'),
    ('super_admin', 'locations'),
    ('super_admin', 'users'),
    ('super_admin', 'vehicles'),
    ('super_admin', 'orders'),
    ('super_admin', 'driver_orders'),
    ('super_admin', 'managements'),
    ('super_admin', 'fleet_map'),
    ('super_admin', 'settings'),
    ('super_admin', 'role_views_management'),
    ('admin', 'home'),
    ('admin', 'attendance'),
    ('admin', 'companies'),
    ('admin', 'locations'),
    ('admin', 'users'),
    ('admin', 'vehicles'),
    ('admin', 'orders'),
    ('admin', 'managements'),
    ('admin', 'fleet_map'),
    ('admin', 'settings'),
    ('supervisor', 'home'),
    ('supervisor', 'attendance'),
    ('supervisor', 'locations'),
    ('supervisor', 'users'),
    ('supervisor', 'vehicles'),
    ('supervisor', 'orders'),
    ('supervisor', 'managements'),
    ('supervisor', 'fleet_map'),
    ('supervisor', 'settings'),
    ('chofer', 'home'),
    ('chofer', 'attendance'),
    ('chofer', 'driver_orders'),
    ('chofer', 'managements'),
    ('chofer', 'settings'),
    ('user', 'home'),
    ('user', 'attendance'),
    ('user', 'orders'),
    ('user', 'settings')
)
insert into public.role_views (role_id, view_id, visible)
select roles.id, app_views.id, desired.view_code is not null
from public.roles as roles
cross join public.app_views as app_views
left join desired
  on desired.role_code = roles.codigo
 and desired.view_code = app_views.codigo
where roles.codigo in ('super_admin', 'admin', 'supervisor', 'chofer', 'user')
on conflict (role_id, view_id) do nothing;

commit;
