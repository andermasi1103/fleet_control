begin;

create table public.supervisor_choferes (
  id uuid primary key default gen_random_uuid(),
  supervisor_usuario_id uuid not null references public.usuarios(id) on delete cascade,
  chofer_usuario_id uuid not null references public.usuarios(id) on delete cascade,
  created_at timestamptz not null default now(),
  constraint supervisor_choferes_distinct_users check (supervisor_usuario_id <> chofer_usuario_id),
  constraint supervisor_choferes_unique unique (supervisor_usuario_id, chofer_usuario_id)
);

create index supervisor_choferes_chofer_usuario_id_idx
  on public.supervisor_choferes (chofer_usuario_id);

alter table public.supervisor_choferes enable row level security;
revoke all on table public.supervisor_choferes from public, anon, authenticated;
grant all on table public.supervisor_choferes to service_role;

create or replace function public.fleet_control_set_supervisor_choferes(
  p_supervisor_usuario_id uuid,
  p_chofer_usuario_ids uuid[]
)
returns void
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_supervisor_empresa_id uuid;
  v_choferes_validos integer;
  v_choferes_solicitados integer;
begin
  select u.empresa_id
    into v_supervisor_empresa_id
  from public.usuarios u
  join public.roles r on r.id = u.rol_id
  where u.id = p_supervisor_usuario_id
    and u.activo = true
    and r.codigo = 'supervisor';

  if v_supervisor_empresa_id is null then
    raise exception using errcode = 'P0001', message = 'invalid_supervisor';
  end if;

  if exists (
    select 1
    from unnest(coalesce(p_chofer_usuario_ids, '{}'::uuid[])) as requested(id)
    where requested.id = p_supervisor_usuario_id
  ) then
    raise exception using errcode = 'P0001', message = 'invalid_driver_assignment';
  end if;

  select count(distinct requested.id)
    into v_choferes_solicitados
  from unnest(coalesce(p_chofer_usuario_ids, '{}'::uuid[])) as requested(id);

  select count(*)
    into v_choferes_validos
  from public.usuarios u
  join public.roles r on r.id = u.rol_id
  where u.id = any(coalesce(p_chofer_usuario_ids, '{}'::uuid[]))
    and u.activo = true
    and u.empresa_id = v_supervisor_empresa_id
    and r.codigo = 'chofer';

  if v_choferes_validos <> v_choferes_solicitados then
    raise exception using errcode = 'P0001', message = 'invalid_driver_assignment';
  end if;

  delete from public.supervisor_choferes
  where supervisor_usuario_id = p_supervisor_usuario_id;

  insert into public.supervisor_choferes (supervisor_usuario_id, chofer_usuario_id)
  select p_supervisor_usuario_id, requested.id
  from unnest(coalesce(p_chofer_usuario_ids, '{}'::uuid[])) as requested(id)
  on conflict (supervisor_usuario_id, chofer_usuario_id) do nothing;
end;
$$;

revoke all on function public.fleet_control_set_supervisor_choferes(uuid, uuid[])
  from public, anon, authenticated;
grant execute on function public.fleet_control_set_supervisor_choferes(uuid, uuid[])
  to service_role;

commit;
