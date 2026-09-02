-- ============================================================================
-- TRABAJO PRÁCTICO N.º 3 - OPTIMIZACIÓN Y PERFORMANCE DE CONSULTAS
-- Archivo: verificacion_carga.sql
-- Base de datos objetivo: foodstore_tp3_carga
-- Propósito: Verificar la integridad y completitud de la carga masiva ejecutada
--            mediante seed_masivo.sql.
--
-- Uso:
--   psql -U postgres -d foodstore_tp3_carga -f verificacion_carga.sql
--
-- IMPORTANTE: script de solo lectura. No contiene DML ni DDL.
-- ============================================================================

\echo '============================================================='
\echo 'VERIFICACIÓN DE CARGA MASIVA — foodstore_tp3_carga'
\echo '============================================================='


-- ============================================================
-- 1. CONTEO DE FILAS POR TABLA
--    Compara los totales reales contra los volúmenes esperados.
--    Se incluyen las filas del dataset de prueba original del
--    schema.sql (3 clientes, 3 productos, 5 pedidos, 7 detalles)
--    porque esa base arrancó con esos datos antes del seed.
--    Si la base se creó limpia solo con el seed, los números
--    exactos serán los del seed; ajustar los expected según
--    corresponda.
-- ============================================================
--    NOTA: el conteo de detalle_pedido (499571) no es determinístico:
--    depende de la distribución aleatoria de 1-4 líneas por pedido.
--    Si se recrea la carga desde cero, este número puede variar
--    levemente; no comparar contra un valor exacto sino contra el
--    rango esperado (~600.000-650.000).
-- ============================================================

\echo ''
\echo '--- 1. CONTEO DE FILAS POR TABLA ---'

SELECT
    'producto'                          AS tabla,
    COUNT(*)                            AS filas_reales,
    50000                               AS filas_esperadas_seed,
    COUNT(*) - 50000                    AS diferencia
FROM producto

UNION ALL

SELECT
    'cliente',
    COUNT(*),
    20000,
    COUNT(*) - 20000
FROM cliente

UNION ALL

SELECT
    'pedido',
    COUNT(*),
    200000,
    COUNT(*) - 200000
FROM pedido

UNION ALL

SELECT
    'detalle_pedido',
    COUNT(*),
    499571,
    COUNT(*) - 499571
FROM detalle_pedido

ORDER BY tabla;

-- Interpretación esperada: diferencia = 0 para cada tabla
-- (o igual al número de filas del dataset base si existían
--  registros previos al seed).


-- ============================================================
-- 2. INTEGRIDAD REFERENCIAL — BÚSQUEDA DE HUÉRFANOS
--    Detecta FKs rotas que podrían haberse colado durante la
--    carga si las constraints estaban diferidas o desactivadas.
-- ============================================================

\echo ''
\echo '--- 2. INTEGRIDAD REFERENCIAL (esperado: 0 filas en cada consulta) ---'

-- 2a. Productos con id_categoria que no existe en categoria
\echo '  2a. Productos con id_categoria huerfano:'
SELECT p.id AS id_producto, p.id_categoria
FROM producto p
WHERE NOT EXISTS (
    SELECT 1 FROM categoria c WHERE c.id = p.id_categoria
);

-- 2b. Pedidos con id_cliente que no existe en cliente
\echo '  2b. Pedidos con id_cliente huerfano:'
SELECT pe.id AS id_pedido, pe.id_cliente
FROM pedido pe
WHERE NOT EXISTS (
    SELECT 1 FROM cliente c WHERE c.id = pe.id_cliente
);

-- 2c. Detalles con id_pedido que no existe en pedido
\echo '  2c. Detalles con id_pedido huerfano:'
SELECT dp.id_pedido, dp.id_producto
FROM detalle_pedido dp
WHERE NOT EXISTS (
    SELECT 1 FROM pedido pe WHERE pe.id = dp.id_pedido
);

-- 2d. Detalles con id_producto que no existe en producto
\echo '  2d. Detalles con id_producto huerfano:'
SELECT dp.id_pedido, dp.id_producto
FROM detalle_pedido dp
WHERE NOT EXISTS (
    SELECT 1 FROM producto pr WHERE pr.id = dp.id_producto
);


-- ============================================================
-- 3. VALIDACIÓN DE PRECIOS
--    precio_lista (producto) y precio_unitario (detalle_pedido)
--    deben ser >= 0 según los CHECK del esquema.
-- ============================================================

