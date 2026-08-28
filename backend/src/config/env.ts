import 'dotenv/config';

import { z } from 'zod';

const booleanFromEnv = z.enum(['true', 'false']).transform((value) => value === 'true');

const envSchema = z.object({
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  PORT: z.coerce.number().int().min(1).max(65_535).default(3000),
  HOST: z.string().min(1).default('127.0.0.1'),
  DATABASE_HOST: z.string().min(1).default('localhost'),
  DATABASE_PORT: z.coerce.number().int().min(1).max(65_535).default(5432),
  DATABASE_NAME: z.string().min(1).default('fleet_control_db'),
  DATABASE_USER: z.string().min(1).optional(),
  DATABASE_PASSWORD: z.string().min(1).optional(),
  DATABASE_SSL: booleanFromEnv.default('false'),
  DATABASE_SSL_REJECT_UNAUTHORIZED: booleanFromEnv.default('true'),
  DATABASE_SSL_CA: z.string().optional(),
  API_LOG_LEVEL: z.enum(['fatal', 'error', 'warn', 'info', 'debug', 'trace', 'silent']).default('info'),
  CORS_ALLOWED_ORIGINS: z.string().optional(),
  CORS_ORIGIN: z.string().optional(),
  TRUST_PROXY: z.string().default('false'),
  BODY_LIMIT_BYTES: z.coerce.number().int().min(1_024).max(20 * 1024 * 1024).default(1_048_576),
  REQUEST_TIMEOUT_MS: z.coerce.number().int().min(1_000).max(120_000).default(30_000),
  PG_POOL_MAX: z.coerce.number().int().min(1).max(100).default(10),
  PG_IDLE_TIMEOUT_MS: z.coerce.number().int().min(1_000).max(300_000).default(30_000),
  PG_CONNECTION_TIMEOUT_MS: z.coerce.number().int().min(1_000).max(60_000).default(5_000),
  PG_STATEMENT_TIMEOUT_MS: z.coerce.number().int().min(1_000).max(300_000).default(30_000),
  SESSION_TTL_HOURS: z.coerce.number().int().min(1).max(168).default(24),
  API_RATE_LIMIT_MAX: z.coerce.number().int().min(10).max(10_000).default(300),
  API_RATE_LIMIT_WINDOW_MS: z.coerce.number().int().min(1_000).max(3_600_000).default(60_000),
  LOGIN_USERNAME_LIMIT_MAX: z.coerce.number().int().min(1).max(20).default(5),
  LOGIN_USERNAME_WINDOW_MS: z.coerce.number().int().min(10_000).max(3_600_000).default(60_000),
  LOGIN_IP_LIMIT_MAX: z.coerce.number().int().min(5).max(100).default(20),
  LOGIN_IP_WINDOW_MS: z.coerce.number().int().min(60_000).max(86_400_000).default(900_000),
  FIREBASE_SERVICE_ACCOUNT_JSON: z.string().optional(),
  FIREBASE_HTTP_TIMEOUT_MS: z.coerce.number().int().min(1_000).max(60_000).default(10_000),
  TRACCAR_BASE_URL: z.string().url().optional(),
  TRACCAR_AUTHORIZATION: z.string().min(1).optional(),
  TRACCAR_HTTP_TIMEOUT_MS: z.coerce.number().int().min(1_000).max(60_000).default(10_000)
}).superRefine((value, context) => {
  if (value.NODE_ENV !== 'production') return;

  const requiredProductionVariables = [
    'PORT', 'HOST', 'DATABASE_HOST', 'DATABASE_PORT', 'DATABASE_NAME',
    'DATABASE_USER', 'DATABASE_PASSWORD', 'DATABASE_SSL', 'API_LOG_LEVEL',
    'CORS_ALLOWED_ORIGINS', 'SESSION_TTL_HOURS'
  ] as const;
  for (const key of requiredProductionVariables) {
    if (!process.env[key]?.trim()) {
      context.addIssue({ code: z.ZodIssueCode.custom, path: [key], message: 'Must be set explicitly in production.' });
    }
  }

  if (value.DATABASE_USER === 'postgres') {
    context.addIssue({ code: z.ZodIssueCode.custom, path: ['DATABASE_USER'], message: 'The PostgreSQL superuser is not allowed in production.' });
  }
  if (!value.DATABASE_SSL || !value.DATABASE_SSL_REJECT_UNAUTHORIZED) {
    context.addIssue({ code: z.ZodIssueCode.custom, path: ['DATABASE_SSL'], message: 'Verified PostgreSQL TLS is required in production.' });
  }
  if ((value.TRACCAR_BASE_URL && !value.TRACCAR_AUTHORIZATION) || (!value.TRACCAR_BASE_URL && value.TRACCAR_AUTHORIZATION)) {
    context.addIssue({ code: z.ZodIssueCode.custom, path: ['TRACCAR_BASE_URL'], message: 'Traccar URL and authorization must be configured together.' });
  }
});

const parsedEnv = envSchema.safeParse(process.env);

if (!parsedEnv.success) {
  throw new Error('Invalid environment configuration. Review backend/.env.');
}

export const env = parsedEnv.data;

export const corsOrigins = (env.CORS_ALLOWED_ORIGINS ?? env.CORS_ORIGIN ?? '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

if (corsOrigins.includes('*')) {
  throw new Error('CORS wildcard origins are not allowed.');
}

if (env.NODE_ENV === 'production' && corsOrigins.length === 0) {
  throw new Error('CORS_ALLOWED_ORIGINS is required in production.');
}

export const trustedProxy = (() => {
  const raw = env.TRUST_PROXY.trim();
  if (!raw || raw === 'false') return false;
  if (raw === 'true') throw new Error('TRUST_PROXY=true is unsafe. Configure explicit proxy IPs or CIDRs.');
  return raw.split(',').map((value) => value.trim()).filter(Boolean);
})();
