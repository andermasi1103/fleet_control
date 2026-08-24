select c.relname as table_name, c.relrowsecurity as rls_enabled,
  has_table_privilege('anon', c.oid, 'select,insert,update,delete') as anon_direct_access,
  has_table_privilege('authenticated', c.oid, 'select,insert,update,delete') as authenticated_direct_access,
  coalesce((select json_agg(json_build_object('name', con.conname, 'definition', pg_get_constraintdef(con.oid)) order by con.conname)
    from pg_constraint con where con.conrelid = c.oid), '[]'::json) as constraints,
  coalesce((select json_agg(json_build_object('name', idx.indexname, 'definition', idx.indexdef) order by idx.indexname)
    from pg_indexes idx where idx.schemaname = 'public' and idx.tablename = c.relname), '[]'::json) as indexes
from pg_class c join pg_namespace n on n.oid = c.relnamespace
where n.nspname = 'public' and c.relname in ('pedidos', 'pedido_descripciones')
order by c.relname;
