# DUIA — TP5 (Unidad 3, Semana 5: Índices, vistas y vistas materializadas)

**Materia:** Base de Datos II
**Proyecto:** Food Store — continúa el esquema de TP1/TP3/TP4
**Base de trabajo:** `foodstore_tp3_carga`
**Herramientas obligatorias:** Kiro (especificación) + un agente de generación y ejecución de código (OpenCode en Parte A y B; GitHub Copilot en Parte C, según la herramienta de cada integrante; Claude Code en la primera tanda de correcciones posteriores a la devolución (Q4, Q2 y costo de escritura en `producto`), y Claude como asistente de chat en la auditoría del repositorio y las correcciones siguientes) + Git

Esta bitácora registra, para cada pieza del trabajo, qué herramienta se
usó, con qué propósito, el spec/prompt entregado, qué propuso la IA, y
qué se aceptó/modificó/descartó con su justificación técnica.

**Paso 4 del flujo obligatorio (commits descriptivos):** la primera
versión de este TP5 no cumplió este punto. La devolución de la cátedra
señaló que el historial de Git no reflejaba el proceso: no había un
commit por pieza, como afirmaba esta misma bitácora. Ese historial no
se reescribe (reescribirlo ocultaría justamente lo que se señaló). Las
correcciones posteriores a la devolución sí se subieron una por pieza,
en commits separados y descriptivos: la remedición y el descarte del
índice de Q4, el caso nuevo de Q2, el costo de escritura con los dos
índices de `producto`, esta corrección de la bitácora y la limpieza de
archivos duplicados. El historial es verificable con
`git log --oneline -- TP5_Indices_Vistas/`.


**Cómo se hizo la corrección (23/09):** una primera tanda de
correcciones posteriores a la devolución se hizo con agentes de IA
(GitHub Copilot y Claude Code) directamente sobre este repositorio,
con muchos cambios encadenados en una misma sesión. Para partir de la
versión que corrigió la cátedra (la misma que tiene el grupo) y rehacer
las correcciones de forma controlada, todo ese trabajo se guardó en la
rama `tp5-mejoras-23sep` y `main` se volvió a esa versión (commit
`5a31f4b`; el commit `0e6c147` deja la carpeta idéntica a la copia del
grupo). Después cada corrección se rehízo una por una sobre `main`,
trayendo de la rama solo los scripts y salidas ya medidos que
correspondían (Q4, Q2 y costo de escritura), revisando cada archivo
antes de commitearlo y sin tocar la Parte C. La rama queda como
respaldo y registro de esa primera tanda; lo que se entrega es `main`.

**Segunda ronda de correcciones (23/09, tarde):** con el trabajo ya
corregido, se le pidió a Claude Code una auditoría de solo lectura del
commit `b677c54`: verificar las correcciones anteriores, buscar errores
nuevos y revisar una lista de detalles opcionales. Después, con el
prompt "armame un plan de accion para solucionar tod, sin tocar ni
modificar nada solo examina y arma el plan", armó un plan de un commit
por tema. Claude Code no modificó ningún archivo. Cada hallazgo se
verificó contra los archivos y las salidas archivadas antes de
corregirlo, y las correcciones se hicieron con Claude (asistente de
chat), un commit por tema, a partir de `2753343`: la cronología del
`VACUUM` de Q6, la selectividad y el paralelismo de Q4, el índice
heredado de `detalle_pedido`, las afirmaciones que salían de la tanda
de Q5 sin archivar, la correlación de `fecha_hora` remedida con salida
archivada, los encabezados de los scripts, la Parte C (con el OK de su
responsable, ver la sección Parte C) y los textos generales. Se decidió
no cambiar la fila "Qué propuso" de Claude Code en el Caso 3, porque
registra lo que propuso en su momento, ni los `\echo` de los scripts
cuyo texto ya está en salidas archivadas.

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
sin comprender el mecanismo (en el Caso 3, el BRIN con `pages_per_range = 32` que propuso Kiro se
descartó antes de crearlo por la correlación ~0 de `fecha_hora`: con
esa correlación, ningún valor de `pages_per_range` lo haría útil).

### Caso 1 — Q5: Ranking de clientes por gasto total

