import { protectedEndpoint } from '../_shared/http.ts';
import { error, json } from '../_shared/responses.ts';
import { canReadCompany, isSuperAdmin } from '../_shared/session.ts';
import { isUuid, relatedName } from '../_shared/validation.ts';

type LocationListRow = Record<string, unknown> & { empresas: unknown };

Deno.serve((request) => protectedEndpoint(request, 'GET', async ({ admin, session, url }) => {
  const requestedCompany = url.searchParams.get('empresa_id');
  if (requestedCompany && !isUuid(requestedCompany)) return error('invalid_request', 400);
  if (requestedCompany && !canReadCompany(session, requestedCompany)) return error('forbidden', 403);
  if (!isSuperAdmin(session) && !session.empresaId) return error('forbidden', 403);
  let query = admin.from('locales').select('id, empresa_id, nombre, direccion, latitud, longitud, radio_metros, activo, created_at, updated_at, empresas(nombre)').order('nombre');
  if (requestedCompany) query = query.eq('empresa_id', requestedCompany);
  if (!isSuperAdmin(session)) query = query.eq('empresa_id', session.empresaId);
  const { data, error: queryError } = await query;
  if (queryError) return error('internal_error', 500);
  return json({ locations: (data ?? []).map((location: LocationListRow) => ({ ...location, empresa_nombre: relatedName(location.empresas), empresas: undefined })) });
}));
