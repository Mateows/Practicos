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
