-- ============================================================================
-- TRABAJO PRÁCTICO N.º 1 - BASE DE DATOS I (UTN - FRM)
-- PROYECTO INTEGRADOR: FOOD STORE (Semana 1)
-- Archivo: schema.sql
-- Carrera: Tecnicatura Universitaria en Programación (Comisión: 1PRO4)
-- Integrantes del Grupo:
--   • Lucas Avila
--   • Amanda Pagano
--   • Mateo Lautaro Liendo
-- Motor: PostgreSQL 14+
-- Descripción: Creación de tipos ENUM, tablas, claves primarias, claves foráneas,
--              restricciones declarativas (CHECK, UNIQUE, NOT NULL, DEFAULT),
--              índices optimizados para cargas de trabajo y dataset de verificación.
-- ============================================================================

-- Limpieza preventiva de esquema previo (ejecutable de forma idempotente)
DROP TABLE IF EXISTS detalle_pedido CASCADE;
DROP TABLE IF EXISTS pedido CASCADE;
DROP TABLE IF EXISTS producto CASCADE;
DROP TABLE IF EXISTS cliente CASCADE;
DROP TABLE IF EXISTS categoria CASCADE;

DROP TYPE IF EXISTS forma_pago_enum CASCADE;
DROP TYPE IF EXISTS estado_pedido_enum CASCADE;

-- ============================================================================
-- 1. CREACIÓN DE TIPOS ENUMERADOS (DOMINIOS CERRADOS)
-- ============================================================================

-- Formas de pago aceptadas en el comercio (según planilla y reglas de negocio)
CREATE TYPE forma_pago_enum AS ENUM (
    'EFECTIVO',
    'TARJETA',
    'TRANSFERENCIA'
);

-- Estados del ciclo de vida de un pedido
CREATE TYPE estado_pedido_enum AS ENUM (
    'PENDIENTE',
    'EN_PREPARACION',
    'ENTREGADO',
    'CANCELADO'
);

-- ============================================================================
-- 2. CREACIÓN DE TABLAS Y RESTRICCIONES DECLARATIVAS
-- ============================================================================

-- ----------------------------------------------------------------------------
-- TABLA: categoria
-- Agrupación de productos (ej. Pizzas, Bebidas, Empanadas)
-- ----------------------------------------------------------------------------
CREATE TABLE categoria (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre VARCHAR(50) NOT NULL UNIQUE,
    descripcion TEXT NULL,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- Restricción CHECK: el nombre no puede ser una cadena vacía
    CONSTRAINT chk_categoria_nombre_no_vacio CHECK (trim(nombre) <> '')
);

COMMENT ON TABLE categoria IS 'Categorías de agrupación de productos del menú.';
COMMENT ON COLUMN categoria.id IS 'Identificador numérico autogenerado (PK).';
COMMENT ON COLUMN categoria.nombre IS 'Nombre único de la categoría.';
COMMENT ON COLUMN categoria.activo IS 'Bandera de baja lógica para preservar integridad histórica (R7).';

