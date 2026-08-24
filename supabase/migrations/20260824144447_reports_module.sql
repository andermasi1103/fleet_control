begin;

insert into public.app_views (codigo, nombre, descripcion, ruta, icono, orden)
values ('reports', 'Reportes', 'Reportes operativos descargables.', '/reports', 'assessment', 130)
on conflict (codigo) do update
set nombre = excluded.nombre,
    descripcion = excluded.descripcion,
    ruta = excluded.ruta,
    icono = excluded.icono,
    orden = excluded.orden;

insert into public.role_views (role_id, view_id, visible)
select r.id, v.id, r.codigo in ('super_admin', 'admin', 'supervisor')
from public.roles r
join public.app_views v on v.codigo = 'reports'
on conflict (role_id, view_id) do update
set visible = excluded.visible,
    updated_at = now();

commit;
