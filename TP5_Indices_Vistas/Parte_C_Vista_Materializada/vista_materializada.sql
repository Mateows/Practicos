-- ============================================================
-- Parte C - Vista materializada
-- Base: foodstore_tp3_carga
-- Objetivo: resumir facturación por categoría y mes para reportes
-- ============================================================

-- 1) Crear vista materializada
CREATE MATERIALIZED VIEW mv_resumen_ventas_categoria_mes AS
SELECT
    c.id AS id_categoria,
    c.nombre AS categoria,
    date_trunc('month', p.fecha_hora) AS mes,
    COUNT(DISTINCT p.id) AS cantidad_pedidos,
    SUM(dp.cantidad) AS unidades_vendidas,
    SUM(dp.subtotal) AS facturacion_total
FROM pedido p
JOIN detalle_pedido dp ON dp.id_pedido = p.id
JOIN producto pr ON pr.id = dp.id_producto
JOIN categoria c ON c.id = pr.id_categoria
WHERE p.estado <> 'CANCELADO'
GROUP BY c.id, c.nombre, date_trunc('month', p.fecha_hora)
WITH DATA;

-- 2) Índice para acelerar filtros por categoría y fecha
CREATE UNIQUE INDEX idx_mv_resumen_ventas_categoria_mes
    ON mv_resumen_ventas_categoria_mes (id_categoria, mes);

-- 3) Cargar los datos iniciales
REFRESH MATERIALIZED VIEW mv_resumen_ventas_categoria_mes;

-- 4) Consultas de uso
SELECT *
FROM mv_resumen_ventas_categoria_mes
ORDER BY mes DESC, facturacion_total DESC;

SELECT categoria, mes, facturacion_total
FROM mv_resumen_ventas_categoria_mes
WHERE id_categoria = 1
ORDER BY mes DESC;

-- 5) Renovación periódica de la vista materializada
-- En producción suele usarse:
-- REFRESH MATERIALIZED VIEW CONCURRENTLY mv_resumen_ventas_categoria_mes;
-- y se ejecuta en un cron o job de ETL/reportes.
