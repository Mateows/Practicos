---
inclusion: always
---

# FoodStore — Convenciones del Esquema

## Nomenclatura de tablas y columnas

- Los nombres de tabla son **en minúscula y en singular**, sin prefijos:
  `categoria`, `cliente`, `producto`, `pedido`, `detalle_pedido`
- Los nombres de columna son en **minúscula con guión bajo** (snake_case):
  `id_categoria`, `nombre_completo`, `precio_lista`, `fecha_hora`
- Las claves foráneas siguen el patrón `id_<tabla_referenciada>`:
  `id_categoria`, `id_cliente`, `id_pedido`, `id_producto`

## Claves primarias

- Todas las tablas principales usan `BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY` con nombre de columna `id`.
- La excepción es `detalle_pedido`, cuya PK es compuesta: `(id_pedido, id_producto)`.

## Borrado lógico

El sistema **nunca borra físicamente** registros que tengan o puedan tener dependencias históricas. El borrado se implementa con una columna booleana:

```sql
activo BOOLEAN NOT NULL DEFAULT TRUE
```

Tablas que implementan borrado lógico: `categoria`, `producto`.

Las claves foráneas usan `ON DELETE RESTRICT` para reforzar esta política (impiden el borrado físico desde la base de datos).

## Tipos ENUM

Dos dominios cerrados definen los valores posibles para columnas de estado:

```sql
-- Formas de pago aceptadas
CREATE TYPE forma_pago_enum AS ENUM (
    'EFECTIVO',
    'TARJETA',
    'TRANSFERENCIA'
);

-- Ciclo de vida de un pedido
CREATE TYPE estado_pedido_enum AS ENUM (
    'PENDIENTE',
    'EN_PREPARACION',
    'ENTREGADO',
    'CANCELADO'
);
```

Al agregar nuevas consultas o migraciones, usar siempre estos tipos en lugar de `VARCHAR` libre.

## Timestamps

- Todas las tablas principales incluyen `created_at TIMESTAMPTZ NOT NULL DEFAULT now()`.
- La tabla `pedido` usa `fecha_hora TIMESTAMPTZ NOT NULL DEFAULT now()` como timestamp de la transacción.
- Siempre usar `TIMESTAMPTZ` (con zona horaria) en lugar de `TIMESTAMP`.

## Constraints

- **CHECK**: validar que strings no sean vacíos con `trim(campo) <> ''`, precios y stocks no negativos.
- **UNIQUE**: email del cliente, nombre de categoría.
- **NOT NULL**: aplicar por defecto salvo campos opcionales explícitos (`descripcion`, `telefono`, `direccion`, `observaciones`).

## Índices

Los índices del esquema responden a tres patrones de consulta:

1. `idx_pedidos_cliente_id` — historial de pedidos por cliente.
2. `idx_productos_categoria_activo` — listado de productos activos por categoría (índice parcial).
3. `idx_detalle_pedido_producto_id` — reportes de ventas agrupados por producto.

Al crear nuevos índices, documentar la justificación de la consulta que optimizan.
