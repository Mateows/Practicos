-- ============================================================================
-- TP7 — Administracion y Seguridad: modelo de roles PostgreSQL
-- Proyecto: FoodStore — Base de Datos II (UTN FRM)
-- Archivo: TP7_Administracion_y_Seguridad/sql/roles.sql
-- Motor: PostgreSQL 16+ (compatible con 17)
-- Base de destino: foodstore_dev (ver SECCION 0)
-- Especificacion estricta:
--   TP7_Administracion_y_Seguridad/docs/kiro_roles_spec/requirements.md
--   TP7_Administracion_y_Seguridad/docs/kiro_roles_spec/design.md
-- ============================================================================
-- PROPOSITO:
--   Implementa la politica de roles de grupo (NOLOGIN) y roles de login (LOGIN)
--   con minimo privilegio, sin usar GRANT ALL en roles operativos.
--
-- PRE-REQUISITOS (orden de ejecucion):
--   1. schema.sql (TP1) + usuarios.sql (TP5 Parte_B_Vistas/usuarios.sql)
--   2. vistas.sql (TP5) + vista_materializada.sql (TP5 Parte_C)
--   3. fn_autenticar y fn_resetear_password (Clases 1 y 2 / TP7).
--      Ver NOTA-FUNCIONES abajo: los GRANT de SECCION 8 son condicionales y
--      emiten NOTICE si las funciones aun no existen.
--
-- NOTA-COLUMNA (password_hash vs contrasena):
--   El enunciado pide excluir "password_hash". La columna real del esquema es
--   usuario.contrasena VARCHAR(255) (TP5_Indices_Vistas/Parte_B_Vistas/
--   usuarios.sql:19; v_usuario_publico la omite por construccion). En este
--   script "password_hash" == "contrasena": rol_soporte NUNCA recibe permisos
--   sobre usuario.contrasena (ver SECCION 5).
--
-- NOTA-FUNCIONES (punto de partida TP7 completado 2026-10-14):
--   fn_autenticar y fn_resetear_password YA existen en foodstore_dev
--   (sql/fn_autenticar.sql, sql/fn_resetear_password.sql, pgcrypto + SECURITY
--   DEFINER, firmas VARCHAR,VARCHAR y BIGINT,VARCHAR). La SECCIÓN 8 usa
--   sentencias directas (sin bloques condicionales ni NOTICEs).
--
-- IDEMPOTENCIA:
--   - CREATE ROLE via DO ... EXCEPTION WHEN duplicate_object THEN NULL.
--   - REVOKE / GRANT / ALTER DEFAULT PRIVILEGES son re-ejecutables.
--   - Re-ejecutar este script no duplica permisos ni falla si los roles ya
--     existen.
--
-- SEGURIDAD OPERATIVA (protocolo_seguridad.md):
--   - Revisar este script antes de ejecutarlo; no ejecutarlo sin autorizacion
--     explicita del grupo. Aprobar el contenido/guardado NO autoriza ejecutarlo.
--   - No probarlo sobre foodstore_dev sin autorizacion; no usar COMMIT implicito
--     como validacion. DDL de roles es a nivel de cluster: verificar
--     current_database() (SECCION 0) y el rol ejecutor (se recomienda
--     superusuario o admin_datos para SECCION 10, ver D6).
--   - Passwords de SECCION 2B son placeholders: gestionar con Vault / variables
--     de entorno, nunca en texto plano en el repositorio (design.md D7 / §11).
-- ============================================================================

-- ============================================================================
-- SECCIÓN 0 — Comprobación de base de destino (assert, design.md §2/§0)
-- Impide ejecución accidental en otra base (p. ej. copias de trabajo TP6).
-- ============================================================================
DO $$
BEGIN
    IF current_database() <> 'foodstore_dev' THEN
        RAISE EXCEPTION
            'roles.sql abortado: base actual=%, se esperaba foodstore_dev. '
            'Revise la conexion antes de continuar.',
            current_database();
    END IF;
END
$$;

-- ============================================================================
-- SECCIÓN 1 — Revocación de permisos inseguros por defecto
-- Requerido por el enunciado (verbatim) + endurecimiento de secuencias y
-- funciones coherente con design.md §3-Sección 1 y §8.
-- REVOKE es idempotente: re-ejecutarlo no falla.
-- ============================================================================
-- 1a. Sentencias exigidas por el enunciado (no remover ni renombrar):
REVOKE ALL ON SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL TABLES IN SCHEMA public FROM PUBLIC;

