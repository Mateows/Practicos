-- Demostracion de que idx_detalle_pedido_id_pedido es redundante con
-- pk_detalle_pedido (id_pedido, id_producto): la PK compuesta ya sirve
-- como indice utilizable por id_pedido solo, al ser su primera columna.
-- Segundo descarte por sobreindexacion de la Parte A (indice redundante
-- con otro ya existente). Todo dentro de una transaccion reversible.
\set ON_ERROR_STOP on

BEGIN;

\echo '=== Indices existentes sobre detalle_pedido antes de crear el candidato ==='
SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'detalle_pedido';

CREATE INDEX idx_detalle_pedido_id_pedido ON detalle_pedido (id_pedido);
ANALYZE detalle_pedido;

\echo '=== Q5 con el candidato presente (deberia elegir la PK o el candidato, nunca los dos) ==='
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

-- Sin el candidato (estado real de la base): confirmar que la PK ya
-- resuelve el join por id_pedido sin necesidad del indice nuevo.
\echo '=== Q5 sin el candidato (solo con pk_detalle_pedido) ==='
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
