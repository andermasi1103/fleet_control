import { protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";

Deno.serve((request) =>
  protectedEndpoint(request, "GET", async ({ admin, session, url }) => {
    const requestedLimit = Number(url.searchParams.get("limit") ?? "50");
    const limit = Number.isInteger(requestedLimit) && requestedLimit > 0
      ? Math.min(requestedLimit, 100)
      : 50;
    const { data, error: queryError } = await admin.from("notificaciones")
      .select(
        "id,tipo,titulo,mensaje,entity_type,entity_id,ruta,leida,created_at,read_at",
      )
      .eq("usuario_id", session.userId)
      .order("created_at", { ascending: false })
      .limit(limit);
    if (queryError) return error("internal_error", 500);
    return json({ notifications: data ?? [] });
  })
);
