import { body, protectedEndpoint } from '../_shared/http.ts';
import { error, json } from '../_shared/responses.ts';

Deno.serve((request) => protectedEndpoint(request, 'POST', async ({ admin, session }) => {
  const payload = await body(request);
  const currentPassword = typeof payload?.current_password === 'string' ? payload.current_password : '';
  const newPassword = typeof payload?.new_password === 'string' ? payload.new_password : '';
  if (!currentPassword || newPassword.length < 8 || newPassword.length > 1024 || currentPassword === newPassword) return error('invalid_request', 400);
  const { data: valid, error: verifyError } = await admin.rpc('fleet_control_verify_usuario_password', { p_user_id: session.userId, p_password: currentPassword });
  if (verifyError) { console.error(JSON.stringify({ event: 'profile-change-password-error', stage: 'verify_current_password', errorCode: verifyError.code, errorMessage: verifyError.message })); return error('internal_error', 500); }
  if (valid !== true) return error('invalid_current_password', 403);
  const { error: updateError } = await admin.rpc('fleet_control_set_usuario_password', { p_user_id: session.userId, p_password: newPassword });
  if (updateError) { console.error(JSON.stringify({ event: 'profile-change-password-error', stage: 'set_password', errorCode: updateError.code, errorMessage: updateError.message })); return error('internal_error', 500); }
  return json({ success: true });
}));
