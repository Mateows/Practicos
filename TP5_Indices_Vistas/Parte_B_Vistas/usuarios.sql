-- TP5 - Extension de seguridad para vistas
-- Compatible con el esquema heredado de TP1-TP4.
-- La columna contrasena representa un hash, nunca una contrasena en claro.

DO $$
BEGIN
    CREATE TYPE rol_usuario AS ENUM ('ADMIN', 'VENDEDOR', 'USUARIO');
EXCEPTION
    WHEN duplicate_object THEN NULL;
END
$$;

CREATE TABLE IF NOT EXISTS usuario (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(80) NOT NULL,
    apellido VARCHAR(80) NOT NULL,
    mail VARCHAR(120) NOT NULL UNIQUE,
    celular VARCHAR(30),
    contrasena VARCHAR(255) NOT NULL,
    rol rol_usuario NOT NULL DEFAULT 'USUARIO',
    eliminado BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_usuario_nombre_no_vacio CHECK (trim(nombre) <> ''),
    CONSTRAINT chk_usuario_apellido_no_vacio CHECK (trim(apellido) <> ''),
    CONSTRAINT chk_usuario_mail_no_vacio CHECK (trim(mail) <> ''),
    CONSTRAINT chk_usuario_contrasena_no_vacia CHECK (trim(contrasena) <> '')
);

COMMENT ON TABLE usuario IS 'Usuarios de acceso; contrasena debe almacenarse como hash.';
COMMENT ON COLUMN usuario.contrasena IS 'Hash de contrasena, no texto plano.';
