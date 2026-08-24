# Fleet Control

## Backend y autenticación

Fleet Control usa autenticación personalizada: `usuario` y contraseña se validan con `public.login_usuario()`. `auth-login` genera un `session_token` aleatorio, guarda únicamente su SHA-256 en `public.sesiones` y devuelve el token al cliente. Flutter envía ese token en `Authorization: Bearer <token>`.

No se utiliza Supabase Auth ni se manejan correos, teléfonos, tokens de acceso o de renovación. Todas las funciones protegidas validan la sesión no revocada y vigente, cargan el usuario activo y su rol. Las Edge Functions usan la clave de servidor y RLS permanece habilitado; Flutter no accede directamente a las tablas de negocio.

## Endpoints

| Área | Endpoints |
| --- | --- |
| Sesión | `auth-login`, `session-logout` |
| Empresas | `companies-list`, `companies-create`, `companies-update` |
| Locales | `locations-list`, `locations-create`, `locations-update` |
| Asistencia | `attendance-status`, `attendance-create`, `attendance-history` |
| Usuarios | `users-list`, `users-create`, `users-update`, `users-reset-password` |
| Vehículos | `vehicles-list`, `vehicles-create`, `vehicles-update` |

Las mutaciones usan JSON y devuelven el recurso bajo `company`, `location`, `user`, `vehicle` o `attendance`. Errores estables: `unauthorized`, `forbidden`, `invalid_request`, `not_found`, `conflict`, `outside_geofence` e `internal_error`.

| Endpoint | Cuerpo o filtros principales |
| --- | --- |
| `companies-create` / `companies-update` | `{ nombre }`; actualización además acepta `{ id, activo }` |
| `locations-create` / `locations-update` | `empresa_id`, `nombre`, `direccion`, `latitud`, `longitud`, `radio_metros`, `activo` (la actualización incluye `id`) |
| `attendance-create` | `{ local_id, latitud, longitud }` |
| `attendance-history` | `desde`, `hasta`, `tipo`, `local_id`, `usuario_id` (sólo roles autorizados), `limit`, `offset` |
| `users-create` | `nombre`, `usuario`, `password`, `empresa_id`, `rol_id`, `activo` |
| `users-update` | `id` y cualquiera de `nombre`, `usuario`, `empresa_id`, `rol_id`, `activo` |
| `users-reset-password` | `{ user_id, new_password }` |
| `vehicles-create` / `vehicles-update` | `empresa_id`, `patente`, `marca`, `modelo`, `anio`, `descripcion`, `activo` (la actualización incluye `id`) |

## Asistencia

`attendance-create` recibe `local_id`, `latitud` y `longitud`; el servidor calcula Haversine, bloquea la marcación fuera de radio con HTTP 422 y determina el siguiente movimiento alternando entrada/salida. Nunca acepta `dentro_geocerca` como dato del cliente.

## Permisos

- `super_admin`: administra todo.
- `admin`: administra locales, usuarios y vehículos de su empresa.
- `supervisor`: consulta usuarios y vehículos de su empresa; puede consultar historial operativo de su empresa.
- `chofer` y `user`: sólo su asistencia, historial y locales de su empresa.

Un administrador no puede crear ni asignar `super_admin`.

## Migración y despliegue

La migración `20260819000000_fleet_control_backend.sql` añade sólo el backend necesario y no debe sustituir el esquema remoto a ciegas. Revise la lista de migraciones remotas antes de aplicarla y despliegue las funciones mediante la CLI de Supabase vinculada al proyecto correcto.

Las contraseñas se hashean en PostgreSQL con `pgcrypto` y jamás se devuelven ni se almacenan en texto plano. Al restablecer una contraseña se revocan las sesiones activas del usuario.
