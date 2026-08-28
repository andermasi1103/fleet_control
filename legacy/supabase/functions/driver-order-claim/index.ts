import { body, protectedEndpoint } from "../_shared/http.ts";
import {
  managementJson,
  readManagement,
  rpcError,
} from "../_shared/managements.ts";
import { error, json } from "../_shared/responses.ts";
import { isUuid } from "../_shared/validation.ts";

Deno.serve((request) =>
  protectedEndpoint(request, "POST", async ({ admin, session }) => {
    if (session.role !== "chofer") return error("forbidden", 403);

    const payload = await body(request);
    if (!payload || !isUuid(payload.order_id)) {
      return error("invalid_request", 400);
    }

    const { data, error: claimError } = await admin.rpc(
      "fleet_control_driver_claim_order",
      {
        p_order_id: payload.order_id,
        p_driver_user_id: session.userId,
      },
    );
    if (claimError) {
      const [code, status] = rpcError(claimError.message);
      return error(code, status);
    }

    const managementId = (data as { id?: string } | null)?.id;
    if (!managementId) return error("internal_error", 500);

    const { data: management, error: readError } = await readManagement(
      admin,
      managementId,
    );
    if (readError || !management) return error("internal_error", 500);

    return json({
      management: managementJson(management as Record<string, unknown>),
    }, 201);
  })
);
