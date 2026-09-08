QUERY PLAN - foodstore_tp3_carga - Consulta B - DESPUES
Cambio probado dentro de BEGIN/ROLLBACK:
CREATE INDEX idx_tp4_b_no_cancelado ON pedido (id) INCLUDE (id_cliente)
WHERE estado <> 'CANCELADO';
ANALYZE pedido;

Limit (cost=19055.73..19055.78 rows=20 width=65)
  -> Sort (cost=19055.73..19105.74 rows=20003)
       Sort Key: (sum(dp.subtotal)) DESC
       -> Finalize HashAggregate (cost=18273.42..18523.46 rows=20003)
            Group Key: c.id
            Batches: 5  Memory Usage: 9521kB  Disk Usage: 744kB
            -> Gather (cost=13722.74..17973.37 rows=40006)
                 Workers Planned: 2  Workers Launched: 2
                 -> Partial HashAggregate
                      Batches: 5
                      -> Hash Join (cost=4758.26..11945.36 rows=155475)
                           Hash Cond: (pdo.id_cliente = c.id)
                           -> Parallel Hash Join (cost=4042.19..10821.08 rows=155475)
                                Hash Cond: (dp.id_pedido = pdo.id)
                                -> Parallel Seq Scan on detalle_pedido dp
                                   actual rows=166203 loops=3
                                -> Parallel Seq Scan on pedido pdo
                                   Filter: (pdo.estado <> 'CANCELADO')
                                   Rows Removed by Filter: 16801
                           -> Hash
                                -> Seq Scan on cliente c
                                   actual rows=20003 loops=3

Join algorithms before/after: Hash Join + Parallel Hash Join; no algorithm change.
Workers before/after: 2 planned and 2 launched.
The proposed index was NOT used; PostgreSQL retained a Parallel Seq Scan
on pedido because the predicate returns most rows.
Buffers: shared hit=6434, temp read=151 written=314
Planning Time: 3.684 ms
Execution Time: 305.604 ms
Decision: REJECTED. The index did not improve the plan or time:
baseline 304.753 ms, after 305.604 ms. The HashAggregate still spilled to disk.
A separate test with SET LOCAL work_mem = '64MB' removed the spill and measured
250.280 ms, so memory configuration is a more relevant optimization candidate
than this index, but it must be documented separately from an index change.

ROLLBACK completed; the test index was not left applied.
