import { body, protectedEndpoint } from '../_shared/http.ts';
import { error, json } from '../_shared/responses.ts';
import { canManageCompany, isSuperAdmin } from '../_shared/session.ts';
import { isUuid } from '../_shared/validation.ts';

Deno.serve((request) => protectedEndpoint(request, 'POST', async ({ admin, session }) => {
  const payload = await body(request); const password = payload && typeof payload.new_password === 'string' ? payload.new_password : '';
  if (!payload || !isUuid(payload.user_id) || password.length < 8 || password.length > 1024) return error('invalid_request', 400);
  const { data: target } = await admin.from('usuarios').select('id, empresa_id').eq('id', payload.user_id).maybeSingle(); if (!target) return error('not_found', 404);
  if (target.id !== session.userId && !isSuperAdmin(session) && !(session.role === 'admin' && canManageCompany(session, target.empresa_id))) return error('forbidden', 403);
  const { error: resetError } = await admin.rpc('fleet_control_set_usuario_password', { p_user_id: payload.user_id, p_password: password });
  return resetError ? error('internal_error', 500) : json({ success: true });
}));
