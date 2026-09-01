# Estado de reconstrucción del baseline PostgreSQL

## Decisión

Se creó `000_initial_schema.sql` como el estado base inmediatamente anterior a
`001_notifications.sql`. La evidencia primaria fue
`local_schema_reference.sql`, un `pg_dump --schema-only` local; permanece sólo
como evidencia local y está ignorado por Git. No se conectó ni ejecutó SQL en
PostgreSQL local, Render u otra base.

`000` crea 17 tablas y 14 funciones de aplicación/trigger requeridas por
Fastify. No contiene RLS, datos, roles, extensiones, `schema_migrations`,
Supabase ni el esquema histórico `extensions`.

## Clasificación de objetos del dump

| Clasificación | Objetos |
| --- | --- |
| BASELINE | `app_views`, `asistencias`, `chofer_ubicaciones` (sin presencia), `empresas`, `gestiones`, `gestion_eventos`, `locales`, `pedido_descripciones`, `pedidos`, `role_views`, `roles`, `sesiones`, `supervisor_choferes`, `usuario_locales`, `usuario_vehiculos`, `usuarios`, `vehiculos` |
| CREATED_OR_CHANGED_BY_003 | `chofer_ubicaciones.last_seen_at`, `chofer_ubicaciones_last_seen_at_idx`, `fleet_control_touch_driver_presence`, versión con presencia de `fleet_control_update_driver_location` |
| CREATED_BY_001 | `notification_devices`, `notificaciones`, sus índices y trigger |
| CREATED_OR_CHANGED_BY_002 | versión queue-aware de `fleet_control_create_gestion` |
| CREATED_OR_CHANGED_BY_004 | `empresas.local_marker_icon`, `empresas.local_marker_color` y sus checks |
| RLS_ONLY | `ENABLE ROW LEVEL SECURITY` y políticas `fleet_app_*`; viven en `database/security/fleet_app_rls.sql` |
| LEGACY | `audit_logs`, `licencias`, `permissions`, `planes`, `role_permissions`; no tienen consumidor actual de Fastify/RLS/fixtures |
| RUNNER_ONLY | `schema_migrations`; la crea exclusivamente `backend/scripts/migrate.ts` |

La forma anterior a `003` de `chofer_ubicaciones` sí es baseline, porque la
migración `003` sólo le añade la marca de presencia. La cola de `gestiones` ya
era previa a la serie numerada; `002` sustituye sólo la asignación manual.

## Resta 000 → 004

| Paso | Requiere o modifica | Garantía de `000` |
| --- | --- | --- |
| `000 → 001` | `usuarios`; crea dispositivos y alertas | No existen `notification_devices` ni `notificaciones` en `000` |
| `001 → 002` | `pedidos`, `usuarios`, `roles`, `vehiculos`, `gestiones`, `gestion_eventos` | Existen tablas, índices queue y la definición anterior de `fleet_control_create_gestion` |
| `002 → 003` | `chofer_ubicaciones`, `usuarios`, `roles`, `gestiones`, `vehiculos` | Existe ubicación sin `last_seen_at`; `003` puede añadirla y reemplazar su RPC |
| `003 → 004` | `empresas` | No existen las columnas de marcador que `004` añade |

## Autenticación y seguridad

Las funciones actualmente invocadas por Fastify están versionadas: login,
contraseña, altas de usuarios, ubicaciones/locales, vehículo/conductores,
pedidos/gestiones y ubicación GPS. `usuarios.password_hash` permanece como
columna de autenticación propia y ninguna función la retorna.

Las llamadas heredadas `extensions.crypt` y `extensions.gen_salt` se
reemplazaron por `public.crypt` y `public.gen_salt`. Todas las funciones de
aplicación `SECURITY DEFINER` fijan `search_path = public`, se revocan de
`PUBLIC` y reciben `EXECUTE` explícito sólo para `fleet_app`. Los objetos se
crean bajo el `SET ROLE fleet_owner` del runner y `000` declara el ownership
de las tablas a ese rol.

Las políticas no se duplican: se aplican después de `000`--`004` desde
`database/security/fleet_app_rls.sql`.

## Transacciones del runner

La autoridad transaccional final es `backend/scripts/migrate.ts`. `000` y las
nuevas migraciones no incluyen `BEGIN`/`COMMIT`; el runner registra el
checksum y el DDL en su única transacción. Para conservar los checksums de
`001`--`004`, el runner elimina sólo su envoltura exterior histórica antes de
ejecutarlos y rechaza control transaccional residual antes de escribir el
ledger. Una sonda temporal con `COMMIT` seguido de error confirmó que no queda
DDL ni entrada de `schema_migrations`.

## Validación pendiente

La validación de este cambio es estática por instrucción: no se ejecutó SQL.
El siguiente paso autorizado es aplicar roles, extensiones, `000`--`004`, RLS
y fixtures en una base PostgreSQL 18 temporal y aislada.
