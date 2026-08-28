import type { FastifyInstance, FastifyReply, FastifyRequest } from 'fastify';
import type { QueryResultRow } from 'pg';

import { hashSessionToken } from '../auth/auth.service.js';
import type { Database, FleetSession } from '../auth/auth.types.js';

const LAST_USED_UPDATE_INTERVAL_MS = 5 * 60 * 1000;

type SessionRow = QueryResultRow & {
  session_id: string;
  user_id: string;
  username: string;
  role_id: string;
  role_code: string;
  company_id: string | null;
  expires_at: Date | string;
};

function sessionError(reply: FastifyReply): void {
  void reply.code(401).send({
    error: 'invalid_session',
    message: 'Sesión inválida o expirada.'
  });
}

function extractBearerToken(authorization: string | undefined): string | null {
  if (!authorization) return null;

  const match = /^Bearer ([A-Za-z0-9_-]+)$/.exec(authorization);
  return match?.[1] ?? null;
}

function toFleetSession(row: SessionRow | undefined): FleetSession | null {
  if (!row
    || typeof row.session_id !== 'string'
    || typeof row.user_id !== 'string'
    || typeof row.username !== 'string'
    || typeof row.role_id !== 'string'
    || typeof row.role_code !== 'string'
    || (row.company_id !== null && typeof row.company_id !== 'string')) {
    return null;
  }

  const expiresAt = row.expires_at instanceof Date
    ? row.expires_at.toISOString()
    : typeof row.expires_at === 'string'
      ? row.expires_at
      : null;

  if (!expiresAt) return null;

  return {
    sessionId: row.session_id,
    userId: row.user_id,
    username: row.username,
    roleId: row.role_id,
    roleCode: row.role_code,
    companyId: row.company_id,
    expiresAt
  };
}

export function registerSessionAuth(app: FastifyInstance, database: Database): void {
  const lastUsedUpdates = new Map<string, number>();

  app.decorateRequest('fleetSession', null);
  app.decorate('requireFleetSession', async (request: FastifyRequest, reply: FastifyReply): Promise<void> => {
    const token = extractBearerToken(request.headers.authorization);
    if (!token) return sessionError(reply);

    const tokenHash = hashSessionToken(token);
    const result = await database.query<SessionRow>(
      `SELECT s.id AS session_id,
              u.id AS user_id,
              u.usuario AS username,
              u.empresa_id AS company_id,
              u.rol_id AS role_id,
              r.codigo AS role_code,
              s.expires_at
       FROM public.sesiones s
       JOIN public.usuarios u ON u.id = s.usuario_id
       JOIN public.roles r ON r.id = u.rol_id AND r.activo = true
       WHERE s.token_hash = $1::text
         AND s.revoked_at IS NULL
         AND s.expires_at > now()
         AND u.activo = true
       LIMIT 1`,
      [tokenHash]
    );
    const session = toFleetSession(result.rows[0]);

    if (!session) return sessionError(reply);

    request.fleetSession = session;

    const now = Date.now();
    const lastUpdate = lastUsedUpdates.get(session.sessionId) ?? 0;
    if (now - lastUpdate >= LAST_USED_UPDATE_INTERVAL_MS) {
      lastUsedUpdates.set(session.sessionId, now);
      void database.query(
        `UPDATE public.sesiones
         SET last_used_at = now()
         WHERE id = $1::uuid
           AND revoked_at IS NULL`,
        [session.sessionId]
      ).catch(() => lastUsedUpdates.delete(session.sessionId));
    }
  });
}
