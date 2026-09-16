-- ============================================================================
-- TP4 — PARTE 3 — CONSULTA B: Subconsulta correlacionada
-- Base de datos: foodstore_tp3_carga
-- ============================================================================

-- ----------------------------------------------------------------------------
-- ESPECIFICACIÓN
-- ----------------------------------------------------------------------------
-- "Genera una consulta SQL sobre el esquema de Food Store que devuelva el
-- nombre y precio_lista de los productos activos (producto.activo = TRUE)
-- cuyo precio_lista sea mayor al precio promedio de los productos activos de
-- su misma categoría, considerando solo categorías vigentes
-- (categoria.activo = TRUE). No uses SELECT *."

-- ----------------------------------------------------------------------------
-- VERSIÓN 1 — Subconsulta correlacionada en WHERE
-- Técnica: por cada fila de producto, se ejecuta una subconsulta que calcula
-- el AVG de los productos activos de esa misma categoría. La correlación es
-- p2.id_categoria = p.id_categoria.
-- ----------------------------------------------------------------------------
SELECT
    p.nombre,
    p.precio_lista
FROM producto p
JOIN categoria cat
    ON cat.id = p.id_categoria
   AND cat.activo = TRUE
WHERE p.activo = TRUE
  AND p.precio_lista > (
      SELECT AVG(p2.precio_lista)
      FROM producto p2
      WHERE p2.activo = TRUE
        AND p2.id_categoria = p.id_categoria
  )
ORDER BY cat.id, p.precio_lista DESC;

-- Muestra parcial ejecutada (primeras 10 filas):
--      nombre     | precio_lista
-- ----------------+--------------
--  Producto 4817  |      4999.77
--  Producto 41506 |      4999.62
--  Producto 19812 |      4999.13
--  Producto 9099  |      4998.61
--  Producto 27598 |      4998.35
--  Producto 19081 |      4998.34
--  Producto 6754  |      4998.30
--  Producto 25914 |      4998.28
--  Producto 45834 |      4998.21
--  Producto 40790 |      4998.19


-- ----------------------------------------------------------------------------
-- VERSIÓN 2 — JOIN con subconsulta de promedios pre-calculados
-- Técnica: la subconsulta calcula el AVG por categoría UNA sola vez
-- (GROUP BY id_categoria), y el resultado se une con JOIN. No hay
-- correlación por fila — el promedio se materializa antes del filtro.
-- ----------------------------------------------------------------------------
SELECT
    p.nombre,
    p.precio_lista
FROM producto p
JOIN categoria cat
    ON cat.id = p.id_categoria
   AND cat.activo = TRUE
JOIN (
    SELECT
        p2.id_categoria,
        AVG(p2.precio_lista) AS promedio_cat
    FROM producto p2
    WHERE p2.activo = TRUE
    GROUP BY p2.id_categoria
) promedios
    ON promedios.id_categoria = p.id_categoria
WHERE p.activo = TRUE
  AND p.precio_lista > promedios.promedio_cat
ORDER BY cat.id, p.precio_lista DESC;

-- Muestra parcial ejecutada (primeras 10 filas):
--      nombre     | precio_lista
-- ----------------+--------------
--  Producto 4817  |      4999.77
--  Producto 41506 |      4999.62
--  Producto 19812 |      4999.13
--  Producto 9099  |      4998.61
--  Producto 27598 |      4998.35
--  Producto 19081 |      4998.34
--  Producto 6754  |      4998.30
--  Producto 25914 |      4998.28
--  Producto 45834 |      4998.21
--  Producto 40790 |      4998.19


-- ----------------------------------------------------------------------------
-- VERIFICACIÓN DE EQUIVALENCIA — EXCEPT en ambos sentidos
-- ----------------------------------------------------------------------------
WITH
v1 AS (
    SELECT p.nombre, p.precio_lista
    FROM producto p
    JOIN categoria cat ON cat.id = p.id_categoria AND cat.activo = TRUE
    WHERE p.activo = TRUE
      AND p.precio_lista > (
          SELECT AVG(p2.precio_lista)
          FROM producto p2
          WHERE p2.activo = TRUE AND p2.id_categoria = p.id_categoria
      )
),
v2 AS (
    SELECT p.nombre, p.precio_lista
    FROM producto p
    JOIN categoria cat ON cat.id = p.id_categoria AND cat.activo = TRUE
    JOIN (
        SELECT p2.id_categoria, AVG(p2.precio_lista) AS promedio_cat
        FROM producto p2
        WHERE p2.activo = TRUE
        GROUP BY p2.id_categoria
    ) promedios ON promedios.id_categoria = p.id_categoria
    WHERE p.activo = TRUE
      AND p.precio_lista > promedios.promedio_cat
)
SELECT 'B_v1_EXCEPT_v2' AS verificacion, COUNT(*) AS filas
FROM ( SELECT * FROM v1 EXCEPT SELECT * FROM v2 ) sub
UNION ALL
SELECT 'B_v2_EXCEPT_v1', COUNT(*)
FROM ( SELECT * FROM v2 EXCEPT SELECT * FROM v1 ) sub2;

-- RESULTADO REAL (ejecutado contra foodstore_tp3_carga):
--   verificacion  | filas
-- ----------------+-------
--  B_v1_EXCEPT_v2 |     0
--  B_v2_EXCEPT_v1 |     0

-- ----------------------------------------------------------------------------
-- ANÁLISIS DE EQUIVALENCIA
-- ----------------------------------------------------------------------------
-- Las dos versiones SON equivalentes: el EXCEPT devuelve 0 filas en ambos
-- sentidos.
--
-- Por qué son equivalentes:
--   Ambas versiones aplican exactamente los mismos filtros de borrado lógico
--   (producto.activo = TRUE, categoria.activo = TRUE) y la misma condición
--   de negocio (precio_lista > promedio de la categoría). La diferencia es
--   únicamente de ejecución:
--
--   • V1 (subconsulta correlacionada): el motor evalúa AVG una vez por cada
--     fila candidata de producto — costoso en tablas grandes (O(n) subconsultas).
--
--   • V2 (JOIN con subquery): el motor calcula todos los promedios por
--     categoría en un único paso (GROUP BY) y luego hace un JOIN — mucho más
--     eficiente en la práctica.
--
--   El resultado del conjunto es matemáticamente idéntico porque AVG sobre
--   el mismo subconjunto (productos activos de la misma categoría) produce
--   el mismo valor independientemente del mecanismo de ejecución.
--
-- Nota de rendimiento: en foodstore_tp3_carga (50.003 productos activos),
-- V1 tardó varios minutos por la naturaleza O(n²) de la correlación.
-- V2 completó en segundos. Mismos resultados, costo muy distinto.
