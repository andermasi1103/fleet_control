-- Fleet Control: notifications for the self-managed PostgreSQL database.
-- This migration deliberately has no platform-specific roles, grants, or RLS policies.

begin;

create table if not exists public.notification_devices (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references public.usuarios(id) on delete cascade,
  token text not null,
  platform text not null,
  device_id text,
  activo boolean not null default true,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint notification_devices_platform_check check (platform in ('android', 'web')),
  constraint notification_devices_token_not_blank check (length(btrim(token)) > 0),
  constraint notification_devices_token_unique unique (token)
);

create index if not exists notification_devices_usuario_activo_idx
  on public.notification_devices (usuario_id, activo);

create table if not exists public.notificaciones (
  id uuid primary key default gen_random_uuid(),
  usuario_id uuid not null references public.usuarios(id) on delete cascade,
  tipo text not null,
  titulo text not null,
  mensaje text not null,
  entity_type text,
  entity_id uuid,
  ruta text,
  leida boolean not null default false,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  constraint notificaciones_tipo_not_blank check (length(btrim(tipo)) > 0),
  constraint notificaciones_title_not_blank check (length(btrim(titulo)) > 0),
  constraint notificaciones_message_not_blank check (length(btrim(mensaje)) > 0),
  constraint notificaciones_read_at_check check (
    (leida = false and read_at is null) or (leida = true and read_at is not null)
  )
);

-- One logical alert per driver for a new order. Registered devices do not
-- participate in this key, so more than one device cannot duplicate an alert.
create unique index if not exists notificaciones_new_order_pedido_usuario_unique
  on public.notificaciones (usuario_id, entity_id)
  where tipo = 'new_order' and entity_type = 'pedido';

create index if not exists notificaciones_usuario_created_at_idx
  on public.notificaciones (usuario_id, created_at desc);

create index if not exists notificaciones_usuario_unread_idx
  on public.notificaciones (usuario_id, created_at desc)
  where leida = false;

-- Reuse the shared timestamp helper only when the local database already has
-- the compatible no-argument trigger function. This migration never creates a
-- duplicate helper function.
do $$
begin
  if exists (
    select 1
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = 'fleet_control_set_updated_at'
      and p.pronargs = 0
      and p.prorettype = 'trigger'::regtype
  ) and not exists (
    select 1
    from pg_catalog.pg_trigger t
    where t.tgrelid = 'public.notification_devices'::regclass
      and t.tgname = 'notification_devices_set_updated_at'
      and not t.tgisinternal
  ) then
    execute 'create trigger notification_devices_set_updated_at '
      || 'before update on public.notification_devices '
      || 'for each row execute function public.fleet_control_set_updated_at()';
  end if;
end;
$$;

commit;
