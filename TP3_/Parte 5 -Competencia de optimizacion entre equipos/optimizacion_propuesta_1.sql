-- ============================================================================
-- TP3 Parte 5 — Propuesta 1: índice sobre pedido(estado)
-- Justificación: el plan baseline muestra un Parallel Seq Scan on pedido
-- que lee 200.005 filas y descarta 150.372 (75%) por el filtro estado='ENTREGADO'.
-- Un índice sobre (estado) permite al planificador usar Bitmap Index Scan
-- y leer solo las ~50k filas ENTREGADAS directamente.
-- Riesgo conocido: en la Parte 2 (Q3) un índice sobre pedido eliminó el
-- paralelismo y empeoró el tiempo real. Hay que medir antes de aceptar.
-- ============================================================================

BEGIN;

CREATE INDEX idx_p5_pedido_estado ON pedido (estado);

-- Forzar actualización de estadísticas para que el planificador vea el índice
ANALYZE pedido;

-- Medir el efecto sobre la consulta base
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

-- Si el tiempo real bajó respecto del baseline (286.909 ms): COMMIT
-- Si empeoró o no cambió: ROLLBACK
-- >>> DECIDIR ANTES DE EJECUTAR LA SIGUIENTE LÍNEA <<<
ROLLBACK;
