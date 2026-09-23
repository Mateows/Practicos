-- Remedicion de Q5 (Caso 1) con la salida archivada.
-- Las 9 corridas originales del control de ruido (3 escenarios x 3 rondas)
-- no habian quedado guardadas en ningun archivo. Este script las repite:
-- en cada ronda corre Q5 en los 3 escenarios, en el mismo orden que la
-- medicion original:
--   Baseline : sin cambios.
--   Indice A : idx_pedido_no_cancelado_cliente creado dentro de
--              BEGIN...ROLLBACK (no queda aplicado).
--   work_mem : SET LOCAL work_mem = '16MB' dentro de BEGIN...ROLLBACK.
-- No modifica la base: todo lo que se crea o cambia se deshace.
\set ON_ERROR_STOP on

\echo '=== RONDA 1 - BASELINE ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    c.nombre_completo,
    SUM(dp.subtotal) AS total_gastado,
    DENSE_RANK() OVER (ORDER BY SUM(dp.subtotal) DESC) AS puesto
FROM cliente c
JOIN pedido p ON p.id_cliente = c.id AND p.estado <> 'CANCELADO'
JOIN detalle_pedido dp ON dp.id_pedido = p.id
GROUP BY c.id, c.nombre_completo
ORDER BY puesto;

\echo '=== RONDA 1 - INDICE A (idx_pedido_no_cancelado_cliente, dentro de BEGIN...ROLLBACK) ==='
BEGIN;
CREATE INDEX idx_pedido_no_cancelado_cliente
    ON pedido (id_cliente)
    WHERE estado <> 'CANCELADO';
ANALYZE pedido;
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    c.nombre_completo,
    SUM(dp.subtotal) AS total_gastado,
    DENSE_RANK() OVER (ORDER BY SUM(dp.subtotal) DESC) AS puesto
FROM cliente c
JOIN pedido p ON p.id_cliente = c.id AND p.estado <> 'CANCELADO'
JOIN detalle_pedido dp ON dp.id_pedido = p.id
GROUP BY c.id, c.nombre_completo
ORDER BY puesto;
ROLLBACK;

\echo '=== RONDA 1 - WORK_MEM = 16MB (dentro de BEGIN...ROLLBACK) ==='
BEGIN;
SET LOCAL work_mem = '16MB';
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    c.nombre_completo,
    SUM(dp.subtotal) AS total_gastado,
    DENSE_RANK() OVER (ORDER BY SUM(dp.subtotal) DESC) AS puesto
FROM cliente c
JOIN pedido p ON p.id_cliente = c.id AND p.estado <> 'CANCELADO'
JOIN detalle_pedido dp ON dp.id_pedido = p.id
GROUP BY c.id, c.nombre_completo
ORDER BY puesto;
ROLLBACK;

\echo '=== RONDA 2 - BASELINE ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    c.nombre_completo,
    SUM(dp.subtotal) AS total_gastado,
    DENSE_RANK() OVER (ORDER BY SUM(dp.subtotal) DESC) AS puesto
FROM cliente c
JOIN pedido p ON p.id_cliente = c.id AND p.estado <> 'CANCELADO'
JOIN detalle_pedido dp ON dp.id_pedido = p.id
GROUP BY c.id, c.nombre_completo
ORDER BY puesto;

\echo '=== RONDA 2 - INDICE A (idx_pedido_no_cancelado_cliente, dentro de BEGIN...ROLLBACK) ==='
BEGIN;
CREATE INDEX idx_pedido_no_cancelado_cliente
    ON pedido (id_cliente)
    WHERE estado <> 'CANCELADO';
ANALYZE pedido;
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    c.nombre_completo,
    SUM(dp.subtotal) AS total_gastado,
    DENSE_RANK() OVER (ORDER BY SUM(dp.subtotal) DESC) AS puesto
FROM cliente c
JOIN pedido p ON p.id_cliente = c.id AND p.estado <> 'CANCELADO'
JOIN detalle_pedido dp ON dp.id_pedido = p.id
GROUP BY c.id, c.nombre_completo
ORDER BY puesto;
ROLLBACK;

\echo '=== RONDA 2 - WORK_MEM = 16MB (dentro de BEGIN...ROLLBACK) ==='
BEGIN;
SET LOCAL work_mem = '16MB';
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    c.nombre_completo,
    SUM(dp.subtotal) AS total_gastado,
    DENSE_RANK() OVER (ORDER BY SUM(dp.subtotal) DESC) AS puesto
FROM cliente c
JOIN pedido p ON p.id_cliente = c.id AND p.estado <> 'CANCELADO'
JOIN detalle_pedido dp ON dp.id_pedido = p.id
GROUP BY c.id, c.nombre_completo
ORDER BY puesto;
ROLLBACK;

\echo '=== RONDA 3 - BASELINE ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    c.nombre_completo,
    SUM(dp.subtotal) AS total_gastado,
    DENSE_RANK() OVER (ORDER BY SUM(dp.subtotal) DESC) AS puesto
FROM cliente c
JOIN pedido p ON p.id_cliente = c.id AND p.estado <> 'CANCELADO'
JOIN detalle_pedido dp ON dp.id_pedido = p.id
GROUP BY c.id, c.nombre_completo
ORDER BY puesto;

\echo '=== RONDA 3 - INDICE A (idx_pedido_no_cancelado_cliente, dentro de BEGIN...ROLLBACK) ==='
BEGIN;
CREATE INDEX idx_pedido_no_cancelado_cliente
    ON pedido (id_cliente)
    WHERE estado <> 'CANCELADO';
ANALYZE pedido;
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    c.nombre_completo,
    SUM(dp.subtotal) AS total_gastado,
    DENSE_RANK() OVER (ORDER BY SUM(dp.subtotal) DESC) AS puesto
FROM cliente c
JOIN pedido p ON p.id_cliente = c.id AND p.estado <> 'CANCELADO'
JOIN detalle_pedido dp ON dp.id_pedido = p.id
GROUP BY c.id, c.nombre_completo
ORDER BY puesto;
ROLLBACK;

\echo '=== RONDA 3 - WORK_MEM = 16MB (dentro de BEGIN...ROLLBACK) ==='
BEGIN;
SET LOCAL work_mem = '16MB';
EXPLAIN (ANALYZE, BUFFERS)
SELECT
    c.nombre_completo,
    SUM(dp.subtotal) AS total_gastado,
    DENSE_RANK() OVER (ORDER BY SUM(dp.subtotal) DESC) AS puesto
FROM cliente c
JOIN pedido p ON p.id_cliente = c.id AND p.estado <> 'CANCELADO'
JOIN detalle_pedido dp ON dp.id_pedido = p.id
GROUP BY c.id, c.nombre_completo
ORDER BY puesto;
ROLLBACK;