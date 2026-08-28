-- Permit the trusted Fastify database role through local RLS tables without
-- granting it extra table privileges. Application-level session and company
--authorization remains enforced by Fastify routes.
begin;

-- These tables are accessed only by the trusted Fastify runtime.  Flutter
-- reaches them through Fastify, so their policies deliberately authorize the
-- fleet_app database role; user and company scoping is enforced by the routes.
alter table public.notification_devices enable row level security;
alter table public.notificaciones enable row level security;

grant select on table public.chofer_ubicaciones to fleet_app;

do $$
declare
  target_table text;
  target_privilege text;
  policy_name text;
begin
  foreach target_table in array array[
    'sesiones', 'usuarios', 'roles', 'empresas', 'locales', 'vehiculos',
    'asistencias', 'usuario_locales', 'pedidos', 'pedido_descripciones',
    'gestiones', 'gestion_eventos', 'chofer_ubicaciones', 'role_views',
    'app_views', 'usuario_vehiculos', 'supervisor_choferes',
    'notification_devices', 'notificaciones'
  ]
  loop
    if not exists (
      select 1
      from pg_class c
      join pg_namespace n on n.oid = c.relnamespace
      where n.nspname = 'public'
        and c.relname = target_table
        and c.relrowsecurity
    ) then
      continue;
    end if;

    foreach target_privilege in array array['SELECT', 'INSERT', 'UPDATE']
    loop
      if not has_table_privilege('fleet_app', format('public.%I', target_table), target_privilege) then
        continue;
      end if;

      policy_name := format('fleet_app_%s', lower(target_privilege));
      if exists (
        select 1 from pg_policy p
        join pg_class c on c.oid = p.polrelid
        join pg_namespace n on n.oid = c.relnamespace
        where n.nspname = 'public'
          and c.relname = target_table
          and p.polname = policy_name
      ) then
        continue;
      end if;

      if target_privilege = 'SELECT' then
        execute format(
          'create policy %I on public.%I for select to fleet_app using (true)',
          policy_name, target_table
        );
      elsif target_privilege = 'INSERT' then
        execute format(
          'create policy %I on public.%I for insert to fleet_app with check (true)',
          policy_name, target_table
        );
      else
        execute format(
          'create policy %I on public.%I for update to fleet_app using (true) with check (true)',
          policy_name, target_table
        );
      end if;
    end loop;
  end loop;
end;
$$;

commit;
