-- Medicion del costo de escritura en detalle_pedido (consigna, Parte A, punto 5):
-- 500 INSERT en detalle_pedido SIN y CON los dos indices aceptados del
-- TP5 (idx_producto_categoria_precio_activo e idx_producto_categoria_precio,
-- ambos sobre producto).
--
-- Ninguno de los dos indices vive en detalle_pedido: un INSERT ahi solo
-- mantiene los indices de detalle_pedido y verifica las FK contra las PK
-- de pedido y producto. Lo esperable es que el tiempo no cambie; se mide
-- igual porque es lo que pide la consigna.
--
-- 1 ronda de calentamiento (no se cuenta) + 3 rondas intercaladas.
-- Cada carga termina con ROLLBACK. En las rondas "sin indices", los dos
-- DROP INDEX van dentro de la misma transaccion que el INSERT, asi que el
-- ROLLBACK tambien los restaura: la base nunca queda sin los indices.
\set ON_ERROR_STOP on
\timing on

\echo '=== Preparacion: 500 pares (id_pedido, id_producto) validos que todavia no existen ==='
CREATE TEMP TABLE tp5_muestra_detalle AS
SELECT p.id AS id_pedido, pr.id AS id_producto, pr.precio_lista AS precio_unitario
FROM pedido AS p
CROSS JOIN LATERAL (
    SELECT id, precio_lista
    FROM producto
    ORDER BY id
    OFFSET ((p.id - 1) % 500)::integer
    LIMIT 1
) AS pr
WHERE NOT EXISTS (
    SELECT 1 FROM detalle_pedido AS dp
    WHERE dp.id_pedido = p.id AND dp.id_producto = pr.id
)
ORDER BY p.id
LIMIT 500;

SELECT count(*) AS filas_muestra FROM tp5_muestra_detalle;

\echo '=== CALENTAMIENTO (no se cuenta) ==='
BEGIN;
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT id_pedido, id_producto, 1, precio_unitario FROM tp5_muestra_detalle;
ROLLBACK;

\echo '=== RONDA 1 - ANTES (sin los 2 indices de TP5) ==='
BEGIN;
DROP INDEX idx_producto_categoria_precio_activo;
DROP INDEX idx_producto_categoria_precio;
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT id_pedido, id_producto, 1, precio_unitario FROM tp5_muestra_detalle;
ROLLBACK;

\echo '=== RONDA 1 - DESPUES (con los 2 indices de TP5) ==='
BEGIN;
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT id_pedido, id_producto, 1, precio_unitario FROM tp5_muestra_detalle;
ROLLBACK;

\echo '=== RONDA 2 - ANTES (sin los 2 indices de TP5) ==='
BEGIN;
DROP INDEX idx_producto_categoria_precio_activo;
DROP INDEX idx_producto_categoria_precio;
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT id_pedido, id_producto, 1, precio_unitario FROM tp5_muestra_detalle;
ROLLBACK;

\echo '=== RONDA 2 - DESPUES (con los 2 indices de TP5) ==='
BEGIN;
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT id_pedido, id_producto, 1, precio_unitario FROM tp5_muestra_detalle;
ROLLBACK;

\echo '=== RONDA 3 - ANTES (sin los 2 indices de TP5) ==='
BEGIN;
DROP INDEX idx_producto_categoria_precio_activo;
DROP INDEX idx_producto_categoria_precio;
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT id_pedido, id_producto, 1, precio_unitario FROM tp5_muestra_detalle;
ROLLBACK;

\echo '=== RONDA 3 - DESPUES (con los 2 indices de TP5) ==='
BEGIN;
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT id_pedido, id_producto, 1, precio_unitario FROM tp5_muestra_detalle;
ROLLBACK;

\echo '=== Verificacion: los indices de producto siguen todos presentes ==='
SELECT indexname FROM pg_indexes WHERE tablename = 'producto' ORDER BY indexname;