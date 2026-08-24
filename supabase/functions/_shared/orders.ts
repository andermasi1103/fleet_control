import type { SupabaseClient } from "@supabase/supabase-js";
import type { FleetSession } from "./session.ts";
import { isSuperAdmin } from "./session.ts";

export const orderStates = [
  "pendiente",
  "asignado",
  "aceptado",
  "en_camino",
  "en_gestion",
  "completado",
  "cancelado",
] as const;
export const orderPriorities = ["baja", "normal", "urgente"] as const;

export function canAdministerOrders(session: FleetSession): boolean {
  return isSuperAdmin(session) || session.role === "admin" ||
    session.role === "supervisor";
}

export async function permittedLocationIds(
  admin: SupabaseClient,
  session: FleetSession,
): Promise<string[] | null> {
  if (isSuperAdmin(session)) return null;
  if (session.role === "admin" || session.role === "supervisor") return [];
  if (session.role !== "user" && session.role !== "local") return [];
  const { data, error } = await admin.from("usuario_locales").select("local_id")
    .eq("usuario_id", session.userId);
  if (error) throw error;
  return (data ?? []).map((row: { local_id: unknown }) => row.local_id).filter((
    id: unknown,
  ): id is string => typeof id === "string");
}

export async function canUseLocation(
  admin: SupabaseClient,
  session: FleetSession,
  local: { id: string; empresa_id: string },
): Promise<boolean> {
  if (isSuperAdmin(session)) return true;
  if (
    (session.role === "admin" || session.role === "supervisor") &&
    session.empresaId === local.empresa_id
  ) return true;
  if (session.role !== "user" && session.role !== "local") return false;
  const { data, error } = await admin.from("usuario_locales").select("local_id")
    .eq("usuario_id", session.userId).eq("local_id", local.id).maybeSingle();
  if (error) throw error;
  return data != null;
}
