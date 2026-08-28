import { protectedEndpoint } from '../_shared/http.ts';
import { error, json } from '../_shared/responses.ts';
import { canReadCompany, isSuperAdmin } from '../_shared/session.ts';
import { isUuid, relatedName } from '../_shared/validation.ts';

type VehicleListRow = Record<string, unknown> & { empresas: unknown };

Deno.serve((request) => protectedEndpoint(request, 'GET', async ({ admin, session, url }) => {
  if (!isSuperAdmin(session) && session.role !== 'admin' && session.role !== 'supervisor') return error('forbidden', 403);
  const requestedCompany = url.searchParams.get('empresa_id'); if (requestedCompany && !isUuid(requestedCompany)) return error('invalid_request', 400);
  let query = admin.from('vehiculos').select('id, empresa_id, patente, marca, modelo, anio, descripcion, tipo_vehiculo, activo, created_at, updated_at, empresas(nombre)').order('patente');
  if (isSuperAdmin(session)) {
    if (requestedCompany) query = query.eq('empresa_id', requestedCompany);
  } else {
    const empresaId = requestedCompany ?? session.empresaId;
    if (!empresaId || !canReadCompany(session, empresaId)) return error('forbidden', 403);
    query = query.eq('empresa_id', empresaId);
  }
  const { data, error: queryError } = await query; if (queryError) return error('internal_error', 500);
  return json({ vehicles: (data ?? []).map((vehicle: VehicleListRow) => ({ ...vehicle, empresa_nombre: relatedName(vehicle.empresas), empresas: undefined })) });
}));
