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