| Campo | Detalle |
|---|---|
| Herramienta | Kiro |
| Propósito | Especificar y proponer índice a partir de `specs/spec_01_pedido_estado_detalle_join.md` |
| Spec entregado | Ver `specs/spec_01_pedido_estado_detalle_join.md` — consulta con filtro `estado <> 'CANCELADO'` y join a `detalle_pedido` sin índice sobre `id_pedido` (afirmación errónea del spec, corregida después: la PK `(id_pedido, id_producto)` ya cubre `id_pedido`; ver Candidato B) |
| Qué propuso | Dos candidatos: (A) `idx_pedido_no_cancelado_cliente (id_cliente) WHERE estado <> 'CANCELADO'`, (B) `idx_detalle_pedido_id_pedido (id_pedido)` — recomendó probar A primero |
| Herramienta | OpenCode |
| Propósito | Generar y ejecutar el `CREATE INDEX` candidato A, y una alternativa de `work_mem`, dentro de `BEGIN...ROLLBACK` |
| Qué se aceptó | `SET LOCAL work_mem = '16MB'` — remedición archivada (`plan_q5_rondas_salida.txt`): ~26% menos en las rondas 2 y 3 (409.6 → 302.0 ms; la ronda 1 del baseline paga el arranque en frío) y `Batches: 5 → 1` en las 3 rondas. La primera tanda de 9 corridas intercaladas (526.5 → 447.2 ms, −15.1%) no quedó archivada y se conserva como antecedente |
| Qué se descartó y por qué | Candidato A: el planificador no lo usó en ninguna corrida: en las 3 archivadas (`plan_q5_rondas_salida.txt`) `pedido` se sigue leyendo con `Parallel Seq Scan`, igual que en la primera tanda, sin archivar. Causa: `estado <> 'CANCELADO'` retiene ~75% de la tabla `pedido` — selectividad demasiado baja para que un índice parcial compita con `Seq Scan` paralelo. **Este es el caso de descarte por sobreindexación exigido por la consigna** (columna con condición parcial de baja selectividad) |
| Candidato B (descartado tras la devolución) | `idx_detalle_pedido_id_pedido (id_pedido)`: redundante con `pk_detalle_pedido (id_pedido, id_producto)`, que ya cubre `id_pedido` por ser su primera columna. El spec decía por error que no había índice sobre esa columna; se corrigió con una nota. Evidencia: `plan_detalle_por_id_pedido.txt` (la PK resuelve `WHERE id_pedido = 100` con `Index Scan`) y `plan_q5_indice_redundante.txt` (con el candidato creado dentro de `BEGIN...ROLLBACK`, el planificador no lo usa en Q5). Es el ejemplo literal de sobreindexación de la consigna: un índice redundante con otro existente |
| Herramienta y prompt (candidato B) | Claude Code generó `medir_indice_redundante_q5.sql` en la primera tanda de correcciones (rama `tp5-mejoras-23sep`), con este prompt: "Índice redundante con la PK. spec_01_pedido_estado_detalle_join.md dice que no hay ningún índice sobre detalle_pedido.id_pedido, y es falso: la PK (id_pedido, id_producto) lo cubre porque es su primera columna. Corregí el spec (sin borrar el error: agregá una nota de corrección). Después documentá el candidato B de la IA, idx_detalle_pedido_id_pedido, como SEGUNDO descarte por sobreindexación (índice redundante con otro ya existente). Demostralo con EXPLAIN ANALYZE de Q5 dentro de BEGIN...ROLLBACK, archivá el plan y agregalo a indices.sql (comentado), al informe y a la DUIA." La prueba directa `plan_detalle_por_id_pedido.txt` la agregó y ejecutó la integrante a partir de la auditoría con Claude (asistente de chat) |
| Remedición archivada (Q5) | Herramienta: Claude (asistente de chat) escribió `medir_q5_rondas.sql`; la integrante lo revisó, lo ejecutó y archivó `plan_q5_rondas_salida.txt`. Prompt: "Vamos, del punto uno al diez", sobre el punto 7 de la auditoría: "Q5: volver a medir las 3 rondas con salida archivada (Q5 tarda menos de 1 s por corrida)". Resultado: el Índice A no aparece en ningún plan; en las rondas 2 y 3, Baseline 409.6 ms, Índice A 407.7 ms y `work_mem` 302.0 ms. La ronda 1 del Baseline (795.6 ms) es arranque en frío y se muestra sin descartarla. Se confirman las decisiones: Índice A descartado y `work_mem` aceptado |

### Caso 2 — Q6: Productos con precio superior al promedio de su categoría

| Campo | Detalle |
|---|---|
| Herramienta | Kiro |
| Propósito | Proponer índice a partir de `specs/spec_02_producto_categoria_precio.md` |
| Qué propuso | `idx_producto_categoria_precio_activo (id_categoria, precio_lista DESC) WHERE activo = TRUE` — covering index parcial |
| Herramienta | OpenCode |
| Propósito | Ejecutar el índice dentro de `BEGIN...ROLLBACK` y medir contra el baseline de 271.205 s |
| Qué se aceptó | El índice: **APLICADO EN FIRME**. Medición inicial (dentro de BEGIN...ROLLBACK, sin salida archivada): 271.2s -> 220.9s (~19%). Medición final, tras aplicar el indice en firme y VACUUM ANALYZE (ver plan_q6_despues.txt): 271.2s -> 158.7s (~41%), confirmado `Index Only Scan` con `Heap Fetches: 0` |
| Modificación / salvedad | Se aceptó con la salvedad de que **no resuelve el problema real** (patrón O(n²) de la subconsulta correlacionada, ejecutada 50.003 veces). La solución real ya existe en TP4-Parte3 (reescritura con tabla derivada pre-agregada). Se acepta el índice igual porque no es redundante con el existente y aporta una mejora real (~41%, 271.2 s → 158.7 s), aunque la consulta sigue tardando minutos |

