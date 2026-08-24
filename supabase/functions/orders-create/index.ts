import { body, protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";
import {
  canUseLocation,
  orderPriorities,
  permittedLocationIds,
} from "../_shared/orders.ts";
import { isUuid } from "../_shared/validation.ts";

const optionalText = (value: unknown) =>
  typeof value === "string" && value.trim() ? value.trim() : null;
const numberOrNull = (value: unknown) =>
  value == null
    ? null
    : typeof value === "number" && Number.isFinite(value)
    ? value
    : undefined;

Deno.serve((request) =>
  protectedEndpoint(request, "POST", async ({ admin, session }) => {
    const payload = await body(request);
    if (!payload) return error("invalid_request", 400);
    let localId = payload.local_id;
    if (session.role === "local" && !isUuid(localId)) {
      try {
        const locationIds = await permittedLocationIds(admin, session);
        if (locationIds?.length === 1) localId = locationIds[0];
      } catch {
        return error("internal_error", 500);
      }
    }
    if (!isUuid(localId)) return error("invalid_request", 400);
    if (
      payload.descripcion_tipo_id != null &&
      !isUuid(payload.descripcion_tipo_id)
    ) return error("invalid_request", 400);
    const priority = payload.prioridad ?? "normal";
    if (
      typeof priority !== "string" ||
      !orderPriorities.includes(priority as typeof orderPriorities[number])
    ) return error("invalid_request", 400);
    const latitude = numberOrNull(payload.destino_latitud),
      longitude = numberOrNull(payload.destino_longitud);
    if (
      latitude === undefined || longitude === undefined ||
      (latitude == null) !== (longitude == null) ||
      (latitude != null &&
        (latitude < -90 || latitude > 90 || longitude! < -180 ||
          longitude! > 180))
    ) return error("invalid_request", 400);
    const { data: local, error: localError } = await admin.from("locales")
      .select("id, empresa_id, activo").eq("id", localId)
      .maybeSingle();
    if (localError) return error("internal_error", 500);
    if (
      !local || local.activo !== true || typeof local.empresa_id !== "string"
    ) return error("invalid_reference", 400);
    try {
      if (
        !await canUseLocation(admin, session, {
          id: local.id,
          empresa_id: local.empresa_id,
        })
      ) return error("forbidden", 403);
    } catch {
      return error("internal_error", 500);
    }
    if (!isUuid(payload.descripcion_tipo_id)) {
      return error("invalid_reference", 400);
    }
    const { data: description, error: descriptionError } = await admin.from(
      "pedido_descripciones",
    ).select("id").eq("id", payload.descripcion_tipo_id).eq(
      "empresa_id",
      local.empresa_id,
    ).eq("activo", true).maybeSingle();
    if (descriptionError) return error("internal_error", 500);
    if (!description) return error("invalid_reference", 400);
    const { data: order, error: insertError } = await admin.from("pedidos")
      .insert({
        empresa_id: local.empresa_id,
        local_id: local.id,
        creado_por_usuario_id: session.userId,
        descripcion_tipo_id: description.id,
        destino: optionalText(payload.destino),
        destino_latitud: latitude,
        destino_longitud: longitude,
        factura_solicitud: optionalText(payload.factura_solicitud),
        numero_contacto: optionalText(payload.numero_contacto),
        prioridad: priority,
        observaciones: optionalText(payload.observaciones),
      }).select().single();
    if (insertError || !order) return error("internal_error", 500);
    return json({ order }, 201);
  })
);