\echo ''
\echo '--- 3. PRECIOS NEGATIVOS (esperado: 0 filas en cada consulta) ---'

-- 3a. Productos con precio_lista negativo
\echo '  3a. Productos con precio_lista < 0:'
SELECT id, nombre, precio_lista
FROM producto
WHERE precio_lista < 0;

-- 3b. Detalles con precio_unitario negativo
\echo '  3b. Detalles con precio_unitario < 0:'
SELECT id_pedido, id_producto, precio_unitario
FROM detalle_pedido
WHERE precio_unitario < 0;


-- ============================================================
-- 4. UNICIDAD DE LA PK COMPUESTA EN detalle_pedido
--    La PK (id_pedido, id_producto) impide duplicados, pero
--    esta consulta confirma que ninguna combinación aparece
--    más de una vez en los datos cargados.
-- ============================================================

\echo ''
\echo '--- 4. DUPLICADOS EN PK COMPUESTA detalle_pedido (esperado: 0 filas) ---'

SELECT id_pedido, id_producto, COUNT(*) AS ocurrencias
FROM detalle_pedido
GROUP BY id_pedido, id_producto
HAVING COUNT(*) > 1
ORDER BY ocurrencias DESC;


-- ============================================================
-- 5. DISTRIBUCIÓN POR ESTADO Y FORMA DE PAGO
--    Confirma que los 4 valores de estado_pedido_enum y los 3
--    de forma_pago_enum fueron efectivamente utilizados durante
--    la carga masiva.
-- ============================================================

\echo ''
\echo '--- 5a. DISTRIBUCION DE PEDIDOS POR ESTADO ---'
\echo '     (esperado: 4 filas — PENDIENTE, EN_PREPARACION, ENTREGADO, CANCELADO)'

SELECT
    estado,
    COUNT(*)                                    AS cantidad,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS porcentaje
FROM pedido
GROUP BY estado
ORDER BY estado;

\echo ''
\echo '--- 5b. DISTRIBUCION DE PEDIDOS POR FORMA DE PAGO ---'
\echo '     (esperado: 3 filas — EFECTIVO, TARJETA, TRANSFERENCIA)'

SELECT
    forma_pago,
    COUNT(*)                                    AS cantidad,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2) AS porcentaje
FROM pedido
GROUP BY forma_pago
ORDER BY forma_pago;


-- ============================================================
-- RESUMEN EJECUTIVO
--    Una vista consolidada de los conteos para lectura rápida.
-- ============================================================

\echo ''
\echo '--- RESUMEN EJECUTIVO ---'

SELECT 'producto'      AS tabla, COUNT(*) AS total FROM producto
UNION ALL
SELECT 'cliente',               COUNT(*) FROM cliente
UNION ALL
SELECT 'pedido',                COUNT(*) FROM pedido
UNION ALL
SELECT 'detalle_pedido',        COUNT(*) FROM detalle_pedido
UNION ALL
SELECT 'categoria',             COUNT(*) FROM categoria;

\echo ''
\echo '============================================================='
\echo 'Verificacion finalizada. Revisar resultados arriba.'
\echo '============================================================='


-- ============================================================
-- 6. DISTRIBUCION DE CLAVES FORANEAS (agregado tras detectar el
--    bug de subconsultas no correlacionadas en la version v1 del
--    seed). Un conteo DISTINCT muy bajo respecto del total de
--    filas de la tabla referenciada indica que la aleatoriedad
--    no se esta aplicando por fila.
-- ============================================================

\echo ''
\echo '--- 6a. DISTRIBUCION producto.id_categoria (esperado: cerca de 50/50) ---'
SELECT id_categoria, COUNT(*) AS cantidad
FROM producto
GROUP BY id_categoria
ORDER BY id_categoria;

\echo ''
\echo '--- 6b. CLIENTES DISTINTOS CON PEDIDOS (esperado: cerca de 20.000) ---'
SELECT COUNT(DISTINCT id_cliente) AS clientes_distintos, COUNT(*) AS total_pedidos
FROM pedido;

\echo ''
\echo '--- 6c. PRODUCTOS DISTINTOS VENDIDOS (esperado: cerca de 50.000) ---'
SELECT COUNT(DISTINCT id_producto) AS productos_distintos, COUNT(DISTINCT id_pedido) AS pedidos_distintos
FROM detalle_pedido;
