import { createPrivateKey, createSign } from 'node:crypto';

import type { Database } from '../auth/auth.types.js';
import { env } from '../config/env.js';

type Row = Record<string, unknown>;
export type FirebaseServiceAccount = { client_email: string; private_key: string; project_id: string; token_uri?: string };
type NewOrder = { id: string; empresa_id: string; local_id: string };
type Device = { id: string; token: string };
type PushMessage = { title: string; body: string; data: { type: string; order_id: string; route: string }; androidChannelId: 'masitrack_orders' };
export type FcmTransport = (device: Device, message: PushMessage, account: FirebaseServiceAccount) => Promise<{ accepted: boolean; invalidToken: boolean; firebaseStatus?: number }>;
let cachedAccessToken: { accountId: string; value: string; expiresAt: number } | null = null;

function accountFromEnv(): FirebaseServiceAccount | null {
  if (!env.FIREBASE_SERVICE_ACCOUNT_JSON) return null;
  try {
    const value: unknown = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON);
    if (!value || typeof value !== 'object') return null;
    const account = value as Record<string, unknown>;
    if (typeof account.client_email !== 'string' || typeof account.private_key !== 'string' || typeof account.project_id !== 'string') return null;
    return { client_email: account.client_email, private_key: account.private_key, project_id: account.project_id, token_uri: typeof account.token_uri === 'string' ? account.token_uri : undefined };
  } catch { return null; }
}

function base64Url(value: string) { return Buffer.from(value).toString('base64url'); }

async function accessToken(account: FirebaseServiceAccount): Promise<string> {
  const accountId = `${account.project_id}:${account.client_email}`;
  if (cachedAccessToken?.accountId === accountId && cachedAccessToken.expiresAt > Date.now() + 60_000) {
    return cachedAccessToken.value;
  }

  const now = Math.floor(Date.now() / 1000);
  const input = `${base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))}.${base64Url(JSON.stringify({ iss: account.client_email, scope: 'https://www.googleapis.com/auth/firebase.messaging', aud: account.token_uri ?? 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3600 }))}`;
  const signer = createSign('RSA-SHA256'); signer.update(input); signer.end();
  const assertion = `${input}.${signer.sign(createPrivateKey(account.private_key)).toString('base64url')}`;
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), env.FIREBASE_HTTP_TIMEOUT_MS);
  let response: Response;
  try {
    response = await fetch(account.token_uri ?? 'https://oauth2.googleapis.com/token', { method: 'POST', headers: { 'Content-Type': 'application/x-www-form-urlencoded' }, body: new URLSearchParams({ grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer', assertion }), signal: controller.signal });
  } finally {
    clearTimeout(timeout);
  }
  if (!response.ok) throw new Error('firebase_oauth_failed');
  const body: unknown = await response.json();
  if (!body || typeof body !== 'object' || typeof (body as Row).access_token !== 'string') throw new Error('firebase_oauth_invalid_response');
  const token = (body as { access_token: string; expires_in?: unknown }).access_token;
  const expiresIn = typeof (body as Row).expires_in === 'number' ? (body as { expires_in: number }).expires_in : 3600;
  cachedAccessToken = { accountId, value: token, expiresAt: Date.now() + Math.max(60, expiresIn) * 1000 };
  return token;
}

function invalidRegistration(status: number, payload: unknown): boolean {
  if (!payload || typeof payload !== 'object') return false;
  const error = (payload as Row).error;
  if (!error || typeof error !== 'object') return false;
  const detail = error as Row;
  if (detail.status === 'UNREGISTERED') return true;
  if (detail.status !== 'INVALID_ARGUMENT') return false;
  const message = typeof detail.message === 'string' ? detail.message.toLowerCase() : '';
  return message.includes('registration token') || message.includes('registration');
}

const httpV1Transport: FcmTransport = async (device, message, account) => {
  const token = await accessToken(account);
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), env.FIREBASE_HTTP_TIMEOUT_MS);
  let response: Response;
  try {
    response = await fetch(`https://fcm.googleapis.com/v1/projects/${encodeURIComponent(account.project_id)}/messages:send`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json; charset=UTF-8' },
      body: JSON.stringify({ message: { token: device.token, notification: { title: message.title, body: message.body }, data: message.data, android: { priority: 'high', notification: { channel_id: message.androidChannelId } }, webpush: { headers: { Urgency: 'high' }, fcm_options: { link: '/driver-orders' } } } }),
      signal: controller.signal
    });
  } finally {
    clearTimeout(timeout);
  }
  console.info('push: firebase status=%d', response.status);
  if (response.ok) return { accepted: true, invalidToken: false, firebaseStatus: response.status };
  return { accepted: false, invalidToken: invalidRegistration(response.status, await response.json().catch(() => null)), firebaseStatus: response.status };
};

