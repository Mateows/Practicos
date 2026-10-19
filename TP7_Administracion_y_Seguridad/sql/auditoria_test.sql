-- ============================================================================
-- TP7 — Parte B punto 2: secuencia de operaciones de prueba para auditoría
-- Proyecto: FoodStore — Base de Datos II (UTN FRM)
-- Archivo: TP7_Administracion_y_Seguridad/sql/auditoria_test.sql
-- Base de destino: foodstore_dev (NO ejecutar sobre foodstore_copia_trabajo)
-- Motor: PostgreSQL 17 (log_statement = 'all', ver Punto B.1)
-- ============================================================================
-- SECUENCIA (mínimo pedido por la consigna):
--   1. Lectura (SELECT) con columnas permitidas.
--   2. Inserción (INSERT) de prueba en categoria.
--   3. Actualización (UPDATE) sobre ese mismo registro.
--   4a. Llamada fallida a fn_autenticar (retorna NULL, sin error).
--   4b. Intento REAL de conexión fallida a nivel de motor: se ejecuta desde
--       shell con password erróneo (fuera de este archivo), para que el log
--       nativo capture FATAL: password authentication failed + connection.
--
-- LIMPIEZA: los puntos 2-3 corren en transacción con ROLLBACK final, por lo
-- que foodstore_dev no conserva el registro de prueba. Las marcas INICIO/FIN
-- delimitan el fragmento a extraer del log en docs/log_auditoria_prueba.txt.
-- Columnas reales del esquema: id, nombre, mail, contrasena, eliminado.
-- Idempotente y re-ejecutable (el INSERT vive solo dentro de la transacción).
-- ============================================================================

-- Marca de inicio del fragmento de log (log_statement='all' la registra).
SELECT 'AUDITORIA_TEST_INICIO_B2' AS marca, clock_timestamp() AS ts;

-- 1. Lectura: usuarios activos con columnas permitidas (sin contrasena).
SELECT id, nombre, mail
FROM usuario
WHERE eliminado = FALSE
ORDER BY id
LIMIT 3;

-- 2 + 3. Inserción y actualización de prueba, revertidas al final.
BEGIN;

INSERT INTO categoria (nombre, descripcion)
VALUES ('AuditoriaTestB2', 'Categoria de prueba B.2, revertida con ROLLBACK')
RETURNING id;

UPDATE categoria
SET descripcion = 'Categoria de prueba B.2, actualizada y luego revertida'
WHERE nombre = 'AuditoriaTestB2'
RETURNING id;

ROLLBACK;

-- 4a. Inicio de sesión fallido vía función (password erróneo -> NULL).
SELECT fn_autenticar('admin@foodstore.com', 'clave_erronea_test') AS login_fallido;

-- Marca de fin del fragmento de log.
SELECT 'AUDITORIA_TEST_FIN_B2' AS marca, clock_timestamp() AS ts;
