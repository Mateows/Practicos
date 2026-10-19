-- TP6 — Parte 2: propuesta de desnormalización transaccional.
-- Ejecutar completo con psql exclusivamente en la copia de trabajo.
-- Requiere respaldo previo porque contiene DDL.
-- No instala cambios persistentes: termina con ROLLBACK.
--
-- Alcance de sincronización:
-- DML normal con triggers habilitados y aislamiento READ COMMITTED.
-- No cubre escrituras que deshabiliten triggers o usen replicación
-- para omitirlos. Las pruebas concurrentes quedan pendientes.

\set ON_ERROR_STOP on

BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

-- ============================================================
-- 1. Base, tablas y condiciones de ejecución
-- ============================================================

DO $$
DECLARE
    v_tabla TEXT;
BEGIN
    IF current_database() <> 'foodstore_copia_trabajo' THEN
        RAISE EXCEPTION
            'Base no permitida: %. Usar foodstore_copia_trabajo.',
            current_database();
    END IF;

    IF current_setting('session_replication_role') <> 'origin' THEN
        RAISE EXCEPTION
            'La prueba requiere session_replication_role = origin.';
    END IF;

    FOREACH v_tabla IN ARRAY ARRAY[
        'pedido', 'detalle_pedido', 'producto', 'categoria', 'cliente'
    ]
    LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM pg_catalog.pg_class AS c
            JOIN pg_catalog.pg_namespace AS n
              ON n.oid = c.relnamespace
            WHERE n.nspname = 'public'
              AND c.relname = v_tabla
              AND c.relkind = 'r'
              AND NOT c.relrowsecurity
        ) THEN
            RAISE EXCEPTION
                'public.% debe existir como tabla ordinaria sin RLS para esta propuesta.',
                v_tabla;
        END IF;
    END LOOP;
END;
$$;

-- Bloquea escrituras y DDL concurrente durante instalación,
-- carga inicial, pruebas y mediciones. NOWAIT evita quedar esperando.
-- ACCESS EXCLUSIVE también bloquea lectores: es una instalación
-- de laboratorio, no una migración en línea.
-- No hay una ventana entre carga y activación de triggers.

LOCK TABLE
    public.categoria,
    public.cliente,
    public.pedido,
    public.producto,
    public.detalle_pedido
IN ACCESS EXCLUSIVE MODE NOWAIT;

-- ============================================================
-- 2. Rechazar objetos existentes y condiciones incompatibles
-- ============================================================

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_catalog.pg_attribute
        WHERE attrelid IN ('public.pedido'::regclass, 'public.detalle_pedido'::regclass)
          AND attname = 'eliminado' AND NOT attisdropped
    ) THEN
        RAISE EXCEPTION 'Ya existe eliminado en pedido o detalle_pedido. Revisar; no reutilizar.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_catalog.pg_attribute
        WHERE attrelid = 'public.detalle_pedido'::regclass
          AND attname IN (
              'fecha_hora_pedido_cache',
              'id_categoria_cache',
              'pedido_eliminado_cache'
          )
          AND NOT attisdropped
    ) THEN
        RAISE EXCEPTION
            'Ya existe alguna columna cache. No se sobrescribirá.';
    END IF;

    -- Rechaza cualquier sobrecarga con estos nombres.
    IF EXISTS (
        SELECT 1
        FROM pg_catalog.pg_proc AS p
        JOIN pg_catalog.pg_namespace AS n
          ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname IN (
              'fn_tp6_sync_detalle_cache',
              'fn_tp6_propagar_fecha_cache',
              'fn_tp6_propagar_categoria_cache'
          )
    ) THEN
        RAISE EXCEPTION
            'Ya existe alguna función reservada para TP6.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_catalog.pg_trigger
        WHERE tgrelid IN (
            'public.detalle_pedido'::regclass,
            'public.pedido'::regclass,
            'public.producto'::regclass
        )
          AND tgname IN (
              'zz_tp6_sync_detalle_cache',
              'trg_tp6_propagar_fecha_cache',
              'trg_tp6_propagar_categoria_cache'
          )
    ) THEN
        RAISE EXCEPTION
            'Ya existe algún trigger reservado para TP6.';
    END IF;

    -- También rechaza una relación de otro tipo con el nombre del índice.
    IF EXISTS (
        SELECT 1
        FROM pg_catalog.pg_class AS c
        JOIN pg_catalog.pg_namespace AS n
          ON n.oid = c.relnamespace
        WHERE n.nspname = 'public'
          AND c.relname = 'idx_tp6_detalle_fecha_cache'
    ) THEN
        RAISE EXCEPTION
            'Ya existe public.idx_tp6_detalle_fecha_cache.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_catalog.pg_constraint
        WHERE conrelid = 'public.detalle_pedido'::regclass
          AND conname = 'fk_tp6_detalle_categoria_cache'
    ) THEN
        RAISE EXCEPTION
            'Ya existe la restricción reservada para TP6.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_catalog.pg_class
        WHERE relnamespace = pg_my_temp_schema()
          AND relname IN (
              'tp6_auditoria_cache',
              'tp6_top_normalizado',
              'tp6_top_cache',
              'tp6_diferencias_top',
              'tp6_filas_normalizadas',
              'tp6_filas_cache',
              'tp6_diferencias_filas'
          )
    ) THEN
        RAISE EXCEPTION
            'Ya existe alguna relación temporal reservada para esta prueba.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM pg_catalog.pg_proc
        WHERE pronamespace = pg_my_temp_schema()
          AND proname = 'fn_tp6_assert_equivalencia'
    ) THEN
        RAISE EXCEPTION 'Ya existe la función temporal de aserciones TP6.';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM pg_catalog.pg_trigger
        WHERE tgrelid IN (
            'public.detalle_pedido'::regclass,
            'public.pedido'::regclass,
            'public.producto'::regclass
        )
          AND NOT tgisinternal
          AND tgenabled <> 'O'
    ) THEN
        RAISE EXCEPTION
            'Hay triggers de usuario fuera del modo origin habilitado. Revisar antes de continuar.';
    END IF;

    -- Verifica la existencia de los padres y de la categoría.
    -- No compara cantidad con stock actual: esa comparación no
    -- determina la validez de un detalle histórico para este ensayo.
    --
    -- El repositorio contiene un script de validación de stock,
    -- pero la comprobación real de esta copia no encontró triggers
    -- de usuario instalados en pedido, detalle_pedido ni producto.
    -- No se instala esa regla ni se modifican cantidades o stock.

    IF EXISTS (
        SELECT 1
        FROM public.detalle_pedido AS dp
        LEFT JOIN public.producto AS pr
          ON pr.id = dp.id_producto
        LEFT JOIN public.pedido AS ped
          ON ped.id = dp.id_pedido
        LEFT JOIN public.categoria AS c
          ON c.id = pr.id_categoria
        WHERE pr.id IS NULL
           OR ped.id IS NULL
           OR c.id IS NULL
    ) THEN
        RAISE EXCEPTION
            'Hay detalles sin pedido, producto o categoría existentes. Carga inicial abortada.';
    END IF;
