import type { FastifyInstance, FastifyReply } from 'fastify';
import type { QueryResultRow } from 'pg';

import type { Database, FleetSession } from '../auth/auth.types.js';
import { notifyNewOrder } from '../notifications/fcm.service.js';
import { sensitiveRateLimit } from '../plugins/rate-limit.js';
import {
  attendanceCreateSchema, attendanceHistorySchema, cancelOrderSchema, descriptionCreateSchema, descriptionListSchema, driverListSchema,
  descriptionPatchSchema, idParamsSchema, managementCreateSchema, managementListSchema, managementStatusSchema,
  orderCreateSchema, orderIdParamsSchema, orderListSchema
} from './operations.schemas.js';

type Row = QueryResultRow & Record<string, unknown>;
type DbError = { code?: string; message?: string };
const operationalStates = ['aceptado', 'en_camino', 'en_gestion'];
const activeStates = ['asignado', ...operationalStates];

function noStore(reply: FastifyReply) { return reply.header('Cache-Control', 'no-store'); }
function fail(reply: FastifyReply, status: number, error: string, message: string) { return noStore(reply).code(status).send({ error, message }); }
function invalid(reply: FastifyReply) { return fail(reply, 400, 'invalid_request', 'Solicitud inválida.'); }
function forbidden(reply: FastifyReply) { return fail(reply, 403, 'forbidden', 'No tienes permiso para realizar esta acción.'); }
function sessionOr401(session: FleetSession | null, reply: FastifyReply): session is FleetSession { if (session) return true; fail(reply, 401, 'invalid_session', 'Sesión inválida o expirada.'); return false; }
function isSuper(s: FleetSession) { return s.roleCode === 'super_admin'; }
function isManager(s: FleetSession) { return isSuper(s) || s.roleCode === 'admin' || s.roleCode === 'supervisor'; }
function sameCompany(s: FleetSession, companyId: unknown) { return isSuper(s) || (typeof companyId === 'string' && s.companyId === companyId); }
function rpcError(error: unknown): [string, number] {
  const message = (error as DbError).message;
  if (['driver_busy', 'vehicle_busy', 'active_management', 'invalid_transition', 'order_already_taken', 'driver_vehicle_required', 'active_management_exists', 'queue_position_conflict'].includes(message ?? '')) return [message!, 409];
  if (message === 'not_found') return [message, 404];
  if (message === 'forbidden') return [message, 403];
  if (message === 'invalid_reference') return [message, 400];
  return ['internal_error', 500];
}
function dbFailure(reply: FastifyReply, error: unknown) { const [code, status] = rpcError(error); return fail(reply, status, code, code === 'internal_error' ? 'No fue posible completar la operación.' : code); }
function haversineMeters(aLat: number, aLng: number, bLat: number, bLng: number) {
  const r = 6371000, rad = Math.PI / 180, dLat = (bLat - aLat) * rad, dLng = (bLng - aLng) * rad;
  const x = Math.sin(dLat / 2) ** 2 + Math.cos(aLat * rad) * Math.cos(bLat * rad) * Math.sin(dLng / 2) ** 2;
  return 2 * r * Math.atan2(Math.sqrt(x), Math.sqrt(1 - x));
}
async function permittedLocationIds(database: Database, userId: string): Promise<string[]> {
  return (await database.query<Row>('SELECT local_id FROM public.usuario_locales WHERE usuario_id = $1::uuid', [userId])).rows.map((row) => String(row.local_id));
}
async function canUseLocation(database: Database, session: FleetSession, location: Row) {
  if (isSuper(session) || (isManager(session) && session.companyId === location.empresa_id)) return true;
  if (session.roleCode !== 'user' && session.roleCode !== 'local') return false;
  const result = await database.query<Row>('SELECT 1 FROM public.usuario_locales WHERE usuario_id=$1::uuid AND local_id=$2::uuid', [session.userId, location.id]);
  return result.rowCount === 1;
}
const managementSelect = `SELECT g.id,g.pedido_id,g.empresa_id,g.local_id,g.chofer_usuario_id,g.vehiculo_id,g.estado,g.queue_position,g.aceptado_at,g.en_camino_at,g.en_gestion_at,g.completado_at,g.created_at,g.updated_at,
  p.estado AS order_status,p.destino,p.destino_latitud,p.destino_longitud,p.factura_solicitud,p.numero_contacto,p.prioridad,p.observaciones AS observaciones_pedido,
  e.nombre AS empresa_nombre,l.nombre AS local_nombre,u.nombre AS driver_name,u.usuario AS driver_username,v.patente AS vehicle_plate,v.marca AS vehicle_brand,v.modelo AS vehicle_model,pd.nombre AS description
  FROM public.gestiones g JOIN public.pedidos p ON p.id=g.pedido_id JOIN public.empresas e ON e.id=g.empresa_id JOIN public.locales l ON l.id=g.local_id JOIN public.usuarios u ON u.id=g.chofer_usuario_id JOIN public.vehiculos v ON v.id=g.vehiculo_id LEFT JOIN public.pedido_descripciones pd ON pd.id=p.descripcion_tipo_id`;
