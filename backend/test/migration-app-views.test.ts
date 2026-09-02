import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import test from 'node:test';

const migrationPath = resolve(process.cwd(), '../database/migrations/006_seed_app_views_and_role_views.sql');
const appViewCodesPath = resolve(process.cwd(), '../lib/features/role_views/app_view_code.dart');

const expectedViews = [
  ['home', 'Inicio', 'Pantalla principal de Fleet Control.', '/home', 'home', 10, true],
  ['attendance', 'Asistencia', 'Marcación e historial de asistencia.', '/attendance', 'fingerprint', 20, true],
  ['companies', 'Empresas', 'Administración de empresas.', '/companies', 'business', 30, true],
  ['locations', 'Locales', 'Administración de locales.', '/locations', 'location_on', 40, true],
  ['users', 'Usuarios', 'Administración de usuarios.', '/users', 'people', 50, true],
  ['vehicles', 'Vehículos', 'Administración de vehículos.', '/vehicles', 'local_shipping', 60, true],
  ['orders', 'Pedidos', 'Gestión de pedidos.', '/orders', 'receipt_long', 70, true],
  ['driver_orders', 'Pedidos disponibles', 'Pedidos que puede tomar un chofer.', '/driver-orders', 'assignment_turned_in', 80, true],
  ['managements', 'Gestiones', 'Seguimiento de gestiones.', '/managements', 'assignment', 90, true],
  ['fleet_map', 'Mapa de Flota', 'Ubicación de la flota.', '/fleet-map', 'map', 100, true],
  ['settings', 'Configuración', 'Configuración y perfil.', '/settings', 'settings', 110, true],
  ['role_views_management', 'Roles y vistas', 'Configuración de vistas disponibles por rol.', '/settings/role-views', 'admin_panel_settings', 120, true],
  ['reports', 'Reportes', 'Reportes operativos descargables.', '/reports', 'assessment', 130, true]
];

test('006 seeds the Flutter app-view catalog and every role-view pair without updates', async () => {
  const [sql, appViewCodes] = await Promise.all([
    readFile(migrationPath, 'utf8'),
    readFile(appViewCodesPath, 'utf8')
  ]);
  const rows = [...sql.matchAll(
    /\('([^']+)', '([^']+)', '([^']+)', '([^']+)', '([^']+)', (\d+), (true|false)\)/g
  )].map((match) => [
    match[1],
    match[2],
    match[3],
    match[4],
    match[5],
    Number(match[6]),
    match[7] === 'true'
  ]);
  const flutterCodes = [...appViewCodes.matchAll(/\w+\('([^']+)'\)/g)].map((match) => match[1]);

  assert.deepEqual(rows, expectedViews);
  assert.deepEqual(flutterCodes, expectedViews.map(([codigo]) => codigo));
  assert.equal(new Set(rows.map(([codigo]) => codigo)).size, 13);
  assert.equal(6 * rows.length, 78);
  assert.match(sql, /ON CONFLICT\s*\(codigo\)\s*DO NOTHING\s*;/i);
  assert.match(sql, /CROSS JOIN public\.app_views/i);
  assert.match(sql, /ON CONFLICT\s*\(role_id, view_id\)\s*DO NOTHING\s*;/i);
  assert.doesNotMatch(sql, /\bUPDATE\b/i);
});