END;
$$;

-- ============================================================
-- 3. Columnas y sincronización de detalles
-- ============================================================

ALTER TABLE public.pedido
    ADD COLUMN eliminado BOOLEAN NOT NULL DEFAULT FALSE;

ALTER TABLE public.detalle_pedido
    ADD COLUMN eliminado BOOLEAN NOT NULL DEFAULT FALSE,
    ADD COLUMN pedido_eliminado_cache BOOLEAN,
    ADD COLUMN fecha_hora_pedido_cache TIMESTAMPTZ,
    ADD COLUMN id_categoria_cache BIGINT;

CREATE FUNCTION public.fn_tp6_sync_detalle_cache()
RETURNS TRIGGER
LANGUAGE plpgsql
VOLATILE
SET search_path = pg_catalog, public
AS $$
DECLARE
    v_fecha TIMESTAMPTZ;
    v_categoria BIGINT;
    v_pedido_eliminado BOOLEAN;
BEGIN
    IF current_setting('transaction_isolation') <> 'read committed' THEN
        RAISE EXCEPTION
            'La sincronización TP6 soporta únicamente READ COMMITTED.';
    END IF;

    -- Orden de lectura/bloqueo: pedido, después producto.
    -- Los bloqueos se conservan hasta terminar la transacción.
    SELECT ped.fecha_hora, ped.eliminado
      INTO v_fecha, v_pedido_eliminado
      FROM public.pedido AS ped
     WHERE ped.id = NEW.id_pedido
     FOR SHARE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'No existe el pedido %.', NEW.id_pedido;
    END IF;

    SELECT pr.id_categoria
      INTO v_categoria
      FROM public.producto AS pr
     WHERE pr.id = NEW.id_producto
     FOR SHARE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'No existe el producto %.', NEW.id_producto;
    END IF;

    -- Siempre se recalcula: no se aceptan copias arbitrarias,
    -- incluso si el UPDATE menciona directamente las columnas cache.
    NEW.fecha_hora_pedido_cache := v_fecha;
    NEW.id_categoria_cache := v_categoria;
    NEW.pedido_eliminado_cache := v_pedido_eliminado;
    -- NEW.eliminado es propio del detalle y no se deriva del pedido.

    RETURN NEW;
END;
$$;

CREATE TRIGGER zz_tp6_sync_detalle_cache
BEFORE INSERT OR UPDATE ON public.detalle_pedido
FOR EACH ROW
EXECUTE FUNCTION public.fn_tp6_sync_detalle_cache();

-- ============================================================
-- 4. Propagación desde pedidos y productos
-- ============================================================

-- Nombre histórico conservado: ahora propaga fecha y eliminado del pedido.
CREATE FUNCTION public.fn_tp6_propagar_fecha_cache()
RETURNS TRIGGER
LANGUAGE plpgsql
VOLATILE
SET search_path = pg_catalog, public
AS $$
BEGIN
    IF current_setting('transaction_isolation') <> 'read committed' THEN
        RAISE EXCEPTION
            'La sincronización TP6 soporta únicamente READ COMMITTED.';
    END IF;

    -- El UPDATE del padre ya mantiene su bloqueo de fila.
    -- Este UPDATE obtiene una instantánea nueva en READ COMMITTED.
    -- Incluye detalles eliminados individualmente; su eliminado no cambia.
    -- El trigger del detalle vuelve a derivar las tres copias.
    UPDATE public.detalle_pedido
       SET fecha_hora_pedido_cache = NEW.fecha_hora,
           pedido_eliminado_cache = NEW.eliminado
     WHERE id_pedido = NEW.id
       AND (fecha_hora_pedido_cache IS DISTINCT FROM NEW.fecha_hora
            OR pedido_eliminado_cache IS DISTINCT FROM NEW.eliminado);

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_tp6_propagar_fecha_cache
AFTER UPDATE ON public.pedido
FOR EACH ROW
WHEN (OLD.fecha_hora IS DISTINCT FROM NEW.fecha_hora
      OR OLD.eliminado IS DISTINCT FROM NEW.eliminado)
EXECUTE FUNCTION public.fn_tp6_propagar_fecha_cache();

CREATE FUNCTION public.fn_tp6_propagar_categoria_cache()
RETURNS TRIGGER
LANGUAGE plpgsql
VOLATILE
SET search_path = pg_catalog, public
AS $$
BEGIN
    IF current_setting('transaction_isolation') <> 'read committed' THEN
        RAISE EXCEPTION
            'La sincronización TP6 soporta únicamente READ COMMITTED.';
    END IF;

    UPDATE public.detalle_pedido
       SET id_categoria_cache = NEW.id_categoria
     WHERE id_producto = NEW.id
       AND id_categoria_cache IS DISTINCT FROM NEW.id_categoria;

    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_tp6_propagar_categoria_cache
