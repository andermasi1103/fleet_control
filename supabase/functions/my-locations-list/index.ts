import { protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";
import { relatedName } from "../_shared/validation.ts";

type LocationRow = Record<string, unknown> & { empresas: unknown };

Deno.serve((request) =>
  protectedEndpoint(request, "GET", async ({ admin, session }) => {
    const { data: assignments, error: assignmentError } = await admin
      .from("usuario_locales")
      .select("local_id")
      .eq("usuario_id", session.userId);
    if (assignmentError) return error("internal_error", 500);

    const assignmentRows = (assignments ?? []) as Array<{ local_id: unknown }>;
    const locationIds = assignmentRows
      .map((assignment) => assignment.local_id)
      .filter((id): id is string => typeof id === "string");
    if (locationIds.length === 0) return json({ locations: [] });

    const { data: locations, error: locationError } = await admin
      .from("locales")
      .select(
        "id, empresa_id, codigo, nombre, direccion, latitud, longitud, radio_metros, activo, empresas(nombre)",
      )
      .in("id", locationIds)
      .order("nombre");
    if (locationError) return error("internal_error", 500);

    return json({
      locations: (locations ?? []).map((location: LocationRow) => ({
        ...location,
        empresa_nombre: relatedName(location.empresas),
        empresas: undefined,
      })),
    });
  })
);
