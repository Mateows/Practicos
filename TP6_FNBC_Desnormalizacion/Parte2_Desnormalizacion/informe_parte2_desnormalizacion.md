# TP6 — FNBC y desnormalización controlada
## Parte 2 — Top diario de categorías

**Estado de la corrección:** las evidencias del 09/10/2026 registran la ejecución de ambos scripts corregidos con el borrado lógico exigido por el profesor, las pruebas secuenciales, las comprobaciones de auditoría y equivalencia y el cierre con ROLLBACK. Las evidencias y capturas del 08/10/2026 permanecen intactas como antecedentes de la versión sin filtros de borrado lógico. Las pruebas concurrentes y la cuantificación del costo adicional de escritura siguen pendientes. Las capturas de la ejecución corregida ya están incorporadas y enlazadas en la sección 11; los resultados nuevos también se documentan mediante los logs de texto.

### 1. Objetivo y adaptación a FoodStore

La consigna solicita mostrar el top cinco de categorías por monto vendido en el día, con actualización frecuente y datos disponibles en tiempo real.

La consulta normalizada se adaptó a los nombres reales del esquema:

| Nombre de la consigna | Nombre en FoodStore |
|---|---|
| `dp.producto_id` | `dp.id_producto` |
| `dp.pedido_id` | `dp.id_pedido` |
| `pr.categoria_id` | `pr.id_categoria` |
| `ped.fecha` | `ped.fecha_hora`, de tipo TIMESTAMPTZ |

Se utilizó el **25 de junio de 2026**, en la zona horaria **America/Buenos_Aires**, como fecha histórica reproducible. Sustituye a `CURRENT_DATE` porque la carga no contiene pedidos de hoy. El filtro utiliza un intervalo semiabierto: incluye las 00:00 del día elegido y excluye las 00:00 del día siguiente.

Se conservan `SUM(dp.subtotal)`, `GROUP BY c.nombre`, orden descendente por monto y `LIMIT 5`. La versión histórica omitió los filtros porque el esquema documentado no tenía esos atributos. Conforme a la aclaración del profesor, la versión corregida incorpora dentro del ensayo `pedido.eliminado` y `detalle_pedido.eliminado`, ambos `BOOLEAN NOT NULL DEFAULT FALSE`, sin modificar los esquemas de TP anteriores. Son estados propios e independientes: se inicializan como no eliminados, sin inferirlos de otro dato. La consulta normalizada exige `dp.eliminado = FALSE AND ped.eliminado = FALSE`; la desnormalizada exige `dp.eliminado = FALSE AND dp.pedido_eliminado_cache = FALSE`, sin volver a unir pedido. No se agregan filtros por estado ni por `activo`; `CANCELADO` no se interpreta como eliminado.

### 2. Volumen y alcance del ensayo

La carga histórica de la copia de trabajo se documentó con estos volúmenes; no constituyen una comprobación actual:

| Tabla | Filas |
|---|---:|
| pedido | 200005 |
| detalle_pedido | 499571 |
| producto | 50003 |
| categoria | 2 |

El límite de cinco se conserva, pero el resultado tiene solo dos categorías. Por ello, el ensayo permite evaluar los recorridos sobre pedidos, detalles y productos, aunque no representa un escenario con muchas categorías ni permite evaluar ampliamente la selección de un top cinco entre numerosos grupos.

La comprobación previa de la copia informó 5132 detalles cuya cantidad supera el stock actual y ningún trigger de usuario instalado en pedido, detalle_pedido o producto. Los scripts de TP2 presentes en el repositorio no equivalen a triggers instalados en esta base. La adaptación no corrige cantidades ni stock y no instala esas reglas anteriores.

### 3. Medición inicial corregida y antecedente histórico

La evidencia `evidencia_top_antes_logico_20261009_092704.txt` registra la medición normalizada corregida antes de incorporar las copias redundantes:

