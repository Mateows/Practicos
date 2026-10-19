# Bitácora de Optimización — TP3 Parte 5
**Equipo:** Lucas Avila, Amanda Pagano, Mateo Lautaro Liendo  
**Base:** `foodstore_tp3_carga` (50.003 productos, 20.003 clientes, 200.005 pedidos, 498.608 detalles)

---

## Consulta base de la competencia

```sql
SELECT
    p.nombre,
    c.nombre AS categoria,
    SUM(dp.cantidad) AS total_unidades_vendidas
FROM detalle_pedido AS dp
JOIN producto AS p
    ON p.id = dp.id_producto
JOIN categoria AS c
    ON c.id = p.id_categoria
JOIN pedido AS pe
    ON pe.id = dp.id_pedido
WHERE pe.estado = 'ENTREGADO'
  AND p.activo = TRUE
GROUP BY p.id, p.nombre, c.id, c.nombre
ORDER BY total_unidades_vendidas DESC
LIMIT 10;
```

---

## Análisis del plan baseline (sin índices adicionales)

**Execution Time: 286.909 ms**  
Plan completo: `planes/plan_p5_antes.txt`

| Nodo | Detalle | Problema identificado |
|---|---|---|
| Parallel Seq Scan on `pedido` | Lee 200.005 filas, descarta 150.372 por `estado = 'ENTREGADO'` | 75% de las filas leídas son descartadas — candidato a índice |
| Sort on `producto` | `Sort Method: external merge  Disk: 3192kB` | El Sort escribe a disco — nodo potencialmente optimizable |
| Parallel Seq Scan on `detalle_pedido` | Lee 498.608 filas completas | Sin filtro propio; el JOIN necesita todas las filas |
| Seq Scan on `producto` | 50.003 filas con filtro `activo = TRUE` | Selectividad baja (casi todos activos), Seq Scan razonable |

---

## Propuesta 1 — Índice sobre `pedido(estado)`

**Justificación sobre el plan:** el Parallel Seq Scan de `pedido` lee 200k filas y descarta el 75% por el filtro `estado = 'ENTREGADO'`. Un índice sobre `(estado)` permite Bitmap Index Scan, leyendo solo las ~50k filas ENTREGADAS.

**Riesgo anticipado:** en la Parte 2 (Q3) un índice sobre `pedido(fecha_hora)` eliminó el paralelismo y empeoró el tiempo real de 160ms a 203ms. Se decidió probar igualmente porque el filtro de estado es más selectivo que el de fecha.

```sql
CREATE INDEX idx_p5_pedido_estado ON pedido (estado);
```

**Resultado medido:**
- Nodo `pedido`: cambió de **Parallel Seq Scan** a **Parallel Bitmap Heap Scan** via `idx_p5_pedido_estado` ✓
- El paralelismo se **mantuvo** (2 workers activos) — el riesgo no se materializó
- Sort a disco sobre `producto`: **sin cambio** (external merge Disk: 3256kB)
- Tiempo real observado en la medición: aproximadamente 264 ms

**Decisión: ACEPTADO.** El índice fue elegido por el planificador, mejoró el nodo de pedido sin eliminar el paralelismo. El script de prueba terminó con `ROLLBACK`; cualquier aplicación permanente del índice se realizó mediante un comando manual posterior.

---

## Propuesta 2 — Índice parcial sobre `producto(id_categoria, id) WHERE activo = TRUE`

**Justificación sobre el plan:** el Sort sobre `producto` escribe 3.192kB a disco (`external merge`) para ordenar por `id_categoria` antes del Merge Join con `categoria`. Un índice sobre `(id_categoria, id)` podría proveer las filas ya ordenadas, eliminando el Sort a disco. El filtro `WHERE activo = TRUE` lo hace parcial: más pequeño y consistente con el filtro de la consulta.

```sql
CREATE INDEX idx_p5_producto_categoria_activo
    ON producto (id_categoria, id)
    WHERE activo = TRUE;
```

**Resultado medido:**
- Nodo Sort sobre `producto`: en la medición posterior pasó de **external merge Disk: 3192kB** a **quicksort Memory: 3820kB** ✓ — el Sort ya no escribe a disco
- El índice **no fue elegido** para el Seq Scan de `producto` (el planificador mantuvo Seq Scan) — esperado, ya que `activo = TRUE` aplica a casi todos los 50k productos y la selectividad es baja
- El paralelismo se **mantuvo** (2 workers activos)
- `Execution Time` medido con ambos índices: **200.606 ms**

**Decisión: ACEPTADO COMO PARTE DE LA ESTRATEGIA.** La medición posterior mostró que el Sort a disco desapareció y el tiempo bajó ~30% respecto del baseline. Sin embargo, como el planificador no utilizó directamente este índice, no se atribuye la mejora exclusivamente a él. El script de prueba terminó con `ROLLBACK`; cualquier aplicación permanente del índice se realizó mediante un comando manual posterior.

---

## Propuesta descartada — Índice sobre `detalle_pedido(id_pedido)`

**Justificación para considerarla:** el Parallel Seq Scan sobre `detalle_pedido` lee 498k filas completas. Un índice sobre `id_pedido` podría ayudar al Parallel Hash Join con `pedido`.

**Por qué se descartó sin probar:** en la Parte 2 (Q3) se creó exactamente este índice — `idx_detalle_pedido_id_pedido ON detalle_pedido (id_pedido)` — y el planificador lo ignoró completamente, manteniendo el Seq Scan. La evidencia previa sobre el mismo volumen de datos hace que probar de nuevo no aporte valor y sume riesgo de eliminar el paralelismo. Descartada con base en evidencia real, no por suposición.

---

## Registro de la competencia

| Equipo | Estrategia aplicada | Tiempo antes (ms) | Tiempo después (ms) | Mejora (x) |
|---|---|---|---|---|
| Avila / Pagano / Liendo | `idx_p5_pedido_estado` (Bitmap Heap Scan en pedido) + `idx_p5_producto_categoria_activo` (propuesta evaluada; el plan mantuvo Seq Scan en producto) | 286.909 | 200.606 | ~1.43x |

---

## Declaración de Uso de IA (DUIA)

| Herramienta | Para qué se usó | Prompt / spec (resumen) | Se aceptó / se descartó — por qué |
|---|---|---|---|
| Kiro | Análisis del plan EXPLAIN ANALYZE baseline y propuesta de índices justificados sobre nodos del plan real | Se le pasó el output completo de EXPLAIN ANALYZE y se pidió identificar los nodos más costosos y proponer índices con justificación en términos del plan | El equipo revisó las sugerencias y aceptó la Propuesta 1 porque el planificador la utilizó. La Propuesta 2 se mantuvo aplicada como parte de la estrategia, pero se dejó asentado que el planificador no la utilizó directamente. Se descartó la propuesta sobre `detalle_pedido` por evidencia previa de la Parte 2 que mostraba que el planificador ignoraba ese índice |
| Kiro | Generación de scripts SQL de prueba dentro de transacciones con ROLLBACK por defecto | Se pidió un script por propuesta que incluyera BEGIN, CREATE INDEX, ANALYZE, EXPLAIN ANALYZE y ROLLBACK al final para medir sin comprometer | La estructura se revisó y se aceptó. El equipo ejecutó los comandos en la terminal, verificó los planes y tiempos en `foodstore_tp3_carga`, y decidió manualmente qué propuestas conservar. La IA no ejecutó comandos ni tomó la decisión final |

