import { body, protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";
import { canManageCompany, isSuperAdmin } from "../_shared/session.ts";
import { isRecord, isUuid } from "../_shared/validation.ts";

const maximumLocations = 500;

type ImportResult = { imported_count?: unknown; errors?: unknown };

Deno.serve((request) =>
  protectedEndpoint(request, "POST", async ({ admin, session }) => {
    if (!isSuperAdmin(session) && session.role !== "admin") {
      return error("forbidden", 403);
    }

    const payload = await body(request);
    const locations = payload?.locations;
    if (!Array.isArray(locations) || locations.length === 0) {
      return error("invalid_request", 400);
    }
    if (locations.length > maximumLocations || !locations.every(isRecord)) {
      return error("invalid_batch_size", 400);
    }

    const requestedCompanyId = payload?.empresa_id;
    const companyId = isSuperAdmin(session)
      ? requestedCompanyId
      : session.empresaId;
    if (!isUuid(companyId) || !canManageCompany(session, companyId)) {
      return error("forbidden", 403);
    }

    const { data: company, error: companyError } = await admin
      .from("empresas")
      .select("id,activo")
      .eq("id", companyId)
      .maybeSingle();
    if (companyError) return error("internal_error", 500);
    if (!company) return error("not_found", 404);
    if (company.activo !== true) return error("forbidden", 403);

    const { data, error: importError } = await admin.rpc(
      "fleet_control_import_locations",
      { p_empresa_id: companyId, p_locations: locations },
    );
    if (importError || !isRecord(data)) return error("internal_error", 500);

    const result = data as ImportResult;
    if (Array.isArray(result.errors)) {
      return json({ errors: result.errors }, 400);
    }
    if (typeof result.imported_count !== "number") {
      return error("internal_error", 500);
    }
    return json({ imported_count: result.imported_count }, 201);
  })
);