### Caso 3 — Q4: Top 3 productos por facturación por categoría

| Campo | Detalle |
|---|---|
| Herramienta | Kiro |
| Propósito | Proponer índice a partir de `specs/spec_03_pedido_fecha_brin.md`, comparando explícitamente B-tree vs. BRIN |
| Qué propuso | (1) B-tree `idx_pedido_fecha_hora_btree (fecha_hora DESC)`, (2) BRIN `idx_pedido_fecha_hora_brin (fecha_hora) WITH (pages_per_range=32)` — con advertencia propia de que ambos corren riesgo real, y recomendación de verificar `pg_stats.correlation` antes de crear el BRIN |
| Verificación previa | `SELECT correlation FROM pg_stats WHERE tablename='pedido' AND attname='fecha_hora'` → `0.013` (prácticamente nula; sin salida archivada). Remedido el 23/09 con salida archivada (`correlacion_fecha_hora_salida.txt`): `0.0072`. Cambia con cada `ANALYZE` porque sale de una muestra; en los dos casos es ~0 |
| Qué se descartó y por qué (BRIN) | **Descartado sin crearlo.** Con correlación ~0, un BRIN no puede eliminar rangos de páginas — evidencia estadística, no fue necesario medir |
| Herramienta | OpenCode |
| Propósito | Ejecutar y medir el B-tree dentro de `BEGIN...ROLLBACK` (no descartable solo con estadística) |
| Primera medición (revertida, sin salida archivada) | Una corrida única sugirió que el índice empeoraba (658 ms → 921 ms). Con ese único dato se había descartado |
| Segunda medición (sin salida archivada) | Re-auditoría detectó que era una sola corrida por lado. Se repitió con 3 rondas intercaladas: Baseline promedio 371.5 ms, B-tree promedio 338.5 ms (~8.9%). Se aceptó el índice, pero esas rondas no quedaron archivadas y la diferencia (33 ms) era menor que la variación de la misma consulta sin ningún cambio (365 a 910 ms) |
| Devolución de la cátedra | Señaló que el 8,9% estaba en un margen cercano al ruido medido |
| Herramienta | Claude Code (agente de codificación en la terminal), usado en la corrección posterior a la devolución |
| Propósito | Generar un script reproducible de 3 rondas intercaladas con la salida completa archivada, y ejecutarlo sobre `foodstore_tp3_carga` con respaldo previo (`pg_dump`) |
| Prompt entregado | "Contradicción en Q4. El informe dice que idx_pedido_fecha_hora_btree mejora un 8,9% (371,5 → 338,5 ms), pero plan_q4_antes.txt da 378 ms y plan_q4_despues.txt da 414 ms, y las 3 rondas no están archivadas. Creá Parte_A_Indices/medir_q4_rondas.sql que haga 3 rondas intercaladas (sin índice / con índice, usando DROP y CREATE del índice dentro de transacciones) con EXPLAIN (ANALYZE, BUFFERS), y archivá la salida completa. Con los resultados reales: si el índice mejora de forma consistente, actualizá los números del informe, la DUIA, indices.sql y el README; si no mejora, cambiá la decisión a descartado, sacá el índice de indices.sql (dejalo comentado con la justificación) y actualizá todos los documentos. En cualquiera de los dos casos, el informe tiene que explicar por qué los planes archivados antes no coincidían con el promedio." |
| Qué propuso | `medir_q4_rondas.sql` y su salida `plan_q4_rondas_salida.txt`. Sin índice: 767.5 / 704.0 / 628.3 ms (promedio 699.9 ms). Con índice: 729.2 / 688.9 / 706.6 ms (promedio 708.2 ms). Propuso descartar el índice por dirección inconsistente y pérdida de paralelismo: sin índice, `Parallel Seq Scan` en varios procesos (`loops=2` o `3`); con índice, `Bitmap Heap Scan` en un solo proceso (`loops=1`) |
| Qué se aceptó (decisión final) | Se leyeron el script y la salida completa, y se verificaron los 6 `Execution Time` y los nodos del plan antes de decidir. **`idx_pedido_fecha_hora_btree`: DESCARTADO.** El `DROP INDEX` en firme lo ejecutó la integrante a mano (`DROP INDEX idx_pedido_fecha_hora_btree; ANALYZE pedido;`); en `indices.sql` quedó comentado con el historial completo. Al revisar después, se vio que la pérdida de paralelismo no es constante: en `plan_q4_despues.txt` el mismo nodo tiene `loops=3` |
| Intervención complementaria | `SET LOCAL work_mem = '8MB'` — recomendada según TP4-Parte4 sobre esta misma consulta, no remedida en TP5. Ataca el spill del `Sort` (`external merge`) que alimenta al `GroupAggregate` (en Q4 no hay `HashAggregate`); en TP4, 16MB dio peor que 8MB. No depende de ningún índice, así que con el B-tree descartado queda como la única intervención aplicable a Q4 |

