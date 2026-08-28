import type { SupabaseClient } from "@supabase/supabase-js";

type FirebaseServiceAccount = {
  client_email: string;
  private_key: string;
  project_id: string;
  token_uri?: string;
};

type NewOrder = { id: string; empresa_id: string; local_id: string };
export type NewOrderRecipient = {
  id: string;
  empresa_id: string | null;
  activo: boolean;
  roleCode: string | null;
};

const encoder = new TextEncoder();

export function isNewOrderRecipient(
  candidate: NewOrderRecipient,
  empresaId: string,
): boolean {
  return candidate.empresa_id === empresaId && candidate.activo === true &&
    candidate.roleCode === "chofer";
}

function roleCode(value: unknown): string | null {
  if (Array.isArray(value)) return roleCode(value[0]);
  if (typeof value !== "object" || value === null) return null;
  const code = (value as Record<string, unknown>).codigo;
  return typeof code === "string" ? code : null;
}

function base64Url(value: Uint8Array | string): string {
  const bytes = typeof value === "string" ? encoder.encode(value) : value;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replaceAll(
    "=",
    "",
  );
}

function parseFirebaseServiceAccount(): FirebaseServiceAccount | null {
  const raw = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!raw) return null;
  try {
    const value: unknown = JSON.parse(raw);
    if (typeof value !== "object" || value === null) return null;
    const account = value as Record<string, unknown>;
    if (
      typeof account.client_email !== "string" ||
      typeof account.private_key !== "string" ||
      typeof account.project_id !== "string"
    ) return null;
    return {
      client_email: account.client_email,
      private_key: account.private_key,
      project_id: account.project_id,
      token_uri: typeof account.token_uri === "string"
        ? account.token_uri
        : undefined,
    };
  } catch {
    return null;
  }
}

function pemBytes(pem: string): ArrayBuffer {
  const base64 = pem.replace(
    /-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g,
    "",
  );
  const binary = atob(base64);
  const buffer = new ArrayBuffer(binary.length);
  const bytes = new Uint8Array(buffer);
  for (let index = 0; index < binary.length; index++) {
    bytes[index] = binary.charCodeAt(index);
  }
  return buffer;
}

