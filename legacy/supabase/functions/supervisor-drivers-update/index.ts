import { body, protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";
import { canManageCompany, isSuperAdmin } from "../_shared/session.ts";
import { isUuid } from "../_shared/validation.ts";

Deno.serve((request) =>
  protectedEndpoint(request, "PUT", async ({ admin, session }) => {
    if (!isSuperAdmin(session) && session.role !== "admin") {
      return error("forbidden", 403);
    }
    const payload = await body(request);
    const supervisorId = payload?.supervisor_user_id;
    const driverIds = payload?.driver_user_ids;
    if (
      !isUuid(supervisorId) || !Array.isArray(driverIds) ||
      !driverIds.every((id) => typeof id === "string" && isUuid(id)) ||
      new Set(driverIds).size !== driverIds.length
    ) return error("invalid_request", 400);

    const { data: supervisor, error: supervisorError } = await admin
      .from("usuarios")
      .select("empresa_id,activo,roles!inner(codigo)")
      .eq("id", supervisorId).eq("activo", true).eq(
        "roles.codigo",
        "supervisor",
      )
      .maybeSingle();
    if (supervisorError) return error("internal_error", 500);
    if (!supervisor || !canManageCompany(session, supervisor.empresa_id)) {
      return error("forbidden", 403);
    }
    const companyId = supervisor.empresa_id;
    const { data: drivers, error: driversError } = await admin.from("usuarios")
      .select("id,roles!inner(codigo)").in("id", driverIds).eq(
        "empresa_id",
        companyId,
      )
      .eq("activo", true).eq("roles.codigo", "chofer");
    if (driversError) return error("internal_error", 500);
    if ((drivers?.length ?? 0) !== driverIds.length) {
      return error("invalid_driver_assignment", 400);
    }

    const { error: rpcError } = await admin.rpc(
      "fleet_control_set_supervisor_choferes",
      {
        p_supervisor_usuario_id: supervisorId,
        p_chofer_usuario_ids: driverIds,
      },
    );
    if (rpcError) return error("invalid_driver_assignment", 400);
    return json({
      supervisor_user_id: supervisorId,
      driver_user_ids: driverIds,
    });
  })
);
