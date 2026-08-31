---
inclusion: always
---

# FoodStore — Descripción del Producto

## Contexto

FoodStore es un proyecto integrador universitario desarrollado para la materia **Base de Datos I** (UTN - FRM, Tecnicatura Universitaria en Programación, Comisión 1PRO4). El equipo está compuesto por Lucas Avila, Amanda Pagano y Mateo Lautaro Liendo.

## Qué es el sistema

FoodStore es un sistema de pedidos tipo **delivery** para un comercio gastronómico. Permite registrar el catálogo de productos organizado por categorías, gestionar clientes, crear pedidos y llevar el detalle de cada venta.

## Dominio principal

El sistema cubre cinco entidades centrales:

- **Categoría** — agrupación de productos del menú (ej. Pizzas, Bebidas, Empanadas).
- **Producto** — artículos a la venta, vinculados a una categoría, con precio de lista y stock.
- **Cliente** — personas registradas que realizan pedidos.
- **Pedido** — cabecera de la transacción: cliente, fecha/hora, forma de pago y estado del ciclo de vida.
- **Detalle de pedido** — líneas de cada pedido, con precio unitario congelado al momento de la venta y subtotal calculado automáticamente.

## Reglas de negocio clave

- **R2** — Todo pedido debe estar asociado a un cliente existente (participación total).
- **R4** — El precio unitario en el detalle se congela al momento de la venta; los cambios futuros en `producto.precio_lista` no lo afectan.
- **R5** — El precio de lista y el stock de un producto nunca pueden ser negativos.
- **R6** — El email del cliente es único y actúa como identificador natural.
- **R7** — El borrado de registros es **lógico**, nunca físico. Las bajas se marcan con la columna `activo = FALSE` para preservar la integridad histórica.
