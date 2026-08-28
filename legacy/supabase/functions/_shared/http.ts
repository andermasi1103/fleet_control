import type { SupabaseClient } from '@supabase/supabase-js';
import { preflightResponse } from './cors.ts';
import { error } from './responses.ts';
import { validateFleetSession, type FleetSession } from './session.ts';
import { createAdminClient } from './supabase_admin.ts';

export type EndpointContext = { admin: SupabaseClient; session: FleetSession; url: URL };

export async function protectedEndpoint(
  request: Request,
  method: string,
  handler: (context: EndpointContext) => Promise<Response>,
): Promise<Response> {
  if (request.method === 'OPTIONS') return preflightResponse();
  if (request.method !== method) return error('method_not_allowed', 405);
  const admin = createAdminClient();
  if (!admin) return error('internal_error', 500);
  try {
    const session = await validateFleetSession(request, admin);
    return session ? await handler({ admin, session, url: new URL(request.url) }) : error('unauthorized', 401);
  } catch {
    return error('internal_error', 500);
  }
}

export async function body(request: Request): Promise<Record<string, unknown> | null> {
  try {
    const value: unknown = await request.json();
    return typeof value === 'object' && value !== null && !Array.isArray(value) ? value as Record<string, unknown> : null;
  } catch { return null; }
}
