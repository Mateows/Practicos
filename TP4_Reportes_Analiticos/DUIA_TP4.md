# DUIA — TP4 Reportes Analíticos (consolidada)

**Materia:** Base de Datos II
**Trabajo práctico:** TP4 — Unidad 2: Reportes analíticos sobre Food Store
**Proyecto:** Food Store
**Alumnos:** Mateo Lautaro Liendo, Lucas Avila, Amanda Pagano
**Docente:** Sergio Neira 
**Motor:** PostgreSQL 17
**Base de trabajo:** `foodstore_tp3_carga`

Esta declaración consolida el uso de IA de las 4 partes del TP4. La
Parte 1 fue trabajada por Mateo (detalle completo en
`Parte1/DUIA_Parte1.md`); la Parte 2 fue trabajada por Lucas; las
Partes 3 y 4 fueron trabajadas por Amanda (detalle completo en los
archivos de sus respectivas carpetas).

## Parte 1 — Laboratorio: consultas analíticas lentas 

| Herramienta | Para qué se usó | Prompt / spec (resumen) | Se aceptó / se descartó |
|---|---|---|---|
| Kiro / GitHub Copilot | Analizar los planes iniciales de las consultas A y B, identificar algoritmos de JOIN, nodos costosos y proponer índices | Planes reales de `EXPLAIN (ANALYZE, BUFFERS, VERBOSE)` sobre la base masiva, pidiendo distinguir Hash Join / Parallel Hash Join / Nested Loop / Merge Join | Se conservaron las propuestas solo como hipótesis; la medición real tuvo prioridad sobre la explicación de la IA |
| Kiro / GitHub Copilot | Probar el índice propuesto para la Consulta A (`idx_tp4_a_estado_id`) dentro de una transacción reversible | `BEGIN` + `CREATE INDEX` + `EXPLAIN ANALYZE` + `ROLLBACK` | **Aceptada:** Parallel Index Only Scan, Heap Fetches: 0, tiempo 699.55ms → 164.25ms, se aplicó en firme |
| Kiro / GitHub Copilot | Probar el índice propuesto para la Consulta B (`idx_tp4_b_no_cancelado`) | Mismo protocolo de transacción reversible | **Descartada:** el índice no fue utilizado por el planificador, tiempo prácticamente igual (304.75ms → 305.60ms) |

**Ver también:** `Parte1/DUIA_Parte1.md` (detalle completo, incluye
criterio de aceptación y verificación de la base de datos).

## Parte 2 — Lectura crítica de planes de join interpretados por IA (Lucas)

| Herramienta | Para qué se usó | Prompt / spec (resumen) | Se aceptó / se descartó |
|---|---|---|---|
| Kiro | Generar una explicación en lenguaje natural del plan real de la Consulta A (Parte 1), identificando nodos de JOIN, uso de índice, paralelismo, y diferencia entre costo estimado y tiempo real | Se le pasó el plan `EXPLAIN ANALYZE` sin contexto adicional, pidiendo explicación nodo por nodo e identificar entrada externa/interna de cada `Hash Join` | La explicación se usó como hipótesis; cada afirmación se contrastó con el plan real antes de incorporarla |
| GitHub Copilot (agente de VS Code) | Organizar la lectura crítica, comparar la respuesta de Kiro contra la evidencia del plan y corregir imprecisiones | Se pidió estructurar la explicación, completar la tabla de afirmaciones y verificar puntualmente `Heap Fetches: 0`, `Workers Planned/Launched` y `cost` vs. `Execution Time` | Se aceptaron las afirmaciones respaldadas por el plan; se corrigió que `Heap Fetches: 0` también depende del mapa de visibilidad, y que el costo del optimizador no equivale a milisegundos |

**Hallazgos de la tabla de lectura crítica** (7 afirmaciones evaluadas): 6 correctas, 1 parcialmente correcta (`Heap Fetches: 0` — la IA lo atribuyó solo a que el índice es covering, sin mencionar el mapa de visibilidad), 1 incorrecta (la IA no cometió este error, se incluyó como control: "el costo 26686.93 equivale a 26.686 milisegundos" es falso, el costo no tiene conversión directa a tiempo).

**Ver también:** `Parte2/DUIA_Parte2.md` y `Parte2/plan_a_explicacion_ia.md`
(detalle completo, incluye el plan real completo y la explicación nodo
por nodo).

