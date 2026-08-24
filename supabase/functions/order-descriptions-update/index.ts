import { body, protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";
import { canManageCompany, isSuperAdmin } from "../_shared/session.ts";
import { isUuid } from "../_shared/validation.ts";

Deno.serve((request) =>
  protectedEndpoint(request, "PATCH", async ({ admin, session }) => {
    if (!isSuperAdmin(session) && session.role !== "admin") {
      return error("forbidden", 403);
    }
    const payload = await body(request);
    if (!payload || !isUuid(payload.id)) return error("invalid_request", 400);
    const { data: current, error: findError } = await admin.from(
      "pedido_descripciones",
    ).select("empresa_id").eq("id", payload.id).maybeSingle();
    if (findError) return error("internal_error", 500);
    if (!current) return error("not_found", 404);
    if (!canManageCompany(session, current.empresa_id)) {
      return error("forbidden", 403);
    }
    const update: Record<string, unknown> = {
      updated_at: new Date().toISOString(),
    };
    if (typeof payload.nombre === "string" && payload.nombre.trim()) {
      update.nombre = payload.nombre.trim();
    }
    if (typeof payload.activo === "boolean") update.activo = payload.activo;
    const { data, error: updateError } = await admin.from(
      "pedido_descripciones",
    ).update(update).eq("id", payload.id).select().single();
    if (updateError?.code === "23505") return error("conflict", 409);
    if (updateError || !data) return error("internal_error", 500);
    return json({ description: data });
  })
);
