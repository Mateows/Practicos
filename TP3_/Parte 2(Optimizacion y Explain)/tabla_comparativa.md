# Tabla comparativa - TP3 Parte 2

**Nota:** Q3 se documenta en dos filas en vez de una sola. La primera fila
("Q3 - resultado final") es la fila que corresponde formalmente a la
consulta, con el plan antes (sin ningun indice) y el plan despues de
aplicar los 2 indices propuestos por la IA, tal como pide la seccion
2.2 de la consigna. La segunda fila ("Q3 - diagnostico intermedio") es
informacion adicional: el resultado de medir el efecto de un solo
indice antes de sumar el segundo, para poder atribuir el efecto a cada
cambio por separado. No son dos consultas distintas, son dos mediciones
de la misma Q3 en distintos pasos del proceso.

| Consulta | Índice aplicado | Plan antes (nodo, cost, tiempo real) | Plan después (nodo, cost, tiempo real) | Mejora |
|---|---|---|---|---|
| Q1 (pedidos pendientes) | `idx_pedido_estado_fecha (estado, fecha_hora DESC)` | Parallel Seq Scan + Sort + Gather Merge, cost=4925.32, Execution Time=33.698 ms | Index Scan using idx_pedido_estado_fecha, cost=0.29..7.00, Execution Time=0.908 ms | ~37x (33.7ms → 0.9ms) |
| Q2 (productos por categoría y precio) | `idx_producto_categoria_precio (id_categoria, precio_lista)` | Seq Scan + Sort, cost=1645.05, Execution Time=12.384 ms | Bitmap Heap Scan + Sort (el Sort NO desapareció), cost=2020.65, Execution Time=12.787 ms | Ninguna (levemente más lento, dentro del ruido de medición) |
| Q3 - resultado final (total facturado por cliente) | `idx_pedido_fecha_hora` + `idx_detalle_pedido_id_pedido` | Hash Join x2 + Seq Scans, con Gather (2 workers), cost=18077.61, Execution Time=160.112 ms | Hash Join x2 + Seq Scan on detalle_pedido (idx_detalle_pedido_id_pedido NO fue usado por el planificador), sin paralelismo, cost=17399.84, Execution Time=198.558 ms | Empeoró: 160.1ms → 198.6ms. El segundo índice nunca fue elegido por el optimizador (confirma la incertidumbre que la propia IA había anticipado); el primero perdió el paralelismo que tenía el plan original |
| Q3 - diagnóstico intermedio (mismo caso, solo con el primer índice) | `idx_pedido_fecha_hora` únicamente | Mismo plan antes que la fila de arriba (160.112 ms) | Bitmap Heap Scan on pedido vía idx_pedido_fecha_hora, plan ya serial (sin Gather/paralelismo), cost=17399.84, Execution Time=203.051 ms | Empeoró: 160.1ms → 203.1ms. Costo estimado bajó pero el tiempo real subió — se perdió el paralelismo de 2 workers que tenía el plan original |
