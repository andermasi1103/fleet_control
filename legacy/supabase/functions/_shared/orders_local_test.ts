import { assertEquals } from "jsr:@std/assert@1";
import { canUseLocation, permittedLocationIds } from "./orders.ts";
import type { FleetSession } from "./session.ts";

const localSession: FleetSession = {
  sessionId: "session",
  userId: "local-user",
  empresaId: "company",
  roleId: "role",
  role: "local",
  usuario: "local",
  nombre: "Local",
};

Deno.test("local sólo obtiene sus locales asignados", async () => {
  const admin = {
    from: () => ({
      select: () => ({
        eq: () =>
          Promise.resolve({ data: [{ local_id: "local-a" }], error: null }),
      }),
    }),
  };

  assertEquals(await permittedLocationIds(admin as never, localSession), [
    "local-a",
  ]);
});

Deno.test("local no puede usar un local no asignado", async () => {
  const admin = {
    from: () => ({
      select: () => ({
        eq: () => ({
          eq: () => ({
            maybeSingle: () => Promise.resolve({ data: null, error: null }),
          }),
        }),
      }),
    }),
  };

  assertEquals(
    await canUseLocation(admin as never, localSession, {
      id: "local-ajeno",
      empresa_id: "company",
    }),
    false,
  );
});

Deno.test("local puede crear pedidos para un local asignado", async () => {
  const admin = {
    from: () => ({
      select: () => ({
        eq: () => ({
          eq: () => ({
            maybeSingle: () =>
              Promise.resolve({ data: { id: "assignment" }, error: null }),
          }),
        }),
      }),
    }),
  };

  assertEquals(
    await canUseLocation(admin as never, localSession, {
      id: "local-a",
      empresa_id: "company",
    }),
    true,
  );
});
