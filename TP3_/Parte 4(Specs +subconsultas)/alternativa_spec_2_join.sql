-- Alternativa Spec 2 — JOIN con subquery en FROM
-- Misma respuesta que solucion_spec_2_subconsulta.sql.
-- Diferencia estructural: en lugar de WHERE id IN (subconsulta),
-- la subquery vive en el FROM como tabla derivada y se une con JOIN.

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
