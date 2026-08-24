import { body, protectedEndpoint } from '../_shared/http.ts';
import { error, json } from '../_shared/responses.ts';
import { isSuperAdmin } from '../_shared/session.ts';
import { isUuid, stringValue } from '../_shared/validation.ts';

Deno.serve((request) => protectedEndpoint(request, 'PATCH', async ({ admin, session }) => {
  if (!isSuperAdmin(session)) return error('forbidden', 403);
  const payload = await body(request); if (!payload || !isUuid(payload.id)) return error('invalid_request', 400);
  const update: Record<string, unknown> = {};
  if ('nombre' in payload) { const nombre = stringValue(payload.nombre, 160); if (!nombre) return error('invalid_request', 400); update.nombre = nombre; }
  if ('activo' in payload) { if (typeof payload.activo !== 'boolean') return error('invalid_request', 400); update.activo = payload.activo; }
  if (Object.keys(update).length === 0) return error('invalid_request', 400);
  const { data, error: updateError } = await admin.from('empresas').update(update).eq('id', payload.id).select('id, nombre, activo, created_at, updated_at').maybeSingle();
  return updateError ? error(updateError.code === '23505' ? 'conflict' : 'internal_error', updateError.code === '23505' ? 409 : 500) : !data ? error('not_found', 404) : json({ company: data });
}));
