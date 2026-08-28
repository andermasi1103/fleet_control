import { body, protectedEndpoint } from '../_shared/http.ts';
import { error, json } from '../_shared/responses.ts';
import { canManageCompany, isSuperAdmin } from '../_shared/session.ts';
import { isUuid, relatedCode, stringValue } from '../_shared/validation.ts';

type UpdatedUserRow = Record<string, unknown> & { roles: unknown };

Deno.serve((request) => protectedEndpoint(request, 'PATCH', async ({ admin, session }) => {
  if (!isSuperAdmin(session) && session.role !== 'admin') return error('forbidden', 403);
  const payload = await body(request); if (!payload || !isUuid(payload.id)) return error('invalid_request', 400);
  const { data: current } = await admin.from('usuarios').select('empresa_id, rol_id').eq('id', payload.id).maybeSingle(); if (!current) return error('not_found', 404);
  const targetCompany = 'empresa_id' in payload ? payload.empresa_id : current.empresa_id;
  if (!(targetCompany === null || isUuid(targetCompany))) return error('invalid_request', 400);
  if (!canManageCompany(session, current.empresa_id) || (!isSuperAdmin(session) && !canManageCompany(session, targetCompany))) return error('forbidden', 403);
  if ('empresa_id' in payload && targetCompany) { const { data: company } = await admin.from('empresas').select('id').eq('id', targetCompany).maybeSingle(); if (!company) return error('not_found', 404); }
  const update: Record<string, unknown> = {};
  if ('nombre' in payload) { const value = stringValue(payload.nombre, 160); if (!value) return error('invalid_request', 400); update.nombre = value; }
  if ('usuario' in payload) { const value = stringValue(payload.usuario, 100); if (!value) return error('invalid_request', 400); update.usuario = value; }
  if ('empresa_id' in payload) update.empresa_id = targetCompany;
  if ('activo' in payload) { if (typeof payload.activo !== 'boolean') return error('invalid_request', 400); update.activo = payload.activo; }
  if ('rol_id' in payload) { if (!isUuid(payload.rol_id)) return error('invalid_request', 400); const { data: role } = await admin.from('roles').select('codigo').eq('id', payload.rol_id).maybeSingle(); if (!role) return error('not_found', 404); if (!isSuperAdmin(session) && role.codigo === 'super_admin') return error('forbidden', 403); update.rol_id = payload.rol_id; }
  if (Object.keys(update).length === 0) return error('invalid_request', 400);
  const { data, error: updateError } = await admin.from('usuarios').update(update).eq('id', payload.id).select('id, nombre, usuario, empresa_id, rol_id, activo, created_at, roles(codigo)').maybeSingle<UpdatedUserRow>();
  return updateError ? error(updateError.code === '23505' ? 'conflict' : 'internal_error', updateError.code === '23505' ? 409 : 500) : !data ? error('not_found', 404) : json({ user: { ...data, rol: relatedCode(data.roles), roles: undefined } });
}));
