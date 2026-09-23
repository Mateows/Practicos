-- Medicion reproducible de Q4 con control de ruido (3 rondas intercaladas)
-- para resolver la contradiccion detectada en la auditoria: el informe
-- decia +8.9% (371.5 -> 338.5 ms) pero plan_q4_antes.txt (378 ms) y
-- plan_q4_despues.txt (414 ms) mostraban lo contrario, y las 3 rondas
-- nunca habian quedado archivadas como salida real.
--
-- idx_pedido_fecha_hora_btree ya esta aplicado en firme sobre
-- foodstore_tp3_carga. Para medir "antes" de verdad se lo elimina y se
-- lo vuelve a crear dentro de la misma sesion, dejando la base en el
-- mismo estado en el que estaba al terminar el script (indice presente).
-- Respaldo previo: TP2_Concurrencia_IA/respaldo_foodstore_tp3_carga_antes_q4_rondas.sql
--
-- NOTA (estado actual, 23/09): despues de esta medicion el indice se
-- DESCARTO y se elimino de la base. Para reproducir: crearlo antes de
-- correr el script y, al terminar, ejecutar
--   DROP INDEX idx_pedido_fecha_hora_btree; ANALYZE pedido;
-- (ver README.md del TP5, seccion 5). El respaldo citado arriba no esta
-- versionado: .gitignore excluye TP2_Concurrencia_IA/respaldo_*.sql.
\set ON_ERROR_STOP on
\timing on

\echo '=== RONDA 1 - ANTES (sin indice) ==='
BEGIN;
DROP INDEX idx_pedido_fecha_hora_btree;
COMMIT;
ANALYZE pedido;
EXPLAIN (ANALYZE, BUFFERS)
WITH ventas_producto AS (
    SELECT cat.id AS id_categoria, cat.nombre AS categoria,
           p.id AS id_producto, p.nombre AS producto,
           SUM(dp.cantidad) AS unidades_vendidas,
           SUM(dp.subtotal) AS facturacion_producto
    FROM categoria AS cat
    JOIN producto AS p ON p.id_categoria = cat.id
    JOIN detalle_pedido AS dp ON dp.id_producto = p.id
    JOIN pedido AS ped ON ped.id = dp.id_pedido
    WHERE ped.estado <> 'CANCELADO'
      AND ped.fecha_hora >= now() - interval '6 months'
      AND cat.activo = TRUE
      AND p.activo = TRUE
    GROUP BY cat.id, cat.nombre, p.id, p.nombre
), ranking AS (
    SELECT categoria, producto, unidades_vendidas, facturacion_producto,
           ROUND(100.0 * facturacion_producto /
                 SUM(facturacion_producto) OVER (PARTITION BY id_categoria), 2)
                 AS pct_de_su_categoria,
           RANK() OVER (
               PARTITION BY id_categoria
               ORDER BY facturacion_producto DESC
           ) AS ranking_en_categoria
    FROM ventas_producto
)
SELECT * FROM ranking WHERE ranking_en_categoria <= 3
ORDER BY categoria, ranking_en_categoria;

\echo '=== RONDA 1 - DESPUES (con indice) ==='
BEGIN;
CREATE INDEX idx_pedido_fecha_hora_btree ON pedido (fecha_hora DESC);
COMMIT;
ANALYZE pedido;
EXPLAIN (ANALYZE, BUFFERS)
WITH ventas_producto AS (
    SELECT cat.id AS id_categoria, cat.nombre AS categoria,
           p.id AS id_producto, p.nombre AS producto,
           SUM(dp.cantidad) AS unidades_vendidas,
           SUM(dp.subtotal) AS facturacion_producto
    FROM categoria AS cat
    JOIN producto AS p ON p.id_categoria = cat.id
    JOIN detalle_pedido AS dp ON dp.id_producto = p.id
    JOIN pedido AS ped ON ped.id = dp.id_pedido
    WHERE ped.estado <> 'CANCELADO'
      AND ped.fecha_hora >= now() - interval '6 months'
      AND cat.activo = TRUE
      AND p.activo = TRUE
    GROUP BY cat.id, cat.nombre, p.id, p.nombre
), ranking AS (
    SELECT categoria, producto, unidades_vendidas, facturacion_producto,
           ROUND(100.0 * facturacion_producto /
                 SUM(facturacion_producto) OVER (PARTITION BY id_categoria), 2)
                 AS pct_de_su_categoria,
           RANK() OVER (
               PARTITION BY id_categoria
               ORDER BY facturacion_producto DESC
           ) AS ranking_en_categoria
    FROM ventas_producto
)
SELECT * FROM ranking WHERE ranking_en_categoria <= 3
ORDER BY categoria, ranking_en_categoria;

\echo '=== RONDA 2 - ANTES (sin indice) ==='
BEGIN;
DROP INDEX idx_pedido_fecha_hora_btree;
COMMIT;
ANALYZE pedido;
EXPLAIN (ANALYZE, BUFFERS)
WITH ventas_producto AS (
    SELECT cat.id AS id_categoria, cat.nombre AS categoria,
           p.id AS id_producto, p.nombre AS producto,
           SUM(dp.cantidad) AS unidades_vendidas,
           SUM(dp.subtotal) AS facturacion_producto
    FROM categoria AS cat
    JOIN producto AS p ON p.id_categoria = cat.id
    JOIN detalle_pedido AS dp ON dp.id_producto = p.id
    JOIN pedido AS ped ON ped.id = dp.id_pedido
    WHERE ped.estado <> 'CANCELADO'
      AND ped.fecha_hora >= now() - interval '6 months'
      AND cat.activo = TRUE
      AND p.activo = TRUE
    GROUP BY cat.id, cat.nombre, p.id, p.nombre
), ranking AS (
    SELECT categoria, producto, unidades_vendidas, facturacion_producto,
           ROUND(100.0 * facturacion_producto /
                 SUM(facturacion_producto) OVER (PARTITION BY id_categoria), 2)
                 AS pct_de_su_categoria,
           RANK() OVER (
               PARTITION BY id_categoria
               ORDER BY facturacion_producto DESC
           ) AS ranking_en_categoria
    FROM ventas_producto
)
SELECT * FROM ranking WHERE ranking_en_categoria <= 3
ORDER BY categoria, ranking_en_categoria;

