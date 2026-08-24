import { protectedEndpoint } from '../_shared/http.ts';
import { error, json } from '../_shared/responses.ts';
import { isSuperAdmin } from '../_shared/session.ts';

Deno.serve((request) =>
  protectedEndpoint(request, 'GET', async ({ admin, session }) => {
    if (!isSuperAdmin(session)) return error('forbidden', 403);

    const { data, error: queryError } = await admin
      .from('roles')
      .select('id, codigo')
      .order('codigo');

    return queryError
      ? error('internal_error', 500)
      : json({ roles: data ?? [] });
  }),
);
