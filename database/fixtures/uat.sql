-- Execute only through backend/scripts/uat-fixtures.ts. The runner provides
-- fleet_control.uat_password as a transaction-local parameter; no password is
-- present in this file, a command line, or a repository file.
insert into public.roles (codigo, nombre, descripcion, nivel, activo)
select source.codigo, source.nombre, 'Rol ficticio para UAT local', source.nivel, true
from (values
  ('super_admin', 'UAT Super Admin', 100),
  ('admin', 'UAT Admin', 80),
  ('supervisor', 'UAT Supervisor', 60),
  ('chofer', 'UAT Chofer', 40)
) as source(codigo, nombre, nivel)
where not exists (
  select 1 from public.roles current where current.codigo = source.codigo
);

insert into public.empresas (nombre, razon_social, documento, activo)
select 'UAT Empresa Fleet Control', 'UAT Empresa Fleet Control', 'UAT-FC-LOCAL', true
where not exists (
  select 1 from public.empresas where nombre = 'UAT Empresa Fleet Control'
);

update public.empresas
set activo = true, updated_at = now()
where nombre = 'UAT Empresa Fleet Control';

insert into public.locales (
  empresa_id, nombre, codigo, descripcion, latitud, longitud, radio_metros, activo
)
select e.id, 'UAT Local Fleet Control', 'UAT-LOCAL-FC', 'Ubicación ficticia para UAT local', -25.2867, -57.6470, 500, true
from public.empresas e
where e.nombre = 'UAT Empresa Fleet Control'
  and not exists (
    select 1
    from public.locales l
    where l.empresa_id = e.id and l.codigo = 'UAT-LOCAL-FC'
  );

update public.locales
set activo = true, latitud = -25.2867, longitud = -57.6470, radio_metros = 500, updated_at = now()
where codigo = 'UAT-LOCAL-FC';

insert into public.vehiculos (empresa_id, patente, marca, modelo, descripcion, tipo_vehiculo, activo)
select e.id, 'UAT-FC-001', 'UAT', 'Vehiculo', 'Vehículo ficticio para UAT local', 'auto', true
from public.empresas e
where e.nombre = 'UAT Empresa Fleet Control'
  and not exists (
    select 1 from public.vehiculos v where v.empresa_id = e.id and v.patente = 'UAT-FC-001'
  );

update public.vehiculos
set activo = true, updated_at = now()
where patente = 'UAT-FC-001';

select public.fleet_control_create_usuario(
  'UAT Super Admin', 'uat_super_admin', current_setting('fleet_control.uat_password', true), null::uuid, r.id, true
)
from public.roles r
where r.codigo = 'super_admin'
  and not exists (select 1 from public.usuarios where usuario = 'uat_super_admin');

select public.fleet_control_create_usuario(
  'UAT Admin', 'uat_admin', current_setting('fleet_control.uat_password', true), e.id, r.id, true
)
from public.empresas e
join public.roles r on r.codigo = 'admin'
where e.nombre = 'UAT Empresa Fleet Control'
  and not exists (select 1 from public.usuarios where usuario = 'uat_admin');

select public.fleet_control_create_usuario(
  'UAT Supervisor', 'uat_supervisor', current_setting('fleet_control.uat_password', true), e.id, r.id, true
)
from public.empresas e
join public.roles r on r.codigo = 'supervisor'
where e.nombre = 'UAT Empresa Fleet Control'
  and not exists (select 1 from public.usuarios where usuario = 'uat_supervisor');

select public.fleet_control_create_usuario(
  'UAT Chofer', 'uat_chofer', current_setting('fleet_control.uat_password', true), e.id, r.id, true
)
from public.empresas e
join public.roles r on r.codigo = 'chofer'
where e.nombre = 'UAT Empresa Fleet Control'
  and not exists (select 1 from public.usuarios where usuario = 'uat_chofer');

update public.usuarios
set activo = true
where usuario in ('uat_super_admin', 'uat_admin', 'uat_supervisor', 'uat_chofer');

select public.fleet_control_set_user_locations(u.id, array[l.id]::uuid[])
from public.usuarios u
join public.locales l on l.codigo = 'UAT-LOCAL-FC'
where u.usuario = 'uat_chofer';

select public.fleet_control_set_user_vehicle(u.id, v.id)
from public.usuarios u
join public.vehiculos v on v.patente = 'UAT-FC-001'
where u.usuario = 'uat_chofer';

select public.fleet_control_set_supervisor_choferes(s.id, array[d.id]::uuid[])
from public.usuarios s
join public.usuarios d on d.usuario = 'uat_chofer'
where s.usuario = 'uat_supervisor';
