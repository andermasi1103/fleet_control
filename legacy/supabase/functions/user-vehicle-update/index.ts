import { body, protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";
import { canManageCompany, isSuperAdmin } from "../_shared/session.ts";
import { isUuid, relatedCode } from "../_shared/validation.ts";

type UserRow = Record<string, unknown> & { roles: unknown };

Deno.serve((request) =>
  protectedEndpoint(request, "PATCH", async ({ admin, session }) => {
    if (!isSuperAdmin(session) && session.role !== "admin") {
      return error("forbidden", 403);
    }

    const payload = await body(request);
    if (
      !payload || !isUuid(payload.user_id) ||
      !(payload.vehicle_id === null || isUuid(payload.vehicle_id))
    ) {
      return error("invalid_request", 400);
    }

    const { data: user, error: userError } = await admin.from("usuarios")
      .select("id,empresa_id,activo,roles!inner(codigo)")
      .eq("id", payload.user_id)
      .maybeSingle<UserRow>();
    if (userError) return error("internal_error", 500);
    if (!user || user.activo !== true || relatedCode(user.roles) !== "chofer") {
      return error("not_found", 404);
    }
    if (!canManageCompany(session, user.empresa_id as string | null)) {
      return error("forbidden", 403);
    }

    const { error: rpcError } = await admin.rpc(
      "fleet_control_set_user_vehicle",
      {
        p_user_id: payload.user_id,
        p_vehicle_id: payload.vehicle_id,
      },
    );
    if (rpcError) {
      return error(
        rpcError.code === "P0001" ? "invalid_request" : "internal_error",
        rpcError.code === "P0001" ? 400 : 500,
      );
    }
    return json({ user_vehicle: null });
  })
);
