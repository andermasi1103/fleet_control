import helmet from '@fastify/helmet';
import type { FastifyInstance } from 'fastify';

import { env } from '../config/env.js';

export async function registerSecurityHeaders(app: FastifyInstance): Promise<void> {
  await app.register(helmet, {
    // Fastify serves API JSON, not the Flutter Web document. The web host owns
    // its CSP, so an API-level CSP is deliberately disabled here.
    contentSecurityPolicy: false,
    crossOriginEmbedderPolicy: false,
    crossOriginResourcePolicy: { policy: 'same-site' },
    frameguard: { action: 'deny' },
    hsts: env.NODE_ENV === 'production'
      ? { maxAge: 15_552_000, includeSubDomains: true }
      : false,
    referrerPolicy: { policy: 'no-referrer' }
  });
}
