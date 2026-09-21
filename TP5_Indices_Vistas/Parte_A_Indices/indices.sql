-- ============================================================================
-- indices.sql — Índices propuestos y evaluados para TP5 (Unidad 3, Semana 5)
-- Base: foodstore_tp3_carga
--
-- Cada bloque documenta: la consulta que motivó la propuesta, el índice
-- (creado o descartado), y el resultado real medido con EXPLAIN ANALYZE
-- (control de ruido: 3 corridas en orden intercalado, ver
-- informe_mediciones.md para el detalle completo).
-- ============================================================================

-- ----------------------------------------------------------------------------
-- CASO 1 — Q5: Ranking de clientes por gasto total (DENSE_RANK)
-- Spec: specs/spec_01_pedido_estado_detalle_join.md
-- ----------------------------------------------------------------------------

-- Candidato A — DESCARTADO
-- Propuesto por Kiro para atacar el filtro "estado <> 'CANCELADO'" en el
-- join pedido-cliente. NO SE CREA EN FIRME: el planificador lo ignoro en
-- las 9 de 9 corridas de control (3 escenarios x 3 rondas intercaladas),
-- manteniendo Parallel Seq Scan on pedido en todos los casos.
--
-- Motivo del descarte: la condicion "estado <> 'CANCELADO'" deja pasar
-- ~75% de las filas de pedido (Rows Removed by Filter confirma esto en
-- el plan real). Con esa selectividad tan baja, un indice parcial termina
-- cubriendo casi toda la tabla, y el optimizador prefiere el Seq Scan
-- paralelo antes que recorrer un B-tree casi tan grande como el heap.
-- Es un caso real de "columna con condicion parcial de baja selectividad",
-- uno de los ejemplos de sobreindexacion que pide descartar la consigna.
--
-- CREATE INDEX idx_pedido_no_cancelado_cliente
--     ON pedido (id_cliente)
--     WHERE estado <> 'CANCELADO';
-- (dejado comentado a proposito: NO se aplica)

-- Intervencion aceptada — SET LOCAL work_mem
-- No es un indice, es un ajuste de memoria de sesion. El plan base
-- mostraba el HashAggregate final derramando a disco (Batches: 5,
-- Disk Usage > 0). Con work_mem = '16MB' para esta sesion, el
-- HashAggregate paso a 1 solo batch, 100% en RAM, en las 3 rondas de
-- control sin excepcion. Mejora de tiempo real de ~15-29% segun la
-- ronda (ver informe_mediciones.md).
--
-- No requiere ningun CREATE INDEX ni cambio de schema. Se aplica por
-- sesion antes de correr el reporte de ranking:
--   SET LOCAL work_mem = '16MB';

-- ----------------------------------------------------------------------------
-- CASO 2 — Q6: Productos con precio superior al promedio de su categoria
-- Spec: specs/spec_02_producto_categoria_precio.md
-- ----------------------------------------------------------------------------

-- ACEPTADO, con salvedad importante documentada abajo
CREATE INDEX idx_producto_categoria_precio_activo
    ON producto (id_categoria, precio_lista DESC)
    WHERE activo = TRUE;

-- Resultado inicial (dentro de BEGIN...ROLLBACK): 271.205 s -> 220.899 s (~19%).
-- Medicion final, sobre el indice ya aplicado en firme y tras VACUUM
-- ANALYZE (ver Parte_A_Indices/plan_q6_despues.txt): 271.205 s -> 158.728 s
-- (~41%). Ver informe_mediciones.md Caso 2 para el detalle completo.
-- El indice SI se usa (Index Only Scan, Heap Fetches: 0) y
-- resuelve el AVG de la subconsulta sin volver al heap.
--
-- SALVEDAD: el indice no resuelve el problema de fondo de esta
-- consulta. La subconsulta correlacionada se ejecuta 50.003 veces (una
-- por producto) -- un patron O(n * filas_categoria) que ningun indice
-- puede eliminar, porque el costo esta en la CANTIDAD de ejecuciones
-- del SubPlan, no en el costo de cada ejecucion individual.
--
-- La solucion real a este problema (ya resuelta en TP4-Parte3) es
-- REESCRIBIR la consulta con una tabla derivada que pre-agrega el
-- promedio una sola vez por categoria (JOIN en vez de subconsulta
-- correlacionada), no crear un indice. Ver TP4_Reportes_Analiticos/
-- Parte3/consulta_b_subconsulta.sql (version V2), que resuelve el
-- mismo resultado en segundos.
--
-- Se acepta el indice igual porque: (a) es complementario, no
-- redundante, con idx_productos_categoria_activo (ese no incluye
-- precio_lista); (b) aporta una mejora real aunque modesta; (c) sirve
-- ademas para acelerar cualquier otra consulta futura que ordene
-- productos activos por precio dentro de una categoria.

