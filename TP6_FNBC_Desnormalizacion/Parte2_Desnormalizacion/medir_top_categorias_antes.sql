-- TP6 Parte 2: medición normalizada corregida, antes de las copias cache.
-- Contiene DDL transaccional: requiere respaldo previo fuera del repositorio.
-- Ejecutar completo solo con autorización específica; no deja cambios persistidos.
-- Los tiempos de evidencias históricas sin filtros no validan este script.
\set ON_ERROR_STOP on

BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;

DO $$
DECLARE
    v_tabla TEXT;
BEGIN
    IF current_database() <> 'foodstore_copia_trabajo' THEN
        RAISE EXCEPTION
            'Base no permitida: %. Conectarse a foodstore_copia_trabajo.',
            current_database();
    END IF;
    IF current_setting('session_replication_role') <> 'origin' THEN
        RAISE EXCEPTION 'La prueba requiere session_replication_role = origin.';
    END IF;
    FOREACH v_tabla IN ARRAY ARRAY['pedido', 'detalle_pedido', 'producto', 'categoria']
    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM pg_catalog.pg_class AS c
            JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
            WHERE n.nspname = 'public' AND c.relname = v_tabla
              AND c.relkind = 'r' AND NOT c.relrowsecurity
        ) THEN
            RAISE EXCEPTION 'public.% debe existir como tabla ordinaria sin RLS.', v_tabla;
        END IF;
    END LOOP;
END;
$$;

-- Ensayo de laboratorio: NOWAIT aborta ante bloqueos incompatibles.
-- ACCESS EXCLUSIVE impide lecturas y escrituras hasta ROLLBACK.
LOCK TABLE public.categoria, public.pedido, public.producto, public.detalle_pedido
IN ACCESS EXCLUSIVE MODE NOWAIT;

DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_catalog.pg_attribute
        WHERE NOT attisdropped
          AND ((attrelid IN ('public.pedido'::regclass, 'public.detalle_pedido'::regclass)
                AND attname = 'eliminado')
            OR (attrelid = 'public.detalle_pedido'::regclass
                AND attname IN ('fecha_hora_pedido_cache', 'id_categoria_cache', 'pedido_eliminado_cache')))
    ) THEN
        RAISE EXCEPTION 'Ya existe una columna reservada para el ensayo TP6. No reutilizar ni sobrescribir.';
    END IF;
    IF EXISTS (
        SELECT 1 FROM pg_catalog.pg_proc AS p
        JOIN pg_catalog.pg_namespace AS n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.proname IN ('fn_tp6_sync_detalle_cache', 'fn_tp6_propagar_fecha_cache',
                           'fn_tp6_propagar_categoria_cache')
    ) OR EXISTS (
        SELECT 1 FROM pg_catalog.pg_class AS c
        JOIN pg_catalog.pg_namespace AS n ON n.oid = c.relnamespace
        WHERE n.nspname = 'public' AND c.relname = 'idx_tp6_detalle_fecha_cache'
    ) OR EXISTS (
        SELECT 1 FROM pg_catalog.pg_constraint
        WHERE conrelid = 'public.detalle_pedido'::regclass
          AND conname = 'fk_tp6_detalle_categoria_cache'
    ) OR EXISTS (
        SELECT 1 FROM pg_catalog.pg_trigger
        WHERE tgrelid IN ('public.pedido'::regclass, 'public.detalle_pedido'::regclass,
                          'public.producto'::regclass)
          AND (tgname IN ('zz_tp6_sync_detalle_cache', 'trg_tp6_propagar_fecha_cache',
                          'trg_tp6_propagar_categoria_cache')
               OR (NOT tgisinternal AND tgenabled <> 'O'))
    ) THEN
        RAISE EXCEPTION 'Hay objetos TP6 existentes o triggers incompatibles. Revisar antes de continuar.';
    END IF;
END;
$$;

ALTER TABLE public.pedido
    ADD COLUMN eliminado BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE public.detalle_pedido
    ADD COLUMN eliminado BOOLEAN NOT NULL DEFAULT FALSE;

-- Fecha histórica reproducible: 2026-06-25 en America/Buenos_Aires.
-- Sustituye CURRENT_DATE porque la carga no contiene pedidos de hoy.
-- Los atributos eliminado se agregan solo dentro de esta transacción.
-- No se agregan filtros por estado comercial ni por activo.
-- Esta referencia previa al cache no sustituye la comparación directa
-- de ambas consultas bajo el mismo estado en el ensayo principal.

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
  AND dp.eliminado = FALSE AND ped.eliminado = FALSE
GROUP BY c.nombre
ORDER BY total_vendido DESC
LIMIT 5;

EXPLAIN (ANALYZE, BUFFERS)
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
  AND dp.eliminado = FALSE AND ped.eliminado = FALSE
GROUP BY c.nombre
ORDER BY total_vendido DESC
LIMIT 5;

ROLLBACK;
