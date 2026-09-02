BEGIN;

CREATE TEMP TABLE resultado_spec_1 AS
SELECT
    c.nombre,
    SUM(dp.subtotal) AS monto_total_vendido
FROM categoria AS c
JOIN producto AS p
    ON p.id_categoria = c.id
JOIN detalle_pedido AS dp
    ON dp.id_producto = p.id
JOIN pedido AS pe
    ON pe.id = dp.id_pedido
WHERE c.activo = TRUE
  AND pe.estado = 'ENTREGADO'
GROUP BY c.id, c.nombre
HAVING SUM(dp.subtotal) > 0
ORDER BY monto_total_vendido DESC;

CREATE TEMP TABLE resultado_spec_1_cte AS
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

SELECT 'Spec 1 - cantidad versión original' AS verificacion,
       COUNT(*) AS cantidad
FROM resultado_spec_1;

SELECT 'Spec 1 - cantidad versión CTE' AS verificacion,
       COUNT(*) AS cantidad
FROM resultado_spec_1_cte;

SELECT 'Spec 1 - filas solo en versión original' AS verificacion,
       COUNT(*) AS cantidad
FROM (
    SELECT nombre, monto_total_vendido FROM resultado_spec_1
    EXCEPT
    SELECT nombre, monto_total_vendido FROM resultado_spec_1_cte
) AS diferencias;

SELECT 'Spec 1 - filas solo en versión CTE' AS verificacion,
       COUNT(*) AS cantidad
FROM (
    SELECT nombre, monto_total_vendido FROM resultado_spec_1_cte
    EXCEPT
    SELECT nombre, monto_total_vendido FROM resultado_spec_1
) AS diferencias;

CREATE TEMP TABLE resultado_spec_2 AS
SELECT
    c.nombre_completo,
    c.email
FROM cliente AS c
WHERE c.id IN (
    SELECT p.id_cliente
    FROM pedido AS p
    GROUP BY p.id_cliente
    HAVING COUNT(*) > 3
)
ORDER BY c.nombre_completo ASC;

CREATE TEMP TABLE resultado_spec_2_join AS
SELECT
    c.nombre_completo,
    c.email
FROM cliente AS c
JOIN (
    SELECT id_cliente
    FROM pedido
    GROUP BY id_cliente
    HAVING COUNT(*) > 3
) AS clientes_frecuentes
    ON clientes_frecuentes.id_cliente = c.id
ORDER BY c.nombre_completo ASC;

SELECT 'Spec 2 - cantidad versión original' AS verificacion,
       COUNT(*) AS cantidad
FROM resultado_spec_2;

SELECT 'Spec 2 - cantidad versión JOIN' AS verificacion,
       COUNT(*) AS cantidad
FROM resultado_spec_2_join;

SELECT 'Spec 2 - filas solo en versión original' AS verificacion,
       COUNT(*) AS cantidad
FROM (
    SELECT nombre_completo, email FROM resultado_spec_2
    EXCEPT
    SELECT nombre_completo, email FROM resultado_spec_2_join
) AS diferencias;

SELECT 'Spec 2 - filas solo en versión JOIN' AS verificacion,
       COUNT(*) AS cantidad
FROM (
    SELECT nombre_completo, email FROM resultado_spec_2_join
    EXCEPT
    SELECT nombre_completo, email FROM resultado_spec_2
) AS diferencias;

ROLLBACK;
