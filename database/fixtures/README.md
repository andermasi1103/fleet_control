# Fixtures UAT locales

Estos scripts crean exclusivamente datos ficticios con prefijo `UAT` para
validar Fleet Control en una base local vacía. No contienen contraseñas.

El ejecutor compilado recibe `UAT_FIXTURE_PASSWORD` y las variables
`UAT_MIGRATOR_*` sólo desde el entorno local efímero. Los secretos se pasan a
PostgreSQL como parámetros, no como argumentos de comando. Debe ejecutarse con
`fleet_migrator`, que asume `fleet_owner`; Fastify continúa usando solamente
`fleet_app`.

Ejecute primero la semilla, realice la UAT y ejecute siempre la limpieza:

```powershell
$env:UAT_MIGRATOR_HOST = '<HOST_LOCAL>'
$env:UAT_MIGRATOR_DATABASE = 'fleet_control_db'
$env:UAT_MIGRATOR_USER = 'fleet_migrator'
# Defina UAT_MIGRATOR_PASSWORD y UAT_FIXTURE_PASSWORD sólo en esta sesión local.
pnpm run uat:seed
pnpm run uat:cleanup
```

No copie valores de secreto a comandos compartidos, historial, Git ni ningún
archivo. `uat_cleanup.sql` elimina únicamente registros unidos a los
marcadores `UAT Empresa Fleet Control`, `uat_*`, `UAT-LOCAL-FC` y `UAT-FC-001`.