AFTER UPDATE ON public.producto
FOR EACH ROW
WHEN (OLD.id_categoria IS DISTINCT FROM NEW.id_categoria)
EXECUTE FUNCTION public.fn_tp6_propagar_categoria_cache();

-- DELETE de detalle elimina también las copias, sin acumulados externos.
-- DELETE de pedido conserva el CASCADE existente hacia sus detalles.
-- Las restricciones originales impiden borrar productos/categorías
-- utilizados.
-- No se modifican las FK originales ni se instalan los triggers de TP2.
-- Los únicos triggers creados aquí son los de sincronización TP6.
--
-- categoria.nombre no se copia: el JOIN muestra su valor vigente.

-- ============================================================
-- 5. Carga inicial, restricciones e índice
-- ============================================================

UPDATE public.detalle_pedido AS dp
SET
    fecha_hora_pedido_cache = ped.fecha_hora,
    id_categoria_cache = pr.id_categoria,
    pedido_eliminado_cache = ped.eliminado
FROM public.pedido AS ped,
     public.producto AS pr
WHERE ped.id = dp.id_pedido
  AND pr.id = dp.id_producto;

ALTER TABLE public.detalle_pedido
    ALTER COLUMN fecha_hora_pedido_cache SET NOT NULL,
    ALTER COLUMN id_categoria_cache SET NOT NULL,
    ALTER COLUMN pedido_eliminado_cache SET NOT NULL,
    ADD CONSTRAINT fk_tp6_detalle_categoria_cache
        FOREIGN KEY (id_categoria_cache)
        REFERENCES public.categoria (id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE;

-- Índice acotado a la búsqueda diaria.
-- Su costo y beneficio forman parte de la adaptación completa.
CREATE INDEX idx_tp6_detalle_fecha_cache
ON public.detalle_pedido (fecha_hora_pedido_cache);

-- ============================================================
-- 6. Auditoría completa, sin limitarse al día de medición
-- ============================================================

CREATE TEMP VIEW tp6_auditoria_cache AS
SELECT
    dp.id_pedido,
    dp.id_producto,
    dp.fecha_hora_pedido_cache,
    ped.fecha_hora AS fecha_hora_original,
    dp.id_categoria_cache,
    pr.id_categoria AS id_categoria_original,
    dp.pedido_eliminado_cache,
    ped.eliminado AS pedido_eliminado_original,
    dp.eliminado AS detalle_eliminado
FROM public.detalle_pedido AS dp
LEFT JOIN public.pedido AS ped
    ON ped.id = dp.id_pedido
LEFT JOIN public.producto AS pr
    ON pr.id = dp.id_producto
LEFT JOIN public.categoria AS c
    ON c.id = dp.id_categoria_cache
WHERE ped.id IS NULL
   OR pr.id IS NULL
   OR c.id IS NULL
   OR dp.fecha_hora_pedido_cache IS DISTINCT FROM ped.fecha_hora
   OR dp.id_categoria_cache IS DISTINCT FROM pr.id_categoria
   OR dp.pedido_eliminado_cache IS DISTINCT FROM ped.eliminado;

SELECT *
FROM pg_temp.tp6_auditoria_cache
ORDER BY id_pedido, id_producto;

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_temp.tp6_auditoria_cache) THEN
        RAISE EXCEPTION
            'Auditoría inicial fallida: hay datos cache desincronizados.';
    END IF;
END;
$$;

-- ============================================================
-- 7. Consultas acordadas
-- ============================================================
-- Fecha histórica reproducible: 2026-06-25, America/Buenos_Aires.
-- Sustituye CURRENT_DATE porque la carga no contiene pedidos de hoy.
-- Ambos atributos eliminado existen solo dentro del ensayo transaccional.
-- No se agregan filtros por estado comercial ni por activo.
--
-- Estas vistas son temporales y normales, no materializadas.
-- El planificador expande sus definiciones.

CREATE TEMP VIEW tp6_top_normalizado AS
SELECT
    c.nombre AS categoria,
    SUM(dp.subtotal) AS total_vendido
FROM public.detalle_pedido AS dp
JOIN public.producto AS pr
    ON pr.id = dp.id_producto
JOIN public.categoria AS c
    ON c.id = pr.id_categoria
JOIN public.pedido AS ped
    ON ped.id = dp.id_pedido
WHERE ped.fecha_hora >= (
    TIMESTAMP '2026-06-25 00:00:00'
    AT TIME ZONE 'America/Buenos_Aires'
)
  AND ped.fecha_hora < (
    TIMESTAMP '2026-06-26 00:00:00'
    AT TIME ZONE 'America/Buenos_Aires'
)
  AND dp.eliminado = FALSE
  AND ped.eliminado = FALSE
GROUP BY c.nombre
ORDER BY total_vendido DESC
LIMIT 5;

CREATE TEMP VIEW tp6_top_cache AS
SELECT
    c.nombre AS categoria,
    SUM(dp.subtotal) AS total_vendido
FROM public.detalle_pedido AS dp
JOIN public.categoria AS c
    ON c.id = dp.id_categoria_cache
WHERE dp.fecha_hora_pedido_cache >= (
    TIMESTAMP '2026-06-25 00:00:00'
    AT TIME ZONE 'America/Buenos_Aires'
)
  AND dp.fecha_hora_pedido_cache < (
    TIMESTAMP '2026-06-26 00:00:00'
    AT TIME ZONE 'America/Buenos_Aires'
)
  AND dp.eliminado = FALSE
  AND dp.pedido_eliminado_cache = FALSE
GROUP BY c.nombre
ORDER BY total_vendido DESC
LIMIT 5;

CREATE TEMP VIEW tp6_diferencias_top AS
SELECT 'normalizado_menos_cache'::TEXT AS sentido, d.*
FROM (
    SELECT categoria, total_vendido
    FROM pg_temp.tp6_top_normalizado
    EXCEPT
    SELECT categoria, total_vendido
    FROM pg_temp.tp6_top_cache
) AS d
UNION ALL
SELECT 'cache_menos_normalizado'::TEXT AS sentido, d.*
FROM (
    SELECT categoria, total_vendido
    FROM pg_temp.tp6_top_cache
    EXCEPT
    SELECT categoria, total_vendido
    FROM pg_temp.tp6_top_normalizado
) AS d;

