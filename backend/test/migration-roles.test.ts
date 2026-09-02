import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { resolve } from 'node:path';
import test from 'node:test';

const migrationPath = resolve(process.cwd(), '../database/migrations/005_seed_initial_roles.sql');

const expectedRoles = [
  ['user', 'Usuario', 'Usuario operativo estándar', 20, true],
  ['local', 'Local', 'Usuario de sucursal que crea y consulta pedidos de sus locales asignados.', 30, true],
  ['chofer', 'Chofer', 'Usuario operativo de conducción', 40, true],
  ['supervisor', 'Supervisor', 'Responsable de supervisión y operación', 60, true],
  ['admin', 'Administrador', 'Administrador de una empresa', 80, true],
  ['super_admin', 'Super Administrador', 'Administrador global de la plataforma', 100, true]
];

test('005 seeds exactly the mandatory role catalog without updating existing roles', async () => {
  const sql = await readFile(migrationPath, 'utf8');
  const rows = [...sql.matchAll(
    /\('([^']+)', '([^']+)', '([^']+)', (\d+), (true|false)\)/g
  )].map((match) => [
    match[1],
    match[2],
    match[3],
    Number(match[4]),
    match[5] === 'true'
  ]);

  assert.deepEqual(rows, expectedRoles);
  assert.match(sql, /INSERT INTO public\.roles\s*\(codigo, nombre, descripcion, nivel, activo\)/i);
  assert.match(sql, /ON CONFLICT\s*\(codigo\)\s*DO NOTHING\s*;/i);
  assert.doesNotMatch(sql, /\bUPDATE\b/i);
});