### Caso 4 — Q2: Productos de una categoría en un rango de precio

| Campo | Detalle |
|---|---|
| Contexto | Caso agregado en la corrección posterior a la devolución de la cátedra: con el B-tree de Q4 descartado, la Parte A necesitaba otra consulta con un cambio de plan real |
| Herramienta | Claude Code (agente de codificación en la terminal) |
| Propósito | Medir el plan actual de Q2, escribir la spec, proponer el índice, medirlo con 3 rondas intercaladas y aplicarlo o descartarlo según los números |
| Prompt entregado | "Nuevo caso para la Parte A: Q2 de queries.sql (productos de categoría 1 con precio entre 1000 y 3000). Tiene que seguir el flujo completo: 1. Medí el plan actual. Si no hace Seq Scan, documentalo y no hagas nada más. 2. Escribí primero el spec en Parte_A_Indices/specs/spec_06_... (consulta, frecuencia, columnas, criterio de aceptación). 3. Proponé el índice. Explicá por qué los índices parciales que ya existen sobre producto no le sirven a Q2, que no filtra por activo. 4. Hacé 3 rondas intercaladas antes y después dentro de transacciones y archivá la salida completa. 5. Aceptalo o descartalo según los números reales, en un commit propio." |
| Spec | `specs/spec_06_producto_categoria_precio_sin_activo.md`, escrita por Claude Code a partir del prompt (no con Kiro), antes de proponer el índice |
| Qué propuso | `idx_producto_categoria_precio (id_categoria, precio_lista)`, **no parcial**, porque los dos índices existentes sobre `producto` son parciales (`WHERE activo = TRUE`) y Q2 no filtra por `activo`. Medición: sin índice 30.8 / 25.0 / 26.6 ms (promedio 27.4 ms); con índice 17.9 / 16.4 / 17.3 ms (promedio 17.2 ms). El plan pasa de `Seq Scan` a `Bitmap Heap Scan` |
| Qué se aceptó | Se leyeron la spec, el script y la salida completa, y se verificaron los 6 `Execution Time` y los nodos del plan. **Aceptado y aplicado en firme** (~37%, 3 de 3 rondas, rangos sin superponerse) |
| Salvedad | En TP3 este mismo índice no había mostrado mejora (12.384 → 12.787 ms, una corrida por lado). Se documenta el antecedente: con tiempos de decenas de ms, una sola corrida no alcanza para decidir |

### Punto 5 — Costo de los índices sobre la escritura

