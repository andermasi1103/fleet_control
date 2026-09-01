import type { PoolConfig } from 'pg';

export type DatabasePoolSettings = {
  DATABASE_HOST: string;
  DATABASE_PORT: number;
  DATABASE_NAME: string;
  DATABASE_USER?: string;
  DATABASE_PASSWORD?: string;
  DATABASE_SSL: boolean;
  DATABASE_SSL_REJECT_UNAUTHORIZED: boolean;
  DATABASE_SSL_CA?: string;
  PG_POOL_MAX: number;
  PG_IDLE_TIMEOUT_MS: number;
  PG_CONNECTION_TIMEOUT_MS: number;
  PG_STATEMENT_TIMEOUT_MS: number;
};

export function createDatabasePoolConfig(settings: DatabasePoolSettings): PoolConfig {
  return {
    host: settings.DATABASE_HOST,
    port: settings.DATABASE_PORT,
    database: settings.DATABASE_NAME,
    user: settings.DATABASE_USER || undefined,
    password: settings.DATABASE_PASSWORD || undefined,
    ...(settings.DATABASE_SSL
      ? {
          ssl: {
            rejectUnauthorized: settings.DATABASE_SSL_REJECT_UNAUTHORIZED,
            ca: settings.DATABASE_SSL_CA
          }
        }
      : {}),
    max: settings.PG_POOL_MAX,
    idleTimeoutMillis: settings.PG_IDLE_TIMEOUT_MS,
    connectionTimeoutMillis: settings.PG_CONNECTION_TIMEOUT_MS,
    statement_timeout: settings.PG_STATEMENT_TIMEOUT_MS,
    application_name: 'fleet-control-backend'
  };
}
