import type { FastifyInstance, FastifyReply } from 'fastify';

import { changePasswordRequestSchema, loginRequestSchema } from './auth.schemas.js';
import { createAuthService } from './auth.service.js';
import type { Database } from './auth.types.js';
import { env } from '../config/env.js';
import { sensitiveRateLimit } from '../plugins/rate-limit.js';

function noStore(reply: FastifyReply): FastifyReply {
  return reply.header('Cache-Control', 'no-store');
}

export function registerAuthRoutes(app: FastifyInstance, database: Database): void {
  const authService = createAuthService(database);
  const loginIpRateLimit = app.createRateLimit({
    max: env.LOGIN_IP_LIMIT_MAX,
    timeWindow: env.LOGIN_IP_WINDOW_MS,
    keyGenerator: (request) => request.ip
  });

  app.post('/api/auth/login', {
    config: {
      rateLimit: {
        max: env.LOGIN_USERNAME_LIMIT_MAX,
        timeWindow: env.LOGIN_USERNAME_WINDOW_MS,
        groupId: 'login-identity',
        keyGenerator: (request) => {
          const body = request.body as { usuario?: unknown } | undefined;
          const usuario = typeof body?.usuario === 'string'
            ? body.usuario.trim().toLocaleLowerCase('es')
            : '';
          return `${request.ip}:${usuario}`;
        }
      }
    }
  }, async (request, reply) => {
    await loginIpRateLimit(request);

    const payload = loginRequestSchema.safeParse(request.body);
    if (!payload.success) {
      return noStore(reply).code(400).send({
        error: 'invalid_request',
        message: 'Solicitud de inicio de sesión inválida.'
      });
    }

    const login = await authService.login(payload.data.usuario, payload.data.password);
    if (!login) {
      return noStore(reply).code(401).send({
        error: 'invalid_credentials',
        message: 'Usuario o contraseña incorrectos.'
      });
    }

    return noStore(reply).send(login);
  });

  app.post('/api/auth/logout', { preHandler: app.requireFleetSession }, async (request, reply) => {
    const session = request.fleetSession;
    if (!session) {
      return noStore(reply).code(401).send({
        error: 'invalid_session',
        message: 'Sesión inválida o expirada.'
      });
    }

    await database.query(
      `UPDATE public.sesiones
       SET revoked_at = now()
       WHERE id = $1::uuid
         AND revoked_at IS NULL`,
      [session.sessionId]
    );

    return noStore(reply).send({ success: true });
  });

  app.post('/api/profile/password', {
    preHandler: app.requireFleetSession,
    config: sensitiveRateLimit
  }, async (request, reply) => {
    const payload = changePasswordRequestSchema.safeParse(request.body);
    if (!payload.success) {
      return noStore(reply).code(400).send({
        error: 'invalid_request',
        message: 'Solicitud de cambio de contraseña inválida.'
      });
    }

    const session = request.fleetSession;
    if (!session) {
      return noStore(reply).code(401).send({
        error: 'invalid_session',
        message: 'Sesión inválida o expirada.'
      });
    }

    const currentPasswordValid = await authService.verifyCurrentPassword(
      session.userId,
      payload.data.currentPassword
    );
    if (!currentPasswordValid) {
      return noStore(reply).code(403).send({
        error: 'invalid_current_password',
        message: 'La contraseña actual es incorrecta.'
      });
    }

    await authService.setPassword(session.userId, payload.data.newPassword);

    return noStore(reply).send({
      success: true,
      reauthenticationRequired: true
    });
  });
}
