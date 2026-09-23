-- ============================================================================
-- TP5 Parte C: medicion de la vista materializada y de su REFRESH
-- (correccion posterior a la devolucion de la catedra).
--
-- Que mide, con la salida completa archivada en medir_refresh_parte_c_salida.txt:
--   1) Consulta del reporte sobre las tablas base vs. sobre la vista
--      materializada, 3 rondas intercaladas con EXPLAIN (ANALYZE, BUFFERS).
--   2) Costo de REFRESH MATERIALIZED VIEW contra REFRESH ... CONCURRENTLY,
--      3 rondas intercaladas medidas con \timing.
--   3) Que bloqueo toma cada REFRESH sobre la vista (pg_locks), dentro de
--      BEGIN...ROLLBACK.
--   4) Que ve un usuario entre dos REFRESH: se cancela un pedido PENDIENTE
--      dentro de BEGIN...ROLLBACK y se compara la vista (sin refrescar)
--      con la consulta directa, antes y despues del REFRESH.
--
-- Estado de la base al terminar: igual que al empezar. Los puntos 3 y 4
-- terminan en ROLLBACK; los REFRESH del punto 2 recalculan la vista con
-- los mismos datos, asi que su contenido no cambia.
-- Requiere: vista_materializada.sql ya ejecutado (vista + indice unico).
-- ============================================================================
\set ON_ERROR_STOP on
\pset pager off

SELECT count(*) AS filas_en_la_vista FROM mv_resumen_ventas_categoria_mes;

-- ---------------------------------------------------------------------------
-- 1) Tablas base vs. vista materializada (3 rondas intercaladas)
-- ---------------------------------------------------------------------------
\echo '=== RONDA 1 - consulta sobre las tablas base ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.id AS id_categoria, c.nombre AS categoria,
       date_trunc('month', p.fecha_hora) AS mes,
       COUNT(DISTINCT p.id) AS cantidad_pedidos,
       SUM(dp.cantidad) AS unidades_vendidas,
       SUM(dp.subtotal) AS facturacion_total
FROM pedido p
JOIN detalle_pedido dp ON dp.id_pedido = p.id
JOIN producto pr ON pr.id = dp.id_producto
JOIN categoria c ON c.id = pr.id_categoria
WHERE p.estado <> 'CANCELADO'
GROUP BY c.id, c.nombre, date_trunc('month', p.fecha_hora)
ORDER BY mes DESC, facturacion_total DESC;
\echo '=== RONDA 1 - consulta sobre la vista materializada ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM mv_resumen_ventas_categoria_mes
ORDER BY mes DESC, facturacion_total DESC;

\echo '=== RONDA 2 - consulta sobre las tablas base ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.id AS id_categoria, c.nombre AS categoria,
       date_trunc('month', p.fecha_hora) AS mes,
       COUNT(DISTINCT p.id) AS cantidad_pedidos,
       SUM(dp.cantidad) AS unidades_vendidas,
       SUM(dp.subtotal) AS facturacion_total
FROM pedido p
JOIN detalle_pedido dp ON dp.id_pedido = p.id
JOIN producto pr ON pr.id = dp.id_producto
JOIN categoria c ON c.id = pr.id_categoria
WHERE p.estado <> 'CANCELADO'
GROUP BY c.id, c.nombre, date_trunc('month', p.fecha_hora)
ORDER BY mes DESC, facturacion_total DESC;
\echo '=== RONDA 2 - consulta sobre la vista materializada ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM mv_resumen_ventas_categoria_mes
ORDER BY mes DESC, facturacion_total DESC;

\echo '=== RONDA 3 - consulta sobre las tablas base ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.id AS id_categoria, c.nombre AS categoria,
       date_trunc('month', p.fecha_hora) AS mes,
       COUNT(DISTINCT p.id) AS cantidad_pedidos,
       SUM(dp.cantidad) AS unidades_vendidas,
       SUM(dp.subtotal) AS facturacion_total
FROM pedido p
JOIN detalle_pedido dp ON dp.id_pedido = p.id
JOIN producto pr ON pr.id = dp.id_producto
JOIN categoria c ON c.id = pr.id_categoria
WHERE p.estado <> 'CANCELADO'
GROUP BY c.id, c.nombre, date_trunc('month', p.fecha_hora)
ORDER BY mes DESC, facturacion_total DESC;
\echo '=== RONDA 3 - consulta sobre la vista materializada ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM mv_resumen_ventas_categoria_mes
ORDER BY mes DESC, facturacion_total DESC;

-- ---------------------------------------------------------------------------
-- 2) Costo del REFRESH: normal vs. CONCURRENTLY (3 rondas intercaladas)
-- ---------------------------------------------------------------------------
\timing on
\echo '=== RONDA 1 - REFRESH MATERIALIZED VIEW ==='
REFRESH MATERIALIZED VIEW mv_resumen_ventas_categoria_mes;
\echo '=== RONDA 1 - REFRESH MATERIALIZED VIEW CONCURRENTLY ==='
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_resumen_ventas_categoria_mes;
\echo '=== RONDA 2 - REFRESH MATERIALIZED VIEW ==='
REFRESH MATERIALIZED VIEW mv_resumen_ventas_categoria_mes;
\echo '=== RONDA 2 - REFRESH MATERIALIZED VIEW CONCURRENTLY ==='
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_resumen_ventas_categoria_mes;
\echo '=== RONDA 3 - REFRESH MATERIALIZED VIEW ==='
REFRESH MATERIALIZED VIEW mv_resumen_ventas_categoria_mes;
\echo '=== RONDA 3 - REFRESH MATERIALIZED VIEW CONCURRENTLY ==='
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_resumen_ventas_categoria_mes;
\timing off

