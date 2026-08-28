begin;

alter table public.gestiones
  add column queue_position integer;

alter table public.gestiones
  add constraint gestiones_queue_position_positive_check
  check (queue_position is null or queue_position > 0);

-- Existing records receive a stable position so they can be presented in the
-- same queue model as newly claimed orders.
with ranked as (
  select
    g.id,
    row_number() over (
      partition by g.chofer_usuario_id
      order by
        case
          when g.estado in ('aceptado', 'en_camino', 'en_gestion') then 0
          else 1
        end,
        g.created_at,
        g.id
    )::integer as queue_position
  from public.gestiones as g
  where g.estado in ('asignado', 'aceptado', 'en_camino', 'en_gestion')
)
update public.gestiones as g
set queue_position = ranked.queue_position
from ranked
where g.id = ranked.id;

-- "asignado" now represents a queued order, rather than an operationally
-- active management. Keep the database-level safety net for actual work.
drop index if exists public.gestiones_chofer_activo_unique;
drop index if exists public.gestiones_vehiculo_activo_unique;

create unique index gestiones_chofer_operativo_unique
  on public.gestiones (chofer_usuario_id)
  where estado in ('aceptado', 'en_camino', 'en_gestion');

create unique index gestiones_vehiculo_operativo_unique
  on public.gestiones (vehiculo_id)
  where estado in ('aceptado', 'en_camino', 'en_gestion');

create unique index gestiones_chofer_queue_position_unique
  on public.gestiones (chofer_usuario_id, queue_position)
  where estado in ('asignado', 'aceptado', 'en_camino', 'en_gestion')
    and queue_position is not null;

create index gestiones_chofer_estado_queue_position_idx
  on public.gestiones (chofer_usuario_id, estado, queue_position);

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

  -- Serializes all claims for this driver, including queue position allocation.
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
  from public.usuario_vehiculos as uv
  join public.vehiculos as v on v.id = uv.vehiculo_id
  where uv.usuario_id = v_driver.id
  for update of uv, v;

  if not found or v_vehicle.activo is not true or
      v_vehicle.empresa_id <> v_order.empresa_id then
    raise exception 'driver_vehicle_required' using errcode = 'P0001';
  end if;

  -- The driver may add work to their own queue while using this vehicle.
  -- A different driver's operational use of the same vehicle remains blocked.
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

create or replace function public.fleet_control_update_gestion_status(
  p_management_id uuid,
  p_status text,
  p_user_id uuid
)
returns public.gestiones
language plpgsql
security definer
set search_path = public
as $$
declare
  v_management public.gestiones%rowtype;
  v_timestamp timestamptz := now();
  v_estado_anterior text;
  v_constraint_name text;
begin
  select *
    into v_management
  from public.gestiones
  where id = p_management_id
  for update;

  if not found then
    raise exception 'not_found' using errcode = 'P0001';
  end if;
  if v_management.chofer_usuario_id <> p_user_id then
    raise exception 'forbidden' using errcode = 'P0001';
  end if;
  if not (
    (v_management.estado = 'asignado' and p_status = 'aceptado') or
    (v_management.estado = 'aceptado' and p_status = 'en_camino') or
    (v_management.estado = 'en_camino' and p_status = 'en_gestion') or
    (v_management.estado = 'en_gestion' and p_status = 'completado')
  ) then
    raise exception 'invalid_transition' using errcode = 'P0001';
  end if;

  -- Serializes competing accept actions for separate queued managements.
  perform 1
  from public.usuarios as u
  where u.id = v_management.chofer_usuario_id
  for update;

  if p_status = 'aceptado' and exists (
    select 1
    from public.gestiones as g
    where g.chofer_usuario_id = v_management.chofer_usuario_id
      and g.id <> v_management.id
      and g.estado in ('aceptado', 'en_camino', 'en_gestion')
  ) then
    raise exception 'active_management_exists' using errcode = 'P0001';
  end if;

  v_estado_anterior := v_management.estado;

  begin
    update public.gestiones
    set
      estado = p_status,
      aceptado_at = case
        when p_status = 'aceptado' then coalesce(aceptado_at, v_timestamp)
        else aceptado_at
      end,
      en_camino_at = case
        when p_status = 'en_camino' then coalesce(en_camino_at, v_timestamp)
        else en_camino_at
      end,
      en_gestion_at = case
        when p_status = 'en_gestion' then coalesce(en_gestion_at, v_timestamp)
        else en_gestion_at
      end,
      completado_at = case
        when p_status = 'completado' then coalesce(completado_at, v_timestamp)
        else completado_at
      end,
      queue_position = case
        when p_status in ('completado', 'cancelado') then null
        else queue_position
      end,
      updated_at = v_timestamp
    where id = v_management.id
    returning * into v_management;
  exception
    when unique_violation then
      get stacked diagnostics v_constraint_name = constraint_name;
      if v_constraint_name = 'gestiones_chofer_operativo_unique' then
        raise exception 'active_management_exists' using errcode = 'P0001';
      elsif v_constraint_name = 'gestiones_vehiculo_operativo_unique' then
        raise exception 'vehicle_busy' using errcode = 'P0001';
      end if;
      raise;
  end;

  update public.pedidos
  set estado = p_status, updated_at = v_timestamp
  where id = v_management.pedido_id;

  insert into public.gestion_eventos (
    gestion_id, usuario_id, estado_anterior, estado_nuevo
  )
  values (v_management.id, p_user_id, v_estado_anterior, p_status);

  if p_status in ('completado', 'cancelado') then
    with ranked as (
      select
        g.id,
        row_number() over (
          order by g.queue_position nulls last, g.created_at, g.id
        )::integer as queue_position
      from public.gestiones as g
      where g.chofer_usuario_id = v_management.chofer_usuario_id
        and g.estado = 'asignado'
    )
    update public.gestiones as g
    set queue_position = ranked.queue_position,
        updated_at = v_timestamp
    from ranked
    where g.id = ranked.id;
  end if;

  return v_management;
end;
$$;

revoke all on function public.fleet_control_driver_claim_order(uuid, uuid)
  from public, anon, authenticated;
grant execute on function public.fleet_control_driver_claim_order(uuid, uuid)
  to service_role;
revoke all on function public.fleet_control_update_gestion_status(uuid, text, uuid)
  from public, anon, authenticated;
grant execute on function public.fleet_control_update_gestion_status(uuid, text, uuid)
  to service_role;

commit;
