import { protectedEndpoint } from '../_shared/http.ts';
import { error, json } from '../_shared/responses.ts';
import { isSuperAdmin } from '../_shared/session.ts';

Deno.serve((request) => protectedEndpoint(request, 'GET', async ({ admin, session }) => {
  let query = admin.from('empresas').select('id, nombre, activo, created_at, updated_at').order('nombre');
  if (!isSuperAdmin(session)) {
    if (!session.empresaId) return error('forbidden', 403);
    query = query.eq('id', session.empresaId);
  }
  const { data, error: queryError } = await query;
  return queryError ? error('internal_error', 500) : json({ companies: data ?? [] });
}));