## Parte 3 — Consultas resumen, rankings y subconsultas 

| Herramienta | Para qué se usó | Prompt / spec (resumen) | Se aceptó / se descartó |
|---|---|---|---|
| Kiro | Generar la Consulta A (ranking con función de ventana) v1 y una v2 con estructura distinta, y verificar equivalencia con EXCEPT | Spec precisa: ranking de clientes por gasto (`DENSE_RANK`), sin filtro de borrado lógico en cliente/detalle_pedido (no existe esa columna en el esquema), empates comparten puesto | La primera V2 propuesta (subconsulta correlacionada con `COUNT(*)`) fue **rechazada**: el EXCEPT dio 19.433 filas de diferencia — no era equivalente a V1. Causa: `COUNT(*)` replica la semántica de `RANK()` (deja huecos tras un empate), no de `DENSE_RANK()`. Se corrigió a `COUNT(DISTINCT total_gastado)`, y el EXCEPT confirmó 0 filas en ambos sentidos — **aceptada** |
| Kiro | Generar la Consulta B (subconsulta correlacionada) v1 y v2 (JOIN con promedio pre-agregado), verificar equivalencia | Spec precisa: productos activos con precio mayor al promedio de su categoría activa | **Aceptada de entrada:** 0 filas de diferencia en el EXCEPT en ambos sentidos. V1 tardó minutos por ser O(n²) sobre 50k productos; V2 (pre-agregada) resolvió en segundos — mismo resultado, rendimiento muy distinto |

**Ver también:** `Parte3/DUIA_Parte3.md`,
`Parte3/consulta_a_ranking.sql` y
`Parte3/consulta_b_subconsulta.sql` (incluyen spec, ambas versiones, y
el resultado real de cada verificación).

## Parte 4 — Competencia de optimización entre equipos

| Herramienta | Para qué se usó | Prompt / spec (resumen) | Se aceptó / se descartó |
|---|---|---|---|
| Kiro | Diagnosticar el nodo más costoso del plan real de la consulta de competencia (top 3 productos por facturación por categoría, últimos 6 meses) | Plan completo de EXPLAIN ANALYZE pegado, pidiendo identificar el nodo más costoso por tiempo real (no por cost estimado) | Se identificó un `Sort` con `external merge Disk` (spill a disco) como cuello de botella real, no ningún `Seq Scan` |
| Kiro | Probar `SET LOCAL work_mem = '8MB'` como alternativa sin tocar índices, dentro de `BEGIN...ROLLBACK` | — | **Aceptada:** el Sort dejó de spillear (`quicksort Memory` en vez de `external merge Disk`); mejora confirmada con promedio de 3 corridas (621.0ms → 539.1ms, ~13%; en la comparación intercalada posterior, solo `work_mem` promedió 571.4ms) |
| Kiro | Probar un índice parcial `idx_pedido_fecha_no_cancelado (fecha_hora DESC) WHERE estado <> 'CANCELADO'`, combinado con `work_mem` | — | **Descartada tras control de sesgo de orden:** una primera medición en bloques (AAA-BBB) mostró al índice ganando por 48ms, pero al intercalar el orden de las corridas (A-B-A-B-A-B) los promedios empataron exactamente (571.4ms vs. 571.4ms), sin dirección consistente par a par. La ventaja inicial era enteramente efecto de caché acumulado por el orden de ejecución, no del índice |

**Ver también:** `Parte4/DUIA_Parte4.md`,
`Parte4/analisis_optimizacion.md` (recorrido completo
de la investigación) y `Parte4/registro_competencia.md` (tabla oficial
de resultados y detalle de la propuesta descartada).

## Reflexión metodológica general

En ambas partes trabajadas individualmente (3 y 4) hubo al menos una
propuesta inicial de la IA que resultó incorrecta o engañosa bajo
verificación real — una diferencia de resultados no detectada a simple
vista (Parte 3) y un efecto de sesgo de orden en la medición de
tiempos (Parte 4). En los dos casos, la corrección no vino de aceptar
la primera respuesta de la IA, sino de exigir verificación empírica
(EXCEPT, control de orden con mediciones intercaladas) antes de dar
algo por cerrado — que es exactamente el criterio de aceptación que
pide la cátedra en ambos TP.