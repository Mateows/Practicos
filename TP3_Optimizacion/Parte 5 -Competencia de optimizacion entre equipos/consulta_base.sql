-- ============================================================================
-- TP3 Parte 5 — Competencia de optimización entre equipos
-- Archivo: consulta_base.sql
-- Base: foodstore_tp3_carga
-- Descripción: Consulta lenta base (sin índices adicionales) que sirve como
--              punto de partida de la competencia. Obtiene el ranking de los
--              10 productos más vendidos (por unidades) en pedidos ENTREGADOS,
--              considerando solo productos activos.
--
-- PASO 1 — Medir el baseline ANTES de cualquier cambio:
--   psql -U postgres -d foodstore_tp3_carga -f consulta_base.sql
-- ============================================================================

EXPLAIN ANALYZE
SELECT
    p.nombre,
    c.nombre AS categoria,
    SUM(dp.cantidad) AS total_unidades_vendidas
FROM detalle_pedido AS dp
JOIN producto AS p
    ON p.id = dp.id_producto
JOIN categoria AS c
    ON c.id = p.id_categoria
JOIN pedido AS pe
    ON pe.id = dp.id_pedido
WHERE pe.estado = 'ENTREGADO'
  AND p.activo = TRUE
GROUP BY p.id, p.nombre, c.id, c.nombre
ORDER BY total_unidades_vendidas DESC
LIMIT 10;