-- Equivalencia de todas las filas elegibles del día, antes de agregar
-- o limitar a cinco categorías. EXCEPT ALL conserva multiplicidades.
CREATE TEMP VIEW tp6_filas_normalizadas AS
SELECT dp.id_pedido, dp.id_producto, c.nombre AS categoria, dp.subtotal
FROM public.detalle_pedido AS dp
JOIN public.producto AS pr ON pr.id = dp.id_producto
JOIN public.categoria AS c ON c.id = pr.id_categoria
JOIN public.pedido AS ped ON ped.id = dp.id_pedido
WHERE ped.fecha_hora >= (TIMESTAMP '2026-06-25 00:00:00' AT TIME ZONE 'America/Buenos_Aires')
  AND ped.fecha_hora < (TIMESTAMP '2026-06-26 00:00:00' AT TIME ZONE 'America/Buenos_Aires')
  AND dp.eliminado = FALSE AND ped.eliminado = FALSE;

CREATE TEMP VIEW tp6_filas_cache AS
SELECT dp.id_pedido, dp.id_producto, c.nombre AS categoria, dp.subtotal
FROM public.detalle_pedido AS dp
JOIN public.categoria AS c ON c.id = dp.id_categoria_cache
WHERE dp.fecha_hora_pedido_cache >= (TIMESTAMP '2026-06-25 00:00:00' AT TIME ZONE 'America/Buenos_Aires')
  AND dp.fecha_hora_pedido_cache < (TIMESTAMP '2026-06-26 00:00:00' AT TIME ZONE 'America/Buenos_Aires')
  AND dp.eliminado = FALSE AND dp.pedido_eliminado_cache = FALSE;

CREATE TEMP VIEW tp6_diferencias_filas AS
SELECT 'normalizado_menos_cache'::TEXT AS sentido, d.*
FROM (
    SELECT * FROM pg_temp.tp6_filas_normalizadas
    EXCEPT ALL
    SELECT * FROM pg_temp.tp6_filas_cache
) AS d
UNION ALL
SELECT 'cache_menos_normalizado'::TEXT AS sentido, d.*
FROM (
    SELECT * FROM pg_temp.tp6_filas_cache
    EXCEPT ALL
    SELECT * FROM pg_temp.tp6_filas_normalizadas
) AS d;

CREATE FUNCTION pg_temp.fn_tp6_assert_equivalencia(p_paso TEXT)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_temp.tp6_auditoria_cache) THEN
        RAISE EXCEPTION 'Auditoría fallida: %.', p_paso;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_temp.tp6_diferencias_filas) THEN
        RAISE EXCEPTION 'EXCEPT ALL de filas detectó diferencias: %.', p_paso;
    END IF;
    IF EXISTS (SELECT 1 FROM pg_temp.tp6_diferencias_top) THEN
        RAISE EXCEPTION 'EXCEPT del top detectó diferencias: %.', p_paso;
    END IF;
END;
$$;

SELECT pg_temp.fn_tp6_assert_equivalencia('estado inicial');

-- ============================================================
-- 8. Pruebas de sincronización reversibles
-- ============================================================
-- IDs negativos explícitos: no se consumen secuencias.
-- OVERRIDING SYSTEM VALUE respeta los identity ALWAYS originales.
-- Se utiliza un cliente existente sin modificarlo.
-- Las filas de prueba tienen cantidades positivas y fechas históricas.
-- Se modifican estados lógicos solo en filas de prueba, no en originales.
-- No hay triggers de usuario previos instalados en esta copia;
-- los scripts de TP2 permanecen en el repositorio y no se ejecutan aquí.
-- Las pruebas se deshacen mediante ROLLBACK TO SAVEPOINT.

SAVEPOINT pruebas_sincronizacion;

DO $$
DECLARE
    v_cliente BIGINT;
    v_fecha TIMESTAMPTZ;
    v_categoria BIGINT;
    v_nombre TEXT;
    v_caso RECORD;
