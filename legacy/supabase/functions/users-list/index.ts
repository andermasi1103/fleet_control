import { protectedEndpoint } from '../_shared/http.ts';
import { error, json } from '../_shared/responses.ts';
import { isSuperAdmin } from '../_shared/session.ts';
import { relatedCode, relatedName } from '../_shared/validation.ts';

type UserListRow = Record<string, unknown> & {
  empresas: unknown;
  roles: unknown;
};

Deno.serve((request) => protectedEndpoint(request, 'GET', async ({ admin, session }) => {
  if (!isSuperAdmin(session) && session.role !== 'admin' && session.role !== 'supervisor') return error('forbidden', 403);
  let query = admin.from('usuarios').select('id, nombre, usuario, empresa_id, rol_id, activo, created_at, empresas(nombre), roles(codigo)').order('nombre');
  if (!isSuperAdmin(session)) { if (!session.empresaId) return error('forbidden', 403); query = query.eq('empresa_id', session.empresaId); }
  const { data, error: queryError } = await query; if (queryError) return error('internal_error', 500);
  return json({ users: (data ?? []).map((user: UserListRow) => ({ ...user, empresa_nombre: relatedName(user.empresas), rol: relatedCode(user.roles), empresas: undefined, roles: undefined })) });
}));
