-- TP Unidad 4 — Parte 1: FNBC en control de lotes.
-- Exclusivamente para foodstore_copia_trabajo.
-- Requisito previo: respaldo de la copia antes de ejecutar DDL.
-- Script de validación: todos los cambios se descartan al finalizar.
-- Ejecutar completo mediante psql.

\set ON_ERROR_STOP on

BEGIN;

-- ============================================================
-- 1. Comprobaciones previas
-- ============================================================
-- No crea ni cambia la conexión.
-- Rechaza otra base, la ausencia de usuario o cualquier objeto
-- previo cuyos nombres se utilizarían en esta propuesta.

DO $$
DECLARE
    v_nombre TEXT;
    v_usuario_oid OID;
BEGIN
    IF current_database() <> 'foodstore_copia_trabajo' THEN
        RAISE EXCEPTION
            'Base no permitida: %. Conectarse a foodstore_copia_trabajo.',
            current_database();
    END IF;

    SELECT c.oid
      INTO v_usuario_oid
      FROM pg_catalog.pg_class AS c
      JOIN pg_catalog.pg_namespace AS n
        ON n.oid = c.relnamespace
     WHERE n.nspname = 'public'
       AND c.relname = 'usuario'
       AND c.relkind IN ('r', 'p');

    IF v_usuario_oid IS NULL THEN
        RAISE EXCEPTION
            'No existe la tabla public.usuario de TP5. Revisar el esquema antes de continuar.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
          FROM pg_catalog.pg_attribute AS a
         WHERE a.attrelid = v_usuario_oid
           AND a.attname = 'id'
           AND NOT a.attisdropped
           AND a.atttypid = 'pg_catalog.int8'::regtype
           AND a.attidentity = 'a'
    ) THEN
        RAISE EXCEPTION
            'public.usuario.id no coincide con BIGINT GENERATED ALWAYS AS IDENTITY esperado.';
    END IF;

    SELECT c.relname
      INTO v_nombre
      FROM pg_catalog.pg_class AS c
      JOIN pg_catalog.pg_namespace AS n
        ON n.oid = c.relnamespace
     WHERE n.nspname = 'public'
       AND c.relname IN (
           'lote',
           'deposito',
           'control_lote_almacen',
           'responsable_deposito',
           'control_lote',
           'v_control_lote_almacen'
       )
     ORDER BY c.relname
     LIMIT 1;

    IF v_nombre IS NOT NULL THEN
        RAISE EXCEPTION
            'Ya existe public.%. Se detiene la prueba para no reutilizar ni sobrescribir objetos existentes.',
            v_nombre;
    END IF;
END;
$$;

-- Evita escrituras concurrentes en usuario durante la comprobación
-- de conflictos y la inserción. El bloqueo se libera al finalizar
-- la transacción. NOWAIT detiene la prueba si no puede obtenerlo.

LOCK TABLE public.usuario
    IN SHARE ROW EXCLUSIVE MODE NOWAIT;

-- ============================================================
-- 2. Comprobar conflictos de los usuarios de ejemplo
-- ============================================================
-- No se reutilizan ni actualizan usuarios existentes.
-- La comparación de correo es deliberadamente conservadora:
-- ignora diferencias de mayúsculas y espacios en los extremos.

DO $$
BEGIN
    IF EXISTS (
        SELECT 1
          FROM public.usuario
         WHERE id IN (801, 802)
    ) THEN
        RAISE EXCEPTION
            'Conflicto: ya existe un usuario con ID 801 o 802. No se insertarán los usuarios de prueba.';
    END IF;

    IF EXISTS (
        SELECT 1
          FROM public.usuario
         WHERE lower(btrim(mail)) IN (
             'responsable801.fnbc@example.invalid',
             'responsable802.fnbc@example.invalid'
         )
    ) THEN
        RAISE EXCEPTION
            'Conflicto: ya existe un correo reservado para esta prueba. No se reutilizará el usuario existente.';
    END IF;
END;
$$;

-- ============================================================
-- 3. Tablas maestras mínimas y relación original
-- ============================================================

CREATE TABLE public.lote (
    id BIGINT PRIMARY KEY
);

CREATE TABLE public.deposito (
    id BIGINT PRIMARY KEY
);

