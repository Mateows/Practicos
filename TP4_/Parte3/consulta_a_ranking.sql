-- ============================================================================
-- TP4 — PARTE 3 — CONSULTA A: Ranking con función de ventana
-- Base de datos: foodstore_tp3_carga
-- ============================================================================

-- ----------------------------------------------------------------------------
-- ESPECIFICACIÓN
-- ----------------------------------------------------------------------------
-- "Genera una consulta SQL sobre el esquema de Food Store que devuelva, para
-- cada cliente con al menos un pedido en estado distinto de CANCELADO, su
-- nombre completo, el total gastado (suma de detalle_pedido.subtotal en esos
-- pedidos) y su puesto en un ranking de mayor a menor gasto, sin colapsar
-- filas. Las tablas cliente y detalle_pedido no tienen columna de borrado
-- lógico, por lo que no se les aplica ningún filtro de ese tipo. En caso de
-- empate, deben compartir el mismo puesto. No uses SELECT *."

-- ----------------------------------------------------------------------------
-- VERSIÓN 1 — DENSE_RANK() como función de ventana inline
-- Técnica: GROUP BY para agregar totales por cliente, DENSE_RANK() OVER (...)
-- aplicado directamente sobre el resultado. En caso de empate asigna el mismo
-- puesto y NO deja huecos en la numeración siguiente.
-- ----------------------------------------------------------------------------
SELECT
    c.nombre_completo,
    SUM(dp.subtotal)                                       AS total_gastado,
    DENSE_RANK() OVER (ORDER BY SUM(dp.subtotal) DESC)     AS puesto
FROM cliente c
JOIN pedido p
    ON p.id_cliente = c.id
   AND p.estado <> 'CANCELADO'
JOIN detalle_pedido dp
    ON dp.id_pedido = p.id
GROUP BY c.id, c.nombre_completo
ORDER BY puesto;

-- Muestra parcial ejecutada (primeras 10 filas):
--       nombre_completo       | total_gastado | puesto
-- ----------------------------+---------------+--------
--  Usuario7456 Apellido7456   |     412879.32 |      1
--  Usuario14847 Apellido14847 |     395037.65 |      2
--  Usuario17542 Apellido17542 |     388685.93 |      3
--  Usuario5484 Apellido5484   |     386983.76 |      4
--  Usuario7060 Apellido7060   |     383973.53 |      5
--  Usuario994 Apellido994     |     382885.21 |      6
--  Usuario6766 Apellido6766   |     378877.16 |      7
--  Usuario16055 Apellido16055 |     378152.03 |      8
--  Usuario11495 Apellido11495 |     377395.67 |      9
--  Usuario14069 Apellido14069 |     374565.78 |     10


-- ----------------------------------------------------------------------------
-- VERSIÓN 2 — Puesto calculado por subconsulta correlacionada (sin ventana)
-- Técnica: CTE que pre-agrega los totales por cliente, luego subconsulta
-- correlacionada que cuenta cuántos VALORES DISTINTOS de total_gastado son
-- estrictamente mayores al del cliente actual. Usar COUNT(DISTINCT) es lo
-- que replica la semántica de DENSE_RANK() (sin huecos) en lugar de RANK()
-- (con huecos). No usa DENSE_RANK() ni ninguna otra función de ventana.
-- ----------------------------------------------------------------------------
WITH totales AS (
    SELECT
        c.nombre_completo,
        SUM(dp.subtotal) AS total_gastado
    FROM cliente c
    JOIN pedido p
        ON p.id_cliente = c.id
       AND p.estado <> 'CANCELADO'
    JOIN detalle_pedido dp
        ON dp.id_pedido = p.id
    GROUP BY c.id, c.nombre_completo
)
SELECT
    t.nombre_completo,
    t.total_gastado,
    1 + (SELECT COUNT(DISTINCT t2.total_gastado)
         FROM totales t2
         WHERE t2.total_gastado > t.total_gastado) AS puesto
FROM totales t
ORDER BY puesto;

