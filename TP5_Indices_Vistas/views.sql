-- ============================================================================
-- views.sql — Punto de entrada de las Partes B y C (estructura de entrega de
-- la consigna, seccion 7). Carga, en orden, los archivos de cada parte:
--   1. Parte_B_Vistas/usuarios.sql         tabla usuario
--   2. Parte_B_Vistas/usuarios_datos.sql   datos de usuario
--   3. Parte_B_Vistas/vistas.sql           las 5 vistas
--   4. Parte_C_Vista_Materializada/vista_materializada.sql
--   5. Parte_B_Vistas/seguridad_roles.sql  rol tp5_reportes (va al final
--      porque otorga SELECT sobre las vistas y la vista materializada)
--
-- Pensado para armar una base desde cero, despues de schema.sql.
-- Ejecutar desde la carpeta TP5_Indices_Vistas:
--   psql -U postgres -d foodstore_tp3_carga -f views.sql
-- En una base que ya tiene todo aplicado, el CREATE MATERIALIZED VIEW
-- y su indice dan "already exists" (el resto sigue) y se vuelven a
-- ejecutar los REFRESH de la Parte C.
-- ============================================================================
\ir Parte_B_Vistas/usuarios.sql
\ir Parte_B_Vistas/usuarios_datos.sql
\ir Parte_B_Vistas/vistas.sql
\ir Parte_C_Vista_Materializada/vista_materializada.sql
\ir Parte_B_Vistas/seguridad_roles.sql
