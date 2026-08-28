import { z } from 'zod';

const optionalNonNegativeNumber = z.number()
  .finite()
  .nonnegative()
  .nullish()
  .transform((value) => value ?? null);

export const driverLocationSchema = z.object({
  latitude: z.number().finite().min(-90).max(90),
  longitude: z.number().finite().min(-180).max(180),
  accuracy: optionalNonNegativeNumber,
  speed: optionalNonNegativeNumber,
  heading: z.number().finite().min(0).lt(360).nullish().transform((value) => value ?? null),
  captured_at: z.string().datetime({ offset: true })
}).strict();
