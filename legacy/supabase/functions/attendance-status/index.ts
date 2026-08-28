import { protectedEndpoint } from '../_shared/http.ts';
import { error, json } from '../_shared/responses.ts';

Deno.serve((request) => protectedEndpoint(request, 'GET', async ({ admin, session }) => {
  const { data, error: queryError } = await admin.from('asistencias')
    .select('id, local_id, tipo, fecha_hora, dentro_geocerca').eq('usuario_id', session.userId)
    .order('fecha_hora', { ascending: false }).limit(1).maybeSingle();
  if (queryError) return error('internal_error', 500);
  const open = data?.tipo === 'entrada';
  return json({ next_action: open ? 'salida' : 'entrada', has_open_attendance: open, last_attendance: data ?? null });
}));