- **Execution Time:** 62.538 ms.
- **Buffers:** `shared hit=8455`.
- `Parallel Seq Scan` sobre pedido con el filtro `NOT eliminado` y el intervalo diario.
- Búsqueda por la PK de detalle_pedido con su filtro `NOT eliminado`.
- 1539 búsquedas de producto.
- Cierre con **ROLLBACK**.

`medir_top_categorias_antes.sql` incorpora los dos atributos propios dentro de `BEGIN`; el ensayo contiene DDL y requiere respaldo y autorización de ejecución. Los **62.538 ms** son una referencia previa al cache, no la base del cálculo de mejora de la comparación directa.

**Antecedente del 08/10/2026 — sin filtros de borrado lógico.**

La evidencia `evidencia_top_antes_20261008_225517.txt` registra:

- **Execution Time:** 47.151 ms.
- **Buffers:** `shared hit=8455`.
- Recorrido `Parallel Seq Scan` sobre pedido.
- Búsquedas mediante `Nested Loop` hacia detalle_pedido y producto.
- 1539 búsquedas en producto, con 4617 buffers compartidos encontrados en caché.

Esta medición permitió identificar los recorridos que se buscaba evitar. Se conserva como referencia histórica; no se utiliza para calcular la mejora de la comparación histórica directa ni como resultado del script corregido.

### 4. Justificación del patrón elegido

Se eligieron columnas precalculadas con disparadores porque el plan inicial mostraba un recorrido de pedido y búsquedas repetidas en producto que podían evitarse copiando sus atributos de consulta al detalle; además, la sincronización dentro de la misma transacción permite mantener los datos vigentes al confirmar cada escritura, sin esperar un refresco periódico. Una vista materializada con actualización nocturna no satisface el requisito de actualización frecuente, y un refresco frecuente exigiría aceptar y medir una demora entre cambios y consultas. La adaptación es reversible porque conserva los atributos originales y permite retirar únicamente las columnas, el índice y los mecanismos de sincronización añadidos.

### 5. Estructura redundante y sincronización

El script corregido agrega los atributos propios indicados y estas copias redundantes a detalle_pedido:

| Columna | Tipo | Fuente original |
|---|---|---|
| fecha_hora_pedido_cache | TIMESTAMPTZ | pedido.fecha_hora |
| id_categoria_cache | BIGINT | producto.id_categoria |
| pedido_eliminado_cache | BOOLEAN | pedido.eliminado |

Las tres copias son obligatorias después de la carga inicial. La categoría copiada tiene una FK hacia categoria. Se conserva el índice `idx_tp6_detalle_fecha_cache` sobre fecha_hora_pedido_cache, sin convertirlo en índice parcial ni agregar otro índice.

Las copias representan los valores actuales de las tablas originales, no datos históricos congelados. Se conserva subtotal, que ya es generado como cantidad por precio unitario. El nombre de categoría no se copia: la consulta mantiene un JOIN con categoria para mostrar su nombre vigente.

Los disparadores funcionan de la siguiente manera:

- **BEFORE INSERT OR UPDATE de detalle:** obtiene la fecha y el estado eliminado del pedido y la categoría del producto; recalcula las tres copias, incluso si se intenta escribir un valor arbitrario en ellas. No asigna el atributo propio `detalle_pedido.eliminado`.
- **AFTER UPDATE de pedido:** cuando cambia fecha_hora o eliminado, propaga ambos datos redundantes a todos sus detalles, incluidos los eliminados individualmente. Conserva los nombres `fn_tp6_propagar_fecha_cache` y `trg_tp6_propagar_fecha_cache`, aclarando su alcance ampliado en comentarios.
- **AFTER UPDATE de producto:** cuando cambia id_categoria, propaga la nueva categoría a sus detalles.

El borrado lógico no elimina filas: modificar `pedido.eliminado` solo propaga su copia y nunca modifica `detalle_pedido.eliminado`. Restaurar el pedido deja eliminados los detalles dados de baja individualmente; restaurar un detalle bajo un pedido eliminado tampoco lo hace visible. El DELETE físico conserva su comportamiento anterior: eliminar un detalle elimina sus copias, y eliminar un pedido conserva el CASCADE existente. Cambiar el nombre de una categoría no requiere propagación porque se consulta mediante JOIN.

