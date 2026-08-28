import { protectedEndpoint } from "../_shared/http.ts";
import { error, json } from "../_shared/responses.ts";
import { isUuid } from "../_shared/validation.ts";

const activeStatuses = ["asignado", "aceptado", "en_camino", "en_gestion"];

function connectionStatus(capturedAt: unknown): "online" | "stale" | "offline" {
  if (typeof capturedAt !== "string") return "offline";
  const capturedTime = Date.parse(capturedAt);
  if (Number.isNaN(capturedTime)) return "offline";
  const age = Date.now() - capturedTime;
  if (age <= 2 * 60 * 1000) return "online";
  if (age <= 10 * 60 * 1000) return "stale";
  return "offline";
}

Deno.serve((request) =>
  protectedEndpoint(request, "GET", async ({ admin, session, url }) => {
    if (!["super_admin", "admin", "supervisor"].includes(session.role)) {
      return error("forbidden", 403);
    }

    const requestedCompanyId = url.searchParams.get("empresa_id");
    if (requestedCompanyId !== null && !isUuid(requestedCompanyId)) {
      return error("invalid_request", 400);
    }
    let companyId: string | null = requestedCompanyId;
    if (session.role !== "super_admin") {
      if (!session.empresaId) return error("forbidden", 403);
      if (
        requestedCompanyId !== null && requestedCompanyId !== session.empresaId
      ) {
        return error("forbidden", 403);
      }
      companyId = session.empresaId;
    }

    const { data: driverRole, error: roleError } = await admin.from("roles")
      .select("id").eq("codigo", "chofer").maybeSingle();
    if (roleError || !driverRole) return error("internal_error", 500);

    let driversQuery = admin.from("usuarios")
      .select("id,nombre,usuario,empresa_id")
      .eq("rol_id", driverRole.id)
      .eq("activo", true)
      .order("nombre");
    if (companyId) driversQuery = driversQuery.eq("empresa_id", companyId);
    const { data: drivers, error: driversError } = await driversQuery;
    if (driversError) return error("internal_error", 500);
    if (!drivers || drivers.length === 0) return json({ drivers: [] });

    const driverIds = drivers.map((driver) => driver.id);
    const [locationsResult, managementsResult, habitualVehiclesResult] =
      await Promise.all([
        admin.from("chofer_ubicaciones")
          .select(
            "chofer_usuario_id,latitud,longitud,precision_metros,velocidad_mps,rumbo_grados,captured_at",
          )
          .in("chofer_usuario_id", driverIds),
        admin.from("gestiones")
          .select("id,chofer_usuario_id,vehiculo_id,estado")
          .in("chofer_usuario_id", driverIds)
          .in("estado", activeStatuses),
        admin.from("usuario_vehiculos")
          .select("usuario_id,vehiculo_id")
          .in("usuario_id", driverIds),
      ]);
    if (
      locationsResult.error || managementsResult.error ||
      habitualVehiclesResult.error
    ) {
      return error("internal_error", 500);
    }

    const locationsByDriver = new Map(
      (locationsResult.data ?? []).map((location) => [
        location.chofer_usuario_id,
        location,
      ]),
    );
    const managementsByDriver = new Map(
      (managementsResult.data ?? []).map((management) => [
        management.chofer_usuario_id,
        management,
      ]),
    );
    const habitualVehiclesByDriver = new Map(
      (habitualVehiclesResult.data ?? []).map((assignment) => [
        assignment.usuario_id,
        assignment,
      ]),
    );
    const vehicleIds = [
      ...new Set(
        [
          ...(managementsResult.data ?? []),
          ...(habitualVehiclesResult.data ?? []),
        ]
          .map((assignment) => assignment.vehiculo_id)
          .filter((id): id is string => typeof id === "string"),
      ),
    ];
    const { data: vehicles, error: vehiclesError } = vehicleIds.length === 0
      ? { data: [], error: null }
      : await admin.from("vehiculos")
        .select("id,patente,tipo_vehiculo,activo")
        .in("id", vehicleIds);
    if (vehiclesError) return error("internal_error", 500);
    const vehiclesById = new Map(
      (vehicles ?? []).map((vehicle) => [vehicle.id, vehicle]),
    );

    return json({
      drivers: drivers.map((driver) => {
        const location = locationsByDriver.get(driver.id);
        const management = managementsByDriver.get(driver.id);
        const habitualVehicle = habitualVehiclesByDriver.get(driver.id);
        const managementVehicleId = typeof management?.vehiculo_id === "string"
          ? management.vehiculo_id
          : null;
        const habitualVehicleId =
          typeof habitualVehicle?.vehiculo_id === "string"
            ? habitualVehicle.vehiculo_id
            : null;
        const managementVehicle = managementVehicleId
          ? vehiclesById.get(managementVehicleId)
          : null;
        const preferredVehicle = habitualVehicleId
          ? vehiclesById.get(habitualVehicleId)
          : null;
        const vehicle = managementVehicle ??
          (preferredVehicle?.activo === true ? preferredVehicle : null);
        return {
          driver_user_id: driver.id,
          driver_name: driver.nombre,
          driver_username: driver.usuario,
          company_id: driver.empresa_id,
          management_id: management?.id ?? null,
          management_status: management?.estado ?? null,
          vehicle_id: managementVehicleId ??
            (preferredVehicle?.activo === true ? habitualVehicleId : null),
          vehicle_plate: vehicle?.patente ?? null,
          vehicle_type: vehicle?.tipo_vehiculo ?? null,
          latitude: location?.latitud ?? null,
          longitude: location?.longitud ?? null,
          accuracy: location?.precision_metros ?? null,
          speed: location?.velocidad_mps ?? null,
          heading: location?.rumbo_grados ?? null,
          captured_at: location?.captured_at ?? null,
          connection_status: connectionStatus(location?.captured_at),
          operational_status: management?.estado ?? "disponible",
        };
      }),
    });
  })
);
