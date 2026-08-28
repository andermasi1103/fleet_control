import { body, protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";

const isPlatform = (value: unknown): value is "android" | "web" =>
  value === "android" || value === "web";

Deno.serve((request) =>
  protectedEndpoint(request, "POST", async ({ admin, session }) => {
    const payload = await body(request);
    const token = typeof payload?.token === "string"
      ? payload.token.trim()
      : "";
    const platform = payload?.platform;
    const deviceId =
      typeof payload?.device_id === "string" && payload.device_id.trim()
        ? payload.device_id.trim().slice(0, 255)
        : null;
    if (!token || token.length > 4096 || !isPlatform(platform)) {
      return error("invalid_request", 400);
    }
    const now = new Date().toISOString();
    const { error: upsertError } = await admin.from("notification_devices")
      .upsert({
        usuario_id: session.userId,
        token,
        platform,
        device_id: deviceId,
        activo: true,
        last_seen_at: now,
        updated_at: now,
      }, { onConflict: "token" });
    return upsertError ? error("internal_error", 500) : json({ success: true });
  })
);
