alter table public.vehiculos
  add column if not exists tipo_vehiculo text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conrelid = 'public.vehiculos'::regclass
      and conname = 'vehiculos_tipo_vehiculo_check'
  ) then
    alter table public.vehiculos
      add constraint vehiculos_tipo_vehiculo_check
      check (
        tipo_vehiculo is null
        or tipo_vehiculo in ('moto', 'auto', 'camion', 'furgon', 'otro')
      );
  end if;
end;
$$;
