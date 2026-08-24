import { body, protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";
import { isSuperAdmin } from "../_shared/session.ts";
import { stringValue } from "../_shared/validation.ts";

const protectedForEveryRole = new Set(["home", "settings"]);
const protectedForSuperAdmin = new Set([
  "home",
  "settings",
  "role_views_management",
]);

Deno.serve((request) =>
  protectedEndpoint(request, "PATCH", async ({ admin, session }) => {
    if (!isSuperAdmin(session)) return error("forbidden", 403);

    const payload = await body(request);
    const roleCode = stringValue(payload?.role_code, 80);
    const viewCode = stringValue(payload?.view_code, 80);
    const visible = payload?.visible;
    if (!roleCode || !viewCode || typeof visible !== "boolean") {
      return error("invalid_request", 400);
    }

    if (
      !visible &&
      (protectedForEveryRole.has(viewCode) ||
        (roleCode === "super_admin" && protectedForSuperAdmin.has(viewCode)))
    ) {
      return error("protected_view", 409);
    }

    const [roleResult, viewResult] = await Promise.all([
      admin.from("roles").select("id").eq("codigo", roleCode).maybeSingle(),
      admin.from("app_views").select("id").eq("codigo", viewCode).maybeSingle(),
    ]);
    if (roleResult.error || viewResult.error) {
      return error("internal_error", 500);
    }
    if (!roleResult.data || !viewResult.data) return error("not_found", 404);

    const { error: updateError } = await admin.from("role_views").upsert({
      role_id: roleResult.data.id,
      view_id: viewResult.data.id,
      visible,
    }, { onConflict: "role_id,view_id" });
    if (updateError) return error("internal_error", 500);

    return json({ role_code: roleCode, view_code: viewCode, visible });
  })
);