| Campo | Detalle |
|---|---|
| Herramienta | Ninguna (medición directa con `psql` + `time`) |
| Hallazgo intermedio | El primer intento de generar 500 `INSERT` de prueba usó subconsultas escalares no correlacionadas (mismo bug de TP3: Postgres las resuelve una sola vez, no por fila). Resultado: `INSERT 0 1` en vez de `INSERT 0 500`. Corregido con la técnica de array + índice aleatorio por fila ya usada en TP3 |
| Medición (Pruebas 1 y 2, sin salida archivada) | Prueba 1 (sobre `detalle_pedido`, tabla sin índices nuevos): 1.036 s → 0.888 s, sin diferencia significativa — resultado trivial porque el índice de esa etapa vivía en `producto`, no en `detalle_pedido`. Prueba 2, corregida (sobre `producto`, la tabla donde vive el índice): `DROP INDEX` → medir sin índice (0.101 s) → recrear índice → medir con índice (0.267 s). **El costo de escritura sí aumenta con el índice presente** (~2.6x en este caso, aunque en términos absolutos ambos siguen siendo rápidos) |
| Herramienta (Prueba 3) | Claude Code, en la corrección posterior a la devolución: con el Caso 4 hay dos índices aceptados sobre `producto` |
| Prompt entregado (Prueba 3) | "Volvé a medir el costo de escritura en producto con 3 rondas intercaladas, SIN y CON los dos índices de TP5 juntos, y archivá la salida." Tras ver la primera corrida: "Agregá al script una ronda de calentamiento al principio (un INSERT + ROLLBACK que no se cuenta), volvé a correrlo, hacé VACUUM ANALYZE producto al final y archivá la salida nueva. En el informe, mostrá las rondas una por una y explicá el calentamiento. No saques la ronda 1 a mano sin decirlo." |
| Qué propuso y qué se aceptó (Prueba 3) | La primera corrida sin calentamiento daba el resultado invertido (los índices "aceleraban" la escritura) por el arranque en frío de la Ronda 1. Con calentamiento: 12.4 → 18.3 ms (+47%), en las 3 rondas. Se aceptó la medición con calentamiento, archivando todas las rondas. El `VACUUM ANALYZE producto` que pedía el prompt no quedó en el script: se corrió a mano después, por eso no está en la salida archivada. Además se verificó con `EXPLAIN` que Q6 sigue usando su índice parcial con el de Q2 presente (`plan_q6_con_dos_indices.txt`) |
| Herramienta (Prueba 4) | Claude (asistente de chat) escribió el script `medir_escritura_detalle_pedido.sql` a partir de la auditoría del repositorio; la integrante lo revisó, lo ejecutó y archivó la salida |
| Prompt entregado (Prueba 4) | "Vamos, del punto uno al diez", sobre el punto 5 de la auditoría: "La consigna pide INSERT en detalle_pedido antes y después de los índices nuevos, y hoy solo está la Prueba 1: una corrida por lado, con time de consola, sin archivo y medida antes de que existiera el índice de Q2. Arreglo: un script de 3 rondas con calentamiento, 500 INSERT en detalle_pedido sin y con los 2 índices aceptados, y la salida archivada." |
| Qué propuso y qué se aceptó (Prueba 4) | Script con los `DROP INDEX` dentro de la transacción del `INSERT` (el `ROLLBACK` los restaura). Resultado: 7.7 → 8.9 ms (~1,2 ms). Se aceptó la medición y se documentó que la diferencia no viene de mantener los índices, que viven en `producto`; la explicación posible (orden fijo de las rondas) quedó marcada como no verificada |

---

## Parte B — Vistas para los reportes del sistema

**Estado: implementada.**

### `usuarios.sql`

| Campo | Detalle |
|---|---|
| Herramienta | Kiro |
| Propósito | Especificar en `spec_04_vistas_reportes.md` la necesidad de una tabla de autenticación, ya que el esquema heredado no tenía ninguna |
| Herramienta | OpenCode |
| Propósito | Generar el DDL de `usuarios.sql` a partir de la especificación |
| Qué propuso | `CREATE TYPE rol_usuario` (enum) + `CREATE TABLE usuario` con `contrasena` como hash, sin modificar `cliente` ni ninguna tabla heredada |
| Qué se aceptó | Tal cual: tabla nueva e independiente (ver justificación de por qué esto no viola "no modificar el modelo de datos" más abajo) |

### `vistas.sql`

| Campo | Detalle |
|---|---|
| Herramienta | Kiro |
| Propósito | Especificar las 5 vistas en `spec_04_vistas_reportes.md` |
| Herramienta | OpenCode |
| Propósito | Generar el DDL de cada vista en `vistas.sql` |
| Qué propuso | `v_catalogo_productos`, `v_reporte_ventas_cliente`, `v_detalle_pedido_producto`, `v_usuario_publico`, `v_pedido_cliente` (esta última agregada tras una auditoría posterior, ver más abajo) |
| Qué se aceptó | Las 5, verificadas con `EXCEPT` bidireccional contra consultas manuales independientes (ver Punto 3 más abajo) |

### `seguridad_roles.sql`

| Campo | Detalle |
|---|---|
| Herramienta | Kiro |
| Propósito | Especificar el rol de seguridad exigido por el punto 4 de la consigna |
| Herramienta | OpenCode |
| Propósito | Generar el rol y los `GRANT`/`REVOKE` en `seguridad_roles.sql` |
| Qué propuso | Rol `tp5_reportes` (`NOLOGIN`), `REVOKE ALL` sobre las tablas base, `GRANT SELECT` solo sobre las vistas (incluida la materializada de Parte C) |
| Qué se aceptó | Verificado con `SET ROLE` + intento fallido real sobre `usuario` (ver `evidencia_permiso_denegado.txt`) |

### Corrección posterior a la devolución: datos de `usuario` y verificación

