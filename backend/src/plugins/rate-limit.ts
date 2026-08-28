import rateLimit from '@fastify/rate-limit';
import type { FastifyInstance } from 'fastify';

import { env } from '../config/env.js';

export const sensitiveRateLimit = {
  rateLimit: { max: 10, timeWindow: 60_000 }
};

export const trackingRateLimit = {
  rateLimit: { max: 120, timeWindow: 60_000 }
};

export async function registerRateLimiting(app: FastifyInstance): Promise<void> {
  await app.register(rateLimit, {
    global: true,
    max: env.API_RATE_LIMIT_MAX,
    timeWindow: env.API_RATE_LIMIT_WINDOW_MS,
    keyGenerator: (request) => request.ip,
    errorResponseBuilder: (_request, context) => ({
      statusCode: context.statusCode,
      error: 'rate_limited',
      message: `Demasiadas solicitudes. Reintenta en ${context.after}.`
    })
  });
}
