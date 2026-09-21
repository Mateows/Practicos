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