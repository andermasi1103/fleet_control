import { body, protectedEndpoint } from '../_shared/http.ts';
import { error, json } from '../_shared/responses.ts';
import { canManageUserLocations } from '../_shared/session.ts';
import { isUuid } from '../_shared/validation.ts';

type DatabaseError = { code?: unknown };

function logFailure(stage: string, failure: DatabaseError): void {
  console.error(JSON.stringify({
    event: 'user-locations-update-error',
    stage,
    errorCode: typeof failure.code === 'string' ? failure.code : null,
  }));
}

Deno.serve((request) =>
  protectedEndpoint(request, 'PUT', async ({ admin, session }) => {
    const payload = await body(request);
    if (!payload || !isUuid(payload.user_id) || !Array.isArray(payload.location_ids)) {
      return error('invalid_request', 400);
    }
    if (!payload.location_ids.every(isUuid)) return error('invalid_request', 400);
    const locationIds = [...new Set(payload.location_ids)];

    const { data: user, error: userError } = await admin
      .from('usuarios')
      .select('id, empresa_id')
      .eq('id', payload.user_id)
      .maybeSingle();
    if (userError) return error('internal_error', 500);
    if (!user) return error('not_found', 404);
    if (!canManageUserLocations(session, user.empresa_id as string | null)) {
      return error('forbidden', 403);
    }

    const { error: updateError } = await admin.rpc('fleet_control_set_user_locations', {
      p_user_id: payload.user_id,
      p_location_ids: locationIds,
    });
    if (!updateError) return json({ success: true });

    logFailure('set_user_locations', updateError);
    if (updateError.code === 'P0001' || updateError.code === '23503') {
      return error('invalid_reference', 400);
    }
    if (updateError.code === '22P02') return error('invalid_request', 400);
    return error('internal_error', 500);
  }),
);
