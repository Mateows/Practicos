-- ============================================================================
-- queries.sql — Consultas de negocio y analíticas (heredadas de Semanas 3 y 4)
-- Base: foodstore_tp3_carga
--
-- Estas son las consultas reales ya trabajadas en TP3 (laboratorio de
-- EXPLAIN ANALYZE) y TP4 (reportes analíticos con joins/rankings). Se
-- consolidan acá para servir de carga de trabajo real a indexar en la
-- Parte A de este trabajo, tal como pide la consigna.
-- ============================================================================

-- Q1 (TP3): Pedidos pendientes (panel de "pedidos por atender")
SELECT id, fecha_hora, forma_pago, id_cliente
FROM pedido
WHERE estado = 'PENDIENTE'
ORDER BY fecha_hora DESC
LIMIT 50;

-- Q2 (TP3): Productos de una categoria en un rango de precio
SELECT id, nombre, precio_lista, stock
FROM producto
WHERE id_categoria = 1 AND precio_lista BETWEEN 1000 AND 3000
ORDER BY precio_lista;

-- Q3 (TP3): Total facturado por cliente en un rango de fechas
SELECT c.id, c.nombre_completo, SUM(dp.subtotal) AS total_facturado
FROM cliente c
JOIN pedido p ON p.id_cliente = c.id
JOIN detalle_pedido dp ON dp.id_pedido = p.id
WHERE p.fecha_hora BETWEEN '2025-06-01' AND '2025-12-31'
GROUP BY c.id, c.nombre_completo
ORDER BY total_facturado DESC
LIMIT 20;

-- Q4 (TP4 Parte 4): Top 3 productos por facturacion dentro de cada
-- categoria (ultimos 6 meses) - la consulta de competencia
WITH ventas_producto AS (
    SELECT cat.id AS id_categoria, cat.nombre AS categoria,
           p.id AS id_producto, p.nombre AS producto,
           SUM(dp.cantidad) AS unidades_vendidas,
           SUM(dp.subtotal) AS facturacion_producto
    FROM categoria cat
    JOIN producto p ON p.id_categoria = cat.id
    JOIN detalle_pedido dp ON dp.id_producto = p.id
    JOIN pedido ped ON ped.id = dp.id_pedido
    WHERE ped.estado <> 'CANCELADO'
      AND ped.fecha_hora >= now() - interval '6 months'
      AND cat.activo = TRUE AND p.activo = TRUE
    GROUP BY cat.id, cat.nombre, p.id, p.nombre
),
ranking AS (
    SELECT categoria, producto, unidades_vendidas, facturacion_producto,
           ROUND(100.0 * facturacion_producto / SUM(facturacion_producto) OVER (PARTITION BY id_categoria), 2) AS pct_de_su_categoria,
           RANK() OVER (PARTITION BY id_categoria ORDER BY facturacion_producto DESC) AS ranking_en_categoria
    FROM ventas_producto
)
SELECT * FROM ranking WHERE ranking_en_categoria <= 3 ORDER BY categoria, ranking_en_categoria;

-- Q5 (TP4 Parte 3): Ranking de clientes por gasto total (funcion de ventana)
SELECT
    c.nombre_completo,
    SUM(dp.subtotal) AS total_gastado,
    DENSE_RANK() OVER (ORDER BY SUM(dp.subtotal) DESC) AS puesto
FROM cliente c
JOIN pedido p ON p.id_cliente = c.id AND p.estado <> 'CANCELADO'
JOIN detalle_pedido dp ON dp.id_pedido = p.id
GROUP BY c.id, c.nombre_completo
ORDER BY puesto;

-- Q6 (TP4 Parte 3): Productos con precio superior al promedio de su
-- categoria (subconsulta correlacionada)
SELECT p.nombre, p.precio_lista
FROM producto p
JOIN categoria cat ON cat.id = p.id_categoria AND cat.activo = TRUE
WHERE p.activo = TRUE
  AND p.precio_lista > (
      SELECT AVG(p2.precio_lista)
      FROM producto p2
      WHERE p2.activo = TRUE AND p2.id_categoria = p.id_categoria
  )
ORDER BY cat.id, p.precio_lista DESC;