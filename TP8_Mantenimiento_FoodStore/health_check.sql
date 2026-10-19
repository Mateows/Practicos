-- ==============================================================================
-- health_check.sql
-- Proyecto : FoodStore — UTN FRM · Base de Datos II
-- Propósito: Monitoreo del estado general de la base 'foodstore' en PostgreSQL 16.
-- Uso      : Ejecutar con psql -d foodstore -f health_check.sql
--            o pegar en pgAdmin > Query Tool conectado a 'foodstore'.
-- Frecuencia recomendada: diaria (ver SPEC_U6.md, Tarea 2).
-- ==============================================================================

-- ==============================================================================
-- CONSULTA 1 — Tamaño de la base de datos
-- Objetivo: confirmar que el volumen de datos es coherente con lo esperado y
--           detectar crecimientos anómalos entre ejecuciones sucesivas.
-- ==============================================================================
SELECT
    datname                          AS base,
    pg_size_pretty(pg_database_size(datname)) AS tamanio
FROM pg_database
WHERE datname = 'foodstore';


-- ==============================================================================
-- CONSULTA 2 — Estadísticas de conexiones activas
-- Objetivo: detectar acumulación de conexiones que puedan indicar connection leaks
--           o saturación del pool.
-- ==============================================================================
SELECT
    datname                          AS base,
    numbackends                      AS conexiones_activas,
    xact_commit                      AS transacciones_confirmadas,
    xact_rollback                    AS transacciones_revertidas,
    blks_read                        AS bloques_leidos_disco,
    blks_hit                         AS bloques_desde_cache,
    ROUND(
        blks_hit::NUMERIC
        / NULLIF(blks_hit + blks_read, 0) * 100, 2
    )                                AS cache_hit_ratio_pct
FROM pg_stat_database
WHERE datname = 'foodstore';


-- ==============================================================================
-- CONSULTA 3 — Tuplas muertas por tabla (bloat de heap)
-- Objetivo: identificar tablas con mayor acumulación de versiones obsoletas (dead
--           tuples) para priorizar el mantenimiento con VACUUM. Un ratio de tuplas
--           muertas superior al 10 % sobre las vivas es señal de alerta.
-- ==============================================================================
SELECT
    schemaname                       AS esquema,
    relname                          AS tabla,
    n_live_tup                       AS tuplas_vivas,
    n_dead_tup                       AS tuplas_muertas,
    CASE
        WHEN n_live_tup = 0 THEN NULL
        ELSE ROUND(n_dead_tup::NUMERIC / n_live_tup * 100, 2)
    END                              AS ratio_muertas_pct,
    last_vacuum                      AS ultimo_vacuum,
    last_autovacuum                  AS ultimo_autovacuum,
    last_analyze                     AS ultimo_analyze,
    last_autoanalyze                 AS ultimo_autoanalyze
FROM pg_stat_user_tables
ORDER BY n_dead_tup DESC;


-- ==============================================================================
-- CONSULTA 4 — Consultas activas con duración (excluye conexiones idle)
-- Objetivo: detectar consultas de larga duración que puedan estar bloqueando
--           recursos o indicando problemas en la aplicación.
-- Nota    : En producción se puede filtrar por duration > interval '5 minutes'
--           para reducir el ruido.
-- ==============================================================================
SELECT
    pid                              AS proceso_id,
    usename                          AS usuario,
    application_name                 AS aplicacion,
    client_addr                      AS ip_cliente,
    state                            AS estado,
    wait_event_type                  AS tipo_espera,
    wait_event                       AS evento_espera,
    now() - query_start              AS duracion,
    LEFT(query, 120)                 AS consulta_truncada
FROM pg_stat_activity
WHERE datname = 'foodstore'
  AND state <> 'idle'
ORDER BY duracion DESC NULLS LAST;
