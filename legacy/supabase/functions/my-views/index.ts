import { protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";

Deno.serve((request) =>
  protectedEndpoint(request, "GET", async ({ admin, session }) => {
    const { data, error: queryError } = await admin
      .from("role_views")
      .select("app_views!inner(codigo, activo, orden)")
      .eq("role_id", session.roleId)
      .eq("visible", true)
      .eq("app_views.activo", true)
      .order("orden", { referencedTable: "app_views" });

    if (queryError) return error("internal_error", 500);

    const views = (data ?? [])
      .map((row: { app_views: unknown }) => {
        const view = Array.isArray(row.app_views)
          ? row.app_views[0]
          : row.app_views;
        return typeof view === "object" && view !== null &&
            "codigo" in view && typeof view.codigo === "string"
          ? view.codigo
          : null;
      })
      .filter((code): code is string => code !== null);

    return json({ views });
  })
);
