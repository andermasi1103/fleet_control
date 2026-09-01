import assert from 'node:assert/strict';
import test from 'node:test';

import { parseEnvironment } from '../src/config/env.js';
import { createDatabasePoolConfig } from '../src/db/pool-config.js';

function productionEnvironment(overrides: Record<string, string | undefined> = {}): NodeJS.ProcessEnv {
  return {
    NODE_ENV: 'production',
    PORT: '3000',
    BACKEND_HOST: '0.0.0.0',
    DATABASE_HOST: 'masitrack-preprod-db.internal',
    DATABASE_PORT: '5432',
    DATABASE_NAME: 'masitrack_preprod',
    DATABASE_USER: 'fleet_app',
    DATABASE_PASSWORD: 'test-only-password',
    DATABASE_NETWORK: 'external',
    DATABASE_SSL: 'true',
    DATABASE_SSL_REJECT_UNAUTHORIZED: 'true',
    API_LOG_LEVEL: 'info',
    CORS_ALLOWED_ORIGINS: 'https://preproduction.example.test',
    SESSION_TTL_HOURS: '24',
    ...overrides
  };
}

test('accepts production external PostgreSQL with verified TLS', () => {
  const environment = parseEnvironment(productionEnvironment());

  assert.equal(environment.DATABASE_NETWORK, 'external');
  assert.equal(environment.DATABASE_SSL, true);
  assert.equal(environment.DATABASE_SSL_REJECT_UNAUTHORIZED, true);
});

test('rejects production external PostgreSQL without TLS', () => {
  assert.throws(
    () => parseEnvironment(productionEnvironment({ DATABASE_SSL: 'false' })),
    /DATABASE_SSL must be true when DATABASE_NETWORK=external in production/
  );
});

test('accepts production Render private PostgreSQL without TLS', () => {
  const environment = parseEnvironment(productionEnvironment({
    DATABASE_NETWORK: 'render_private',
    DATABASE_SSL: 'false'
  }));

  assert.equal(environment.DATABASE_NETWORK, 'render_private');
  assert.equal(environment.DATABASE_SSL, false);
});

test('omits the pg ssl option for Render private PostgreSQL', () => {
  const environment = parseEnvironment(productionEnvironment({
    DATABASE_NETWORK: 'render_private',
    DATABASE_SSL: 'false'
  }));
  const poolConfig = createDatabasePoolConfig(environment);

  assert.equal(Object.hasOwn(poolConfig, 'ssl'), false);
});

test('rejects postgres as the production runtime user', () => {
  assert.throws(
    () => parseEnvironment(productionEnvironment({ DATABASE_USER: 'postgres' })),
    /The PostgreSQL superuser is not allowed in production/
  );
});

test('rejects contradictory or implicit production database network settings', () => {
  assert.throws(
    () => parseEnvironment(productionEnvironment({
      DATABASE_NETWORK: 'render_private',
      DATABASE_SSL: 'true'
    })),
    /DATABASE_SSL must be false when DATABASE_NETWORK=render_private in production/
  );
  assert.throws(
    () => parseEnvironment(productionEnvironment({ DATABASE_SSL_REJECT_UNAUTHORIZED: 'false' })),
    /DATABASE_SSL_REJECT_UNAUTHORIZED must be true in production/
  );
  assert.throws(
    () => parseEnvironment(productionEnvironment({ DATABASE_NETWORK: undefined })),
    /DATABASE_NETWORK must be set explicitly in production/
  );
});
