-- ============================================================================
-- TP3 Parte 2 - Indices propuestos por Kiro, justificados sobre planes reales
--
-- ESTADO FINAL (ver DUIA_TP3.md y tabla_comparativa.md para el detalle de
-- cada medicion): de los 4 indices propuestos, solo el primero mostro
-- mejora real y se mantiene aplicado en foodstore_tp3_carga. Los otros 3
-- fueron revertidos con DROP INDEX porque no mejoraron el tiempo real
-- (uno no tuvo efecto, dos empeoraron el plan).
-- ============================================================================

-- Q1: ataca Parallel Seq Scan + Sort + Gather Merge (pedido, filtro estado)
-- RESULTADO: mejora confirmada, ~37x (33.7ms -> 0.9ms). SE MANTIENE APLICADO.
CREATE INDEX idx_pedido_estado_fecha ON pedido (estado, fecha_hora DESC);

-- Q2: ataca Seq Scan + Sort (producto, filtro categoria+precio)
-- RESULTADO: sin mejora real (12.4ms -> 12.8ms, el Sort no desaparecio
-- porque el planificador uso Bitmap Heap Scan). REVERTIDO (DROP INDEX).
CREATE INDEX idx_producto_categoria_precio ON producto (id_categoria, precio_lista);

-- Q3a: ataca Parallel Seq Scan on pedido (filtro de fecha)
-- RESULTADO: empeoro (160.1ms -> 203.1ms), el plan perdio el paralelismo
-- que tenia sin el indice. REVERTIDO (DROP INDEX).
CREATE INDEX idx_pedido_fecha_hora ON pedido (fecha_hora);

-- Q3b: ataca Parallel Seq Scan on detalle_pedido (join por id_pedido)
-- RESULTADO: nunca fue elegido por el planificador (siguio usando Seq
-- Scan). REVERTIDO (DROP INDEX).
CREATE INDEX idx_detalle_pedido_id_pedido ON detalle_pedido (id_pedido);
