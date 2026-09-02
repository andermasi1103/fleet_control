import cors from '@fastify/cors';
import type { FastifyInstance } from 'fastify';

import { corsOrigins } from '../config/env.js';

export async function registerCors(app: FastifyInstance): Promise<void> {
  await app.register(cors, {
    origin(origin, callback) {
      // Requests without Origin (for example curl or a native mobile client) are not CORS requests.
      if (!origin) {
        callback(null, true);
        return;
      }

      callback(null, corsOrigins.includes(origin));
    },
    methods: ['GET', 'HEAD', 'POST', 'PUT', 'PATCH'],
    credentials: false
  });
}