-- ---------------------------------------------------------------------------
-- 3) Bloqueo que toma cada REFRESH sobre la vista
--    AccessExclusiveLock bloquea tambien los SELECT de otros usuarios;
--    ExclusiveLock deja leer, pero no permite otro REFRESH ni escrituras.
-- ---------------------------------------------------------------------------
\echo '=== BLOQUEO - REFRESH MATERIALIZED VIEW ==='
BEGIN;
REFRESH MATERIALIZED VIEW mv_resumen_ventas_categoria_mes;
SELECT mode, granted
FROM pg_locks
WHERE relation = 'mv_resumen_ventas_categoria_mes'::regclass
  AND pid = pg_backend_pid()
ORDER BY mode;
ROLLBACK;

\echo '=== BLOQUEO - REFRESH MATERIALIZED VIEW CONCURRENTLY ==='
BEGIN;
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_resumen_ventas_categoria_mes;
SELECT mode, granted
FROM pg_locks
WHERE relation = 'mv_resumen_ventas_categoria_mes'::regclass
  AND pid = pg_backend_pid()
ORDER BY mode;
ROLLBACK;

-- ---------------------------------------------------------------------------
-- 4) Que ve el usuario entre dos REFRESH (todo dentro de BEGIN...ROLLBACK)
-- ---------------------------------------------------------------------------
\echo '=== DATO DESACTUALIZADO - se cancela un pedido PENDIENTE ==='
BEGIN;
SELECT id AS pedido_id, fecha_hora AS pedido_fecha,
       date_trunc('month', fecha_hora) AS pedido_mes
FROM pedido
WHERE estado = 'PENDIENTE' AND fecha_hora <= now()
ORDER BY fecha_hora DESC, id
LIMIT 1 \gset

\echo 'Pedido elegido:' :pedido_id 'del mes' :'pedido_mes'

\echo '--- Antes del cambio: vista y consulta directa coinciden ---'
SELECT 'vista' AS fuente, id_categoria, cantidad_pedidos, facturacion_total
FROM mv_resumen_ventas_categoria_mes
WHERE mes = :'pedido_mes'
UNION ALL
SELECT 'directa', pr.id_categoria, COUNT(DISTINCT p.id), SUM(dp.subtotal)
FROM pedido p
JOIN detalle_pedido dp ON dp.id_pedido = p.id
JOIN producto pr ON pr.id = dp.id_producto
WHERE p.estado <> 'CANCELADO'
  AND date_trunc('month', p.fecha_hora) = :'pedido_mes'
GROUP BY pr.id_categoria
ORDER BY id_categoria, fuente;

UPDATE pedido SET estado = 'CANCELADO' WHERE id = :pedido_id;

\echo '--- Despues del cambio, SIN REFRESH: la vista sigue mostrando el dato viejo ---'
SELECT 'vista' AS fuente, id_categoria, cantidad_pedidos, facturacion_total
FROM mv_resumen_ventas_categoria_mes
WHERE mes = :'pedido_mes'
UNION ALL
SELECT 'directa', pr.id_categoria, COUNT(DISTINCT p.id), SUM(dp.subtotal)
FROM pedido p
JOIN detalle_pedido dp ON dp.id_pedido = p.id
JOIN producto pr ON pr.id = dp.id_producto
WHERE p.estado <> 'CANCELADO'
  AND date_trunc('month', p.fecha_hora) = :'pedido_mes'
GROUP BY pr.id_categoria
ORDER BY id_categoria, fuente;

REFRESH MATERIALIZED VIEW mv_resumen_ventas_categoria_mes;

\echo '--- Despues del REFRESH: la vista vuelve a coincidir ---'
SELECT 'vista' AS fuente, id_categoria, cantidad_pedidos, facturacion_total
FROM mv_resumen_ventas_categoria_mes
WHERE mes = :'pedido_mes'
UNION ALL
SELECT 'directa', pr.id_categoria, COUNT(DISTINCT p.id), SUM(dp.subtotal)
FROM pedido p
JOIN detalle_pedido dp ON dp.id_pedido = p.id
JOIN producto pr ON pr.id = dp.id_producto
WHERE p.estado <> 'CANCELADO'
  AND date_trunc('month', p.fecha_hora) = :'pedido_mes'
GROUP BY pr.id_categoria
ORDER BY id_categoria, fuente;
ROLLBACK;

\echo '=== Verificacion final: el pedido sigue PENDIENTE y la vista igual ==='
SELECT id, estado FROM pedido WHERE id = :pedido_id;
SELECT count(*) AS filas_en_la_vista FROM mv_resumen_ventas_categoria_mes;