BEGIN
    IF EXISTS (
        SELECT 1 FROM public.categoria WHERE id IN (-6001, -6002)
    ) OR EXISTS (
        SELECT 1 FROM public.producto WHERE id IN (-6001, -6002)
    ) OR EXISTS (
        SELECT 1 FROM public.pedido WHERE id IN (-6001, -6002)
    ) OR EXISTS (
        SELECT 1
        FROM public.categoria
        WHERE nombre IN (
            'TP6_TEST_CACHE_A',
            'TP6_TEST_CACHE_B',
            'TP6_TEST_CACHE_RENOMBRADA'
        )
    ) THEN
        RAISE EXCEPTION
            'Conflicto con IDs o nombres reservados para las pruebas.';
    END IF;

    SELECT id INTO v_cliente
    FROM public.cliente
    ORDER BY id
    LIMIT 1;

    IF v_cliente IS NULL THEN
        RAISE EXCEPTION
            'Se necesita un cliente existente para los pedidos de prueba.';
    END IF;

    INSERT INTO public.categoria (id, nombre)
    OVERRIDING SYSTEM VALUE
    VALUES
        (-6001, 'TP6_TEST_CACHE_A'),
        (-6002, 'TP6_TEST_CACHE_B');
    PERFORM pg_temp.fn_tp6_assert_equivalencia('categorías de prueba');

    INSERT INTO public.producto (
        id, id_categoria, nombre, precio_lista, stock
    )
    OVERRIDING SYSTEM VALUE
    VALUES
        (-6001, -6001, 'TP6 producto prueba A', 10.00, 100),
        (-6002, -6002, 'TP6 producto prueba B', 20.00, 100);
    PERFORM pg_temp.fn_tp6_assert_equivalencia('productos de prueba');

    INSERT INTO public.pedido (
        id, id_cliente, fecha_hora, forma_pago
    )
    OVERRIDING SYSTEM VALUE
    VALUES
        (
            -6001, v_cliente,
            TIMESTAMP '2026-06-25 10:00:00'
                AT TIME ZONE 'America/Buenos_Aires',
            'EFECTIVO'
        ),
        (
            -6002, v_cliente,
            TIMESTAMP '2026-06-24 10:00:00'
                AT TIME ZONE 'America/Buenos_Aires',
            'EFECTIVO'
        );
    PERFORM pg_temp.fn_tp6_assert_equivalencia('pedidos de prueba');

    -- INSERT: copias derivadas y subtotal generado.
    INSERT INTO public.detalle_pedido (
        id_pedido, id_producto, cantidad, precio_unitario
    )
    VALUES (-6001, -6001, 2, 10.00);
    PERFORM pg_temp.fn_tp6_assert_equivalencia('INSERT detalle');

    IF NOT EXISTS (
        SELECT 1
        FROM public.detalle_pedido
        WHERE id_pedido = -6001
          AND id_producto = -6001
          AND fecha_hora_pedido_cache = (
              TIMESTAMP '2026-06-25 10:00:00'
              AT TIME ZONE 'America/Buenos_Aires'
          )
          AND id_categoria_cache = -6001
          AND eliminado = FALSE
          AND pedido_eliminado_cache = FALSE
          AND subtotal = 20.00
    ) THEN
        RAISE EXCEPTION 'Falló la prueba de INSERT.';
    END IF;

    -- UPDATE: cambia monto y rechaza copias arbitrarias.
    UPDATE public.detalle_pedido
    SET cantidad = 3,
        precio_unitario = 12.00,
        fecha_hora_pedido_cache = (
            TIMESTAMP '2000-01-01 00:00:00'
            AT TIME ZONE 'America/Buenos_Aires'
        ),
        id_categoria_cache = -6002,
        pedido_eliminado_cache = TRUE
    WHERE id_pedido = -6001
      AND id_producto = -6001;
    PERFORM pg_temp.fn_tp6_assert_equivalencia('UPDATE y copias arbitrarias');

    IF NOT EXISTS (
        SELECT 1
        FROM public.detalle_pedido
        WHERE id_pedido = -6001
          AND id_producto = -6001
          AND id_categoria_cache = -6001
          AND fecha_hora_pedido_cache = (
              TIMESTAMP '2026-06-25 10:00:00'
              AT TIME ZONE 'America/Buenos_Aires'
          )
          AND subtotal = 36.00
          AND pedido_eliminado_cache = FALSE
    ) THEN
        RAISE EXCEPTION 'Falló la prueba de UPDATE del detalle.';
    END IF;

    -- Cambia ambos padres del detalle.
    UPDATE public.pedido SET eliminado = TRUE WHERE id = -6002;
    PERFORM pg_temp.fn_tp6_assert_equivalencia('pedido destino eliminado');
    UPDATE public.detalle_pedido SET eliminado = TRUE
    WHERE id_pedido = -6001 AND id_producto = -6001;
    PERFORM pg_temp.fn_tp6_assert_equivalencia('eliminación propia antes de cambiar padres');

    UPDATE public.detalle_pedido
    SET id_pedido = -6002,
        id_producto = -6002
    WHERE id_pedido = -6001
      AND id_producto = -6001;
    PERFORM pg_temp.fn_tp6_assert_equivalencia('cambio a pedido eliminado');

    IF NOT EXISTS (
        SELECT 1
        FROM public.detalle_pedido
        WHERE id_pedido = -6002
          AND id_producto = -6002
          AND id_categoria_cache = -6002
          AND eliminado = TRUE
          AND pedido_eliminado_cache = TRUE
          AND fecha_hora_pedido_cache = (
              TIMESTAMP '2026-06-24 10:00:00'
              AT TIME ZONE 'America/Buenos_Aires'
          )
    ) THEN
        RAISE EXCEPTION 'Falló la prueba de cambio de padres.';
    END IF;

    UPDATE public.pedido SET eliminado = FALSE WHERE id = -6002;
    PERFORM pg_temp.fn_tp6_assert_equivalencia('restauración después de cambiar padres');
    IF NOT EXISTS (
        SELECT 1 FROM public.detalle_pedido
        WHERE id_pedido = -6002 AND id_producto = -6002
          AND eliminado = TRUE AND pedido_eliminado_cache = FALSE
    ) THEN
        RAISE EXCEPTION 'Restaurar el nuevo pedido cambió el eliminado propio.';
    END IF;
    UPDATE public.detalle_pedido SET eliminado = FALSE
    WHERE id_pedido = -6002 AND id_producto = -6002;
    PERFORM pg_temp.fn_tp6_assert_equivalencia('restauración individual del detalle');
    IF NOT EXISTS (
        SELECT 1 FROM public.detalle_pedido
        WHERE id_pedido = -6002 AND id_producto = -6002
          AND eliminado = FALSE AND pedido_eliminado_cache = FALSE
    ) OR NOT EXISTS (SELECT 1 FROM public.pedido WHERE id = -6002 AND eliminado = FALSE) THEN
        RAISE EXCEPTION 'Restauración individual incorrecta o modificación del pedido.';
    END IF;

    -- Fecha del pedido: el detalle vuelve al día medido.
    UPDATE public.pedido
    SET fecha_hora = (
        TIMESTAMP '2026-06-25 11:00:00'
        AT TIME ZONE 'America/Buenos_Aires'
    )
    WHERE id = -6002;
    PERFORM pg_temp.fn_tp6_assert_equivalencia('propagación de fecha');

    SELECT fecha_hora_pedido_cache INTO v_fecha
    FROM public.detalle_pedido
    WHERE id_pedido = -6002 AND id_producto = -6002;

    IF v_fecha IS DISTINCT FROM (
        TIMESTAMP '2026-06-25 11:00:00'
        AT TIME ZONE 'America/Buenos_Aires'
    ) THEN
        RAISE EXCEPTION 'Falló la propagación de fecha.';
    END IF;

    -- Categoría actual del producto.
    UPDATE public.producto
    SET id_categoria = -6001
    WHERE id = -6002;
    PERFORM pg_temp.fn_tp6_assert_equivalencia('propagación de categoría');

    SELECT id_categoria_cache INTO v_categoria
    FROM public.detalle_pedido
    WHERE id_pedido = -6002 AND id_producto = -6002;

    IF v_categoria IS DISTINCT FROM -6001::BIGINT THEN
        RAISE EXCEPTION 'Falló la propagación de categoría.';
    END IF;

    -- Nombre: el JOIN debe mostrar el cambio sin copiarlo.
    UPDATE public.categoria
    SET nombre = 'TP6_TEST_CACHE_RENOMBRADA'
    WHERE id = -6001;
    PERFORM pg_temp.fn_tp6_assert_equivalencia('nombre vigente de categoría');

    SELECT c.nombre INTO v_nombre
    FROM public.detalle_pedido AS dp
    JOIN public.categoria AS c
      ON c.id = dp.id_categoria_cache
    WHERE dp.id_pedido = -6002 AND dp.id_producto = -6002;

    IF v_nombre IS DISTINCT FROM 'TP6_TEST_CACHE_RENOMBRADA' THEN
        RAISE EXCEPTION 'Falló la prueba de nombre de categoría.';
    END IF;

    IF EXISTS (SELECT 1 FROM pg_temp.tp6_auditoria_cache) THEN
        RAISE EXCEPTION 'Auditoría fallida durante las pruebas.';
    END IF;

    IF EXISTS (SELECT 1 FROM pg_temp.tp6_diferencias_top) THEN
        RAISE EXCEPTION 'Resultados diferentes durante las pruebas.';
    END IF;

    -- Segundo detalle eliminado individualmente: el pedido debe
    -- propagar también hacia él, pero nunca restaurarlo implícitamente.
    INSERT INTO public.detalle_pedido (
        id_pedido, id_producto, cantidad, precio_unitario, eliminado
    ) VALUES (-6002, -6001, 1, 10.00, TRUE);
    PERFORM pg_temp.fn_tp6_assert_equivalencia('segundo detalle eliminado individualmente');

    -- Matriz completa: pedido/detalle FALSE/FALSE, FALSE/TRUE,
    -- TRUE/FALSE y TRUE/TRUE. El segundo detalle conserva su TRUE.
    FOR v_caso IN
        SELECT * FROM (VALUES
            (1, FALSE, FALSE), (2, FALSE, TRUE),
            (3, TRUE, FALSE), (4, TRUE, TRUE)
        ) AS casos(orden, pedido_eliminado, detalle_eliminado)
        ORDER BY orden
    LOOP
        UPDATE public.pedido SET eliminado = v_caso.pedido_eliminado
        WHERE id = -6002;
        PERFORM pg_temp.fn_tp6_assert_equivalencia('matriz: cambio de pedido');
        IF (SELECT COUNT(*) FROM public.detalle_pedido
            WHERE id_pedido = -6002
              AND pedido_eliminado_cache = v_caso.pedido_eliminado) <> 2
           OR NOT EXISTS (
               SELECT 1 FROM public.detalle_pedido
               WHERE id_pedido = -6002 AND id_producto = -6001 AND eliminado = TRUE
           ) THEN
            RAISE EXCEPTION 'La propagación no alcanzó ambos detalles o alteró el eliminado propio.';
        END IF;

        UPDATE public.detalle_pedido SET eliminado = v_caso.detalle_eliminado
        WHERE id_pedido = -6002 AND id_producto = -6002;
        -- TRUE/FALSE prueba restaurar el detalle bajo pedido eliminado:
        -- su estado propio cambia, el pedido sigue eliminado y no es visible.
        PERFORM pg_temp.fn_tp6_assert_equivalencia('matriz: cambio propio de detalle');
        IF NOT EXISTS (
            SELECT 1 FROM public.detalle_pedido
            WHERE id_pedido = -6002 AND id_producto = -6002
              AND eliminado = v_caso.detalle_eliminado
              AND pedido_eliminado_cache = v_caso.pedido_eliminado
        ) OR NOT EXISTS (
            SELECT 1 FROM public.pedido
            WHERE id = -6002 AND eliminado = v_caso.pedido_eliminado
        ) OR EXISTS (
            SELECT 1 FROM pg_temp.tp6_filas_normalizadas
            WHERE id_pedido = -6002 AND id_producto = -6002
        ) IS DISTINCT FROM (NOT v_caso.pedido_eliminado AND NOT v_caso.detalle_eliminado)
          OR EXISTS (
            SELECT 1 FROM pg_temp.tp6_filas_cache
            WHERE id_pedido = -6002 AND id_producto = -6002
        ) IS DISTINCT FROM (NOT v_caso.pedido_eliminado AND NOT v_caso.detalle_eliminado)
          OR EXISTS (
            SELECT 1 FROM pg_temp.tp6_filas_cache
            WHERE id_pedido = -6002 AND id_producto = -6001
        ) THEN
            RAISE EXCEPTION 'Visibilidad incorrecta en matriz pedido %, detalle %.',
                v_caso.pedido_eliminado, v_caso.detalle_eliminado;
        END IF;
    END LOOP;

    -- Restaurar únicamente el pedido NO restaura detalles individuales.
    UPDATE public.pedido SET eliminado = FALSE WHERE id = -6002;
    PERFORM pg_temp.fn_tp6_assert_equivalencia('restaurar pedido con ambos detalles eliminados');
    IF (SELECT COUNT(*) FROM public.detalle_pedido
        WHERE id_pedido = -6002 AND eliminado = TRUE
          AND pedido_eliminado_cache = FALSE) <> 2
       OR EXISTS (SELECT 1 FROM pg_temp.tp6_filas_cache WHERE id_pedido = -6002) THEN
        RAISE EXCEPTION 'Restaurar el pedido restauró detalles individuales.';
    END IF;

    UPDATE public.detalle_pedido SET eliminado = FALSE
    WHERE id_pedido = -6002 AND id_producto = -6002;
    PERFORM pg_temp.fn_tp6_assert_equivalencia('restaurar un detalle con pedido vigente');
    IF NOT EXISTS (SELECT 1 FROM pg_temp.tp6_filas_cache
                   WHERE id_pedido = -6002 AND id_producto = -6002) THEN
        RAISE EXCEPTION 'El detalle restaurado debe volver al conjunto diario.';
    END IF;

    -- Cambiar simultáneamente fecha y eliminado propaga ambas copias
    -- a los dos detalles, incluso al eliminado individualmente.
    UPDATE public.pedido
    SET fecha_hora = (TIMESTAMP '2026-06-24 12:00:00' AT TIME ZONE 'America/Buenos_Aires'),
        eliminado = TRUE
    WHERE id = -6002;
    PERFORM pg_temp.fn_tp6_assert_equivalencia('cambio simultáneo fecha y eliminado');
    IF (SELECT COUNT(*) FROM public.detalle_pedido
        WHERE id_pedido = -6002 AND pedido_eliminado_cache = TRUE
          AND fecha_hora_pedido_cache = (
              TIMESTAMP '2026-06-24 12:00:00' AT TIME ZONE 'America/Buenos_Aires'
          )) <> 2 THEN
        RAISE EXCEPTION 'Falló la propagación simultánea a ambos detalles.';
    END IF;

    UPDATE public.detalle_pedido SET pedido_eliminado_cache = FALSE
    WHERE id_pedido = -6002;
    PERFORM pg_temp.fn_tp6_assert_equivalencia('corregir cache arbitrario bajo pedido eliminado');
    IF EXISTS (SELECT 1 FROM public.detalle_pedido
               WHERE id_pedido = -6002 AND pedido_eliminado_cache = FALSE) THEN
        RAISE EXCEPTION 'Se aceptó un estado redundante arbitrario.';
    END IF;

    UPDATE public.pedido
    SET fecha_hora = (TIMESTAMP '2026-06-25 11:00:00' AT TIME ZONE 'America/Buenos_Aires'),
        eliminado = FALSE
    WHERE id = -6002;
    PERFORM pg_temp.fn_tp6_assert_equivalencia('restauración simultánea fecha y eliminado');
    IF NOT EXISTS (SELECT 1 FROM public.detalle_pedido
                   WHERE id_pedido = -6002 AND id_producto = -6001 AND eliminado = TRUE)
       OR (SELECT COUNT(*) FROM public.detalle_pedido
           WHERE id_pedido = -6002 AND pedido_eliminado_cache = FALSE
             AND fecha_hora_pedido_cache = (
                 TIMESTAMP '2026-06-25 11:00:00' AT TIME ZONE 'America/Buenos_Aires'
             )) <> 2
       OR NOT EXISTS (SELECT 1 FROM pg_temp.tp6_filas_cache
                       WHERE id_pedido = -6002 AND id_producto = -6002) THEN
        RAISE EXCEPTION 'La restauración simultánea alteró la independencia de los detalles.';
    END IF;

    -- DELETE directo.
    DELETE FROM public.detalle_pedido
    WHERE id_pedido = -6002 AND id_producto = -6002;
    PERFORM pg_temp.fn_tp6_assert_equivalencia('DELETE directo');

    IF EXISTS (
        SELECT 1 FROM public.detalle_pedido
        WHERE id_pedido = -6002 AND id_producto = -6002
    ) THEN
        RAISE EXCEPTION 'Falló la prueba de DELETE.';
    END IF;

    -- DELETE del pedido con CASCADE.
    UPDATE public.pedido SET eliminado = TRUE WHERE id = -6002;
    PERFORM pg_temp.fn_tp6_assert_equivalencia('pedido eliminado antes de INSERT');
    INSERT INTO public.detalle_pedido (
        id_pedido, id_producto, cantidad, precio_unitario
    )
    VALUES (-6002, -6002, 1, 20.00);
    PERFORM pg_temp.fn_tp6_assert_equivalencia('INSERT bajo pedido eliminado');
    IF NOT EXISTS (
        SELECT 1 FROM public.detalle_pedido
        WHERE id_pedido = -6002 AND id_producto = -6002
          AND eliminado = FALSE AND pedido_eliminado_cache = TRUE
    ) OR EXISTS (SELECT 1 FROM pg_temp.tp6_filas_cache WHERE id_pedido = -6002) THEN
        RAISE EXCEPTION 'INSERT bajo pedido eliminado no conservó la semántica independiente.';
    END IF;

    -- Traslado entre pedidos con distintos estados sin modificar el propio.
    IF EXISTS (
        SELECT 1 FROM public.detalle_pedido
        WHERE id_pedido = -6001 AND id_producto = -6002
    ) OR NOT EXISTS (
        SELECT 1 FROM public.pedido WHERE id = -6001 AND eliminado = FALSE
    ) THEN
        RAISE EXCEPTION 'Conflicto de detalle destino o pedido de prueba no vigente.';
    END IF;

    UPDATE public.detalle_pedido SET id_pedido = -6001
    WHERE id_pedido = -6002 AND id_producto = -6002;
    PERFORM pg_temp.fn_tp6_assert_equivalencia('traslado de pedido eliminado a vigente');
    IF NOT EXISTS (
        SELECT 1 FROM public.detalle_pedido
        WHERE id_pedido = -6001 AND id_producto = -6002
          AND eliminado = FALSE AND pedido_eliminado_cache = FALSE
          AND fecha_hora_pedido_cache = (
              TIMESTAMP '2026-06-25 10:00:00' AT TIME ZONE 'America/Buenos_Aires'
          ) AND id_categoria_cache = -6001
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_temp.tp6_filas_normalizadas
        WHERE id_pedido = -6001 AND id_producto = -6002
    ) OR NOT EXISTS (
        SELECT 1 FROM pg_temp.tp6_filas_cache
        WHERE id_pedido = -6001 AND id_producto = -6002
    ) THEN
        RAISE EXCEPTION 'Falló el traslado de pedido eliminado a vigente.';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.detalle_pedido
        WHERE id_pedido = -6002 AND id_producto = -6002
    ) THEN
        RAISE EXCEPTION 'Conflicto con el detalle de retorno al pedido eliminado.';
    END IF;
    UPDATE public.detalle_pedido SET id_pedido = -6002
    WHERE id_pedido = -6001 AND id_producto = -6002;
    PERFORM pg_temp.fn_tp6_assert_equivalencia('retorno de pedido vigente a eliminado');
    IF NOT EXISTS (
        SELECT 1 FROM public.detalle_pedido
        WHERE id_pedido = -6002 AND id_producto = -6002
          AND eliminado = FALSE AND pedido_eliminado_cache = TRUE
          AND fecha_hora_pedido_cache = (
              TIMESTAMP '2026-06-25 11:00:00' AT TIME ZONE 'America/Buenos_Aires'
          ) AND id_categoria_cache = -6001
    ) OR EXISTS (
        SELECT 1 FROM pg_temp.tp6_filas_normalizadas
        WHERE id_pedido = -6002 AND id_producto = -6002
    ) OR EXISTS (
        SELECT 1 FROM pg_temp.tp6_filas_cache
        WHERE id_pedido = -6002 AND id_producto = -6002
    ) THEN
        RAISE EXCEPTION 'Falló el retorno de pedido vigente a eliminado.';
    END IF;

    DELETE FROM public.pedido WHERE id = -6002;
    PERFORM pg_temp.fn_tp6_assert_equivalencia('DELETE CASCADE');

    IF EXISTS (
        SELECT 1 FROM public.detalle_pedido WHERE id_pedido = -6002
    ) THEN
        RAISE EXCEPTION 'Falló la prueba de DELETE CASCADE.';
    END IF;

    IF EXISTS (SELECT 1 FROM pg_temp.tp6_auditoria_cache) THEN
        RAISE EXCEPTION 'Auditoría fallida después de DELETE.';
    END IF;

    RAISE NOTICE
        'Pruebas de sincronización secuenciales superadas; no son pruebas concurrentes.';
