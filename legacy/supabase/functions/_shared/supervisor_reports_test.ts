function assert(condition: unknown): asserts condition {
  if (!condition) throw Error("Assertion failed");
}

Deno.test("la migración protege la relación supervisor-chofer", async () => {
  const sql = await Deno.readTextFile(
    "supabase/migrations/20260824174109_supervisor_driver_assignments.sql",
  );
  assert(sql.includes("supervisor_choferes_unique"));
  assert(sql.includes("enable row level security"));
  assert(sql.includes("invalid_driver_assignment"));
});

Deno.test("reports-data conserva restricciones de supervisor", async () => {
  const source = await Deno.readTextFile(
    "supabase/functions/reports-data/index.ts",
  );
  assert(source.includes('type === "locations"'));
  assert(source.includes("return limit(type, [])"));
  assert(source.includes("!assigned.includes(driverId)"));
  assert(source.includes('session.role === "supervisor"'));
});
