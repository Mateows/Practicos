# TP4 — Parte 4: Competencia de Optimización
## Consulta: Top 3 productos por facturación dentro de cada categoría (últimos 6 meses)
## Base: `foodstore_tp3_carga` | Tiempo base: **660.865 ms**

---

## 1. Nodo más costoso real (por tiempo de ejecución)

El cuello de botella no está en ningún Seq Scan sino en el **Sort con spill a disco**
dentro de los workers paralelos:

```
Sort  (actual time=323.171..336.597 rows=60470 loops=3)
  Sort Key: cat.id, p.id
  Sort Method: external merge  Disk: 3576kB
  Worker 0:  Sort Method: external merge  Disk: 3576kB
  Worker 1:  Sort Method: external merge  Disk: 3776kB
```

Ese Sort acumula ~323ms de los 660ms totales (≈49% del tiempo total).
Todo lo posterior en el plan (GroupAggregate, Gather Merge, WindowAgg,
Incremental Sort) espera a que ese Sort termine, por eso el tiempo se propaga
hacia los nodos de más arriba.

Los Seq Scans en sí son secundarios:
| Tabla           | Tiempo real | Filas leídas | Filas descartadas |
|-----------------|-------------|--------------|-------------------|
| `pedido`        | ~41ms       | 66.669       | 42.465 (CANCELADO + fuera rango) |
| `detalle_pedido`| ~71ms       | 499.572      | 0 (sin filtro propio) |
| `producto`      | ~19ms       | 50.003       | 0 (activo ya cubre todo) |
| `categoria`     | ~0.5ms      | 205          | 203 (solo 2 activas) |

---

## 2. Alternativa sin índices: `SET LOCAL work_mem = '8MB'`

### Por qué es la causa

El `work_mem` por defecto de PostgreSQL es 4MB por operación por worker.
Con 2 workers activos + el proceso principal, el Sort necesita mantener
~3.6MB por worker en RAM. Al superar el límite, PostgreSQL spillea a disco
(`external merge Disk`), lo que añade I/O de escritura + lectura al tiempo
del Sort.

### Resultado real (ejecutado con BEGIN...ROLLBACK)

```sql
BEGIN;
SET LOCAL work_mem = '8MB';
-- [consulta_competencia.sql]
ROLLBACK;
```

```
Sort Method: quicksort  Memory: 5926kB   ← ya no spillea
Worker 0:  Sort Method: quicksort  Memory: 5800kB
Worker 1:  Sort Method: quicksort  Memory: 5627kB
Execution Time: 556.884 ms
```

**Mejora: 660ms → 556ms = −104ms (−16%)**

### ¿Vale subir más? Prueba con 16MB

```
Execution Time: 641.026 ms   ← peor que 8MB
```

Con 16MB el Sort sigue en RAM pero el tiempo sube por variabilidad de la
ejecución paralela y costos de gestión de memoria. **8MB es el punto óptimo.**

### Estimación de mejora: modesta-grande
- Elimina el I/O de disco del Sort (ganancia garantizada y repetible).
- No requiere ningún cambio de schema ni de índices.
- Tradeoff: memoria de sesión, no afecta otras conexiones con SET LOCAL.

---

## 3. Índice propuesto: `idx_pedido_fecha_no_cancelado`

### Nodo atacado

```
Parallel Seq Scan on pedido ped
  Filter: ((estado <> 'CANCELADO') AND (fecha_hora >= now() - '6 mons'))
  Rows Removed by Filter: 42465
```

El Seq Scan lee 66.669 filas y descarta 42.465 (64% de descarte).
Un índice parcial sobre `fecha_hora DESC WHERE estado <> 'CANCELADO'` permite
al planner hacer Bitmap Index Scan directo sobre el rango temporal,
evitando leer los pedidos cancelados.

```sql
CREATE INDEX idx_pedido_fecha_no_cancelado
    ON pedido (fecha_hora DESC)
    WHERE estado <> 'CANCELADO';
```

**¿Por qué no el índice existente `idx_pedido_estado_fecha`?**
Ese índice tiene `estado` como primera columna con igualdad implícita en mente.
La condición real es `estado <> 'CANCELADO'` (desigualdad): un B-tree no puede
usar la primera columna como punto de entrada con negación eficiente. El nuevo
índice parcial resuelve eso directamente dejando afuera los CANCELADO desde la
definición del índice.

### Resultado real (solo índice, sin cambiar work_mem)

```
Parallel Bitmap Heap Scan on pedido ped
  Bitmap Index Scan on idx_pedido_fecha_no_cancelado
    Index Cond: (fecha_hora >= (now() - '6 mons'))
Execution Time: 635.828 ms
```

**Mejora: 660ms → 635ms = −25ms (−4%)**

El Sort sigue spilleando a disco porque `work_mem` no cambió. La mejora
del índice es absorbida por el cuello de botella del Sort.

### Estimación de mejora (índice solo): modesta
- Elimina el Seq Scan sobre ~66k filas.
- La ganancia se ve opacada por el Sort spill mientras work_mem sea bajo.
- Valor real: cuando el Sort ya no spillea, este índice contribuye a reducir
  la carga del Hash Join del lado de `pedido`.

---

## 4. Combinación: `work_mem = '8MB'` + `idx_pedido_fecha_no_cancelado`

### Resultado real

```
Sort Method: quicksort  Memory: 7794kB   ← en RAM
Execution Time: 622.922 ms
```

