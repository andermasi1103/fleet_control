import { protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";
import { relatedName } from "../_shared/validation.ts";

Deno.serve((request) =>
  protectedEndpoint(request, "GET", async ({ admin, session }) => {
    if (session.role !== "chofer" || !session.empresaId) {
      return error("forbidden", 403);
    }

    const { data, error: queryError } = await admin.from("pedidos").select(
      "id,destino,destino_latitud,destino_longitud,factura_solicitud,numero_contacto,prioridad,observaciones,created_at,locales(nombre),pedido_descripciones(nombre),gestiones!left(id)",
    ).eq("empresa_id", session.empresaId).eq("estado", "pendiente").is(
      "gestiones.id",
      null,
    ).order("created_at", { ascending: false });

    if (queryError) return error("internal_error", 500);

    return json({
      orders: (data ?? []).map((row: Record<string, unknown>) => ({
        order_id: row.id,
        local: relatedName(row.locales),
        descripcion: relatedName(row.pedido_descripciones),
        destino: row.destino,
        destino_latitud: row.destino_latitud,
        destino_longitud: row.destino_longitud,
        factura_solicitud: row.factura_solicitud,
        numero_contacto: row.numero_contacto,
        prioridad: row.prioridad,
        observaciones: row.observaciones,
        created_at: row.created_at,
      })),
    });
  })
);
