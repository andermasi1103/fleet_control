import { body, protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";
import { canManageCompany, isSuperAdmin } from "../_shared/session.ts";
import { isUuid } from "../_shared/validation.ts";

Deno.serve((request) =>
  protectedEndpoint(request, "POST", async ({ admin, session }) => {
    if (!isSuperAdmin(session) && session.role !== "admin") {
      return error("forbidden", 403);
    }
    const payload = await body(request);
    const nombre = typeof payload?.nombre === "string"
      ? payload.nombre.trim()
      : "";
    const empresaId = payload?.empresa_id;
    if (!nombre || !isUuid(empresaId)) return error("invalid_request", 400);
    if (!canManageCompany(session, empresaId)) return error("forbidden", 403);
    const { data, error: insertError } = await admin.from(
      "pedido_descripciones",
    ).insert({ empresa_id: empresaId, nombre }).select().single();
    if (insertError?.code === "23505") return error("conflict", 409);
    if (insertError || !data) return error("internal_error", 500);
    return json({ description: data }, 201);
  })
);
