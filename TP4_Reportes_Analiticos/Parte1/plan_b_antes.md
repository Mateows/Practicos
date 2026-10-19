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