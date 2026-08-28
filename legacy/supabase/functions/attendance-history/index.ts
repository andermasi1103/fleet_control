import { protectedEndpoint } from '../_shared/http.ts';
import { error, json } from '../_shared/responses.ts';
import { canReadCompany, isSuperAdmin } from '../_shared/session.ts';
import { isUuid, limitOffset, relatedName } from '../_shared/validation.ts';

type AttendanceHistoryRow = Record<string, unknown> & {
  usuarios: unknown;
  empresas: unknown;
  locales: unknown;
};

Deno.serve((request) => protectedEndpoint(request, 'GET', async ({ admin, session, url }) => {
  const page = limitOffset(url.searchParams); if (!page) return error('invalid_request', 400);
  const userId = url.searchParams.get('usuario_id'); const localId = url.searchParams.get('local_id');
  const type = url.searchParams.get('tipo'); const desde = url.searchParams.get('desde'); const hasta = url.searchParams.get('hasta');
  if ((userId && !isUuid(userId)) || (localId && !isUuid(localId)) || (type && type !== 'entrada' && type !== 'salida') ||
    (desde && Number.isNaN(Date.parse(desde))) || (hasta && Number.isNaN(Date.parse(hasta)))) return error('invalid_request', 400);
  let scopedUser = session.userId;
  if (userId) {
    if (isSuperAdmin(session)) scopedUser = userId;
    else {
      const { data: target } = await admin.from('usuarios').select('empresa_id').eq('id', userId).maybeSingle();
      if (!target || !canReadCompany(session, target.empresa_id) || session.role === 'chofer' || session.role === 'user') return error('forbidden', 403);
      scopedUser = userId;
    }
  }
  let query = admin.from('asistencias').select('id, usuario_id, empresa_id, local_id, tipo, fecha_hora, latitud, longitud, dentro_geocerca, usuarios(nombre), empresas(nombre), locales(nombre)', { count: 'exact' })
    .eq('usuario_id', scopedUser).order('fecha_hora', { ascending: false }).range(page.offset, page.offset + page.limit - 1);
  if (localId) query = query.eq('local_id', localId); if (type) query = query.eq('tipo', type); if (desde) query = query.gte('fecha_hora', desde); if (hasta) query = query.lte('fecha_hora', hasta);
  const { data, count, error: queryError } = await query;
  if (queryError) return error('internal_error', 500);
  return json({ attendances: (data ?? []).map((item: AttendanceHistoryRow) => ({ ...item, usuario_nombre: relatedName(item.usuarios), empresa_nombre: relatedName(item.empresas), local_nombre: relatedName(item.locales), usuarios: undefined, empresas: undefined, locales: undefined })), limit: page.limit, offset: page.offset, total: count ?? 0 });
}));
