import { protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";
import { isSuperAdmin } from "../_shared/session.ts";
import { managementJson, managementStatuses } from "../_shared/managements.ts";
import { isUuid } from "../_shared/validation.ts";
Deno.serve((request) =>
  protectedEndpoint(request, "GET", async ({ admin, session, url }) => {
    if (session.role === "user") return error("forbidden", 403);
    const status = url.searchParams.get("estado"),
      driver = url.searchParams.get("driver_user_id"),
      vehicle = url.searchParams.get("vehicle_id"),
      local = url.searchParams.get("local_id"),
      order = url.searchParams.get("order_id");
    if (
      (status &&
        !managementStatuses.includes(
          status as typeof managementStatuses[number],
        )) ||
      [driver, vehicle, local, order].some((x) => x !== null && !isUuid(x))
    ) return error("invalid_request", 400);
    const limit = Math.min(
        Math.max(Number(url.searchParams.get("limit") ?? "20"), 1),
        100,
      ),
      offset = Math.max(Number(url.searchParams.get("offset") ?? "0"), 0);
    if (!Number.isInteger(limit) || !Number.isInteger(offset)) {
      return error("invalid_request", 400);
    }
    let q = admin.from("gestiones").select(
      "id,pedido_id,empresa_id,local_id,chofer_usuario_id,vehiculo_id,estado,queue_position,aceptado_at,en_camino_at,en_gestion_at,completado_at,created_at,updated_at,pedidos(estado,descripcion_tipo_id,destino,destino_latitud,destino_longitud,factura_solicitud,numero_contacto,prioridad,observaciones,pedido_descripciones(nombre)),empresas(nombre),locales(nombre),chofer:usuarios!gestiones_chofer_usuario_id_fkey(nombre,usuario),vehiculos(patente,marca,modelo)",
      { count: "exact" },
    ).order("created_at", { ascending: false }).range(
      offset,
      offset + limit - 1,
    );
    if (session.role === "chofer") {
      q = q.eq("chofer_usuario_id", session.userId);
    } else if (!isSuperAdmin(session)) {
      if (!session.empresaId) return error("forbidden", 403);
      q = q.eq("empresa_id", session.empresaId);
    }
    if (status) q = q.eq("estado", status);
    if (driver) q = q.eq("chofer_usuario_id", driver);
    if (vehicle) q = q.eq("vehiculo_id", vehicle);
    if (local) q = q.eq("local_id", local);
    if (order) q = q.eq("pedido_id", order);
    const { data, error: queryError, count } = await q;
    if (queryError) return error("internal_error", 500);
    const managements: Record<string, unknown>[] = (data ?? []).map((row) =>
      managementJson(row as Record<string, unknown>)
    );
    if (session.role === "chofer") {
      const rank = (status: unknown) => {
        if (["aceptado", "en_camino", "en_gestion"].includes(String(status))) {
          return 0;
        }
        if (status === "asignado") return 1;
        return 2;
      };
      managements.sort((a, b) => {
        const byStatus = rank(a.management_status) - rank(b.management_status);
        if (byStatus !== 0) return byStatus;
        if (a.management_status === "asignado") {
          return Number(a.queue_position ?? Number.MAX_SAFE_INTEGER) -
            Number(b.queue_position ?? Number.MAX_SAFE_INTEGER);
        }
        return String(b.created_at).localeCompare(String(a.created_at));
      });
    }
    return json({
      managements,
      limit,
      offset,
      total: count ?? 0,
    });
  })
);
