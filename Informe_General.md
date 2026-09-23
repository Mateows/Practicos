# Informe Integrador — Base de Datos II

**Proyecto integrador:** FoodStore — sistema de pedidos tipo delivery (categorías, clientes, productos, pedidos y detalle de pedidos)

**Alumnos:** Lucas Avila, Mateo Liendo, Amanda Pagano

**Profesor:** Neira Sergio.

**Comisión:** 4 · **Materia:** Base de Datos II · **UTN FRM — Tecnicatura Universitaria en Programación**

**Motor:** PostgreSQL 17 · **Repositorio:** `Base_de_datos2` (Git)

## Introducción

Este informe integra los cinco trabajos prácticos de la cursada sobre un mismo proyecto: **FoodStore**. Cada TP retoma y amplía el esquema anterior, desde el modelado inicial (TP1) hasta índices, vistas y vista materializada sobre una base cargada masivamente (TP5), por lo que el trabajo debe leerse como una progresión continua, no como cinco entregas aisladas.

Toda la cursada se hizo bajo un flujo obligatorio de IA asistida: **Kiro** para especificar y planificar cada pieza, y un agente de generación de código (**OpenCode** o **GitHub Copilot**, según el integrante) para producirla. Ninguna propuesta de la IA se aceptó por su explicación: cada afirmación de rendimiento, cada script y cada plan de ejecución se verificó contra el motor real (PostgreSQL 17), y cada TP documenta su Declaración de Uso de IA (DUIA): qué se pidió, qué se generó, qué se aceptó y qué se corrigió o descartó.

Desde TP2 se sigue además un **protocolo de seguridad** de tres pasos para trabajar con scripts generados por IA sin arriesgar la base real: (1) **copia** — nunca se ejecuta nada sobre `foodstore_dev`, todo corre contra una copia de trabajo; (2) **transacción** — todo cambio se prueba primero dentro de `BEGIN...ROLLBACK`, revisando el efecto real antes de confirmar; (3) **respaldo** — todo cambio estructural se respalda con `pg_dump` antes de aplicarse. El TP2 documenta además casos reales de agentes de IA que borraron bases de producción por no seguir exactamente este tipo de disciplina, como justificación del protocolo.

## TP1 — Modelado ER, normalización y DDL

Diseño completo de la base FoodStore desde cero: modelo entidad-relación, derivación al modelo relacional, normalización hasta BCNF y script DDL final para PostgreSQL.

- **MER:** diccionario de entidades y atributos, cardinalidades y participaciones.
- **MR:** reglas formales de pasaje del ER al relacional, esquemas con PK/FK.
- **Normalización:** clave candidata universal, listado de dependencias funcionales (DF1 a DF4) y demostración paso a paso de 1FN, 2FN, 3FN y BCNF.
- **DDL (`schema.sql`):** tipos `ENUM`, claves foráneas con `ON DELETE RESTRICT`, restricciones `CHECK`/`UNIQUE`, columnas generadas (`STORED`), 3 índices B-Tree justificados y datos de prueba.

Entregado como paquete completo: informe PDF formal, diagrama ER en alta definición (300 DPI), `schema.sql` comentado y probado, y el código DBML fuente del diagrama.

## TP2 — Integridad, transacciones y concurrencia

Laboratorio grupal sobre el esquema FoodStore, cubriendo cuatro partes.

**Parte 0 — Protocolo de seguridad.** Los tres pasos (copia, transacción, respaldo) descritos en la introducción, adaptados al entorno real (PostgreSQL 17.11, Git Bash, `psql`).

**Parte 1 — Restricciones de integridad (triggers PL/pgSQL)**, generadas con OpenCode en modo Plan → Build:

1. Transición de estado: un pedido `ENTREGADO` o `CANCELADO` no puede cambiar a ningún otro estado.
2. Fecha no futura: `fecha_hora` de un pedido no puede ser posterior a `now()`.
3. Validación de stock: la `cantidad` en `detalle_pedido` no puede superar el stock disponible del producto.

