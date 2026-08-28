import { protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";
import { isSuperAdmin } from "../_shared/session.ts";
import { isUuid } from "../_shared/validation.ts";

Deno.serve((request) =>
  protectedEndpoint(request, "GET", async ({ admin, session, url }) => {
    const requested = url.searchParams.get("empresa_id");
    if (requested && !isUuid(requested)) return error("invalid_request", 400);
    const empresaId = isSuperAdmin(session) ? requested : session.empresaId;
    if (!empresaId) return error("invalid_request", 400);
    const { data, error: queryError } = await admin.from("pedido_descripciones")
      .select("*").eq("empresa_id", empresaId).order("nombre");
    if (queryError) return error("internal_error", 500);
    return json({ descriptions: data ?? [] });
  })
);
