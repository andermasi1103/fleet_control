import { createClient, type SupabaseClient } from '@supabase/supabase-js';

function secretKey(): string | null {
  const keys = Deno.env.get('SUPABASE_SECRET_KEYS');
  if (keys) {
    try {
      const parsed: unknown = JSON.parse(keys);
      if (typeof parsed === 'object' && parsed !== null && 'default' in parsed &&
        typeof parsed.default === 'string' && parsed.default.length > 0) return parsed.default;
    } catch { /* Fall back to the legacy variable. */ }
  }
  const legacy = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  return legacy && legacy.length > 0 ? legacy : null;
}

export function createAdminClient(): SupabaseClient | null {
  const url = Deno.env.get('SUPABASE_URL');
  const key = secretKey();
  return url && key ? createClient(url, key, { auth: { autoRefreshToken: false, persistSession: false } }) : null;
}
