import { protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";
import { canUseLocation } from "../_shared/orders.ts";
import { isUuid } from "../_shared/validation.ts";

Deno.serve((request) =>
  protectedEndpoint(request, "GET", async ({ admin, session, url }) => {
    const id = url.searchParams.get("id");
    if (!id || !isUuid(id)) return error("invalid_request", 400);
    const { data: order, error: queryError } = await admin.from("pedidos")
      .select("*").eq("id", id).maybeSingle();
    if (queryError) return error("internal_error", 500);
    if (!order) return error("not_found", 404);
    let driverAllowed = false;
    if (session.role === "chofer") {
      const { data: management, error: managementError } = await admin
        .from("gestiones")
        .select("id")
        .eq("pedido_id", order.id)
        .eq("chofer_usuario_id", session.userId)
        .maybeSingle();
      if (managementError) return error("internal_error", 500);
      driverAllowed = management != null ||
        (session.empresaId === order.empresa_id &&
          order.estado === "pendiente");
    }
    let locationAllowed = false;
    if (session.role === "user" || session.role === "local") {
      try {
        locationAllowed = await canUseLocation(admin, session, {
          id: order.local_id,
          empresa_id: order.empresa_id,
        });
      } catch {
        return error("internal_error", 500);
      }
    }
    const allowed = session.role === "super_admin" ||
      ((session.role === "admin" || session.role === "supervisor") &&
        session.empresaId === order.empresa_id) ||
      locationAllowed ||
      driverAllowed;
    if (!allowed) return error("forbidden", 403);
    return json({ order });
  })
);
