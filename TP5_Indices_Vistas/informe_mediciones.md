# Informe de mediciones — TP5 (índices, costo de escritura y vista materializada)

**Base:** `foodstore_tp3_carga` · **Motor:** PostgreSQL

**Índices que ya existían sobre `pedido`:** `pedido_pkey`,
`idx_pedidos_cliente_id` (de `schema.sql`) e
`idx_pedido_estado_fecha (estado, fecha_hora DESC)`, heredado de TP3
para Q1 (`TP3_Optimizacion/.../indices_propuestos.sql`). Todas las
mediciones "sin índice" de Q5 y Q4 se hicieron con esos índices
presentes. Ninguna de las dos usa `idx_pedido_estado_fecha`: las dos
filtran con `estado <> 'CANCELADO'`, una desigualdad que el B-tree no
puede usar como punto de entrada (sirve para `estado = ...`), y
`fecha_hora`, que Q4 también filtra, es la segunda columna del índice.
Es el mismo análisis de TP4-Parte 4 (`analisis_optimizacion.md`). Los
índices heredados de `detalle_pedido` (`pk_detalle_pedido` e
`idx_detalle_pedido_producto_id`, de `schema.sql`) y de `producto` se
tratan en el Caso 1 (Candidato B) y en el Punto 5.

## Caso 1 — Q5: Ranking de clientes por gasto total

**Consulta:**
```sql
SELECT c.nombre_completo, SUM(dp.subtotal) AS total_gastado,
       DENSE_RANK() OVER (ORDER BY SUM(dp.subtotal) DESC) AS puesto
FROM cliente c
JOIN pedido p ON p.id_cliente = c.id AND p.estado <> 'CANCELADO'
JOIN detalle_pedido dp ON dp.id_pedido = p.id
GROUP BY c.id, c.nombre_completo
ORDER BY puesto;
```

**Plan "antes" (baseline, sin cambios):** `plan_q5_antes.txt`. Execution
Time inicial: 527.637 ms. Nodo relevante: `Finalize HashAggregate` con
`Batches: 5, Disk Usage: 1568kB` (spill a disco), y `Parallel Seq Scan
on pedido` con `Filter: estado <> 'CANCELADO'`, descartando ~25% de las
filas (selectividad real ~75%, no el ~83% que había estimado la IA antes de medir — la estimación inicial de Kiro se corrigió tras medir la selectividad real con `pg_stats`).

### Candidato A — `idx_pedido_no_cancelado_cliente (id_cliente) WHERE estado <> 'CANCELADO'`

Propuesto por Kiro a partir de `specs/spec_01_pedido_estado_detalle_join.md`.

**Control de ruido (primera tanda, sin salida archivada):** 3 escenarios (Baseline / Índice A / `work_mem`),
3 rondas en orden intercalado (9 corridas totales), cada una dentro de
`BEGIN...ROLLBACK` para no dejar nada aplicado durante la prueba.

| Corrida | Escenario | Execution Time | Plan |
|---|---|---|---|
| 1 | Baseline | 615.794 ms | Parallel Seq Scan, 5 batches a disco |
| 2 | Índice A | 612.803 ms | Índice ignorado, mismo plan que baseline |
| 3 | work_mem | 610.424 ms | 1 batch, sin spill |
| 4 | Baseline | 528.812 ms | Parallel Seq Scan, 5 batches a disco |
| 5 | Índice A | 482.216 ms | Índice ignorado, mismo plan que baseline |
| 6 | work_mem | 377.322 ms | 1 batch, sin spill |
| 7 | Baseline | 434.925 ms | Parallel Seq Scan, 5 batches a disco |
| 8 | Índice A | 455.060 ms | Índice ignorado, mismo plan que baseline |
| 9 | work_mem | 353.851 ms | 1 batch, sin spill |

**Promedios:**

| Escenario | Promedio | Dif. vs. baseline |
|---|---|---|
| Baseline | 526.5 ms | — |
| Índice A | 516.7 ms | −1.8% (dentro del ruido) |
| `work_mem = 16MB` | 447.2 ms | −15.1% |

**Remedición con salida archivada (corrección posterior a la
devolución):** las 9 corridas de arriba no habían quedado guardadas.
Se repitieron con `Parte_A_Indices/medir_q5_rondas.sql`, con la salida
completa en `Parte_A_Indices/plan_q5_rondas_salida.txt` (mismo orden en
cada ronda: Baseline, Índice A y `work_mem`; el índice y el `work_mem`,
dentro de `BEGIN...ROLLBACK`):

| Ronda | Baseline (ms) | Índice A (ms) | `work_mem = 16MB` (ms) |
|---|---|---|---|
| 1 | 795.568 | 417.282 | 323.945 |
| 2 | 433.272 | 409.968 | 306.372 |
| 3 | 385.951 | 405.510 | 297.678 |

