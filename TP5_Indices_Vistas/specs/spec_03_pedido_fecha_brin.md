# spec: indice_pedido_fecha_brin

Objetivo: acelerar el filtro de fecha en la consulta de facturacion por
categoria (Q4 de queries.sql), sin repetir el error de TP3 (un indice
B-tree simple sobre fecha_hora ya empeoro un caso similar por perdida
de paralelismo).

Consulta afectada: Q4 completa (top 3 productos por facturacion por
categoria, ultimos 6 meses) -- ver queries.sql.

Filtro relevante en pedido:
  WHERE estado <> 'CANCELADO' AND fecha_hora >= now() - interval '6 months'
Selectividad real medida: retiene ~35.5% de las filas (23.655 de 66.668
examinadas por worker) -- mas selectivo que en Q5 (75%), pero con el
mismo riesgo estructural que en TP3-Q3 (selectividad ~33%, un indice
btree simple sobre fecha_hora empeoro el tiempo real por perdida de
paralelismo, ver TP3_Optimizacion/.../tabla_comparativa.md).

Columnas candidatas: fecha_hora (correlacionada con el orden fisico de
insercion, ya que se carga con generate_series creciente -- candidata
natural para BRIN en vez de B-tree).

Criterio de aceptacion: comparar EXPLICITAMENTE dos tipos de indice
sobre la misma columna (B-tree vs BRIN), midiendo el tiempo real de
cada uno con EXPLAIN ANALYZE, en vez de asumir que B-tree es la unica
opcion. Si ambos empeoran o no cambian nada, documentar el descarte
igual -- no forzar un indice que no ayuda.