-- ----------------------------------------------------------------------------
-- TABLA: cliente
-- Clientes registrados en la plataforma
-- ----------------------------------------------------------------------------
CREATE TABLE cliente (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre_completo VARCHAR(100) NOT NULL,
    email VARCHAR(150) NOT NULL UNIQUE,
    telefono VARCHAR(30) NULL,
    direccion VARCHAR(200) NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- Restricciones CHECK
    CONSTRAINT chk_cliente_nombre_no_vacio CHECK (trim(nombre_completo) <> ''),
    -- Validación básica de formato de correo electrónico
    CONSTRAINT chk_cliente_email_valido CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

COMMENT ON TABLE cliente IS 'Información de clientes registrados para realizar pedidos.';
COMMENT ON COLUMN cliente.email IS 'Correo electrónico único que identifica al cliente (R6).';

-- ----------------------------------------------------------------------------
-- TABLA: producto
-- Bienes comercializados por el negocio
-- ----------------------------------------------------------------------------
CREATE TABLE producto (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_categoria BIGINT NOT NULL,
    nombre VARCHAR(100) NOT NULL,
    descripcion TEXT NULL,
    precio_lista NUMERIC(10, 2) NOT NULL,
    stock INTEGER NOT NULL DEFAULT 0,
    activo BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),

    -- Clave foránea hacia categoria
    -- Se utiliza ON DELETE RESTRICT para impedir la eliminación física de categorías
    -- que tengan productos asociados, asegurando la política de baja lógica (R7).
    CONSTRAINT fk_producto_categoria FOREIGN KEY (id_categoria)
        REFERENCES categoria (id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    -- Restricciones CHECK para cumplir la regla R5 (stock y precio no negativos)
    CONSTRAINT chk_producto_precio_positivo CHECK (precio_lista >= 0.00),
    CONSTRAINT chk_producto_stock_no_negativo CHECK (stock >= 0),
    CONSTRAINT chk_producto_nombre_no_vacio CHECK (trim(nombre) <> '')
);

COMMENT ON TABLE producto IS 'Catálogo de productos a la venta.';
COMMENT ON COLUMN producto.precio_lista IS 'Precio actual de lista del producto (no negativo, R5).';
COMMENT ON COLUMN producto.stock IS 'Cantidad disponible en stock (no negativo, R5).';
COMMENT ON COLUMN producto.activo IS 'Marca de baja lógica (R7).';

-- ----------------------------------------------------------------------------
-- TABLA: pedido
-- Encabezado de la transacción u orden de compra
-- ----------------------------------------------------------------------------
CREATE TABLE pedido (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_cliente BIGINT NOT NULL,
    fecha_hora TIMESTAMPTZ NOT NULL DEFAULT now(),
    forma_pago forma_pago_enum NOT NULL,
    estado estado_pedido_enum NOT NULL DEFAULT 'PENDIENTE',
    observaciones TEXT NULL,

    -- Clave foránea hacia cliente
    -- ON DELETE RESTRICT evita que un cliente con historial de pedidos sea borrado físicamente.
    CONSTRAINT fk_pedido_cliente FOREIGN KEY (id_cliente)
        REFERENCES cliente (id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

COMMENT ON TABLE pedido IS 'Cabecera de pedidos realizados por los clientes.';
COMMENT ON COLUMN pedido.id_cliente IS 'Cliente que realizó el pedido (Participación Total, R2).';
COMMENT ON COLUMN pedido.forma_pago IS 'Medio de pago utilizado (EFECTIVO, TARJETA, TRANSFERENCIA).';

-- ----------------------------------------------------------------------------
-- TABLA: detalle_pedido
-- Entidad asociativa (relación N:M entre Pedido y Producto)
-- ----------------------------------------------------------------------------
CREATE TABLE detalle_pedido (
    id_pedido BIGINT NOT NULL,
    id_producto BIGINT NOT NULL,
    cantidad INTEGER NOT NULL,
    precio_unitario NUMERIC(10, 2) NOT NULL,
    -- Columna generada que calcula el subtotal de la línea de forma garantizada y consistente
    subtotal NUMERIC(10, 2) GENERATED ALWAYS AS (cantidad * precio_unitario) STORED,

    -- Clave primaria compuesta: garantiza que un producto no se repita en el mismo pedido
    CONSTRAINT pk_detalle_pedido PRIMARY KEY (id_pedido, id_producto),

    -- Claves foráneas con integridad referencial controlada
    CONSTRAINT fk_detalle_pedido_pedido FOREIGN KEY (id_pedido)
        REFERENCES pedido (id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_detalle_pedido_producto FOREIGN KEY (id_producto)
        REFERENCES producto (id)
        ON DELETE RESTRICT -- Impide borrar productos que figuren en ventas históricas (R7)
        ON UPDATE CASCADE,

    -- Restricciones CHECK
    CONSTRAINT chk_detalle_cantidad_positiva CHECK (cantidad > 0),
    CONSTRAINT chk_detalle_precio_unitario_positivo CHECK (precio_unitario >= 0.00)
);

COMMENT ON TABLE detalle_pedido IS 'Líneas de detalle de cada producto incluido en un pedido.';
COMMENT ON COLUMN detalle_pedido.precio_unitario IS 'Precio unitario histórico congelado al momento de la venta (R4).';
COMMENT ON COLUMN detalle_pedido.cantidad IS 'Cantidad de unidades vendidas (debe ser mayor a 0).';
COMMENT ON COLUMN detalle_pedido.subtotal IS 'Monto total de la línea (calculado automáticamente y almacenado).';

-- ============================================================================
-- 3. ÍNDICES DE RENDIMIENTO (OPTIMIZACIÓN DE CONSULTAS)
-- ============================================================================

-- Índice 1: Optimiza la búsqueda de pedidos por cliente (consultas de historial y perfil)
-- Justificación: Es la consulta más frecuente en aplicaciones de delivery ("Mis Pedidos" o atención al cliente).
CREATE INDEX idx_pedidos_cliente_id ON pedido (id_cliente);

-- Índice 2: Optimiza el listado de productos activos filtrados por categoría (catálogo/menú)
-- Justificación: Acelera la renderización del menú de venta donde se filtran solo productos vigentes por rubro.
CREATE INDEX idx_productos_categoria_activo ON producto (id_categoria, activo) WHERE activo = TRUE;

-- Índice 3: Optimiza los reportes de ventas y recaudación agrupados por producto
-- Justificación: Acelera consultas analíticas de volumen de venta por producto en la tabla intermedia.
CREATE INDEX idx_detalle_pedido_producto_id ON detalle_pedido (id_producto);

-- ============================================================================
-- 4. VERIFICACIÓN Y POBLADO DE PRUEBA (DATASET DE LA PLANILLA ORIGINAL)
-- ============================================================================

-- Inserción de Categorías
INSERT INTO categoria (nombre, descripcion) VALUES
('Pizzas', 'Pizzas artesanales al horno de barro'),
('Bebidas', 'Gaseosas, jugos y aguas');

-- Inserción de Clientes
INSERT INTO cliente (nombre_completo, email, telefono, direccion) VALUES
('Ana Gómez', 'ana.gomez@example.com', '261-4567890', 'Av. San Martín 1234, Mendoza'),
('Luis Paz', 'luis.paz@example.com', '261-7890123', 'Calle Belgrano 456, Godoy Cruz'),
('Marta Ruiz', 'marta.ruiz@example.com', '261-1234567', 'Calle Las Heras 789, Ciudad');

-- Inserción de Productos (Precios de lista vigentes)
INSERT INTO producto (id_categoria, nombre, precio_lista, stock) VALUES
(1, 'Muzzarella', 1050.00, 50),
(1, 'Napolitana', 1500.00, 35),
(2, 'Coca 1.5L', 800.00, 100);

-- Inserción de Pedidos (con fechas históricas de la planilla)
INSERT INTO pedido (id_cliente, fecha_hora, forma_pago, estado) VALUES
(1, '2026-03-01 20:30:00-03', 'EFECTIVO', 'ENTREGADO'),       -- Pedido ID 1 (Ana Gómez)
(2, '2026-03-01 21:15:00-03', 'TARJETA', 'ENTREGADO'),        -- Pedido ID 2 (Luis Paz)
(1, '2026-03-05 21:00:00-03', 'TRANSFERENCIA', 'ENTREGADO'),  -- Pedido ID 3 (Ana Gómez)
(3, '2026-03-06 20:45:00-03', 'EFECTIVO', 'ENTREGADO'),       -- Pedido ID 4 (Marta Ruiz)
(2, '2026-03-07 22:00:00-03', 'TARJETA', 'ENTREGADO');        -- Pedido ID 5 (Luis Paz)

-- Inserción de Detalles de Pedidos (con precios congelados al momento de facturar)
INSERT INTO detalle_pedido (id_pedido, id_producto, cantidad, precio_unitario) VALUES
-- Pedido 1: Ana Gómez (01/03/2026) -> Muzzarella $1000 x 2, Coca 1.5L $800 x 1
(1, 1, 2, 1000.00),
(1, 3, 1, 800.00),
-- Pedido 2: Luis Paz (01/03/2026) -> Napolitana $1500 x 1
(2, 2, 1, 1500.00),
-- Pedido 3: Ana Gómez (05/03/2026) -> Muzzarella $1050 x 3 (Demuestra cambio de precio en R4)
(3, 1, 3, 1050.00),
-- Pedido 4: Marta Ruiz (06/03/2026) -> Coca 1.5L $800 x 4, Napolitana $1500 x 2
(4, 3, 4, 800.00),
(4, 2, 2, 1500.00),
-- Pedido 5: Luis Paz (07/03/2026) -> Muzzarella $1050 x 1
(5, 1, 1, 1050.00);

-- ============================================================================
-- 5. CONSULTA DE VERIFICACIÓN (RECONSTRUCCIÓN DE LA PLANILLA ORIGINAL)
-- ============================================================================
/*
SELECT 
    p.id AS nro_pedido,
    to_char(p.fecha_hora, 'DD/MM/YYYY') AS fecha,
    c.nombre_completo AS cliente,
    pr.nombre AS producto,
    cat.nombre AS categoria,
    dp.precio_unitario,
    dp.cantidad AS cant,
    dp.subtotal,
    p.forma_pago
FROM pedido p
JOIN cliente c ON p.id_cliente = c.id
JOIN detalle_pedido dp ON p.id = dp.id_pedido
JOIN producto pr ON dp.id_producto = pr.id
JOIN categoria cat ON pr.id_categoria = cat.id
ORDER BY p.id, pr.nombre;
*/
