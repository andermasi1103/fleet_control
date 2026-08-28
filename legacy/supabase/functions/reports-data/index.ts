import { protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";
import { isSuperAdmin } from "../_shared/session.ts";
import { isUuid } from "../_shared/validation.ts";
import type { SupabaseClient } from "@supabase/supabase-js";

const maxRows = 10000;
const types = [
  "orders",
  "managements",
  "attendance",
  "drivers",
  "vehicles",
  "locations",
] as const;
type Type = typeof types[number];
type Row = Record<string, unknown>;
const label = (value: unknown, field: string): string => {
  if (Array.isArray(value)) return label(value[0], field);
  return value && typeof value === "object" &&
      typeof (value as Row)[field] === "string"
    ? (value as Row)[field] as string
    : "";
};
const value = (row: Row, field: string): string =>
  typeof row[field] === "string" ? row[field] as string : "";
async function team(
  admin: SupabaseClient,
  id: string,
): Promise<string[] | null> {
  const { data, error: queryError } = await admin.from("supervisor_choferes")
    .select("chofer_usuario_id").eq("supervisor_usuario_id", id);
  return queryError
    ? null
    : (data ?? []).map((row: Row) => value(row, "chofer_usuario_id")).filter(
      Boolean,
    );
}
function validDate(value: string | null): boolean {
  return value === null ||
    /^\d{4}-\d{2}-\d{2}(?:T.*(?:Z|[+-]\d{2}:\d{2}))?$/.test(value) &&
      !Number.isNaN(Date.parse(value));
}
function limit(type: Type, rows: Row[]) {
  return rows.length > maxRows
    ? error("report_too_large", 422)
    : json({ type, rows, count: rows.length });
}

Deno.serve((request) =>
  protectedEndpoint(request, "GET", async ({ admin, session, url }) => {
    if (
      !isSuperAdmin(session) && session.role !== "admin" &&
      session.role !== "supervisor"
    ) return error("forbidden", 403);
    const type = url.searchParams.get("type") as Type;
    const requestedCompany = url.searchParams.get("empresa_id"),
      localId = url.searchParams.get("local_id"),
      driverId = url.searchParams.get("driver_user_id");
    const from = url.searchParams.get("desde"),
      until = url.searchParams.get("hasta");
    if (
      !types.includes(type) ||
      (requestedCompany && !isUuid(requestedCompany)) ||
      (localId && !isUuid(localId)) || (driverId && !isUuid(driverId)) ||
      !validDate(from) || !validDate(until) || (from && until && from > until)
    ) return error("invalid_request", 400);
    const companyId = isSuperAdmin(session)
      ? requestedCompany
      : session.empresaId;
    if (!isSuperAdmin(session) && !companyId) return error("forbidden", 403);
    let drivers: string[] | null = driverId ? [driverId] : null;
    if (session.role === "supervisor") {
      if (type === "locations") return error("forbidden", 403);
      const assigned = await team(admin, session.userId);
      if (assigned === null) return error("internal_error", 500);
      if (driverId && !assigned.includes(driverId)) {
        return error("forbidden", 403);
      }
      drivers = driverId ? [driverId] : assigned;
      if (drivers.length === 0) return limit(type, []);
    }
    const dates = <
      T extends {
        gte: (column: string, date: string) => T;
        lte: (column: string, date: string) => T;
      },
    >(query: T, column: string) => {
      if (from) query = query.gte(column, from);
      if (until) query = query.lte(column, until);
      return query;
    };
    if (type === "orders") {
      let managements = admin.from("gestiones").select(
        "pedido_id,chofer_usuario_id,vehiculos(patente),usuarios!gestiones_chofer_usuario_id_fkey(nombre),completado_at",
      );
      if (companyId) managements = managements.eq("empresa_id", companyId);
      if (drivers) managements = managements.in("chofer_usuario_id", drivers);
      const m = await managements;
      if (m.error) return error("internal_error", 500);
      const byOrder = new Map(
        (m.data ?? []).map((row: Row) => [value(row, "pedido_id"), row]),
      );
      if (session.role === "supervisor" && byOrder.size === 0) {
        return limit(type, []);
      }
      let query = admin.from("pedidos").select(
        "id,created_at,prioridad,estado,numero_contacto,locales(nombre),pedido_descripciones(nombre)",
      ).limit(maxRows + 1);
      if (companyId) query = query.eq("empresa_id", companyId);
      if (localId) query = query.eq("local_id", localId);
      if (session.role === "supervisor") {
        query = query.in("id", [...byOrder.keys()]);
      }
      query = dates(query, "created_at");
      const result = await query.order("created_at", { ascending: false });
      if (result.error) return error("internal_error", 500);
      return limit(
        type,
        (result.data ?? []).map((row: Row) => {
          const m = byOrder.get(value(row, "id"));
          return {
            "Fecha": value(row, "created_at"),
            "Local": label(row.locales, "nombre"),
            "Descripción": label(row.pedido_descripciones, "nombre"),
            "Prioridad": value(row, "prioridad"),
            "Estado": value(row, "estado"),
            "Chofer": label(m?.usuarios, "nombre"),
            "Vehículo": label(m?.vehiculos, "patente"),
            "Contacto": value(row, "numero_contacto"),
            "Fecha completado": value(m ?? {}, "completado_at"),
          };
        }),
      );
    }
    if (type === "managements") {
      let query = admin.from("gestiones").select(
        "created_at,estado,aceptado_at,en_camino_at,en_gestion_at,completado_at,locales(nombre),vehiculos(patente),usuarios!gestiones_chofer_usuario_id_fkey(nombre)",
      ).limit(maxRows + 1);
      if (companyId) query = query.eq("empresa_id", companyId);
      if (drivers) query = query.in("chofer_usuario_id", drivers);
      if (localId) query = query.eq("local_id", localId);
      query = dates(query, "created_at");
      const result = await query.order("created_at", { ascending: false });
      if (result.error) return error("internal_error", 500);
      return limit(
        type,
        (result.data ?? []).map((r: Row) => ({
          "Fecha": value(r, "created_at"),
          "Local": label(r.locales, "nombre"),
          "Chofer": label(r.usuarios, "nombre"),
          "Vehículo": label(r.vehiculos, "patente"),
          "Estado": value(r, "estado"),
          "Aceptado": value(r, "aceptado_at"),
          "En camino": value(r, "en_camino_at"),
          "Inicio gestión": value(r, "en_gestion_at"),
          "Completado": value(r, "completado_at"),
        })),
      );
    }
    if (type === "attendance") {
      let query = admin.from("asistencias").select(
        "fecha_hora,tipo,dentro_geocerca,usuarios(nombre,usuario),locales(nombre)",
      ).limit(maxRows + 1);
      if (companyId) query = query.eq("empresa_id", companyId);
      if (drivers) query = query.in("usuario_id", drivers);
      if (localId) query = query.eq("local_id", localId);
      query = dates(query, "fecha_hora");
      const result = await query.order("fecha_hora", { ascending: false });
      if (result.error) return error("internal_error", 500);
      return limit(
        type,
        (result.data ?? []).map((r: Row) => ({
          "Fecha y hora": value(r, "fecha_hora"),
          "Usuario": label(r.usuarios, "usuario"),
          "Nombre": label(r.usuarios, "nombre"),
          "Local": label(r.locales, "nombre"),
          "Tipo de marca": value(r, "tipo"),
          "Resultado": r.dentro_geocerca === true
            ? "Dentro de geocerca"
            : "Fuera de geocerca",
        })),
      );
    }
    if (type === "drivers") {
      let query = admin.from("usuarios").select(
        "id,usuario,nombre,activo,roles!inner(codigo),usuario_vehiculos(vehiculos(patente,tipo))",
      ).eq("roles.codigo", "chofer").limit(maxRows + 1);
      if (companyId) query = query.eq("empresa_id", companyId);
      if (drivers) query = query.in("id", drivers);
      const result = await query.order("nombre");
      if (result.error) return error("internal_error", 500);
      return limit(
        type,
        (result.data ?? []).map((r: Row) => ({
          "Usuario": value(r, "usuario"),
          "Nombre": value(r, "nombre"),
          "Activo": r.activo === true ? "Sí" : "No",
          "Vehículo habitual": label(
            label(r.usuario_vehiculos, "vehiculos"),
            "patente",
          ),
          "Tipo de vehículo": label(
            label(r.usuario_vehiculos, "vehiculos"),
            "tipo",
          ),
        })),
      );
    }
    if (type === "vehicles") {
      let managements = admin.from("gestiones").select(
        "vehiculo_id,chofer_usuario_id,usuarios!gestiones_chofer_usuario_id_fkey(nombre)",
      );
      if (companyId) managements = managements.eq("empresa_id", companyId);
      if (drivers) managements = managements.in("chofer_usuario_id", drivers);
      managements = dates(managements, "created_at");
      const used = await managements;
      if (used.error) return error("internal_error", 500);
      const vehicleIds = [
        ...new Set(
          (used.data ?? []).map((r: Row) => value(r, "vehiculo_id")).filter(
            Boolean,
          ),
        ),
      ];
      if (session.role === "supervisor" && vehicleIds.length === 0) {
        return limit(type, []);
      }
      let query = admin.from("vehiculos").select(
        "id,patente,tipo,marca,modelo,anio,activo",
      ).limit(maxRows + 1);
      if (companyId) query = query.eq("empresa_id", companyId);
      if (session.role === "supervisor") query = query.in("id", vehicleIds);
      const result = await query.order("patente");
      if (result.error) return error("internal_error", 500);
      return limit(
        type,
        (result.data ?? []).map((r: Row) => {
          const uses = (used.data ?? []).filter((m: Row) =>
            value(m, "vehiculo_id") === value(r, "id")
          );
          return {
            "Patente": value(r, "patente"),
            "Tipo": value(r, "tipo"),
            "Marca": value(r, "marca"),
            "Modelo": value(r, "modelo"),
            "Año": r.anio ?? "",
            "Activo": r.activo === true ? "Sí" : "No",
            "Chofer": uses.length ? label(uses[0].usuarios, "nombre") : "",
            "Gestiones realizadas": uses.length,
          };
        }),
      );
    }
    let query = admin.from("locales").select(
      "codigo,nombre,direccion,radio_metros,activo",
    ).limit(maxRows + 1);
    if (companyId) query = query.eq("empresa_id", companyId);
    if (localId) query = query.eq("id", localId);
    const result = await query.order("nombre");
    if (result.error) return error("internal_error", 500);
    return limit(
      type,
      (result.data ?? []).map((r: Row) => ({
        "Código": value(r, "codigo"),
        "Nombre": value(r, "nombre"),
        "Dirección": value(r, "direccion"),
        "Radio geocerca": r.radio_metros ?? "",
        "Activo": r.activo === true ? "Sí" : "No",
      })),
    );
  })
);
