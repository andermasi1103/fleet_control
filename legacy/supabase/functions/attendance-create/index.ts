import { body, protectedEndpoint } from '../_shared/http.ts';
import { error, json } from '../_shared/responses.ts';
import { canReadCompany } from '../_shared/session.ts';
import { haversineMeters, isUuid, numberValue } from '../_shared/validation.ts';

Deno.serve((request) => protectedEndpoint(request, 'POST', async ({ admin, session }) => {
  const payload = await body(request);
  if (!payload || !isUuid(payload.local_id) || 'dentro_geocerca' in payload) return error('invalid_request', 400);
  const latitud = numberValue(payload.latitud, -90, 90); const longitud = numberValue(payload.longitud, -180, 180);
  if (latitud === null || longitud === null) return error('invalid_request', 400);
  const { data: location, error: locationError } = await admin.from('locales')
    .select('id, empresa_id, nombre, latitud, longitud, radio_metros, activo').eq('id', payload.local_id).maybeSingle();
  if (locationError) return error('internal_error', 500);
  if (!location) return error('not_found', 404);
  if (location.activo !== true || !canReadCompany(session, location.empresa_id) || (session.empresaId !== null && session.empresaId !== location.empresa_id)) return error('forbidden', 403);
  const distance = haversineMeters(latitud, longitud, location.latitud, location.longitud);
  const within = distance <= location.radio_metros;
  if (!within) return json({ error: 'outside_geofence', distancia_metros: Math.round(distance), dentro_geocerca: false }, 422);
  const { data: latest, error: latestError } = await admin.from('asistencias').select('tipo, fecha_hora')
    .eq('usuario_id', session.userId).order('fecha_hora', { ascending: false }).limit(1).maybeSingle();
  if (latestError) return error('internal_error', 500);
  const tipo = latest?.tipo === 'entrada' ? 'salida' : 'entrada';
  const { data: attendance, error: insertError } = await admin.from('asistencias').insert({
    usuario_id: session.userId, empresa_id: location.empresa_id, local_id: location.id, tipo,
    latitud, longitud, dentro_geocerca: true,
  }).select('id, usuario_id, empresa_id, local_id, tipo, fecha_hora, latitud, longitud, dentro_geocerca').single();
  return insertError || !attendance ? error('internal_error', 500) : json({ attendance, distancia_metros: Math.round(distance), dentro_geocerca: true }, 201);
}));