En revisión posterior se detectó que el trigger de transición de estado dejaba habilitado el pasaje `ENTREGADO → CANCELADO` (y viceversa); se corrigió para bloquear cualquier cambio de estado una vez alcanzado un estado final. Los 5 casos de prueba (3 inválidos + 1 válido + el caso corregido) se verificaron dentro de una transacción sobre la copia de trabajo, con `pg_dump` previo.

**Parte 2 — Anomalías de concurrencia**, con dos sesiones `psql` simultáneas:

- **Lectura no repetible:** reproducida en `READ COMMITTED` (una misma consulta devuelve dos valores distintos dentro de la misma transacción); resuelta con `REPEATABLE READ`.
- **Lectura fantasma:** un `COUNT(*)` cambia dentro de la misma transacción porque otra sesión insertó una fila que cumple el filtro; resuelta con `SERIALIZABLE`.
- **Espera por bloqueo:** dos sesiones piden `SELECT ... FOR UPDATE` sobre la misma fila; la segunda queda bloqueada hasta que la primera hace `COMMIT`.

Cada explicación de la IA se confirmó reproduciendo el escenario en el motor real, antes y después de cambiar el nivel de aislamiento.

**Parte 3 — Lectura crítica de scripts SQL**, con Kiro. Se analizaron dos scripts con errores reales de lógica:

1. `UPDATE funcion SET activa = FALSE;` sin `WHERE` — desactiva **todas** las filas, no solo las buscadas.
2. `DELETE ... WHERE id NOT IN (SELECT categoria_id FROM producto)` — si la subconsulta devuelve algún `NULL`, `NOT IN` no borra **ninguna** fila (falla silenciosa).

Para cada caso se documentó el efecto real, por qué no coincide con la consigna, y la versión corregida (agregando el filtro faltante y `categoria_id IS NOT NULL` / `NOT EXISTS`, respectivamente). Esta parte también analiza casos reales documentados de agentes de IA que borraron bases de producción (Replit, Google Gemini CLI, entre otros) como fundamento del protocolo de la Parte 0: en todos los casos la falla no fue de sintaxis sino de no confirmar el entorno, no revisar el efecto antes de ejecutar, y confiar en el reporte del propio agente.

## TP3 — Carga masiva y optimización con IA

Base poblada masivamente (~200.000 pedidos, 499.571 líneas de detalle) para medir y optimizar con `EXPLAIN ANALYZE`. Cinco partes repartidas en el equipo.

**Parte 1 — Carga masiva.** Adaptación de un generador de la cátedra al esquema real (`generate_series`, pools de identificadores). Se detectó y corrigió un **bug real**: subconsultas `ORDER BY random() LIMIT 1` que PostgreSQL evaluaba una sola vez para toda la sentencia en lugar de una vez por fila, degenerando la distribución de claves foráneas; se reemplazó por selección aleatoria por fila con `array_agg` + índice aleatorio, con `ON CONFLICT DO NOTHING` para la clave compuesta. Verificado con un script de solo lectura (conteos, integridad referencial, duplicados, distribuciones).

**Parte 2 — `EXPLAIN ANALYZE` sobre 3 consultas lentas**, con índices propuestos por Kiro y contrastados contra el planificador real:

- **Q1** (pedidos pendientes por fecha): el índice `(estado, fecha_hora DESC)` cambió el plan de `Parallel Seq Scan + Sort + Gather Merge` a `Index Scan` — de ~33,7 ms a ~0,9 ms.
- **Q2** (productos por categoría y precio): el índice propuesto no mejoró el resultado real; se descartó.
- **Q3** (facturación por cliente y fecha): los índices probados tampoco mejoraron; uno eliminó el paralelismo del plan original y el otro no fue elegido por el planificador. Ambos se descartaron.