\echo '=== RONDA 2 - DESPUES (con indice) ==='
BEGIN;
CREATE INDEX idx_pedido_fecha_hora_btree ON pedido (fecha_hora DESC);
COMMIT;
ANALYZE pedido;
EXPLAIN (ANALYZE, BUFFERS)
WITH ventas_producto AS (
    SELECT cat.id AS id_categoria, cat.nombre AS categoria,
           p.id AS id_producto, p.nombre AS producto,
           SUM(dp.cantidad) AS unidades_vendidas,
           SUM(dp.subtotal) AS facturacion_producto
    FROM categoria AS cat
    JOIN producto AS p ON p.id_categoria = cat.id
    JOIN detalle_pedido AS dp ON dp.id_producto = p.id
    JOIN pedido AS ped ON ped.id = dp.id_pedido
    WHERE ped.estado <> 'CANCELADO'
      AND ped.fecha_hora >= now() - interval '6 months'
      AND cat.activo = TRUE
      AND p.activo = TRUE
    GROUP BY cat.id, cat.nombre, p.id, p.nombre
), ranking AS (
    SELECT categoria, producto, unidades_vendidas, facturacion_producto,
           ROUND(100.0 * facturacion_producto /
                 SUM(facturacion_producto) OVER (PARTITION BY id_categoria), 2)
                 AS pct_de_su_categoria,
           RANK() OVER (
               PARTITION BY id_categoria
               ORDER BY facturacion_producto DESC
           ) AS ranking_en_categoria
    FROM ventas_producto
)
SELECT * FROM ranking WHERE ranking_en_categoria <= 3
ORDER BY categoria, ranking_en_categoria;

\echo '=== RONDA 3 - ANTES (sin indice) ==='
BEGIN;
DROP INDEX idx_pedido_fecha_hora_btree;
COMMIT;
ANALYZE pedido;
EXPLAIN (ANALYZE, BUFFERS)
WITH ventas_producto AS (
    SELECT cat.id AS id_categoria, cat.nombre AS categoria,
           p.id AS id_producto, p.nombre AS producto,
           SUM(dp.cantidad) AS unidades_vendidas,
           SUM(dp.subtotal) AS facturacion_producto
    FROM categoria AS cat
    JOIN producto AS p ON p.id_categoria = cat.id
    JOIN detalle_pedido AS dp ON dp.id_producto = p.id
    JOIN pedido AS ped ON ped.id = dp.id_pedido
    WHERE ped.estado <> 'CANCELADO'
      AND ped.fecha_hora >= now() - interval '6 months'
      AND cat.activo = TRUE
      AND p.activo = TRUE
    GROUP BY cat.id, cat.nombre, p.id, p.nombre
), ranking AS (
    SELECT categoria, producto, unidades_vendidas, facturacion_producto,
           ROUND(100.0 * facturacion_producto /
                 SUM(facturacion_producto) OVER (PARTITION BY id_categoria), 2)
                 AS pct_de_su_categoria,
           RANK() OVER (
               PARTITION BY id_categoria
               ORDER BY facturacion_producto DESC
           ) AS ranking_en_categoria
    FROM ventas_producto
)
SELECT * FROM ranking WHERE ranking_en_categoria <= 3
ORDER BY categoria, ranking_en_categoria;

\echo '=== RONDA 3 - DESPUES (con indice) ==='
BEGIN;
CREATE INDEX idx_pedido_fecha_hora_btree ON pedido (fecha_hora DESC);
COMMIT;
ANALYZE pedido;
EXPLAIN (ANALYZE, BUFFERS)
WITH ventas_producto AS (
    SELECT cat.id AS id_categoria, cat.nombre AS categoria,
           p.id AS id_producto, p.nombre AS producto,
           SUM(dp.cantidad) AS unidades_vendidas,
           SUM(dp.subtotal) AS facturacion_producto
    FROM categoria AS cat
    JOIN producto AS p ON p.id_categoria = cat.id
    JOIN detalle_pedido AS dp ON dp.id_producto = p.id
    JOIN pedido AS ped ON ped.id = dp.id_pedido
    WHERE ped.estado <> 'CANCELADO'
      AND ped.fecha_hora >= now() - interval '6 months'
      AND cat.activo = TRUE
      AND p.activo = TRUE
    GROUP BY cat.id, cat.nombre, p.id, p.nombre
), ranking AS (
    SELECT categoria, producto, unidades_vendidas, facturacion_producto,
           ROUND(100.0 * facturacion_producto /
                 SUM(facturacion_producto) OVER (PARTITION BY id_categoria), 2)
                 AS pct_de_su_categoria,
           RANK() OVER (
               PARTITION BY id_categoria
               ORDER BY facturacion_producto DESC
           ) AS ranking_en_categoria
    FROM ventas_producto
)
SELECT * FROM ranking WHERE ranking_en_categoria <= 3
ORDER BY categoria, ranking_en_categoria;

-- Verificacion final: el indice debe seguir existiendo al terminar
-- (mismo estado en el que estaba la base antes de correr este script).
\echo '=== Verificacion: el indice quedo aplicado en firme ==='
SELECT indexname FROM pg_indexes WHERE indexname = 'idx_pedido_fecha_hora_btree';
