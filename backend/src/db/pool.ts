import { Pool } from 'pg';

import { env } from '../config/env.js';

export const pool = new Pool({
  host: env.DATABASE_HOST,
  port: env.DATABASE_PORT,
  database: env.DATABASE_NAME,
  user: env.DATABASE_USER || undefined,
  password: env.DATABASE_PASSWORD || undefined,
  ssl: env.DATABASE_SSL
    ? {
        rejectUnauthorized: env.DATABASE_SSL_REJECT_UNAUTHORIZED,
        ca: env.DATABASE_SSL_CA
      }
    : undefined,
  max: env.PG_POOL_MAX,
  idleTimeoutMillis: env.PG_IDLE_TIMEOUT_MS,
  connectionTimeoutMillis: env.PG_CONNECTION_TIMEOUT_MS,
  statement_timeout: env.PG_STATEMENT_TIMEOUT_MS,
  application_name: 'fleet-control-backend'
});
