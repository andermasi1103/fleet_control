begin;

alter table public.empresas
  add column local_marker_icon text not null default 'storefront',
  add column local_marker_color text;

alter table public.empresas
  add constraint empresas_local_marker_icon_check
    check (local_marker_icon in (
      'store', 'storefront', 'business', 'grocery', 'shopping', 'location'
    )),
  add constraint empresas_local_marker_color_check
    check (
      local_marker_color is null
      or local_marker_color ~ '^#[0-9A-Fa-f]{6}$'
    );

commit;