END;
$$;

ROLLBACK TO SAVEPOINT pruebas_sincronizacion;
RELEASE SAVEPOINT pruebas_sincronizacion;

-- ============================================================
-- 9. Auditoría y equivalencia después de deshacer las pruebas
-- ============================================================

SELECT *
FROM pg_temp.tp6_auditoria_cache
ORDER BY id_pedido, id_producto;

SELECT *
FROM pg_temp.tp6_diferencias_top
ORDER BY sentido, categoria;

SELECT *
FROM pg_temp.tp6_diferencias_filas
ORDER BY sentido, id_pedido, id_producto;

SELECT pg_temp.fn_tp6_assert_equivalencia('después de ROLLBACK TO SAVEPOINT');

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_temp.tp6_auditoria_cache) THEN
        RAISE EXCEPTION
            'Auditoría completa fallida después de las pruebas.';
    END IF;

    IF EXISTS (SELECT 1 FROM pg_temp.tp6_diferencias_top) THEN
        RAISE EXCEPTION
            'EXCEPT bidireccional detectó resultados diferentes.';
    END IF;

    RAISE NOTICE
        'Auditoría completa y EXCEPT bidireccional: resultados vacíos.';
END;
$$;

-- ============================================================
-- 10. Medición comparable después de cargar e indexar
-- ============================================================
-- Ambas consultas ven las mismas filas y estadísticas.
-- La carga inicial genera versiones de filas y puede afectar
-- visibilidad/index-only scans: no representa una tabla ya aspirada.
-- No se ejecuta VACUUM dentro de esta transacción.
-- Se informa este límite al interpretar los resultados.

