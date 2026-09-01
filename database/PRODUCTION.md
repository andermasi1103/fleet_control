# Operación de producción

La topología recomendada es: Internet → reverse proxy HTTPS → Fastify privado
→ PostgreSQL privado. El proxy debe ser el único componente público; configure
`TRUST_PROXY` con sus IPs o CIDRs explícitos cuando reenvíe la IP del cliente.

PostgreSQL no debe exponerse a Internet. Restrinja el puerto 5432 al backend,
administración controlada y proceso de backup mediante firewall, VPC o red
privada. Active TLS verificado (`DATABASE_SSL=true` y
`DATABASE_SSL_REJECT_UNAUTHORIZED=true`) en producción.

## Cambios de esquema

1. Tome un backup.
2. Ejecute `database/security/create_roles.sql` como administrador y configure
   la contraseña de `fleet_app` fuera del repositorio. En una sesión `psql`
   administrativa use `\password fleet_app` (preferido) o
   `ALTER ROLE fleet_app WITH PASSWORD 'TU_PASSWORD_FLEET_APP';`.
   Si RLS está habilitado en tablas locales, ejecute después
   `database/security/fleet_app_rls.sql` con la misma identidad de migración.
3. Ejecute `pnpm run db:migrate` desde `backend` con una identidad operativa
   de migración, distinta de Fastify, autorizada a asumir `fleet_owner`.
   El runner lee exclusivamente `MIGRATION_DATABASE_HOST`,
   `MIGRATION_DATABASE_PORT` (opcional; 5432 por defecto),
   `MIGRATION_DATABASE_NAME`, `MIGRATION_DATABASE_USER` y
   `MIGRATION_DATABASE_PASSWORD`, `MIGRATION_DATABASE_SSL`,
   `MIGRATION_DATABASE_SSL_REJECT_UNAUTHORIZED` y
   `MIGRATION_DATABASE_SSL_CA`; el usuario debe ser `fleet_migrator`.
   Provea esas credenciales efímeramente desde la terminal o el gestor de
   secretos de CI. Fastify conserva `DATABASE_*` con `fleet_app`; las
   utilidades UAT usan por separado `UAT_MIGRATOR_*`. `fleet_owner` no tiene
   login y no debe asignarse a `fleet_app`.
4. Valide `pnpm run db:check` con `fleet_app`.
5. Reinicie Fastify. El runtime nunca ejecuta DDL automáticamente.

Antes de este procedimiento, rote cualquier contraseña PostgreSQL que haya
estado versionada. Hágalo de forma interactiva sobre el rol afectado y
actualice el secreto local o el gestor de secretos; no lo guarde en archivos
versionados. Fastify debe arrancar con `DATABASE_USER=fleet_app`; `postgres`
queda reservado para administración local controlada.

El script `db:migrate` registra nombre, SHA-256 y fecha en
`public.schema_migrations`; rechaza una migración cuyo checksum ya registrado
haya cambiado. Use `--dry-run` para ver las pendientes.

## Backups y restore

Con las variables `DATABASE_*` configuradas en el entorno, ejecute:

```powershell
.\scripts\backup_database.ps1 -OutputDirectory D:\backups\fleet-control
```

Use formato custom a diario, conserve copias según la política de la empresa,
tome una copia antes de cada migración y pruebe restores periódicamente en una
base aislada. El script de restore exige `-ConfirmRestore` porque borra y
recrea objetos del destino.
