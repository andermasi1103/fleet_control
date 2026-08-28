import { protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";
import { isSuperAdmin } from "../_shared/session.ts";
import {
  orderPriorities,
  orderStates,
  permittedLocationIds,
} from "../_shared/orders.ts";
import { isUuid, relatedName } from "../_shared/validation.ts";

Deno.serve((request) =>
  protectedEndpoint(request, "GET", async ({ admin, session, url }) => {
    if (session.role === "chofer") return error("forbidden", 403);
    const status = url.searchParams.get("estado"),
      locationId = url.searchParams.get("local_id"),
      priority = url.searchParams.get("prioridad"),
      from = url.searchParams.get("desde"),
      until = url.searchParams.get("hasta");
    if (
      (status && !orderStates.includes(status as typeof orderStates[number])) ||
      (priority &&
        !orderPriorities.includes(
          priority as typeof orderPriorities[number],
        )) ||
      (locationId && !isUuid(locationId))
    ) return error("invalid_request", 400);
    const limit = Math.min(
        Math.max(Number(url.searchParams.get("limit") ?? "20"), 1),
        100,
      ),
      offset = Math.max(Number(url.searchParams.get("offset") ?? "0"), 0);
    if (!Number.isInteger(limit) || !Number.isInteger(offset)) {
      return error("invalid_request", 400);
    }
    let query = admin.from("pedidos").select(
      "id,empresa_id,local_id,creado_por_usuario_id,descripcion_tipo_id,destino,destino_latitud,destino_longitud,factura_solicitud,numero_contacto,prioridad,observaciones,estado,created_at,updated_at,empresas(nombre),locales(nombre),usuarios!pedidos_creado_por_usuario_id_fkey(nombre),pedido_descripciones(nombre)",
      { count: "exact" },
    ).order("created_at", { ascending: false }).range(
      offset,
      offset + limit - 1,
    );
    if (status) query = query.eq("estado", status);
    if (priority) query = query.eq("prioridad", priority);
    if (from) {
      if (Number.isNaN(Date.parse(from))) return error("invalid_request", 400);
      query = query.gte("created_at", from);
    }
    if (until) {
      if (Number.isNaN(Date.parse(until))) return error("invalid_request", 400);
      query = query.lte("created_at", until);
    }
    if (isSuperAdmin(session)) {
      if (locationId) query = query.eq("local_id", locationId);
    } else if (session.role === "admin" || session.role === "supervisor") {
      if (!session.empresaId) return error("forbidden", 403);
      query = query.eq("empresa_id", session.empresaId);
      if (locationId) query = query.eq("local_id", locationId);
    } else {
      const ids = await permittedLocationIds(admin, session);
      if (!ids?.length) return json({ orders: [], limit, offset, total: 0 });
      if (locationId && !ids.includes(locationId)) {
        return error("forbidden", 403);
      }
      query = query.in("local_id", locationId ? [locationId] : ids);
    }
    const { data, error: queryError, count } = await query;
    if (queryError) return error("internal_error", 500);
    return json({
      orders: (data ?? []).map((row: Record<string, unknown>) => ({
        ...row,
        empresa_nombre: relatedName(row.empresas),
        local_nombre: relatedName(row.locales),
        creado_por_nombre: relatedName(row.usuarios),
        descripcion: relatedName(row.pedido_descripciones),
        empresas: undefined,
        locales: undefined,
        usuarios: undefined,
        pedido_descripciones: undefined,
      })),
      limit,
      offset,
      total: count ?? 0,
    });
  })
);
