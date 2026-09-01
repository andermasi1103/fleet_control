# Roles y privilegios de producción

`create_roles.sql` prepara tres roles sin contraseña embebida:

- `fleet_owner`: sin login; se reserva para migraciones y ownership.
- `fleet_migrator`: login aislado para el runner de migraciones; puede hacer
  `SET ROLE fleet_owner`.
- `fleet_app`: login restringido para el proceso Fastify.

Ejecute el script manualmente con el propietario actual de `fleet_control_db`,
después defina la contraseña de `fleet_app` mediante un gestor de secretos o
una sesión administrativa interactiva. No ejecute DDL desde el arranque de
Fastify.

## Procedimiento local

1. Como credencial inicial propietaria de la base, ejecute `create_roles.sql`.
   El script no contiene ni modifica contraseñas, retira `CREATE` de `PUBLIC`
   sobre `public`, y deja la membresía persistente limitada a
   `fleet_migrator → fleet_owner`.
2. Tras verificar los roles, ejecute
   `../bootstrap/create_extensions.sql` con esa misma credencial. Instala
   `pgcrypto` en `public`; no cree el esquema histórico `extensions`.
3. Defina interactivamente las dos contraseñas: `\password fleet_migrator` y
   `\password fleet_app`. Guárdelas sólo en el gestor de secretos o en el
   entorno local correspondiente; nunca en SQL, documentación o Git.
4. Ejecute `pnpm run db:check` y las pruebas de backend con `fleet_app` sólo
   después de una ventana de migraciones confirmada.

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

`pnpm run db:migrate` acepta únicamente las variables de migración
`MIGRATION_DATABASE_HOST`, `MIGRATION_DATABASE_PORT` (opcional; 5432 por
defecto), `MIGRATION_DATABASE_NAME`, `MIGRATION_DATABASE_USER` y
`MIGRATION_DATABASE_PASSWORD`, `MIGRATION_DATABASE_SSL`,
`MIGRATION_DATABASE_SSL_REJECT_UNAUTHORIZED` y
`MIGRATION_DATABASE_SSL_CA`; el usuario debe ser `fleet_migrator`. No usa
`DATABASE_*` (reservadas para Fastify y `fleet_app`) ni `UAT_MIGRATOR_*`
(reservadas para fixtures y utilidades de seguridad). Provea la contraseña
sólo mediante variables efímeras de terminal o secretos de CI.
El script transfiere a `fleet_owner` los objetos de aplicación existentes de
`public`, excluyendo los miembros de extensiones. También configura los
privilegios por defecto de `fleet_owner`: `PUBLIC` no recibe `EXECUTE` en
funciones, mientras `fleet_app` recibe `SELECT`, `INSERT` y `UPDATE` en tablas
nuevas y los permisos de secuencia necesarios. Las funciones nuevas deben
otorgar `EXECUTE` explícitamente desde su migración. La transferencia de
ownership de la base completa queda fuera del script.

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
