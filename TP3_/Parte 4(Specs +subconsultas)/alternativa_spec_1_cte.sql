-- Alternativa Spec 1 — CTE
-- Misma respuesta que solucion_spec_1_agregacion.sql.
-- Diferencia estructural: preagrega los montos por categoría en una CTE
-- antes de unirse a la tabla categoria, en lugar de encadenar 4 JOINs.

WITH ventas_por_categoria AS (
    SELECT
        p.id_categoria,
        SUM(dp.subtotal) AS monto_total_vendido
    FROM detalle_pedido AS dp
    JOIN pedido AS pe
        ON pe.id = dp.id_pedido
    JOIN producto AS p
        ON p.id = dp.id_producto
    WHERE pe.estado = 'ENTREGADO'
    GROUP BY p.id_categoria
    HAVING SUM(dp.subtotal) > 0
)
SELECT
    c.nombre,
    vpc.monto_total_vendido
FROM categoria AS c
JOIN ventas_por_categoria AS vpc
    ON vpc.id_categoria = c.id
WHERE c.activo = TRUE
ORDER BY vpc.monto_total_vendido DESC;
