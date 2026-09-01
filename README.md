# MasiTrack

MasiTrack es una aplicación Flutter para la operación de flotas. Su runtime
utiliza MasiTrack API (Fastify) y PostgreSQL como base de datos.

El repositorio mantiene el nombre técnico `fleet_control` por compatibilidad e
historial.

## Arquitectura

- Flutter se comunica con MasiTrack API (Fastify) mediante `BACKEND_API_BASE_URL` y un token
  Bearer de sesión propio.
- MasiTrack API concentra autenticación, permisos, operaciones, reportes, mapa y
  notificaciones.
- PostgreSQL (`fleet_control_db`) mantiene el esquema y la lógica de datos.
- Firebase Cloud Messaging es opcional para notificaciones push; las alertas
  internas siguen funcionando si no se configura Firebase.

Flutter no accede directamente a las tablas de negocio.

## Nomenclatura de entornos

- Producto: MasiTrack
- API: MasiTrack API
- Repositorio técnico: `fleet_control`
- Preproducción futura: `masitrack-web` y `masitrack-api`
- Dominios futuros conceptuales: `app.masitrack...` y `api.masitrack...`

## MasiTrack Preproducción

La preproducción usa una API Fastify pública detrás de HTTPS y PostgreSQL
privado. La configuración, las variables por entorno, las migraciones, el
build Flutter y el checklist manual están en
[`docs/preproduction-deployment.md`](docs/preproduction-deployment.md).
No contiene secretos ni crea servicios cloud automáticamente.

## Android y datos móviles

La APK recibe la URL de Fastify al compilar mediante `BACKEND_API_BASE_URL`.
Para una prueba LAN puede usarse una IP privada solo mientras el teléfono esté
en la misma red. Para datos móviles o producción se requiere una API pública
HTTPS (por ejemplo, detrás de un reverse proxy); Android no debe conectarse
directamente a PostgreSQL.

```powershell
flutter build apk --debug --dart-define=BACKEND_API_BASE_URL=https://api.example.com
```

## Desarrollo local

### Desarrollo local web

En PowerShell, la forma recomendada de iniciar Fastify y Flutter Web es:

```powershell
.\scripts\dev-web.ps1
```

El launcher mantiene ambos procesos separados: reutiliza Fastify si `/ready`
responde en el puerto 3000, o lo inicia con `pnpm run dev`, espera readiness y
recién entonces abre Chrome en el puerto 8080 con la URL de backend explícita.
No guarda credenciales ni detiene procesos ajenos.

1. Configure `backend/.env` a partir de `backend/.env.example` con los datos
   de PostgreSQL y, si se requiere push, `FIREBASE_SERVICE_ACCOUNT_JSON`.
2. Inicie Fastify desde `backend` con `pnpm run dev`.
3. Ejecute Flutter con una URL de API explícita, por ejemplo:

```bash
flutter run -d web-server --web-port 8080 --dart-define=BACKEND_API_BASE_URL=http://127.0.0.1:3000
```

El origen web debe estar incluido en `CORS_ALLOWED_ORIGINS` del backend.

## Migraciones

`database/migrations/` es la fuente de verdad para los cambios de PostgreSQL.
Revise su README y aplique las migraciones al entorno correspondiente antes de
desplegar una versión que las requiera.

El material anterior de la plataforma retirada se conserva solamente como
referencia histórica en `legacy/supabase/`; no forma parte del runtime ni de
los pasos de despliegue.
