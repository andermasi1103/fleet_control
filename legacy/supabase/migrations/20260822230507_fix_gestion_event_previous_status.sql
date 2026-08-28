create or replace function public.fleet_control_update_gestion_status(p_management_id uuid,p_status text,p_user_id uuid)
returns public.gestiones language plpgsql security definer set search_path = public as $$
declare
  v_management public.gestiones;
  v_timestamp timestamptz := now();
  v_estado_anterior text;
begin
  select * into v_management from public.gestiones where id=p_management_id for update;
  if not found then raise exception 'not_found'; end if;
  if v_management.chofer_usuario_id <> p_user_id then raise exception 'forbidden'; end if;
  if not ((v_management.estado='asignado' and p_status='aceptado') or (v_management.estado='aceptado' and p_status='en_camino') or (v_management.estado='en_camino' and p_status='en_gestion') or (v_management.estado='en_gestion' and p_status='completado')) then raise exception 'invalid_transition'; end if;

  v_estado_anterior := v_management.estado;

  update public.gestiones set estado=p_status, aceptado_at=case when p_status='aceptado' then coalesce(aceptado_at,v_timestamp) else aceptado_at end, en_camino_at=case when p_status='en_camino' then coalesce(en_camino_at,v_timestamp) else en_camino_at end, en_gestion_at=case when p_status='en_gestion' then coalesce(en_gestion_at,v_timestamp) else en_gestion_at end, completado_at=case when p_status='completado' then coalesce(completado_at,v_timestamp) else completado_at end, updated_at=v_timestamp where id=v_management.id returning * into v_management;
  update public.pedidos set estado=p_status,updated_at=v_timestamp where id=v_management.pedido_id;
  insert into public.gestion_eventos(gestion_id,usuario_id,estado_anterior,estado_nuevo) values(v_management.id,p_user_id,v_estado_anterior,p_status);
  return v_management;
end; $$;
