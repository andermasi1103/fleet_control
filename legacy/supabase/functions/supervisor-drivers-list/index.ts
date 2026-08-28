import { protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";
import { canManageCompany, isSuperAdmin } from "../_shared/session.ts";
import { isUuid, relatedCode } from "../_shared/validation.ts";

type UserRow = Record<string, unknown> & { roles: unknown };

function userSummary(row: UserRow) {
  return {
    id: row.id as string,
    nombre: row.nombre,
    usuario: row.usuario,
    empresa_id: row.empresa_id,
    rol: relatedCode(row.roles),
  };
}

Deno.serve((request) =>
  protectedEndpoint(request, "GET", async ({ admin, session, url }) => {
    if (!isSuperAdmin(session) && session.role !== "admin") {
      return error("forbidden", 403);
    }
    const supervisorId = url.searchParams.get("supervisor_user_id");
    if (!supervisorId || !isUuid(supervisorId)) {
      return error("invalid_request", 400);
    }

    const { data: supervisor, error: supervisorError } = await admin
      .from("usuarios")
      .select("id,nombre,usuario,empresa_id,activo,roles!inner(codigo)")
      .eq("id", supervisorId)
      .eq("activo", true)
      .eq("roles.codigo", "supervisor")
      .maybeSingle<UserRow>();
    if (supervisorError) return error("internal_error", 500);
    if (
      !supervisor ||
      !canManageCompany(session, supervisor.empresa_id as string | null)
    ) {
      return error("forbidden", 403);
    }
    const companyId = supervisor.empresa_id as string | null;
    if (!companyId) return error("invalid_request", 400);

    const [
      { data: drivers, error: driversError },
      { data: assignments, error: assignmentsError },
    ] = await Promise.all([
      admin.from("usuarios").select(
        "id,nombre,usuario,empresa_id,roles!inner(codigo)",
      )
        .eq("empresa_id", companyId).eq("activo", true).eq(
          "roles.codigo",
          "chofer",
        ).order("nombre"),
      admin.from("supervisor_choferes").select("chofer_usuario_id")
        .eq("supervisor_usuario_id", supervisorId),
    ]);
    if (driversError || assignmentsError) return error("internal_error", 500);
    const assignedIds = new Set(
      (assignments ?? []).map((row: { chofer_usuario_id: string }) =>
        row.chofer_usuario_id
      ),
    );
    const availableDrivers = (drivers ?? []).map((row: UserRow) =>
      userSummary(row as UserRow)
    );
    return json({
      supervisor: userSummary(supervisor),
      assigned_driver_ids: [...assignedIds],
      assigned_drivers: availableDrivers.filter((driver) =>
        assignedIds.has(driver.id)
      ),
      available_drivers: availableDrivers,
    });
  })
);
