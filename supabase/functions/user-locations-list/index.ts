import { protectedEndpoint } from '../_shared/http.ts';
import { error, json } from '../_shared/responses.ts';
import { canManageUserLocations } from '../_shared/session.ts';
import { isUuid, relatedName } from '../_shared/validation.ts';

type UserRow = Record<string, unknown> & { empresas: unknown };
type LocationRow = Record<string, unknown> & { empresas: unknown };

Deno.serve((request) =>
  protectedEndpoint(request, 'GET', async ({ admin, session, url }) => {
    const userId = url.searchParams.get('user_id');
    if (!isUuid(userId)) return error('invalid_request', 400);

    const { data: user, error: userError } = await admin
      .from('usuarios')
      .select('id, usuario, nombre, empresa_id, empresas(nombre)')
      .eq('id', userId)
      .maybeSingle<UserRow>();
    if (userError) return error('internal_error', 500);
    if (!user) return error('not_found', 404);
    if (!canManageUserLocations(session, user.empresa_id as string | null)) {
      return error('forbidden', 403);
    }

    const companyId = typeof user.empresa_id === 'string' ? user.empresa_id : null;
    if (companyId === null) {
      return json({
        user: { ...user, empresa_nombre: relatedName(user.empresas), empresas: undefined },
        locations: [],
      });
    }

    const { data: assignments, error: assignmentError } = await admin
      .from('usuario_locales')
      .select('local_id')
      .eq('usuario_id', userId);
    if (assignmentError) return error('internal_error', 500);
    const assignmentRows = (assignments ?? []) as Array<{ local_id: unknown }>;
    const assignedIds = new Set(
      assignmentRows
        .map((assignment) => assignment.local_id)
        .filter((id): id is string => typeof id === 'string'),
    );

    const { data: locations, error: locationError } = await admin
      .from('locales')
      .select('id, empresa_id, nombre, direccion, activo, empresas(nombre)')
      .eq('empresa_id', companyId)
      .order('nombre');
    if (locationError) return error('internal_error', 500);

    return json({
      user: { ...user, empresa_nombre: relatedName(user.empresas), empresas: undefined },
      locations: (locations ?? []).map((location: LocationRow) => ({
        ...location,
        empresa_nombre: relatedName(location.empresas),
        empresas: undefined,
        assigned: assignedIds.has(location.id as string),
      })),
    });
  }),
);
