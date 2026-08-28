import { z } from 'zod';

const uuid = z.string().uuid();
const pagination = {
  limit: z.coerce.number().int().min(1).max(100).default(20),
  offset: z.coerce.number().int().min(0).default(0)
};

export const attendanceCreateSchema = z.object({
  local_id: uuid,
  latitud: z.number().finite().min(-90).max(90),
  longitud: z.number().finite().min(-180).max(180)
}).strict();

export const attendanceHistorySchema = z.object({
  ...pagination,
  usuario_id: uuid.optional(),
  local_id: uuid.optional(),
  tipo: z.enum(['entrada', 'salida']).optional(),
  desde: z.string().datetime({ offset: true }).optional(),
  hasta: z.string().datetime({ offset: true }).optional()
}).strict();

export const orderListSchema = z.object({
  ...pagination,
  estado: z.enum(['pendiente', 'asignado', 'aceptado', 'en_camino', 'en_gestion', 'completado', 'cancelado']).optional(),
  prioridad: z.enum(['baja', 'normal', 'urgente']).optional(),
  local_id: uuid.optional(),
  desde: z.string().datetime({ offset: true }).optional(),
  hasta: z.string().datetime({ offset: true }).optional()
}).strict();

const optionalText = z.string().trim().min(1).nullable().optional();
const coordinate = z.number().finite();

export const orderCreateSchema = z.object({
  local_id: uuid.optional(),
  descripcion_tipo_id: uuid,
  destino: optionalText,
  destino_latitud: coordinate.min(-90).max(90).nullable().optional(),
  destino_longitud: coordinate.min(-180).max(180).nullable().optional(),
  factura_solicitud: optionalText,
  numero_contacto: optionalText,
  prioridad: z.enum(['baja', 'normal', 'urgente']).default('normal'),
  observaciones: optionalText
}).strict().superRefine((value, context) => {
  if ((value.destino_latitud == null) !== (value.destino_longitud == null)) {
    context.addIssue({ code: z.ZodIssueCode.custom, message: 'Las coordenadas deben enviarse juntas.' });
  }
});

export const idParamsSchema = z.object({ id: uuid }).strict();
export const orderIdParamsSchema = z.object({ orderId: uuid }).strict();
export const cancelOrderSchema = z.object({}).strict();

export const descriptionListSchema = z.object({ empresa_id: uuid.optional() }).strict();
export const driverListSchema = z.object({ empresa_id: uuid.optional() }).strict();
export const descriptionCreateSchema = z.object({ empresa_id: uuid, nombre: z.string().trim().min(1).max(200) }).strict();
export const descriptionPatchSchema = z.object({ nombre: z.string().trim().min(1).max(200).optional(), activo: z.boolean().optional() }).strict().refine((value) => value.nombre !== undefined || value.activo !== undefined);

export const managementListSchema = z.object({
  ...pagination,
  estado: z.enum(['asignado', 'aceptado', 'en_camino', 'en_gestion', 'completado', 'cancelado']).optional(),
  driver_user_id: uuid.optional(),
  vehicle_id: uuid.optional(),
  local_id: uuid.optional(),
  order_id: uuid.optional()
}).strict();
export const managementCreateSchema = z.object({ order_id: uuid, driver_user_id: uuid, vehicle_id: uuid }).strict();
export const managementStatusSchema = z.object({ status: z.enum(['aceptado', 'en_camino', 'en_gestion', 'completado']) }).strict();
