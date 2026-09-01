# Fixtures UAT locales

Estos scripts crean exclusivamente datos ficticios con prefijo `UAT` para
validar MasiTrack en una base local vacía. No contienen contraseñas.

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

## UAT HTTP de presencia

Con Fastify local iniciado, conserve `UAT_FIXTURE_PASSWORD` sólo en la sesión
actual y ejecute desde `backend`:

```powershell
pnpm run uat:presence
```

El runner usa `http://127.0.0.1:3000` por defecto; puede definir
`UAT_API_BASE_URL` para otro endpoint local. No se conecta directamente a
PostgreSQL, no imprime la contraseña ni tokens y no ejecuta cleanup automático.
