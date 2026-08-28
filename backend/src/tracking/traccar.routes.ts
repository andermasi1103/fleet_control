import type { FastifyInstance, FastifyReply } from 'fastify';

import type { Database, FleetSession } from '../auth/auth.types.js';
import { env } from '../config/env.js';
import { sensitiveRateLimit } from '../plugins/rate-limit.js';

const resources = new Set(['devices', 'positions', 'events']);

function noStore(reply: FastifyReply): FastifyReply {
  return reply.header('Cache-Control', 'no-store');
}

function canReadTracking(session: FleetSession): boolean {
  return ['super_admin', 'admin', 'supervisor'].includes(session.roleCode);
}

async function loadResource(resource: string): Promise<unknown> {
  if (!env.TRACCAR_BASE_URL || !env.TRACCAR_AUTHORIZATION) {
    throw new Error('traccar_unconfigured');
  }

  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), env.TRACCAR_HTTP_TIMEOUT_MS);
  try {
    const response = await fetch(new URL(resource, `${env.TRACCAR_BASE_URL.replace(/\/$/, '')}/`), {
      headers: { Authorization: env.TRACCAR_AUTHORIZATION, Accept: 'application/json' },
      signal: controller.signal
    });
    if (!response.ok) throw new Error('traccar_unavailable');
    return await response.json();
  } finally {
    clearTimeout(timeout);
  }
}

export function registerTraccarRoutes(app: FastifyInstance, _database: Database): void {
  app.get('/api/tracking/:resource', {
    preHandler: app.requireFleetSession,
    config: sensitiveRateLimit
  }, async (request, reply) => {
    const session = request.fleetSession;
    const resource = (request.params as { resource?: string }).resource;
    if (!session) {
      return noStore(reply).code(401).send({ error: 'invalid_session', message: 'Sesión inválida o expirada.' });
    }
    if (!canReadTracking(session)) {
      return noStore(reply).code(403).send({ error: 'forbidden', message: 'No tienes permiso para consultar el seguimiento.' });
    }
    if (!resource || !resources.has(resource)) {
      return noStore(reply).code(404).send({ error: 'not_found', message: 'Recurso no encontrado.' });
    }

    try {
      const items = await loadResource(resource);
      if (!Array.isArray(items)) throw new Error('traccar_unavailable');
      return noStore(reply).send({ items });
    } catch (error) {
      const code = (error as { message?: string }).message;
      if (code === 'traccar_unconfigured') {
        return noStore(reply).code(503).send({ error: 'dependency_unavailable', message: 'Seguimiento no configurado.' });
      }
      request.log.warn({ resource }, 'Tracking provider request failed');
      return noStore(reply).code(503).send({ error: 'dependency_unavailable', message: 'Seguimiento no disponible.' });
    }
  });
}
