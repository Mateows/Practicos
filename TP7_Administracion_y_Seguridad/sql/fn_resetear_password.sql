-- ============================================================================
-- TP7 — Clase 2: fn_resetear_password (reconstrucción punto de partida)
-- Proyecto: FoodStore — Base de Datos II (UTN FRM)
-- Archivo: TP7_Administracion_y_Seguridad/sql/fn_resetear_password.sql
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
--   p_id_usuario == columna "id"; p_nueva_password se guarda como hash
--   bcrypt en "contrasena" ("password_hash" del enunciado).
--
-- SEGURIDAD:
--   - pgcrypto crypt/gen_salt('bf') para el nuevo hash (nunca texto plano).
--   - SECURITY DEFINER + SET search_path para ejecución controlada.
--   - REVOKE ALL FROM PUBLIC: el acceso se otorga solo vía roles.sql §8
--     (EXECUTE a rol_soporte y admin_datos, resto NINGUNO).
--   - Política mínima de password: longitud >= 8 tras trim (los CHECK del
--     repo solo exigen no-vacío; este mínimo es decisión TP7 documentada).
--   - Respeta baja lógica: no resetea usuarios con eliminado = TRUE
--     (devuelve FALSE); el alta/baja la gestiona rol_soporte vía
--     UPDATE(eliminado) según Kiro RF-03.
--
-- IDEMPOTENCIA: CREATE EXTENSION IF NOT EXISTS + CREATE OR REPLACE.
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE OR REPLACE FUNCTION public.fn_resetear_password(
    p_id_usuario     BIGINT,
    p_nueva_password VARCHAR
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $func$
DECLARE
    v_actualizadas INTEGER;
BEGIN
    -- Validación mínima (decisión TP7): password de al menos 8 caracteres.
    IF p_id_usuario IS NULL
       OR p_nueva_password IS NULL
       OR char_length(btrim(p_nueva_password)) < 8 THEN
        RETURN FALSE;
    END IF;

    UPDATE public.usuario AS u
    SET contrasena = crypt(btrim(p_nueva_password), gen_salt('bf'))
    WHERE u.id = p_id_usuario
      AND u.eliminado = FALSE;

    GET DIAGNOSTICS v_actualizadas = ROW_COUNT;

    RETURN (v_actualizadas = 1);
END;
$func$;

COMMENT ON FUNCTION public.fn_resetear_password(BIGINT, VARCHAR) IS
'TP7 Clase 2: resetea el hash bcrypt de usuario.contrasena para un usuario '
'activo. Devuelve TRUE si actualizó 1 fila. SECURITY DEFINER; EXECUTE vía roles.sql §8.';

-- Mínimo privilegio desde la creación (roles.sql §8 lo reafirma).
REVOKE ALL ON FUNCTION public.fn_resetear_password(BIGINT, VARCHAR) FROM PUBLIC;