-- 1b. Endurecimiento complementario (solo revoca de PUBLIC, no de roles TP7):
REVOKE ALL ON ALL SEQUENCES IN SCHEMA public FROM PUBLIC;
REVOKE ALL ON ALL FUNCTIONS IN SCHEMA public FROM PUBLIC;

-- 1c. Revocación explícita sobre objetos conocidos (defensa en profundidad;
--     redundante con 1a/1b pero documenta la superficie cerrada según
--     requirements.md §1: tablas base, secuencias *_id_seq, funciones).
REVOKE ALL ON TABLE
    categoria, cliente, producto, pedido, detalle_pedido, usuario
FROM PUBLIC;
REVOKE ALL ON SEQUENCE
    categoria_id_seq, cliente_id_seq, producto_id_seq,
    pedido_id_seq, usuario_id_seq
FROM PUBLIC;

-- ============================================================================
-- SECCIÓN 2 — Creación idempotente de roles
-- 2A: roles de grupo (NOLOGIN). 2B: roles de login (LOGIN).
-- Se crean TODOS los roles antes de los GRANTs para que el script sea
-- ejecutable en una sola pasada (design.md §§2+11 unificados; los GRANTs de
-- §§4-8 referencian a admin_datos, que debe existir previamente).
-- ============================================================================

-- 2A. Roles de grupo (NOLOGIN)
DO $$ BEGIN CREATE ROLE rol_app_lectura  NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE ROLE rol_app_escritura NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE ROLE rol_soporte      NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE ROLE rol_reportes     NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$;
DO $$ BEGIN CREATE ROLE rol_auditoria    NOLOGIN; EXCEPTION WHEN duplicate_object THEN NULL; END $$;

-- 2B. Roles de login (LOGIN)
-- Passwords: 'CAMBIAR_POR_VAULT' es un placeholder NO productivo usado solo
-- en este entorno local de laboratorio. Por política no se versionan secretos
-- en Git: fuera del laboratorio se gestionan con Vault / variables de entorno
-- y nunca se escriben en texto plano en el repositorio (design.md D7 / §11).
-- CONNECTION LIMIT como defensa en profundidad (design.md D7).
DO $$ BEGIN
    CREATE ROLE app_web LOGIN PASSWORD 'CAMBIAR_POR_VAULT' CONNECTION LIMIT 20;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
    CREATE ROLE admin_datos LOGIN PASSWORD 'CAMBIAR_POR_VAULT' CONNECTION LIMIT 5;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ============================================================================
-- SECCIÓN 3 — Permisos de schema (design.md §3)
-- Todos necesitan USAGE para nombrar objetos. Solo admin_datos recibe CREATE
-- (DDL controlado, requirements.md §2.2); ningun rol operativo recibe CREATE.
-- ============================================================================
GRANT USAGE ON SCHEMA public TO
    rol_app_lectura, rol_app_escritura, rol_soporte,
    rol_reportes, rol_auditoria;

GRANT USAGE ON SCHEMA public TO app_web, admin_datos;

-- DDL controlado: solo admin_datos puede crear objetos en el schema del proyecto.
GRANT CREATE ON SCHEMA public TO admin_datos;

-- ============================================================================
-- SECCIÓN 4 — Permisos de tabla, nivel de tabla (requirements.md RF-01)
-- Granulares: solo SELECT / INSERT, UPDATE. Sin DELETE para rol_app_escritura
-- (baja logica, design.md D1) y sin GRANT ALL en roles operativos.
-- rol_soporte / rol_reportes / rol_auditoria NO reciben permisos de tabla
-- completa (usan columnas §5 o vistas §7).
-- ============================================================================
-- rol_app_lectura: catalogo de negocio, solo lectura (RF-01 fila lectura).
GRANT SELECT ON TABLE
    categoria, cliente, producto, pedido, detalle_pedido
TO rol_app_lectura;

-- rol_app_escritura: operaciones transaccionales sin DELETE (RF-01).
GRANT INSERT, UPDATE ON TABLE
    cliente, pedido, detalle_pedido
TO rol_app_escritura;

-- Catalogo: solo INSERT y UPDATE para mantener productos y categorias (design §4).
GRANT INSERT, UPDATE ON TABLE
    categoria, producto
TO rol_app_escritura;

-- admin_datos: administracion completa (RF-01 fila admin_datos).
-- Es el UNICO rol que recibe ALL sobre tablas; no es un rol operativo.
GRANT ALL ON TABLE
    categoria, cliente, producto, pedido, detalle_pedido, usuario
TO admin_datos;

