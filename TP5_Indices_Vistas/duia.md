# DUIA — TP5 (Unidad 3, Semana 5: Índices, vistas y vistas materializadas)

**Materia:** Base de Datos II
**Proyecto:** Food Store — continúa el esquema de TP1/TP3/TP4
**Base de trabajo:** `foodstore_tp3_carga`
**Herramientas obligatorias:** Kiro (especificación) + OpenCode (generación y ejecución) + Git

Esta bitácora registra, para cada pieza del trabajo, qué herramienta se
usó, con qué propósito, el spec/prompt entregado, qué propuso la IA, y
qué se aceptó/modificó/descartó con su justificación técnica.

---

## Parte A — Plan de indexado asistido por IA

### Lectura línea por línea antes de ejecutar (consigna, punto 3 del flujo obligatorio)

Antes de aplicar cualquier `CREATE INDEX` generado por OpenCode —tanto
dentro de `BEGIN...ROLLBACK` para pruebas como al aplicar en firme— se
leyó el SQL propuesto y se verificó explícitamente:

- Que el tipo de índice (B-tree, parcial, covering, BRIN) coincidiera
  con lo que pedía la spec correspondiente.
- Que las columnas y su orden fueran las que participan del filtro,
  join u `ORDER BY` real de la consulta (no genéricas).
- Que ningún `CREATE INDEX` tocara el modelo de datos ni agregara
  restricciones no pedidas.
- En los casos con condición parcial (`WHERE activo = TRUE`,
  `WHERE estado <> 'CANCELADO'`), que la condición coincidiera
  exactamente con el filtro de la consulta que se buscaba optimizar.

Ningún índice se ejecutó "a ciegas": los que no se entendían del todo
al proponerse (por ejemplo, el `pages_per_range` del candidato BRIN)
se investigaron antes de decidir, no se aplicaron ni se descartaron
sin comprender el mecanismo (ver Caso 3 más abajo, donde el
`pages_per_range = 32` propuesto por Kiro se justificó explícitamente
antes de decidir no crear el índice).

### Caso 1 — Q5: Ranking de clientes por gasto total

| Campo | Detalle |
|---|---|
| Herramienta | Kiro |
| Propósito | Especificar y proponer índice a partir de `specs/spec_01_pedido_estado_detalle_join.md` |
| Spec entregado | Ver `specs/spec_01_pedido_estado_detalle_join.md` — consulta con filtro `estado <> 'CANCELADO'` y join a `detalle_pedido` sin índice sobre `id_pedido` |
| Qué propuso | Dos candidatos: (A) `idx_pedido_no_cancelado_cliente (id_cliente) WHERE estado <> 'CANCELADO'`, (B) `idx_detalle_pedido_id_pedido (id_pedido)` — recomendó probar A primero |
| Herramienta | OpenCode |
| Propósito | Generar y ejecutar el `CREATE INDEX` candidato A, y una alternativa de `work_mem`, dentro de `BEGIN...ROLLBACK` |
| Qué se aceptó | `SET LOCAL work_mem = '16MB'` — control de ruido con 9 corridas intercaladas (3 escenarios x 3 rondas): promedio 526.5 ms (baseline) → 447.2 ms (work_mem), −15.1% |
| Qué se descartó y por qué | Candidato A: el planificador lo ignoró en las 9/9 corridas (`Índice ignorado` en el plan, siempre). Causa: `estado <> 'CANCELADO'` retiene ~75% de la tabla `pedido` — selectividad demasiado baja para que un índice parcial compita con `Seq Scan` paralelo. **Este es el caso de descarte por sobreindexación exigido por la consigna** (columna con condición parcial de baja selectividad) |

### Caso 2 — Q6: Productos con precio superior al promedio de su categoría

| Campo | Detalle |
|---|---|
| Herramienta | Kiro |
| Propósito | Proponer índice a partir de `specs/spec_02_producto_categoria_precio.md` |
| Qué propuso | `idx_producto_categoria_precio_activo (id_categoria, precio_lista DESC) WHERE activo = TRUE` — covering index parcial |
| Herramienta | OpenCode |
| Propósito | Ejecutar el índice dentro de `BEGIN...ROLLBACK` y medir contra el baseline de 271.205 s |
| Qué se aceptó | El índice: **APLICADO EN FIRME**. Mejora real 271.2s → 220.9s (~19%), confirmado `Index Only Scan` con `Heap Fetches: 0` |
| Modificación / salvedad | Se aceptó con la salvedad de que **no resuelve el problema real** (patrón O(n²) de la subconsulta correlacionada, ejecutada 50.003 veces). La solución real ya existe en TP4-Parte3 (reescritura con tabla derivada pre-agregada). Se acepta el índice igual porque no es redundante con el existente y aporta mejora real, aunque modesta |

