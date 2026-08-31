-- ============================================================================
-- TRABAJO PRÁCTICO N.º 2 - CONCURRENCIA E IA
-- Archivo: TP2_Concurrencia_IA/restricciones_integridad.sql
-- Motor: PostgreSQL 17.11
-- Descripción: Restricciones de integridad mediante triggers:
--   1. Transiciones irreversibles de estados finalizados en pedidos.
--   2. Validación de fecha_hora no futura en pedidos.
--   3. Validación de stock disponible al insertar líneas de detalle.
-- ============================================================================

-- ----------------------------------------------------------------------------
-- RESTRICCIÓN 1: Transición irreversible de estado en tabla 'pedido'
-- Un pedido en ENTREGADO o CANCELADO es un estado final y no admite ningún cambio
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validar_transicion_estado_pedido()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.estado IN ('ENTREGADO', 'CANCELADO') AND NEW.estado <> OLD.estado THEN
        RAISE EXCEPTION 'Transición no permitida: el estado % es un estado final y no admite cambios.',
            OLD.estado;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_pedido_estado_transicion ON pedido;
CREATE TRIGGER trg_pedido_estado_transicion
BEFORE UPDATE ON pedido
FOR EACH ROW
EXECUTE FUNCTION fn_validar_transicion_estado_pedido();


-- ----------------------------------------------------------------------------
-- RESTRICCIÓN 2: Validación de fecha_hora no futura en tabla 'pedido'
-- fecha_hora no puede ser posterior al momento actual (now())
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validar_fecha_hora_pedido()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.fecha_hora > now() THEN
        RAISE EXCEPTION 'La fecha y hora del pedido (%) no puede ser posterior al momento actual (%)',
            NEW.fecha_hora, now();
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_pedido_fecha_hora ON pedido;
CREATE TRIGGER trg_pedido_fecha_hora
BEFORE INSERT OR UPDATE ON pedido
FOR EACH ROW
EXECUTE FUNCTION fn_validar_fecha_hora_pedido();


-- ----------------------------------------------------------------------------
-- RESTRICCIÓN 3: Validación de stock en tabla 'detalle_pedido'
-- La cantidad no puede superar el stock disponible en la tabla 'producto'
-- ----------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_validar_stock_detalle_pedido()
RETURNS TRIGGER AS $$
DECLARE
    v_stock INTEGER;
BEGIN
    SELECT stock INTO v_stock
    FROM producto
    WHERE id = NEW.id_producto;

    IF v_stock IS NULL THEN
        RAISE EXCEPTION 'El producto con ID % no existe', NEW.id_producto;
    END IF;

    IF NEW.cantidad > v_stock THEN
        RAISE EXCEPTION 'Stock insuficiente para el producto ID %. Cantidad solicitada: %, Stock disponible: %',
            NEW.id_producto, NEW.cantidad, v_stock;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_detalle_pedido_validar_stock ON detalle_pedido;
CREATE TRIGGER trg_detalle_pedido_validar_stock
BEFORE INSERT OR UPDATE ON detalle_pedido
FOR EACH ROW
EXECUTE FUNCTION fn_validar_stock_detalle_pedido();