import Fastify from 'fastify';

import { registerAuthRoutes } from './auth/auth.routes.js';
import type { Database } from './auth/auth.types.js';
import { registerBootstrapRoutes } from './bootstrap/bootstrap.routes.js';
import { env } from './config/env.js';
import { pool } from './db/pool.js';
import { registerCors } from './plugins/cors.js';
import { registerErrorHandler } from './plugins/error-handler.js';
import { registerRateLimiting } from './plugins/rate-limit.js';
import { registerSecurityHeaders } from './plugins/security.js';
import { registerSessionAuth } from './plugins/session-auth.js';
import { trustedProxy } from './config/env.js';
import type { HealthResponse } from './shared/types/api.js';
import { registerTrackingRoutes } from './tracking/tracking.routes.js';
import { registerTraccarRoutes } from './tracking/traccar.routes.js';
import { registerAdministrationRoutes } from './administration/administration.routes.js';
import { registerOperationsRoutes } from './operations/operations.routes.js';
import { registerInsightsRoutes } from './insights/insights.routes.js';

type AppDependencies = {
  database?: Database;
};

export async function buildApp({ database = pool }: AppDependencies = {}) {
  const app = Fastify({
    bodyLimit: env.BODY_LIMIT_BYTES,
    requestTimeout: env.REQUEST_TIMEOUT_MS,
    trustProxy: trustedProxy,
    logger: {
      level: env.API_LOG_LEVEL,
      redact: [
        'req.headers.authorization',
        'req.headers.cookie',
        'req.headers["x-api-key"]',
        'req.body.password',
        'req.body.currentPassword',
        'req.body.newPassword',
        'req.body.current_password',
        'req.body.new_password',
        'req.body.password_hash',
        'req.body.token',
        'req.body.sessionToken',
        'req.body.session_token',
        'req.body.token_hash',
        'req.body.fcm_token',
        'req.body.deviceToken',
        'req.body.device_token',
        'DATABASE_PASSWORD',
        'FIREBASE_SERVICE_ACCOUNT_JSON',
        'TRACCAR_AUTHORIZATION'
      ]
    }
  });

  registerErrorHandler(app);
  await registerSecurityHeaders(app);
  await registerCors(app);
  await registerRateLimiting(app);
  registerSessionAuth(app, database);
  registerAuthRoutes(app, database);
  registerBootstrapRoutes(app, database);
  registerTrackingRoutes(app, database);
  registerTraccarRoutes(app, database);
  registerAdministrationRoutes(app, database);
  registerOperationsRoutes(app, database);
  registerInsightsRoutes(app, database);

  app.get('/health', async (): Promise<HealthResponse> => ({ status: 'ok' }));

  app.get('/health/db', async (request, reply) => {
    try {
      await database.query('SELECT 1');
      return { status: 'ok', database: 'connected' };
    } catch (error) {
      const databaseError = error as { name?: string; code?: string };
      request.log.error(
        { errorName: databaseError.name, errorCode: databaseError.code },
        'Database health check failed'
      );
      return reply.status(503).send({
        error: 'database_unavailable',
        message: 'Database unavailable.'
      });
    }
  });

  app.get('/ready', async (_request, reply) => {
    try {
      await database.query('SELECT 1');
      return { status: 'ready' };
    } catch {
      return reply.status(503).send({
        error: 'dependency_unavailable',
        message: 'Service dependency unavailable.'
      });
    }
  });

  app.addHook('onClose', async () => {
    if (database === pool) await pool.end();
  });

  return app;
}
