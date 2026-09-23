-- TP5 - Parte B: rol con acceso a vistas, no a tablas base
-- El rol es grupal (NOLOGIN). Se prueba mediante SET ROLE.
-- IMPORTANTE: este script asume que usuarios.sql, vistas.sql y
-- Parte_C_Vista_Materializada/vista_materializada.sql ya se ejecutaron
-- antes (crean la secuencia usuario_id_seq, las vistas y la vista
-- materializada sobre las que este script otorga permisos). Si se corre
-- antes, falla con "relation does not exist". views.sql los ejecuta en
-- ese orden.

DO $$
BEGIN
    CREATE ROLE tp5_reportes NOLOGIN;
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;

REVOKE ALL ON TABLE usuario, cliente, pedido, detalle_pedido, producto, categoria
    FROM PUBLIC, tp5_reportes;
REVOKE ALL ON SEQUENCE usuario_id_seq FROM tp5_reportes;

GRANT USAGE ON SCHEMA public TO tp5_reportes;
GRANT SELECT ON
    v_usuario_publico,
    v_reporte_ventas_cliente,
    v_catalogo_productos,
    v_detalle_pedido_producto,
    v_pedido_cliente,
    mv_resumen_ventas_categoria_mes
    TO tp5_reportes;
