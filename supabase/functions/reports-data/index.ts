import { protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";
import { isSuperAdmin } from "../_shared/session.ts";
import { isUuid } from "../_shared/validation.ts";

const maxRows = 10000;
const reportTypes = [
  "orders",
  "managements",
  "attendance",
  "drivers",
  "vehicles",
  "locations",
] as const;
type ReportType = typeof reportTypes[number];

function parseIsoDate(value: string | null): Date | null {
  if (value === null) return null;
  const match =
    /^(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,9}))?)?(?:Z|[+-]\d{2}:\d{2}))?$/
      .exec(value);
  if (!match) return null;
  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);
  const hour = match[4] === undefined ? 0 : Number(match[4]);
  const minute = match[5] === undefined ? 0 : Number(match[5]);
  const second = match[6] === undefined ? 0 : Number(match[6]);
  const daysInMonth = new Date(Date.UTC(year, month, 0)).getUTCDate();
  if (
    month < 1 || month > 12 || day < 1 || day > daysInMonth ||
    hour > 23 || minute > 59 || second > 59
  ) {
    return null;
  }
  const parsed = new Date(value);
  return Number.isNaN(parsed.valueOf()) ? null : parsed;
}

Deno.serve((request) =>
  protectedEndpoint(request, "GET", async ({ admin, session, url }) => {
    if (
      !isSuperAdmin(session) && session.role !== "admin" &&
      session.role !== "supervisor"
    ) {
      return error("forbidden", 403);
    }
    const type = url.searchParams.get("type");
    if (!reportTypes.includes(type as ReportType)) {
      return error("invalid_request", 400);
    }
    const requestedCompany = url.searchParams.get("empresa_id");
    const localId = url.searchParams.get("local_id");
    const from = url.searchParams.get("desde");
    const until = url.searchParams.get("hasta");
    const fromDate = parseIsoDate(from);
    const untilDate = parseIsoDate(until);
    if (
      (requestedCompany && !isUuid(requestedCompany)) ||
      (localId && !isUuid(localId)) || (from && !fromDate) ||
      (until && !untilDate) ||
      (fromDate && untilDate && fromDate > untilDate)
    ) {
      return error("invalid_request", 400);
    }
    const companyId = isSuperAdmin(session)
      ? requestedCompany
      : session.empresaId;
    if (!isSuperAdmin(session) && !companyId) return error("forbidden", 403);
    const state = url.searchParams.get("estado");
    const priority = url.searchParams.get("prioridad");
    let result: { data: unknown[] | null; error: unknown };

    if (type === "orders") {
      let query = admin.from("pedidos").select(
        "id,created_at,empresa_id,local_id,descripcion_tipo_id,prioridad,estado,numero_contacto,empresas(nombre),locales(nombre),pedido_descripciones(nombre)",
      ).limit(maxRows + 1);
      if (companyId) query = query.eq("empresa_id", companyId);
      if (localId) query = query.eq("local_id", localId);
      if (state) query = query.eq("estado", state);
      if (priority) query = query.eq("prioridad", priority);
      if (from) query = query.gte("created_at", from);
      if (until) query = query.lte("created_at", until);
      result = await query.order("created_at", { ascending: false });
    } else if (type === "managements") {
      let query = admin.from("gestiones").select(
        "id,pedido_id,empresa_id,local_id,chofer_usuario_id,vehiculo_id,estado,queue_position,created_at,aceptado_at,en_camino_at,en_gestion_at,completado_at,locales(nombre),vehiculos(patente),usuarios!gestiones_chofer_usuario_id_fkey(nombre,usuario)",
      ).limit(maxRows + 1);
      if (companyId) query = query.eq("empresa_id", companyId);
      if (localId) query = query.eq("local_id", localId);
      if (state) query = query.eq("estado", state);
      if (from) query = query.gte("created_at", from);
      if (until) query = query.lte("created_at", until);
      result = await query.order("created_at", { ascending: false });
    } else if (type === "attendance") {
      let query = admin.from("asistencias").select(
        "id,fecha_hora,usuario_id,empresa_id,local_id,tipo,latitud,longitud,dentro_geocerca,usuarios(nombre,usuario,roles(codigo)),locales(nombre)",
      ).limit(maxRows + 1);
      if (companyId) query = query.eq("empresa_id", companyId);
      if (localId) query = query.eq("local_id", localId);
      if (from) query = query.gte("fecha_hora", from);
      if (until) query = query.lte("fecha_hora", until);
      result = await query.order("fecha_hora", { ascending: false });
    } else if (type === "drivers") {
      let query = admin.from("usuarios").select(
        "id,usuario,nombre,activo,empresa_id,roles!inner(codigo),usuario_vehiculos(vehiculos(patente,tipo,marca,modelo))",
      ).eq("roles.codigo", "chofer").limit(maxRows + 1);
      if (companyId) query = query.eq("empresa_id", companyId);
      result = await query.order("nombre");
    } else if (type === "vehicles") {
      let query = admin.from("vehiculos").select(
        "id,empresa_id,patente,tipo,marca,modelo,anio,activo",
      ).limit(maxRows + 1);
      if (companyId) query = query.eq("empresa_id", companyId);
      result = await query.order("patente");
    } else {
      let query = admin.from("locales").select(
        "id,empresa_id,codigo,nombre,descripcion,direccion,latitud,longitud,radio_metros,activo",
      ).limit(maxRows + 1);
      if (companyId) query = query.eq("empresa_id", companyId);
      if (localId) query = query.eq("id", localId);
      result = await query.order("nombre");
    }
    if (result.error) return error("internal_error", 500);
    const rows = result.data ?? [];
    if (rows.length > maxRows) return error("report_too_large", 422);
    return json({ type, rows, count: rows.length, company_id: companyId });
  })
);
