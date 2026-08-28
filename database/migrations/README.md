# Migraciones de PostgreSQL

Este directorio es la fuente de verdad para los cambios de esquema de
`fleet_control_db`. Las migraciones se aplican directamente a PostgreSQL y son
consumidas exclusivamente por Fastify; Flutter nunca accede a las tablas.

El rol de aplicación `fleet_app`, cuando se habilite, debe recibir sólo los
privilegios mínimos que requieran las rutas del backend (por ejemplo, `SELECT`,
`INSERT` y `UPDATE` en las tablas necesarias).
