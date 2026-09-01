# MasiTrack Preproducción

Esta guía prepara un entorno público de preproducción; no crea recursos, no
despliega y no contiene valores secretos. El repositorio técnico sigue siendo
`fleet_control`.

## Estado actual verificado en Render

- PostgreSQL `masitrack-preprod-db` ya existe en Oregon con PostgreSQL 18; la
  base es `masitrack_preprod`.
- El diagnóstico de privilegios dio **GO**: la credencial inicial no es
  superuser, pero permite `CREATE ROLE`, membresías, `SET ROLE` y `ALTER ...
  OWNER` para objetos que posee.
- `CREATE EXTENSION IF NOT EXISTS pgcrypto` fue probado con éxito y se revirtió
  dentro de la prueba; la base sigue limpia.
- El primer intento de bootstrap se revirtió por completo porque el esquema
  heredado `extensions` no existe. El bootstrap corregido posterior sí dejó
  `fleet_owner`, `fleet_migrator` y `fleet_app` con sus atributos y membresías
  validados.
- El comportamiento observado al crear `fleet_owner` concuerda con PostgreSQL
  18: queda un grant implícito del bootstrap superuser con `ADMIN TRUE`,
  `INHERIT FALSE` y `SET FALSE`. El parámetro
  `createrole_self_grant` puede añadir otro grant emitido por la credencial
  creadora. El bootstrap crea un grant temporal separado con sólo `SET TRUE`
  para transferir ownership y fijar default privileges; al terminar revoca los
  grants emitidos por esa credencial. El grant implícito no es revocable por el
  creador y no permite uso runtime de `fleet_owner`. PostgreSQL puede mostrar
  varias filas de membresía, diferenciadas por `grantor`.
- GitHub ya está conectado a Render y pgAdmin tiene su conexión de
  preproducción. La API Web Service todavía no fue creada.

## Arquitectura

```text
Flutter Web / Android -> HTTPS público -> MasiTrack API -> PostgreSQL privado
```

Sólo MasiTrack API conoce la conexión a PostgreSQL. No exponga la base de datos
a Internet, ni incluya sus credenciales, secretos de Firebase o autorización de
Traccar en Flutter.

## Backend en Render

Use el blueprint [`render.yaml`](../render.yaml) como referencia o cree el
servicio manualmente. El servicio es Node nativo, con raíz `backend`, build
`pnpm install --frozen-lockfile && pnpm run build`, start
`node dist/src/server.js` y health check `/ready`.

`PORT` debe dejarse al proveedor cloud. Configure `BACKEND_HOST=0.0.0.0` sólo
en cloud; el desarrollo local continúa en `127.0.0.1:3000`. El build genera
`backend/dist/src/server.js`, que es el archivo de arranque verificado.

No se define `preDeployCommand`: las migraciones requieren una identidad de
migración separada y deben ejecutarse manualmente durante una ventana
controlada. El blueprint deja el auto-deploy apagado.

### Variables de entorno

| Grupo | Variables | Desarrollo | Preproducción |
| --- | --- | --- | --- |
| Runtime | `NODE_ENV`, `PORT`, `BACKEND_HOST`, `API_LOG_LEVEL` | `development`, `3000`, `127.0.0.1`, `info` | `production`, proveedor, `0.0.0.0`, `info` |
| DB runtime | `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_NAME`, `DATABASE_USER`, `DATABASE_PASSWORD` | PostgreSQL local y `fleet_app` | host privado y login de mínimo privilegio validado; no credencial Render gestionada con rol default administrativo |
| TLS runtime | `DATABASE_SSL`, `DATABASE_SSL_REJECT_UNAUTHORIZED`, `DATABASE_SSL_CA` | `false`, `true`, vacía | `true`, `true`, CA del proveedor si corresponde |
| Pool | `PG_POOL_MAX`, `PG_IDLE_TIMEOUT_MS`, `PG_CONNECTION_TIMEOUT_MS`, `PG_STATEMENT_TIMEOUT_MS` | defaults de `.env.example` | mismos valores iniciales, ajustar según el plan de DB |
| CORS/proxy | `CORS_ALLOWED_ORIGINS`, `TRUST_PROXY` | URLs localhost explícitas, `false` | URL HTTPS exacta de Flutter Web, `false` hasta validar IP/CIDR del proxy |
| Integraciones | `FIREBASE_SERVICE_ACCOUNT_JSON`, `TRACCAR_BASE_URL`, `TRACCAR_AUTHORIZATION` | opcionales | secretos sólo en gestor cloud; nunca en dart-defines |
| Migraciones | `MIGRATION_DATABASE_HOST`, `MIGRATION_DATABASE_PORT`, `MIGRATION_DATABASE_NAME`, `MIGRATION_DATABASE_USER`, `MIGRATION_DATABASE_PASSWORD`, `MIGRATION_DATABASE_SSL`, `MIGRATION_DATABASE_SSL_REJECT_UNAUTHORIZED`, `MIGRATION_DATABASE_SSL_CA` | conexión local efímera | conexión privada/TLS, credencial Render gestionada miembro de `fleet_migrator` |

