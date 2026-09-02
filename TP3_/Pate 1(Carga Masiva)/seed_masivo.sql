-- ============================================================================
-- TRABAJO PRÁCTICO N.º 3 - OPTIMIZACIÓN Y PERFORMANCE DE CONSULTAS
-- Archivo: parte1_carga_masiva/seed_masivo.sql
-- Motor: PostgreSQL 17
-- Adaptación del script Genera_registros.sql provisto por la cátedra al
-- esquema real de FoodStore (TP1). Mapeo aplicado:
--   usuario                     -> cliente
--   usuario.nombre + apellido   -> cliente.nombre_completo
--   usuario.mail                -> cliente.email
--   usuario.celular             -> cliente.telefono
--   usuario.contrasena          -> (no existe en este esquema, se omite)
--   producto.categoria_id       -> producto.id_categoria
--   producto.precio             -> producto.precio_lista
--   pedido.usuario_id           -> pedido.id_cliente
--   pedido.fecha (DATE)         -> pedido.fecha_hora (TIMESTAMPTZ)
--   detalle_pedido.producto_id/pedido_id -> id_producto / id_pedido
--   estado: 'CONFIRMADO'->'EN_PREPARACION', 'TERMINADO'->'ENTREGADO'
--   precio_unitario: sin trigger trg_subtotal en este esquema, se completa
--                     explicitamente con el precio_lista del producto elegido
--
-- CORRECCION (v2): la version original de este script usaba subconsultas
-- escalares del tipo (SELECT id FROM tabla ORDER BY random() LIMIT 1) y un
-- CROSS JOIN LATERAL sin correlacion real con la fila externa. PostgreSQL
-- puede resolver ese tipo de subconsultas UNA SOLA VEZ para toda la
-- sentencia (en vez de una vez por fila), porque no dependen de ninguna
-- columna de la fila externa. Esto genero relaciones degeneradas:
--   - producto.id_categoria: 50.002 de 50.003 filas en una sola categoria
--   - pedido.id_cliente: 200.000 de 200.005 pedidos en un solo cliente
--   - detalle_pedido.id_producto: solo 7 productos distintos en 621.801 filas
-- Verificado empiricamente contra foodstore_tp3_carga (ver DUIA_TP3.md).
--
-- Esta version reemplaza esas subconsultas por indexado de arrays
-- (array_agg + floor(random()*n) como expresion directa en el SELECT),
-- que si se evalua fila por fila porque no depende de una subconsulta
-- aparte que el planificador pueda resolver una unica vez.
-- ============================================================================
BEGIN;

-- 1) Productos: 50.000 filas repartidas entre las categorias existentes
WITH cat_pool AS (
    SELECT array_agg(id ORDER BY id) AS ids, count(*) AS total_cats
    FROM categoria
)
INSERT INTO producto (nombre, precio_lista, descripcion, stock, id_categoria)
SELECT 'Producto ' || i,
       (random() * 4500 + 500)::numeric(10,2),
       'Producto generado para prueba de carga',
       (random() * 200)::int,
       cp.ids[1 + floor(random() * cp.total_cats)::int]
FROM generate_series(1, 50000) AS s(i)
CROSS JOIN cat_pool cp;

-- 2) Clientes: 20.000 filas (sin FK aleatoria, no estaba afectado por el bug)
INSERT INTO cliente (nombre_completo, email, telefono)
SELECT 'Usuario' || i || ' Apellido' || i,
       'usuario' || i || '@test.com',
       '261' || lpad((random()*9999999)::int::text, 7, '0')
FROM generate_series(1, 20000) AS s(i);

-- 3) Pedidos: 200.000 filas, con cliente existente elegido al azar (corregido)
WITH client_pool AS (
    SELECT array_agg(id ORDER BY id) AS ids, count(*) AS total_clients
    FROM cliente
)
INSERT INTO pedido (fecha_hora, estado, forma_pago, id_cliente)
SELECT (CURRENT_DATE - (random()*365)::int)::timestamptz,
       (ARRAY['PENDIENTE','EN_PREPARACION','ENTREGADO','CANCELADO']::estado_pedido_enum[])
           [floor(random()*4+1)],
       (ARRAY['TARJETA','TRANSFERENCIA','EFECTIVO']::forma_pago_enum[])
           [floor(random()*3+1)],
       cp.ids[1 + floor(random() * cp.total_clients)::int]
FROM generate_series(1, 200000) AS s(i)
CROSS JOIN client_pool cp;

-- 4) Detalle de pedido: entre 1 y 4 lineas por pedido (corregido).
--    Se elige el producto por indice de array directamente en el SELECT
--    (evaluado por fila), y se hace un JOIN normal (no LATERAL) contra
--    producto para traer el precio_lista correcto de ese producto puntual.
--    Puede haber colision de producto repetido dentro del mismo pedido;
--    se descarta con ON CONFLICT DO NOTHING (salvedad ya documentada en
--    el DUIA desde la version anterior).
WITH product_pool AS (
    SELECT array_agg(id ORDER BY id) AS prod_ids, count(*) AS total_prods
    FROM producto
),
pedido_lines AS (
    SELECT p.id AS id_pedido,
           generate_series(1, (1 + floor(random()*4))::int) AS line_num
    FROM pedido p
),
sub AS (
    SELECT pl.id_pedido,
           pp.prod_ids[1 + floor(random() * pp.total_prods)::int] AS id_producto,
           (1 + floor(random()*4))::int AS cantidad
    FROM pedido_lines pl
    CROSS JOIN product_pool pp
)
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario)
SELECT sub.id_pedido, sub.id_producto, sub.cantidad, pr.precio_lista
FROM sub
JOIN producto pr ON pr.id = sub.id_producto
ON CONFLICT (id_pedido, id_producto) DO NOTHING;

COMMIT;

ANALYZE producto; ANALYZE cliente; ANALYZE pedido; ANALYZE detalle_pedido;
