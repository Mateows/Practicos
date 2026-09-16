# DUIA — TP4 Parte 4 

**Materia:** Base de Datos II
**Trabajo práctico:** TP4 — Unidad 2: Reportes analíticos sobre Food Store
**Parte:** 4 — Competencia de optimización entre equipos
**Alumnos:** Mateo Lautaro Liendo, Lucas Avila y Amanda Pagano  
**Comision:** 4 
**Docente:** Sergio Neira 
**Proyecto:** Food Store
**Motor:** PostgreSQL 17
**Base de trabajo:** `foodstore_tp3_carga`

## Nota sobre la consulta de competencia

La consigna preveía que la cátedra entregara una consulta común para
que todos los equipos compitieran sobre la misma base. Esa consulta no
llegó a distribuirse a tiempo, así que el equipo generó la propia (top
3 productos por facturación dentro de cada categoría, últimos 6 meses),
cumpliendo los mismos requisitos de la consigna (al menos 2 JOIN y una
agregación, sobre la base masiva compartida).

## Registro de usos de IA

| Herramienta | Para qué se usó | Prompt / spec (resumen) | Se aceptó / se descartó |
|---|---|---|---|
| Kiro | Diagnosticar el nodo más costoso del plan real de la consulta de competencia | Plan completo de `EXPLAIN ANALYZE` pegado, pidiendo identificar el nodo más costoso por tiempo real (no por cost estimado) | Se identificó un `Sort` con `external merge Disk` (spill a disco) como cuello de botella real, no ningún `Seq Scan` |
| Kiro | Probar `SET LOCAL work_mem = '8MB'` como alternativa sin tocar índices, dentro de `BEGIN...ROLLBACK` | — | **Aceptada:** el Sort dejó de spillear (`quicksort Memory` en vez de `external merge Disk`); mejora confirmada con promedio de 3 corridas (621.0ms → 571.4ms, ~13%) |
| Kiro | Probar un índice parcial `idx_pedido_fecha_no_cancelado (fecha_hora DESC) WHERE estado <> 'CANCELADO'`, combinado con `work_mem` | — | **Descartada tras control de sesgo de orden:** una primera medición en bloques (AAA-BBB) mostró al índice ganando por 48ms, pero al intercalar el orden de las corridas (A-B-A-B-A-B) los promedios empataron exactamente (571.4ms vs. 571.4ms), sin dirección consistente par a par. La ventaja inicial era enteramente efecto de caché acumulado por el orden de ejecución, no del índice |

## Criterio de aceptación

Ninguna propuesta se aplicó "porque lo dijo la IA". Las 3 propuestas se
midieron con `EXPLAIN ANALYZE` real, y la que parecía ganar por 48ms en
una primera comparación se descartó al confirmar, con un control
metodológico de orden de mediciones, que esa ventaja era enteramente
un efecto de caché acumulado y no del índice en sí. Se documentó la
propuesta descartada con el mismo nivel de detalle que la aceptada,
tal como exige la consigna ("se documenta en la bitácora toda propuesta
de la IA que no funcionó, no solo la que se terminó usando").

## Ver también

- `analisis_optimizacion.md` — recorrido completo de la investigación,
  incluyendo el control de sesgo de orden.
- `registro_competencia.md` — tabla oficial de resultados de la
  competencia y detalle de la propuesta descartada.
- `consulta_competencia.sql` — la consulta propia usada para competir.
- `plan_antes.txt` / `plan_despues.txt` — planes reales de
  `EXPLAIN ANALYZE`.
- `../DUIA_TP4.md` — declaración consolidada de las 4 partes del TP4.