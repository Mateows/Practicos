Estos son los planes antes y después de aplicar la propuesta:

PLAN ANTES:
Plan A
Planning Time: 54.428 ms
Execution Time: 699.550 ms
Buffers: shared hit=8044



Plan B
Planning Time: 14.287 ms
Execution Time: 304.753 ms
Buffers: shared hit=6434, temp read=101 written=237






PLAN DESPUÉS:
Plan A
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







Plan B
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


Compará ambos planes con evidencia concreta. Indicá:

1. Si el índice o reescritura fue realmente utilizado.
2. Qué nodos cambiaron.
3. Qué algoritmo de JOIN utilizaba PostgreSQL antes y después.
4. Si cambió la relación externa/interna de algún JOIN.
5. Si aumentó o disminuyó el volumen de filas procesadas.
6. Si se mantuvo o se perdió el paralelismo.
7. Execution Time antes y después.
8. Si la mejora es real, nula o negativa.
9. Si la propuesta debe aceptarse o rechazarse.
10. Una explicación breve y defendible oralmente.

No bases la conclusión solamente en el costo estimado:
prioriza Execution Time, actual rows, actual time, buffers y el plan real.