# Baseline PostgreSQL de Fleet Control

## Estado

El baseline SQL no fue generado todavía. La fuente primaria es el catálogo
actual de PostgreSQL remoto, pero su extracción schema-only no pudo completarse
en este entorno: la CLI de Supabase requiere Docker Desktop para ejecutar su
`pg_dump` y no hay `psql` ni `pg_dump` instalados localmente.

No aplicar un baseline derivado sólo de `supabase/migrations` ni de
`supabase/manual`: el repositorio no contiene el DDL inicial completo ni la
definición real de `public.login_usuario(text, text)`.

## Requisitos para continuar

1. Docker Desktop en ejecución, con el proyecto Supabase ya vinculado; o
2. un cliente `pg_dump`/`psql` compatible con PostgreSQL 17 y una conexión de
   sólo lectura suministrada fuera del repositorio.

No guardar contraseñas, URLs con contraseña, dumps de datos ni secretos en Git.

## Extracción de solo lectura

Con Docker Desktop disponible, desde la raíz del proyecto:

```powershell
supabase db dump --linked --schema public --file database/baseline/source/remote_public_schema.sql
```

El archivo resultante es una fuente de comparación. No es automáticamente el
baseline final: se debe revisar para retirar roles/grants exclusivos de
Supabase y preservar los objetos de negocio reales.

Después, ejecutar las consultas de [catalog_queries.sql](catalog_queries.sql)
en una conexión de solo lectura contra la misma base y guardar los resultados
fuera de Git o en artefactos saneados.

## Criterio para crear `baseline.sql`

Sólo se creará cuando el dump y el catálogo confirmen:

- las tablas, columnas, constraints, índices y triggers reales;
- las definiciones reales de las funciones, especialmente `login_usuario`;
- extensiones y dependencias no gestionadas por Supabase;
- políticas, grants y `SECURITY DEFINER` que deban convertirse al modelo
  `fleet_owner` / `fleet_app`.

El resultado será schema-only, sin usuarios, hashes de contraseña, sesiones,
pedidos, ubicaciones ni tokens de dispositivo.
