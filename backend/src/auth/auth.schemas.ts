import { z } from 'zod';

const passwordSchema = z.string().min(1).max(1024);

export const loginRequestSchema = z.object({
  usuario: z.string()
    .trim()
    .min(1)
    .max(100)
    .refine((value) => !value.includes('@'), 'El acceso por email no está disponible.'),
  password: passwordSchema
}).strict();

export const changePasswordRequestSchema = z.object({
  currentPassword: passwordSchema,
  newPassword: z.string().min(8).max(1024)
}).strict().refine(
  ({ currentPassword, newPassword }) => currentPassword !== newPassword,
  { message: 'La nueva contraseña debe ser distinta a la actual.', path: ['newPassword'] }
);

export type LoginRequest = z.infer<typeof loginRequestSchema>;
export type ChangePasswordRequest = z.infer<typeof changePasswordRequestSchema>;
