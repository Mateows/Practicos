-- ==============================================================================
-- maintenance.sql
-- Proyecto : FoodStore — UTN FRM · Base de Datos II
-- Propósito: Revisión del estado del autovacuum/ANALYZE y mantenimiento manual
--            periódico de la base 'foodstore' en PostgreSQL 16.
-- Uso      : Ejecutar con psql -d foodstore -f maintenance.sql
--            o pegar en pgAdmin > Query Tool conectado a 'foodstore'.
-- Frecuencia recomendada: semanal (ver SPEC_U6.md, Tarea 3).
--
-- IMPORTANTE: Este script NO incluye VACUUM FULL.
--   VACUUM FULL adquiere un lock exclusivo sobre la tabla, bloquea lecturas y
--   escrituras durante toda su ejecución y es innecesario como rutina periódica.
--   Reservarlo únicamente para recuperación de espacio en disco tras una carga
--   o eliminación masiva puntual, y siempre con autorización del grupo.
-- ==============================================================================


-- ==============================================================================
-- SECCIÓN 1 — Estado del autovacuum y ANALYZE por tabla
-- Objetivo: verificar que el autovacuum esté actuando sobre todas las tablas y
--           detectar si alguna fue ignorada (p. ej. por tener autovacuum desactivado
--           a nivel de storage parameter o por carga baja de escrituras).
-- ==============================================================================
SELECT
    schemaname                        AS esquema,
    relname                           AS tabla,
    last_vacuum                       AS ultimo_vacuum_manual,
    last_autovacuum                   AS ultimo_autovacuum,
    last_analyze                      AS ultimo_analyze_manual,
    last_autoanalyze                  AS ultimo_autoanalyze,
    vacuum_count                      AS veces_vacuum_manual,
    autovacuum_count                  AS veces_autovacuum,
    analyze_count                     AS veces_analyze_manual,
    autoanalyze_count                 AS veces_autoanalyze,
    n_dead_tup                        AS tuplas_muertas_actuales
FROM pg_stat_user_tables
ORDER BY relname;


-- ==============================================================================
-- SECCIÓN 2 — Configuración de autovacuum por tabla (umbrales efectivos)
-- Objetivo: confirmar que los parámetros de disparo del autovacuum son coherentes
--           con el volumen de datos. Si autovacuum_vacuum_scale_factor es muy alto
--           en tablas grandes, el autovacuum puede tardar demasiado en dispararse.
-- ==============================================================================
SELECT
    c.relname                         AS tabla,
    c.reltuples::BIGINT               AS filas_estimadas,
    COALESCE(
        (SELECT option_value
         FROM pg_options_to_table(c.reloptions)
         WHERE option_name = 'autovacuum_vacuum_scale_factor'),
        current_setting('autovacuum_vacuum_scale_factor')
    )                                 AS scale_factor_vacuum,
    COALESCE(
        (SELECT option_value
         FROM pg_options_to_table(c.reloptions)
         WHERE option_name = 'autovacuum_analyze_scale_factor'),
        current_setting('autovacuum_analyze_scale_factor')
    )                                 AS scale_factor_analyze,
    COALESCE(
        (SELECT option_value
         FROM pg_options_to_table(c.reloptions)
         WHERE option_name = 'autovacuum_enabled'),
        'heredado'
    )                                 AS autovacuum_tabla
FROM pg_class c
JOIN pg_namespace n ON n.oid = c.relnamespace
WHERE n.nspname = 'public'
  AND c.relkind = 'r'
ORDER BY c.relname;


-- ==============================================================================
-- SECCIÓN 3 — Procesos de autovacuum en ejecución en este momento
-- Objetivo: detectar si algún autovacuum lleva demasiado tiempo corriendo, lo
--           que podría indicar bloqueos o tablas con volumen excesivo de cambios.
-- ==============================================================================
SELECT
    pid                               AS proceso_id,
    now() - query_start               AS duracion,
    LEFT(query, 120)                  AS descripcion
FROM pg_stat_activity
WHERE query ILIKE '%autovacuum%'
  AND state <> 'idle'
ORDER BY duracion DESC NULLS LAST;


-- ==============================================================================
-- SECCIÓN 4 — VACUUM ANALYZE manual sobre detalle_pedido
--
-- Justificación: detalle_pedido es la tabla con mayor volumen de escrituras del
-- esquema, ya que cada pedido genera al menos una fila nueva y los precios
-- históricos nunca se actualizan (R4). En contextos de carga masiva (TP3) acumula
-- más dead tuples que el resto. Ejecutar VACUUM ANALYZE manualmente una vez por
-- semana, después de revisar los resultados de la Sección 1, garantiza que:
--   a) Las versiones obsoletas se limpian sin esperar al próximo ciclo de
--      autovacuum, reduciendo el bloat de heap.
--   b) Las estadísticas del planificador quedan actualizadas, lo que mejora los
--      planes de las consultas analíticas (TP4) que unen pedido con detalle_pedido.
--
-- No se usa VACUUM FULL: adquiriría lock exclusivo y bloquearía cualquier
-- consulta concurrente durante su ejecución.
-- ==============================================================================
VACUUM ANALYZE detalle_pedido;