No use `*` en `CORS_ALLOWED_ORIGINS`. Android nativo no depende de CORS; Flutter
Web sí. `TRUST_PROXY=true` está bloqueado intencionalmente: sólo configúrelo
con IPs o CIDRs concretos del proxy tras verificarlos con el proveedor. De lo
contrario, no confíe en encabezados `X-Forwarded-*` de origen no validado.

## PostgreSQL y migraciones

1. La base privada de preproducción ya está creada y el diagnóstico de
   privilegios ya confirmó `CREATE ROLE`, `GRANT`, `ALTER ... OWNER` y
   `SET ROLE` para la credencial inicial de Render.
2. Use la credencial Render gestionada sólo para migraciones, miembro de
   `fleet_migrator` y autorizada a `SET ROLE fleet_owner`. No configure aún
   una credencial Render gestionada para runtime.
3. Sólo en una ventana de migraciones posterior, ejecute desde `backend`
   `pnpm run db:migrate` con exclusivamente `MIGRATION_DATABASE_*`. El runner
   rechaza otro usuario y no usa variables runtime `DATABASE_*`.
   La cadena empieza con `000_initial_schema.sql`, reconstruida desde el dump
   local `schema-only`; después aplica `001`--`004`. Pruebe esa secuencia sólo
   en una base PostgreSQL 18 temporal y aislada antes de una ventana remota.
4. Después de esa ventana, ejecute `pnpm run db:check` con un login runtime de
   mínimo privilegio validado y aplique RLS si corresponde siguiendo
   `database/security/README.md`.

El modelo de tres roles requiere privilegios administrativos que algunos
PostgreSQL administrados restringen. Si el proveedor no permite crear roles u
ownership/`SET ROLE`, no sustituya los roles a ciegas: defina primero una
estrategia compatible con su soporte. El runtime nunca debe ejecutar DDL.

Tome un backup lógico antes de migraciones y pruebe su restore en una base
aislada. Use herramientas compatibles con la versión que ofrezca el proveedor;
la instalación local actual usa PostgreSQL 18. La tabla
`chofer_ubicaciones` recibe actualizaciones de ubicación/presencia y crecerá
de forma continua: defina retención y capacidad antes de producción, sin
activar aún una purga automática.

### Separación de responsabilidades y prueba de compatibilidad

| Rol | Uso | Privilegios requeridos | Prohibiciones |
| --- | --- | --- | --- |
| Credencial inicial de Render | Bootstrap manual solamente | Crear roles, otorgar membresías y transferir ownership si el diagnóstico lo permite | No runtime Fastify ni migraciones normales |
| `fleet_owner` | Propietario sin login de objetos y funciones | `USAGE, CREATE` en `public`, ownership de objetos de aplicación | No login, no uso directo por la API |
| `fleet_migrator` | Rol de autorización de migraciones | `CONNECT` y membresía de `fleet_owner` para `SET ROLE fleet_owner` | No runtime Fastify; tras validar las credenciales Render se convertirá a `NOLOGIN` |
| `fleet_app` | Rol de autorización del runtime | `CONNECT`, `USAGE` en `public`, grants explícitos de tablas/secuencias/funciones | Sin DDL, ownership, `CREATE` en `public` ni membresía de `fleet_owner`; tras validar las credenciales Render se convertirá a `NOLOGIN` |
| Credencial Render de migraciones | Login aislado | Miembro directo de `fleet_migrator` con `INHERIT TRUE, SET TRUE, ADMIN FALSE`; el runner asume explícitamente `fleet_owner` | No runtime Fastify |
| Credencial Render de runtime | **NO-GO por ahora** | Ninguno: el patrón observado la inicia bajo un rol default con membresías adicionales | No crear ni configurar en `DATABASE_*` hasta que Render garantice un perfil inicial mínimo |