-- Muestra parcial ejecutada (primeras 10 filas):
--       nombre_completo       | total_gastado | puesto
-- ----------------------------+---------------+--------
--  Usuario7456 Apellido7456   |     412879.32 |      1
--  Usuario14847 Apellido14847 |     395037.65 |      2
--  Usuario17542 Apellido17542 |     388685.93 |      3
--  Usuario5484 Apellido5484   |     386983.76 |      4
--  Usuario7060 Apellido7060   |     383973.53 |      5
--  Usuario994 Apellido994     |     382885.21 |      6
--  Usuario6766 Apellido6766   |     378877.16 |      7
--  Usuario16055 Apellido16055 |     378152.03 |      8
--  Usuario11495 Apellido11495 |     377395.67 |      9
--  Usuario14069 Apellido14069 |     374565.78 |     10


-- ----------------------------------------------------------------------------
-- VERIFICACIÓN DE EQUIVALENCIA — EXCEPT en ambos sentidos
-- ----------------------------------------------------------------------------
WITH
v1 AS (
    SELECT
        c.nombre_completo,
        SUM(dp.subtotal)                                   AS total_gastado,
        DENSE_RANK() OVER (ORDER BY SUM(dp.subtotal) DESC) AS puesto
    FROM cliente c
    JOIN pedido p ON p.id_cliente = c.id AND p.estado <> 'CANCELADO'
    JOIN detalle_pedido dp ON dp.id_pedido = p.id
    GROUP BY c.id, c.nombre_completo
),
totales AS (
    SELECT
        c.nombre_completo,
        SUM(dp.subtotal) AS total_gastado
    FROM cliente c
    JOIN pedido p ON p.id_cliente = c.id AND p.estado <> 'CANCELADO'
    JOIN detalle_pedido dp ON dp.id_pedido = p.id
    GROUP BY c.id, c.nombre_completo
),
v2 AS (
    SELECT
        t.nombre_completo,
        t.total_gastado,
        1 + (SELECT COUNT(DISTINCT t2.total_gastado)
             FROM totales t2
             WHERE t2.total_gastado > t.total_gastado) AS puesto
    FROM totales t
)
SELECT 'A_v1_EXCEPT_v2' AS verificacion, COUNT(*) AS filas
FROM ( SELECT * FROM v1 EXCEPT SELECT * FROM v2 ) sub
UNION ALL
SELECT 'A_v2_EXCEPT_v1', COUNT(*)
FROM ( SELECT * FROM v2 EXCEPT SELECT * FROM v1 ) sub2;

-- RESULTADO REAL (ejecutado contra foodstore_tp3_carga):
--   verificacion  | filas
-- ----------------+-------
--  A_v1_EXCEPT_v2 |     0
--  A_v2_EXCEPT_v1 |     0
--
-- Ambas versiones son equivalentes: 0 filas en ambos sentidos.


-- ----------------------------------------------------------------------------
-- NOTA DE PROCESO — COUNT(*) vs COUNT(DISTINCT): por qué importa el detalle
-- ----------------------------------------------------------------------------
-- Durante el desarrollo se generó una V2 inicial con COUNT(*) en lugar de
-- COUNT(DISTINCT total_gastado):
--
--   1 + (SELECT COUNT(*) FROM totales t2 WHERE t2.total_gastado > t.total_gastado)
--
-- Esa versión produjo 19.433 filas de diferencia en el EXCEPT (en ambos
-- sentidos), evidenciando una no equivalencia real.
--
-- La causa es la diferencia semántica entre RANK() y DENSE_RANK():
--
--   COUNT(*) cuenta FILAS con total estrictamente mayor → replica RANK().
--   Ejemplo con empate en el puesto 5 (clientes A y B con mismo total):
--     - A y B reciben puesto 5 (hay 4 filas con total mayor).
--     - El siguiente cliente recibe puesto 7 (hay 6 filas con total mayor),
--       dejando un hueco en el 6. Eso es RANK().
--
--   COUNT(DISTINCT total_gastado) cuenta VALORES DISTINTOS con total mayor
--   → replica DENSE_RANK().
--   Ejemplo con el mismo empate:
--     - A y B reciben puesto 5 (hay 4 valores distintos mayores).
--     - El siguiente cliente recibe puesto 6 (hay 5 valores distintos mayores),
--       sin hueco. Eso es DENSE_RANK().
--
-- La corrección fue reemplazar COUNT(*) por COUNT(DISTINCT total_gastado),
-- verificada con EXCEPT antes de dar la consulta por buena.
-- El resultado final (0 filas en ambos sentidos) confirma la equivalencia.
