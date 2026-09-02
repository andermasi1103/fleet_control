-- Mandatory base catalog for application authorization. Existing role records
-- are intentionally preserved; codigo is the natural key of this catalog.
insert into public.roles (codigo, nombre, descripcion, nivel, activo)
values
  ('user', 'Usuario', 'Usuario operativo estándar', 20, true),
  ('local', 'Local', 'Usuario de sucursal que crea y consulta pedidos de sus locales asignados.', 30, true),
  ('chofer', 'Chofer', 'Usuario operativo de conducción', 40, true),
  ('supervisor', 'Supervisor', 'Responsable de supervisión y operación', 60, true),
  ('admin', 'Administrador', 'Administrador de una empresa', 80, true),
  ('super_admin', 'Super Administrador', 'Administrador global de la plataforma', 100, true)
on conflict (codigo) do nothing;
