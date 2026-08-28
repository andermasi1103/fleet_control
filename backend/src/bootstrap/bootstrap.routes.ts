import type { FastifyInstance, FastifyReply } from 'fastify';
import type { QueryResultRow } from 'pg';

import type { Database } from '../auth/auth.types.js';
import { sensitiveRateLimit } from '../plugins/rate-limit.js';
import {
  notificationDeviceRegisterSchema,
  notificationDeviceUnregisterSchema,
  notificationIdParamsSchema,
  notificationListQuerySchema
} from './bootstrap.schemas.js';

type ViewRow = QueryResultRow & { codigo: string };
type NotificationRow = QueryResultRow & {
  id: string;
  tipo: string;
  titulo: string;
  mensaje: string;
  entity_type: string | null;
  entity_id: string | null;
  ruta: string | null;
  leida: boolean;
  created_at: Date;
  read_at: Date | null;
};
type UpdatedNotificationRow = QueryResultRow & { id: string };

function noStore(reply: FastifyReply): FastifyReply {
  return reply.header('Cache-Control', 'no-store');
}

function invalidRequest(reply: FastifyReply): FastifyReply {
  return noStore(reply).code(400).send({
    error: 'invalid_request',
    message: 'Solicitud inválida.'
  });
}

export function registerBootstrapRoutes(app: FastifyInstance, database: Database): void {
  app.get('/api/me/views', { preHandler: app.requireFleetSession }, async (request, reply) => {
    const session = request.fleetSession;
    if (!session) return noStore(reply).code(401).send({ error: 'invalid_session', message: 'Sesión inválida o expirada.' });

    const result = await database.query<ViewRow>(
      `SELECT av.codigo
       FROM public.role_views rv
       JOIN public.app_views av ON av.id = rv.view_id
       WHERE rv.role_id = $1::uuid
         AND rv.visible = true
         AND av.activo = true
       ORDER BY av.orden ASC`,
      [session.roleId]
    );

    return noStore(reply).send({ views: result.rows.map((row) => row.codigo) });
  });

  app.get('/api/notifications', { preHandler: app.requireFleetSession }, async (request, reply) => {
    const query = notificationListQuerySchema.safeParse(request.query);
    if (!query.success) return invalidRequest(reply);

    const session = request.fleetSession;
    if (!session) return noStore(reply).code(401).send({ error: 'invalid_session', message: 'Sesión inválida o expirada.' });

    const result = await database.query<NotificationRow>(
      `SELECT id, tipo, titulo, mensaje, entity_type, entity_id, ruta, leida, created_at, read_at
       FROM public.notificaciones
       WHERE usuario_id = $1::uuid
       ORDER BY created_at DESC
       LIMIT $2::int`,
      [session.userId, query.data.limit]
    );

    return noStore(reply).send({ notifications: result.rows });
  });

  app.post('/api/notifications/:id/read', { preHandler: app.requireFleetSession }, async (request, reply) => {
    const params = notificationIdParamsSchema.safeParse(request.params);
    if (!params.success) return invalidRequest(reply);

    const session = request.fleetSession;
    if (!session) return noStore(reply).code(401).send({ error: 'invalid_session', message: 'Sesión inválida o expirada.' });

    const result = await database.query<UpdatedNotificationRow>(
      `UPDATE public.notificaciones
       SET leida = true,
           read_at = now()
       WHERE id = $1::uuid
         AND usuario_id = $2::uuid
       RETURNING id`,
      [params.data.id, session.userId]
    );

    if (result.rowCount !== 1) {
      return noStore(reply).code(404).send({
        error: 'not_found',
        message: 'Notificación no encontrada.'
      });
    }

    return noStore(reply).send({ success: true });
  });

  app.post('/api/notification-devices', {
    preHandler: app.requireFleetSession,
    config: sensitiveRateLimit
  }, async (request, reply) => {
    const payload = notificationDeviceRegisterSchema.safeParse(request.body);
    if (!payload.success) return invalidRequest(reply);

    const session = request.fleetSession;
    if (!session) return noStore(reply).code(401).send({ error: 'invalid_session', message: 'Sesión inválida o expirada.' });

    await database.query(
      `INSERT INTO public.notification_devices (
         usuario_id, token, platform, device_id, activo, last_seen_at, updated_at
       ) VALUES ($1::uuid, $2::text, $3::text, $4::text, true, now(), now())
       ON CONFLICT (token) DO UPDATE
       SET usuario_id = EXCLUDED.usuario_id,
           platform = EXCLUDED.platform,
           device_id = EXCLUDED.device_id,
           activo = true,
           last_seen_at = now(),
           updated_at = now()`,
      [session.userId, payload.data.token, payload.data.platform, payload.data.deviceId ?? null]
    );

    return noStore(reply).send({ success: true });
  });

  app.post('/api/notification-devices/unregister', {
    preHandler: app.requireFleetSession,
    config: sensitiveRateLimit
  }, async (request, reply) => {
    const payload = notificationDeviceUnregisterSchema.safeParse(request.body);
    if (!payload.success) return invalidRequest(reply);

    const session = request.fleetSession;
    if (!session) return noStore(reply).code(401).send({ error: 'invalid_session', message: 'Sesión inválida o expirada.' });

    await database.query(
      `UPDATE public.notification_devices
       SET activo = false,
           updated_at = now()
       WHERE usuario_id = $1::uuid
         AND token = $2::text`,
      [session.userId, payload.data.token]
    );

    return noStore(reply).send({ success: true });
  });
}