-- ============================================================================
-- SECCIÓN 5 — Permisos a nivel de columna sobre usuario (requirements.md RF-03)
-- rol_soporte NUNCA recibe SELECT/UPDATE sobre la tabla completa.
-- Solo columnas de identificacion + UPDATE(eliminado) para alta/baja logica.
-- La columna contrasena (= password_hash del enunciado) queda excluida.
-- Se revoca primero cualquier permiso total previo para garantizar el minimo
-- privilegio incluso en re-ejecuciones sobre instalaciones parciales.
-- ============================================================================
REVOKE ALL ON TABLE usuario FROM rol_soporte;

GRANT SELECT (id, nombre, apellido, mail, celular, rol, eliminado, created_at)
    ON TABLE usuario
    TO rol_soporte;

GRANT UPDATE (eliminado)
    ON TABLE usuario
    TO rol_soporte;

-- Verificacion esperada: bajo rol_soporte,
--   SELECT contrasena FROM usuario LIMIT 1;
-- debe fallar con ERROR: permission denied for column contrasena.

-- ============================================================================
-- SECCIÓN 6 — Permisos de secuencia (requirements.md RF-04 + matriz 4.4)
-- rol_app_escritura necesita USAGE, SELECT para reservar IDs al insertar.
-- Se otorgan las 4 secuencias de tablas con INSERT permitido (categoria,
-- cliente, producto, pedido). usuario_id_seq queda excluida (solo admin_datos).
-- detalle_pedido no tiene secuencia (PK compuesta).
-- ============================================================================
GRANT USAGE, SELECT ON SEQUENCE
    cliente_id_seq, pedido_id_seq
TO rol_app_escritura;

-- Necesarias porque §4 otorga INSERT en categoria y producto (design.md §6).
GRANT USAGE, SELECT ON SEQUENCE
    categoria_id_seq, producto_id_seq
TO rol_app_escritura;

-- admin_datos: control total de secuencias (unico ALL sobre secuencias).
GRANT ALL ON SEQUENCE
    categoria_id_seq, cliente_id_seq, producto_id_seq,
    pedido_id_seq, usuario_id_seq
TO admin_datos;

-- Ningun otro rol recibe permisos de secuencia.

-- ============================================================================
-- SECCIÓN 7 — Permisos de vista y vista materializada (requirements.md RF-02)
-- rol_app_lectura: vistas operativas. rol_reportes: vistas de analisis +
-- materializada (v_usuario_publico excluye contrasena por construccion).
-- rol_auditoria: ninguno (solo monitoreo §9).
-- ============================================================================
GRANT SELECT ON
    v_catalogo_productos,
    v_pedido_cliente,
    v_detalle_pedido_producto
TO rol_app_lectura;

GRANT SELECT ON
    v_reporte_ventas_cliente,
    v_usuario_publico,
    mv_resumen_ventas_categoria_mes
TO rol_reportes;

-- admin_datos: administracion total de vistas (unico ALL sobre vistas).
GRANT ALL ON
    v_usuario_publico,
    v_reporte_ventas_cliente,
    v_catalogo_productos,
    v_detalle_pedido_producto,
    v_pedido_cliente,
    mv_resumen_ventas_categoria_mes
TO admin_datos;

-- ============================================================================
-- SECCIÓN 8 — Permisos de ejecución de funciones (requirements.md RF-05)
-- Firmas según design.md §8, existentes en foodstore_dev desde el punto de
-- partida TP7 (sql/fn_autenticar.sql, sql/fn_resetear_password.sql):
--   fn_autenticar(VARCHAR, VARCHAR), fn_resetear_password(BIGINT, VARCHAR).
-- Sentencias directas e idempotentes: todos los objetos existen (verificado
-- 2026-10-14: 6 tablas, 5 vistas, 1 materializada, 5 secuencias, 2 funciones),
-- por lo que la ejecución no emite warnings por objetos inexistentes. Con
-- ON_ERROR_STOP, un cambio futuro de firma detiene el script en lugar de
-- pasar en silencio.
-- Matriz: fn_autenticar -> rol_app_escritura + admin_datos;
--          fn_resetear_password -> rol_soporte + admin_datos; resto NINGUNO.
-- ============================================================================
-- Revocar EXECUTE de PUBLIC en ambas funciones sensibles.
REVOKE ALL ON FUNCTION public.fn_autenticar(VARCHAR, VARCHAR) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.fn_resetear_password(BIGINT, VARCHAR) FROM PUBLIC;

-- fn_autenticar: la llama la aplicacion web en cada login (flujo transaccional).
GRANT EXECUTE ON FUNCTION public.fn_autenticar(VARCHAR, VARCHAR)
    TO rol_app_escritura;

