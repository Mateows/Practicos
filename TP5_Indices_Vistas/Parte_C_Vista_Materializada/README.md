# Parte C — Vista materializada

**Base de prueba:** `foodstore_tp3_carga` (~200.000 pedidos, 499.571 líneas de detalle)  
**Motor:** PostgreSQL 17  
**Estado:** implementada y aplicada en firme sobre `foodstore_tp3_carga`.

---

## Justificación

La consulta de facturación por categoría y mes cruza 4 tablas (`pedido`, `detalle_pedido`, `producto`, `categoria`), usa agregación con `COUNT(DISTINCT)` y `SUM`, y ordena el resultado. Sobre la base masiva esta consulta demora **618 ms** porque el planificador debe leer y procesar 499.571 filas de `detalle_pedido` completas, incluso cuando el resultado final tiene solo 26 filas.

Una vista materializada resuelve exactamente este caso: paga el costo de la agregación una sola vez en el `REFRESH`, y cada consulta posterior solo lee las 26 filas ya resumidas.

---

## Qué implementa la vista

```sql
CREATE MATERIALIZED VIEW mv_resumen_ventas_categoria_mes AS
SELECT
    c.id          AS id_categoria,
    c.nombre      AS categoria,
    date_trunc('month', p.fecha_hora) AS mes,
    COUNT(DISTINCT p.id)  AS cantidad_pedidos,
    SUM(dp.cantidad)      AS unidades_vendidas,
    SUM(dp.subtotal)      AS facturacion_total
FROM pedido p
JOIN detalle_pedido dp ON dp.id_pedido = p.id
JOIN producto pr        ON pr.id = dp.id_producto
JOIN categoria c        ON c.id = pr.id_categoria
WHERE p.estado <> 'CANCELADO'
GROUP BY c.id, c.nombre, date_trunc('month', p.fecha_hora)
WITH DATA;
```

**Índice sobre la vista:**

```sql
CREATE UNIQUE INDEX idx_mv_resumen_ventas_categoria_mes
    ON mv_resumen_ventas_categoria_mes (id_categoria, mes);
```

El índice es único porque la combinación `(id_categoria, mes)` identifica una sola fila en el resumen. Además es necesario para poder usar `REFRESH MATERIALIZED VIEW CONCURRENTLY` en producción.

---

## Resultados de la prueba

### Consulta base sobre tablas directas (antes)

Plan: 4 Hash Join paralelos + Seq Scans sobre `detalle_pedido` (499.571 filas) + Sort con external merge a disco.

```
Execution Time: 618.156 ms
Buffers: shared hit=4007 read=4124, temp read=2440 written=2446
Sort Method: external merge  Disk: ~6500kB por worker
Workers Planned: 2 / Workers Launched: 2
```

### Consulta general sobre la vista materializada (después)

Plan: Seq Scan sobre 26 filas + quicksort en memoria.

```
Execution Time: 0.073 ms
Buffers: shared hit=7
Sort Method: quicksort  Memory: 26kB
```

### Consulta filtrada por categoría (`WHERE id_categoria = 1`)

Plan: Seq Scan sobre 26 filas + filtro + quicksort.  
*(Con solo 26 filas el planificador prefirió Seq Scan sobre el índice; el índice tiene valor cuando la vista crezca o se use `REFRESH CONCURRENTLY`.)*

```
Execution Time: 0.073 ms
Buffers: shared hit=4
```

---

## Tabla comparativa

| Caso | Nodo principal | Execution Time | Disco temp. |
|---|---|---|---|
| Consulta sobre tablas base | 3× Hash Join + Sort external merge | **618.156 ms** | ~6.500 kB/worker |
| Consulta general sobre vista | Seq Scan (26 filas) + quicksort | **0.073 ms** | 0 |
| Consulta filtrada por categoría | Seq Scan (26 filas) + filtro | **0.073 ms** | 0 |

**Mejora:** ~**8468x** en tiempo de lectura.

---

## Costo del REFRESH

El `REFRESH` ejecuta internamente la misma query costosa sobre las tablas base. En esta base tardó del orden de los 600 ms (equivalente a la consulta base). Ese es el costo que se paga una vez para que todas las lecturas posteriores sean instantáneas.

En producción se usa `REFRESH MATERIALIZED VIEW CONCURRENTLY` para que la vista siga respondiendo consultas mientras se actualiza. Requiere el índice único definido arriba.

---

## Conclusión técnica

La vista materializada es la herramienta correcta para este caso porque:

- El resultado tiene muy pocas filas (26) respecto al volumen de datos de entrada (499.571).
- La consulta se ejecuta muchas veces (reportes periódicos).
- Los datos de la base no cambian en tiempo real: el `REFRESH` puede programarse en un cron o job de ETL.
- La penalidad de escritura es asumible: solo se paga al refrescar, no en cada INSERT/UPDATE de `pedido` o `detalle_pedido`.

No es la herramienta correcta cuando los datos cambian continuamente y la vista debe estar siempre al día, o cuando el resultado tiene tantas filas como la tabla base (no hay compresión real del volumen).
