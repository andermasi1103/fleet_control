type LoginResponse = {
  sessionToken?: unknown;
};

type DriverSnapshot = {
  latitude: number;
  longitude: number;
  accuracy: number | null;
  speed: number | null;
  heading: number | null;
  capturedAt: string;
  lastSeenAt: string;
  connectionStatus: string;
};

class UatFailure extends Error {}

function requiredEnvironmentVariable(name: 'UAT_FIXTURE_PASSWORD'): string {
  const value = process.env[name]?.trim();
  if (!value) throw new UatFailure(`Missing required UAT environment variable: ${name}`);
  return value;
}

function apiBaseUrl(): URL {
  const value = process.env.UAT_API_BASE_URL?.trim() || 'http://127.0.0.1:3000';
  try {
    return new URL(value.endsWith('/') ? value : `${value}/`);
  } catch {
    throw new UatFailure('UAT_API_BASE_URL must be an absolute URL.');
  }
}

function assertUat(condition: unknown, message: string): asserts condition {
  if (!condition) throw new UatFailure(message);
}

function exactEqual(actual: unknown, expected: unknown, message: string): void {
  assertUat(Object.is(actual, expected), message);
}

function timestampAfter(after: string, before: string, message: string): void {
  const afterTime = Date.parse(after);
  const beforeTime = Date.parse(before);
  assertUat(Number.isFinite(afterTime) && Number.isFinite(beforeTime) && afterTime > beforeTime, message);
}

function numberOrNull(value: unknown, field: string): number | null {
  if (value === null) return null;
  assertUat(typeof value === 'number' && Number.isFinite(value), `Fleet location has an invalid ${field}.`);
  return value;
}

async function json(response: Response, path: string): Promise<Record<string, unknown>> {
  try {
    const value: unknown = await response.json();
    assertUat(typeof value === 'object' && value !== null && !Array.isArray(value), `Invalid JSON from ${path}.`);
    return value as Record<string, unknown>;
  } catch (error) {
    if (error instanceof UatFailure) throw error;
    throw new UatFailure(`Invalid JSON from ${path}.`);
  }
}

