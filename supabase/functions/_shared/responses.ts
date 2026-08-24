import { corsHeaders } from './cors.ts';

export function json(body: Record<string, unknown>, status = 200): Response {
  return Response.json(body, { status, headers: corsHeaders });
}

export function error(code: string, status: number): Response {
  return json({ error: code }, status);
}