La ronda 1 del Baseline (795.568 ms) es la primera consulta de la
sesión y paga el arranque en frío, así que el promedio del Baseline con
las 3 rondas (538.3 ms) queda inflado y haría parecer que el Índice A
mejora. Comparando las rondas 2 y 3: Baseline 409.6 ms, Índice A
407.7 ms (gana una ronda y pierde la otra: sin efecto) y `work_mem`
302.0 ms (~26% menos; es el más rápido en las 3 rondas). En los 9
planes, el Índice A no aparece como nodo de lectura (el planificador lo
ignora), y `work_mem` baja el `HashAggregate` de `Batches: 5` a
`Batches: 1`. La remedición confirma las dos decisiones de abajo.

### Decisión — Índice A: **DESCARTADO**

En todas las corridas con el Índice A, el plan sigue leyendo `pedido`
con `Parallel Seq Scan` y el índice no aparece: en las 3 archivadas de
la remedición y en las de la primera tanda, sin archivar. No es un efecto de ruido, es una decisión estructural del
optimizador. Causa: la condición `estado <> 'CANCELADO'` retiene ~75%
de la tabla `pedido`, una selectividad demasiado baja para que un
índice parcial sobre esa condición compita con un `Seq Scan` paralelo.
Documentado como el caso de descarte explícito por sobreindexación de
la Parte A (columna/condición de baja selectividad).


### Decisión — `SET LOCAL work_mem = '16MB'`: **ACEPTADO**

Elimina el spill a disco del `HashAggregate` final en las 3 rondas sin
excepción (`Batches: 5 → 1`, `Disk Usage → 0`). La mejora de tiempo
varía por ronda (en la remedición archivada, la mayor diferencia es la
de la ronda 1, inflada por el arranque en frío del Baseline; en las
rondas 2 y 3 es de ~26%), pero el cambio estructural en el plan es consistente. No
requiere ningún índice ni cambio de esquema — se aplica por sesión.

### Candidato B — `idx_detalle_pedido_id_pedido (id_pedido)`: **DESCARTADO por redundante**

Kiro lo propuso como segundo candidato para el join con
`detalle_pedido`. `spec_01` afirmaba que no había ningún índice sobre
`detalle_pedido.id_pedido`, pero es falso: la PK es compuesta,
`PRIMARY KEY (id_pedido, id_producto)`, y un B-tree compuesto sirve
para buscar por su primera columna sola. El candidato duplicaría lo que
ya hace `pk_detalle_pedido`.

**Evidencia:**
- `Parte_A_Indices/plan_detalle_por_id_pedido.txt`: una búsqueda
  `WHERE id_pedido = 100`, sin el candidato, usa
  `Index Scan using pk_detalle_pedido` (2.401 ms).
- `Parte_A_Indices/plan_q5_indice_redundante.txt` (script
  `medir_indice_redundante_q5.sql`, dentro de `BEGIN...ROLLBACK`): Q5
  con el candidato creado tarda 615.608 ms y sin él 612.285 ms. En los
  dos casos el planificador lee `detalle_pedido` con
  `Parallel Seq Scan` (Q5 recorre toda la tabla) y el candidato no se
  usa.

**Decisión: DESCARTADO.** Es el ejemplo literal de sobreindexación de
la consigna (un índice redundante con otro ya existente): tendría costo
de mantenimiento en cada `INSERT` de `detalle_pedido` sin aportar nada
que la PK no haga. El error de `spec_01` quedó corregido con una nota,
sin borrar la afirmación original.

**Planes "después" archivados del Caso 1** (en `Parte_A_Indices/`):

- `plan_q5_despues_workmem.txt` — 336.877 ms con `SET LOCAL work_mem = '16MB'`: el `HashAggregate` pasa de `Batches: 5` con `Disk Usage` a `Batches: 1` sin volcado a disco.
- `plan_q5_despues_indice_descartado.txt` — 301.954 ms: se probó (dentro de `BEGIN...ROLLBACK`) un índice parcial `idx_pedido_no_cancelado_cliente ON pedido (id_cliente) WHERE estado <> 'CANCELADO'`. El planner **no lo usó** — siguió eligiendo `Seq Scan` sobre `pedido`, porque el filtro `estado <> 'CANCELADO'` descarta muy pocas filas (~25%: en `plan_q5_antes.txt` son 16.620 filas descartadas por proceso, con `loops=3`; en total ~49.860 de los 200.005 pedidos) y no es lo suficientemente selectivo para justificar el índice. Se documenta como índice evaluado y descartado, no aplicado en la base final.

---

## Caso 2 — Q6: Productos con precio superior al promedio de su categoría

**Consulta:**
```sql
SELECT p.nombre, p.precio_lista
FROM producto p
JOIN categoria cat ON cat.id = p.id_categoria AND cat.activo = TRUE
WHERE p.activo = TRUE
  AND p.precio_lista > (
      SELECT AVG(p2.precio_lista)
      FROM producto p2
      WHERE p2.activo = TRUE AND p2.id_categoria = p.id_categoria
  )
ORDER BY cat.id, p.precio_lista DESC;
```

