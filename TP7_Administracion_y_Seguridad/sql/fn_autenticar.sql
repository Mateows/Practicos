-- ============================================================================
-- TP7 — Clase 2: fn_autenticar (reconstrucción punto de partida)
-- Proyecto: FoodStore — Base de Datos II (UTN FRM)
-- Archivo: TP7_Administracion_y_Seguridad/sql/fn_autenticar.sql
-- Base de destino: foodstore_dev (NO ejecutar sobre foodstore_copia_trabajo)
-- Motor: PostgreSQL 16+ (compatible con 17)
-- ============================================================================
-- CONTEXTO:
--   Las funciones fn_autenticar / fn_resetear_password no existen en el
--   repositorio (TP1–TP6) ni en foodstore_dev (verificado 2026-10-14:
--   0 funciones en public en ambas bases). Se reconstruyen aquí como paso
--   previo obligatorio ("El caso de Food Store: punto de partida" del TP).
--
-- COMPATIBILIDAD DE ESQUEMA (decisión validada por el equipo):
--   Se mantiene el esquema real del repo
--   (TP5_Indices_Vistas/Parte_B_Vistas/usuarios.sql):
--     usuario(id, nombre, apellido, mail, celular, contrasena, rol,
--             eliminado, created_at)
--   En esta función "password_hash" == columna "contrasena".
--   La variante alternativa (id_usuario, email, password_hash, fecha_alta,
--   activo) se rechazó porque rompería vistas.sql, roles.sql §5 y Kiro RF-03.
--
-- SEGURIDAD:
--   - pgcrypto (crypt/gen_salt, blowfish) para verificación de hash.
--   - SECURITY DEFINER + SET search_path para ejecución controlada.
--   - REVOKE ALL FROM PUBLIC: el acceso se otorga solo vía roles.sql §8
--     (EXECUTE a rol_app_escritura y admin_datos, resto NINGUNO).
--   - No devuelve el hash; devuelve el id o NULL (no distingue
--     usuario-inexistente de password-incorrecta para no enumerar cuentas).
--   - Respeta baja lógica: usuarios con eliminado = TRUE nunca autentican.
--
-- IDEMPOTENCIA: CREATE EXTENSION IF NOT EXISTS + CREATE OR REPLACE.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION public.fn_autenticar(
    p_email    VARCHAR,
    p_password VARCHAR
)
RETURNS BIGINT
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $func$
DECLARE
    v_id BIGINT;
BEGIN
    -- Entradas vacías o nulas: fallo genérico sin revelar causa.
    IF p_email IS NULL OR p_password IS NULL
       OR btrim(p_email) = '' OR btrim(p_password) = '' THEN
        RETURN NULL;
    END IF;

    SELECT u.id INTO v_id
    FROM public.usuario AS u
    WHERE u.mail = btrim(p_email)
      AND u.eliminado = FALSE
      AND u.contrasena = crypt(p_password, u.contrasena)
    LIMIT 1;

    IF FOUND THEN
        RETURN v_id;
    END IF;

    RETURN NULL;
END;
$func$;

COMMENT ON FUNCTION public.fn_autenticar(VARCHAR, VARCHAR) IS
'TP7 Clase 2: autentica contra usuario(mail, contrasena hash bcrypt). '
'Devuelve id del usuario activo o NULL. SECURITY DEFINER; EXECUTE vía roles.sql §8.';

-- Mínimo privilegio desde la creación (roles.sql §8 lo reafirma).
REVOKE ALL ON FUNCTION public.fn_autenticar(VARCHAR, VARCHAR) FROM PUBLIC;