La carga inicial histórica completó dos columnas para **499571 detalles**. La evidencia corregida `evidencia_top_desnormalizacion_logico_20261009_092837.txt` registra **UPDATE 499571** durante la carga de las tres copias, seguido del establecimiento de restricciones y la creación del índice. Las comprobaciones de conflicto rechazan las nuevas columnas y los objetos reservados, sin reutilizarlos ni sobrescribirlos silenciosamente.

### 6. Condiciones de comparación

En ambos ensayos, histórico y corregido, las consultas se midieron después de completar la carga inicial, crear el índice y ejecutar ANALYZE. La evidencia corregida registra consultas previas para calentar ambos recorridos y dos rondas con orden alternado:

1. Normalizada y luego desnormalizada.
2. Desnormalizada y luego normalizada.

Las vistas temporales utilizadas para repetir las consultas son vistas normales que el planificador expande; no son vistas materializadas ni almacenan resultados precalculados.

### 7. Resultados corregidos de rendimiento y antecedentes

La evidencia `evidencia_top_desnormalizacion_logico_20261009_092837.txt` registra:

| Medición | Normalizada: tiempo (ms) | Desnormalizada: tiempo (ms) | Normalizada: shared hit | Desnormalizada: shared hit |
|---|---:|---:|---:|---:|
| Ronda 1 | 49.291 | 1.980 | 10942 | 565 |
| Ronda 2 | 47.556 | 1.323 | 10942 | 565 |
| Promedio | 48.4235 | 1.6515 | 10942 | 565 |

El cociente entre los promedios corregidos es aproximadamente **29.32**. La reducción de tiempo observada es **96.59 %** y la de accesos a buffers compartidos es **94.84 %**. Se calculan exclusivamente con las dos rondas corregidas: `48.4235 / 1.6515`, `100 × (1 − 1.6515 / 48.4235)` y `100 × (1 − 565 / 10942)`, respectivamente.

Estos resultados corresponden al conjunto de **tres copias redundantes más índice, con filtros de borrado lógico**; no separan el aporte individual de cada componente. Los 62.538 ms de la medición inicial corregida y los tiempos históricos no intervienen en estos cálculos.

**Antecedentes del 08/10/2026 — sin filtros de borrado lógico.**

La evidencia `evidencia_top_desnormalizacion_20261008_232126.txt` registra:

| Medición | Normalizada: tiempo (ms) | Desnormalizada: tiempo (ms) | Normalizada: shared hit | Desnormalizada: shared hit |
|---|---:|---:|---:|---:|
| Ronda 1 | 42.807 | 1.855 | 10942 | 564 |
| Ronda 2 | 41.920 | 1.815 | 10942 | 564 |
| Promedio | 42.3635 | 1.835 | 10942 | 564 |

| Antes: normalizada | Después: desnormalizada |
|---|---|
| Promedio: 42.3635 ms | Promedio: 1.835 ms |
| shared hit: 10942 | shared hit: 564 |
| Trabajo principal: Parallel Seq Scan de pedido y Nested Loop con búsquedas en detalle/producto | Trabajo principal: Bitmap Heap Scan de detalle mediante el índice de fecha y Nested Loop con categoria |

El cociente entre los tiempos promedio es aproximadamente **23.09**. La reducción del tiempo de ejecución observada es de aproximadamente **95.67 %**, y la reducción de accesos a buffers compartidos es de aproximadamente **94.85 %**.

Estos resultados corresponden al **conjunto histórico de dos columnas redundantes más índice, sin filtros de borrado lógico**. El ensayo no separa el aporte individual de cada componente. Los 47.151 ms iniciales no intervienen en estos cálculos. Los tiempos, promedios y porcentajes de este bloque son antecedentes; los resultados corregidos se presentan por separado y no reutilizan las mediciones históricas.

