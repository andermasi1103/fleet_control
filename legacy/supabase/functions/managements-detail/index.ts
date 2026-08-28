import { protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";
import {
  canReadManagement,
  managementJson,
  readManagement,
} from "../_shared/managements.ts";
import { isUuid } from "../_shared/validation.ts";
Deno.serve((request) =>
  protectedEndpoint(request, "GET", async ({ admin, session, url }) => {
    const id = url.searchParams.get("id");
    if (!id || !isUuid(id)) return error("invalid_request", 400);
    const { data, error: readError } = await readManagement(admin, id);
    if (readError) return error("internal_error", 500);
    if (!data) return error("not_found", 404);
    const row = data as Record<string, unknown>;
    if (
      !canReadManagement(
        session,
        row.empresa_id as string,
        row.chofer_usuario_id as string,
      )
    ) return error("forbidden", 403);
    const { data: events, error: eventError } = await admin.from(
      "gestion_eventos",
    ).select(
      "id,usuario_id,estado_anterior,estado_nuevo,observaciones,created_at",
    ).eq("gestion_id", id).order("created_at");
    if (eventError) return error("internal_error", 500);
    return json({ management: managementJson(row), events: events ?? [] });
  })
);