### Caso 3 — Q4: Top 3 productos por facturación por categoría

| Campo | Detalle |
|---|---|
| Herramienta | Kiro |
| Propósito | Proponer índice a partir de `specs/spec_03_pedido_fecha_brin.md`, comparando explícitamente B-tree vs. BRIN |
| Qué propuso | (1) B-tree `idx_pedido_fecha_hora_btree (fecha_hora DESC)`, (2) BRIN `idx_pedido_fecha_hora_brin (fecha_hora) WITH (pages_per_range=32)` — con advertencia propia de que ambos corren riesgo real, y recomendación de verificar `pg_stats.correlation` antes de crear el BRIN |
| Verificación previa | `SELECT correlation FROM pg_stats WHERE tablename='pedido' AND attname='fecha_hora'` → `0.013` (prácticamente nula) |
| Qué se descartó y por qué (BRIN) | **Descartado sin crearlo.** Con correlación ~0, un BRIN no puede eliminar rangos de páginas — evidencia estadística, no fue necesario medir |
| Herramienta | OpenCode |
| Propósito | Ejecutar y medir el B-tree dentro de `BEGIN...ROLLBACK` (no descartable solo con estadística) |
| Primera medición (revertida) | Una corrida única sugirió que el índice empeoraba (658 ms → 921 ms). Con ese único dato se había descartado |
| Corrección con control de ruido | Re-auditoría detectó que era una sola corrida por lado (mismo error metodológico ya evitado en Caso 1). Se repitió con 3 rondas intercaladas: Baseline promedio 371.5 ms, B-tree promedio 338.5 ms — el índice ganó en 3/3 rondas, dirección consistente |
| Qué se aceptó (decisión final) | **`idx_pedido_fecha_hora_btree`: ACEPTADO Y APLICADO EN FIRME**, revirtiendo la conclusión inicial errónea. Mejora real ~8.9%. Se documenta el cambio de conclusión completo, no se oculta el error metodológico inicial |
| Intervención complementaria | `SET LOCAL work_mem = '16MB'` — ya confirmado en TP4-Parte4 sobre esta misma consulta (ataca el spill del `HashAggregate`, distinto del filtro de fecha que ataca el índice de arriba). No remedido el efecto combinado |

### Punto 5 — Costo de los índices sobre la escritura

| Campo | Detalle |
|---|---|
| Herramienta | Ninguna (medición directa con `psql` + `time`) |
| Hallazgo intermedio | El primer intento de generar 500 `INSERT` de prueba usó subconsultas escalares no correlacionadas (mismo bug de TP3: Postgres las resuelve una sola vez, no por fila). Resultado: `INSERT 0 1` en vez de `INSERT 0 500`. Corregido con la técnica de array + índice aleatorio por fila ya usada en TP3 |
| Medición | Prueba 1 (sobre `detalle_pedido`, tabla sin índices nuevos): 1.036 s → 0.888 s, sin diferencia significativa — resultado trivial porque el índice de esa etapa vivía en `producto`, no en `detalle_pedido`. Prueba 2, corregida (sobre `producto`, la tabla donde vive el índice): `DROP INDEX` → medir sin índice (0.101 s) → recrear índice → medir con índice (0.267 s). **El costo de escritura sí aumenta con el índice presente** (~2.6x en este caso, aunque en términos absolutos ambos siguen siendo rápidos) |

---

## Parte B — Vistas para los reportes del sistema

**Estado: pendiente.**

## Parte C — Vista materializada

**Estado: pendiente.**

---

## Resumen de aceptado/descartado (Parte A)

| Pieza | Decisión | Motivo |
|---|---|---|
| `idx_pedido_no_cancelado_cliente` | Descartado | Ignorado por el planificador (baja selectividad, ~75%) |
| `SET LOCAL work_mem = '16MB'` (Q5) | Aceptado | −15.1% real, confirmado con 9 corridas |
| `idx_producto_categoria_precio_activo` | **Aceptado (aplicado en firme)** | +19% real, con salvedad de que no resuelve el O(n²) de fondo |
| `idx_pedido_fecha_hora_brin` | Descartado sin crear | Correlación física ~0 |
| `idx_pedido_fecha_hora_btree` | **Aceptado (aplicado en firme)** | Primera corrida sugería descarte (658→921ms); control de 3 rondas intercaladas lo revirtió: +8.9% real, 3/3 rondas consistentes |
| `SET LOCAL work_mem = '16MB'` (Q4) | Aceptado (complementario) | Ya confirmado en TP4 sobre la misma consulta; ataca un cuello de botella distinto al del índice |