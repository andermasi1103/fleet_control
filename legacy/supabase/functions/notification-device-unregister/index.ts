import { body, protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";

Deno.serve((request) =>
  protectedEndpoint(request, "POST", async ({ admin, session }) => {
    const payload = await body(request);
    const token = typeof payload?.token === "string"
      ? payload.token.trim()
      : "";
    if (!token || token.length > 4096) return error("invalid_request", 400);
    const { error: updateError } = await admin.from("notification_devices")
      .update({ activo: false, updated_at: new Date().toISOString() })
      .eq("usuario_id", session.userId)
      .eq("token", token);
    return updateError ? error("internal_error", 500) : json({ success: true });
  })
);
