-- ============================================================================
-- indices.sql — Punto de entrada de la Parte A (estructura de entrega de la
-- consigna, seccion 7). El contenido real, con cada indice aceptado y
-- descartado y su justificacion, esta en Parte_A_Indices/indices.sql.
--
-- Ejecutar desde la carpeta TP5_Indices_Vistas:
--   psql -U postgres -d foodstore_tp3_carga -f indices.sql
-- Se puede correr mas de una vez: los CREATE INDEX usan IF NOT EXISTS.
-- ============================================================================
\ir Parte_A_Indices/indices.sql
