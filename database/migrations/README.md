# Migraciones de PostgreSQL

Este directorio registra los cambios de esquema de `fleet_control_db` que se
aplican directamente a PostgreSQL y son consumidos exclusivamente por Fastify;
Flutter nunca accede a las tablas.

## Estado del baseline

`000_initial_schema.sql` reconstruye el estado estructural inmediatamente
anterior a `001_notifications.sql`, contrastando el dump local `schema-only`
con las migraciones, el backend y los scripts históricos. No es un snapshot
final: excluye los objetos creados o modificados después por `001`--`004`.
El inventario, la clasificación y el grafo estático están en
[BASELINE_STATUS.md](BASELINE_STATUS.md).

`database/security/create_roles.sql` y
`database/bootstrap/create_extensions.sql` son prerrequisitos operativos
separados del historial de migraciones. El baseline asume que
`pgcrypto` ya está disponible en `public` y que el runner ya asumió
`fleet_owner`; no debe crear roles ni extensiones.

El rol de aplicación `fleet_app` recibe sólo los privilegios que exigen las
rutas de Fastify. Las políticas RLS se aplican por separado desde
`database/security/fleet_app_rls.sql` una vez que las tablas existen.

## Registro y transacciones

`backend/scripts/migrate.ts` verifica el SHA-256 de cada archivo y registra su
nombre en `public.schema_migrations`. Inserta ese registro antes del SQL del
archivo, dentro de la misma transacción iniciada por el runner. La tabla tiene
`name text primary key`, `checksum text not null` y `applied_at timestamptz not
null default now()`.

Las cuatro migraciones históricas actuales contienen un `BEGIN` inicial y un
`COMMIT` final. El runner conserva el SHA-256 del archivo fuente, pero elimina
esa única envoltura exterior antes de ejecutarlo. Así `001`--`004` mantienen
sus checksums registrados, mientras que el runner conserva la única
transacción que abarca DDL y registro.

El runner rechaza cualquier `BEGIN`, `COMMIT` o `ROLLBACK` que permanezca
después de esa normalización, antes de insertar el ledger. Las nuevas
migraciones no deben incluir control transaccional. Esta regla se validó contra
una migración temporal que intentaba confirmar DDL antes de fallar: no dejó ni
la tabla ni una entrada en `schema_migrations`.