export async function notifyNewOrder(database: Database, order: NewOrder, options: { transport?: FcmTransport; account?: FirebaseServiceAccount | null } = {}): Promise<void> {
  try {
    const drivers = await database.query<Row>(`SELECT u.id FROM public.usuario_locales ul JOIN public.usuarios u ON u.id=ul.usuario_id JOIN public.roles r ON r.id=u.rol_id JOIN public.locales l ON l.id=ul.local_id WHERE ul.local_id=$1::uuid AND u.empresa_id=$2::uuid AND l.empresa_id=$2::uuid AND u.activo=true AND r.codigo='chofer'`, [order.local_id, order.empresa_id]);
    const driverIds = drivers.rows.map((row) => typeof row.id === 'string' ? row.id : '').filter(Boolean);
    console.info('push: eligibleRecipients=%d', driverIds.length);
    if (!driverIds.length) return;
    const title = 'MasiTrack'; const body = 'Nuevo pedido disponible';
    const created = await database.query<Row>(
      `INSERT INTO public.notificaciones (usuario_id,tipo,titulo,mensaje,entity_type,entity_id,ruta)
       SELECT recipient_id,'new_order',$2::text,$3::text,'pedido',$4::uuid,'/driver-orders'
       FROM unnest($1::uuid[]) AS recipient_id
       ON CONFLICT (usuario_id,entity_id) WHERE tipo='new_order' AND entity_type='pedido' DO NOTHING
       RETURNING usuario_id`,
      [driverIds, title, body, order.id]
    );
    const createdUserIds = created.rows.map((row) => typeof row.usuario_id === 'string' ? row.usuario_id : '').filter(Boolean);
    if (!createdUserIds.length) return;
    const devices = await database.query<Row>('SELECT id,token FROM public.notification_devices WHERE usuario_id=ANY($1::uuid[]) AND activo=true', [createdUserIds]);
    const activeDevices: Device[] = devices.rows.flatMap((row) => typeof row.id === 'string' && typeof row.token === 'string' && row.token ? [{ id: row.id, token: row.token }] : []);
    const account = options.account === undefined ? accountFromEnv() : options.account;
    console.info('push: configured=%s activeDevices=%d', account !== null, activeDevices.length);
    if (!account || !activeDevices.length) {
      console.info('push: attempted=0 accepted=0 rejected=0');
      return;
    }
    const transport = options.transport ?? httpV1Transport;
    const invalidIds: string[] = [];
    let accepted = 0;
    let rejected = 0;
    await Promise.all(activeDevices.map(async (device) => {
      try {
        const result = await transport(device, { title, body, data: { type: 'new_order', order_id: order.id, route: '/driver-orders' }, androidChannelId: 'masitrack_orders' }, account);
        if (result.accepted) accepted += 1;
        else rejected += 1;
        if (result.invalidToken) invalidIds.push(device.id);
      } catch {
        rejected += 1;
      }
    }));
    console.info('push: attempted=%d accepted=%d rejected=%d', activeDevices.length, accepted, rejected);
    if (invalidIds.length) await database.query('UPDATE public.notification_devices SET activo=false,updated_at=now() WHERE id=ANY($1::uuid[])', [invalidIds]);
  } catch (error) {
    // The order and its transaction must never fail because notification delivery fails.
    console.error('push: new order delivery failed', { errorType: error instanceof Error ? error.name : 'unknown' });
  }
}
