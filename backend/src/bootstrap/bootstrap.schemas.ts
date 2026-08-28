import { z } from 'zod';

export const viewsResponseSchema = z.object({
  views: z.array(z.string())
});

export const notificationListQuerySchema = z.object({
  limit: z.coerce.number().int().positive().max(100).default(50)
}).strict();

export const notificationIdParamsSchema = z.object({
  id: z.string().uuid()
}).strict();

const notificationTokenSchema = z.string().trim().min(1).max(4096);

export const notificationDeviceRegisterSchema = z.object({
  token: notificationTokenSchema,
  platform: z.enum(['android', 'web']),
  deviceId: z.string().trim().min(1).max(255).nullable().optional()
}).strict();

export const notificationDeviceUnregisterSchema = z.object({
  token: notificationTokenSchema
}).strict();
