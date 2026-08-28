import { body, protectedEndpoint } from '../_shared/http.ts';
import { error, json } from '../_shared/responses.ts';
import { isSuperAdmin } from '../_shared/session.ts';
import { stringValue } from '../_shared/validation.ts';

Deno.serve((request) => protectedEndpoint(request, 'POST', async ({ admin, session }) => {
  if (!isSuperAdmin(session)) return error('forbidden', 403);
  const payload = await body(request); const nombre = payload ? stringValue(payload.nombre, 160) : null;
  if (!nombre) return error('invalid_request', 400);
  const { data: existing, error: lookupError } = await admin.from('empresas').select('id').ilike('nombre', nombre).maybeSingle();
  if (lookupError) return error('internal_error', 500);
  if (existing) return error('conflict', 409);
  const { data, error: insertError } = await admin.from('empresas').insert({ nombre, activo: true }).select('id, nombre, activo, created_at, updated_at').single();
  return insertError || !data ? error(insertError?.code === '23505' ? 'conflict' : 'internal_error', insertError?.code === '23505' ? 409 : 500) : json({ company: data }, 201);
}));
