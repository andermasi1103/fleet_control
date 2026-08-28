import { createClient } from '@supabase/supabase-js';
import { corsHeaders } from '@supabase/supabase-js/cors';

function jsonResponse(
  body: Record<string, unknown>,
  status = 200,
): Response {
  return Response.json(body, {
    status,
    headers: {
      ...corsHeaders,
      'Cache-Control': 'no-store',
    },
  });
}

function invalidCredentials(): Response {
  return jsonResponse(
    { error: 'invalid_credentials' },
    401,
  );
}

function getSecretKey(): string | null {
  const rawSecretKeys = Deno.env.get('SUPABASE_SECRET_KEYS');

  if (rawSecretKeys) {
    try {
      const keys = JSON.parse(rawSecretKeys);

      if (
        typeof keys === 'object' &&
        keys !== null &&
        typeof keys.default === 'string' &&
        keys.default.length > 0
      ) {
        return keys.default;
      }
    } catch {
      console.error(
        'auth-login: SUPABASE_SECRET_KEYS no contiene JSON válido.',
      );
    }
  }

  const legacyServiceRole =
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');

  if (legacyServiceRole && legacyServiceRole.length > 0) {
    return legacyServiceRole;
  }

  return null;
}

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((byte) => byte.toString(16).padStart(2, '0'))
    .join('');
}

function generateSessionToken(): string {
  const bytes = crypto.getRandomValues(new Uint8Array(32));
  return bytesToHex(bytes);
}

async function sha256(value: string): Promise<string> {
  const data = new TextEncoder().encode(value);

  const digest = await crypto.subtle.digest(
    'SHA-256',
    data,
  );

  return bytesToHex(new Uint8Array(digest));
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') {
    return new Response('ok', {
      status: 200,
      headers: corsHeaders,
    });
  }

  if (request.method !== 'POST') {
    return jsonResponse(
      { error: 'method_not_allowed' },
      405,
    );
  }

  try {
    let payload: unknown;

    try {
      payload = await request.json();
    } catch {
      return invalidCredentials();
    }

    if (
      typeof payload !== 'object' ||
      payload === null ||
      Array.isArray(payload)
    ) {
      return invalidCredentials();
    }

    const body = payload as Record<string, unknown>;

    const usuario =
      typeof body.usuario === 'string'
        ? body.usuario.trim()
        : '';

    const password =
      typeof body.password === 'string'
        ? body.password
        : '';

    if (
      usuario.length === 0 ||
      usuario.length > 100 ||
      password.length === 0 ||
      password.length > 1024
    ) {
      return invalidCredentials();
    }

    const supabaseUrl =
      Deno.env.get('SUPABASE_URL');

    const secretKey =
      getSecretKey();

    if (!supabaseUrl || !secretKey) {
      console.error(
        'auth-login: faltan variables de entorno.',
      );

      return jsonResponse(
        { error: 'configuration_error' },
        500,
      );
    }

    const admin = createClient(
      supabaseUrl,
      secretKey,
      {
        auth: {
          autoRefreshToken: false,
          persistSession: false,
          detectSessionInUrl: false,
        },
      },
    );

    // 1. Validar usuario + contraseña.
    const {
      data,
      error,
    } = await admin.rpc(
      'login_usuario',
      {
        p_usuario: usuario,
        p_password: password,
      },
    );

    if (error) {
      console.error(
        'auth-login: error ejecutando login_usuario:',
        error.message,
      );

      return jsonResponse(
        { error: 'authentication_error' },
        500,
      );
    }

    if (
      !Array.isArray(data) ||
      data.length !== 1
    ) {
      return invalidCredentials();
    }

    const profile = data[0];

    if (
      typeof profile.id !== 'string' ||
      typeof profile.usuario !== 'string' ||
      typeof profile.nombre !== 'string' ||
      typeof profile.rol_id !== 'string' ||
      typeof profile.rol_codigo !== 'string' ||
      profile.activo !== true
    ) {
      console.error(
        'auth-login: perfil inválido.',
      );

      return jsonResponse(
        { error: 'authentication_error' },
        500,
      );
    }

    // 2. Generar token de sesión aleatorio.
    const sessionToken =
      generateSessionToken();

    const tokenHash =
      await sha256(sessionToken);

    // 3. Sesión válida por 24 horas.
    const expiresAt =
      new Date(
        Date.now() + 24 * 60 * 60 * 1000,
      ).toISOString();

    // 4. Guardar SOLO el hash del token.
    const {
      error: sessionError,
    } = await admin
      .from('sesiones')
      .insert({
        usuario_id: profile.id,
        token_hash: tokenHash,
        expires_at: expiresAt,
      });

    if (sessionError) {
      console.error(
        'auth-login: error creando sesión:',
        sessionError.message,
      );

      return jsonResponse(
        { error: 'session_creation_error' },
        500,
      );
    }

    // 5. Devolver token real solo al cliente.
    return jsonResponse({
      session_token: sessionToken,
      expires_at: expiresAt,
      user: {
        id: profile.id,
        usuario: profile.usuario,
        nombre: profile.nombre,
        empresa_id: profile.empresa_id ?? null,
        rol_id: profile.rol_id,
        rol: profile.rol_codigo,
        activo: profile.activo,
      },
    });
  } catch (error) {
    console.error(
      'auth-login: error inesperado:',
      error,
    );

    return jsonResponse(
      { error: 'authentication_error' },
      500,
    );
  }
});