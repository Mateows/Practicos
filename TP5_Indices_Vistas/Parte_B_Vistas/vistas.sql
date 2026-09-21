-- TP5 - Parte B: vistas de reportes y exposicion controlada
-- Ejecutar despues de schema.sql y usuarios.sql.

CREATE OR REPLACE VIEW v_usuario_publico AS
SELECT
    id,
    nombre,
    apellido,
    mail,
    celular,
    rol,
    created_at
FROM usuario
WHERE eliminado = FALSE;

CREATE OR REPLACE VIEW v_reporte_ventas_cliente AS
SELECT
    c.id AS cliente_id,
    c.nombre_completo,
    COUNT(DISTINCT p.id) AS pedidos,
    COALESCE(SUM(dp.subtotal), 0)::NUMERIC(12, 2) AS total_facturado
FROM cliente AS c
LEFT JOIN pedido AS p
    ON p.id_cliente = c.id
   AND p.estado <> 'CANCELADO'
LEFT JOIN detalle_pedido AS dp
    ON dp.id_pedido = p.id
GROUP BY c.id, c.nombre_completo;

CREATE OR REPLACE VIEW v_catalogo_productos AS
SELECT
    p.id AS producto_id,
    p.nombre AS producto,
    c.nombre AS categoria,
    p.precio_lista,
    p.stock
FROM producto AS p
JOIN categoria AS c ON c.id = p.id_categoria
WHERE p.activo = TRUE
  AND c.activo = TRUE;

COMMENT ON VIEW v_usuario_publico IS 'Vista segura: omite deliberadamente usuario.contrasena.';
COMMENT ON VIEW v_reporte_ventas_cliente IS 'Reporte de ventas por cliente sin exponer credenciales.';
COMMENT ON VIEW v_catalogo_productos IS 'Catalogo operativo de productos y categorias activas.';

CREATE OR REPLACE VIEW v_detalle_pedido_producto AS
SELECT
    dp.id_pedido,
    dp.id_producto,
    pr.nombre AS producto,
    dp.cantidad,
    dp.precio_unitario,
    dp.subtotal
FROM detalle_pedido AS dp
JOIN producto AS pr ON pr.id = dp.id_producto;

COMMENT ON VIEW v_detalle_pedido_producto IS 'Detalle de pedido con el nombre del producto, para reportes.';

CREATE OR REPLACE VIEW v_pedido_cliente AS
SELECT
    p.id AS pedido_id,
    p.fecha_hora,
    p.forma_pago,
    p.estado,
    c.id AS cliente_id,
    c.nombre_completo,
    c.email
FROM pedido AS p
JOIN cliente AS c ON c.id = p.id_cliente;

COMMENT ON VIEW v_pedido_cliente IS 'Pedidos con los datos del cliente, fila a fila (punto 1 de la consigna). v_reporte_ventas_cliente queda como reporte agregado complementario.';