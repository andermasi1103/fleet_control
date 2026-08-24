import { corsHeaders as supabaseCorsHeaders } from '@supabase/supabase-js/cors';

export const corsHeaders = {
  ...supabaseCorsHeaders,
  'Cache-Control': 'no-store',
};

export function preflightResponse(): Response {
  return new Response('ok', { status: 200, headers: corsHeaders });
}
