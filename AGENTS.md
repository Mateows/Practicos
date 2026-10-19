# Instrucciones para agentes — Base de Datos II (UTN FRM)

## Repositorio

Proyecto académico PostgreSQL: FoodStore.

- [TP1](TP1_FoodStore/README.md): modelado, normalización y esquema base.
- [TP2](TP2_Concurrencia_IA/README.md): integridad, transacciones y concurrencia.
- [TP3](TP3_Optimizacion/DUIA_COMPLETA.md): carga masiva y optimización.
- [TP4](TP4_Reportes_Analiticos/DUIA_TP4.md): reportes analíticos y lectura crítica.
- [TP5](TP5_Indices_Vistas/README.md): índices, vistas y vista materializada.
- [TP6](TP6_FNBC_Desnormalizacion/README.md): FNBC y desnormalización controlada.

Consultar el [README general](README.md), el [informe integrador](Informe_General.md) y el [protocolo de seguridad](protocolo_seguridad.md).

## Autorización y alcance

El agente puede leer archivos, analizar y presentar propuestas sin modificarlos.

Cada modificación requiere autorización explícita del grupo y debe limitarse a los archivos, operaciones y alcance aprobados. La autorización para una tarea no habilita cambios adicionales ni correcciones de entregas anteriores.

No ejecutar SQL, conectarse a PostgreSQL, crear, restaurar, borrar o recrear bases, realizar git add, commit o push sin autorización específica para esas operaciones. Aprobar el contenido de un script o su guardado no autoriza ejecutarlo.

No ejecutar pruebas sobre foodstore_dev. No borrar ni recrear automáticamente una copia de trabajo ante un error.

Antes de una operación autorizada, revisar su origen, destino, requisitos y respaldo. Ante conflictos de nombres u objetos, detenerse e informar; no sobrescribir ni reutilizar silenciosamente.

## Seguridad y estado de las bases

Seguir el [protocolo de seguridad](protocolo_seguridad.md).

- Las validaciones de DDL/DML transaccional utilizan BEGIN y terminan con ROLLBACK.
- COMMIT requiere autorización explícita: un resultado correcto no constituye autorización.
- Respaldar antes de DDL; conservar los respaldos nuevos fechados fuera del repositorio.
- CREATE DATABASE y DROP DATABASE no se ejecutan dentro de una transacción y requieren autorización específica.
- Revisar los scripts históricos antes de ejecutarlos: algunos contienen COMMIT.

Los scripts y las decisiones históricas no son un inventario de objetos instalados actualmente. No asumir que las distintas bases o copias tienen el mismo esquema, datos, índices o triggers.

Los scripts actuales de TP6 comprueban foodstore_copia_trabajo como destino. No ejecutarlos sobre otra base ni cambiar esa comprobación sin autorización. Sus implementaciones se validaron con ROLLBACK y no quedaron persistidas.

## Convenciones del esquema documentado

Fuentes: [schema.sql de TP1](TP1_FoodStore/schema.sql) y [usuario de TP5](TP5_Indices_Vistas/Parte_B_Vistas/usuarios.sql).

- producto y categoria usan activo para baja lógica.
- usuario usa eliminado.
- En schema.sql de TP1, pedido y detalle_pedido no tienen activo ni eliminado; ese esquema se conserva. TP6 Parte 2 incorpora eliminado BOOLEAN NOT NULL DEFAULT FALSE en ambas tablas únicamente dentro de sus ensayos transaccionales, como estados propios independientes. La consulta normalizada filtra dp.eliminado = FALSE AND ped.eliminado = FALSE; la desnormalizada filtra dp.eliminado = FALSE AND dp.pedido_eliminado_cache = FALSE. El cache copia exclusivamente el estado del pedido y no modifica el eliminado propio del detalle. Los ensayos terminan con ROLLBACK; estas adiciones no describen un esquema instalado permanentemente. No equiparar CANCELADO con eliminado.
- La FK detalle_pedido.id_pedido → pedido.id usa ON DELETE CASCADE.
- Las FK producto → categoria, pedido → cliente y detalle_pedido → producto usan ON DELETE RESTRICT.
- detalle_pedido.subtotal es GENERATED ALWAYS AS (cantidad * precio_unitario) STORED.
- Usar los nombres reales id_pedido, id_producto, id_categoria y fecha_hora.

Estas convenciones describen los archivos revisados; no reemplazan una comprobación autorizada del esquema instalado.

## Evidencias y comunicación

Conservar las evidencias históricas intactas. Distinguir resultados medidos, decisiones, pruebas pendientes y cambios persistidos.

En TP6, la concurrencia entre sesiones no fue probada y el costo adicional de escritura no fue cuantificado. No presentar las pruebas secuenciales como concurrentes ni extrapolar tiempos a otras cargas.

Antes de ampliar el alcance, presentar la propuesta al grupo y esperar autorización.