**Plan "antes":** `plan_q6_antes.txt`. Execution Time: **271.205 s** (271205.318 ms según `plan_q6_antes.txt`)
(~4.5 minutos). Nodo relevante: `Nested Loop` con `SubPlan 1` ejecutado
**50.003 veces** (una por producto), cada una con `Bitmap Heap Scan`
sobre `producto` filtrando por `id_categoria` — patrón O(n²).

### Candidato — `idx_producto_categoria_precio_activo (id_categoria, precio_lista DESC) WHERE activo = TRUE`

Propuesto por Kiro (`specs/spec_02_producto_categoria_precio.md`),
probado con OpenCode dentro de `BEGIN...ROLLBACK`.

**Resultado provisional (sin salida archivada):** Execution Time con índice: **220.899 s**. Mejora: ~19%. Este número no tiene archivo de respaldo; el valor que se toma es el de `plan_q6_despues.txt` (ver abajo).

**Nota de trazabilidad:** los 220.899 s de arriba son la medición hecha
dentro de `BEGIN...ROLLBACK` al probar el candidato por primera vez (ya
con `Index Only Scan`, `Heap Fetches: 0`). La medición final, sobre el
índice ya aplicado en firme, quedó en `Parte_A_Indices/plan_q6_despues.txt`:
**158.728 s**, capturada después de correr `VACUUM ANALYZE producto;`
(los INSERT de la Prueba 2 del Punto 5, hechos antes de esta medición,
habían desactualizado el mapa de visibilidad y forzaban temporalmente un `Index Scan` con
fetches al heap). Ese último número —no el 220.899 s— es el que refleja
el estado real de la base entregada: mejora de **271.205 s → 158.728 s
(~41%)**, mayor a la estimada inicialmente en esta sección.
El plan confirma `Index Only Scan` con `Heap Fetches: 0` — el índice
sí se usa y resuelve el `AVG` sin volver al heap.

### Decisión: **ACEPTADO, con salvedad importante**

El índice funciona correctamente pero **no resuelve el problema real**
de esta consulta: la subconsulta correlacionada sigue ejecutándose
50.003 veces, sin importar cuánto más rápido sea cada ejecución
individual. El cuello de botella es la *cantidad de ejecuciones* del
`SubPlan`, no el costo de cada una — ningún índice puede corregir eso
por sí solo.

La solución real ya existe: en **TP4-Parte 3** (`consulta_b_subconsulta.sql`,
versión V2) se reescribió esta misma consulta reemplazando la
subconsulta correlacionada por una tabla derivada que pre-agrega el
promedio una sola vez por categoría (JOIN en vez de subconsulta por
fila), resolviendo en segundos en vez de minutos — mismo resultado,
verificado por equivalencia con `EXCEPT` en aquel momento.

Se acepta el índice de todas formas porque:
- No es redundante con `idx_productos_categoria_activo` (ese no
  incluye `precio_lista`, no sirve para el `ORDER BY` ni el `AVG`).
- Aporta una mejora real: ~41% en la medición final archivada
  (`plan_q6_despues.txt`); la medición provisional de ~19% no quedó
  archivada (ver Nota de trazabilidad arriba).
- Sirve para acelerar cualquier consulta futura que ordene productos
  activos por precio dentro de una categoría — no es un índice de un
  solo uso.

**Lección para la defensa oral:** un índice puede funcionar
perfectamente (usarse, evitar ir al heap) y aun así no ser la
herramienta correcta para el problema — cuando el cuello de botella es
la *estructura* de la consulta (ejecutar algo N veces en vez de una),
hay que reescribir, no indexar.

**Plan "después" archivado del Caso 2** (en `Parte_A_Indices/`):

- `plan_q6_despues.txt` — 158.728 s (158728.129 ms según `plan_q6_despues.txt`), confirmado `Index Only Scan` con `Heap Fetches: 0` tras ejecutar `VACUUM ANALYZE producto;` (el mapa de visibilidad estaba desactualizado por los INSERT de la Prueba 2 del Punto 5, lo que inicialmente forzaba `Index Scan` con fetches al heap).

## Caso 3 — Q4: Top 3 productos por facturación dentro de cada categoría

**Consulta:** ver `queries.sql` (Q4) — join de 4 tablas + funciones de
ventana, ya trabajada en TP4-Parte4 pero nunca desde el ángulo de
índices.

**Plan "antes" de referencia:** `plan_q4_antes.txt` (378.669 ms, una
corrida individual — el número oficial de comparación es el promedio
de 3 rondas de control, ver más abajo). Mismo patrón que en TP4:
`Sort ... external merge Disk` (spill a disco), y filtro
`estado <> 'CANCELADO' AND fecha_hora >= now() - interval '6 months'`
sobre `pedido`, reteniendo ~33-35% de las filas según la corrida
(35,5% en `plan_q4_antes.txt`: 35.482 filas × 2 procesos; 33,2% en
`plan_q4_rondas_salida.txt`: 22.161 × 3; sobre 200.005 pedidos; la
ventana de 6 meses se mueve con `now()`).

