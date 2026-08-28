import { createHash, randomBytes } from 'node:crypto';

import type { QueryResultRow } from 'pg';

import { env } from '../config/env.js';
import type { Database } from './auth.types.js';

const SESSION_DURATION_MS = env.SESSION_TTL_HOURS * 60 * 60 * 1000;
const SESSION_TOKEN_BYTES = 32;
const MAX_SESSION_INSERT_ATTEMPTS = 3;

type LoginUserRow = QueryResultRow & {
  id: string;
  usuario: string;
  nombre: string;
  empresa_id: string | null;
  rol_id: string;
  rol_codigo: string;
  activo: boolean;
};

type CreatedSessionRow = QueryResultRow & { id: string };
type PasswordVerificationRow = QueryResultRow & { valid: boolean };

export type AuthenticatedUser = {
  id: string;
  usuario: string;
  nombre: string;
  empresaId: string | null;
  roleId: string;
  rolCodigo: string;
};

export type LoginResult = {
  user: AuthenticatedUser;
  sessionToken: string;
  expiresAt: string;
};

type DatabaseError = { code?: string };

function isActiveLoginUser(row: LoginUserRow | undefined): row is LoginUserRow {
  return row?.activo === true
    && typeof row.id === 'string'
    && typeof row.usuario === 'string'
    && typeof row.nombre === 'string'
    && typeof row.rol_id === 'string'
    && typeof row.rol_codigo === 'string'
    && (row.empresa_id === null || typeof row.empresa_id === 'string');
}

export function hashSessionToken(token: string): string {
  return createHash('sha256').update(token, 'utf8').digest('hex');
}

function generateSessionToken(): string {
  return randomBytes(SESSION_TOKEN_BYTES).toString('base64url');
}

export function createAuthService(database: Database) {
  async function login(usuario: string, password: string): Promise<LoginResult | null> {
    const loginResult = await database.query<LoginUserRow>(
      `SELECT id, usuario, nombre, empresa_id, rol_id, rol_codigo, activo
       FROM public.login_usuario($1::text, $2::text)`,
      [usuario, password]
    );
    const profile = loginResult.rows.length === 1 ? loginResult.rows[0] : undefined;

    if (!isActiveLoginUser(profile)) return null;

    const expiresAt = new Date(Date.now() + SESSION_DURATION_MS);

    for (let attempt = 0; attempt < MAX_SESSION_INSERT_ATTEMPTS; attempt += 1) {
      const sessionToken = generateSessionToken();
      const tokenHash = hashSessionToken(sessionToken);

      try {
        const sessionResult = await database.query<CreatedSessionRow>(
          `INSERT INTO public.sesiones (usuario_id, token_hash, expires_at)
           VALUES ($1::uuid, $2::text, $3::timestamptz)
           RETURNING id`,
          [profile.id, tokenHash, expiresAt]
        );

        if (typeof sessionResult.rows[0]?.id !== 'string') {
          throw new Error('Session insertion did not return an id.');
        }

        return {
          user: {
            id: profile.id,
            usuario: profile.usuario,
            nombre: profile.nombre,
            empresaId: profile.empresa_id,
            roleId: profile.rol_id,
            rolCodigo: profile.rol_codigo
          },
          sessionToken,
          expiresAt: expiresAt.toISOString()
        };
      } catch (error) {
        const databaseError = error as DatabaseError;
        const isLastAttempt = attempt === MAX_SESSION_INSERT_ATTEMPTS - 1;

        if (databaseError.code !== '23505' || isLastAttempt) throw error;
      }
    }

    throw new Error('Unable to create a unique session token.');
  }

  async function verifyCurrentPassword(userId: string, password: string): Promise<boolean> {
    const result = await database.query<PasswordVerificationRow>(
      `SELECT public.fleet_control_verify_usuario_password($1::uuid, $2::text) AS valid`,
      [userId, password]
    );

    return result.rows[0]?.valid === true;
  }

  async function setPassword(userId: string, password: string): Promise<void> {
    await database.query(
      `SELECT public.fleet_control_set_usuario_password($1::uuid, $2::text)`,
      [userId, password]
    );
  }

  return { login, verifyCurrentPassword, setPassword };
}
