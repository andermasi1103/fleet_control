import { body, protectedEndpoint } from '../_shared/http.ts';
import { error, json } from '../_shared/responses.ts';
import { canManageCompany } from '../_shared/session.ts';
import { isUuid, numberValue, optionalString, stringValue } from '../_shared/validation.ts';

Deno.serve((request) => protectedEndpoint(request, 'PATCH', async ({ admin, session }) => {
  const payload = await body(request); if (!payload || !isUuid(payload.id)) return error('invalid_request', 400);
  const { data: current, error: currentError } = await admin.from('locales').select('empresa_id').eq('id', payload.id).maybeSingle();
  if (currentError) return error('internal_error', 500); if (!current) return error('not_found', 404);
  const targetCompany = 'empresa_id' in payload ? payload.empresa_id : current.empresa_id;
  if (!isUuid(targetCompany) || !canManageCompany(session, current.empresa_id) || !canManageCompany(session, targetCompany)) return error('forbidden', 403);
  if ('empresa_id' in payload) { const { data: company } = await admin.from('empresas').select('id').eq('id', targetCompany).maybeSingle(); if (!company) return error('not_found', 404); }
  const update: Record<string, unknown> = {};
  if ('empresa_id' in payload) update.empresa_id = targetCompany;
  if ('nombre' in payload) { const value = stringValue(payload.nombre, 160); if (!value) return error('invalid_request', 400); update.nombre = value; }
  if ('direccion' in payload) { const value = optionalString(payload.direccion, 500); if (value === undefined) return error('invalid_request', 400); update.direccion = value; }
  if ('latitud' in payload) { const value = numberValue(payload.latitud, -90, 90); if (value === null) return error('invalid_request', 400); update.latitud = value; }
  if ('longitud' in payload) { const value = numberValue(payload.longitud, -180, 180); if (value === null) return error('invalid_request', 400); update.longitud = value; }
  if ('radio_metros' in payload) { const value = numberValue(payload.radio_metros, 1, 100000); if (value === null) return error('invalid_request', 400); update.radio_metros = value; }
  if ('activo' in payload) { if (typeof payload.activo !== 'boolean') return error('invalid_request', 400); update.activo = payload.activo; }
  if (Object.keys(update).length === 0) return error('invalid_request', 400);
  const { data, error: updateError } = await admin.from('locales').update(update).eq('id', payload.id).select('id, empresa_id, nombre, direccion, latitud, longitud, radio_metros, activo, created_at, updated_at').maybeSingle();
  return updateError ? error('internal_error', 500) : !data ? error('not_found', 404) : json({ location: data });
}));