**Nota metodológica:** esta consulta se midió varias veces a lo largo
de la sesión de trabajo (658, 910, 365, 384, 378 ms en distintos
momentos, siempre sin ningún índice nuevo aplicado; salvo los 378 ms
de `plan_q4_antes.txt`, esas corridas no tienen salida archivada), con variación
significativa por el estado del caché de PostgreSQL/SO durante una
sesión larga. Esto llevó a que la primera comparación contra el B-tree
(un solo baseline vs. una sola corrida con índice) diera una
conclusión que después se revirtió con control de ruido — ver abajo.

### Candidato 1 — BRIN sobre `fecha_hora`

`specs/spec_03_pedido_fecha_brin.md`. Antes de crearlo, se verificó la
correlación física de la columna:
```sql
SELECT correlation FROM pg_stats WHERE tablename = 'pedido' AND attname = 'fecha_hora';
-- resultado al decidir: 0.013024098 (sin salida archivada)
-- remedido el 23/09 con salida archivada: 0.0071880464
```

La salida del segundo valor está en
`Parte_A_Indices/correlacion_fecha_hora_salida.txt` (script:
`correlacion_fecha_hora.sql`). El número cambia con cada `ANALYZE`
porque sale de una muestra de la tabla; en los dos casos es ~0, que es
lo que sostiene la decisión.

**Decisión: DESCARTADO sin crearlo.** Un índice BRIN depende de que los
valores estén físicamente correlacionados con el orden de las páginas
en disco. Con correlación ~0 (el `seed_masivo.sql` genera `fecha_hora`
con `random()`, sin relación con el orden de inserción por `id`), cada
rango de páginas contiene fechas de todo el año mezcladas — el BRIN no
podría descartar casi ninguna.

### Candidato 2 — B-tree simple sobre `fecha_hora`

```sql
CREATE INDEX idx_pedido_fecha_hora_btree ON pedido (fecha_hora DESC);
```

**Primera medición (corrida única, sin salida archivada, luego revertida):** una comparación
aislada de una corrida de cada lado sugirió que el índice empeoraba el
tiempo (~658 ms sin índice → ~921 ms con índice), aparentemente por
pérdida de paralelismo — el mismo patrón que en TP3-Q3. Con ese único
dato, el índice se había descartado.

**Segunda medición (3 rondas intercaladas, sin salida archivada):** al
re-auditar, se detectó que esa conclusión salía de una sola corrida de
cada escenario — el mismo error metodológico ya evitado en el Caso 1.
Se repitió con 3 rondas intercaladas (Baseline-B-tree-Baseline-B-tree-
Baseline-B-tree), todas dentro de `BEGIN...ROLLBACK`:

| Ronda | Baseline (ms) | B-tree (ms) |
|---|---|---|
| 1 | 380.800 | 358.550 |
| 2 | 390.572 | 327.330 |
| 3 | 343.204 | 329.518 |
| **Promedio** | **371.5** | **338.5** |

El índice ganó en 3 de 3 rondas (~8.9%) y en ese momento se aceptó.
Pero esas rondas no quedaron archivadas, y la diferencia (33 ms) es
menor que la variación de la misma consulta sin ningún cambio (entre
365 y 910 ms, ver la Nota metodológica). Es exactamente lo que señaló
la devolución de la cátedra: una mejora con un margen cercano al ruido.

El plan "después" de una corrida única con el índice quedó archivado en `Parte_A_Indices/`:

- `plan_q4_despues.txt` — 414.220 ms (uso de `idx_pedido_fecha_hora_btree`, `Bitmap Index Scan`). Es una corrida única y ya daba un tiempo **peor** que `plan_q4_antes.txt` (378.669 ms), lo que no coincidía con el promedio de la tabla de arriba.

**Tercera medición (3 rondas intercaladas, salida archivada):**
`Parte_A_Indices/medir_q4_rondas.sql`, con la salida completa en
`Parte_A_Indices/plan_q4_rondas_salida.txt` (`EXPLAIN (ANALYZE, BUFFERS)`
en cada ronda):

| Ronda | Sin índice (ms) | Con índice (ms) |
|---|---|---|
| 1 | 767.525 | 729.226 |
| 2 | 704.008 | 688.866 |
| 3 | 628.264 | 706.615 |
| **Promedio** | **699.9** | **708.2** |

La dirección es inconsistente: el índice mejora en las rondas 1 y 2 y
empeora ~12% en la 3, y en promedio queda levemente peor. El plan
muestra una causa probable: sin índice, `pedido` se lee con
`Parallel Seq Scan` repartido en varios procesos (`loops=2` o `3`); con
índice, en las 3 rondas archivadas el `Parallel Bitmap Heap Scan` sobre
`pedido` terminó en un solo proceso (`loops=1`), aunque el resto del
plan siguió en paralelo (`Workers Launched: 2`). No es fijo: en
`plan_q4_despues.txt` el mismo nodo se repartió en 3 procesos y aun así
tardó más que sin índice (414.220 ms contra 378.669 ms). En ningún caso
el índice dio una mejora que supere el ruido.

