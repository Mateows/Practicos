# spec: vista_materializada_resumen_ventas_categoria_mes

Objetivo: acelerar el reporte de facturación, pedidos y unidades
vendidas por categoría y mes, que hoy cruza pedido + detalle_pedido +
producto + categoria y demora varios cientos de ms sobre el volumen
masivo de TP3 (499.571 filas en detalle_pedido).

Consulta afectada: agregación de dp.cantidad, dp.subtotal y
COUNT(DISTINCT p.id), agrupada por categoria.id, categoria.nombre y
date_trunc('month', p.fecha_hora), filtrando p.estado <> 'CANCELADO'.

Columnas candidatas para el índice único: (id_categoria, mes) —
identifican una fila del resumen y habilitan REFRESH CONCURRENTLY a
futuro.

Criterio de aceptación: la consulta contra la vista materializada
debe ser sustancialmente más rápida que la consulta directa sobre las
tablas base (orden de magnitud), y debe documentarse la frecuencia de
refresh recomendada según el uso esperado del reporte.
---

## Complemento (23/09, corrección posterior a la devolución)

La cátedra observó que no se analizaron las consecuencias del REFRESH
y que REFRESH CONCURRENTLY no se ejecutó. Se amplía el criterio de
aceptación:

1. Medir con salida archivada, en 3 rondas intercaladas, la consulta
   del reporte sobre las tablas base y sobre la vista materializada.
2. Ejecutar y medir REFRESH MATERIALIZED VIEW y REFRESH MATERIALIZED
   VIEW CONCURRENTLY sobre la misma vista (3 rondas intercaladas).
3. Mostrar con pg_locks qué bloqueo toma cada uno y qué significa para
   los usuarios que están leyendo el reporte mientras se refresca.
4. Mostrar qué ve un usuario entre dos REFRESH: un cambio en pedido no
   aparece en la vista hasta el siguiente REFRESH.
5. Todo reversible: los cambios de datos, dentro de BEGIN...ROLLBACK;
   la base tiene que quedar igual que antes.
6. Con esos resultados, justificar en informe_mediciones.md la
   frecuencia de REFRESH y el modo (normal o CONCURRENTLY).