function managementJson(row: Row): Row { return { ...row, order_id: row.pedido_id, management_status: row.estado, pedido_id: undefined, estado: undefined }; }
function orderJson(row: Row) { return row; }

export function registerOperationsRoutes(app: FastifyInstance, database: Database): void {
  app.get('/api/attendance/status', { preHandler: app.requireFleetSession }, async (request, reply) => {
    if (!sessionOr401(request.fleetSession, reply)) return;
    const result = await database.query<Row>('SELECT id,local_id,tipo,fecha_hora,dentro_geocerca FROM public.asistencias WHERE usuario_id=$1::uuid ORDER BY fecha_hora DESC LIMIT 1', [request.fleetSession.userId]);
    const last = result.rows[0] ?? null;
    return noStore(reply).send({ next_action: last?.tipo === 'entrada' ? 'salida' : 'entrada', has_open_attendance: last?.tipo === 'entrada', last_attendance: last });
  });
  app.post('/api/attendance', {
    preHandler: app.requireFleetSession,
    config: sensitiveRateLimit
  }, async (request, reply) => {
    const body = attendanceCreateSchema.safeParse(request.body); if (!body.success) return invalid(reply); if (!sessionOr401(request.fleetSession, reply)) return;
    const location = (await database.query<Row>('SELECT id,empresa_id,latitud,longitud,radio_metros,activo FROM public.locales WHERE id=$1::uuid', [body.data.local_id])).rows[0];
    if (!location) return fail(reply, 404, 'not_found', 'Local no encontrado.');
    if (location.activo !== true || !sameCompany(request.fleetSession, location.empresa_id)) return forbidden(reply);
    const distance = haversineMeters(body.data.latitud, body.data.longitud, Number(location.latitud), Number(location.longitud));
    if (distance > Number(location.radio_metros)) return noStore(reply).code(422).send({ error: 'outside_geofence', distancia_metros: Math.round(distance), dentro_geocerca: false });
    const latest = await database.query<Row>('SELECT tipo FROM public.asistencias WHERE usuario_id=$1::uuid ORDER BY fecha_hora DESC LIMIT 1', [request.fleetSession.userId]);
    const type = latest.rows[0]?.tipo === 'entrada' ? 'salida' : 'entrada';
    const inserted = await database.query<Row>('INSERT INTO public.asistencias (usuario_id,empresa_id,local_id,tipo,latitud,longitud,dentro_geocerca) VALUES ($1::uuid,$2::uuid,$3::uuid,$4::text,$5::double precision,$6::double precision,true) RETURNING id,usuario_id,empresa_id,local_id,tipo,fecha_hora,latitud,longitud,dentro_geocerca', [request.fleetSession.userId, location.empresa_id, location.id, type, body.data.latitud, body.data.longitud]);
    return noStore(reply).code(201).send({ attendance: inserted.rows[0], distancia_metros: Math.round(distance), dentro_geocerca: true });
  });
  app.get('/api/attendance', { preHandler: app.requireFleetSession }, async (request, reply) => {
    const query = attendanceHistorySchema.safeParse(request.query); if (!query.success) return invalid(reply); if (!sessionOr401(request.fleetSession, reply)) return;
    const s = request.fleetSession; let userId = s.userId;
    if (query.data.usuario_id) { if (isSuper(s)) userId = query.data.usuario_id; else { const target = (await database.query<Row>('SELECT empresa_id FROM public.usuarios WHERE id=$1::uuid', [query.data.usuario_id])).rows[0]; if (!target || !sameCompany(s, target.empresa_id) || s.roleCode === 'chofer' || s.roleCode === 'user') return forbidden(reply); userId = query.data.usuario_id; } }
    const filters: string[] = ['a.usuario_id=$1::uuid']; const values: unknown[] = [userId];
    for (const [column, value] of [['a.local_id', query.data.local_id], ['a.tipo', query.data.tipo], ['a.fecha_hora >=', query.data.desde], ['a.fecha_hora <=', query.data.hasta]] as const) if (value) { values.push(value); filters.push(`${column} $${values.length}${column === 'a.tipo' ? '::text' : column.includes('fecha_hora') ? '::timestamptz' : '::uuid'}`); }
    const where = filters.join(' AND '), count = await database.query<Row>(`SELECT count(*)::int AS total FROM public.asistencias a WHERE ${where}`, values);
    values.push(query.data.limit, query.data.offset);
    const result = await database.query<Row>(`SELECT a.id,a.usuario_id,a.empresa_id,a.local_id,a.tipo,a.fecha_hora,a.latitud,a.longitud,a.dentro_geocerca,u.nombre AS usuario_nombre,e.nombre AS empresa_nombre,l.nombre AS local_nombre FROM public.asistencias a LEFT JOIN public.usuarios u ON u.id=a.usuario_id LEFT JOIN public.empresas e ON e.id=a.empresa_id LEFT JOIN public.locales l ON l.id=a.local_id WHERE ${where} ORDER BY a.fecha_hora DESC LIMIT $${values.length - 1}::int OFFSET $${values.length}::int`, values);
    return noStore(reply).send({ attendances: result.rows, limit: query.data.limit, offset: query.data.offset, total: Number(count.rows[0]?.total ?? 0) });
  });

  app.get('/api/orders', { preHandler: app.requireFleetSession }, async (request, reply) => {
    const query = orderListSchema.safeParse(request.query); if (!query.success) return invalid(reply); if (!sessionOr401(request.fleetSession, reply)) return; const s = request.fleetSession;
    if (s.roleCode === 'chofer') return forbidden(reply); const filters: string[] = []; const values: unknown[] = [];
    const add = (sql: string, value: unknown, cast: string) => { values.push(value); filters.push(`${sql}=$${values.length}::${cast}`); };
    if (isSuper(s)) { if (query.data.local_id) add('p.local_id', query.data.local_id, 'uuid'); }
    else if (isManager(s)) { if (!s.companyId) return forbidden(reply); add('p.empresa_id', s.companyId, 'uuid'); if (query.data.local_id) add('p.local_id', query.data.local_id, 'uuid'); }
    else { const ids = await permittedLocationIds(database, s.userId); if (!ids.length) return noStore(reply).send({ orders: [], limit: query.data.limit, offset: query.data.offset, total: 0 }); if (query.data.local_id && !ids.includes(query.data.local_id)) return forbidden(reply); values.push(query.data.local_id ? [query.data.local_id] : ids); filters.push(`p.local_id = ANY($${values.length}::uuid[])`); }
    if (query.data.estado) add('p.estado', query.data.estado, 'text'); if (query.data.prioridad) add('p.prioridad', query.data.prioridad, 'text');
    for (const [op, value] of [['>=', query.data.desde], ['<=', query.data.hasta]] as const) if (value) { values.push(value); filters.push(`p.created_at ${op} $${values.length}::timestamptz`); }
    const where = filters.length ? `WHERE ${filters.join(' AND ')}` : '';
    const count = await database.query<Row>(`SELECT count(*)::int AS total FROM public.pedidos p ${where}`, values); values.push(query.data.limit, query.data.offset);
    const result = await database.query<Row>(`SELECT p.*,e.nombre AS empresa_nombre,l.nombre AS local_nombre,u.nombre AS creado_por_nombre,pd.nombre AS descripcion FROM public.pedidos p JOIN public.empresas e ON e.id=p.empresa_id JOIN public.locales l ON l.id=p.local_id LEFT JOIN public.usuarios u ON u.id=p.creado_por_usuario_id LEFT JOIN public.pedido_descripciones pd ON pd.id=p.descripcion_tipo_id ${where} ORDER BY p.created_at DESC LIMIT $${values.length - 1}::int OFFSET $${values.length}::int`, values);
    return noStore(reply).send({ orders: result.rows.map(orderJson), limit: query.data.limit, offset: query.data.offset, total: Number(count.rows[0]?.total ?? 0) });
  });
  app.post('/api/orders', {
    preHandler: app.requireFleetSession,
    config: sensitiveRateLimit
  }, async (request, reply) => {
    const body = orderCreateSchema.safeParse(request.body); if (!body.success) return invalid(reply); if (!sessionOr401(request.fleetSession, reply)) return; const s = request.fleetSession;
    let localId = body.data.local_id; if (s.roleCode === 'local' && !localId) { const ids = await permittedLocationIds(database, s.userId); if (ids.length === 1) localId = ids[0]; }
    if (!localId) return invalid(reply); const local = (await database.query<Row>('SELECT id,empresa_id,activo FROM public.locales WHERE id=$1::uuid', [localId])).rows[0]; if (!local || local.activo !== true) return fail(reply, 400, 'invalid_reference', 'Local inválido.'); if (!await canUseLocation(database, s, local)) return forbidden(reply);
    const description = (await database.query<Row>('SELECT id FROM public.pedido_descripciones WHERE id=$1::uuid AND empresa_id=$2::uuid AND activo=true', [body.data.descripcion_tipo_id, local.empresa_id])).rows[0]; if (!description) return fail(reply, 400, 'invalid_reference', 'Descripción inválida.');
    const d = body.data; const result = await database.query<Row>('INSERT INTO public.pedidos (empresa_id,local_id,creado_por_usuario_id,descripcion_tipo_id,destino,destino_latitud,destino_longitud,factura_solicitud,numero_contacto,prioridad,observaciones) VALUES ($1::uuid,$2::uuid,$3::uuid,$4::uuid,$5::text,$6::double precision,$7::double precision,$8::text,$9::text,$10::text,$11::text) RETURNING *', [local.empresa_id,local.id,s.userId,description.id,d.destino ?? null,d.destino_latitud ?? null,d.destino_longitud ?? null,d.factura_solicitud ?? null,d.numero_contacto ?? null,d.prioridad,d.observaciones ?? null]);
    const order = result.rows[0];
    if (order) await notifyNewOrder(database, { id: String(order.id), empresa_id: String(order.empresa_id), local_id: String(order.local_id) });
    return noStore(reply).code(201).send({ order });
  });
  app.get('/api/orders/:id', { preHandler: app.requireFleetSession }, async (request, reply) => {
    const params = idParamsSchema.safeParse(request.params); if (!params.success) return invalid(reply); if (!sessionOr401(request.fleetSession, reply)) return; const s = request.fleetSession;
    const order = (await database.query<Row>('SELECT * FROM public.pedidos WHERE id=$1::uuid', [params.data.id])).rows[0]; if (!order) return fail(reply, 404, 'not_found', 'Pedido no encontrado.');
    let allowed = isSuper(s) || (isManager(s) && s.companyId === order.empresa_id);
    if (!allowed && (s.roleCode === 'user' || s.roleCode === 'local')) allowed = await canUseLocation(database, s, { id: order.local_id, empresa_id: order.empresa_id });
    if (!allowed && s.roleCode === 'chofer') { const assigned = await database.query<Row>('SELECT 1 FROM public.gestiones WHERE pedido_id=$1::uuid AND chofer_usuario_id=$2::uuid', [order.id, s.userId]); allowed = assigned.rowCount === 1 || (s.companyId === order.empresa_id && order.estado === 'pendiente'); }
    if (!allowed) return forbidden(reply); return noStore(reply).send({ order });
  });
  app.post('/api/orders/:id/cancel', { preHandler: app.requireFleetSession }, async (request, reply) => {
    const params=idParamsSchema.safeParse(request.params), body=cancelOrderSchema.safeParse(request.body ?? {}); if(!params.success||!body.success)return invalid(reply); if(!sessionOr401(request.fleetSession,reply))return; const s=request.fleetSession;
    const order=(await database.query<Row>('SELECT id,local_id,empresa_id,estado FROM public.pedidos WHERE id=$1::uuid',[params.data.id])).rows[0]; if(!order)return fail(reply,404,'not_found','Pedido no encontrado.'); if(s.roleCode==='local'&&order.estado!=='pendiente')return fail(reply,409,'local_cancellation_only_pending','El local solo puede cancelar pedidos pendientes.'); const management=await database.query<Row>('SELECT 1 FROM public.gestiones WHERE pedido_id=$1::uuid AND estado=ANY($2::text[])',[order.id,activeStates]); if(management.rowCount)return fail(reply,409,'active_management','El pedido tiene una gestión activa.'); if(!await canUseLocation(database,s,order))return forbidden(reply); const states=s.roleCode==='local'?['pendiente']:['pendiente','asignado']; const updated=await database.query<Row>('UPDATE public.pedidos SET estado=$1::text,cancelado_por_usuario_id=$2::uuid,cancelado_at=now(),updated_at=now() WHERE id=$3::uuid AND estado=ANY($4::text[]) RETURNING *',['cancelado',s.userId,order.id,states]); if(!updated.rowCount)return fail(reply,409,'conflict','El pedido ya no puede cancelarse.'); return noStore(reply).send({order:updated.rows[0]});
  });

  app.get('/api/order-descriptions', { preHandler: app.requireFleetSession }, async (request, reply) => { const query=descriptionListSchema.safeParse(request.query);if(!query.success)return invalid(reply);if(!sessionOr401(request.fleetSession,reply))return;const s=request.fleetSession;const companyId=isSuper(s)?query.data.empresa_id:s.companyId;if(!companyId)return invalid(reply);const result=await database.query<Row>('SELECT * FROM public.pedido_descripciones WHERE empresa_id=$1::uuid ORDER BY nombre',[companyId]);return noStore(reply).send({descriptions:result.rows}); });
  app.post('/api/order-descriptions', { preHandler: app.requireFleetSession }, async (request, reply) => {const body=descriptionCreateSchema.safeParse(request.body);if(!body.success)return invalid(reply);if(!sessionOr401(request.fleetSession,reply))return;const s=request.fleetSession;if(!isSuper(s)&&s.roleCode!=='admin')return forbidden(reply);if(!sameCompany(s,body.data.empresa_id))return forbidden(reply);try{const result=await database.query<Row>('INSERT INTO public.pedido_descripciones (empresa_id,nombre) VALUES ($1::uuid,$2::text) RETURNING *',[body.data.empresa_id,body.data.nombre]);return noStore(reply).code(201).send({description:result.rows[0]});}catch(error){if((error as DbError).code==='23505')return fail(reply,409,'conflict','Ya existe esa descripción.');throw error;}});
  app.patch('/api/order-descriptions/:id', { preHandler: app.requireFleetSession }, async (request, reply) => {const params=idParamsSchema.safeParse(request.params),body=descriptionPatchSchema.safeParse(request.body);if(!params.success||!body.success)return invalid(reply);if(!sessionOr401(request.fleetSession,reply))return;const s=request.fleetSession;if(!isSuper(s)&&s.roleCode!=='admin')return forbidden(reply);const current=(await database.query<Row>('SELECT empresa_id FROM public.pedido_descripciones WHERE id=$1::uuid',[params.data.id])).rows[0];if(!current)return fail(reply,404,'not_found','Descripción no encontrada.');if(!sameCompany(s,current.empresa_id))return forbidden(reply);const values:unknown[]=[];const set:string[]=[];if(body.data.nombre!==undefined){values.push(body.data.nombre);set.push(`nombre=$${values.length}::text`);}if(body.data.activo!==undefined){values.push(body.data.activo);set.push(`activo=$${values.length}::boolean`);}values.push(params.data.id);try{const result=await database.query<Row>(`UPDATE public.pedido_descripciones SET ${set.join(',')},updated_at=now() WHERE id=$${values.length}::uuid RETURNING *`,values);return noStore(reply).send({description:result.rows[0]});}catch(error){if((error as DbError).code==='23505')return fail(reply,409,'conflict','Ya existe esa descripción.');throw error;}});

  app.get('/api/driver/orders/available', { preHandler: app.requireFleetSession }, async (request, reply) => {if(!sessionOr401(request.fleetSession,reply))return;const s=request.fleetSession;if(s.roleCode!=='chofer'||!s.companyId)return forbidden(reply);const result=await database.query<Row>(`SELECT p.id AS order_id,l.nombre AS local,pd.nombre AS descripcion,p.destino,p.destino_latitud,p.destino_longitud,p.factura_solicitud,p.numero_contacto,p.prioridad,p.observaciones,p.created_at FROM public.pedidos p JOIN public.locales l ON l.id=p.local_id LEFT JOIN public.pedido_descripciones pd ON pd.id=p.descripcion_tipo_id LEFT JOIN public.gestiones g ON g.pedido_id=p.id WHERE p.empresa_id=$1::uuid AND p.estado='pendiente' AND g.id IS NULL ORDER BY p.created_at DESC`,[s.companyId]);return noStore(reply).send({orders:result.rows});});
  app.post('/api/driver/orders/:orderId/claim', { preHandler: app.requireFleetSession, config: sensitiveRateLimit }, async (request, reply) => {const params=orderIdParamsSchema.safeParse(request.params);if(!params.success)return invalid(reply);if(!sessionOr401(request.fleetSession,reply))return;const s=request.fleetSession;if(s.roleCode!=='chofer')return forbidden(reply);try{const rpc=await database.query<Row>('SELECT * FROM public.fleet_control_driver_claim_order($1::uuid,$2::uuid)',[params.data.orderId,s.userId]);const id=rpc.rows[0]?.id;if(!id)throw new Error('Missing management id');const management=(await database.query<Row>(`${managementSelect} WHERE g.id=$1::uuid`,[id])).rows[0];if(!management)throw new Error('Management not found');return noStore(reply).code(201).send({management:managementJson(management)});}catch(error){return dbFailure(reply,error);}});

  app.get('/api/managements', { preHandler: app.requireFleetSession }, async (request, reply) => {const query=managementListSchema.safeParse(request.query);if(!query.success)return invalid(reply);if(!sessionOr401(request.fleetSession,reply))return;const s=request.fleetSession;if(s.roleCode==='user')return forbidden(reply);const filters:string[]=[];const values:unknown[]=[];const add=(column:string,value:string|undefined)=>{if(value){values.push(value);filters.push(`${column}=$${values.length}::uuid`);}};if(s.roleCode==='chofer'){values.push(s.userId);filters.push(`g.chofer_usuario_id=$${values.length}::uuid`);}else if(!isSuper(s)){if(!s.companyId)return forbidden(reply);values.push(s.companyId);filters.push(`g.empresa_id=$${values.length}::uuid`);}if(query.data.estado){values.push(query.data.estado);filters.push(`g.estado=$${values.length}::text`);}add('g.chofer_usuario_id',query.data.driver_user_id);add('g.vehiculo_id',query.data.vehicle_id);add('g.local_id',query.data.local_id);add('g.pedido_id',query.data.order_id);const where=filters.length?`WHERE ${filters.join(' AND ')}`:'';const count=await database.query<Row>(`SELECT count(*)::int AS total FROM public.gestiones g ${where}`,values);values.push(query.data.limit,query.data.offset);const result=await database.query<Row>(`${managementSelect} ${where} ORDER BY g.created_at DESC LIMIT $${values.length-1}::int OFFSET $${values.length}::int`,values);const managements=result.rows.map(managementJson);if(s.roleCode==='chofer')managements.sort((a,b)=>{const rank=(v:unknown)=>operationalStates.includes(String(v))?0:v==='asignado'?1:2;const r=rank(a.management_status)-rank(b.management_status);return r||(a.management_status==='asignado'?Number(a.queue_position??Number.MAX_SAFE_INTEGER)-Number(b.queue_position??Number.MAX_SAFE_INTEGER):String(b.created_at).localeCompare(String(a.created_at)));});return noStore(reply).send({managements,limit:query.data.limit,offset:query.data.offset,total:Number(count.rows[0]?.total??0)});});
  app.get('/api/managements/:id', { preHandler: app.requireFleetSession }, async (request, reply) => {const params=idParamsSchema.safeParse(request.params);if(!params.success)return invalid(reply);if(!sessionOr401(request.fleetSession,reply))return;const s=request.fleetSession;const management=(await database.query<Row>(`${managementSelect} WHERE g.id=$1::uuid`,[params.data.id])).rows[0];if(!management)return fail(reply,404,'not_found','Gestión no encontrada.');if(!(isSuper(s)||(isManager(s)&&s.companyId===management.empresa_id)||(s.roleCode==='chofer'&&s.userId===management.chofer_usuario_id)))return forbidden(reply);const events=await database.query<Row>('SELECT id,usuario_id,estado_anterior,estado_nuevo,observaciones,created_at FROM public.gestion_eventos WHERE gestion_id=$1::uuid ORDER BY created_at',[params.data.id]);return noStore(reply).send({management:managementJson(management),events:events.rows});});
  app.post('/api/managements', { preHandler: app.requireFleetSession }, async (request, reply) => {const body=managementCreateSchema.safeParse(request.body);if(!body.success)return invalid(reply);if(!sessionOr401(request.fleetSession,reply))return;const s=request.fleetSession;if(!isManager(s))return forbidden(reply);const order=(await database.query<Row>('SELECT empresa_id FROM public.pedidos WHERE id=$1::uuid',[body.data.order_id])).rows[0];if(!order)return fail(reply,404,'not_found','Pedido no encontrado.');if(!sameCompany(s,order.empresa_id))return forbidden(reply);try{const rpc=await database.query<Row>('SELECT * FROM public.fleet_control_create_gestion($1::uuid,$2::uuid,$3::uuid,$4::uuid)',[body.data.order_id,body.data.driver_user_id,body.data.vehicle_id,s.userId]);const id=rpc.rows[0]?.id;if(!id)throw new Error('Missing management id');const management=(await database.query<Row>(`${managementSelect} WHERE g.id=$1::uuid`,[id])).rows[0];if(!management)throw new Error('Management not found');return noStore(reply).code(201).send({management:managementJson(management)});}catch(error){return dbFailure(reply,error);}});
  app.post('/api/managements/:id/status', { preHandler: app.requireFleetSession }, async (request, reply) => {const params=idParamsSchema.safeParse(request.params),body=managementStatusSchema.safeParse(request.body);if(!params.success||!body.success)return invalid(reply);if(!sessionOr401(request.fleetSession,reply))return;const s=request.fleetSession;if(s.roleCode!=='chofer')return forbidden(reply);try{const rpc=await database.query<Row>('SELECT * FROM public.fleet_control_update_gestion_status($1::uuid,$2::text,$3::uuid)',[params.data.id,body.data.status,s.userId]);const id=rpc.rows[0]?.id;if(!id)throw new Error('Missing management id');const management=(await database.query<Row>(`${managementSelect} WHERE g.id=$1::uuid`,[id])).rows[0];if(!management)throw new Error('Management not found');return noStore(reply).send({management:managementJson(management)});}catch(error){return dbFailure(reply,error);}});
  app.get('/api/drivers', { preHandler: app.requireFleetSession }, async (request, reply) => {const query=driverListSchema.safeParse(request.query);if(!query.success)return invalid(reply);if(!sessionOr401(request.fleetSession,reply))return;const s=request.fleetSession;if(!isManager(s))return forbidden(reply);const companyId=isSuper(s)?query.data.empresa_id:s.companyId;if(!companyId&&!isSuper(s))return forbidden(reply);const result=await database.query<Row>(`SELECT u.id,u.nombre,u.usuario FROM public.usuarios u JOIN public.roles r ON r.id=u.rol_id WHERE r.codigo='chofer' AND u.activo=true ${companyId?'AND u.empresa_id=$1::uuid':''} ORDER BY u.nombre`,companyId?[companyId]:[]);return noStore(reply).send({drivers:result.rows});});
}
