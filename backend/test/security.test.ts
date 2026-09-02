import assert from 'node:assert/strict';
import test from 'node:test';

import type { QueryResultRow } from 'pg';

import type { Database, DatabaseQueryResult } from '../src/auth/auth.types.js';

process.env.CORS_ALLOWED_ORIGINS ??= 'http://localhost:8080';

const { buildApp } = await import('../src/app.js');

class SecurityDatabase implements Database {
  async query<Row extends QueryResultRow = QueryResultRow>(
    text: string
  ): Promise<DatabaseQueryResult<Row>> {
    if (text.includes('public.login_usuario')) return { rows: [], rowCount: 0 };
    if (text.includes('SELECT 1')) return { rows: [{ ok: 1 }] as Row[], rowCount: 1 };
    throw new Error(`Unexpected query in security test: ${text}`);
  }
}

test('security headers are present and an untrusted browser origin is not allowed', async () => {
  const app = await buildApp({ database: new SecurityDatabase() });
  try {
    const response = await app.inject({
      method: 'GET',
      url: '/health',
      headers: { origin: 'https://untrusted.example' }
    });

    assert.equal(response.statusCode, 200);
    assert.equal(response.headers['x-content-type-options'], 'nosniff');
    assert.equal(response.headers['x-frame-options'], 'DENY');
    assert.equal(response.headers['referrer-policy'], 'no-referrer');
    assert.equal(response.headers['access-control-allow-origin'], undefined);
  } finally {
    await app.close();
  }
});

test('the configured local browser origin is allowed', async () => {
  const app = await buildApp({ database: new SecurityDatabase() });
  try {
    const response = await app.inject({
      method: 'GET',
      url: '/health',
      headers: { origin: 'http://localhost:8080' }
    });
    assert.equal(response.statusCode, 200);
    assert.equal(response.headers['access-control-allow-origin'], 'http://localhost:8080');
  } finally {
    await app.close();
  }
});

test('CORS preflight permits PATCH for the configured local browser origin', async () => {
  const app = await buildApp({ database: new SecurityDatabase() });
  try {
    const response = await app.inject({
      method: 'OPTIONS',
      url: '/api/locations/00000000-0000-0000-0000-000000000001',
      headers: {
        origin: 'http://localhost:8080',
        'access-control-request-method': 'PATCH'
      }
    });

    assert.equal(response.statusCode, 204);
    assert.equal(response.headers['access-control-allow-origin'], 'http://localhost:8080');
    assert.match(response.headers['access-control-allow-methods'] ?? '', /\bPATCH\b/);
  } finally {
    await app.close();
  }
});

test('CORS preflight does not allow an untrusted browser origin', async () => {
  const app = await buildApp({ database: new SecurityDatabase() });
  try {
    const response = await app.inject({
      method: 'OPTIONS',
      url: '/api/locations/00000000-0000-0000-0000-000000000001',
      headers: {
        origin: 'https://untrusted.example',
        'access-control-request-method': 'PATCH'
      }
    });

    assert.equal(response.statusCode, 404);
    assert.equal(response.headers['access-control-allow-origin'], undefined);
  } finally {
    await app.close();
  }
});

test('login attempts are limited without revealing whether the user exists', async () => {
  const app = await buildApp({ database: new SecurityDatabase() });
  try {
    for (let attempt = 0; attempt < 5; attempt += 1) {
      const response = await app.inject({
        method: 'POST',
        url: '/api/auth/login',
        headers: { origin: 'http://localhost:8080' },
        payload: { usuario: 'unknown-user', password: 'incorrecta' }
      });
      assert.equal(response.statusCode, 401);
      assert.equal(response.headers['access-control-allow-origin'], 'http://localhost:8080');
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
  } finally {
    await app.close();
  }
});

test('the Traccar proxy requires a Fleet session', async () => {
  const app = await buildApp({ database: new SecurityDatabase() });
  try {
    const response = await app.inject({
      method: 'GET',
      url: '/api/tracking/devices'
    });
    assert.equal(response.statusCode, 401);
  } finally {
    await app.close();
  }
});
