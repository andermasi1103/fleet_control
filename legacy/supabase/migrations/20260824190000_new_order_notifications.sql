begin;

create table public.notification_devices (
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

create index notification_devices_usuario_activo_idx
  on public.notification_devices (usuario_id, activo);

create table public.notificaciones (
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
  constraint notificaciones_title_not_blank check (length(btrim(titulo)) > 0),
  constraint notificaciones_message_not_blank check (length(btrim(mensaje)) > 0),
  constraint notificaciones_read_at_check check (
    (leida = false and read_at is null) or (leida = true and read_at is not null)
  )
);

-- One logical alert per driver for each new order, regardless of devices.
-- NULL entity values remain reusable for future notification types.
alter table public.notificaciones
  add constraint notificaciones_usuario_tipo_entidad_unique
  unique (usuario_id, tipo, entity_type, entity_id);
create index notificaciones_usuario_created_at_idx
  on public.notificaciones (usuario_id, created_at desc);
create index notificaciones_usuario_unread_idx
  on public.notificaciones (usuario_id, created_at desc)
  where leida = false;

alter table public.notification_devices enable row level security;
alter table public.notificaciones enable row level security;

-- The custom-session Edge Functions are the only client access path.
revoke all on table public.notification_devices from public, anon, authenticated;
revoke all on table public.notificaciones from public, anon, authenticated;
grant all on table public.notification_devices to service_role;
grant all on table public.notificaciones to service_role;

commit;