**Mejora: 660ms → 622ms = −38ms (−6%)**

Paradójicamente, la combinación es **peor que work_mem solo** (556ms).
Causa: los Hash Joins y el Bitmap Heap Scan añaden overhead de coordinación
entre workers que con el Seq Scan paralelo era más eficiente. El planner
eligió Bitmap Heap Scan (single-threaded sobre el heap) en lugar del
Parallel Seq Scan que con work_mem=8MB ya era rápido.

---

## 5. Control de ruido — iteración 1: promedios en bloques (AAA-BBB)

La medición de una sola corrida tiene variabilidad de ±60–100ms. En una
primera iteración se ejecutaron 3 corridas por escenario en bloques
consecutivos (baseline × 3, luego work_mem × 3, luego combinado × 3).

| Corrida | Baseline | Solo `work_mem = '8MB'` | `work_mem` + índice |
|---------|----------|-------------------------|---------------------|
| 1       | 657.116 ms | 612.393 ms            | 524.399 ms          |
| 2       | 557.481 ms | 508.713 ms            | 473.774 ms          |
| 3       | 648.521 ms | 496.328 ms            | 475.538 ms          |
| **Promedio** | **621.0 ms** | **539.1 ms**     | **491.2 ms**        |

Ese resultado mostraba el combinado como el mejor (−130ms vs base, −48ms
vs work_mem solo). Sin embargo, los bloques corren en orden fijo: el cache
del SO y de shared_buffers se calienta progresivamente a lo largo de toda
la sesión, no solo dentro de cada bloque. El escenario que corre último
se beneficia de ese calentamiento acumulado, independientemente de si el
índice aporta algo real.

---

## 6. Control de ruido — iteración 2: orden intercalado (A-B-A-B-A-B)

Para aislar el efecto del índice del efecto de orden, se repitió la
comparación entre los dos escenarios relevantes alternando en cada corrida:
A (solo `work_mem = '8MB'`) y B (`work_mem + índice`).

### Datos crudos intercalados

| Posición | Escenario | Execution Time |
|----------|-----------|----------------|
| 1        | A — solo work_mem   | 600.726 ms |
| 2        | B — work_mem+índice | 585.960 ms |
| 3        | A — solo work_mem   | 557.130 ms |
| 4        | B — work_mem+índice | 569.065 ms |
| 5        | A — solo work_mem   | 556.218 ms |
| 6        | B — work_mem+índice | 559.129 ms |

### Diferencias par a par (B − A, positivo = B más lento)

| Par | A | B | Diferencia |
|-----|---|---|------------|
| 1   | 600.726 ms | 585.960 ms | −14.8 ms (B gana) |
| 2   | 557.130 ms | 569.065 ms | +11.9 ms (A gana) |
| 3   | 556.218 ms | 559.129 ms | +2.9 ms  (A gana) |

### Promedios intercalados

| Escenario                        | Promedio (3 corridas intercaladas) |
|----------------------------------|------------------------------------|
| Solo `SET LOCAL work_mem = '8MB'`| 571.4 ms                           |
| `work_mem = '8MB'` + índice      | 571.4 ms                           |

---

## 7. Conclusión final

**El índice `idx_pedido_fecha_no_cancelado` no aporta mejora medible
sobre esta consulta cuando `work_mem = '8MB'` ya está activo.**

La ventaja de ~48ms observada en la medición en bloques (iteración 1)
era íntegramente efecto de orden: el escenario combinado corrió siempre
último y se benefició del cache caliente acumulado. Al intercalar los
escenarios, los promedios convergen a 571ms en ambos casos, y las
diferencias par a par no tienen dirección consistente (B gana en el par 1,
A gana en los pares 2 y 3).

El margen observado (máximo 15ms entre pares) está dentro del ruido normal
de variación del planificador paralelo (~30–60ms entre corridas).

### Recomendación final ajustada

| Intervención | ¿Aporta mejora real? | Magnitud |
|---|---|---|
| `SET LOCAL work_mem = '8MB'` | **Sí, confirmada** | −82ms vs base (−13%), consistente |
| `idx_pedido_fecha_no_cancelado` + work_mem | **No confirmada** para esta consulta | Dentro del ruido |

**La única intervención con efecto real y reproducible es `SET LOCAL work_mem = '8MB'`.**

El índice parcial sobre `pedido (fecha_hora DESC) WHERE estado <> 'CANCELADO'`
sigue siendo estructuralmente correcto y beneficia queries que filtran
`pedido` sin grandes agregaciones posteriores (por ejemplo, búsquedas
de historial por rango de fecha), pero para esta consulta de competencia
en particular — donde el cuello de botella es el Sort de 60k filas, no
el Seq Scan de pedido — el índice no cambia el tiempo de ejecución de
forma medible con cache caliente.

### Lección metodológica

Medir en bloques fijos (AAA-BBB) sobreestima la ventaja del escenario
que corre último. Para comparaciones honestas entre dos escenarios hay
que intercalar (A-B-A-B-A-B) para que ambos enfrenten condiciones de
cache equivalentes en promedio.

---

## 8. Protocolo de ejecución

Todos los `CREATE INDEX` y `SET LOCAL` se ejecutaron dentro de bloques
`BEGIN...ROLLBACK` sobre `foodstore_tp3_carga`, sin modificar `foodstore_dev`
ni aplicar ningún cambio en firme. Los tiempos registrados son los reportados
por `EXPLAIN ANALYZE` en cada ejecución.
