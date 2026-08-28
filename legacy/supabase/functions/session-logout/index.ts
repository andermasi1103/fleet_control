import { protectedEndpoint } from '../_shared/http.ts';
import { error, json } from '../_shared/responses.ts';

Deno.serve((request) => protectedEndpoint(request, 'POST', async ({ admin, session }) => {
  const { error: updateError } = await admin.from('sesiones').update({ revoked_at: new Date().toISOString() }).eq('id', session.sessionId).is('revoked_at', null);
  return updateError ? error('internal_error', 500) : json({ success: true });
}));
