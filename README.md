# Fleet Control

Fleet Control es una aplicación Flutter para la operación de flotas. Su
runtime utiliza Fastify como API y PostgreSQL como base de datos.

## Arquitectura

- Flutter se comunica con Fastify mediante `BACKEND_API_BASE_URL` y un token
  Bearer de sesión propio.
- Fastify concentra autenticación, permisos, operaciones, reportes, mapa y
  notificaciones.
- PostgreSQL (`fleet_control_db`) mantiene el esquema y la lógica de datos.
- Firebase Cloud Messaging es opcional para notificaciones push; las alertas
  internas siguen funcionando si no se configura Firebase.

Flutter no accede directamente a las tablas de negocio.

## Desarrollo local

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
