-- Medicion de 3 rondas intercaladas para el candidato de Q2:
-- idx_producto_categoria_precio (id_categoria, precio_lista), SIN
-- condicion parcial (Q2 no filtra por activo, asi que los indices
-- parciales existentes -- idx_productos_categoria_activo,
-- idx_producto_categoria_precio_activo -- no son aplicables).
-- Todo dentro de transacciones reversibles (CREATE/DROP del candidato).
\set ON_ERROR_STOP on
\timing on

\echo '=== RONDA 1 - ANTES (Seq Scan) ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, nombre, precio_lista, stock
FROM producto
WHERE id_categoria = 1 AND precio_lista BETWEEN 1000 AND 3000
ORDER BY precio_lista;

\echo '=== RONDA 1 - DESPUES (con candidato) ==='
BEGIN;
CREATE INDEX idx_producto_categoria_precio ON producto (id_categoria, precio_lista);
ANALYZE producto;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, nombre, precio_lista, stock
FROM producto
WHERE id_categoria = 1 AND precio_lista BETWEEN 1000 AND 3000
ORDER BY precio_lista;
ROLLBACK;

\echo '=== RONDA 2 - ANTES (Seq Scan) ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, nombre, precio_lista, stock
FROM producto
WHERE id_categoria = 1 AND precio_lista BETWEEN 1000 AND 3000
ORDER BY precio_lista;

\echo '=== RONDA 2 - DESPUES (con candidato) ==='
BEGIN;
CREATE INDEX idx_producto_categoria_precio ON producto (id_categoria, precio_lista);
ANALYZE producto;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, nombre, precio_lista, stock
FROM producto
WHERE id_categoria = 1 AND precio_lista BETWEEN 1000 AND 3000
ORDER BY precio_lista;
ROLLBACK;

\echo '=== RONDA 3 - ANTES (Seq Scan) ==='
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, nombre, precio_lista, stock
FROM producto
WHERE id_categoria = 1 AND precio_lista BETWEEN 1000 AND 3000
ORDER BY precio_lista;

\echo '=== RONDA 3 - DESPUES (con candidato) ==='
BEGIN;
CREATE INDEX idx_producto_categoria_precio ON producto (id_categoria, precio_lista);
ANALYZE producto;
EXPLAIN (ANALYZE, BUFFERS)
SELECT id, nombre, precio_lista, stock
FROM producto
WHERE id_categoria = 1 AND precio_lista BETWEEN 1000 AND 3000
ORDER BY precio_lista;
ROLLBACK;

\echo '=== Verificacion: el candidato NO debe quedar aplicado (todo dentro de ROLLBACK) ==='
SELECT indexname FROM pg_indexes WHERE indexname = 'idx_producto_categoria_precio';
