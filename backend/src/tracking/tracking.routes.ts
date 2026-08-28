import type { FastifyInstance, FastifyReply } from 'fastify';
import type { QueryResultRow } from 'pg';

import type { Database } from '../auth/auth.types.js';
import { trackingRateLimit } from '../plugins/rate-limit.js';
import { driverLocationSchema } from './tracking.schemas.js';

type DriverLocationRow = QueryResultRow & {
  chofer_usuario_id: string;
  empresa_id: string;
  gestion_id: string | null;
  vehiculo_id: string | null;
  latitud: number;
  longitud: number;
  precision_metros: number | null;
  velocidad_mps: number | null;
  rumbo_grados: number | null;
  captured_at: Date | string;
};

type DatabaseError = { code?: string; message?: string };

function noStore(reply: FastifyReply): FastifyReply {
  return reply.header('Cache-Control', 'no-store');
}

function toLocationResponse(row: DriverLocationRow) {
  return {
    driver_user_id: row.chofer_usuario_id,
    company_id: row.empresa_id,
    management_id: row.gestion_id,
    vehicle_id: row.vehiculo_id,
    latitude: row.latitud,
    longitude: row.longitud,
    accuracy: row.precision_metros,
    speed: row.velocidad_mps,
    heading: row.rumbo_grados,
    captured_at: row.captured_at instanceof Date ? row.captured_at.toISOString() : row.captured_at
  };
}

export function registerTrackingRoutes(app: FastifyInstance, database: Database): void {
  app.post('/api/driver/location', {
    preHandler: app.requireFleetSession,
    config: trackingRateLimit
  }, async (request, reply) => {
    const session = request.fleetSession;
    if (!session) {
      return noStore(reply).code(401).send({
        error: 'invalid_session',
        message: 'Sesión inválida o expirada.'
      });
    }
    if (session.roleCode !== 'chofer') {
      return noStore(reply).code(403).send({
        error: 'forbidden',
        message: 'No tienes permiso para informar ubicación.'
      });
    }

    const payload = driverLocationSchema.safeParse(request.body);
    if (!payload.success) {
      return noStore(reply).code(400).send({
        error: 'invalid_request',
        message: 'Ubicación inválida.'
      });
    }

    try {
      const result = await database.query<DriverLocationRow>(
        `SELECT (public.fleet_control_update_driver_location(
            $1::uuid,
            $2::double precision,
            $3::double precision,
            $4::double precision,
            $5::double precision,
            $6::double precision,
            $7::timestamptz
          )).*`,
        [
          session.userId,
          payload.data.latitude,
          payload.data.longitude,
          payload.data.accuracy,
          payload.data.speed,
          payload.data.heading,
          new Date(payload.data.captured_at).toISOString()
        ]
      );
      const location = result.rows[0];

      if (!location) throw new Error('Driver location RPC did not return a row.');

      return noStore(reply).send({ location: toLocationResponse(location) });
    } catch (error) {
      const databaseError = error as DatabaseError;
      if (databaseError.message === 'invalid_location' || databaseError.message === 'invalid_captured_at') {
        return noStore(reply).code(400).send({
          error: databaseError.message,
          message: 'Ubicación inválida.'
        });
      }
      if (databaseError.message === 'forbidden') {
        return noStore(reply).code(403).send({
          error: 'forbidden',
          message: 'No tienes permiso para informar ubicación.'
        });
      }
      throw error;
    }
  });
}
