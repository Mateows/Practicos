QUERY PLAN - foodstore_tp3_carga - Consulta A - DESPUES
Cambio probado dentro de BEGIN/ROLLBACK:
CREATE INDEX idx_tp4_a_estado_id ON pedido (estado, id) INCLUDE (fecha_hora);
ANALYZE pedido;

Incremental Sort (cost=15617.57..26686.93 rows=61812 width=166)
  -> Finalize GroupAggregate (cost=15589.45..23621.14 rows=61812)
       -> Gather Merge (cost=15589.45..22178.86 rows=51510)
            Workers Planned: 2  Workers Launched: 2
            -> Partial GroupAggregate (cost=14589.43..15233.31 rows=25755)
                 -> Sort (cost=14589.43..14653.82 rows=25755)
                      -> Hash Join (cost=3557.05..10851.05 rows=25755)
                           Hash Cond: (dp.id_producto = p.id)
                           -> Parallel Hash Join (cost=1825.22..8604.12 rows=51509)
                                Hash Cond: (dp.id_pedido = pdo.id)
                                -> Parallel Seq Scan on detalle_pedido dp
                                   actual rows=166203 loops=3
                                -> Parallel Hash
                                     -> Parallel Index Only Scan using idx_tp4_a_estado_id on pedido pdo
                                          Index Cond: (pdo.estado = 'ENTREGADO')
                                          actual rows=49633 loops=1
                                          Heap Fetches: 0
                           -> Hash
                                -> Hash Join (cost=16.66..1419.31 rows=25002)
                                     Hash Cond: (p.id_categoria = c.id)
                                     -> Seq Scan on producto p
                                        actual rows=50003 loops=3
                                     -> Seq Scan on categoria c
                                        Filter: c.activo
                                        actual rows=2 loops=3

Join algorithms before/after: Hash Join + Parallel Hash Join; no algorithm change.
Workers before/after: 2 planned and 2 launched.
Buffers: shared hit=6529 read=247
Planning Time: 5.386 ms
Execution Time: 164.254 ms
Decision: ACCEPTED for testing. The index was used by a Parallel Index Only Scan,
returned no heap fetches, preserved parallelism, and improved the observed time
from 699.550 ms to 164.254 ms. Re-run measurements if a final permanent result
is required because EXPLAIN ANALYZE timings vary with cache and load.

ROLLBACK completed; the test index was not left applied.
