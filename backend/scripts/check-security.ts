import assert from 'node:assert/strict';

import type { QueryResultRow } from 'pg';

import type { Database, DatabaseQueryResult } from '../src/auth/auth.types.js';

process.env.CORS_ALLOWED_ORIGINS ??= 'http://localhost:8080';

const { buildApp } = await import('../src/app.js');

class SecurityDatabase implements Database {
  async query<Row extends QueryResultRow = QueryResultRow>(
    text: string
  ): Promise<DatabaseQueryResult<Row>> {
    if (text.includes('public.login_usuario')) return { rows: [], rowCount: 0 };
    if (text.includes('SELECT 1')) return { rows: [{ ok: 1 }] as unknown as Row[], rowCount: 1 };
    throw new Error(`Unexpected query in security check: ${text}`);
  }
}

const app = await buildApp({ database: new SecurityDatabase() });

try {
  const untrustedOrigin = await app.inject({
    method: 'GET',
    url: '/health',
    headers: { origin: 'https://untrusted.example' }
  });
  assert.equal(untrustedOrigin.statusCode, 200);
  assert.equal(untrustedOrigin.headers['x-content-type-options'], 'nosniff');
  assert.equal(untrustedOrigin.headers['x-frame-options'], 'DENY');
  assert.equal(untrustedOrigin.headers['referrer-policy'], 'no-referrer');
  assert.equal(untrustedOrigin.headers['access-control-allow-origin'], undefined);

  const allowedOrigin = await app.inject({
    method: 'GET',
    url: '/health',
    headers: { origin: 'http://localhost:8080' }
  });
  assert.equal(allowedOrigin.headers['access-control-allow-origin'], 'http://localhost:8080');

  for (let attempt = 0; attempt < 5; attempt += 1) {
    const response = await app.inject({
      method: 'POST',
      url: '/api/auth/login',
      payload: { usuario: 'unknown-user', password: 'incorrecta' }
    });
    assert.equal(response.statusCode, 401);
    assert.deepEqual(response.json(), {
      error: 'invalid_credentials',
      message: 'Usuario o contraseña incorrectos.'
    });
  }

  const limited = await app.inject({
    method: 'POST',
    url: '/api/auth/login',
    payload: { usuario: 'unknown-user', password: 'incorrecta' }
  });
  assert.equal(limited.statusCode, 429);
  assert.equal(limited.json().error, 'rate_limited');

  const protectedTracking = await app.inject({
    method: 'GET',
    url: '/api/tracking/devices'
  });
  assert.equal(protectedTracking.statusCode, 401);
  console.log('Security checks passed');
} finally {
  await app.close();
}