**Decisión final: DESCARTADO.** Una mejora que no supera el ruido no
justifica el costo de mantener el índice en cada `INSERT`/`UPDATE` de
`pedido`. El índice se eliminó de la base
(`DROP INDEX idx_pedido_fecha_hora_btree; ANALYZE pedido;`) y quedó
comentado en `indices.sql` con el historial completo.

### Intervención complementaria — `SET LOCAL work_mem = '8MB'` (recomendada según TP4, no remedida en TP5)

En Q4 no hay `HashAggregate`: el nodo que se va a disco es el `Sort`
que alimenta al `Partial GroupAggregate` (`Sort Method: external merge`,
~4.5 MB a disco en el proceso principal y en uno de los workers, ver
`plan_q4_antes.txt`). En TP4-Parte 4 se trabajó esta misma consulta:
con `work_mem = '8MB'` el `Sort` pasó a `quicksort` en memoria, y con
`16MB` no mejoró (641.026 ms, peor que con 8MB), así que el valor
validado es 8MB. No depende de ningún índice (ataca el spill del
ordenamiento, no el filtro de fecha), así que con el B-tree descartado
queda como la única intervención aplicable a Q4. En TP5 no se volvió a
medir: se toma el resultado de TP4.

**Cierre del Caso 3:** dos candidatos descartados por motivos
distintos. El BRIN, por estadística (correlación ~0). El B-tree, por
medición: una mejora de ~8.9% en rondas sin archivar no se sostuvo al
remedir con la salida completa, y el plan mostró la pérdida de
paralelismo. La conclusión cambió dos veces, y cada cambio quedó
documentado: lo que se defiende es el proceso de medición, no un
resultado aislado.

## Caso 4 — Q2: Productos de una categoría en un rango de precio

*(Caso agregado en la corrección posterior a la devolución de la
cátedra: con el B-tree de Q4 descartado, la Parte A necesitaba otra
consulta con un cambio de plan real.)*

**Consulta:** Q2 de `queries.sql`:
```sql
SELECT id, nombre, precio_lista, stock
FROM producto
WHERE id_categoria = 1 AND precio_lista BETWEEN 1000 AND 3000
ORDER BY precio_lista;
```

**Plan "antes":** `plan_q2_antes.txt`. `Seq Scan on producto`: recorre
las 50.003 filas y descarta 38.955 (`Rows Removed by Filter`) para
quedarse con 11.048, más un `Sort` por `precio_lista`.

**Por qué no sirven los índices que ya existían sobre `producto`:**
`idx_productos_categoria_activo` e `idx_producto_categoria_precio_activo`
son **parciales** (`WHERE activo = TRUE`). Para usar un índice parcial,
la consulta tiene que garantizar esa condición en su propio `WHERE`.
Q2 no filtra por `activo`, así que usarlos dejaría afuera productos
inactivos que Q2 sí tiene que devolver.

### Candidato — `idx_producto_categoria_precio (id_categoria, precio_lista)`

Especificado en `specs/spec_06_producto_categoria_precio_sin_activo.md`.
Índice compuesto **no parcial**: `id_categoria` para la igualdad y
`precio_lista` para el rango.

**Medición (3 rondas intercaladas):** `Parte_A_Indices/medir_q2_rondas.sql`,
con la salida completa en `Parte_A_Indices/plan_q2_rondas_salida.txt`.
El candidato se creó dentro de `BEGIN...ROLLBACK` en cada ronda.

| Ronda | Sin índice (ms) | Con índice (ms) |
|---|---|---|
| 1 | 30.757 | 17.925 |
| 2 | 24.997 | 16.431 |
| 3 | 26.580 | 17.330 |
| **Promedio** | **27.4** | **17.2** |

El índice mejora en las 3 rondas (~37%), y los rangos no se superponen
(sin índice 25–31 ms, con índice 16–18 ms). El plan pasa de
`Seq Scan on producto` a `Bitmap Heap Scan` con `Bitmap Index Scan`
sobre `idx_producto_categoria_precio`, que lee solo las 11.048 filas
que cumplen el filtro. El `Sort` por `precio_lista` se mantiene en los
dos planes, porque el `Bitmap Heap Scan` no devuelve las filas
ordenadas.

**Antecedente de TP3:** este mismo índice se probó para Q2 en TP3 con
una sola corrida por lado y no mostró mejora (12.384 ms → 12.787 ms,
"dentro del ruido"). Con tiempos tan chicos, una corrida por lado no
alcanza para decidir; la medición de 3 rondas intercaladas de este TP
sí muestra una mejora consistente.

**Decisión: ACEPTADO Y APLICADO EN FIRME**
(`CREATE INDEX idx_producto_categoria_precio ON producto (id_categoria, precio_lista); ANALYZE producto;`).

## Punto 5 — Costo de los índices sobre la escritura

**Prueba 1 (inicial, sobre `detalle_pedido`, sin salida archivada):** insertar 500 filas en
`detalle_pedido` dentro de una transacción con `ROLLBACK`, midiendo el
tiempo total con `time` sobre el comando `psql`.

