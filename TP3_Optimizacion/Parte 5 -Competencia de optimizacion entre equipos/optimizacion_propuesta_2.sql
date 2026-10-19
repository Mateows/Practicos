-- ============================================================================
-- TP3 Parte 5 — Propuesta 2: índice parcial sobre producto(id_categoria, id)
-- Justificación: el plan baseline y el plan post-Propuesta 1 muestran un
-- Sort con external merge Disk: ~3200kB sobre producto, que ordena 41.157
-- filas por id_categoria para alimentar el Merge Join con categoria.
-- Un índice sobre (id_categoria, id) WHERE activo = TRUE permite al
-- planificador obtener las filas de producto ya ordenadas por id_categoria
-- directamente desde el índice, eliminando el Sort a disco.
-- El filtro WHERE activo = TRUE lo hace parcial: más pequeño (excluye
-- productos inactivos) y más selectivo.
-- Riesgo: el planificador podría igualmente preferir Seq Scan + Hash Join
-- si estima que el índice no reduce suficientemente el volumen.
-- ============================================================================

BEGIN;

CREATE INDEX idx_p5_producto_categoria_activo
    ON producto (id_categoria, id)
    WHERE activo = TRUE;

ANALYZE producto;

-- Medir el efecto combinado (Propuesta 1 ya aplicada + esta propuesta)
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

-- Si el Sort externo a disco desaparece y el tiempo real baja: COMMIT
-- Si el planificador ignora el índice o el tiempo empeora: ROLLBACK
-- >>> DECIDIR ANTES DE EJECUTAR LA SIGUIENTE LÍNEA <<<
ROLLBACK;