-- ----------------------------------------------------------------------------
-- CASO 3 — Q4: Top 3 productos por facturacion dentro de cada categoria
-- Spec: specs/spec_03_pedido_fecha_brin.md
-- ----------------------------------------------------------------------------

-- Candidato BRIN — DESCARTADO SIN CREAR
-- CREATE INDEX idx_pedido_fecha_hora_brin
--     ON pedido USING BRIN (fecha_hora)
--     WITH (pages_per_range = 32);
--
-- Descartado antes de crearlo, con evidencia estadistica:
--   SELECT correlation FROM pg_stats
--   WHERE tablename = 'pedido' AND attname = 'fecha_hora';
--   -> resultado real: 0.013024098 (practicamente nula)
--
-- Un BRIN funciona eliminando rangos de paginas cuyo [min,max] no
-- intersecta el filtro. Con correlacion ~0, cada rango de paginas
-- contiene fechas de todo el año mezcladas (el seed genero fecha_hora
-- con random() independiente del orden de insercion por id), asi que
-- no hay casi ningun rango descartable. Crear este indice hubiera sido
-- un gasto de tiempo para confirmar algo que la estadistica ya
-- garantiza: no va a servir.

-- Candidato B-tree — CREADO Y APLICADO EN FIRME (tras corregir una
-- conclusion erronea de una medicion aislada)
CREATE INDEX idx_pedido_fecha_hora_btree ON pedido (fecha_hora DESC);
--
-- Historial de la decision (documentado completo, no se oculta el
-- cambio de conclusion):
-- 1) Primera medicion (corrida unica): parecio empeorar el tiempo
--    (658 ms sin indice -> 921 ms con indice). Con esa sola corrida se
--    habia descartado el indice.
-- 2) Al re-auditar, se detecto que esa conclusion venia de UNA sola
--    corrida de cada lado, sin control de ruido -- el mismo error
--    metodologico que ya se habia evitado en el Caso 1. Se repitio la
--    prueba con 3 rondas intercaladas (Baseline-Btree-Baseline-Btree-
--    Baseline-Btree), todo dentro de BEGIN...ROLLBACK:
--      Baseline: 380.800 / 390.572 / 343.204 ms -> promedio 371.5 ms
--      B-tree:   358.550 / 327.330 / 329.518 ms -> promedio 338.5 ms
--    El indice gano en las 3 de 3 rondas (direccion consistente, a
--    diferencia del Candidato A del Caso 1) -- mejora real de ~8.9%.
-- 3) Conclusion final: ACEPTADO Y APLICADO EN FIRME. La primera
--    medicion aislada llevaba a una conclusion equivocada; el control
--    riguroso la revirtio. Se documenta el cambio completo porque es
--    la evidencia de que el proceso de medicion (no solo el resultado)
--    es lo que hay que poder defender.

-- Intervencion complementaria — SET LOCAL work_mem (igual que en Caso 1 y en TP4)
--   SET LOCAL work_mem = '16MB';
-- Ya confirmado en TP4-Parte4 que resuelve el spill a disco del
-- HashAggregate de esta misma consulta. Es una intervencion distinta
-- y compatible con el indice de arriba (uno ataca el filtro de fecha,
-- el otro el spill del agregado) -- no se remidio la combinacion de
-- ambas en este TP, queda como posible mejora adicional a futuro.