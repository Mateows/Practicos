-- Medicion del costo de escritura en producto con los DOS indices de
-- TP5 juntos (idx_producto_categoria_precio_activo del Caso 2 e
-- idx_producto_categoria_precio del Caso 4), no solo uno a la vez.
-- idx_productos_categoria_activo (heredado de TP1, en schema.sql) NO
-- se toca -- no se modifica el modelo heredado.
-- 3 rondas intercaladas, DROP/CREATE real de ambos indices dentro de
-- transacciones, \timing.
--
-- Incluye una ronda de CALENTAMIENTO antes de la Ronda 1: la primera
-- corrida de la sesion sobre producto (tras un VACUUM) mostro un costo
-- de arranque en frio que no se repetia en las rondas siguientes
-- (47.8 ms vs. 11-17 ms en una medicion previa sin calentamiento, que
-- no quedo archivada; en la corrida archivada el calentamiento dio
-- 65.963 ms). El
-- calentamiento se archiva igual que las demas rondas, con su propio
-- rotulo -- no se descarta en silencio, se muestra y se explica.
\set ON_ERROR_STOP on
\timing on

\echo '=== CALENTAMIENTO (no se cuenta para la conclusion; ver nota en el informe) ==='
BEGIN;
INSERT INTO producto (nombre, id_categoria, precio_lista, stock, activo)
SELECT
    'TP5-escritura2-warmup-' || gs,
    (ARRAY(SELECT id FROM categoria ORDER BY id))[1 + (gs % (SELECT count(*) FROM categoria))],
    1000 + gs,
    10,
    TRUE
FROM generate_series(1, 500) AS gs;
ROLLBACK;

\echo '=== RONDA 1 - ANTES (sin los 2 indices de TP5) ==='
BEGIN;
DROP INDEX idx_producto_categoria_precio_activo;
DROP INDEX idx_producto_categoria_precio;
COMMIT;
BEGIN;
INSERT INTO producto (nombre, id_categoria, precio_lista, stock, activo)
SELECT
    'TP5-escritura2-' || gs,
    (ARRAY(SELECT id FROM categoria ORDER BY id))[1 + (gs % (SELECT count(*) FROM categoria))],
    1000 + gs,
    10,
    TRUE
FROM generate_series(1, 500) AS gs;
ROLLBACK;

\echo '=== RONDA 1 - DESPUES (con los 2 indices de TP5) ==='
BEGIN;
CREATE INDEX idx_producto_categoria_precio_activo
    ON producto (id_categoria, precio_lista DESC)
    WHERE activo = TRUE;
CREATE INDEX idx_producto_categoria_precio ON producto (id_categoria, precio_lista);
COMMIT;
BEGIN;
INSERT INTO producto (nombre, id_categoria, precio_lista, stock, activo)
SELECT
    'TP5-escritura2-' || gs,
    (ARRAY(SELECT id FROM categoria ORDER BY id))[1 + (gs % (SELECT count(*) FROM categoria))],
    1000 + gs,
    10,
    TRUE
FROM generate_series(1, 500) AS gs;
ROLLBACK;

\echo '=== RONDA 2 - ANTES (sin los 2 indices de TP5) ==='
BEGIN;
DROP INDEX idx_producto_categoria_precio_activo;
DROP INDEX idx_producto_categoria_precio;
COMMIT;
BEGIN;
INSERT INTO producto (nombre, id_categoria, precio_lista, stock, activo)
SELECT
    'TP5-escritura2-' || gs,
    (ARRAY(SELECT id FROM categoria ORDER BY id))[1 + (gs % (SELECT count(*) FROM categoria))],
    1000 + gs,
    10,
    TRUE
FROM generate_series(1, 500) AS gs;
ROLLBACK;

\echo '=== RONDA 2 - DESPUES (con los 2 indices de TP5) ==='
BEGIN;
CREATE INDEX idx_producto_categoria_precio_activo
    ON producto (id_categoria, precio_lista DESC)
    WHERE activo = TRUE;
CREATE INDEX idx_producto_categoria_precio ON producto (id_categoria, precio_lista);
COMMIT;
BEGIN;
INSERT INTO producto (nombre, id_categoria, precio_lista, stock, activo)
SELECT
    'TP5-escritura2-' || gs,
    (ARRAY(SELECT id FROM categoria ORDER BY id))[1 + (gs % (SELECT count(*) FROM categoria))],
    1000 + gs,
    10,
    TRUE
FROM generate_series(1, 500) AS gs;
ROLLBACK;

\echo '=== RONDA 3 - ANTES (sin los 2 indices de TP5) ==='
BEGIN;
DROP INDEX idx_producto_categoria_precio_activo;
DROP INDEX idx_producto_categoria_precio;
COMMIT;
BEGIN;
INSERT INTO producto (nombre, id_categoria, precio_lista, stock, activo)
SELECT
    'TP5-escritura2-' || gs,
    (ARRAY(SELECT id FROM categoria ORDER BY id))[1 + (gs % (SELECT count(*) FROM categoria))],
    1000 + gs,
    10,
    TRUE
FROM generate_series(1, 500) AS gs;
ROLLBACK;

\echo '=== RONDA 3 - DESPUES (con los 2 indices de TP5) ==='
BEGIN;
CREATE INDEX idx_producto_categoria_precio_activo
    ON producto (id_categoria, precio_lista DESC)
    WHERE activo = TRUE;
CREATE INDEX idx_producto_categoria_precio ON producto (id_categoria, precio_lista);
COMMIT;
BEGIN;
INSERT INTO producto (nombre, id_categoria, precio_lista, stock, activo)
SELECT
    'TP5-escritura2-' || gs,
    (ARRAY(SELECT id FROM categoria ORDER BY id))[1 + (gs % (SELECT count(*) FROM categoria))],
    1000 + gs,
    10,
    TRUE
FROM generate_series(1, 500) AS gs;
ROLLBACK;

\echo '=== Verificacion: los 2 indices de TP5 deben seguir aplicados en firme ==='
SELECT indexname FROM pg_indexes WHERE tablename = 'producto' ORDER BY indexname;
