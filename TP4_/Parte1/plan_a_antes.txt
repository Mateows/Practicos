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
