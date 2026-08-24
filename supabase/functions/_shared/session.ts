import type { SupabaseClient } from '@supabase/supabase-js';

export type FleetSession = {
  sessionId: string; userId: string; empresaId: string | null; roleId: string;
  role: string; usuario: string; nombre: string;
};

function tokenFrom(request: Request): string | null {
  const raw = request.headers.get('Authorization');
  if (!raw?.startsWith('Bearer ')) return null;
  const token = raw.slice(7).trim();
  return token ? token : null;
}

async function sha256(value: string): Promise<string> {
  const hash = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(value));
  return Array.from(new Uint8Array(hash)).map((byte) => byte.toString(16).padStart(2, '0')).join('');
}

export async function validateFleetSession(request: Request, admin: SupabaseClient): Promise<FleetSession | null> {
  const token = tokenFrom(request);
  if (!token) return null;
  const hash = await sha256(token);
  const now = new Date().toISOString();
  const { data: session, error: sessionError } = await admin.from('sesiones')
    .select('id, usuario_id').eq('token_hash', hash).is('revoked_at', null).gt('expires_at', now).maybeSingle();
  if (sessionError || !session || typeof session.id !== 'string' || typeof session.usuario_id !== 'string') return null;
  const { data: user, error: userError } = await admin.from('usuarios')
    .select('id, empresa_id, rol_id, usuario, nombre, activo').eq('id', session.usuario_id).maybeSingle();
  if (userError || !user || user.activo !== true || typeof user.rol_id !== 'string' ||
    typeof user.usuario !== 'string' || typeof user.nombre !== 'string') return null;
  const { data: role, error: roleError } = await admin.from('roles').select('codigo').eq('id', user.rol_id).maybeSingle();
  if (roleError || !role || typeof role.codigo !== 'string') return null;
  void admin.from('sesiones').update({ last_used_at: now }).eq('id', session.id).then(() => undefined);
  return { sessionId: session.id, userId: user.id, empresaId: typeof user.empresa_id === 'string' ? user.empresa_id : null,
    roleId: user.rol_id, role: role.codigo, usuario: user.usuario, nombre: user.nombre };
}

export function isSuperAdmin(session: FleetSession): boolean { return session.role === 'super_admin'; }
export function isAdmin(session: FleetSession): boolean { return session.role === 'admin'; }
export function canManageCompany(session: FleetSession, empresaId: string | null): boolean {
  return isSuperAdmin(session) || (isAdmin(session) && session.empresaId !== null && session.empresaId === empresaId);
}

export function canReadCompany(session: FleetSession, empresaId: string | null): boolean {
  return isSuperAdmin(session) || (session.empresaId !== null && session.empresaId === empresaId);
}

export function canManageUserLocations(session: FleetSession, empresaId: string | null): boolean {
  return isSuperAdmin(session) ||
    ((session.role === 'admin' || session.role === 'supervisor') &&
      session.empresaId !== null && session.empresaId === empresaId);
}
