import { body, protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";
import { isUuid } from "../_shared/validation.ts";

Deno.serve((request) =>
  protectedEndpoint(request, "POST", async ({ admin, session }) => {
    const payload = await body(request);
    if (!payload || !isUuid(payload.notification_id)) {
      return error("invalid_request", 400);
    }
    const now = new Date().toISOString();
    const { data, error: updateError } = await admin.from("notificaciones")
      .update({ leida: true, read_at: now })
      .eq("id", payload.notification_id)
      .eq("usuario_id", session.userId)
      .select("id")
      .maybeSingle();
    if (updateError) return error("internal_error", 500);
    if (!data) return error("not_found", 404);
    return json({ success: true });
  })
);