| Campo | Detalle |
|---|---|
| Herramienta | Claude (asistente de chat), a partir de una auditoría del repositorio contra la consigna y la devolución |
| Prompt entregado | "Vamos, del punto uno al diez", sobre los puntos 3 y 4 de la auditoría: "Datos de usuario en el repo (Admin, Vero, más un caso con eliminado = TRUE)" y "Verificación de las vistas con count(*) y salida archivada" |
| Qué propuso | `usuarios_datos.sql` (versiona Admin y Vero, que se habían cargado a mano, y agrega un usuario dado de baja; idempotente con `ON CONFLICT (mail) DO NOTHING`) y una sección 6 en `verificacion_vistas.sql` que compara, por vista, las diferencias con `EXCEPT` y la cantidad de filas de cada lado |
| Qué se aceptó | Las dos cosas, después de leer el SQL y correrlo sobre `foodstore_tp3_carga`: `v_usuario_publico` muestra 2 de los 3 usuarios (oculta al dado de baja) y las 5 vistas dan 0 diferencias y la misma cantidad de filas que su consulta manual. Salida archivada en `Parte_B_Vistas/verificacion_vistas_salida.txt` |

La consigna pide tres vistas (productos vigentes con categoría, pedidos
con datos del cliente, detalle de pedido con nombre de producto) más
una vista que aplique el criterio de seguridad visto en la teoría. El
esquema heredado de TP1-TP4 usa `cliente`, sin tabla de autenticación.
Se agregó una tabla
`usuario` nueva (con contraseña como hash y un enum de rol), sin
reemplazar `cliente` ni afectar las consultas ya existentes — así se
implementó en `usuarios.sql`.

Esta adición es la única modificación al modelo de datos heredado, y
está acotada a un requisito puntual de la propia consigna: el punto 4
exige una vista de seguridad que oculte la columna `contrasena`, pero
ninguna tabla del esquema heredado (`cliente`, `pedido`, `producto`,
`categoria`, `detalle_pedido`) tiene una columna de autenticación con
ese propósito. Cumplir literalmente ese punto sin agregar una tabla
nueva es imposible: no hay contraseña que ocultar si no existe la
columna. La restricción de "no modificar el modelo de datos" se
interpretó, por lo tanto, como protección de las tablas y relaciones
ya existentes (no se modificó ninguna columna, tipo ni restricción de
`cliente`, `pedido`, `producto`, `categoria` ni `detalle_pedido`), y
no como una prohibición de agregar una tabla nueva e independiente
cuando la propia consigna exige, en otro punto, una funcionalidad que
solo esa tabla puede sostener.

Kiro especificó las vistas en `specs/spec_04_vistas_reportes.md`; OpenCode generó `usuarios.sql` y `vistas.sql` a partir de esa especificación, dentro del flujo obligatorio especificar → generar → verificar.
El SQL generado por OpenCode (`usuarios.sql`, `vistas.sql`,
`seguridad_roles.sql`) se revisó contra lo pedido en
`specs/spec_04_vistas_reportes.md` antes de ejecutarlo; la corrección
del resultado se confirmó después con la verificación de equivalencia
bidireccional descrita más abajo.

`vistas.sql` define las cinco vistas, especificadas en
`specs/spec_04_vistas_reportes.md`:

- `v_catalogo_productos` — productos vigentes (`activo = TRUE`) con su categoría.
- `v_reporte_ventas_cliente` — pedidos no cancelados agregados por cliente.
- `v_detalle_pedido_producto` — detalle de pedido con el nombre del producto.
- `v_usuario_publico` — vista de seguridad: expone `usuario` sin la
  columna `contrasena`, cumpliendo el punto 4 de la consigna.
- `v_pedido_cliente` — pedidos con los datos del cliente, fila a fila,
  cumpliendo literalmente el punto 1 de la consigna (agregada tras una
  auditoria que detectó que `v_reporte_ventas_cliente` era un agregado,
  no la vista plana que pide el enunciado).

`seguridad_roles.sql` crea el rol grupal `tp5_reportes` (NOLOGIN),
revoca todo permiso sobre las tablas base y concede `SELECT`
únicamente sobre las vistas (incluida la vista materializada de la
Parte C). La verificación queda en `verificacion_vistas.sql`, con dos
partes: (1) se comprueban las columnas expuestas por
`v_usuario_publico`, se consultan las vistas con
`SET ROLE tp5_reportes`, y se confirma que la consulta directa sobre
`usuario` falla por falta de privilegios (evidencia real capturada en `Parte_B_Vistas/evidencia_permiso_denegado.txt`); (2) **verificación de
equivalencia (punto 3 de la consigna)**: cada una de las 5 vistas se
compara, con `EXCEPT` en ambos sentidos, contra una consulta manual
escrita de forma independiente — `v_reporte_ventas_cliente` en
particular se verificó contra una versión con subconsultas escalares,
deliberadamente distinta a la forma con `JOIN + GROUP BY` de la vista,
para que la comparación sea real. `v_pedido_cliente` se verificó contra un JOIN directo pedido-cliente. Los 5 bloques devuelven 0 filas. En la corrección posterior a la devolución se agregaron dos cosas: `usuarios_datos.sql`, que versiona los usuarios de la tabla `usuario` (incluido uno dado de baja, que la vista oculta), y una sección 6 en el script que compara también la cantidad de filas, porque `EXCEPT` no detecta duplicados. La salida completa quedó archivada en `Parte_B_Vistas/verificacion_vistas_salida.txt`: las 5 vistas dan 0 diferencias y la misma cantidad de filas que su consulta manual (50.003, 20.003, 499.571, 2 y 200.005).

