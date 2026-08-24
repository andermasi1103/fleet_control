import { body, protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";
import {
  canAssignManagement,
  managementJson,
  readManagement,
  rpcError,
} from "../_shared/managements.ts";
import { isUuid } from "../_shared/validation.ts";
Deno.serve((request) =>
  protectedEndpoint(request, "POST", async ({ admin, session }) => {
    if (!canAssignManagement(session)) return error("forbidden", 403);
    const p = await body(request);
    if (
      !p || !isUuid(p.order_id) || !isUuid(p.driver_user_id) ||
      !isUuid(p.vehicle_id)
    ) return error("invalid_request", 400);
    const { data: order, error: orderError } = await admin.from("pedidos")
      .select("empresa_id").eq("id", p.order_id).maybeSingle();
    if (orderError) return error("internal_error", 500);
    if (!order) return error("not_found", 404);
    if (
      !canAssignManagement(session) ||
      (session.role !== "super_admin" && session.empresaId !== order.empresa_id)
    ) return error("forbidden", 403);
    const { data, error: rpc } = await admin.rpc(
      "fleet_control_create_gestion",
      {
        p_order_id: p.order_id,
        p_driver_user_id: p.driver_user_id,
        p_vehicle_id: p.vehicle_id,
        p_assigned_by_user_id: session.userId,
      },
    );
    if (rpc) {
      const [code, status] = rpcError(rpc.message);
      return error(code, status);
    }
    const { data: management, error: readError } = await readManagement(
      admin,
      (data as { id: string }).id,
    );
    if (readError || !management) return error("internal_error", 500);
    return json({
      management: managementJson(management as Record<string, unknown>),
    }, 201);
  })
);
