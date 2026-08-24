begin;

create or replace function public.fleet_control_driver_claim_order(
  p_order_id uuid,
  p_driver_user_id uuid
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
  v_constraint_name text;
begin
  -- The order row is the concurrency boundary: only one claim can evaluate it
  -- as pending and create its management.
  select o.*
    into v_order
  from public.pedidos as o
  where o.id = p_order_id
  for update;

  if not found then
    raise exception 'not_found' using errcode = 'P0001';
  end if;

  if v_order.estado <> 'pendiente' then
    raise exception 'order_already_taken' using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.gestiones as g
    where g.pedido_id = v_order.id
  ) then
    raise exception 'order_already_taken' using errcode = 'P0001';
  end if;

  -- Lock the driver as well so two different orders cannot be claimed by the
  -- same driver at the same time.
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

  if v_driver_role <> 'chofer' or
      v_driver.empresa_id is null or
      v_driver.empresa_id <> v_order.empresa_id then
    raise exception 'invalid_reference' using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.gestiones as g
    where g.chofer_usuario_id = v_driver.id
      and g.estado in ('asignado', 'aceptado', 'en_camino', 'en_gestion')
  ) then
    raise exception 'driver_busy' using errcode = 'P0001';
  end if;

  -- usuario_vehiculos has one habitual vehicle per driver. Lock both rows to
  -- serialize claims that might otherwise select the same vehicle.
  select v.*
    into v_vehicle
  from public.usuario_vehiculos as uv
  join public.vehiculos as v on v.id = uv.vehiculo_id
  where uv.usuario_id = v_driver.id
  for update of uv, v;

  if not found or v_vehicle.activo is not true or
      v_vehicle.empresa_id <> v_order.empresa_id then
    raise exception 'driver_vehicle_required' using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.gestiones as g
    where g.vehiculo_id = v_vehicle.id
      and g.estado in ('asignado', 'aceptado', 'en_camino', 'en_gestion')
  ) then
    raise exception 'vehicle_busy' using errcode = 'P0001';
  end if;

  begin
    insert into public.gestiones (
      pedido_id,
      empresa_id,
      local_id,
      chofer_usuario_id,
      vehiculo_id,
      asignado_por_usuario_id
    )
    values (
      v_order.id,
      v_order.empresa_id,
      v_order.local_id,
      v_driver.id,
      v_vehicle.id,
      v_driver.id
    )
    returning * into v_management;
  exception
    when unique_violation then
      get stacked diagnostics v_constraint_name = constraint_name;
      if v_constraint_name = 'gestiones_pedido_unique' then
        raise exception 'order_already_taken' using errcode = 'P0001';
      elsif v_constraint_name = 'gestiones_chofer_activo_unique' then
        raise exception 'driver_busy' using errcode = 'P0001';
      elsif v_constraint_name = 'gestiones_vehiculo_activo_unique' then
        raise exception 'vehicle_busy' using errcode = 'P0001';
      end if;
      raise;
  end;

  update public.pedidos
  set estado = 'asignado', updated_at = now()
  where id = v_order.id;

  insert into public.gestion_eventos (
    gestion_id,
    usuario_id,
    estado_nuevo
  )
  values (v_management.id, v_driver.id, 'asignado');

  return v_management;
end;
$$;

revoke all on function public.fleet_control_driver_claim_order(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.fleet_control_driver_claim_order(uuid, uuid)
  to service_role;

commit;
