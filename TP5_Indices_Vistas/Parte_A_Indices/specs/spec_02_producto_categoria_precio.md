# spec: indice_producto_categoria_precio

Objetivo: acelerar la consulta "productos con precio mayor al promedio
de su categoria" (Q6 de queries.sql), que hoy usa una subconsulta
correlacionada O(n^2) y tarda varios minutos sobre 50.000 productos
(ya verificado en TP4).

Consulta afectada:
SELECT p.nombre, p.precio_lista
FROM producto p
JOIN categoria cat ON cat.id = p.id_categoria AND cat.activo = TRUE
WHERE p.activo = TRUE
  AND p.precio_lista > (
      SELECT AVG(p2.precio_lista)
      FROM producto p2
      WHERE p2.activo = TRUE AND p2.id_categoria = p.id_categoria
  )
ORDER BY cat.id, p.precio_lista DESC;

Frecuencia: consulta analitica, uso ocasional (reportes de pricing).

Columnas candidatas: id_categoria (agrupa el AVG por categoria),
precio_lista (evita el sort posterior si el indice ya viene ordenado).

Nota: ya existe idx_productos_categoria_activo (id_categoria, activo)
WHERE activo=TRUE -- es parcial y no incluye precio_lista, por lo que
no cubre el filtro de rango de precio ni el AVG. Evaluar si el nuevo
indice seria redundante o complementario a este.

Criterio de aceptacion: el plan mejora el acceso a producto (de Seq
Scan a Index Scan), con reduccion de tiempo medible respecto a la
subconsulta actual.
