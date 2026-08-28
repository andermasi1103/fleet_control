# Roles y privilegios de producción

`create_roles.sql` prepara dos roles sin contraseña embebida:

- `fleet_owner`: sin login; se reserva para migraciones y ownership.
- `fleet_app`: login restringido para el proceso Fastify.

Ejecute el script manualmente con el propietario actual de `fleet_control_db`,
después defina la contraseña de `fleet_app` mediante un gestor de secretos o
una sesión administrativa interactiva. No ejecute DDL desde el arranque de
Fastify.

## Procedimiento local

1. Como propietario de la base, ejecute `create_roles.sql` en
   `fleet_control_db`. El script no contiene ni modifica contraseñas.
2. Defina la contraseña del runtime fuera del repositorio. La opción preferida
   es abrir `psql` como administrador y ejecutar `\password fleet_app`. Si se
   necesita SQL explícito, use únicamente un valor que el operador provea:

   ```sql
   ALTER ROLE fleet_app WITH PASSWORD 'TU_PASSWORD_FLEET_APP';
   ```

3. Guarde esa contraseña sólo en el gestor de secretos o en `backend/.env`
   local, junto con `DATABASE_USER=fleet_app`. Nunca la copie a
   `.env.example`, SQL, documentación ni Git.
4. Ejecute `pnpm run db:check` y las pruebas de backend con `fleet_app`.

La credencial que estuvo expuesta era una contraseña de conexión PostgreSQL
(`DATABASE_PASSWORD`). Si correspondía a un rol todavía activo, rótela de
forma interactiva para ese rol y actualice únicamente el secreto local o el
gestor de secretos:

```sql
ALTER ROLE <ROL_ASOCIADO_A_LA_CREDENCIAL_EXPUESTA>
  WITH PASSWORD 'TU_PASSWORD_NUEVA';
```

Valide en este orden: backup, roles/grants, migraciones asumiendo
`fleet_owner`, `pnpm run db:check` usando `fleet_app`, pruebas de
autenticación y operaciones. `fleet_owner` no tiene login: para el comando de
migración use una identidad operativa separada, no usada por Fastify, que esté
autorizada a ejecutar `SET ROLE fleet_owner`. No conceda esa membresía a
`fleet_app`.
El script transfiere los owners de las funciones `SECURITY DEFINER` listadas a
`fleet_owner` y también los objetos existentes del esquema `public`, para que
las migraciones puedan modificar su propio esquema. Debe revisarse y ejecutarse
durante una ventana de mantenimiento. La transferencia de ownership de la base
completa queda fuera del script y se programa por separado.

## RLS del runtime Fastify

Si las tablas locales conservan RLS de la migración anterior, ejecute también
`fleet_app_rls.sql` con la identidad de migración que asume `fleet_owner`. El
script crea políticas sólo para `SELECT`, `INSERT` y `UPDATE` que ya fueron
otorgados a `fleet_app`, y agrega el `SELECT` mínimo de
`chofer_ubicaciones` necesario para mapa y reportes. No desactiva RLS ni da
privilegios de base, schema o DDL al runtime.

Con las mismas variables locales efímeras de `UAT_MIGRATOR_*`, puede aplicarse
sin poner una contraseña en el comando mediante `pnpm run security:apply-rls`
desde `backend`.
