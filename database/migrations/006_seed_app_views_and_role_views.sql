-- Mandatory navigation catalog. Existing catalog rows and assignments are
-- preserved; codes resolve the stable application relationships.
insert into public.app_views (codigo, nombre, descripcion, ruta, icono, orden, activo)
values
  ('home', 'Inicio', 'Pantalla principal de Fleet Control.', '/home', 'home', 10, true),
  ('attendance', 'Asistencia', 'Marcación e historial de asistencia.', '/attendance', 'fingerprint', 20, true),
  ('companies', 'Empresas', 'Administración de empresas.', '/companies', 'business', 30, true),
  ('locations', 'Locales', 'Administración de locales.', '/locations', 'location_on', 40, true),
  ('users', 'Usuarios', 'Administración de usuarios.', '/users', 'people', 50, true),
  ('vehicles', 'Vehículos', 'Administración de vehículos.', '/vehicles', 'local_shipping', 60, true),
  ('orders', 'Pedidos', 'Gestión de pedidos.', '/orders', 'receipt_long', 70, true),
  ('driver_orders', 'Pedidos disponibles', 'Pedidos que puede tomar un chofer.', '/driver-orders', 'assignment_turned_in', 80, true),
  ('managements', 'Gestiones', 'Seguimiento de gestiones.', '/managements', 'assignment', 90, true),
  ('fleet_map', 'Mapa de Flota', 'Ubicación de la flota.', '/fleet-map', 'map', 100, true),
  ('settings', 'Configuración', 'Configuración y perfil.', '/settings', 'settings', 110, true),
  ('role_views_management', 'Roles y vistas', 'Configuración de vistas disponibles por rol.', '/settings/role-views', 'admin_panel_settings', 120, true),
  ('reports', 'Reportes', 'Reportes operativos descargables.', '/reports', 'assessment', 130, true)
on conflict (codigo) do nothing;

insert into public.role_views (role_id, view_id, visible)
select role_catalog.id, app_view_catalog.id, true
from public.roles as role_catalog
cross join public.app_views as app_view_catalog
where role_catalog.codigo in ('user', 'local', 'chofer', 'supervisor', 'admin', 'super_admin')
  and app_view_catalog.codigo in (
    'home', 'attendance', 'companies', 'locations', 'users', 'vehicles', 'orders',
    'driver_orders', 'managements', 'fleet_map', 'settings', 'role_views_management', 'reports'
  )
on conflict (role_id, view_id) do nothing;
