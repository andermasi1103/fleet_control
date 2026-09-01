-- Align manual management assignment with the existing driver queue model.
-- This migration is for fleet_control_db only.

begin;

create or replace function public.fleet_control_create_gestion(
  p_order_id uuid,
  p_driver_user_id uuid,
  p_vehicle_id uuid,
  p_assigned_by_user_id uuid
)
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
  select o.*
    into v_order
  from public.pedidos as o
  where o.id = p_order_id
  for update;

  if not found then
    raise exception 'not_found' using errcode = 'P0001';
  end if;

  if v_order.estado <> 'pendiente' or exists (
    select 1 from public.gestiones as g where g.pedido_id = v_order.id
  ) then
    raise exception 'active_management' using errcode = 'P0001';
  end if;

  -- This lock serializes manual assignments with driver claims and allocates a
  -- unique queue position for this driver.
  select u.*
    into v_driver
  from public.usuarios as u
  where u.id = p_driver_user_id
  for update;

  if not found or v_driver.activo is not true then
    raise exception 'invalid_reference' using errcode = 'P0001';
  end if;

  select r.codigo
    into v_driver_role
  from public.roles as r
  where r.id = v_driver.rol_id;

  if v_driver_role <> 'chofer' or v_driver.empresa_id is null or
      v_driver.empresa_id <> v_order.empresa_id then
    raise exception 'invalid_reference' using errcode = 'P0001';
  end if;

  select v.*
    into v_vehicle
  from public.vehiculos as v
  where v.id = p_vehicle_id
  for update;

  if not found or v_vehicle.activo is not true or
      v_vehicle.empresa_id <> v_order.empresa_id then
    raise exception 'invalid_reference' using errcode = 'P0001';
  end if;

  -- Queued work does not monopolize a vehicle. A different driver's active
  -- operational management still does.
  if exists (
    select 1
    from public.gestiones as g
    where g.vehiculo_id = v_vehicle.id
      and g.chofer_usuario_id <> v_driver.id
      and g.estado in ('aceptado', 'en_camino', 'en_gestion')
  ) then
    raise exception 'vehicle_busy' using errcode = 'P0001';
  end if;

  select coalesce(max(g.queue_position), 0) + 1
    into v_queue_position
  from public.gestiones as g
  where g.chofer_usuario_id = v_driver.id
    and g.estado in ('asignado', 'aceptado', 'en_camino', 'en_gestion');

  begin
    insert into public.gestiones (
      pedido_id,
      empresa_id,
      local_id,
      chofer_usuario_id,
      vehiculo_id,
      asignado_por_usuario_id,
      queue_position
    )
    values (
      v_order.id,
      v_order.empresa_id,
      v_order.local_id,
      v_driver.id,
      v_vehicle.id,
      p_assigned_by_user_id,
      v_queue_position
    )
    returning * into v_management;
  exception
    when unique_violation then
      get stacked diagnostics v_constraint_name = constraint_name;
      if v_constraint_name = 'gestiones_pedido_unique' then
        raise exception 'active_management' using errcode = 'P0001';
      elsif v_constraint_name = 'gestiones_chofer_queue_position_unique' then
        raise exception 'queue_position_conflict' using errcode = 'P0001';
      elsif v_constraint_name = 'gestiones_vehiculo_operativo_unique' then
        raise exception 'vehicle_busy' using errcode = 'P0001';
      end if;
      raise;
  end;

  update public.pedidos
  set estado = 'asignado', updated_at = now()
  where id = v_order.id;

  insert into public.gestion_eventos (gestion_id, usuario_id, estado_nuevo)
  values (v_management.id, p_assigned_by_user_id, 'asignado');

  return v_management;
end;
$$;

-- The migration runner has already SET ROLE fleet_owner. Keep this privileged
-- RPC closed to PUBLIC and expose it only to the Fastify runtime role.
revoke all on function public.fleet_control_create_gestion(uuid, uuid, uuid, uuid)
  from public;
grant execute on function public.fleet_control_create_gestion(uuid, uuid, uuid, uuid)
  to fleet_app;

commit;
