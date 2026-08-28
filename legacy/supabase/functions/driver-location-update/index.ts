import { body, protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";
import { numberValue } from "../_shared/validation.ts";

function optionalNonNegative(value: unknown): number | null | undefined {
  if (value === undefined || value === null) return null;
  return typeof value === "number" && Number.isFinite(value) && value >= 0
    ? value
    : undefined;
}

function optionalHeading(value: unknown): number | null | undefined {
  if (value === undefined || value === null) return null;
  return typeof value === "number" && Number.isFinite(value) && value >= 0 &&
      value < 360
    ? value
    : undefined;
}

function locationJson(row: Record<string, unknown>) {
  return {
    driver_user_id: row.chofer_usuario_id,
    company_id: row.empresa_id,
    management_id: row.gestion_id,
    vehicle_id: row.vehiculo_id,
    latitude: row.latitud,
    longitude: row.longitud,
    accuracy: row.precision_metros,
    speed: row.velocidad_mps,
    heading: row.rumbo_grados,
    captured_at: row.captured_at,
  };
}

Deno.serve((request) =>
  protectedEndpoint(request, "POST", async ({ admin, session }) => {
    if (session.role !== "chofer") return error("forbidden", 403);

    const payload = await body(request);
    const latitude = numberValue(payload?.latitude, -90, 90);
    const longitude = numberValue(payload?.longitude, -180, 180);
    const accuracy = optionalNonNegative(payload?.accuracy);
    const speed = optionalNonNegative(payload?.speed);
    const heading = optionalHeading(payload?.heading);
    const capturedAt = typeof payload?.captured_at === "string"
      ? new Date(payload.captured_at)
      : null;
    if (
      !payload || latitude === null || longitude === null ||
      accuracy === undefined || speed === undefined || heading === undefined ||
      capturedAt === null || Number.isNaN(capturedAt.getTime())
    ) return error("invalid_request", 400);

    const { data, error: rpcError } = await admin.rpc(
      "fleet_control_update_driver_location",
      {
        p_user_id: session.userId,
        p_latitude: latitude,
        p_longitude: longitude,
        p_accuracy: accuracy,
        p_speed: speed,
        p_heading: heading,
        p_captured_at: capturedAt.toISOString(),
      },
    );
    if (rpcError) {
      if (["invalid_location", "invalid_captured_at"].includes(rpcError.message)) {
        return error(rpcError.message, 400);
      }
      if (rpcError.message === "forbidden") return error("forbidden", 403);
      return error("internal_error", 500);
    }
    const location = Array.isArray(data) ? data[0] : data;
    if (!location || typeof location !== "object") {
      return error("internal_error", 500);
    }

    return json({
      location: locationJson(location as Record<string, unknown>),
    });
  })
);
