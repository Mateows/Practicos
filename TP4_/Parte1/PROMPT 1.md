Estoy realizando la Parte 1 de la práctica de Base de Datos II, Unidad 2,
sobre optimización de consultas analíticas en PostgreSQL.

Base:
- Proyecto: Food Store.
- Motor: PostgreSQL 17.
- Base de trabajo: foodstore_tp3_carga.
- La base está poblada masivamente.
- No debe modificarse la base principal.
- Toda creación de índices debe proponerse primero y probarse dentro de una
  transacción con ROLLBACK.
- No ejecutes comandos automáticamente ni supongas que una propuesta funciona.

Objetivo:
Analizar dos consultas analíticas que cruzan al menos tres tablas y tienen
JOIN, filtros, agregación y/u ordenamiento. Debo comparar los planes
EXPLAIN ANALYZE antes y después de una optimización.

Consultas:

CONSULTA A — Facturación por categoría y mes

SELECT
    c.id,
    c.nombre,
    DATE_TRUNC('month', pdo.fecha_hora) AS mes,
    SUM(dp.subtotal) AS total_facturado
FROM categoria AS c
JOIN producto AS p
    ON p.id_categoria = c.id
JOIN detalle_pedido AS dp
    ON dp.id_producto = p.id
JOIN pedido AS pdo
    ON pdo.id = dp.id_pedido
WHERE c.activo = TRUE
  AND pdo.estado = 'ENTREGADO'
GROUP BY
    c.id,
    c.nombre,
    DATE_TRUNC('month', pdo.fecha_hora)
ORDER BY
    mes,
    total_facturado DESC;


CONSULTA B — Ranking de clientes por gasto

SELECT
    c.id,
    c.nombre_completo,
    SUM(dp.subtotal) AS total_gastado
FROM cliente AS c
JOIN pedido AS pdo
    ON pdo.id_cliente = c.id
JOIN detalle_pedido AS dp
    ON dp.id_pedido = pdo.id
WHERE pdo.estado <> 'CANCELADO'
GROUP BY
    c.id,
    c.nombre_completo
ORDER BY
    total_gastado DESC
LIMIT 20;

A continuación incluyo los planes reales obtenidos con:

EXPLAIN (ANALYZE, BUFFERS, VERBOSE)

PLAN DE CONSULTA A ANTES:
QUERY PLAN - foodstore_tp3_carga - Consulta A - ANTES
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)

Plan real masivo:
Incremental Sort (cost=16550.74..27625.76 rows=61837)
  -> Finalize GroupAggregate (cost=16522.54..24557.36 rows=61837)
      -> Gather Merge (cost=16522.54..23114.50 rows=51530)
          Workers Planned: 2  Workers Launched: 2
          -> Partial GroupAggregate (cost=15522.51..16166.64 rows=25765)
              -> Sort (cost=15522.51..15586.92 rows=25765)
                  -> Hash Join (cost=4489.12..11783.32 rows=25765)
                      Hash Cond: (dp.id_producto = p.id)
                      -> Parallel Hash Join (cost=2757.28..9536.18 rows=51530)
                          Hash Cond: (dp.id_pedido = pdo.id)
                          -> Parallel Seq Scan on detalle_pedido dp
                            (actual rows=166203 loops=3)
                          -> Parallel Bitmap Heap Scan on pedido pdo
                            Recheck Cond: (pdo.estado = 'ENTREGADO')
                            -> Bitmap Index Scan on idx_p5_pedido_estado
                               Index Cond: (pdo.estado = 'ENTREGADO')
                      -> Hash
                          -> Hash Join (cost=16.66..1419.31 rows=25002)
                              Hash Cond: (p.id_categoria = c.id)
                              -> Seq Scan on producto p
                                (actual rows=50003 loops=3)
                              -> Seq Scan on categoria c
                                Filter: c.activo
                                (actual rows=2 loops=3)

Planning Time: 54.428 ms
Execution Time: 699.550 ms
Buffers: shared hit=8044


PLAN DE CONSULTA B ANTES:
QUERY PLAN - foodstore_tp3_carga - Consulta B - ANTES
EXPLAIN (ANALYZE, BUFFERS, VERBOSE)

Plan real masivo:
Limit (cost=19053.81..19053.86 rows=20)
  -> Sort (cost=19053.81..19103.81 rows=20003)
       Sort Key: (sum(dp.subtotal)) DESC
       -> Finalize HashAggregate (cost=18271.50..18521.53 rows=20003)
            Group Key: c.id
            Batches: 5  Memory Usage: 10289kB  Disk Usage: 720kB
            -> Gather (cost=13720.81..17971.45 rows=40006)
                 Workers Planned: 2  Workers Launched: 2
                 -> Partial HashAggregate (cost=12720.81..12970.85 rows=20003)
                      Batches: 5  Memory Usage: 8241kB  Disk Usage: 216kB
                      -> Hash Join (cost=4757.33..11944.09 rows=155344)
                           Hash Cond: (pdo.id_cliente = c.id)
                           -> Parallel Hash Join (cost=4041.26..10820.16 rows=155344)
                                Hash Cond: (dp.id_pedido = pdo.id)
                                -> Parallel Seq Scan on detalle_pedido dp
                                   (actual rows=166203 loops=3)
                                -> Parallel Seq Scan on pedido pdo
                                   Filter: (pdo.estado <> 'CANCELADO')
                                   Rows Removed by Filter: 16801
                           -> Hash
                                -> Seq Scan on cliente c
                                   (actual rows=20003 loops=3)

Planning Time: 14.287 ms
Execution Time: 304.753 ms
Buffers: shared hit=6434, temp read=101 written=237
Tarea:

1. Analiza cada plan línea por línea.
2. Identifica todos los algoritmos de JOIN utilizados:
   - Nested Loop
   - Hash Join
   - Merge Join
3. Para cada JOIN indica:
   - tablas involucradas;
   - relación externa e interna, cuando corresponda;
   - condición del JOIN;
   - filas estimadas y reales;
   - costo estimado;
   - tiempo real;
   - si el JOIN parece eficiente o costoso.
4. Identifica los principales cuellos de botella:
   - Seq Scan;
   - Index Scan;
   - Bitmap Heap Scan;
   - Sort;
   - Hash;
   - Aggregate;
   - falta o pérdida de paralelismo;
   - exceso de filas procesadas antes de agregar.
5. Propón índices o reescrituras únicamente si están justificadas por un
   nodo concreto del plan.
6. Para cada propuesta explica:
   - qué nodo intenta mejorar;
   - qué columnas utiliza;
   - por qué podría ayudar;
   - qué algoritmo de JOIN podría cambiar;
   - riesgos de empeorar el tiempo real;
   - SQL exacto para probarla.
7. No confundas:
   - cost con milisegundos;
   - filas estimadas con filas reales;
   - tiempo de un nodo con Execution Time total.
8. No afirmes que un índice será utilizado hasta comprobarlo con otro plan.
9. No propongas cambios genéricos ni índices sobre columnas que no aparecen
   en filtros, JOIN, agrupamientos u ordenamientos.
10. No modifiques todavía ninguna tabla ni generes comandos para aplicar
    permanentemente los cambios.

Entrega la respuesta con esta estructura:

A. Resumen del plan de cada consulta.
B. Tabla de algoritmos de JOIN.
C. Cuellos de botella concretos.
D. Propuestas de optimización justificadas.
E. Índices o reescrituras que conviene probar primero.
F. Comandos de prueba dentro de BEGIN ... ROLLBACK.
G. Tabla esperada para comparar antes y después.
H. Riesgos y puntos que debo poder explicar en la defensa oral.