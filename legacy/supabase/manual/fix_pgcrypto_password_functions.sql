-- Corrección mínima para un proyecto donde pgcrypto está instalado en schema extensions.
-- No crea ni elimina tablas, filas, funciones ni permisos.

create or replace function public.fleet_control_create_usuario(
  p_nombre text, p_usuario text, p_password text, p_empresa_id uuid,
  p_rol_id uuid, p_activo boolean default true
) returns uuid language plpgsql security definer set search_path = public as $$
declare
  new_id uuid;
begin
  insert into public.usuarios (nombre, usuario, password_hash, empresa_id, rol_id, activo)
  values (
    p_nombre,
    p_usuario,
    extensions.crypt(p_password, extensions.gen_salt('bf'::text, 12)),
    p_empresa_id,
    p_rol_id,
    p_activo
  )
  returning id into new_id;
  return new_id;
end;
$$;

create or replace function public.fleet_control_set_usuario_password(
  p_user_id uuid, p_password text
) returns void language plpgsql security definer set search_path = public as $$
begin
  update public.usuarios
  set password_hash = extensions.crypt(
    p_password,
    extensions.gen_salt('bf'::text, 12)
  )
  where id = p_user_id;
  if not found then
    raise exception 'user_not_found';
  end if;
  update public.sesiones
  set revoked_at = now()
  where usuario_id = p_user_id and revoked_at is null;
end;
$$;