CREATE TABLE public.control_lote_almacen (
    lote_id BIGINT NOT NULL,
    deposito_id BIGINT NOT NULL,
    responsable_control_id BIGINT NOT NULL,

    CONSTRAINT pk_control_lote_almacen
        PRIMARY KEY (lote_id, deposito_id),

    CONSTRAINT fk_cla_lote
        FOREIGN KEY (lote_id)
        REFERENCES public.lote (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_cla_deposito
        FOREIGN KEY (deposito_id)
        REFERENCES public.deposito (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_cla_responsable
        FOREIGN KEY (responsable_control_id)
        REFERENCES public.usuario (id)
        ON DELETE RESTRICT
);

-- La PK garantiza (lote_id, deposito_id) → responsable_control_id.
-- Las tres FK no garantizan responsable_control_id → deposito_id.

-- ============================================================
-- 4. Datos maestros y usuarios de prueba
-- ============================================================

INSERT INTO public.lote (id)
VALUES (501), (502), (503);

INSERT INTO public.deposito (id)
VALUES (30), (31);

-- OVERRIDING SYSTEM VALUE permite indicar IDs explícitos
-- en usuario.id GENERATED ALWAYS AS IDENTITY.
--
-- Los valores de contrasena son MARCADORES DE HASH DE PRUEBA:
-- no son hashes válidos ni credenciales utilizables.
-- Se incluyen únicamente para satisfacer el esquema de TP5.
-- No se modifica ni reajusta la secuencia identity.

INSERT INTO public.usuario (
    id,
    nombre,
    apellido,
    mail,
    celular,
    contrasena,
    rol,
    eliminado
)
OVERRIDING SYSTEM VALUE
VALUES
(
    801,
    'Responsable',
    'Prueba801',
    'responsable801.fnbc@example.invalid',
    NULL,
    'MARCADOR_HASH_PRUEBA_NO_VALIDO_801',
    'USUARIO',
    FALSE
),
(
    802,
    'Responsable',
    'Prueba802',
    'responsable802.fnbc@example.invalid',
    NULL,
    'MARCADOR_HASH_PRUEBA_NO_VALIDO_802',
    'USUARIO',
    FALSE
);

-- ============================================================
-- 5. Instancia original
-- ============================================================

INSERT INTO public.control_lote_almacen (
    lote_id,
    deposito_id,
    responsable_control_id
)
VALUES
    (501, 30, 801),
    (502, 30, 801),
    (503, 31, 802);

-- ============================================================
-- 6. Validación de la dependencia antes de migrar
-- ============================================================
-- Cada responsable debe aparecer asociado a un único depósito.
-- No se exige que cada depósito tenga un único responsable.

DO $$
BEGIN
    IF EXISTS (
        SELECT responsable_control_id
          FROM public.control_lote_almacen
         GROUP BY responsable_control_id
        HAVING COUNT(DISTINCT deposito_id) > 1
    ) THEN
        RAISE EXCEPTION
            'La relación original viola responsable_control_id → deposito_id. Migración abortada.';
    END IF;
END;
$$;

-- ============================================================
-- 7. Relaciones descompuestas
-- ============================================================
-- responsable_deposito registra únicamente responsables
-- de control; no impone pertenencia a todos los usuarios.

CREATE TABLE public.responsable_deposito (
    responsable_control_id BIGINT NOT NULL,
    deposito_id BIGINT NOT NULL,

    CONSTRAINT pk_responsable_deposito
        PRIMARY KEY (responsable_control_id),

    CONSTRAINT fk_rd_responsable
        FOREIGN KEY (responsable_control_id)
        REFERENCES public.usuario (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_rd_deposito
        FOREIGN KEY (deposito_id)
        REFERENCES public.deposito (id)
        ON DELETE RESTRICT
);

CREATE TABLE public.control_lote (
    lote_id BIGINT NOT NULL,
    responsable_control_id BIGINT NOT NULL,

    CONSTRAINT pk_control_lote
        PRIMARY KEY (lote_id, responsable_control_id),

    CONSTRAINT fk_cl_lote
        FOREIGN KEY (lote_id)
        REFERENCES public.lote (id)
        ON DELETE RESTRICT,

    CONSTRAINT fk_cl_responsable_deposito
        FOREIGN KEY (responsable_control_id)
        REFERENCES public.responsable_deposito (responsable_control_id)
        ON DELETE RESTRICT
);

-- Descomposición sin pérdida:
-- el atributo común es responsable_control_id y determina
-- toda la relación responsable_deposito.
--
-- LIMITACIÓN DE PRESERVACIÓN:
-- estas PK/FK no preservan localmente
-- (lote_id, deposito_id) → responsable_control_id.
-- Dos responsables del mismo depósito podrían quedar asignados
-- al mismo lote en control_lote.
-- No se implementan triggers ni controles adicionales aquí.

-- ============================================================
-- 8. Migración mediante proyecciones de la relación original
-- ============================================================

INSERT INTO public.responsable_deposito (
    responsable_control_id,
    deposito_id
)
SELECT DISTINCT
    responsable_control_id,
    deposito_id
FROM public.control_lote_almacen;

INSERT INTO public.control_lote (
    lote_id,
    responsable_control_id
)
SELECT DISTINCT
    lote_id,
    responsable_control_id
FROM public.control_lote_almacen;

-- ============================================================
-- 9. Reconstrucción mediante JOIN por el atributo común
-- ============================================================

CREATE VIEW public.v_control_lote_almacen (
    lote_id,
    deposito_id,
    responsable_control_id
) AS
SELECT
    cl.lote_id,
    rd.deposito_id,
    cl.responsable_control_id
FROM public.control_lote AS cl
JOIN public.responsable_deposito AS rd
  ON rd.responsable_control_id = cl.responsable_control_id;

-- ============================================================
-- 10. Verificación de equivalencia en ambos sentidos
-- ============================================================
-- Esta consulta debe devolver cero filas.

SELECT
    'original_menos_reconstruida' AS sentido,
    diferencia.lote_id,
    diferencia.deposito_id,
    diferencia.responsable_control_id
FROM (
    SELECT lote_id, deposito_id, responsable_control_id
    FROM public.control_lote_almacen
    EXCEPT
    SELECT lote_id, deposito_id, responsable_control_id
    FROM public.v_control_lote_almacen
) AS diferencia

UNION ALL

SELECT
    'reconstruida_menos_original' AS sentido,
    diferencia.lote_id,
    diferencia.deposito_id,
    diferencia.responsable_control_id
FROM (
    SELECT lote_id, deposito_id, responsable_control_id
    FROM public.v_control_lote_almacen
    EXCEPT
    SELECT lote_id, deposito_id, responsable_control_id
    FROM public.control_lote_almacen
) AS diferencia

ORDER BY sentido, lote_id, deposito_id, responsable_control_id;

-- Aserción: falla si cualquiera de las diferencias es no vacía.
-- Se compara también la cantidad de filas para detectar
-- multiplicidades que EXCEPT, por sí solo, elimina.

DO $$
BEGIN
    IF EXISTS (
        SELECT lote_id, deposito_id, responsable_control_id
        FROM public.control_lote_almacen
        EXCEPT
        SELECT lote_id, deposito_id, responsable_control_id
        FROM public.v_control_lote_almacen
    ) OR EXISTS (
        SELECT lote_id, deposito_id, responsable_control_id
        FROM public.v_control_lote_almacen
        EXCEPT
        SELECT lote_id, deposito_id, responsable_control_id
        FROM public.control_lote_almacen
    ) THEN
        RAISE EXCEPTION
            'Falló la equivalencia: existen diferencias entre la relación original y la reconstruida.';
    END IF;

    IF (SELECT COUNT(*) FROM public.control_lote_almacen)
       <> (SELECT COUNT(*) FROM public.v_control_lote_almacen)
    THEN
        RAISE EXCEPTION
            'Falló la equivalencia: las cantidades de filas son diferentes.';
    END IF;

    RAISE NOTICE
        'Equivalencia verificada: ambas diferencias son vacías y los conteos coinciden.';
END;
$$;

-- Conteos esperados:
-- original: 3; responsable_deposito: 2;
-- control_lote: 3; reconstruida: 3.

SELECT
    (SELECT COUNT(*) FROM public.control_lote_almacen)
        AS filas_originales,
    (SELECT COUNT(*) FROM public.responsable_deposito)
        AS filas_responsable_deposito,
    (SELECT COUNT(*) FROM public.control_lote)
        AS filas_control_lote,
    (SELECT COUNT(*) FROM public.v_control_lote_almacen)
        AS filas_reconstruidas;

-- Filas esperadas:
-- (501, 30, 801)
-- (502, 30, 801)
-- (503, 31, 802)

SELECT
    lote_id,
    deposito_id,
    responsable_control_id
FROM public.v_control_lote_almacen
ORDER BY lote_id, deposito_id, responsable_control_id;

-- ============================================================
-- 11. Descartar toda la prueba
-- ============================================================

ROLLBACK;
