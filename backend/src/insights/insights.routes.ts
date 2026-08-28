import type { FastifyInstance, FastifyReply } from 'fastify';
import type { QueryResultRow } from 'pg';

import type { Database, FleetSession } from '../auth/auth.types.js';
import { fleetLocationsQuerySchema, reportTypeParamsSchema, reportsQuerySchema, type ReportType } from './insights.schemas.js';

type Row = QueryResultRow & Record<string, unknown>;
const maxRows = 10_000;

function noStore(reply: FastifyReply) { return reply.header('Cache-Control', 'no-store'); }
function fail(reply: FastifyReply, status: number, error: string, message: string) { return noStore(reply).code(status).send({ error, message }); }
function invalid(reply: FastifyReply) { return fail(reply, 400, 'invalid_request', 'Solicitud inválida.'); }
function forbidden(reply: FastifyReply) { return fail(reply, 403, 'forbidden', 'No tienes permiso para realizar esta acción.'); }
function sessionOr401(session: FleetSession | null, reply: FastifyReply): session is FleetSession { if (session) return true; fail(reply, 401, 'invalid_session', 'Sesión inválida o expirada.'); return false; }
function isSuper(session: FleetSession) { return session.roleCode === 'super_admin'; }
function isReportRole(session: FleetSession) { return isSuper(session) || session.roleCode === 'admin' || session.roleCode === 'supervisor'; }
function addEquals(filters: string[], values: unknown[], column: string, value: string | undefined, cast = 'uuid') { if (value) { values.push(value); filters.push(`${column} = $${values.length}::${cast}`); } }
function dates(filters: string[], values: unknown[], column: string, from: string | undefined, until: string | undefined) { if (from) { values.push(from); filters.push(`${column} >= $${values.length}::timestamptz`); } if (until) { values.push(until); filters.push(`${column} <= $${values.length}::timestamptz`); } }
function reportReply(reply: FastifyReply, type: ReportType, rows: Row[]) { if (rows.length > maxRows) return fail(reply, 422, 'report_too_large', 'El reporte supera el límite permitido.'); return noStore(reply).send({ type, rows, count: rows.length }); }

async function reportScope(database: Database, session: FleetSession, requestedCompany: string | undefined, requestedDriver: string | undefined, type: ReportType): Promise<{ companyId?: string; driverIds?: string[]; forbidden?: boolean }> {
  if (!isReportRole(session)) return { forbidden: true };
  if (session.roleCode === 'supervisor' && type === 'locations') return { forbidden: true };
  const companyId = isSuper(session) ? requestedCompany : session.companyId ?? undefined;
  if (!isSuper(session) && !companyId) return { forbidden: true };
  if (session.roleCode !== 'supervisor') return { companyId, driverIds: requestedDriver ? [requestedDriver] : undefined };
  const assigned = await database.query<Row>('SELECT chofer_usuario_id FROM public.supervisor_choferes WHERE supervisor_usuario_id=$1::uuid', [session.userId]);
  const driverIds = assigned.rows.map((row) => String(row.chofer_usuario_id));
  if (requestedDriver && !driverIds.includes(requestedDriver)) return { forbidden: true };
  return { companyId, driverIds: requestedDriver ? [requestedDriver] : driverIds };
}

