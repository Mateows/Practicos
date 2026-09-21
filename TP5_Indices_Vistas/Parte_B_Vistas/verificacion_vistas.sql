-- TP5 - Verificacion de Partes B y C.
-- Las sentencias de escritura/DDL deben ejecutarse en la base de trabajo.

-- 1) La vista publica no debe exponer la columna de contrasena.
SELECT column_name
FROM information_schema.columns
WHERE table_name = 'v_usuario_publico'
ORDER BY ordinal_position;

-- 2) La vista materializada debe existir y tener datos despues de la carga.
SELECT * FROM mv_resumen_ventas_categoria_mes
ORDER BY facturacion_total DESC, id_categoria;

-- 3) Actualizacion de la vista materializada.
REFRESH MATERIALIZED VIEW mv_resumen_ventas_categoria_mes;

-- 4) Prueba conceptual de permisos. Ejecutar como propietario o superusuario.
SET ROLE tp5_reportes;
SELECT * FROM v_usuario_publico LIMIT 5;
SELECT * FROM v_reporte_ventas_cliente LIMIT 5;
SELECT * FROM v_catalogo_productos LIMIT 5;
SELECT * FROM v_detalle_pedido_producto LIMIT 5;
SELECT * FROM mv_resumen_ventas_categoria_mes LIMIT 5;
-- Esta consulta debe fallar por falta de privilegios:
-- SELECT * FROM usuario;
-- Evidencia real capturada de este fallo (ERROR: permiso denegado a la tabla usuario): ver Parte_B_Vistas/evidencia_permiso_denegado.txt
RESET ROLE;

-- 5) Verificacion de equivalencia: cada vista contra su consulta manual.
-- Cada bloque debe devolver 0 filas si la vista y la consulta manual coinciden exactamente.

-- v_catalogo_productos
(
    SELECT producto_id, producto, categoria, precio_lista, stock
    FROM v_catalogo_productos
    EXCEPT
    SELECT p.id, p.nombre, c.nombre, p.precio_lista, p.stock
    FROM producto AS p
    JOIN categoria AS c ON c.id = p.id_categoria
    WHERE p.activo = TRUE AND c.activo = TRUE
)
UNION ALL
(
    SELECT p.id, p.nombre, c.nombre, p.precio_lista, p.stock
    FROM producto AS p
    JOIN categoria AS c ON c.id = p.id_categoria
    WHERE p.activo = TRUE AND c.activo = TRUE
    EXCEPT
    SELECT producto_id, producto, categoria, precio_lista, stock
    FROM v_catalogo_productos
);

-- v_reporte_ventas_cliente (consulta manual con subconsultas escalares,
-- deliberadamente distinta a la forma con JOIN + GROUP BY de la vista)
(
    SELECT cliente_id, nombre_completo, pedidos, total_facturado
    FROM v_reporte_ventas_cliente
    EXCEPT
    SELECT
        c.id,
        c.nombre_completo,
        (SELECT COUNT(*) FROM pedido pe WHERE pe.id_cliente = c.id AND pe.estado <> 'CANCELADO'),
        COALESCE((
            SELECT SUM(dp.subtotal)
            FROM pedido pe
            JOIN detalle_pedido dp ON dp.id_pedido = pe.id
            WHERE pe.id_cliente = c.id AND pe.estado <> 'CANCELADO'
        ), 0)::NUMERIC(12, 2)
    FROM cliente AS c
)
UNION ALL
(
    SELECT
        c.id,
        c.nombre_completo,
        (SELECT COUNT(*) FROM pedido pe WHERE pe.id_cliente = c.id AND pe.estado <> 'CANCELADO'),
        COALESCE((
            SELECT SUM(dp.subtotal)
            FROM pedido pe
            JOIN detalle_pedido dp ON dp.id_pedido = pe.id
            WHERE pe.id_cliente = c.id AND pe.estado <> 'CANCELADO'
        ), 0)::NUMERIC(12, 2)
    FROM cliente AS c
    EXCEPT
    SELECT cliente_id, nombre_completo, pedidos, total_facturado
    FROM v_reporte_ventas_cliente
);

-- v_detalle_pedido_producto
(
    SELECT id_pedido, id_producto, producto, cantidad, precio_unitario, subtotal
    FROM v_detalle_pedido_producto
    EXCEPT
    SELECT dp.id_pedido, dp.id_producto, pr.nombre, dp.cantidad, dp.precio_unitario, dp.subtotal
    FROM detalle_pedido AS dp
    JOIN producto AS pr ON pr.id = dp.id_producto
)
UNION ALL
(
    SELECT dp.id_pedido, dp.id_producto, pr.nombre, dp.cantidad, dp.precio_unitario, dp.subtotal
    FROM detalle_pedido AS dp
    JOIN producto AS pr ON pr.id = dp.id_producto
    EXCEPT
    SELECT id_pedido, id_producto, producto, cantidad, precio_unitario, subtotal
    FROM v_detalle_pedido_producto
);

-- v_usuario_publico
(
    SELECT id, nombre, apellido, mail, celular, rol, created_at
    FROM v_usuario_publico
    EXCEPT
    SELECT id, nombre, apellido, mail, celular, rol, created_at
    FROM usuario
    WHERE eliminado = FALSE
)
UNION ALL
(
    SELECT id, nombre, apellido, mail, celular, rol, created_at
    FROM usuario
    WHERE eliminado = FALSE
    EXCEPT
    SELECT id, nombre, apellido, mail, celular, rol, created_at
    FROM v_usuario_publico
);

-- v_pedido_cliente
(
    SELECT pedido_id, fecha_hora, forma_pago, estado, cliente_id, nombre_completo, email
    FROM v_pedido_cliente
    EXCEPT
    SELECT p.id, p.fecha_hora, p.forma_pago, p.estado, c.id, c.nombre_completo, c.email
    FROM pedido AS p
    JOIN cliente AS c ON c.id = p.id_cliente
)
UNION ALL
(
    SELECT p.id, p.fecha_hora, p.forma_pago, p.estado, c.id, c.nombre_completo, c.email
    FROM pedido AS p
    JOIN cliente AS c ON c.id = p.id_cliente
    EXCEPT
    SELECT pedido_id, fecha_hora, forma_pago, estado, cliente_id, nombre_completo, email
    FROM v_pedido_cliente
);