ANALYZE public.pedido;
ANALYZE public.producto;
ANALYZE public.categoria;
ANALYZE public.detalle_pedido;

-- Resultados y calentamiento previo de ambos recorridos.
SELECT categoria, total_vendido
FROM pg_temp.tp6_top_normalizado
ORDER BY total_vendido DESC;

SELECT categoria, total_vendido
FROM pg_temp.tp6_top_cache
ORDER BY total_vendido DESC;

-- Ronda 1: normalizada, luego desnormalizada.
\echo 'Ronda 1 — consulta normalizada'

EXPLAIN (ANALYZE, BUFFERS)
SELECT categoria, total_vendido
FROM pg_temp.tp6_top_normalizado
ORDER BY total_vendido DESC;

\echo 'Ronda 1 — consulta desnormalizada'

EXPLAIN (ANALYZE, BUFFERS)
SELECT categoria, total_vendido
FROM pg_temp.tp6_top_cache
ORDER BY total_vendido DESC;

-- Ronda 2: orden inverso.
\echo 'Ronda 2 — consulta desnormalizada'

EXPLAIN (ANALYZE, BUFFERS)
SELECT categoria, total_vendido
FROM pg_temp.tp6_top_cache
ORDER BY total_vendido DESC;

\echo 'Ronda 2 — consulta normalizada'

EXPLAIN (ANALYZE, BUFFERS)
SELECT categoria, total_vendido
FROM pg_temp.tp6_top_normalizado
ORDER BY total_vendido DESC;

-- No se adjudica una mejora antes de observar tiempos y buffers.
-- Las evidencias históricas sin eliminado se conservan como antecedentes.
-- Sus tiempos y planes no son resultados del script corregido.
-- La comparación directa necesita nuevas mediciones bajo el mismo estado.
--
-- Resultados históricos sin filtros: antecedentes, no aserciones ni
-- resultados medidos de esta versión corregida:
-- Bebidas  5589534.40
-- Pizzas   5215387.22

-- ============================================================
-- 11. Descartar estructura, sincronización y cambios de prueba
-- ============================================================

ROLLBACK;