**Hallazgo previo a la medición:** el primer intento de generar las
500 filas usó subconsultas escalares no correlacionadas
(`(SELECT id FROM pedido ORDER BY random() LIMIT 1)`), el mismo bug ya
documentado en TP3 — PostgreSQL las resuelve una sola vez para toda la
sentencia, no una vez por fila. Resultado: `INSERT 0 1` en vez de
`INSERT 0 500`. Corregido con la misma técnica de TP3 (array_agg +
índice de array aleatorio por fila), confirmando `INSERT 0 500` antes
de medir el tiempo real.

| Momento | Índices nuevos aplicados | Tiempo real (`INSERT` 500 filas en `detalle_pedido`) |
|---|---|---|
| Antes | Ninguno | 1.036 s |
| Después | `idx_producto_categoria_precio_activo` (sobre `producto`) | 0.888 s |

**Observación (detectada en re-auditoría con Kiro):** esta primera
prueba no mide el escenario más relevante — el único índice aplicado
en firme vive en `producto`, no en `detalle_pedido`, así que el
resultado "sin cambio significativo" es esperable pero trivial: no
prueba el costo real de mantener un índice en la tabla donde
efectivamente se escribe.

**Prueba 2 (corregida, sobre `producto`, la tabla donde vive el
índice; sin salida archivada):** insertar 500 filas en `producto` (misma técnica de
`array_agg`, sin el bug de aleatoriedad ya que solo depende de
`categoria`, con apenas 2 filas — impacto insignificante), midiendo
antes de crear el índice y después, sobre la misma sesión:

```bash
psql ... -c "DROP INDEX idx_producto_categoria_precio_activo;"
time psql ... -c "BEGIN; INSERT INTO producto (...) SELECT ... FROM generate_series(1,500)...; ROLLBACK;"
psql ... -c "CREATE INDEX idx_producto_categoria_precio_activo ...;"
```

| Momento | Índice sobre `producto` | Tiempo real (`INSERT` 500 filas en `producto`) |
|---|---|---|
| Antes | Sin `idx_producto_categoria_precio_activo` | 0.101 s |
| Después | Con `idx_producto_categoria_precio_activo` | 0.267 s |

**Conclusión real:** al medir sobre la tabla correcta, el costo de
escritura **sí aumenta** con el índice presente (~2.6x más lento en
este caso, aunque en términos absolutos sigue siendo rápido:
milisegundos, no segundos). Esto es exactamente el comportamiento
esperado y el que pide demostrar la consigna: cada índice que se
agrega tiene un costo real de mantenimiento en cada `INSERT`/`UPDATE`
sobre esa tabla, que hay que sopesar contra el beneficio de lectura
que aporta (en este caso, ~41% de mejora en la Q6 del Caso 2 — un
trade-off razonable dado que `producto` se escribe con mucha menos
frecuencia de la que se lee en reportes analíticos).

La Prueba 1 se conserva en el informe (no se borra) porque documenta
un hallazgo metodológico real: medir el costo de escritura en una
tabla sin índices nuevos da un resultado trivial y no debe confundirse
con "los índices no tienen costo de escritura". Las Pruebas 1 y 2 se
midieron a mano con `time` y no tienen salida archivada; las mediciones
archivadas del costo de escritura son la Prueba 3 (`producto`) y la
Prueba 4 (`detalle_pedido`).


### Prueba 3 — `producto` con los dos índices aceptados (Q6 y Q2)

Con el Caso 4, `producto` pasa a tener dos índices nuevos de este TP.
Se midió el costo de escritura con los dos juntos:
`Parte_A_Indices/medir_escritura_producto_dos_indices.sql`, con la
salida completa en `Parte_A_Indices/medicion_escritura_producto_dos_indices_salida.txt`.
Son 500 `INSERT` en `producto` dentro de transacciones con `ROLLBACK`,
3 rondas intercaladas, medidas con `\timing` de `psql` (no con `time`
de consola).

**Ronda de calentamiento:** el primer `INSERT` de la sesión tardó
65.963 ms por arranque en frío. Queda en la salida, pero no se cuenta.
En una corrida anterior sin calentamiento, ese costo caía en la Ronda 1
"sin índices" y daba la conclusión falsa de que los índices aceleraban
la escritura.

| Ronda | Sin los 2 índices (ms) | Con los 2 índices (ms) |
|---|---|---|
| 1 | 13.505 | 18.407 |
| 2 | 11.225 | 17.462 |
| 3 | 12.578 | 19.168 |
| **Promedio** | **12.4** | **18.3** |

Con los dos índices, cada carga de 500 filas en `producto` tarda
alrededor de un 47% más, en las 3 rondas. Se acepta ese costo porque
`producto` se escribe poco y se lee mucho en reportes: a cambio, Q6
mejora ~41% y Q2 ~37%. Al terminar la prueba se corrió a mano
`VACUUM ANALYZE producto;` (no está en el script, así que no aparece
en la salida archivada), porque los `INSERT` deshechos con
`ROLLBACK` dejan filas muertas que le hacen perder a Q6 el
`Index Only Scan` sin ir al heap.

