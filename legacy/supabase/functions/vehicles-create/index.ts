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

Deno.serve((request) => protectedEndpoint(request, 'POST', async ({ admin, session }) => {
  if (!isSuperAdmin(session) && session.role !== 'admin') return error('forbidden', 403);
  const payload = await body(request); if (!payload || !isUuid(payload.empresa_id)) return error('invalid_request', 400);
  const patente = stringValue(payload.patente, 30); const marca = optionalString(payload.marca, 80); const modelo = optionalString(payload.modelo, 80); const descripcion = optionalString(payload.descripcion, 500);
  const anio = payload.anio === undefined || payload.anio === null ? null : numberValue(payload.anio, 1900, 2100); const activo = payload.activo === undefined ? true : payload.activo;
  const tipoVehiculo = payload.tipo_vehiculo === undefined || payload.tipo_vehiculo === null ? null : vehicleTypeValue(payload.tipo_vehiculo);
  if (!patente || marca === undefined || modelo === undefined || descripcion === undefined || anio === null && payload.anio !== undefined && payload.anio !== null || tipoVehiculo === undefined && payload.tipo_vehiculo !== undefined && payload.tipo_vehiculo !== null || typeof activo !== 'boolean') return error('invalid_request', 400);
  if (!canManageCompany(session, payload.empresa_id)) return error('forbidden', 403);
  const { data: company } = await admin.from('empresas').select('id').eq('id', payload.empresa_id).maybeSingle(); if (!company) return error('not_found', 404);
  const { data, error: insertError } = await admin.from('vehiculos').insert({ empresa_id: payload.empresa_id, patente, marca, modelo, anio, descripcion, tipo_vehiculo: tipoVehiculo, activo }).select('id, empresa_id, patente, marca, modelo, anio, descripcion, tipo_vehiculo, activo, created_at, updated_at').single();
  return insertError || !data ? error(insertError?.code === '23505' ? 'conflict' : 'internal_error', insertError?.code === '23505' ? 409 : 500) : json({ vehicle: data }, 201);
}));
