# spec: indice_pedido_estado_detalle_join

Objetivo: acelerar el ranking de clientes por gasto total (Q5 de
queries.sql), que hoy no fue optimizada en ningun TP anterior (en TP4
se verifico su equivalencia entre dos versiones, pero nunca se midio
ni se propuso indice sobre su plan de ejecucion).

Consulta afectada:
SELECT
    c.nombre_completo,
    SUM(dp.subtotal) AS total_gastado,
    DENSE_RANK() OVER (ORDER BY SUM(dp.subtotal) DESC) AS puesto
FROM cliente c
JOIN pedido p ON p.id_cliente = c.id AND p.estado <> 'CANCELADO'
JOIN detalle_pedido dp ON dp.id_pedido = p.id
GROUP BY c.id, c.nombre_completo
ORDER BY puesto;

Frecuencia: reporte de ranking, uso periodico (ej. informe mensual de
mejores clientes).

Columnas candidatas:
- pedido.estado (filtro por desigualdad <> 'CANCELADO' -- ojo: los
  indices B-tree simples no favorecen bien las desigualdades; evaluar
  si conviene reescribir como IN (...) sobre los 3 estados restantes,
  o si no vale la pena indexar esta columna para este caso).
- detalle_pedido.id_pedido (columna de join hacia pedido; HOY NO
  EXISTE ningun indice sobre esta columna -- el unico indice de
  detalle_pedido es sobre id_producto).

Nota de contexto importante: en TP3 se probo un indice sobre
detalle_pedido(id_pedido) para otra consulta con un join similar, y el
planificador NO LO USO (siguio prefiriendo Hash Join + Seq Scan sobre
Nested Loop + Index Scan, dado el volumen de filas involucradas).
Tenerlo en cuenta al proponer: puede pasar lo mismo aca, y si pasa, no
es un error sino un dato real a documentar.

Criterio de aceptacion: el plan cambia el algoritmo de acceso a
detalle_pedido y/o pedido (de Seq Scan a Index/Bitmap Scan, o el
algoritmo de join elegido cambia), con mejora de tiempo real medible.
Si el indice se crea pero el planificador no lo usa, se documenta esa
decision del optimizador igual, no se descarta en silencio.