Los valores `shared hit` representan accesos resueltos en caché compartida; no equivalen a páginas únicas ni a lecturas físicas de disco.

### 8. Interpretación de los planes corregidos e históricos

**Plan corregido normalizado.** Conserva el Parallel Seq Scan sobre pedido, ahora con `NOT eliminado` y el intervalo diario, y las búsquedas por la PK del detalle con su filtro `NOT eliminado`. Procesa 588 pedidos del día y realiza 1539 búsquedas de producto. En ambas rondas, los buffers informados para pedido, detalle y producto son 1472, 4844 y 4617 respectivamente. La incorporación de categoria, la agregación y el ordenamiento siguen el recorrido general histórico.

**Plan corregido desnormalizado.** Utiliza el índice de fecha y un Bitmap Heap Scan del detalle con `NOT eliminado AND NOT pedido_eliminado_cache`, sin unir pedido ni producto. Obtiene 1539 filas visibles y accede a **559 bloques** de tabla. El Bitmap Index Scan informa **1547 candidatos**; esa cifra no representa 1547 detalles elegibles. El plan reutiliza las filas mediante un nodo Materialize y combina con categoria antes de agregar y ordenar. Ese nodo no es una vista materializada.

**Antecedentes del 08/10/2026 — planes sin filtros lógicos.**

**Consulta normalizada.** Mantiene el recorrido secuencial paralelo de pedido para filtrar la fecha. Para los 588 pedidos del día realiza búsquedas por la PK de detalle_pedido y luego 1539 búsquedas por la PK de producto. En ambas rondas, pedido utiliza 1472 buffers, las búsquedas de detalle 4844 y las de producto 4617. Finalmente se incorpora categoria mediante Hash Join y se realiza agregación parcial, Gather Merge y agregación final. El recorrido y las búsquedas repetidas constituyen el trabajo principal; el ordenamiento final procesa solamente dos grupos. Los tiempos de los nodos son inclusivos y no deben sumarse como costos independientes.

**Consulta desnormalizada.** Utiliza Bitmap Index Scan sobre el índice de fecha y Bitmap Heap Scan para obtener los 1539 detalles visibles del día, accediendo a 558 bloques de tabla. Después combina esos detalles con las dos categorías mediante Nested Loop, reutilizando el conjunto de detalles con un nodo Materialize, y realiza GroupAggregate y el ordenamiento final. Ese Materialize es un nodo de ejecución, no una vista materializada. Desaparecen tanto el recorrido de pedido como las búsquedas individuales en producto. El acceso por fecha a detalle_pedido pasa a ser el recorrido principal.

### 9. Equivalencia, auditoría y pruebas ejecutadas

La evidencia corregida `evidencia_top_desnormalizacion_logico_20261009_092837.txt` registra auditoría inicial y posterior con **cero filas**, diferencias del top mediante EXCEPT bidireccional con **cero filas** y diferencias de las filas participantes mediante EXCEPT ALL bidireccional con **cero filas**. Las llamadas a la función temporal de aserciones finalizaron sin error. Ambas consultas corregidas devolvieron **Bebidas: 5589534.40** y **Pizzas: 5215387.22**.

**Antecedentes del 08/10/2026.**

En la versión histórica sin filtros, ambas consultas devolvieron los mismos resultados:

| categoria | total_vendido |
|---|---:|
| Bebidas | 5589534.40 |
| Pizzas | 5215387.22 |

La comparación con EXCEPT en ambos sentidos produjo cero filas. No hubo categorías o montos presentes en un resultado y ausentes en el otro.

La auditoría completa comparó las columnas redundantes de todos los detalles contra pedido.fecha_hora y producto.id_categoria, utilizando `IS DISTINCT FROM`. También verificó la existencia de sus padres y de la categoría copiada. Tanto la auditoría inicial como la posterior a las pruebas devolvieron **cero filas**, y sus aserciones finalizaron sin error.