**Sobre la prueba reversible (punto 3 del flujo obligatorio):** a
diferencia de los índices de Parte A —que se probaron dentro de
`BEGIN...ROLLBACK` porque reconstruir un índice sobre una tabla de
cientos de miles de filas es costoso y su descarte debía quedar sin
rastro—, `usuarios.sql`, `vistas.sql` y `seguridad_roles.sql` son
operaciones no destructivas y de costo trivial: `CREATE VIEW`,
`CREATE TABLE` y `GRANT`/`REVOKE` no modifican datos existentes y se
deshacen al instante con `DROP VIEW`, `DROP TABLE` o revocando el rol,
sin necesidad de envolverlas en una transacción de prueba. La
verificación de corrección se hizo antes de darlas por definitivas:
cada vista se validó con el bloque `EXCEPT` bidireccional de
`verificacion_vistas.sql` (ver más arriba), y solo después de que las
5 comparaciones devolvieran 0 filas se consideraron aplicadas en
firme.

## Parte C — Vista materializada

**Estado: implementada y aplicada en firme.**

| Campo | Detalle |
|---|---|
| Herramienta | Kiro |
| Propósito | Elegir el reporte agregado costoso a materializar y especificar la vista a partir de `specs/spec_05_resumen_ventas_categoria_mes.md`: facturación, pedidos y unidades vendidas por categoría y mes |
| Herramienta | GitHub Copilot (agente de VS Code) |
| Prompt entregado | No se conservó el texto literal. Según el propósito registrado abajo, se le pidió generar y ejecutar `vista_materializada.sql` a partir de `specs/spec_05_resumen_ventas_categoria_mes.md`. La consigna pide OpenCode como agente de generación: en esta parte se usó GitHub Copilot, y la cátedra lo observó en la devolución. Se usó Copilot porque OpenCode no funcionaba correctamente en el entorno de trabajo, algo que el docente sabía durante la cursada. La pieza no se rehízo con otra herramienta; la corrección posterior se registra más abajo, con su prompt |
| Propósito | Generar y ejecutar `vista_materializada.sql`: crear la vista, el índice único, y correr `REFRESH MATERIALIZED VIEW` |
| Qué propuso | `mv_resumen_ventas_categoria_mes`, creada con `WITH DATA` más un índice único sobre `(id_categoria, mes)` para habilitar a futuro `REFRESH MATERIALIZED VIEW CONCURRENTLY` |
| Qué se hizo | Se creó la vista con los datos cargados en el mismo `CREATE`, se creó el índice único, y se midió con `EXPLAIN ANALYZE` la consulta sobre las tablas base y sobre la vista materializada |
| Resultados | Consulta sobre tablas base: **618.156 ms** (4 Hash Join + Seq Scans sobre 499.571 filas de `detalle_pedido` + Sort con spill a disco). Consulta sobre la vista: **0.073 ms** (Seq Scan sobre 26 filas + quicksort en memoria). Mejora ~8468x. Medición original, sin salida archivada: la medición archivada está en la corrección posterior, más abajo |
| Frecuencia de refresh recomendada | El reporte es mensual y los datos no necesitan estar al segundo: se recomienda un `REFRESH` diario (por ejemplo, por cron nocturno) en vez de por cada `INSERT`/`UPDATE` de `pedido`/`detalle_pedido` — el costo del `REFRESH` (~0,9 s según la medición archivada de la corrección posterior, equivalente a la consulta base) se paga una sola vez y no impacta las lecturas del resto del día |
| Qué se aceptó | La vista queda **aplicada en firme** en `foodstore_tp3_carga`, con el índice único que habilita `REFRESH CONCURRENTLY`. En la corrección posterior, `REFRESH CONCURRENTLY` pasó a ejecutarse en el paso 5 de `vista_materializada.sql` |
| Prueba reversible previa | Antes de aplicarse en firme, se validó como prueba de concepto: se creó la vista con `WITH NO DATA`, se cargó con `REFRESH MATERIALIZED VIEW`, se midió con `EXPLAIN ANALYZE`, y se eliminó con `DROP MATERIALIZED VIEW` sin dejar nada aplicado. Confirmado el resultado, se volvió a crear con `WITH DATA` para la aplicación en firme (equivalente al `BEGIN...ROLLBACK` de Parte A, adaptado a que un `REFRESH` de vista materializada no se prueba dentro de una transacción de forma útil) |
| Lectura previa | El SQL generado (`CREATE MATERIALIZED VIEW`, el índice único, el `REFRESH`) se revisó contra lo pedido en `specs/spec_05_resumen_ventas_categoria_mes.md` antes de ejecutarlo; la corrección del resultado se confirmó después con la medición `EXPLAIN ANALYZE` y con la prueba `WITH NO DATA`/`DROP` descrita arriba |
| Observación de la cátedra | No se analizaron las consecuencias del `REFRESH` para los usuarios, `REFRESH CONCURRENTLY` no se ejecutó (quedaba como comentario) y se usó Copilot en lugar de OpenCode |
| Corrección posterior: herramienta | Claude (asistente de chat), con el OK del integrante a cargo de la Parte C. Primero se amplió el criterio de aceptación en `spec_05` (complemento del 23/09) y después se generó el script a partir de ese criterio |
| Corrección posterior: prompt | "esto lo hacemos ahora tambien ya me dio el ok mateo", sobre estos puntos de la auditoría: el `REFRESH ... CONCURRENTLY`, el README de la Parte C que no existe y la fila del prompt de Copilot en la DUIA |
| Corrección posterior: qué propuso | `medir_refresh_parte_c.sql`: 3 rondas intercaladas de la consulta directa contra la vista; 3 rondas de `REFRESH` contra `REFRESH CONCURRENTLY`; `pg_locks` de cada `REFRESH` dentro de `BEGIN...ROLLBACK`, y la cancelación de un pedido dentro de `BEGIN...ROLLBACK` para mostrar el dato desactualizado. Además, pasar el `CONCURRENTLY` del paso 5 de comentario a sentencia |
| Corrección posterior: qué se aceptó | Se leyó el script antes de correrlo y se archivó la salida (`medir_refresh_parte_c_salida.txt`), sin errores y con la base igual al terminar. Resultados: 976.1 ms contra 0.054 ms; `REFRESH` 936.4 ms y `CONCURRENTLY` 889.0 ms; `AccessExclusiveLock` contra `ExclusiveLock`; la vista siguió mostrando 178 pedidos y 1.959.552,09 de la categoría 2 hasta el `REFRESH`. Se aceptó todo, salvo generalizar que `CONCURRENTLY` sea más rápido: con 26 filas la comparación fila por fila no cuesta casi nada, y con una vista grande sería más lento. El análisis completo y la frecuencia recomendada están en `informe_mediciones.md`, sección Parte C |