**Sobre `detalle_pedido`:** la consigna pide medir `INSERT` en
`detalle_pedido`. Ninguno de los índices aceptados vive en esa tabla,
así que un `INSERT` en `detalle_pedido` no tiene que mantenerlos (la
Prueba 1 ya lo mostró: sin diferencia significativa). El costo real de
los índices aceptados aparece en `producto`, y por eso se mide ahí.

**Tres índices sobre `producto` que empiezan por `id_categoria`:**
`idx_productos_categoria_activo` (heredado de TP1, parcial),
`idx_producto_categoria_precio_activo` (Q6, parcial) e
`idx_producto_categoria_precio` (Q2, no parcial). Los dos de TP5 no son
redundantes entre sí: Q2 no puede usar los parciales porque no filtra
por `activo`, y Q6 usa el parcial para resolver el `AVG` con
`Index Only Scan`. Con los dos presentes, un `EXPLAIN` de Q6 confirma
que sigue eligiendo `idx_producto_categoria_precio_activo`
(`Parte_A_Indices/plan_q6_con_dos_indices.txt`). El de TP1 no se toca,
porque está en `schema.sql` y el modelo heredado no se modifica.


### Prueba 4 — `detalle_pedido` con los dos índices aceptados

La consigna pide medir el costo de escritura con `INSERT` en
`detalle_pedido`. Script: `Parte_A_Indices/medir_escritura_detalle_pedido.sql`,
con la salida completa en `Parte_A_Indices/medicion_escritura_detalle_pedido_salida.txt`.
Son 500 `INSERT` en `detalle_pedido` (pares `id_pedido`/`id_producto`
válidos que todavía no existen), con `ROLLBACK` en cada carga, una
ronda de calentamiento y 3 rondas intercaladas, medidas con `\timing`.
En las rondas "sin índices", los dos `DROP INDEX` van en la misma
transacción que el `INSERT`, así que el `ROLLBACK` los restaura y la
base nunca queda sin ellos.

**Calentamiento:** 20.995 ms (no se cuenta).

| Ronda | Sin los 2 índices (ms) | Con los 2 índices (ms) |
|---|---|---|
| 1 | 8.067 | 9.163 |
| 2 | 7.195 | 8.876 |
| 3 | 7.805 | 8.646 |
| **Promedio** | **7.7** | **8.9** |

En las 3 rondas, la carga con índices fue algo más lenta, pero la
diferencia es de ~1,2 ms. No puede deberse a mantener los índices: los
dos viven en `producto`, y un `INSERT` en `detalle_pedido` no los
actualiza (mantiene la PK de `detalle_pedido` y el índice heredado
`idx_detalle_pedido_producto_id`, presentes en las dos condiciones, y verifica las FK
contra las PK de `pedido` y `producto`). Una explicación posible, que
no se verificó, es el orden fijo de las rondas: la ronda "con índices"
corre justo después de una transacción que borró y restauró índices de
`producto`, y PostgreSQL tiene que volver a cargar la información de
esa tabla. Comparado con la Prueba 3 (en `producto`, donde los índices
sí se mantienen: ~6 ms más sobre ~12 ms, un 47%), el efecto en
`detalle_pedido` es chico. **Conclusión:** el costo de escritura de los
índices aceptados se paga al escribir en `producto`, no en
`detalle_pedido`.

## Parte C — Vista materializada `mv_resumen_ventas_categoria_mes`

**Reporte:** facturación, cantidad de pedidos y unidades vendidas por
categoría y mes (`Parte_C_Vista_Materializada/specs/spec_05_resumen_ventas_categoria_mes.md`).
La vista se crea en `Parte_C_Vista_Materializada/vista_materializada.sql`
con `WITH DATA` y un índice único sobre `(id_categoria, mes)`, que es
lo que permite usar `REFRESH ... CONCURRENTLY`.

**Medición archivada (corrección posterior a la devolución):**
`Parte_C_Vista_Materializada/medir_refresh_parte_c.sql`, con la salida
completa en `Parte_C_Vista_Materializada/medir_refresh_parte_c_salida.txt`.
La medición original de la Parte C (618.156 ms contra 0.073 ms) no
había quedado archivada; los números de esta sección son los de la
salida.

### Consulta directa vs. vista materializada (3 rondas intercaladas)

| Ronda | Tablas base (ms) | Vista materializada (ms) |
|---|---|---|
| 1 | 1103.941 | 0.051 |
| 2 | 1002.192 | 0.060 |
| 3 | 822.318 | 0.052 |
| **Promedio** | **976.1** | **0.054** |

La ronda 1 de la consulta directa es la primera de la sesión y paga el
arranque en frío (`Planning Time: 25.273 ms`). Aun sin esa ronda
(rondas 2 y 3: 912.3 ms contra 0.056 ms), la vista responde unas 16.000 veces más
rápido: lee 26 filas ya calculadas, en lugar de cruzar `pedido`,
`detalle_pedido` (~500.000 filas), `producto` y `categoria` y agrupar.

