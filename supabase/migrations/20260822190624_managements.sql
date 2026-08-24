begin;

create table public.gestiones (
  id uuid primary key default gen_random_uuid(),
  pedido_id uuid not null references public.pedidos(id) on delete restrict,
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
  constraint gestiones_estado_check check (estado in ('asignado','aceptado','en_camino','en_gestion','completado','cancelado')),
  constraint gestiones_pedido_unique unique (pedido_id)
);

create table public.gestion_eventos (
  id uuid primary key default gen_random_uuid(),
  gestion_id uuid not null references public.gestiones(id) on delete restrict,
  usuario_id uuid not null references public.usuarios(id) on delete restrict,
  estado_anterior text,
  estado_nuevo text not null,
  observaciones text,
  created_at timestamptz not null default now(),
  constraint gestion_eventos_estado_check check (estado_nuevo in ('asignado','aceptado','en_camino','en_gestion','completado','cancelado'))
);

create index gestiones_empresa_id_idx on public.gestiones(empresa_id);
create index gestiones_local_id_idx on public.gestiones(local_id);
create index gestiones_chofer_usuario_id_idx on public.gestiones(chofer_usuario_id);
create index gestiones_vehiculo_id_idx on public.gestiones(vehiculo_id);
create index gestiones_estado_idx on public.gestiones(estado);
create index gestiones_created_at_idx on public.gestiones(created_at desc);
create index gestion_eventos_gestion_id_idx on public.gestion_eventos(gestion_id);
create index gestion_eventos_created_at_idx on public.gestion_eventos(created_at desc);
create unique index gestiones_chofer_activo_unique on public.gestiones(chofer_usuario_id) where estado in ('asignado','aceptado','en_camino','en_gestion');
create unique index gestiones_vehiculo_activo_unique on public.gestiones(vehiculo_id) where estado in ('asignado','aceptado','en_camino','en_gestion');

alter table public.gestiones enable row level security;
alter table public.gestion_eventos enable row level security;
revoke all on public.gestiones, public.gestion_eventos from anon, authenticated;

create or replace function public.fleet_control_create_gestion(p_order_id uuid, p_driver_user_id uuid, p_vehicle_id uuid, p_assigned_by_user_id uuid)
returns public.gestiones language plpgsql security definer set search_path = public as $$
declare v_order public.pedidos; v_driver record; v_vehicle record; v_management public.gestiones;
begin
  select * into v_order from public.pedidos where id=p_order_id for update;
  if not found then raise exception 'not_found'; end if;
  if v_order.estado not in ('pendiente') then raise exception 'active_management'; end if;
  select u.id,u.empresa_id,u.activo,r.codigo into v_driver from public.usuarios u join public.roles r on r.id=u.rol_id where u.id=p_driver_user_id;
  if not found or v_driver.activo is not true or v_driver.codigo <> 'chofer' or v_driver.empresa_id <> v_order.empresa_id then raise exception 'invalid_reference'; end if;
  select id,empresa_id,activo into v_vehicle from public.vehiculos where id=p_vehicle_id;
  if not found or v_vehicle.activo is not true or v_vehicle.empresa_id <> v_order.empresa_id then raise exception 'invalid_reference'; end if;
  if exists(select 1 from public.gestiones where chofer_usuario_id=p_driver_user_id and estado in ('asignado','aceptado','en_camino','en_gestion')) then raise exception 'driver_busy'; end if;
  if exists(select 1 from public.gestiones where vehiculo_id=p_vehicle_id and estado in ('asignado','aceptado','en_camino','en_gestion')) then raise exception 'vehicle_busy'; end if;
  insert into public.gestiones(pedido_id,empresa_id,local_id,chofer_usuario_id,vehiculo_id,asignado_por_usuario_id) values(v_order.id,v_order.empresa_id,v_order.local_id,p_driver_user_id,p_vehicle_id,p_assigned_by_user_id) returning * into v_management;
  update public.pedidos set estado='asignado',updated_at=now() where id=v_order.id;
  insert into public.gestion_eventos(gestion_id,usuario_id,estado_nuevo) values(v_management.id,p_assigned_by_user_id,'asignado');
  return v_management;
end; $$;

create or replace function public.fleet_control_update_gestion_status(p_management_id uuid,p_status text,p_user_id uuid)
returns public.gestiones language plpgsql security definer set search_path = public as $$
declare v_management public.gestiones; v_timestamp timestamptz := now();
begin
  select * into v_management from public.gestiones where id=p_management_id for update;
  if not found then raise exception 'not_found'; end if;
  if v_management.chofer_usuario_id <> p_user_id then raise exception 'forbidden'; end if;
  if not ((v_management.estado='asignado' and p_status='aceptado') or (v_management.estado='aceptado' and p_status='en_camino') or (v_management.estado='en_camino' and p_status='en_gestion') or (v_management.estado='en_gestion' and p_status='completado')) then raise exception 'invalid_transition'; end if;
  update public.gestiones set estado=p_status, aceptado_at=case when p_status='aceptado' then coalesce(aceptado_at,v_timestamp) else aceptado_at end, en_camino_at=case when p_status='en_camino' then coalesce(en_camino_at,v_timestamp) else en_camino_at end, en_gestion_at=case when p_status='en_gestion' then coalesce(en_gestion_at,v_timestamp) else en_gestion_at end, completado_at=case when p_status='completado' then coalesce(completado_at,v_timestamp) else completado_at end, updated_at=v_timestamp where id=v_management.id returning * into v_management;
  update public.pedidos set estado=p_status,updated_at=v_timestamp where id=v_management.pedido_id;
  insert into public.gestion_eventos(gestion_id,usuario_id,estado_anterior,estado_nuevo) values(v_management.id,p_user_id, (select estado from public.gestion_eventos where gestion_id=v_management.id order by created_at desc limit 1),p_status);
  return v_management;
end; $$;

revoke all on function public.fleet_control_create_gestion(uuid,uuid,uuid,uuid) from public;
revoke all on function public.fleet_control_update_gestion_status(uuid,text,uuid) from public;
grant execute on function public.fleet_control_create_gestion(uuid,uuid,uuid,uuid) to service_role;
grant execute on function public.fleet_control_update_gestion_status(uuid,text,uuid) to service_role;
commit;
