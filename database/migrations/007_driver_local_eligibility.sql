-- Driver eligibility for published orders is defined by usuario_locales.
-- The existing N:M relationship remains the single source of truth for
-- local assignments; no chofer_locales table is needed.

create index if not exists usuario_locales_local_usuario_idx
  on public.usuario_locales (local_id, usuario_id);

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
    raise exception 'order_already_taken' using errcode = 'P0001';
  end if;

  -- This row lock serializes this eligibility check with
  -- fleet_control_set_user_locations, which also locks the user row.
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

  if not exists (
    select 1
    from public.usuario_locales as ul
    join public.locales as l on l.id = ul.local_id
    where ul.usuario_id = v_driver.id
      and ul.local_id = v_order.local_id
      and l.empresa_id = v_order.empresa_id
  ) then
    raise exception 'forbidden' using errcode = 'P0001';
  end if;

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
      v_driver.id,
      v_queue_position
    )
    returning * into v_management;
  exception
    when unique_violation then
      get stacked diagnostics v_constraint_name = constraint_name;
      if v_constraint_name = 'gestiones_pedido_unique' then
        raise exception 'order_already_taken' using errcode = 'P0001';
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
  values (v_management.id, v_driver.id, 'asignado');

  return v_management;
end;
$$;

revoke all on function public.fleet_control_driver_claim_order(uuid, uuid)
  from public;
grant execute on function public.fleet_control_driver_claim_order(uuid, uuid)
  to fleet_app;
