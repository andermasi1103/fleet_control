begin;

create extension if not exists pgcrypto;

create table if not exists public.pedido_descripciones (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(id) on delete restrict,
  nombre text not null,
  activo boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint pedido_descripciones_nombre_no_vacio check (length(btrim(nombre)) > 0)
);

create unique index if not exists pedido_descripciones_empresa_nombre_unique
  on public.pedido_descripciones (empresa_id, lower(btrim(nombre)));
create index if not exists pedido_descripciones_empresa_activo_idx
  on public.pedido_descripciones (empresa_id, activo);

create table if not exists public.pedidos (
  id uuid primary key default gen_random_uuid(),
  empresa_id uuid not null references public.empresas(id) on delete restrict,
  local_id uuid not null references public.locales(id) on delete restrict,
  creado_por_usuario_id uuid not null references public.usuarios(id) on delete restrict,
  descripcion_tipo_id uuid references public.pedido_descripciones(id) on delete restrict,
  destino text,
  destino_latitud double precision,
  destino_longitud double precision,
  factura_solicitud text,
  numero_contacto text,
  prioridad text not null default 'normal',
  observaciones text,
  estado text not null default 'pendiente',
  cancelado_por_usuario_id uuid references public.usuarios(id) on delete set null,
  cancelado_at timestamptz,
  tracking_token_hash text,
  tracking_enabled boolean not null default false,
  tracking_expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint pedidos_estado_check check (estado in ('pendiente','asignado','aceptado','en_camino','en_gestion','completado','cancelado')),
  constraint pedidos_prioridad_check check (prioridad in ('baja','normal','urgente')),
  constraint pedidos_destino_coordenadas_check check (
    (destino_latitud is null and destino_longitud is null) or
    (destino_latitud between -90 and 90 and destino_longitud between -180 and 180)
  )
);

create index if not exists pedidos_empresa_id_idx on public.pedidos (empresa_id);
create index if not exists pedidos_local_id_idx on public.pedidos (local_id);
create index if not exists pedidos_estado_idx on public.pedidos (estado);
create index if not exists pedidos_created_at_idx on public.pedidos (created_at desc);
create index if not exists pedidos_creado_por_usuario_id_idx on public.pedidos (creado_por_usuario_id);

alter table public.pedido_descripciones enable row level security;
alter table public.pedidos enable row level security;
revoke all on table public.pedido_descripciones from anon, authenticated;
revoke all on table public.pedidos from anon, authenticated;

commit;