De 4 índices propuestos en total (incluyendo Parte 5), solo 1 mostró mejora real y quedó aplicado; el resto se revirtió tras medir, documentando por qué no funcionó.

**Parte 3 — Lectura crítica de un plan real:** de las afirmaciones evaluadas, tres resultaron incorrectas y una correcta (el tiempo total de ejecución de 0,908 ms, confirmado por el plan).

**Parte 4 — Consultas resumen bajo especificación precisa**, cada una con una alternativa de estructura distinta (agregación vs. CTE; subconsulta `IN` vs. `JOIN`) y verificación de equivalencia con `EXCEPT` en ambos sentidos.

**Parte 5 — Competencia de optimización** sobre una consulta propia: de 286,909 ms (baseline) a 200,606 ms (~1,43x), con el índice `idx_p5_pedido_estado` aplicado tras confirmar con `EXPLAIN ANALYZE` que cambiaba el escaneo a bitmap scan manteniendo el paralelismo; otro índice parcial se descartó por evidencia previa de que el planificador lo ignoraba.

## TP4 — Reportes analíticos asistidos por IA

Continuación de TP3 sobre la misma base masiva (`foodstore_tp3_carga`), con foco en joins múltiples, funciones de ventana y subconsultas correlacionadas.

**Parte 1 — Consultas analíticas lentas con múltiples `JOIN`.** Se identificó el algoritmo elegido por el optimizador (`Hash Join`, `Parallel Hash Join`) antes y después de indexar. El índice de la Consulta A (`idx_tp4_a_estado_id`) se aceptó: pasó a `Parallel Index Only Scan` con `Heap Fetches: 0`, de 699,55 ms a 164,25 ms. El de la Consulta B se descartó: el planificador no lo usó y el tiempo quedó prácticamente igual (304,75 ms → 305,60 ms).

**Parte 2 — Lectura crítica de un plan de join real** (la Consulta A de la Parte 1), explicado nodo por nodo por IA y contrastado contra el plan real: de 7 afirmaciones evaluadas, 6 correctas, 1 parcialmente correcta (`Heap Fetches: 0` se atribuyó solo a que el índice es covering, sin mencionar que también depende del mapa de visibilidad) y 1 marcada como falsa a modo de control (el costo estimado del planificador no equivale a milisegundos).

**Parte 3 — Dos consultas bajo especificación precisa**, cada una con una segunda versión de estructura distinta y verificación de equivalencia con `EXCEPT`:

- **Ranking (`DENSE_RANK`):** la primera alternativa propuesta (subconsulta correlacionada con `COUNT(*)`) fue **rechazada** — el `EXCEPT` mostró 19.433 filas de diferencia, porque `COUNT(*)` replica la semántica de `RANK()` (deja huecos tras un empate) y no la de `DENSE_RANK()`. Se corrigió a `COUNT(DISTINCT total_gastado)`, confirmado con 0 diferencias en ambos sentidos.
- **Subconsulta correlacionada** (productos con precio mayor al promedio de su categoría): la alternativa con `JOIN` sobre un promedio pre-agregado fue equivalente (0 diferencias) pero resolvió en segundos lo que la versión original (O(n²) sobre 50k productos) tardaba minutos.

**Parte 4 — Competencia de optimización** (top 3 productos por facturación y categoría, últimos 6 meses). El cuello de botella real resultó ser un `Sort` con *spill* a disco (`external merge Disk`), no un `Seq Scan` como se sospechaba inicialmente. Subir `work_mem` de sesión a 8MB eliminó el spill (`quicksort Memory`) y mejoró el tiempo de 621,0 ms a 571,4 ms (~13%, promedio de 3 corridas). Un índice parcial adicional pareció sumar otra mejora en una primera medición en bloques, pero un control de sesgo con corridas intercaladas (A-B-A-B-A-B) mostró los promedios exactamente empatados: la ventaja inicial era enteramente efecto de caché acumulado, no del índice, que se descartó.