El bootstrap es [`database/security/create_roles.sql`](../database/security/create_roles.sql).
No contiene contraseñas. La credencial gestionada de migraciones se guarda sólo
en `MIGRATION_DATABASE_*`; un login runtime sólo se configurará cuando se haya
validado que su perfil inicial es de mínimo privilegio.
El bootstrap crea los tres roles, concede a `fleet_migrator` la membresía de
autorización de `fleet_owner` y usa
`current_database()` para no depender de un nombre de base literal. Usa
`session_user` para el grant temporal porque no cambia al hacer `SET LOCAL
ROLE`. Al finalizar no queda ningún grant emitido por la credencial inicial;
PostgreSQL 18 normalmente conserva sólo su grant implícito (`ADMIN TRUE,
INHERIT FALSE, SET FALSE`), sin acceso runtime.

Al arrancar en producción, Fastify exige que `session_user` sea `fleet_app` o
su miembro directo con `ADMIN FALSE, INHERIT TRUE, SET FALSE`; también exige
que `current_user = session_user`, que no pueda asumir `fleet_owner` y que no
tenga ninguna otra membresía directa con `SET TRUE`. Por tanto una credencial
bootstrap, de migraciones o gestionada por Render con rol default inyectado
impide el arranque antes de atender tráfico.

Antes de aplicarlo en un proveedor gestionado ejecute manualmente
[`database/bootstrap/render-privileges-diagnostic.sql`](../database/bootstrap/render-privileges-diagnostic.sql).
El script usa una transacción y `ROLLBACK`: comprueba identidad, atributos del
rol actual, `CREATE ROLE`, membresía, `SET ROLE`, transferencia de owner de una
tabla temporal y extensiones instaladas, sin dejar roles ni datos permanentes.
También muestra `createrole_self_grant` e informa cada grant del rol de prueba
con su `grantor`, `ADMIN`, `INHERIT` y `SET`.

**Decisión GO:** continuar sólo si la credencial inicial puede crear los roles,
conceder `fleet_owner` a `fleet_migrator`, permitir que éste haga `SET ROLE
fleet_owner`, y transferir ownership a `fleet_owner`. **NO-GO:** si alguno de
esos controles obliga a usar `fleet_app` con DDL/ownership o a eliminar la
separación de identidades; no se rebaja el modelo por conveniencia del
proveedor.

`SECURITY DEFINER` está presente en las migraciones `002` y `003`. Las
funciones fijan `search_path = public`; como `PUBLIC` no puede crear objetos en
ese esquema, no hay vector de path hijacking por el runtime. Sus grants a
`PUBLIC` se revocan y el acceso de `fleet_app` se concede explícitamente.

La migración `001` llama a `gen_random_uuid()`, que PostgreSQL 18 ofrece en el
catálogo core. `pgcrypto` se conserva para `crypt` y `gen_salt` usados por las
funciones de contraseña existentes. La ubicación soportada es el esquema
estándar `public`, no `extensions`. No se detectaron usos activos de `postgis`,
`pgvector` ni `uuid-ossp`.

En Render se confirmó `pgcrypto` 1.4 en `public`: la credencial inicial posee
la extensión, pero sus funciones contenidas pertenecen al bootstrap superuser.
Es el comportamiento esperado de una extensión *trusted* instalada por un
usuario no-superuser. Por ello el bootstrap valida la presencia de
`crypt`/`gen_salt` y el `EXECUTE` efectivo de `fleet_owner`, pero no intenta
cambiar ACLs de objetos que no posee. `PUBLIC` conserva `EXECUTE` en esas
funciones de extensión; `PUBLIC` significa todos los roles PostgreSQL, no
acceso desde Internet, y exige de todos modos conexión y acceso al esquema.
Es una limitación aceptada de prioridad P2: esas funciones transforman sólo los
argumentos recibidos y no otorgan lectura de hashes ni de tablas de usuarios.
Las funciones de aplicación que sí manejan contraseñas siguen otro modelo:
`fleet_owner` las posee, fijan `search_path`, revocan `EXECUTE` a `PUBLIC` y
conceden sólo el acceso necesario a `fleet_app`.

El bootstrap de roles es [`database/security/create_roles.sql`](../database/security/create_roles.sql).
Luego, y sólo después de comprobar sus roles, la credencial inicial instala
`pgcrypto` mediante [`database/bootstrap/create_extensions.sql`](../database/bootstrap/create_extensions.sql).
La extensión queda administrada por esa credencial, mientras sus objetos
contenidos permanecen bajo el owner administrado por PostgreSQL/Render; los
objetos de aplicación quedan bajo `fleet_owner`. No se crea un esquema
artificial `extensions`.

