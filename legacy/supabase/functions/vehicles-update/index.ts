import { body, protectedEndpoint } from '../_shared/http.ts';
import { error, json } from '../_shared/responses.ts';
import { canManageCompany, isSuperAdmin } from '../_shared/session.ts';
import { isUuid, numberValue, optionalString, stringValue } from '../_shared/validation.ts';

const vehicleTypes = ['moto', 'auto', 'camion', 'furgon', 'otro'] as const;
type VehicleType = typeof vehicleTypes[number];

function vehicleTypeValue(value: unknown): VehicleType | undefined {
  return typeof value === 'string' && vehicleTypes.includes(value as VehicleType)
    ? value as VehicleType
    : undefined;
}

Deno.serve((request) => protectedEndpoint(request, 'PATCH', async ({ admin, session }) => {
  if (!isSuperAdmin(session) && session.role !== 'admin') return error('forbidden', 403);
  const payload = await body(request); if (!payload || !isUuid(payload.id)) return error('invalid_request', 400);
  const { data: current } = await admin.from('vehiculos').select('empresa_id').eq('id', payload.id).maybeSingle(); if (!current) return error('not_found', 404);
  const targetCompany = 'empresa_id' in payload ? payload.empresa_id : current.empresa_id;
  if (!isUuid(targetCompany) || !canManageCompany(session, current.empresa_id) || !canManageCompany(session, targetCompany)) return error('forbidden', 403);
  if ('empresa_id' in payload) { const { data: company } = await admin.from('empresas').select('id').eq('id', targetCompany).maybeSingle(); if (!company) return error('not_found', 404); }
  const update: Record<string, unknown> = {};
  if ('empresa_id' in payload) update.empresa_id = targetCompany;
  if ('patente' in payload) { const value = stringValue(payload.patente, 30); if (!value) return error('invalid_request', 400); update.patente = value; }
  for (const field of ['marca', 'modelo', 'descripcion'] as const) if (field in payload) { const value = optionalString(payload[field], field === 'descripcion' ? 500 : 80); if (value === undefined) return error('invalid_request', 400); update[field] = value; }
  if ('anio' in payload) { if (payload.anio === null) update.anio = null; else { const value = numberValue(payload.anio, 1900, 2100); if (value === null) return error('invalid_request', 400); update.anio = value; } }
  if ('tipo_vehiculo' in payload) { if (payload.tipo_vehiculo === null) update.tipo_vehiculo = null; else { const value = vehicleTypeValue(payload.tipo_vehiculo); if (!value) return error('invalid_request', 400); update.tipo_vehiculo = value; } }
  if ('activo' in payload) { if (typeof payload.activo !== 'boolean') return error('invalid_request', 400); update.activo = payload.activo; }
  if (Object.keys(update).length === 0) return error('invalid_request', 400);
  const { data, error: updateError } = await admin.from('vehiculos').update(update).eq('id', payload.id).select('id, empresa_id, patente, marca, modelo, anio, descripcion, tipo_vehiculo, activo, created_at, updated_at').maybeSingle();
  return updateError ? error(updateError.code === '23505' ? 'conflict' : 'internal_error', updateError.code === '23505' ? 409 : 500) : !data ? error('not_found', 404) : json({ vehicle: data });
}));
