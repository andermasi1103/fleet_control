import { body, protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";
import { canUseLocation } from "../_shared/orders.ts";
import { isUuid } from "../_shared/validation.ts";

Deno.serve((request) =>
  protectedEndpoint(request, "POST", async ({ admin, session }) => {
    const payload = await body(request);
    if (!payload || !isUuid(payload.order_id)) {
      return error("invalid_request", 400);
    }
    const { data: order, error: queryError } = await admin.from("pedidos")
      .select("id,local_id,empresa_id,estado").eq("id", payload.order_id)
      .maybeSingle();
    if (queryError) return error("internal_error", 500);
    if (!order) return error("not_found", 404);
    if (session.role === "local" && order.estado !== "pendiente") {
      return error("local_cancellation_only_pending", 409);
    }
    const { data: activeManagement, error: managementError } = await admin
      .from("gestiones")
      .select("id")
      .eq("pedido_id", order.id)
      .in("estado", ["asignado", "aceptado", "en_camino", "en_gestion"])
      .maybeSingle();
    if (managementError) return error("internal_error", 500);
    if (activeManagement) return error("active_management", 409);
    try {
      if (
        !await canUseLocation(admin, session, {
          id: order.local_id,
          empresa_id: order.empresa_id,
        })
      ) return error("forbidden", 403);
    } catch {
      return error("internal_error", 500);
    }
    if (!["pendiente", "asignado"].includes(order.estado)) {
      return error("conflict", 409);
    }
    const { data: updated, error: updateError } = await admin.from("pedidos")
      .update({
        estado: "cancelado",
        cancelado_por_usuario_id: session.userId,
        cancelado_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }).eq("id", order.id).in(
        "estado",
        session.role === "local" ? ["pendiente"] : ["pendiente", "asignado"],
      ).select()
      .maybeSingle();
    if (updateError) return error("internal_error", 500);
    if (!updated) return error("conflict", 409);
    return json({ order: updated });
  })
);
