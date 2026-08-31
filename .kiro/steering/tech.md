---
inclusion: always
---

# FoodStore — Stack Tecnológico

## Motor de base de datos

- **PostgreSQL 17** (el schema fue escrito para PostgreSQL 14+ y es compatible con 17).
- No hay backend de aplicación todavía; toda la lógica reside en la capa de base de datos.

## Definición del esquema

El esquema completo (tipos ENUM, tablas, constraints, índices y dataset de prueba) está en:

```
TP1_FoodStore/schema.sql
```

#[[file:TP1_FoodStore/schema.sql]]

## Características de PostgreSQL utilizadas

| Característica | Uso en el proyecto |
|---|---|
| `BIGINT GENERATED ALWAYS AS IDENTITY` | PKs autoincremental en todas las tablas principales |
| `CREATE TYPE ... AS ENUM` | Dominios cerrados para `forma_pago_enum` y `estado_pedido_enum` |
| `NUMERIC(10, 2)` GENERATED ALWAYS AS (...) STORED | Columna `subtotal` calculada en `detalle_pedido` |
| `TIMESTAMPTZ` | Fechas con zona horaria en `created_at` y `fecha_hora` |
| `ON DELETE RESTRICT` / `ON DELETE CASCADE` | Política de integridad referencial declarativa |
| Índices parciales (`WHERE activo = TRUE`) | Optimización del catálogo de productos activos |

## Convenciones de escritura SQL

- Palabras reservadas de SQL en **MAYÚSCULAS**.
- Nombres de objetos (tablas, columnas, constraints, índices) en **minúsculas con guión bajo**.
- Los nombres de constraints siguen el patrón: `<tipo>_<tabla>_<descripcion>` (ej. `chk_producto_precio_positivo`, `fk_detalle_pedido_pedido`).
- Se usan `COMMENT ON TABLE` y `COMMENT ON COLUMN` para documentar el propósito de cada objeto.