### Credenciales Render gestionadas: migraciones GO, runtime NO-GO

Hecho comprobado: la credencial Render gestionada de migraciones autentica como
`session_user`, pero Render le configura un `role` de conexión. PostgreSQL
aplica ese ajuste al abrir sesión, por lo que `current_user` empieza como ese
rol default; `RESET ROLE` vuelve exactamente a dicho ajuste. No es un error de
autenticación. El runner usa `session_user`, valida su membresía directa de
`fleet_migrator` (`ADMIN FALSE, INHERIT TRUE, SET TRUE`) y luego ejecuta
explícitamente `SET ROLE fleet_owner` antes de cualquier migración.

La misma credencial gestionada recibió además roles proporcionados por Render,
incluidos un rol default anterior, `pg_read_all_stats` y `pg_signal_backend`,
con `SET TRUE`. No se revocan automáticamente: son una limitación de privilegio
del proveedor. `pg_read_all_stats` permite observabilidad amplia y
`pg_signal_backend` permite señalizar sesiones autorizadas; no se convierten en
grants de `fleet_app`, pero descartan esa credencial para runtime.

Por inferencia de este patrón observado, una futura credencial gestionada podría
recibir también un rol default y membresías adicionales. Un `SET ROLE
fleet_app` al crear una conexión no lo resolvería: `session_user` conservaría
la capacidad de hacer `RESET ROLE` o asumir cualquier rol con `SET TRUE`.
Por ello no se crea una credencial Render gestionada para Fastify hasta que el
proveedor permita demostrar un perfil inicial sin esas membresías.

