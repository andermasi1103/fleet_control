import { body, protectedEndpoint } from '../_shared/http.ts';
import { error, json } from '../_shared/responses.ts';
import { canManageCompany } from '../_shared/session.ts';
import { isUuid, numberValue, optionalString, stringValue } from '../_shared/validation.ts';

Deno.serve((request) => protectedEndpoint(request, 'POST', async ({ admin, session }) => {
  const payload = await body(request);
  if (!payload || !isUuid(payload.empresa_id)) return error('invalid_request', 400);
  const nombre = stringValue(payload.nombre, 160); const direccion = optionalString(payload.direccion, 500);
  const latitud = numberValue(payload.latitud, -90, 90); const longitud = numberValue(payload.longitud, -180, 180); const radio = numberValue(payload.radio_metros, 1, 100000);
  if (!nombre || direccion === undefined || latitud === null || longitud === null || radio === null) return error('invalid_request', 400);
  if (!canManageCompany(session, payload.empresa_id)) return error('forbidden', 403);
  const { data: company } = await admin.from('empresas').select('id, activo').eq('id', payload.empresa_id).maybeSingle();
  if (!company) return error('not_found', 404); if (company.activo !== true) return error('forbidden', 403);
  const { data, error: insertError } = await admin.from('locales').insert({ empresa_id: payload.empresa_id, nombre, direccion, latitud, longitud, radio_metros: radio, activo: true }).select('id, empresa_id, nombre, direccion, latitud, longitud, radio_metros, activo, created_at, updated_at').single();
  return insertError || !data ? error('internal_error', 500) : json({ location: data }, 201);
}));
