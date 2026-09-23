# spec: vistas_reportes_food_store

Objetivo: exponer de forma simple y controlada los datos que hoy se
arman a mano con JOINs repetidos en cada reporte: catálogo de
productos vigentes, ventas por cliente, y detalle de pedido con
nombre de producto. Además, exponer los datos de `usuario` sin la
columna de contraseña, para poder otorgar acceso de lectura sin
exponer credenciales.

Vistas requeridas:
1. v_catalogo_productos — productos vigentes (activo = TRUE) con su
   categoría (categoria.activo = TRUE también).
2. v_reporte_ventas_cliente — por cada cliente: cantidad de pedidos
   no cancelados y facturación total.
3. v_detalle_pedido_producto — detalle de pedido (cantidad,
   precio_unitario, subtotal) con el nombre del producto en vez de
   solo su id.
4. v_usuario_publico — todos los datos de usuario excepto
   contrasena, filtrando eliminado = FALSE.
   NOTA DE CORRECCION (23/09, no se borra el texto original): la vista
   omite contrasena (por seguridad) y también eliminado, que se usa
   solo como filtro. Ver vistas.sql y la lista de columnas más abajo.

Restricción de seguridad (punto 4 de la consigna): v_usuario_publico
es la vista que debe poder otorgarse via GRANT sin dar acceso a la
tabla usuario.

Criterio de aceptación: cada vista debe poder correr sin error sobre
el esquema heredado (schema.sql + usuarios.sql), y sus resultados
deben coincidir exactamente con una consulta manual equivalente
escrita de forma independiente (ver
Parte_B_Vistas/verificacion_vistas.sql).
Vista agregada tras una auditoría posterior (cubre el punto 1 de la
consigna de forma literal, ya que v_reporte_ventas_cliente es un
agregado y no una vista plana fila a fila):

5. v_pedido_cliente — pedidos con los datos del cliente, sin agregar
   (fecha_hora, forma_pago, estado, y datos del cliente asociado).

Mismo criterio de aceptación que las anteriores: correr sin error y
coincidir exactamente con una consulta manual (ver
Parte_B_Vistas/verificacion_vistas.sql).

Columnas exactas por vista (agregado en la corrección posterior a la
devolución; la versión original las describía sin enumerarlas):

1. v_catalogo_productos: producto_id, producto, categoria,
   precio_lista, stock. Filtro de vigencia: producto.activo = TRUE y
   categoria.activo = TRUE.
2. v_reporte_ventas_cliente: cliente_id, nombre_completo, pedidos,
   total_facturado. Cuenta solo pedidos no cancelados; los clientes
   sin pedidos aparecen con 0.
3. v_detalle_pedido_producto: id_pedido, id_producto, producto,
   cantidad, precio_unitario, subtotal.
4. v_usuario_publico: id, nombre, apellido, mail, celular, rol,
   created_at. Columna oculta por seguridad: contrasena. Filtro:
   eliminado = FALSE.
5. v_pedido_cliente: pedido_id, fecha_hora, forma_pago, estado,
   cliente_id, nombre_completo, email.