async function run(): Promise<void> {
  const password = requiredEnvironmentVariable('UAT_FIXTURE_PASSWORD');
  const baseUrl = apiBaseUrl();

  async function request(path: string, init: RequestInit = {}): Promise<Response> {
    try {
      return await fetch(new URL(path.replace(/^\//, ''), baseUrl), init);
    } catch {
      throw new UatFailure(`Request to ${path} failed.`);
    }
  }

  async function expectStatus(
    path: string,
    expectedStatus: number,
    init: RequestInit = {}
  ): Promise<Response> {
    const response = await request(path, init);
    if (response.status !== expectedStatus) {
      throw new UatFailure(`${path} returned HTTP ${response.status}; expected ${expectedStatus}.`);
    }
    return response;
  }

  async function login(username: string): Promise<string> {
    const response = await expectStatus('/api/auth/login', 200, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ usuario: username, password })
    });
    const body = await json(response, '/api/auth/login') as LoginResponse;
    assertUat(typeof body.sessionToken === 'string' && body.sessionToken.length > 0, `Login ${username} did not return a session.`);
    return body.sessionToken;
  }

  const bearer = (token: string): HeadersInit => ({ authorization: `Bearer ${token}` });
  const presence = (token: string, body: Record<string, unknown> = {}): RequestInit => ({
    method: 'POST',
    headers: { ...bearer(token), 'content-type': 'application/json' },
    body: JSON.stringify(body)
  });

  async function fleetSnapshot(adminToken: string): Promise<DriverSnapshot> {
    const response = await expectStatus('/api/fleet/locations', 200, { headers: bearer(adminToken) });
    const body = await json(response, '/api/fleet/locations');
    assertUat(Array.isArray(body.drivers), 'Fleet locations did not return drivers.');
    const driver = body.drivers.find((value) => (
      typeof value === 'object'
      && value !== null
      && (value as Record<string, unknown>).driver_username === 'uat_chofer'
    ));
    assertUat(typeof driver === 'object' && driver !== null, 'UAT driver was not returned by fleet locations.');
    const location = driver as Record<string, unknown>;
    assertUat(typeof location.latitude === 'number' && Number.isFinite(location.latitude), 'UAT driver has no valid latitude.');
    assertUat(typeof location.longitude === 'number' && Number.isFinite(location.longitude), 'UAT driver has no valid longitude.');
    assertUat(typeof location.captured_at === 'string', 'UAT driver has no captured_at.');
    assertUat(typeof location.last_seen_at === 'string', 'UAT driver has no last_seen_at.');
    assertUat(typeof location.connection_status === 'string', 'UAT driver has no connection status.');
    return {
      latitude: location.latitude,
      longitude: location.longitude,
      accuracy: numberOrNull(location.accuracy, 'accuracy'),
      speed: numberOrNull(location.speed, 'speed'),
      heading: numberOrNull(location.heading, 'heading'),
      capturedAt: location.captured_at,
      lastSeenAt: location.last_seen_at,
      connectionStatus: location.connection_status
    };
  }

  async function sendLocation(token: string, latitude: number, longitude: number): Promise<string> {
    const capturedAt = new Date().toISOString();
    await expectStatus('/api/driver/location', 200, {
      method: 'POST',
      headers: { ...bearer(token), 'content-type': 'application/json' },
      body: JSON.stringify({
        latitude,
        longitude,
        accuracy: 8,
        speed: 0,
        heading: 90,
        captured_at: capturedAt
      })
    });
    return capturedAt;
  }

  await expectStatus('/health', 200);
  await expectStatus('/health/db', 200);
  await expectStatus('/ready', 200);
  console.log('PASS health');

  const [driverToken, adminToken, supervisorToken] = await Promise.all([
    login('uat_chofer'),
    login('uat_admin'),
    login('uat_supervisor')
  ]);
  console.log('PASS login uat_chofer');
  console.log('PASS login uat_admin');
  console.log('PASS login uat_supervisor');

  const initialCapturedAt = await sendLocation(driverToken, -25.2867, -57.6470);
  const initial = await fleetSnapshot(adminToken);
  exactEqual(initial.capturedAt, initialCapturedAt, 'Initial captured_at does not match the GPS timestamp.');
  console.log('PASS GPS initial');

  await new Promise<void>((resolve) => setTimeout(resolve, 1_100));
  await expectStatus('/api/driver/presence', 204, presence(driverToken));
  const afterPresence = await fleetSnapshot(adminToken);
  timestampAfter(afterPresence.lastSeenAt, initial.lastSeenAt, 'last_seen_at did not advance after presence.');
  exactEqual(afterPresence.capturedAt, initial.capturedAt, 'captured_at changed after presence.');
  exactEqual(afterPresence.latitude, initial.latitude, 'latitude changed after presence.');
  exactEqual(afterPresence.longitude, initial.longitude, 'longitude changed after presence.');
  exactEqual(afterPresence.accuracy, initial.accuracy, 'accuracy changed after presence.');
  exactEqual(afterPresence.speed, initial.speed, 'speed changed after presence.');
  exactEqual(afterPresence.heading, initial.heading, 'heading changed after presence.');
  exactEqual(afterPresence.connectionStatus, 'online', 'Driver is not online after presence.');
  console.log('PASS presence 204');
  console.log('PASS last_seen_at changed');
  console.log('PASS captured_at unchanged');
  console.log('PASS coordinates unchanged');
  console.log('PASS accuracy/speed/heading unchanged');
  console.log('PASS online based on presence');

  await expectStatus('/api/driver/presence', 400, presence(driverToken, {
    last_seen_at: '2030-01-01T00:00:00Z'
  }));
  console.log('PASS arbitrary body 400');

  await expectStatus('/api/driver/presence', 401, {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: '{}'
  });
  console.log('PASS no bearer 401');

  await expectStatus('/api/driver/presence', 401, presence('invalid-uat-session'));
  console.log('PASS invalid bearer 401');

  await expectStatus('/api/driver/presence', 403, presence(adminToken));
  console.log('PASS admin 403');

  await expectStatus('/api/driver/presence', 403, presence(supervisorToken));
  console.log('PASS supervisor 403');

  const secondCapturedAt = await sendLocation(driverToken, -25.2868, -57.6471);
  const second = await fleetSnapshot(adminToken);
  timestampAfter(second.capturedAt, initial.capturedAt, 'captured_at did not advance after the second GPS update.');
  timestampAfter(second.lastSeenAt, afterPresence.lastSeenAt, 'last_seen_at did not advance after the second GPS update.');
  exactEqual(second.capturedAt, secondCapturedAt, 'Second captured_at does not match the GPS timestamp.');
  console.log('PASS second GPS');
  console.log('PRESENCE UAT: PASS');
}

try {
  await run();
} catch (error) {
  const message = error instanceof UatFailure ? error.message : 'Unexpected UAT failure.';
  console.error(`PRESENCE UAT: FAIL — ${message}`);
  process.exitCode = 1;
}