## TP5 — Índices, vistas y vista materializada

Continuación de la base masiva de TP3/TP4 (~200.000 pedidos, 499.571 líneas de detalle), integrando el aporte de cada integrante sobre el mismo esquema heredado, con especificaciones propias en Kiro y verificación propia antes de aceptar cada pieza.

**Parte A — Plan de indexado** sobre 3 consultas reales con `Seq Scan` (ranking de clientes, productos vs. promedio de categoría, top 3 por facturación mensual). De 3 candidatos: 2 quedaron aplicados en firme; 1 se descartó explícitamente por sobreindexación (índice parcial ignorado por el planificador en 9/9 corridas, por baja selectividad). Un tercer caso (B-tree sobre `fecha_hora`) se descartó tras una primera medición aislada y se revirtió a aceptado después de un control de ruido con 3 rondas intercaladas — el cambio de conclusión quedó documentado, no ocultado.

**Parte B — Vistas y seguridad por roles.** 5 vistas (`vistas.sql`): productos vigentes con categoría, ventas agregadas por cliente, pedidos con datos del cliente, detalle de pedido con nombre de producto, y una vista de seguridad (`v_usuario_publico`) que expone la tabla `usuario` sin la columna `contrasena`. Como el esquema heredado no tenía tabla de autenticación, se agregó `usuario` como tabla nueva sin tocar `cliente`. Un rol de solo lectura (`tp5_reportes`, `NOLOGIN`) tiene `SELECT` sobre las 5 vistas pero **no** sobre las tablas base (verificado con un intento real de acceso denegado). Cada vista se verificó contra una consulta manual equivalente con `EXCEPT` en ambos sentidos (`verificacion_vistas.sql`).

**Parte C — Vista materializada** `mv_resumen_ventas_categoria_mes` (facturación, pedidos y unidades por categoría y mes), creada con `WITH DATA` e índice único para habilitar `REFRESH CONCURRENTLY` a futuro. Mejora medida contra la consulta directa sobre las tablas base: **618 ms → 0,073 ms (~8468x)**. Aplicada en firme, con prueba reversible previa (`WITH NO DATA` → `REFRESH` → `EXPLAIN ANALYZE` → `DROP`, luego reaplicación con `WITH DATA`).

DUIA consolidada en `TP5_Indices_Vistas/duia.md`.

## Conclusión

A lo largo de los cinco TP se sostuvo el mismo criterio de trabajo: la IA (Kiro para especificar, OpenCode/Copilot para generar código) propone, pero **nunca decide**. Todo script se leyó antes de ejecutarse, todo cambio estructural se probó primero en `BEGIN...ROLLBACK` sobre una copia de trabajo, y toda afirmación de rendimiento o de equivalencia se contrastó con el motor real — con `EXPLAIN ANALYZE`, con `EXCEPT` bidireccional, o con controles de sesgo de medición (corridas intercaladas).

Ese criterio evitó errores concretos en cada etapa: un bug de aleatorización no correlacionada en la carga masiva (TP3), una no-equivalencia real entre `COUNT(*)` y `COUNT(DISTINCT ...)` al replicar `DENSE_RANK` (TP4), una mejora de índice que resultó ser enteramente efecto de caché (TP4), y un trigger de transición de estado con un caso límite sin cubrir (TP2). En ningún caso se aceptó una propuesta de la IA por su explicación: se aceptó (o se descartó) por lo que el motor efectivamente devolvió.

El resultado es una base FoodStore que evolucionó de un modelo normalizado (TP1) a un esquema con integridad reforzada por triggers y aislamiento de transacciones correcto (TP2), luego cargado a escala real y optimizado con evidencia medible (TP3, TP4), y finalmente enriquecido con índices, vistas de seguridad por rol y una vista materializada de reporte (TP5) — cada decisión de diseño respaldada por una medición reproducible, no por una suposición.