create or replace function public.fleet_control_verify_usuario_password(
  p_user_id uuid, p_password text
) returns boolean language sql security definer set search_path = public as $$
  select exists (
    select 1 from public.usuarios
    where id = p_user_id
      and extensions.crypt(p_password, password_hash) = password_hash
  );
$$;
revoke all on function public.fleet_control_verify_usuario_password(uuid, text) from public;
grant execute on function public.fleet_control_verify_usuario_password(uuid, text) to service_role;
