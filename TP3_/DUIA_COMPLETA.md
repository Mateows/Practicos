# DUIA COMPLETA - TP3

## Declaracion de Uso de Inteligencia Artificial

**Materia:** Base de Datos II  
**Trabajo practico:** TP3 - Optimizacion y performance de consultas  
**Proyecto:** FoodStore  
**Alumnos:** Mateo Lautaro Liendo, Lucas Avila y Amanda Pagano  
**Comision:** 4  
**Docente:** Sergio Neira  
**Motor objetivo:** PostgreSQL 17  
**Base de trabajo:** `foodstore_tp3_carga`

---

## Indice

1. [Alcance y criterio de integracion](#alcance-y-criterio-de-integracion)
2. [Parte 1 - Carga masiva](#parte-1---carga-masiva)
3. [Parte 2 - Consultas lentas y optimizacion](#parte-2---consultas-lentas-y-optimizacion)
4. [Parte 3 - Lectura critica de planes](#parte-3---lectura-critica-de-planes)
5. [Parte 4 - Consultas bajo especificacion](#parte-4---consultas-bajo-especificacion)
6. [Parte 5 - Competencia de optimizacion](#parte-5---competencia-de-optimizacion)
7. [Inventario completo de archivos](#inventario-completo-de-archivos)
8. [Declaracion final](#declaracion-final)

---

## Alcance y criterio de integracion

Este documento integra visualmente las cinco partes de TP3 en el orden en que fueron realizadas. No reemplaza ni reescribe los archivos de trabajo: cada script SQL, plan de ejecucion y documento se conserva en su ubicacion original y se enlaza desde este documento.

La integracion respeta las decisiones y resultados documentados en cada parte:

- La carga masiva se realiza sobre una base separada y se verifica mediante consultas de solo lectura.
- Las consultas candidatas se analizan con `EXPLAIN ANALYZE` antes y despues de aplicar indices.
- Los costos estimados se distinguen de los tiempos reales de ejecucion.
- Las alternativas SQL de la Parte 4 se comparan por equivalencia de resultados.
- Las propuestas de optimizacion de la Parte 5 se aceptan o descartan con base en mediciones reales.

---

## Parte 1 - Carga masiva

### Objetivo

Poblar el esquema real de FoodStore con un volumen suficiente de datos para realizar mediciones de performance. El script adapta la generacion de registros al esquema existente y carga, como objetivo, 50.000 productos, 20.000 clientes, 200.000 pedidos y entre 1 y 4 lineas por pedido.

### Uso de IA

La IA se utilizo como apoyo para adaptar el script de generacion al esquema real, revisar la distribucion aleatoria de las claves foraneas y proponer una correccion cuando se detectaron subconsultas que podian evaluarse una sola vez para toda la sentencia.

La version final utiliza arreglos construidos con `array_agg` y seleccion por indice aleatorio para que la eleccion de categoria, cliente y producto se realice por fila. Tambien documenta la posibilidad de colisiones de producto dentro de un mismo pedido y utiliza `ON CONFLICT DO NOTHING` para respetar la clave primaria compuesta.

### Criterios aceptados

- Adaptacion de nombres y columnas al esquema FoodStore.
- Uso de `generate_series` para la carga masiva.
- Uso de pools de identificadores mediante arreglos.
- Carga dentro de una transaccion.
- Actualizacion de estadisticas mediante `ANALYZE`.
- Verificacion posterior de cantidades, claves foraneas, precios, duplicados y distribuciones.

### Verificacion

El archivo de verificacion es de solo lectura. Comprueba los conteos esperados, la integridad referencial, los precios negativos, la unicidad de `(id_pedido, id_producto)`, la distribucion de estados y formas de pago, y la distribucion de claves foraneas.

**Archivos originales:**

- [seed_masivo.sql](Parte%201%20-%20Poblar%20la%20base%20masivamente%20con%20datos%20generados%20por%20IA/seed_masivo.sql)
- [verificacion_carga.sql](Parte%201%20-%20Poblar%20la%20base%20masivamente%20con%20datos%20generados%20por%20IA/verificacion_carga.sql)

---

## Parte 2 - Consultas lentas y optimizacion

### Objetivo

Seleccionar consultas representativas, obtener sus planes reales y medir el efecto de indices propuestos sobre el mismo volumen de datos.

### Consultas analizadas

- **Q1:** pedidos pendientes ordenados por fecha, con un limite de 50 filas.
- **Q2:** productos de una categoria dentro de un rango de precio.
- **Q3:** total facturado por cliente en un rango de fechas.

### Uso de IA

La IA se utilizo para identificar nodos costosos de los planes `EXPLAIN ANALYZE` y proponer indices relacionados con filtros, ordenamientos y joins. Las propuestas fueron contrastadas con el planificador y con los tiempos reales, sin aceptar una mejora solamente por la disminucion del costo estimado.

### Resultados documentados

- **Q1:** el indice `(estado, fecha_hora DESC)` permitio pasar de un plan con `Parallel Seq Scan`, `Sort` y `Gather Merge` a un `Index Scan`. El tiempo paso de aproximadamente 33,7 ms a 0,9 ms.
- **Q2:** el indice `(id_categoria, precio_lista)` no produjo una mejora real. El planificador mantuvo un ordenamiento y el tiempo fue levemente mayor.
- **Q3:** los indices sobre `fecha_hora` y `detalle_pedido(id_pedido)` no mejoraron el resultado. El primero elimino el paralelismo del plan original y el segundo no fue elegido por el planificador.

La [tabla comparativa](Parte%202%20-%20Consultas%20lentas,%20EXPLAIN%20y%20optimizacion%20medida/tabla_comparativa.md) conserva los valores de costo, tiempo real, nodos y mejora medidos para cada caso.

**Archivos originales:**

- [queries_candidatas.sql](Parte%202%20-%20Consultas%20lentas,%20EXPLAIN%20y%20optimizacion%20medida/queries_candidatas.sql)
- [indices_propuestos.sql](Parte%202%20-%20Consultas%20lentas,%20EXPLAIN%20y%20optimizacion%20medida/indices_propuestos.sql)
- [tabla_comparativa.md](Parte%202%20-%20Consultas%20lentas,%20EXPLAIN%20y%20optimizacion%20medida/tabla_comparativa.md)
- [Planes de ejecucion](Parte%202%20-%20Consultas%20lentas,%20EXPLAIN%20y%20optimizacion%20medida/planes/)

---

## Parte 3 - Lectura critica de planes

### Objetivo

Revisar afirmaciones generadas por IA a partir de un plan real y determinar, para cada una, si coincide con la evidencia del plan.

### Uso de IA y revision humana

La IA se utilizo como apoyo para interpretar el plan. Cada afirmacion fue comparada con los campos `cost`, `rows`, `actual time`, `actual rows` y `Execution Time` del plan real.

El analisis distingue correctamente entre:

- costo estimado, expresado en unidades internas del planificador;
- filas estimadas y filas realmente procesadas;
- tiempo de cada nodo;
- tiempo total de ejecucion.

La conclusion documentada es que tres afirmaciones eran incorrectas y una era correcta: el tiempo total de ejecucion de 0,908 ms estaba confirmado por la ultima linea del plan.

**Archivo original:**

- [lectura_critica.md](Parte%203%20-%20Lectura%20critica%20de%20planes%20interpretados%20por%20IA/lectura_critica.md)

---

## Parte 4 - Consultas bajo especificacion

### Objetivo

Resolver dos especificaciones SQL y construir una alternativa equivalente para cada una, verificando que ambas versiones produzcan los mismos resultados.

### Especificacion 1

Obtener el monto total vendido por categoria considerando categorias activas y pedidos entregados, agrupando y ordenando por el monto vendido.

- Solucion original: agregacion con joins.
- Alternativa: CTE con ventas agrupadas por categoria.
- Verificacion: cantidad de filas y diferencias mediante `EXCEPT`.

### Especificacion 2

Obtener clientes que realizaron mas de tres pedidos, mostrando nombre completo y email, ordenados alfabeticamente.

- Solucion original: subconsulta con `IN`.
- Alternativa: `JOIN` contra la agrupacion de clientes frecuentes.
- Verificacion: cantidad de filas y diferencias mediante `EXCEPT`.

### Uso de IA y control de equivalencia

La IA se utilizo para proponer las soluciones alternativas respetando las condiciones de cada especificacion. La aceptacion de las alternativas depende de la verificacion ejecutable: ambas consultas deben devolver la misma cantidad de filas y cero diferencias en ambos sentidos.

**Archivos originales:**

- [solucion_spec_1_agregacion.sql](Parte%204%20-%20Consultas%20resumen%20y%20subconsultas%20bajo%20especificacion%20precisa/solucion_spec_1_agregacion.sql)
- [alternativa_spec_1_cte.sql](Parte%204%20-%20Consultas%20resumen%20y%20subconsultas%20bajo%20especificacion%20precisa/alternativa_spec_1_cte.sql)
- [solucion_spec_2_subconsulta.sql](Parte%204%20-%20Consultas%20resumen%20y%20subconsultas%20bajo%20especificacion%20precisa/solucion_spec_2_subconsulta.sql)
- [alternativa_spec_2_join.sql](Parte%204%20-%20Consultas%20resumen%20y%20subconsultas%20bajo%20especificacion%20precisa/alternativa_spec_2_join.sql)
- [verificacion_equivalencia.sql](Parte%204%20-%20Consultas%20resumen%20y%20subconsultas%20bajo%20especificacion%20precisa/verificacion_equivalencia.sql)
- [Especificacion 1](Parte%204%20-%20Consultas%20resumen%20y%20subconsultas%20bajo%20especificacion%20precisa/Spec%201%20-%20Consulta%20de%20Resumen(agregacion))
- [Especificacion 2](Parte%204%20-%20Consultas%20resumen%20y%20subconsultas%20bajo%20especificacion%20precisa/Spec%202%20-%20Consulta%20con%20subconsulta)

---

## Parte 5 - Competencia de optimizacion

### Objetivo

Comparar una consulta base contra una estrategia de optimizacion propuesta por el equipo, justificando cada cambio a partir de los nodos del plan y de mediciones reproducibles.

### Equipo y resultado

**Equipo:** Lucas Avila, Amanda Pagano y Mateo Lautaro Liendo  
**Resultado baseline:** 286,909 ms  
**Resultado con la estrategia evaluada:** 200,606 ms  
**Mejora registrada:** aproximadamente 1,43x

### Uso de IA

Se utilizo Kiro para:

- analizar el plan `EXPLAIN ANALYZE` baseline;
- proponer indices justificados sobre nodos reales del plan;
- generar scripts de prueba con `BEGIN`, `CREATE INDEX`, `ANALYZE`, `EXPLAIN ANALYZE` y `ROLLBACK`.

El equipo reviso las sugerencias, ejecuto las mediciones en la base de carga y tomo manualmente las decisiones finales.

### Decisiones documentadas

- Se acepto `idx_p5_pedido_estado` porque cambio el escaneo de `pedido` a un bitmap scan y mantuvo el paralelismo.
- Se mantuvo en la estrategia la propuesta parcial sobre `producto`, dejando asentado que el planificador no la eligio directamente.
- Se descarto el indice sobre `detalle_pedido(id_pedido)` por evidencia previa de que el planificador lo ignoraba.
- La prueba de los indices se realizo con `ROLLBACK`; cualquier aplicacion permanente se hizo mediante una accion manual posterior.

**Archivos originales:**

- [bitacora_p5.md](Parte%205%20-Competencia%20de%20optimizacion%20entre%20equipos/bitacora_p5.md)
- [consulta_base.sql](Parte%205%20-Competencia%20de%20optimizacion%20entre%20equipos/consulta_base.sql)
- [optimizacion_propuesta_1.sql](Parte%205%20-Competencia%20de%20optimizacion%20entre%20equipos/optimizacion_propuesta_1.sql)
- [optimizacion_propuesta_2.sql](Parte%205%20-Competencia%20de%20optimizacion%20entre%20equipos/optimizacion_propuesta_2.sql)
- [Planes de ejecucion](Parte%205%20-Competencia%20de%20optimizacion%20entre%20equipos/planes/)

---

## Inventario completo de archivos

### Parte 1

- `seed_masivo.sql`
- `verificacion_carga.sql`

### Parte 2

- `queries_candidatas.sql`
- `indices_propuestos.sql`
- `tabla_comparativa.md`
- carpeta `planes/` con los planes antes, despues e intermedios de Q1, Q2 y Q3

### Parte 3

- `lectura_critica.md`

### Parte 4

- `solucion_spec_1_agregacion.sql`
- `alternativa_spec_1_cte.sql`
- `solucion_spec_2_subconsulta.sql`
- `alternativa_spec_2_join.sql`
- `verificacion_equivalencia.sql`
- archivos de especificacion de Spec 1 y Spec 2

### Parte 5

- `bitacora_p5.md`
- `consulta_base.sql`
- `optimizacion_propuesta_1.sql`
- `optimizacion_propuesta_2.sql`
- carpeta `planes/`

---

## Declaracion final

La inteligencia artificial se utilizo como herramienta de apoyo para adaptar scripts, proponer consultas e indices, interpretar planes y redactar alternativas. El equipo conservo el control sobre la revision, ejecucion, medicion, verificacion y aceptacion final de cada resultado.

Las decisiones tecnicas incluidas en este TP3 se basan en los planes y resultados registrados en los archivos originales. Este documento organiza y referencia ese material para facilitar su lectura y entrega, sin modificar el contenido de las partes ni de sus archivos fuente.
