-- TP5 - Parte B: datos de la tabla usuario.
-- Ejecutar despues de usuarios.sql.
--
-- Admin y Vero ya existian en foodstore_tp3_carga (cargados a mano) y no
-- estaban en ningun script: se versionan aca con los mismos valores para
-- que la base se pueda reconstruir desde el repositorio.
-- El tercer usuario esta dado de baja (eliminado = TRUE) para probar que
-- v_usuario_publico lo filtra.
-- La columna contrasena guarda un hash; estos valores son marcadores de
-- ejemplo, nunca contrasenas en texto plano.
-- Idempotente: ON CONFLICT (mail) DO NOTHING.

INSERT INTO usuario (nombre, apellido, mail, celular, contrasena, rol, eliminado) VALUES
    ('Admin', 'Sistema', 'admin@foodstore.com', '2615000001',
     'hash_ejemplo_no_es_texto_plano_1', 'ADMIN', FALSE),
    ('Vero', 'Reportes', 'vero@foodstore.com', '2615000002',
     'hash_ejemplo_no_es_texto_plano_2', 'VENDEDOR', FALSE),
    ('Baja', 'Prueba', 'baja.prueba@foodstore.com', '2615000003',
     'hash_ejemplo_no_es_texto_plano_3', 'USUARIO', TRUE)
ON CONFLICT (mail) DO NOTHING;