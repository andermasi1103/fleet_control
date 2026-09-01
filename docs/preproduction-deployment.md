# MasiTrack Preproducción

Esta guía prepara un entorno público de preproducción; no crea recursos, no
despliega y no contiene valores secretos. El repositorio técnico sigue siendo
`fleet_control`.

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
| DB runtime | `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_NAME`, `DATABASE_USER`, `DATABASE_PASSWORD` | PostgreSQL local y `fleet_app` | host privado y secreto del gestor cloud para `fleet_app` |
| TLS runtime | `DATABASE_SSL`, `DATABASE_SSL_REJECT_UNAUTHORIZED`, `DATABASE_SSL_CA` | `false`, `true`, vacía | `true`, `true`, CA del proveedor si corresponde |
| Pool | `PG_POOL_MAX`, `PG_IDLE_TIMEOUT_MS`, `PG_CONNECTION_TIMEOUT_MS`, `PG_STATEMENT_TIMEOUT_MS` | defaults de `.env.example` | mismos valores iniciales, ajustar según el plan de DB |
| CORS/proxy | `CORS_ALLOWED_ORIGINS`, `TRUST_PROXY` | URLs localhost explícitas, `false` | URL HTTPS exacta de Flutter Web, `false` hasta validar IP/CIDR del proxy |
| Integraciones | `FIREBASE_SERVICE_ACCOUNT_JSON`, `TRACCAR_BASE_URL`, `TRACCAR_AUTHORIZATION` | opcionales | secretos sólo en gestor cloud; nunca en dart-defines |
| Migraciones | `MIGRATION_DATABASE_HOST`, `MIGRATION_DATABASE_PORT`, `MIGRATION_DATABASE_NAME`, `MIGRATION_DATABASE_USER`, `MIGRATION_DATABASE_PASSWORD`, `MIGRATION_DATABASE_SSL`, `MIGRATION_DATABASE_SSL_REJECT_UNAUTHORIZED`, `MIGRATION_DATABASE_SSL_CA` | conexión local efímera | conexión privada/TLS, secret separado, usuario `fleet_migrator` |

No use `*` en `CORS_ALLOWED_ORIGINS`. Android nativo no depende de CORS; Flutter
Web sí. `TRUST_PROXY=true` está bloqueado intencionalmente: sólo configúrelo
con IPs o CIDRs concretos del proxy tras verificarlos con el proveedor. De lo
contrario, no confíe en encabezados `X-Forwarded-*` de origen no validado.

## PostgreSQL y migraciones

1. Cree una base privada en la misma región/red que el backend cuando el
   proveedor lo permita.
2. Con una cuenta administrativa, valide que el servicio administrado permita
   `CREATE ROLE`, `GRANT`, `ALTER ... OWNER` y `SET ROLE`; aplique
   `database/security/create_roles.sql` sólo tras revisarlo para el proveedor.
3. Configure `fleet_app` para Fastify y una identidad de migración separada
   `fleet_migrator`, autorizada a `SET ROLE fleet_owner`.
4. Ejecute desde `backend` el comando manual `pnpm run db:migrate` con sólo
   variables `MIGRATION_DATABASE_*`. El runner rechaza otro usuario y no usa
   variables runtime `DATABASE_*`.
5. Ejecute `pnpm run db:check` usando `fleet_app`; aplique RLS si corresponde
   siguiendo `database/security/README.md`.

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
