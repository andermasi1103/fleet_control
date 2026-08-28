-- Delete only records tied to the explicit local UAT markers.
with uat_users as (
  select id from public.usuarios where usuario in ('uat_super_admin', 'uat_admin', 'uat_supervisor', 'uat_chofer')
), uat_company as (
  select id from public.empresas where nombre = 'UAT Empresa Fleet Control'
)
delete from public.notification_devices where usuario_id in (select id from uat_users);

with uat_users as (
  select id from public.usuarios where usuario in ('uat_super_admin', 'uat_admin', 'uat_supervisor', 'uat_chofer')
)
delete from public.notificaciones where usuario_id in (select id from uat_users);

with uat_users as (
  select id from public.usuarios where usuario in ('uat_super_admin', 'uat_admin', 'uat_supervisor', 'uat_chofer')
)
delete from public.sesiones where usuario_id in (select id from uat_users);

with uat_company as (
  select id from public.empresas where nombre = 'UAT Empresa Fleet Control'
)
delete from public.asistencias where empresa_id in (select id from uat_company);

with uat_users as (
  select id from public.usuarios where usuario in ('uat_super_admin', 'uat_admin', 'uat_supervisor', 'uat_chofer')
)
delete from public.chofer_ubicaciones where chofer_usuario_id in (select id from uat_users);

with uat_company as (
  select id from public.empresas where nombre = 'UAT Empresa Fleet Control'
)
delete from public.gestion_eventos where gestion_id in (
  select id from public.gestiones where empresa_id in (select id from uat_company)
);

with uat_company as (
  select id from public.empresas where nombre = 'UAT Empresa Fleet Control'
)
delete from public.gestiones where empresa_id in (select id from uat_company);

with uat_company as (
  select id from public.empresas where nombre = 'UAT Empresa Fleet Control'
)
delete from public.pedidos where empresa_id in (select id from uat_company);

with uat_company as (
  select id from public.empresas where nombre = 'UAT Empresa Fleet Control'
)
delete from public.pedido_descripciones where empresa_id in (select id from uat_company);

with uat_users as (
  select id from public.usuarios where usuario in ('uat_super_admin', 'uat_admin', 'uat_supervisor', 'uat_chofer')
)
delete from public.supervisor_choferes
where supervisor_usuario_id in (select id from uat_users)
   or chofer_usuario_id in (select id from uat_users);

with uat_users as (
  select id from public.usuarios where usuario in ('uat_super_admin', 'uat_admin', 'uat_supervisor', 'uat_chofer')
)
delete from public.usuario_vehiculos where usuario_id in (select id from uat_users);

with uat_users as (
  select id from public.usuarios where usuario in ('uat_super_admin', 'uat_admin', 'uat_supervisor', 'uat_chofer')
)
delete from public.usuario_locales where usuario_id in (select id from uat_users);

delete from public.usuarios where usuario in ('uat_super_admin', 'uat_admin', 'uat_supervisor', 'uat_chofer');
delete from public.vehiculos where patente = 'UAT-FC-001';
delete from public.locales where codigo = 'UAT-LOCAL-FC';
delete from public.empresas where nombre = 'UAT Empresa Fleet Control';

delete from public.role_views
where role_id in (
  select id from public.roles
  where codigo in ('super_admin', 'admin', 'supervisor', 'chofer')
    and nombre like 'UAT %'
);

delete from public.roles
where codigo in ('super_admin', 'admin', 'supervisor', 'chofer')
  and nombre like 'UAT %'
  and not exists (select 1 from public.usuarios u where u.rol_id = public.roles.id);