Las pruebas secuenciales verificaron inserción de detalles, modificación de cantidad y precio, corrección de copias arbitrarias, cambio de pedido y producto asociados, propagación de fecha, propagación de categoría, cambio de nombre de categoría, eliminación directa y eliminación mediante CASCADE del pedido.

Se utilizaron IDs negativos explícitos con `OVERRIDING SYSTEM VALUE`, sin consumir secuencias. Las filas de prueba se deshicieron mediante `ROLLBACK TO SAVEPOINT` antes de medir. La evidencia registra que las pruebas secuenciales fueron superadas; **no fueron pruebas concurrentes**.

**Validación corregida del 09/10/2026.** La auditoría completa amplía la comparación con `pedido_eliminado_cache IS DISTINCT FROM pedido.eliminado`, sin filtrar detalles eliminados ni limitarse al día. El estado propio del detalle se muestra para diagnóstico, pero no se exige que coincida con el del pedido.

Además de conservar la comparación bidireccional del top, incorpora `EXCEPT ALL` bidireccional de las filas participantes del día, incluyendo pedido, producto, categoría y subtotal. Esto verifica pertenencia y multiplicidad sin que `LIMIT 5` o la agregación oculten diferencias. Las aserciones de auditoría, top y filas se integran en las pruebas y se repiten después de deshacerlas.

Las pruebas secuenciales reversibles ejecutadas cubrieron:

- Las cuatro combinaciones de `pedido.eliminado` y `detalle_pedido.eliminado`, con visibilidad solo cuando ambos son FALSE.
- Restauración del pedido sin restaurar detalles eliminados individualmente, y restauración individual del detalle sin modificar al pedido.
- Inserción bajo un pedido eliminado y cambio de pedido con distinto estado lógico, conservando el estado propio del detalle.
- Traslado de un detalle propio vigente desde un pedido eliminado a otro vigente y su retorno: se mantuvo `detalle_pedido.eliminado = FALSE`, se sincronizaron estado redundante, fecha y categoría y se comprobó su presencia o ausencia en ambas vistas de filas del día.
- Cambio simultáneo de fecha y eliminado del pedido, verificando ambas copias.
- Corrección de una escritura arbitraria de `pedido_eliminado_cache` y propagación a varios detalles, incluso los eliminados.
- Integración con las pruebas anteriores de montos, categoría, cambio de padres, DELETE y CASCADE.

La evidencia registra el aviso **«Pruebas de sincronización secuenciales superadas; no son pruebas concurrentes»** y la finalización del bloque sin error. Las comprobaciones directas de estados y visibilidad verificaron la independencia de pedido y detalle, además de la equivalencia entre consultas. Las aserciones de auditoría, top y filas se comprobaron después de cada escritura de prueba. Se utilizaron IDs negativos explícitos; las filas de prueba se descartaron mediante `ROLLBACK TO SAVEPOINT` y liberación del savepoint antes de ANALYZE y las mediciones. Después de deshacerlas se repitieron las aserciones y se mostraron los resultados vacíos de auditoría, EXCEPT del top y EXCEPT ALL de filas. Estas pruebas verifican los casos secuenciales ejecutados; no demuestran corrección ante carreras entre sesiones.

### 10. Costos de escritura y límites

La adaptación aumenta el tamaño de los detalles y agrega búsquedas de padres, bloqueos de filas y mantenimiento del índice durante las escrituras. Cambiar la fecha o el borrado lógico de un pedido, o la categoría de un producto, puede actualizar numerosos detalles, generando más versiones de filas, WAL y trabajo posterior de mantenimiento. El costo de escritura no fue cuantificado históricamente y el costo adicional de esta corrección sigue pendiente.

La sincronización soporta **READ COMMITTED**. Sus funciones rechazan otros niveles cuando se ejecutan. El disparador de detalle toma bloqueos FOR SHARE sobre el pedido y luego sobre el producto para proteger los atributos que copia. Los bloqueos de padres y detalles pueden producir interbloqueos; la transacción abortada deberá reintentarse completa. La corrección ante carreras entre sesiones aún requiere pruebas concurrentes.

