import { z } from 'zod';

const uuid = z.string().uuid();
const reportType = z.enum(['orders', 'managements', 'attendance', 'drivers', 'vehicles', 'locations']);

export const fleetLocationsQuerySchema = z.object({ empresa_id: uuid.optional() }).strict();

export const reportsQuerySchema = z.object({
  empresa_id: uuid.optional(),
  local_id: uuid.optional(),
  driver_user_id: uuid.optional(),
  desde: z.string().datetime({ offset: true }).optional(),
  hasta: z.string().datetime({ offset: true }).optional(),
  estado: z.enum(['pendiente', 'asignado', 'aceptado', 'en_camino', 'en_gestion', 'completado', 'cancelado']).optional(),
  prioridad: z.enum(['baja', 'normal', 'urgente']).optional()
}).strict().refine((value) => !value.desde || !value.hasta || value.desde <= value.hasta, {
  message: 'El rango de fechas no es válido.'
});

export const reportTypeParamsSchema = z.object({ type: reportType }).strict();
export type ReportType = z.infer<typeof reportType>;