-- fn_resetear_password: la usa soporte para restablecimiento de credenciales.
GRANT EXECUTE ON FUNCTION public.fn_resetear_password(BIGINT, VARCHAR)
    TO rol_soporte;

-- admin_datos puede ejecutar ambas como autoridad de administracion.
GRANT EXECUTE ON FUNCTION
    public.fn_autenticar(VARCHAR, VARCHAR),
    public.fn_resetear_password(BIGINT, VARCHAR)
TO admin_datos;

-- ============================================================================
-- SECCIÓN 9 — Permisos de monitoreo para rol_auditoria (requirements.md RF-06)
-- Solo catalogos y estadisticas del motor. Ningun acceso a datos de negocio.
-- ============================================================================
GRANT pg_monitor TO rol_auditoria;

GRANT SELECT ON ALL TABLES IN SCHEMA information_schema TO rol_auditoria;
GRANT SELECT ON ALL TABLES IN SCHEMA pg_catalog TO rol_auditoria;

-- ============================================================================
-- SECCIÓN 10 — ALTER DEFAULT PRIVILEGES (requirements.md RF-07 + salvedad D6)
-- Las tablas y secuencias futuras heredan la politica de rol_app_lectura y
-- rol_app_escritura sin intervencion manual. Las 3 sentencias RF-07 (planas)
-- aplican a los objetos creados por el rol ejecutor (postgres/superusuario);
-- las 3 variantes FOR ROLE admin_datos cubren la salvedad D6: todo DDL futuro
-- debe ejecutarse como admin_datos según el contrato de mantenimiento.
-- Sin privilegios heredados para soporte/reportes/auditoria.
-- Todas idempotentes; ejecutar este script como superusuario para que ambas
-- series queden registradas.
-- ============================================================================
ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE ON TABLES TO rol_app_escritura;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT SELECT ON TABLES TO rol_app_lectura;

ALTER DEFAULT PRIVILEGES IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO rol_app_escritura;

-- Serie D6: mismos privilegios para objetos futuros creados por admin_datos.
ALTER DEFAULT PRIVILEGES FOR ROLE admin_datos IN SCHEMA public
    GRANT SELECT, INSERT, UPDATE ON TABLES TO rol_app_escritura;

ALTER DEFAULT PRIVILEGES FOR ROLE admin_datos IN SCHEMA public
    GRANT SELECT ON TABLES TO rol_app_lectura;

ALTER DEFAULT PRIVILEGES FOR ROLE admin_datos IN SCHEMA public
    GRANT USAGE, SELECT ON SEQUENCES TO rol_app_escritura;

-- ============================================================================
-- SECCIÓN 11 — Asignación de membresías (design.md §12)
-- app_web hereda lectura + escritura. Sus permisos se administran en los
-- roles de grupo, nunca directamente en app_web.
-- admin_datos no hereda roles de grupo; sus permisos son directos (§§4-8).
-- GRANT role TO login es idempotente (re-ejecutarlo es un no-op).
-- ============================================================================
GRANT rol_app_lectura  TO app_web;
GRANT rol_app_escritura TO app_web;

-- ============================================================================
-- SECCIÓN 12 — Verificación sugerida (solo lectura, design.md §7)
-- Ejecutar manualmente tras aplicar el script, con autorizacion:
--
-- -- 12.1 Permisos de tabla otorgados a los roles de TP7
-- SELECT grantee, table_name, privilege_type
-- FROM information_schema.role_table_grants
-- WHERE grantee IN ('rol_app_lectura','rol_app_escritura','rol_soporte',
--                   'rol_reportes','rol_auditoria','app_web','admin_datos')
-- ORDER BY grantee, table_name, privilege_type;
--
-- -- 12.2 Permisos a nivel de columna sobre usuario
-- SELECT grantee, column_name, privilege_type
-- FROM information_schema.column_privileges
-- WHERE table_name = 'usuario' AND grantee = 'rol_soporte'
-- ORDER BY column_name;
--
-- -- 12.3 Confirmar que rol_soporte no lee contrasena (debe dar ERROR)
-- -- SET ROLE rol_soporte;
-- -- SELECT contrasena FROM usuario LIMIT 1;  -- permission denied esperado
-- -- RESET ROLE;
--
-- -- 12.4 Membresias de app_web
-- SELECT r.rolname AS login_role, m.rolname AS member_of
-- FROM pg_auth_members am
-- JOIN pg_roles r ON r.oid = am.member
-- JOIN pg_roles m ON m.oid = am.roleid
-- WHERE r.rolname = 'app_web';
-- ============================================================================