## Resumen de aceptado/descartado (Parte A)

| Pieza | Decisión | Motivo |
|---|---|---|
| `idx_pedido_no_cancelado_cliente` | Descartado | Ignorado por el planificador (baja selectividad, ~75%) |
| `SET LOCAL work_mem = '16MB'` (Q5) | Aceptado | ~26% en la remedición archivada (rondas 2 y 3: 409.6 → 302.0 ms) y `Batches: 5 → 1` en las 3 rondas; la primera tanda, sin archivar, había dado −15.1% |
| `idx_producto_categoria_precio_activo` | **Aceptado (aplicado en firme)** | Mejora real ~41% (271.2s -> 158.7s, medicion final tras VACUUM ANALYZE; ver informe_mediciones.md Caso 2), con salvedad de que no resuelve el O(n²) de fondo |
| `idx_pedido_fecha_hora_brin` | Descartado sin crear | Correlación física ~0 |
| `idx_pedido_fecha_hora_btree` | Descartado (tras remedir) | El 8,9% salía de rondas sin archivar, cercano al ruido. Remedición con salida archivada (3 rondas): 699.9 → 708.2 ms, dirección inconsistente y pérdida de paralelismo |
| `SET LOCAL work_mem = '8MB'` (Q4) | Recomendado según TP4 | Validado en TP4 sobre la misma consulta (Sort a memoria; 16MB dio peor), no remedido en TP5; con el B-tree descartado, es la única intervención aplicable a Q4 |
| `idx_producto_categoria_precio` (Q2) | **Aceptado (aplicado en firme)** | ~37% en 3 de 3 rondas (27.4 → 17.2 ms), `Seq Scan` → `Bitmap Heap Scan`. Los índices parciales existentes no le sirven a Q2, que no filtra por `activo` |
| `idx_detalle_pedido_id_pedido` | Descartado (redundante) | La PK `(id_pedido, id_producto)` ya cubre `id_pedido`; el planificador no lo usa en Q5 |