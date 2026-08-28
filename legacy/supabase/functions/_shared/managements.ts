import type { SupabaseClient } from "@supabase/supabase-js";
import type { FleetSession } from "./session.ts";
import { isSuperAdmin } from "./session.ts";

export const managementStatuses = [
  "asignado",
  "aceptado",
  "en_camino",
  "en_gestion",
  "completado",
  "cancelado",
] as const;
export function canAssignManagement(session: FleetSession) {
  return isSuperAdmin(session) || session.role === "admin" ||
    session.role === "supervisor";
}
export function canReadManagement(
  session: FleetSession,
  companyId: string,
  driverId: string,
) {
  return isSuperAdmin(session) ||
    ((session.role === "admin" || session.role === "supervisor") &&
      session.empresaId === companyId) ||
    (session.role === "chofer" && session.userId === driverId);
}
export function rpcError(message: string): [string, number] {
  if (
    [
      "driver_busy",
      "vehicle_busy",
      "active_management",
      "invalid_transition",
      "order_already_taken",
      "driver_vehicle_required",
      "active_management_exists",
      "queue_position_conflict",
    ]
      .includes(message)
  ) return [message, 409];
  if (message === "not_found") return [message, 404];
  if (message === "forbidden") return [message, 403];
  if (message === "invalid_reference") return [message, 400];
  return ["internal_error", 500];
}
export async function readManagement(admin: SupabaseClient, id: string) {
  return await admin.from("gestiones").select(
    "id,pedido_id,empresa_id,local_id,chofer_usuario_id,vehiculo_id,estado,queue_position,aceptado_at,en_camino_at,en_gestion_at,completado_at,created_at,updated_at,pedidos(estado,descripcion_tipo_id,destino,destino_latitud,destino_longitud,factura_solicitud,numero_contacto,prioridad,observaciones,pedido_descripciones(nombre)),empresas(nombre),locales(nombre),chofer:usuarios!gestiones_chofer_usuario_id_fkey(nombre,usuario),vehiculos(patente,marca,modelo)",
  ).eq("id", id).maybeSingle();
}
export function managementJson(row: Record<string, unknown>) {
  const get = (key: string) => row[key] as Record<string, unknown> | null;
  const order = get("pedidos"),
    company = get("empresas"),
    local = get("locales"),
    driver = get("chofer"),
    vehicle = get("vehiculos"),
    description = order?.pedido_descripciones as Record<string, unknown> | null;
  return {
    ...row,
    order_id: row.pedido_id,
    management_status: row.estado,
    order_status: order?.estado,
    empresa_nombre: company?.nombre,
    local_nombre: local?.nombre,
    driver_name: driver?.nombre,
    driver_username: driver?.usuario,
    vehicle_plate: vehicle?.patente,
    vehicle_brand: vehicle?.marca,
    vehicle_model: vehicle?.modelo,
    description: description?.nombre,
    destino: order?.destino,
    destino_latitud: order?.destino_latitud,
    destino_longitud: order?.destino_longitud,
    factura_solicitud: order?.factura_solicitud,
    numero_contacto: order?.numero_contacto,
    prioridad: order?.prioridad,
    observaciones_pedido: order?.observaciones,
    pedidos: undefined,
    empresas: undefined,
    locales: undefined,
    chofer: undefined,
    vehiculos: undefined,
  };
}
