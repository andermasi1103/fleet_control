# Catalog report — Fase 0

## Estado de la extracción remota

- Proyecto remoto vinculado localmente: sí.
- Versión PostgreSQL registrada por la CLI: `17.6.1.155`.
- Volcado schema-only: no disponible en este entorno.
- Motivo: `supabase db dump --linked --schema public` requiere Docker Desktop;
  la CLI informó que Docker Desktop no está disponible. No existe cliente local
  `psql` ni `pg_dump` como alternativa.
- No se ejecutó ninguna instrucción de modificación remota.

## Objetos esperados desde el repositorio local

### Tablas

`empresas`, `locales`, `usuarios`, `roles`, `sesiones`, `asistencias`,
`vehiculos`, `usuario_locales`, `usuario_vehiculos`, `supervisor_choferes`,
`pedido_descripciones`, `pedidos`, `gestiones`, `gestion_eventos`,
`chofer_ubicaciones`, `app_views`, `role_views`, `notification_devices` y
`notificaciones`.

Las primeras siete tablas no tienen DDL inicial completo en
`supabase/migrations`; su forma real debe extraerse del catálogo remoto.

### Funciones críticas a recuperar del remoto

- `login_usuario(text, text)`
- `fleet_control_create_usuario`
- `fleet_control_set_usuario_password`
- `fleet_control_verify_usuario_password`
- `fleet_control_set_user_locations`
- `fleet_control_set_user_vehicle`
- `fleet_control_import_locations`
- `fleet_control_create_gestion`
- `fleet_control_driver_claim_order`
- `fleet_control_update_gestion_status`
- `fleet_control_update_driver_location`
- `fleet_control_set_supervisor_choferes`

`login_usuario(text, text)` es el bloqueador principal: el código local la
invoca, pero no conserva su definición real. No se puede confirmar su retorno,
el control de usuario activo, ni la exclusión de `password_hash` sin catálogo.

## Extensiones y seguridad

`pgcrypto` es necesaria según migraciones/manuales locales: aporta
`gen_random_uuid`, `crypt` y `gen_salt`. No se detectó otra extensión de
negocio en los archivos locales; el catálogo debe confirmarlo.

RLS y grants a `anon`, `authenticated` y `service_role` son protecciones del
Data API/Edge Functions de Supabase. No deben copiarse al baseline de
PostgreSQL propio. El diseño objetivo es:

- `fleet_owner`: propietario de esquema y migraciones.
- `fleet_app`: rol de conexión del backend Fastify, sin acceso público.
- PostgreSQL sólo accesible desde el backend privado.

Las funciones `SECURITY DEFINER`, sus propietarios, `search_path` y grants
actuales permanecen pendientes de obtener del catálogo real.

## Índices y constraints que deberán confirmarse

- usuario único sin distinción de mayúsculas;
- patente única por empresa;
- token hash de sesión;
- asignaciones usuario-local, usuario-vehículo y supervisor-chofer;
- un pedido tomado una sola vez;
- gestión operativa única por chofer y vehículo;
- `queue_position` única dentro de la cola;
- una ubicación vigente por chofer;
- idempotencia `new_order` por usuario y pedido.

## Comparación local pendiente

Las 15 migraciones y los SQL bajo `supabase/manual` sirven para contrastar el
dump, no para construir el baseline de manera automática. También contienen
funciones reemplazadas por migraciones posteriores, por lo que concatenarlas
produciría un esquema no confiable.

## Bloqueador

No es seguro crear `baseline.sql` hasta obtener un dump schema-only y las
definiciones del catálogo remoto. Crear uno ahora inventaría el estado de
producción y contradice la condición de que PostgreSQL remoto es la fuente de
verdad.
