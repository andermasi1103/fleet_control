import { body, protectedEndpoint } from '../_shared/http.ts';
import { error, json } from '../_shared/responses.ts';
import { canManageCompany, isSuperAdmin } from '../_shared/session.ts';
import { isUuid, stringValue } from '../_shared/validation.ts';

type DatabaseError = {
  code?: unknown;
  message?: unknown;
  details?: unknown;
  hint?: unknown;
};

function logError(stage: string, failure: unknown): void {
  const databaseError =
    typeof failure === 'object' && failure !== null
      ? (failure as DatabaseError)
      : {};
  console.error(
    JSON.stringify({
      event: 'users-create-error',
      stage,
      errorCode:
        typeof databaseError.code === 'string' ? databaseError.code : null,
      errorMessage:
        typeof databaseError.message === 'string'
          ? databaseError.message
          : failure instanceof Error
          ? failure.message
          : null,
      errorDetails:
        typeof databaseError.details === 'string'
          ? databaseError.details
          : null,
      errorHint:
        typeof databaseError.hint === 'string' ? databaseError.hint : null,
    }),
  );
}

function databaseFailure(stage: string, failure: DatabaseError): Response {
  logError(stage, failure);
  switch (failure.code) {
    case '23505':
      return error('conflict', 409);
    case '23503':
      return error('invalid_reference', 400);
    case '22P02':
      return error('invalid_request', 400);
    default:
      return error('internal_error', 500);
  }
}

Deno.serve((request) =>
  protectedEndpoint(request, 'POST', async ({ admin, session }) => {
    let stage = 'validate_body';
    try {
      if (!isSuperAdmin(session) && session.role !== 'admin') {
        return error('forbidden', 403);
      }

      const payload = await body(request);
      if (!payload || !isUuid(payload.rol_id)) {
        return error('invalid_request', 400);
      }

      const nombre = stringValue(payload.nombre, 160);
      const usuario = stringValue(payload.usuario, 100);
      const password = typeof payload.password === 'string' ? payload.password : '';
      stage = 'validate_company';
      const empresaId =
        payload.empresa_id === null
          ? null
          : isUuid(payload.empresa_id)
          ? payload.empresa_id
          : undefined;
      const activo = payload.activo === undefined ? true : payload.activo;
      if (
        !nombre ||
        !usuario ||
        password.length < 8 ||
        password.length > 1024 ||
        empresaId === undefined ||
        typeof activo !== 'boolean'
      ) {
        return error('invalid_request', 400);
      }

      stage = 'validate_role';
      const { data: role, error: roleError } = await admin
        .from('roles')
        .select('id, codigo')
        .eq('id', payload.rol_id)
        .maybeSingle();
      if (roleError) return databaseFailure(stage, roleError);
      if (!role) return error('not_found', 404);

      stage = 'validate_permissions';
      if (
        (!isSuperAdmin(session) &&
          (!empresaId ||
            !canManageCompany(session, empresaId) ||
            role.codigo === 'super_admin')) ||
        (role.codigo !== 'super_admin' && !empresaId)
      ) {
        return error('forbidden', 403);
      }

      stage = 'validate_company';
      if (empresaId) {
        const { data: company, error: companyError } = await admin
          .from('empresas')
          .select('id')
          .eq('id', empresaId)
          .maybeSingle();
        if (companyError) return databaseFailure(stage, companyError);
        if (!company) return error('not_found', 404);
      }

      stage = 'check_duplicate';
      const { data: existingUser, error: lookupError } = await admin
        .from('usuarios')
        .select('id')
        .ilike('usuario', usuario)
        .maybeSingle();
      if (lookupError) return databaseFailure(stage, lookupError);
      if (existingUser) return error('conflict', 409);

      stage = 'rpc_create_user';
      const { data: id, error: createError } = await admin.rpc(
        'fleet_control_create_usuario',
        {
          p_nombre: nombre,
          p_usuario: usuario,
          p_password: password,
          p_empresa_id: empresaId,
          p_rol_id: payload.rol_id,
          p_activo: activo,
        },
      );
      if (createError) return databaseFailure(stage, createError);
      if (!isUuid(id)) {
        logError(stage, new Error('La RPC no devolvió un UUID válido.'));
        return error('internal_error', 500);
      }

      stage = 'fetch_created_user';
      const { data: createdUser, error: fetchError } = await admin
        .from('usuarios')
        .select('id, nombre, usuario, empresa_id, rol_id, activo, created_at')
        .eq('id', id)
        .single();
      if (fetchError) return databaseFailure(stage, fetchError);
      if (!createdUser) {
        logError(stage, new Error('No se encontró el usuario recién creado.'));
        return error('internal_error', 500);
      }

      stage = 'serialize_response';
      return json({ user: createdUser }, 201);
    } catch (failure) {
      logError(
        stage === 'serialize_response' ? 'serialize_response' : 'unexpected',
        failure,
      );
      return error('internal_error', 500);
    }
  }),
);
