import { protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";
import { isSuperAdmin } from "../_shared/session.ts";
import { isUuid, relatedName } from "../_shared/validation.ts";
Deno.serve((request) =>
  protectedEndpoint(request, "GET", async ({ admin, session, url }) => {
    if (
      !isSuperAdmin(session) && session.role !== "admin" &&
      session.role !== "supervisor"
    ) return error("forbidden", 403);
    const requested = url.searchParams.get("empresa_id");
    if (requested && !isUuid(requested)) return error("invalid_request", 400);
    const company = isSuperAdmin(session) ? requested : session.empresaId;
    if (!company) return error("invalid_request", 400);
    const { data, error: queryError } = await admin.from("usuarios").select(
      "id,nombre,usuario,empresa_id,empresas(nombre),roles!inner(codigo)",
    ).eq("empresa_id", company).eq("activo", true).eq("roles.codigo", "chofer")
      .order("nombre");
    if (queryError) return error("internal_error", 500);
    return json({
      drivers: (data ?? []).map((row: Record<string, unknown>) => ({
        ...row,
        empresa_nombre: relatedName(row.empresas),
        empresas: undefined,
        roles: undefined,
      })),
    });
  })
);