Render documenta que cada nueva credencial gestionada se vuelve el *default
user* de la base, afectando las URLs mostradas y las referencias dinámicas de
Blueprint. Este proyecto usa variables individuales con `sync: false`, pero
eso no elimina las membresías/ajustes de rol observados. No cree otra
credencial sólo para probar runtime en esta etapa. [Documentación de Render](https://render.com/docs/postgresql-credentials)

No se modifica `create_roles.sql`: los roles existentes siguen temporalmente
con `LOGIN`. Tampoco se los convierte a `NOLOGIN` hasta resolver y validar el
login runtime alternativo.

### Pasos manuales posteriores

1. Mantenga la credencial Render gestionada actual exclusivamente en
   `MIGRATION_DATABASE_*`; confirme su `session_user`, su membresía directa de
   `fleet_migrator` y el salto explícito a `fleet_owner`.
2. No configure `DATABASE_*` con esa credencial ni con otra managed que tenga
   un rol default o membresías adicionales con `SET TRUE`.
3. Pruebe de forma controlada el login SQL `fleet_app` mediante conexión
   interna de Render, cuando exista una vía autorizada para hacerlo. El fallo
   SCRAM externo anterior no demuestra que ese camino interno falle.
4. Si ese login tampoco puede autenticarse, mantenga el NO-GO de runtime y
   evalúe soporte de Render, una credencial con perfil mínimo verificable u
   otro proveedor. No ejecute todavía `pgcrypto`, migraciones ni despliegues.

Los servicios de Render en la misma cuenta y región deberán usar la conexión
interna/privada; el acceso externo es sólo para bootstrap o herramientas
temporales y debe retirarse/restringirse después. PostgreSQL nunca es público
para Flutter.

### Configuración posterior de MasiTrack API (no ejecutar aún)

Cuando el GO de roles esté confirmado, cree manualmente un Web Service llamado
`masitrack-api-preprod`: root `backend`, runtime Node, build
`pnpm install --frozen-lockfile && pnpm run build`, start
`node dist/src/server.js`, health check `/ready`, y auto-deploy apagado.
`package.json` requiere Node `>=24 <25` y `pnpm@11.23.0`.

`/ready` prueba `SELECT 1`: devuelve 200 sólo si Fastify y PostgreSQL están
disponibles; devuelve 503 sin exponer detalles internos si la dependencia cae.
El proceso escucha `BACKEND_HOST`/`HOST` y `PORT`, por lo que cloud debe usar
`BACKEND_HOST=0.0.0.0` y el `PORT` asignado por Render.

No configure `TRUST_PROXY=true`: el código lo rechaza. Mantenga `false` hasta
conocer CIDRs concretos del proxy; entonces use sólo esos CIDRs. El rate limit
global es 300/minuto, login tiene límites específicos y tracking/presencia usan
límites de ruta compatibles con heartbeats de 60/30 segundos y GPS frecuente.
Los logs redactan Authorization, cookies, contraseñas, tokens, Firebase y
Traccar; no imprima el entorno completo.

### Checklist de variables cloud (sin valores)

| Grupo | Variables |
| --- | --- |
| Runtime no secret | `NODE_ENV`, `PORT`, `BACKEND_HOST`, `API_LOG_LEVEL`, límites, timeouts, pool y `SESSION_TTL_HOURS` |
| Runtime DB | `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_NAME`, `DATABASE_USER`, `DATABASE_PASSWORD`, `DATABASE_SSL`, `DATABASE_SSL_REJECT_UNAUTHORIZED`, `DATABASE_SSL_CA` |
| Migraciones aisladas | `MIGRATION_DATABASE_HOST`, `MIGRATION_DATABASE_PORT`, `MIGRATION_DATABASE_NAME`, `MIGRATION_DATABASE_USER`, `MIGRATION_DATABASE_PASSWORD`, `MIGRATION_DATABASE_SSL`, `MIGRATION_DATABASE_SSL_REJECT_UNAUTHORIZED`, `MIGRATION_DATABASE_SSL_CA` |
| CORS | `CORS_ALLOWED_ORIGINS` con la URL HTTPS exacta de Web, nunca `*` |
| Integraciones backend-only | `FIREBASE_SERVICE_ACCOUNT_JSON`, `TRACCAR_BASE_URL`, `TRACCAR_AUTHORIZATION`, y sus timeouts |

El runtime usa variables individuales, no necesita adoptar `DATABASE_URL`.
Mantenga las variables `MIGRATION_DATABASE_*` fuera del Web Service normal;
úselo sólo para el runner manual o CI aislado. TLS verificado está exigido por
el runtime en producción (`DATABASE_SSL=true` y
`DATABASE_SSL_REJECT_UNAUTHORIZED=true`); la CA del proveedor se suministra en
la variable dedicada si corresponde. No use `rejectUnauthorized=false`.

Firebase carga un JSON de cuenta de servicio sólo desde el secreto de backend.
Traccar exige URL y autorización juntas y su autorización nunca llega a
Flutter. Para UAT use fixtures/seed mínimos, no copie la base local completa:
sin sesiones antiguas, tokens, logs, historial GPS o credenciales. Defina un
backup lógico/restauración antes de datos reales y limite el acceso a
ubicaciones por rol.

## Flutter Web y Android

`BACKEND_API_BASE_URL` es público y debe inyectarse sólo al compilar:

```powershell
C:\dev\flutter\bin\flutter.bat build web --release --dart-define=BACKEND_API_BASE_URL=https://<masitrack-api-publica>
C:\dev\flutter\bin\flutter.bat build apk --release --dart-define=BACKEND_API_BASE_URL=https://<masitrack-api-publica>
```

No compile con IPs privadas, `localhost` o credenciales. Flutter Web debe
publicarse como Static Site separado con `build/web` como directorio publicado.
Render ofrece hosting estático, pero su runtime nativo no incluye Flutter:
prepare el artefacto en CI o use un host/build-image que disponga de Flutter;
no se añade Docker en este sprint.

El release Android actual se firma con la clave debug. Antes de distribuir un
APK/AAB real, cree y gestione un keystore de release fuera de Git, configure
una signingConfig de release y guarde sus contraseñas en un gestor de secretos.
No hay configuración de cleartext ni network security config: la
preproducción/release debe usar exclusivamente HTTPS; el debug local conserva
su comportamiento actual.

La versión actual está en `pubspec.yaml`; mantenga `versionName` semver y
suba `buildNumber` de forma incremental al preparar un artefacto de
preproducción. No se modificó el versionado en este sprint.

## Checklist manual

- [ ] Git limpio y credencial histórica rotada.
- [ ] PostgreSQL privado creado, backup inicial y compatibilidad de roles validada.
- [ ] Variables runtime, TLS, CORS y secretos configurados en el proveedor.
- [ ] Roles creados, migraciones aplicadas y `pnpm run db:check` correcto.
- [ ] MasiTrack API responde `GET /ready` con HTTP 200.
- [ ] Flutter Web compilado con URL HTTPS pública y login comprobado.
- [ ] Android compilado con URL HTTPS pública; probar datos móviles, GPS y background.
- [ ] Rollback preparado: restaurar versión previa del servicio y backup probado.