### Costo del REFRESH: normal vs. CONCURRENTLY (3 rondas intercaladas)

| Ronda | `REFRESH` (ms) | `REFRESH ... CONCURRENTLY` (ms) |
|---|---|---|
| 1 | 956.124 | 907.325 |
| 2 | 920.415 | 878.248 |
| 3 | 932.677 | 881.295 |
| **Promedio** | **936.4** | **889.0** |

Los dos cuestan lo mismo que una consulta directa (~0,9 s), porque
recalculan la vista entera: la vista materializada no ahorra ese
trabajo, lo concentra en el momento del `REFRESH`. En esta base el
`CONCURRENTLY` fue ~5% más rápido en las 3 rondas, pero no es una
ventaja que se pueda generalizar: `CONCURRENTLY` calcula el resultado
nuevo aparte y lo compara fila por fila con la vista vieja (para eso
necesita el índice único), y aplica solo las diferencias. Con 26 filas
esa comparación no cuesta casi nada; con una vista grande, sería más
lento que el `REFRESH` normal.

### Bloqueos: qué le pasa al usuario que está leyendo el reporte

Cada `REFRESH` se ejecutó dentro de `BEGIN...ROLLBACK` y se consultó
`pg_locks` sobre la vista:

| Modo | Bloqueo principal sobre la vista | Otros bloqueos |
|---|---|---|
| `REFRESH` | `AccessExclusiveLock` | `ExclusiveLock`, `ShareLock` |
| `REFRESH ... CONCURRENTLY` | `ExclusiveLock` | `AccessShareLock`, `RowExclusiveLock` |

- **`REFRESH` normal:** `AccessExclusiveLock` es incompatible con
  todo, incluso con el `AccessShareLock` que toma un `SELECT`. Mientras
  dura el `REFRESH` (~0,9 s acá, y crece con los datos), cualquier
  usuario que abra el reporte queda esperando. Si ya hay una consulta
  larga en curso, el `REFRESH` espera a que termine y las lecturas
  nuevas se encolan detrás de él.
- **`REFRESH ... CONCURRENTLY`:** `ExclusiveLock` es compatible con
  `AccessShareLock`, así que los `SELECT` siguen funcionando y ven la
  versión anterior de la vista hasta que el `REFRESH` termina. Lo que
  sí bloquea es otro `REFRESH` simultáneo sobre la misma vista. Exige
  el índice único y que la vista ya tenga datos (no sirve sobre una
  vista creada con `WITH NO DATA`).

### Qué ve el usuario entre dos REFRESH

Dentro de `BEGIN...ROLLBACK` se canceló el pedido 6549 (`PENDIENTE`, de
septiembre de 2026), que solo tenía productos de la categoría 2:

| Momento | Vista: pedidos / facturación (cat. 2) | Consulta directa (cat. 2) |
|---|---|---|
| Antes de cancelarlo | 178 / 1.959.552,09 | 178 / 1.959.552,09 |
| Cancelado, sin `REFRESH` | **178 / 1.959.552,09** | 177 / 1.934.407,12 |
| Después del `REFRESH` | 177 / 1.934.407,12 | 177 / 1.934.407,12 |

Hasta el siguiente `REFRESH`, el reporte sigue contando un pedido
cancelado y $25.144,97 de facturación que ya no existe. El usuario no
recibe ningún error ni aviso: el dato está desactualizado sin que se
note. El `ROLLBACK` deshizo la cancelación y el `REFRESH`, y la
verificación final de la salida confirma que el pedido sigue
`PENDIENTE` y que la vista tiene las mismas 26 filas.

### Frecuencia de REFRESH recomendada

El reporte es de gestión: se usa para comparar categorías y meses, no
para operar los pedidos del momento. Con eso y con lo medido:

- **Una vez por día, de noche, con `CONCURRENTLY`.** Cuesta ~0,9 s por
  ejecución, lo mismo que una sola consulta directa, y con
  `CONCURRENTLY` nadie queda bloqueado si consulta el reporte en ese
  momento.
- **Qué implica para los usuarios:** durante el día, el reporte muestra
  los datos hasta el último `REFRESH`. Los meses cerrados casi no
  cambian, así que el desfase afecta sobre todo al mes en curso: los
  pedidos nuevos, las cancelaciones y los cambios de estado del día no
  aparecen hasta la noche, como muestra el ejemplo del pedido 6549.
  Para un reporte mensual, un día de desfase es aceptable, siempre que
  el usuario sepa que los datos son "al cierre del día anterior".
- **Cuándo no sirve:** si alguien necesita la facturación del día en
  tiempo real (por ejemplo, para cerrar caja), la vista materializada no
  es la herramienta: tiene que consultar las tablas base o una vista
  común. Refrescarla después de cada `INSERT` o `UPDATE` en `pedido`
  costaría ~0,9 s por cambio y anularía la ventaja.
- **`REFRESH` normal:** solo conviene en una ventana sin usuarios (por
  ejemplo, un mantenimiento), porque bloquea las lecturas mientras dura.
