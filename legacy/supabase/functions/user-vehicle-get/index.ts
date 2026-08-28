import { protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";
import { canReadCompany, isSuperAdmin } from "../_shared/session.ts";
import { isUuid, relatedCode } from "../_shared/validation.ts";

type UserRow = Record<string, unknown> & { roles: unknown };

Deno.serve((request) =>
  protectedEndpoint(request, "GET", async ({ admin, session, url }) => {
    if (
      !isSuperAdmin(session) && !["admin", "supervisor"].includes(session.role)
    ) {
      return error("forbidden", 403);
    }

    const userId = url.searchParams.get("user_id");
    if (!isUuid(userId)) return error("invalid_request", 400);

    const { data: user, error: userError } = await admin.from("usuarios")
      .select("id,empresa_id,activo,roles!inner(codigo)")
      .eq("id", userId)
      .maybeSingle<UserRow>();
    if (userError) return error("internal_error", 500);
    if (!user || user.activo !== true || relatedCode(user.roles) !== "chofer") {
      return error("not_found", 404);
    }
    if (!canReadCompany(session, user.empresa_id as string | null)) {
      return error("forbidden", 403);
    }
    if (typeof user.empresa_id !== "string") {
      return error("invalid_request", 400);
    }

    const [assignmentResult, vehiclesResult] = await Promise.all([
      admin.from("usuario_vehiculos")
        .select(
          "usuario_id,vehiculo_id,vehiculos(id,patente,marca,modelo,tipo_vehiculo,activo)",
        )
        .eq("usuario_id", userId)
        .maybeSingle(),
      admin.from("vehiculos")
        .select("id,patente,marca,modelo,tipo_vehiculo")
        .eq("empresa_id", user.empresa_id)
        .eq("activo", true)
        .order("patente"),
    ]);
    if (assignmentResult.error || vehiclesResult.error) {
      return error("internal_error", 500);
    }

    const assignment = assignmentResult.data as Record<string, unknown> | null;
    const vehicle = assignment?.vehiculos;
    return json({
      user_vehicle: assignment
        ? {
          user_id: assignment.usuario_id,
          vehicle_id: assignment.vehiculo_id,
          vehicle: Array.isArray(vehicle)
            ? vehicle[0] ?? null
            : vehicle ?? null,
        }
        : null,
      vehicles: vehiclesResult.data ?? [],
    });
  })
);
