# MasiTrack API

Backend propio de MasiTrack con autenticación y sesiones locales sobre PostgreSQL.

## Requisitos

- Node.js 20 o superior
- PostgreSQL accesible con la base `fleet_control_db`

## Instalación y configuración

Desde la carpeta `backend`:

```bash
pnpm install --frozen-lockfile
copy .env.example .env
```

Complete `DATABASE_USER` y `DATABASE_PASSWORD` en `.env` según corresponda a su instalación local. El archivo `.env` está ignorado por Git y nunca debe compartirse. En producción el proceso debe usar `fleet_app`, nunca `postgres`.

Después de aplicar `database/security/create_roles.sql`, configure la
contraseña de `fleet_app` sólo en el gestor de secretos o en `backend/.env`
local. El administrador debe definirla interactivamente (`\password fleet_app`)
o con `ALTER ROLE fleet_app WITH PASSWORD 'TU_PASSWORD_FLEET_APP';`; el valor
real no debe aparecer en el repositorio. Si una contraseña PostgreSQL fue
versionada antes, rótela para el rol afectado y actualice únicamente ese
secreto local.

Variables disponibles:

- `PORT` y `BACKEND_HOST`: dirección de escucha de la API. `BACKEND_HOST`
  acepta `0.0.0.0` para una UAT LAN controlada y por defecto permanece en
  `127.0.0.1`; `HOST` se conserva como alias compatible.
- `DATABASE_HOST`, `DATABASE_PORT`, `DATABASE_NAME`, `DATABASE_USER`, `DATABASE_PASSWORD`, `DATABASE_SSL`, `DATABASE_SSL_REJECT_UNAUTHORIZED`, `DATABASE_SSL_CA`: conexión a PostgreSQL.
- `API_LOG_LEVEL`: nivel de registro de Fastify.
- `CORS_ALLOWED_ORIGINS`: orígenes web permitidos, separados por comas. Para Flutter Web local use un puerto fijo, por ejemplo `http://localhost:8080,http://127.0.0.1:8080`; no use `*`.
- `TRUST_PROXY`: `false` o una lista de IPs/CIDRs del reverse proxy; nunca use `true` indiscriminadamente.
- `SESSION_TTL_HOURS`, límites de body/request/pool y rate limits: controles operativos con defaults seguros descritos en `.env.example`.
- `FIREBASE_SERVICE_ACCOUNT_JSON`: JSON completo de una cuenta de servicio Firebase usado sólo por Fastify para FCM HTTP v1. Es opcional: sin ella, el pedido y la notificación interna se crean y el push se omite.
- `TRACCAR_BASE_URL` y `TRACCAR_AUTHORIZATION`: integración opcional, sólo disponible en el backend. Flutter nunca recibe esta credencial.

## Ejecutar

```bash
pnpm run dev
```

También están disponibles:

```bash
pnpm run typecheck
pnpm run build
pnpm run start
pnpm run db:check
pnpm run db:migrate -- --dry-run
pnpm test
```

## Flutter Web local

Ejecute Flutter con un origen fijo que coincida con `CORS_ORIGIN` y apúntelo a
Fastify mediante `--dart-define`:

```bash
flutter run -d web-server --web-port 8080 --dart-define=BACKEND_API_BASE_URL=http://127.0.0.1:3000
```

Si se utiliza otro puerto, agréguelo explícitamente a `CORS_ALLOWED_ORIGINS` antes de
iniciar el backend. Flutter envía el token de sesión local únicamente a las
rutas de Fastify.

`db:check` abre una transacción `READ ONLY` y comprueba las tablas, funciones, extensión `pgcrypto` y schema `extensions` esperados. No realiza cambios en la base de datos.

## Health checks

- `GET /health` responde `{ "status": "ok" }`.
- `GET /health/db` ejecuta `SELECT 1`. Cuando PostgreSQL está disponible responde `{ "status": "ok", "database": "connected" }`; si no, responde HTTP 503 sin exponer credenciales.
- `GET /ready` verifica la dependencia de PostgreSQL para readiness sin exponer detalles internos.

## Autenticación local

- `POST /api/auth/login` recibe `usuario` y `password`. La contraseña se valida con `public.login_usuario(text, text)` y la sesión dura 24 horas, igual que el endpoint anterior.
- `POST /api/auth/logout` requiere `Authorization: Bearer <token>` y revoca la sesión actual.
- `POST /api/profile/password` requiere el mismo Bearer y recibe `currentPassword` y `newPassword` (8 a 1024 caracteres, distinta a la actual). La función PostgreSQL revoca las sesiones, por lo que el usuario debe iniciar sesión de nuevo.

El token de sesión se genera con 32 bytes criptográficamente seguros y sólo su hash SHA-256 se guarda en PostgreSQL. Los endpoints de autenticación no almacenan ni registran contraseñas, tokens ni hashes en los logs.

Pendiente antes de producción: ejecutar la validación final con el rol `fleet_app`, credenciales externas y configuración real de HTTPS/CORS.

## Producción

Use un reverse proxy HTTPS delante de Fastify y mantenga PostgreSQL en una red
privada. Configure `TRUST_PROXY` sólo con los proxies que realmente reenvían
tráfico. En `NODE_ENV=production` el backend exige declarar explícitamente
puerto, host, conexión PostgreSQL, TLS, nivel de logs, CORS y TTL de sesión;
además valida TLS de PostgreSQL con verificación y un usuario de base no
superusuario.

Prepare roles, grants, backups y migraciones siguiendo
[`database/PRODUCTION.md`](../database/PRODUCTION.md). Fastify no ejecuta DDL
al arrancar y realiza cierre ordenado ante `SIGINT` o `SIGTERM`.

`fleet_owner` no es una identidad de runtime: no tiene login. Las migraciones
deben ejecutarse con una identidad operativa separada, autorizada a asumir ese
rol; nunca conceda esa capacidad a `fleet_app`.

La API aplica headers de seguridad. Su CSP se desactiva deliberadamente porque
Fastify no entrega el documento Flutter Web; el host que sirve esa aplicación
debe definir la CSP correspondiente.
