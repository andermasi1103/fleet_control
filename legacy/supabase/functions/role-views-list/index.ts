import { protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";
import { isSuperAdmin } from "../_shared/session.ts";

Deno.serve((request) =>
  protectedEndpoint(request, "GET", async ({ admin, session }) => {
    if (!isSuperAdmin(session)) return error("forbidden", 403);

    const [rolesResult, viewsResult, assignmentsResult] = await Promise.all([
      admin.from("roles").select("codigo").in(
        "codigo",
        ["super_admin", "admin", "supervisor", "chofer", "user", "local"],
      ).order("codigo"),
      admin.from("app_views").select(
        "codigo,nombre,descripcion,ruta,icono,orden,activo",
      ).order("orden"),
      admin.from("role_views").select(
        "visible,roles!inner(codigo),app_views!inner(codigo)",
      ),
    ]);

    if (rolesResult.error || viewsResult.error || assignmentsResult.error) {
      return error("internal_error", 500);
    }

    const assignments = (assignmentsResult.data ?? []).flatMap((row) => {
      const role = Array.isArray(row.roles) ? row.roles[0] : row.roles;
      const view = Array.isArray(row.app_views)
        ? row.app_views[0]
        : row.app_views;
      if (
        !role || !view || typeof role.codigo !== "string" ||
        typeof view.codigo !== "string"
      ) return [];
      return [{
        role_code: role.codigo,
        view_code: view.codigo,
        visible: row.visible === true,
      }];
    });

    return json({
      roles: rolesResult.data ?? [],
      views: viewsResult.data ?? [],
      role_views: assignments,
    });
  })
);
