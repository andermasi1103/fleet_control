const migration = await Deno.readTextFile(
  new URL(
    "../../migrations/20260824190000_new_order_notifications.sql",
    import.meta.url,
  ),
);
const ordersCreate = await Deno.readTextFile(
  new URL("../orders-create/index.ts", import.meta.url),
);
const { isNewOrderRecipient } = await import("./notifications.ts");

Deno.test("la migración mantiene una notificación lógica por chofer y pedido", () => {
  if (
    !migration.includes("unique (usuario_id, tipo, entity_type, entity_id)")
  ) {
    throw new Error("Falta la clave de idempotencia de new_order");
  }
  if (!migration.includes("notification_devices_token_unique unique (token)")) {
    throw new Error("Falta la unicidad del token de dispositivo");
  }
});

Deno.test("notifica sólo a choferes activos de la empresa, aunque estén ocupados", () => {
  const empresaA = "empresa-a";
  const choferActivo = {
    id: "chofer-a",
    empresa_id: empresaA,
    activo: true,
    roleCode: "chofer",
  };
  // Una gestión activa no participa en el criterio, por diseño.
  if (!isNewOrderRecipient(choferActivo, empresaA)) {
    throw new Error("chofer activo excluido");
  }
  if (
    isNewOrderRecipient({ ...choferActivo, empresa_id: "empresa-b" }, empresaA)
  ) {
    throw new Error("se incluyó otra empresa");
  }
  for (
    const roleCode of ["admin", "supervisor", "local", "user", "super_admin"]
  ) {
    if (isNewOrderRecipient({ ...choferActivo, roleCode }, empresaA)) {
      throw new Error(`se incluyó el rol ${roleCode}`);
    }
  }
  if (isNewOrderRecipient({ ...choferActivo, activo: false }, empresaA)) {
    throw new Error("se incluyó un chofer inactivo");
  }
});

Deno.test("la creación del pedido contiene una entrega best-effort", () => {
  if (!ordersCreate.includes("await notifyNewOrder(admin, order)")) {
    throw new Error(
      "orders-create debe intentar notificar después de crear el pedido",
    );
  }
});