export function registerInsightsRoutes(app: FastifyInstance, database: Database): void {
  app.get('/api/fleet/locations', { preHandler: app.requireFleetSession }, async (request, reply) => {
    const query = fleetLocationsQuerySchema.safeParse(request.query); if (!query.success) return invalid(reply); if (!sessionOr401(request.fleetSession, reply)) return;
    const session = request.fleetSession;
    if (!isReportRole(session)) return forbidden(reply);
    if (!isSuper(session) && query.data.empresa_id && query.data.empresa_id !== session.companyId) return forbidden(reply);
    const companyId = isSuper(session) ? query.data.empresa_id : session.companyId;
    if (!isSuper(session) && !companyId) return forbidden(reply);
    const result = await database.query<Row>(
      `SELECT u.id AS driver_user_id,u.nombre AS driver_name,u.usuario AS driver_username,u.empresa_id AS company_id,
              m.id AS management_id,m.estado AS management_status,
              COALESCE(mv.id,hv.id) AS vehicle_id,COALESCE(mv.patente,hv.patente) AS vehicle_plate,COALESCE(mv.tipo_vehiculo,hv.tipo_vehiculo) AS vehicle_type,
              cl.latitud AS latitude,cl.longitud AS longitude,cl.precision_metros AS accuracy,cl.velocidad_mps AS speed,cl.rumbo_grados AS heading,cl.captured_at,
              CASE WHEN cl.captured_at IS NULL THEN 'offline'
                   WHEN now() - cl.captured_at <= interval '2 minutes' THEN 'online'
                   WHEN now() - cl.captured_at <= interval '10 minutes' THEN 'stale'
                   ELSE 'offline' END AS connection_status,
              COALESCE(m.estado,'disponible') AS operational_status
       FROM public.usuarios u
       JOIN public.roles r ON r.id=u.rol_id AND r.codigo='chofer'
       LEFT JOIN public.chofer_ubicaciones cl ON cl.chofer_usuario_id=u.id
       LEFT JOIN LATERAL (
         SELECT g.id,g.estado,g.vehiculo_id FROM public.gestiones g
         WHERE g.chofer_usuario_id=u.id AND g.estado=ANY(ARRAY['asignado','aceptado','en_camino','en_gestion']::text[])
         ORDER BY CASE WHEN g.estado=ANY(ARRAY['aceptado','en_camino','en_gestion']::text[]) THEN 0 ELSE 1 END, g.queue_position NULLS LAST, g.created_at DESC LIMIT 1
       ) m ON true
       LEFT JOIN public.vehiculos mv ON mv.id=m.vehiculo_id
       LEFT JOIN public.usuario_vehiculos uv ON uv.usuario_id=u.id
       LEFT JOIN public.vehiculos hv ON hv.id=uv.vehiculo_id AND hv.activo=true
       WHERE u.activo=true ${companyId ? 'AND u.empresa_id=$1::uuid' : ''}
       ORDER BY u.nombre`,
      companyId ? [companyId] : []
    );
    return noStore(reply).send({ drivers: result.rows });
  });

  app.get('/api/reports/:type', { preHandler: app.requireFleetSession }, async (request, reply) => {
    const params = reportTypeParamsSchema.safeParse(request.params), query = reportsQuerySchema.safeParse(request.query);
    if (!params.success || !query.success) return invalid(reply); if (!sessionOr401(request.fleetSession, reply)) return;
    const type = params.data.type, data = query.data, scope = await reportScope(database, request.fleetSession, data.empresa_id, data.driver_user_id, type);
    if (scope.forbidden) return forbidden(reply);
    if (request.fleetSession.roleCode === 'supervisor' && scope.driverIds?.length === 0) return reportReply(reply, type, []);
    const filters: string[] = []; const values: unknown[] = [];
    const driverFilter = (column: string) => { if (scope.driverIds) { values.push(scope.driverIds); filters.push(`${column} = ANY($${values.length}::uuid[])`); } };
    if (type === 'orders') {
      addEquals(filters, values, 'p.empresa_id', scope.companyId); addEquals(filters, values, 'p.local_id', data.local_id); addEquals(filters, values, 'p.estado', data.estado, 'text'); addEquals(filters, values, 'p.prioridad', data.prioridad, 'text'); dates(filters, values, 'p.created_at', data.desde, data.hasta);
      if (scope.driverIds) { values.push(scope.driverIds); filters.push(`g.chofer_usuario_id = ANY($${values.length}::uuid[])`); }
      const where = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
      const rows = await database.query<Row>(`SELECT p.created_at AS "Fecha",l.nombre AS "Local",pd.nombre AS "Descripción",p.prioridad AS "Prioridad",p.estado AS "Estado",u.nombre AS "Chofer",v.patente AS "Vehículo",p.numero_contacto AS "Contacto",g.completado_at AS "Fecha completado" FROM public.pedidos p LEFT JOIN public.gestiones g ON g.pedido_id=p.id LEFT JOIN public.locales l ON l.id=p.local_id LEFT JOIN public.pedido_descripciones pd ON pd.id=p.descripcion_tipo_id LEFT JOIN public.usuarios u ON u.id=g.chofer_usuario_id LEFT JOIN public.vehiculos v ON v.id=g.vehiculo_id ${where} ORDER BY p.created_at DESC LIMIT ${maxRows + 1}`, values); return reportReply(reply, type, rows.rows);
    }
    if (type === 'managements') {
      addEquals(filters, values, 'g.empresa_id', scope.companyId); addEquals(filters, values, 'g.local_id', data.local_id); addEquals(filters, values, 'g.estado', data.estado, 'text'); driverFilter('g.chofer_usuario_id'); dates(filters, values, 'g.created_at', data.desde, data.hasta);
      const where = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
      const rows = await database.query<Row>(`SELECT g.created_at AS "Fecha",l.nombre AS "Local",u.nombre AS "Chofer",v.patente AS "Vehículo",g.estado AS "Estado",g.aceptado_at AS "Aceptado",g.en_camino_at AS "En camino",g.en_gestion_at AS "Inicio gestión",g.completado_at AS "Completado" FROM public.gestiones g JOIN public.locales l ON l.id=g.local_id JOIN public.usuarios u ON u.id=g.chofer_usuario_id JOIN public.vehiculos v ON v.id=g.vehiculo_id ${where} ORDER BY g.created_at DESC LIMIT ${maxRows + 1}`, values); return reportReply(reply, type, rows.rows);
    }
    if (type === 'attendance') {
      addEquals(filters, values, 'a.empresa_id', scope.companyId); addEquals(filters, values, 'a.local_id', data.local_id); driverFilter('a.usuario_id'); dates(filters, values, 'a.fecha_hora', data.desde, data.hasta);
      const where = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
      const rows = await database.query<Row>(`SELECT a.fecha_hora AS "Fecha y hora",u.usuario AS "Usuario",u.nombre AS "Nombre",l.nombre AS "Local",a.tipo AS "Tipo de marca",CASE WHEN a.dentro_geocerca THEN 'Dentro de geocerca' ELSE 'Fuera de geocerca' END AS "Resultado" FROM public.asistencias a LEFT JOIN public.usuarios u ON u.id=a.usuario_id LEFT JOIN public.locales l ON l.id=a.local_id ${where} ORDER BY a.fecha_hora DESC LIMIT ${maxRows + 1}`, values); return reportReply(reply, type, rows.rows);
    }
    if (type === 'drivers') {
      addEquals(filters, values, 'u.empresa_id', scope.companyId); driverFilter('u.id');
      const where = filters.length ? `AND ${filters.join(' AND ')}` : '';
      const rows = await database.query<Row>(`SELECT u.usuario AS "Usuario",u.nombre AS "Nombre",CASE WHEN u.activo THEN 'Sí' ELSE 'No' END AS "Activo",v.patente AS "Vehículo habitual",v.tipo_vehiculo AS "Tipo de vehículo" FROM public.usuarios u JOIN public.roles r ON r.id=u.rol_id AND r.codigo='chofer' LEFT JOIN public.usuario_vehiculos uv ON uv.usuario_id=u.id LEFT JOIN public.vehiculos v ON v.id=uv.vehiculo_id WHERE true ${where} ORDER BY u.nombre LIMIT ${maxRows + 1}`, values); return reportReply(reply, type, rows.rows);
    }
    if (type === 'vehicles') {
      addEquals(filters, values, 'g.empresa_id', scope.companyId); driverFilter('g.chofer_usuario_id'); dates(filters, values, 'g.created_at', data.desde, data.hasta);
      const where = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
      const rows = await database.query<Row>(`SELECT v.patente AS "Patente",v.tipo_vehiculo AS "Tipo",v.marca AS "Marca",v.modelo AS "Modelo",v.anio AS "Año",CASE WHEN v.activo THEN 'Sí' ELSE 'No' END AS "Activo",max(u.nombre) AS "Chofer",count(g.id)::int AS "Gestiones realizadas" FROM public.gestiones g JOIN public.vehiculos v ON v.id=g.vehiculo_id LEFT JOIN public.usuarios u ON u.id=g.chofer_usuario_id ${where} GROUP BY v.id,v.patente,v.tipo_vehiculo,v.marca,v.modelo,v.anio,v.activo ORDER BY v.patente LIMIT ${maxRows + 1}`, values); return reportReply(reply, type, rows.rows);
    }
    addEquals(filters, values, 'l.empresa_id', scope.companyId); addEquals(filters, values, 'l.id', data.local_id);
    const where = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
    const rows = await database.query<Row>(`SELECT l.codigo AS "Código",l.nombre AS "Nombre",l.direccion AS "Dirección",l.radio_metros AS "Radio geocerca",CASE WHEN l.activo THEN 'Sí' ELSE 'No' END AS "Activo" FROM public.locales l ${where} ORDER BY l.nombre LIMIT ${maxRows + 1}`, values); return reportReply(reply, type, rows.rows);
  });
}
