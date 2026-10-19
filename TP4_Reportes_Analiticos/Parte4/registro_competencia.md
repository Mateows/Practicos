# TP4 — Parte 4: Registro de Competencia de Optimización
## Consulta: Top 3 productos por facturación dentro de cada categoría (últimos 6 meses)
## Base: `foodstore_tp3_carga`

---

## Tabla de resultados

| Equipo | Estrategia aplicada | Tiempo antes (ms) | Tiempo después (ms) | Mejora (×) |
|--------|--------------------|-----------------:|--------------------:|-----------:|
| Avila · Pagano · Liendo | `SET LOCAL work_mem = '8MB'` antes de ejecutar la consulta (sin cambios de índice ni de esquema) | 621.0 | 571.4 | 1.09× |

> **Tiempos reportados como promedios de mediciones controladas**, no corridas únicas:
> - Tiempo antes: promedio de 3 corridas baseline (657.1 / 557.5 / 648.5 ms).
> - Tiempo después: promedio del control intercalado A-B-A-B-A-B
>   (600.7 / 557.1 / 556.2 ms), que elimina el sesgo de orden de cache.
>   Corrida oficial única para el plan registrado: 601.629 ms.
> - **Aclaración sobre `plan_antes.txt`:** ese archivo registra una corrida
>   aislada distinta (660.865 ms), capturada antes de iniciar el control de
>   ruido. No es un error ni una inconsistencia: es la primera medición
>   individual del plan completo, mientras que 621.0 ms (usado en la tabla
>   de arriba) es el promedio de 3 corridas independientes, más confiable
>   para reportar como "tiempo antes" oficial de la competencia.

---

## Diagnóstico del cuello de botella

El nodo dominante no era ningún Seq Scan sino el **Sort con spill a disco**
dentro de los 2 workers paralelos:

```
Sort Method: external merge  Disk: 3576kB   ← ANTES
Sort Method: quicksort  Memory: 5883kB      ← DESPUÉS
```

Con `work_mem` por defecto (4MB), cada worker no tenía suficiente RAM para
mantener el sort de ~3.6MB en memoria y lo volcaba a disco. Subir a 8MB
elimina el spill completamente.

---

## Propuesta descartada: `idx_pedido_fecha_no_cancelado`

```sql
CREATE INDEX idx_pedido_fecha_no_cancelado
    ON pedido (fecha_hora DESC)
    WHERE estado <> 'CANCELADO';
```

**Justificación estructural:** el `Parallel Seq Scan on pedido` filtra 42.465
filas de 66.669 (64% de descarte). Un índice parcial sobre `fecha_hora`
excluyendo los cancelados permite Bitmap Index Scan directo sobre el rango
temporal, en teoría reduciendo las filas que entran al Hash Join.

**Por qué se descarta:** el control de orden reveló que la mejora observada
en mediciones en bloque (AAA-BBB) era íntegramente efecto de cache acumulado,
no del índice. Al intercalar los escenarios (A-B-A-B-A-B) los promedios
convergen exactamente:

| Posición | Escenario | Tiempo |
|----------|-----------|--------|
| 1 | Solo `work_mem = '8MB'`  | 600.726 ms |
| 2 | `work_mem` + índice       | 585.960 ms |
| 3 | Solo `work_mem = '8MB'`  | 557.130 ms |
| 4 | `work_mem` + índice       | 569.065 ms |
| 5 | Solo `work_mem = '8MB'`  | 556.218 ms |
| 6 | `work_mem` + índice       | 559.129 ms |

**Promedio solo `work_mem`: 571.4 ms — Promedio con índice: 571.4 ms**

Las diferencias par a par no tienen dirección consistente (B gana en el par 1,
A gana en los pares 2 y 3). El índice no aporta mejora medible sobre esta
consulta con `work_mem = '8MB'` activo.

**Explicación:** una vez que el Sort ya no spillea a disco, el Seq Scan sobre
`pedido` (~30ms con cache caliente) deja de ser el dominante. El planner
además prefiere Parallel Seq Scan para el Hash Join con 66k filas sobre
Bitmap Heap Scan (que es single-threaded sobre el heap), lo cual es correcto
dado el volumen. El índice tiene valor real para queries que filtren `pedido`
por rango de fecha sin agregaciones masivas posteriores, pero no para esta.

**Decisión:** el índice **no se aplica**. No requiere ningún cambio de schema.

---

## Cambios aplicados de forma permanente

**Ninguno.** `SET LOCAL work_mem = '8MB'` se configura por sesión en el
momento de ejecutar la consulta de competencia. No modifica `postgresql.conf`,
no afecta otras conexiones, y no deja ningún artefacto en el schema.