async function firebaseAccessToken(
  account: FirebaseServiceAccount,
): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const assertionHeader = base64Url(
    JSON.stringify({ alg: "RS256", typ: "JWT" }),
  );
  const assertionPayload = base64Url(JSON.stringify({
    iss: account.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: account.token_uri ?? "https://oauth2.googleapis.com/token",
    iat: now,
    exp: now + 3600,
  }));
  const signingInput = `${assertionHeader}.${assertionPayload}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    pemBytes(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    encoder.encode(signingInput),
  );
  const form = new URLSearchParams({
    grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
    assertion: `${signingInput}.${base64Url(new Uint8Array(signature))}`,
  });
  const response = await fetch(
    account.token_uri ?? "https://oauth2.googleapis.com/token",
    {
      method: "POST",
      headers: { "Content-Type": "application/x-www-form-urlencoded" },
      body: form,
    },
  );
  if (!response.ok) throw new Error("firebase_oauth_failed");
  const data: unknown = await response.json();
  if (
    typeof data !== "object" || data === null ||
    typeof (data as Record<string, unknown>).access_token !== "string"
  ) {
    throw new Error("firebase_oauth_invalid_response");
  }
  return (data as Record<string, string>).access_token;
}

function isInvalidFcmResponse(value: unknown): boolean {
  if (typeof value !== "object" || value === null) return false;
  const error = (value as Record<string, unknown>).error;
  if (typeof error !== "object" || error === null) return false;
  const status = (error as Record<string, unknown>).status;
  return status === "UNREGISTERED" || status === "INVALID_ARGUMENT";
}

export async function notifyNewOrder(
  admin: SupabaseClient,
  order: NewOrder,
): Promise<void> {
  try {
    const { data: drivers, error: driversError } = await admin
      .from("usuarios")
      .select("id, empresa_id, activo, roles!inner(codigo)")
      .eq("empresa_id", order.empresa_id)
      .eq("activo", true)
      .eq("roles.codigo", "chofer");
    if (driversError) throw driversError;
    const driverIds = (drivers ?? []).flatMap(
      (driver: Record<string, unknown>) => {
        const id = driver.id;
        if (typeof id !== "string") return [];
        return isNewOrderRecipient({
            id,
            empresa_id: typeof driver.empresa_id === "string"
              ? driver.empresa_id
              : null,
            activo: driver.activo === true,
            roleCode: roleCode(driver.roles),
          }, order.empresa_id)
          ? [id]
          : [];
      },
    );
    if (driverIds.length === 0) {
      console.info(`new_order_notification order=${order.id} recipients=0`);
      return;
    }

    const { data: local, error: localError } = await admin.from("locales")
      .select("nombre")
      .eq("id", order.local_id)
      .maybeSingle();
    if (localError) throw localError;
    const localName =
      local && typeof local.nombre === "string" && local.nombre.trim()
        ? local.nombre.trim()
        : null;
    const title = "Nuevo pedido disponible";
    const message = localName
      ? `${localName} lanzó un nuevo pedido.`
      : "Hay un nuevo pedido disponible.";
    const rows = driverIds.map((usuario_id) => ({
      usuario_id,
      tipo: "new_order",
      titulo: title,
      mensaje: message,
      entity_type: "order",
      entity_id: order.id,
      ruta: "/driver-orders",
    }));
    const { data: created, error: createError } = await admin
      .from("notificaciones")
      .upsert(rows, {
        onConflict: "usuario_id,tipo,entity_type,entity_id",
        ignoreDuplicates: true,
      })
      .select("usuario_id");
    if (createError) throw createError;
    const createdUserIds = (created ?? [])
      .map((row: Record<string, unknown>) => row.usuario_id)
      .filter((id): id is string => typeof id === "string");
    if (createdUserIds.length === 0) {
      console.info(
        `new_order_notification order=${order.id} recipients=${driverIds.length} created=0`,
      );
      return;
    }

    const { data: devices, error: devicesError } = await admin
      .from("notification_devices")
      .select("id, token")
      .in("usuario_id", createdUserIds)
      .eq("activo", true);
    if (devicesError) throw devicesError;
    const activeDevices = (devices ?? []).filter((
      device: Record<string, unknown>,
    ) =>
      typeof device.id === "string" && typeof device.token === "string" &&
      device.token.length > 0
    ) as Array<{ id: string; token: string }>;
    const account = parseFirebaseServiceAccount();
    if (!account) {
      console.info(
        `new_order_notification order=${order.id} recipients=${driverIds.length} created=${createdUserIds.length} push=skipped_no_firebase_config`,
      );
      return;
    }
    const accessToken = await firebaseAccessToken(account);
    let successful = 0;
    let failed = 0;
    const invalidDeviceIds: string[] = [];
    await Promise.all(activeDevices.map(async (device) => {
      try {
        const response = await fetch(
          `https://fcm.googleapis.com/v1/projects/${
            encodeURIComponent(account.project_id)
          }/messages:send`,
          {
            method: "POST",
            headers: {
              Authorization: `Bearer ${accessToken}`,
              "Content-Type": "application/json",
            },
            body: JSON.stringify({
              message: {
                token: device.token,
                notification: { title, body: message },
                data: {
                  type: "new_order",
                  order_id: order.id,
                  route: "/driver-orders",
                },
                android: { priority: "high" },
                webpush: {
                  headers: { Urgency: "high" },
                  fcm_options: { link: "/driver-orders" },
                },
              },
            }),
          },
        );
        if (response.ok) {
          successful += 1;
          return;
        }
        failed += 1;
        if (isInvalidFcmResponse(await response.json().catch(() => null))) {
          invalidDeviceIds.push(device.id);
        }
      } catch {
        failed += 1;
      }
    }));
    if (invalidDeviceIds.length > 0) {
      await admin.from("notification_devices").update({
        activo: false,
        updated_at: new Date().toISOString(),
      }).in("id", invalidDeviceIds);
    }
    console.info(
      `new_order_notification order=${order.id} recipients=${driverIds.length} created=${createdUserIds.length} push_ok=${successful} push_failed=${failed} invalid_tokens=${invalidDeviceIds.length}`,
    );
  } catch {
    // Delivery is explicitly best-effort: an order must never be rolled back.
    console.error(`new_order_notification_failed order=${order.id}`);
  }
}
