-- ============================================================================
-- TP3 Parte 2 - Consultas candidatas a optimizar
-- Base: foodstore_tp3_carga
-- ============================================================================

-- Q1: Pedidos pendientes (panel de "pedidos por atender")
SELECT id, fecha_hora, forma_pago, id_cliente
FROM pedido
WHERE estado = 'PENDIENTE'
ORDER BY fecha_hora DESC
LIMIT 50;

-- Q2: Productos de una categoria en un rango de precio
SELECT id, nombre, precio_lista, stock
FROM producto
WHERE id_categoria = 1 AND precio_lista BETWEEN 1000 AND 3000
ORDER BY precio_lista;

-- Q3: Total facturado por cliente en un rango de fechas
SELECT c.id, c.nombre_completo, SUM(dp.subtotal) AS total_facturado
FROM cliente c
JOIN pedido p ON p.id_cliente = c.id
JOIN detalle_pedido dp ON dp.id_pedido = p.id
WHERE p.fecha_hora BETWEEN '2025-06-01' AND '2025-12-31'
GROUP BY c.id, c.nombre_completo
ORDER BY total_facturado DESC
LIMIT 20;