La instalación, carga inicial y medición se realizaron dentro de una misma transacción, manteniendo bloqueos ACCESS EXCLUSIVE que impiden escrituras y lecturas concurrentes sobre las tablas bloqueadas. Esto corresponde a un ensayo de laboratorio, no a una instalación en línea.

La carga inicial genera versiones de filas y modifica el estado físico de la tabla. No se ejecutó VACUUM dentro de la transacción. Aunque ambas consultas se compararon bajo el mismo estado y con orden alternado, dos rondas no constituyen un benchmark exhaustivo ni garantizan los mismos tiempos bajo carga concurrente o después de mantenimiento.

Se conserva el orden histórico `ORDER BY total_vendido DESC LIMIT 5`. Si hubiera empates en el límite, no hay desempate determinista y podría variar la selección del top; cualquier cambio simétrico del orden requiere revisión aparte. La comparación completa de filas no depende de ese límite.

### 11. Reversibilidad y cierre

Capturas del ensayo corregido — 09/10/2026:

- [Plan normalizado corregido — ronda 1](capturas/antes_logico_ronda1.png): filtros lógicos, 49.291 ms y shared hit=10942.
- [Plan desnormalizado corregido — ronda 1](capturas/despues_logico_ronda1.png): ambos filtros, 1.980 ms y shared hit=565.
- [Auditoría y equivalencia corregidas](capturas/auditoria_logico.png): pruebas secuenciales superadas, auditoría, top y EXCEPT ALL vacíos; el ROLLBACK visible corresponde a ROLLBACK TO SAVEPOINT.

El **ROLLBACK final** de la transacción está registrado en el [TXT completo del ensayo corregido](evidencias/evidencia_top_desnormalizacion_logico_20261009_092837.txt).

La información original permanece en pedido, producto, categoria y detalle_pedido. En una eventual instalación persistente, retirar únicamente triggers y funciones TP6, índice, FK añadida y las tres columnas cache permitiría volver a la consulta normalizada, conservando ambos atributos propios de borrado lógico. Retirar esos atributos perdería información de bajas lógicas y no forma parte de esa reversión.

El ensayo histórico y ambos scripts corregidos terminaron con **ROLLBACK**, registrado en sus respectivas evidencias. En el ensayo principal corregido, el rollback al savepoint descartó primero las filas de prueba; el rollback final descartó la estructura y sincronización instaladas durante la transacción. No se persistieron los cambios del ensayo.

El grupo informó un postcheck con **cero columnas añadidas**, **200005 pedidos** y **499571 detalles**. Esta comprobación posterior tiene como fuente la información suministrada por el grupo; no está registrada en los dos logs nuevos examinados ni equivale a una verificación independiente del estado actual de PostgreSQL.

Ambos scripts corregidos mantienen `ON_ERROR_STOP` y `ROLLBACK` final. Antes de una ejecución autorizada debe comprobarse el destino `foodstore_copia_trabajo`, procedencia y contenido de la carga, esquema y triggers instalados, conflictos y disponibilidad para los bloqueos exclusivos. No se ejecutan sobre `foodstore_dev` ni se adapta silenciosamente el destino.

Por contener DDL, ambos requieren un respaldo independiente previo, fechado fuera del repositorio, sin sobrescribir anteriores y registrando base, formato y finalización. Generar el respaldo, conectarse o ejecutar SQL requiere autorización específica; aprobar estos archivos no autoriza esas operaciones. Los logs examinados no demuestran por sí solos la existencia, ubicación o integridad del respaldo. Ante un error se descarta la transacción, sin COMMIT ni recreación automática. Las evidencias y capturas anteriores permanecen intactas. Los dos logs corregidos del 09/10/2026 documentan esta ejecución; cualquier nueva ejecución deberá generar sus propias evidencias. Las capturas corregidas están enlazadas en la sección 11. No se modifican TP1–TP5 ni Parte 1 desde este ensayo.
