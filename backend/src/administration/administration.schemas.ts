import { z } from 'zod';

const uuid = z.string().uuid();
const optionalText = (max: number) => z.string().trim().max(max).nullable().optional();

export const idParamsSchema = z.object({ id: uuid }).strict();
export const companySchema = z.object({ nombre: z.string().trim().min(1).max(160), activo: z.boolean().optional() }).strict();
export const companyPatchSchema = companySchema.partial().refine((value) => Object.keys(value).length > 0);

const locationFields = z.object({
  empresa_id: uuid.optional(), nombre: z.string().trim().min(1).max(160).optional(),
  direccion: optionalText(500), codigo: optionalText(80), descripcion: optionalText(500),
  latitud: z.number().finite().min(-90).max(90).optional(), longitud: z.number().finite().min(-180).max(180).optional(),
  radio_metros: z.number().finite().min(1).max(100000).optional(), activo: z.boolean().optional()
}).strict();
export const locationCreateSchema = locationFields.required({ empresa_id: true, nombre: true, latitud: true, longitud: true });
export const locationPatchSchema = locationFields.refine((value) => Object.keys(value).length > 0);
export const locationListSchema = z.object({ empresa_id: uuid.optional() }).strict();
const importLocationSchema = z.object({
  codigo: z.string().trim().min(1).max(80), nombre: z.string().trim().min(1).max(160),
  descripcion: optionalText(500), direccion: optionalText(500),
  latitud: z.number().finite().min(-90).max(90), longitud: z.number().finite().min(-180).max(180),
  radio_geocerca_metros: z.number().finite().min(10).max(5000), activo: z.boolean().optional()
}).strict();
export const locationImportSchema = z.object({ empresa_id: uuid.optional(), locations: z.array(importLocationSchema).min(1).max(500) }).strict();

const userFields = z.object({
  nombre: z.string().trim().min(1).max(160).optional(), usuario: z.string().trim().min(1).max(100).optional(),
  empresa_id: uuid.nullable().optional(), rol_id: uuid.optional(), activo: z.boolean().optional()
}).strict();
export const userCreateSchema = userFields.extend({ password: z.string().min(8).max(1024) }).required({ nombre: true, usuario: true, rol_id: true });
export const userPatchSchema = userFields.refine((value) => Object.keys(value).length > 0);
export const passwordResetSchema = z.object({ password: z.string().min(8).max(1024) }).strict();

const vehicleFields = z.object({
  empresa_id: uuid.optional(), patente: z.string().trim().min(1).max(30).optional(), marca: optionalText(80),
  modelo: optionalText(80), descripcion: optionalText(500), anio: z.number().int().min(1900).max(2100).nullable().optional(),
  tipo_vehiculo: z.enum(['moto', 'auto', 'camion', 'furgon', 'otro']).nullable().optional(), activo: z.boolean().optional()
}).strict();
export const vehicleCreateSchema = vehicleFields.required({ empresa_id: true, patente: true });
export const vehiclePatchSchema = vehicleFields.refine((value) => Object.keys(value).length > 0);
export const vehicleListSchema = z.object({ empresa_id: uuid.optional() }).strict();

export const userLocationsSchema = z.object({ location_ids: z.array(uuid).max(500).transform((ids) => [...new Set(ids)]) }).strict();
export const userVehicleSchema = z.object({ vehicle_id: uuid.nullable() }).strict();
export const supervisorDriversSchema = z.object({ driver_user_ids: z.array(uuid).max(500).transform((ids) => [...new Set(ids)]) }).strict();
export const roleViewSchema = z.object({ role_code: z.string().trim().min(1).max(80), view_code: z.string().trim().min(1).max(80), visible: z.boolean() }).strict();
