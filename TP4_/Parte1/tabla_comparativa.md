# Tabla comparativa - TP4 Parte 1

**Base:** `foodstore_tp3_carga`  
**Motor:** PostgreSQL 17  
**Metodo:** medicion con `EXPLAIN (ANALYZE, BUFFERS, VERBOSE)`. Cada indice adicional se probo dentro de `BEGIN ... ROLLBACK`.

## Resultados

| Consulta | JOIN antes | Cambio probado | JOIN despues | Tiempo antes | Tiempo despues | Mejora | Decision |
|---|---|---|---|---:|---:|---|---|
| **A - Facturacion por categoria y mes** | `Parallel Hash Join` (`dp`-`pdo`), `Hash Join` (`dp`-`p`), `Hash Join` (`p`-`c`), con 2 workers | `CREATE INDEX idx_tp4_a_estado_id ON pedido (estado, id) INCLUDE (fecha_hora)` | Se conservaron los mismos algoritmos y los 2 workers. `pedido` paso a `Parallel Index Only Scan` con `Heap Fetches: 0` | 699.550 ms | 164.254 ms | **~4,26x** | **Aceptar.** |
| **B - Ranking de clientes por gasto** | `Parallel Hash Join` (`dp`-`pdo`) y `Hash Join` (resultado-`c`), con 2 workers | `CREATE INDEX idx_tp4_b_no_cancelado ON pedido (id) INCLUDE (id_cliente) WHERE estado <> 'CANCELADO'` | Sin cambios de JOIN ni de paralelismo. PostgreSQL mantuvo `Parallel Seq Scan` sobre `pedido` y no uso el indice | 304.753 ms | 305.604 ms | **Nula** | **Rechazar.** |

## Evidencia y lectura

- La Consulta A ya utilizaba el indice previo `idx_p5_pedido_estado` en el plan inicial. La propuesta de TP4 agrego `idx_tp4_a_estado_id`, que fue utilizada como `Parallel Index Only Scan` para obtener las filas `ENTREGADO` sin accesos al heap.
- En A no cambio el algoritmo de JOIN: continuaron `Hash Join` y `Parallel Hash Join`. La mejora provino del acceso a `pedido`, no de un cambio de JOIN.
- En la Consulta B el indice parcial no fue elegido porque `estado <> 'CANCELADO'` conserva la mayoria de las filas. Leer la tabla mediante `Parallel Seq Scan` siguio siendo mas conveniente.
- En B el `HashAggregate` continuo usando lotes y espacio temporal: `Batches: 5`, `Disk Usage: 720kB` antes y `744kB` despues.
- Una prueba independiente con `SET LOCAL work_mem = '64MB'` elimino el derrame del agregado y dio `250.280 ms`. Es una observacion adicional sobre memoria, no debe presentarse como efecto del indice de B.
- Las mediciones no son estrictamente deterministas: el tiempo real puede variar por cache, carga y estado del sistema. La conclusion se basa en el plan utilizado y en la medicion observada.
- Los indices temporales fueron revertidos mediante `ROLLBACK` y no quedaron aplicados.

## Archivos de planes

- [plan_a_antes.txt](plan_a_antes.txt)
- [plan_a_despues.txt](plan_a_despues.txt)
- [plan_b_antes.txt](plan_b_antes.txt)
- [plan_b_despues.txt](plan_b_despues.txt)
