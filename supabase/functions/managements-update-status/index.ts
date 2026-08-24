import { body, protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";
import {
  managementJson,
  readManagement,
  rpcError,
} from "../_shared/managements.ts";
import { isUuid } from "../_shared/validation.ts";
Deno.serve((request) =>
  protectedEndpoint(request, "POST", async ({ admin, session }) => {
    const p = await body(request);
    if (
      !p || !isUuid(p.management_id) || typeof p.status !== "string" ||
      !["aceptado", "en_camino", "en_gestion", "completado"].includes(p.status)
    ) return error("invalid_request", 400);
    if (session.role !== "chofer") return error("forbidden", 403);
    const { data, error: rpc } = await admin.rpc(
      "fleet_control_update_gestion_status",
      {
        p_management_id: p.management_id,
        p_status: p.status,
        p_user_id: session.userId,
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
    });
  })
);
