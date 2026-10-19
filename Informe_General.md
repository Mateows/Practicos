# Informe Integrador — Base de Datos II

**Proyecto integrador:** FoodStore — sistema de pedidos tipo delivery (categorías, clientes, productos, pedidos y detalle de pedidos)

**Alumnos:** Lucas Avila, Mateo Liendo, Amanda Pagano

**Profesor:** Neira Sergio.

**Comisión:** 4 · **Materia:** Base de Datos II · **UTN FRM — Tecnicatura Universitaria en Programación**

**Motor:** PostgreSQL 17 · **Repositorio:** `Base_de_datos2` (Git)

## Introducción

Este informe integra los seis trabajos prácticos de la cursada sobre **FoodStore**. El recorrido comprende modelado y normalización (TP1), integridad y concurrencia (TP2), carga masiva y optimización (TP3), reportes analíticos (TP4), índices y vistas (TP5), y FNBC y desnormalización controlada (TP6).

En TP1 a TP5 se documentó el uso de Kiro, OpenCode o GitHub Copilot según la etapa y el integrante. En las correcciones de TP5 también se utilizaron Claude Code y Claude, registrados en su DUIA. En TP6 se utilizaron **ChatGPT y Codex CLI** para analizar, proponer scripts, revisar evidencias y preparar documentación. Las propuestas se revisaron y los cambios de archivos se realizaron con autorización humana; las ejecuciones en PostgreSQL fueron realizadas por el grupo y sus salidas se utilizaron como evidencia. No se atribuyen a TP6 las herramientas utilizadas en otras entregas.

Las fuentes principales son las declaraciones y documentos de cada trabajo: [TP1](TP1_FoodStore/README.md), [TP2](TP2_Concurrencia_IA/README.md), [DUIA de TP3](TP3_Optimizacion/DUIA_COMPLETA.md), [DUIA de TP4](TP4_Reportes_Analiticos/DUIA_TP4.md), [DUIA de TP5](TP5_Indices_Vistas/duia.md) y [documentación de TP6](TP6_FNBC_Desnormalizacion/README.md).

El [protocolo de seguridad](protocolo_seguridad.md) establece copia de trabajo, transacciones explícitas y respaldo previo a DDL. Los ensayos históricos deben interpretarse según su base y evidencia: TP3 a TP5 documentan trabajo sobre `foodstore_tp3_carga`, mientras TP6 se validó en `foodstore_copia_trabajo`.

**Una decisión histórica de aceptar una propuesta no demuestra que el objeto esté instalado actualmente.** Se distingue entre resultados medidos, pruebas revertidas y aplicaciones permanentes documentadas. Este informe no constituye un inventario actual de PostgreSQL ni una instalación para ejecutar todos los scripts en secuencia.

## TP1 — Modelado ER, normalización y DDL

Diseño completo de FoodStore desde cero: modelo entidad-relación, derivación al modelo relacional, normalización hasta BCNF y DDL para PostgreSQL.

- **MER:** diccionario de entidades y atributos, cardinalidades y participaciones.
- **MR:** reglas de pasaje del ER al relacional y esquemas con PK/FK.
- **Normalización:** clave candidata universal, dependencias funcionales DF1 a DF4 y demostración de 1FN, 2FN, 3FN y BCNF.
- **DDL:** tipos ENUM, restricciones CHECK y UNIQUE, claves foráneas, columnas generadas STORED, tres índices B-tree justificados y datos de prueba.

La entrega incluye el [informe PDF](TP1_FoodStore/TP1_FoodStore_Grupo_Avila_Pagano_Liendo.pdf), el [diagrama ER](TP1_FoodStore/diagrama_er.pdf), el [script schema.sql](TP1_FoodStore/schema.sql) y el [código DBML](TP1_FoodStore/dbdiagram_code.dbml).

## TP2 — Integridad, transacciones y concurrencia

Laboratorio sobre FoodStore, organizado en cuatro partes.

**Parte 0 — Protocolo de seguridad.** Se documentaron copia, transacción y respaldo para PostgreSQL 17.11, Git Bash y psql.

**Parte 1 — Restricciones de integridad.** Se generaron triggers PL/pgSQL con OpenCode en modo Plan → Build para:

1. Impedir cambios de estado después de ENTREGADO o CANCELADO.
2. Rechazar fechas de pedido posteriores a `now()`.
3. Validar que la cantidad del detalle no supere el stock disponible.

En revisión posterior se detectó que una versión permitía ENTREGADO → CANCELADO y viceversa. Se corrigió para bloquear cualquier cambio una vez alcanzado un estado final. Los cinco casos documentados se verificaron sobre la copia de trabajo dentro de una transacción, con respaldo previo. Véanse el [script de restricciones](TP2_Concurrencia_IA/parte1/restricciones_integridad.sql) y la [DUIA de Parte 1](TP2_Concurrencia_IA/parte1/DUIA_parte1.md).

Estas pruebas históricas no implican que esos triggers estén instalados en toda copia posterior.

**Parte 2 — Anomalías de concurrencia.** Se trabajó con dos sesiones psql simultáneas:

- Lectura no repetible en READ COMMITTED, resuelta con REPEATABLE READ.
- Lectura fantasma en READ COMMITTED, tratada con SERIALIZABLE.
- Espera por bloqueo entre dos sesiones que solicitan FOR UPDATE sobre la misma fila.

Los escenarios están documentados en el [informe de concurrencia](TP2_Concurrencia_IA/parte2/informe_concurrencia.md). Estas pruebas pertenecen a TP2; no sustituyen las pruebas concurrentes pendientes de la adaptación de TP6.

**Parte 3 — Lectura crítica de SQL.** Se analizaron un UPDATE sin WHERE y un DELETE con NOT IN susceptible a valores NULL. Para cada caso se explicó el efecto real y se propuso una corrección. También se revisaron casos documentados de agentes de IA que afectaron bases de producción, como fundamento del protocolo. Fuente: [ejercicio de lectura crítica](TP2_Concurrencia_IA/parte3/ejercicio_lectura_critica.md).

## TP3 — Carga masiva y optimización con IA

Se pobló FoodStore a escala de aproximadamente 200000 pedidos y se analizaron consultas mediante EXPLAIN ANALYZE. Los conteos de detalles corresponden a las cargas registradas en cada etapa: la bitácora de Parte 5 informa 498608 detalles, mientras la carga utilizada posteriormente en TP6 contiene 499571. No se consideran todas las mediciones como realizadas sobre una única instancia idéntica.

**Parte 1 — Carga masiva.** Se adaptó el generador al esquema real con generate_series y pools de identificadores. Se corrigió un problema de aleatorización: subconsultas ORDER BY random() LIMIT 1 podían evaluarse una sola vez para toda la sentencia. La versión final utiliza arreglos y selección aleatoria por fila, con ON CONFLICT DO NOTHING para respetar la PK compuesta. Se verificaron conteos, integridad, duplicados y distribuciones.

**Parte 2 — Optimización de tres consultas.**

- **Q1:** el índice `(estado, fecha_hora DESC)` cambió Parallel Seq Scan + Sort + Gather Merge por Index Scan: **33.698 ms → 0.908 ms**, aproximadamente 37 veces.
- **Q2:** el índice de categoría y precio no eliminó el ordenamiento ni mejoró el tiempo: **12.384 ms → 12.787 ms**. Se descartó.
- **Q3:** los índices de fecha de pedido e identificador de pedido en detalle no mejoraron el resultado. La medición final fue **160.112 ms → 198.558 ms**; el primero eliminó el paralelismo y el segundo no fue utilizado. Ambos se descartaron.

Los **cuatro índices evaluados en esta parte** fueron uno para Q1, uno para Q2 y dos para Q3. Solo Q1 mostró mejora y se conservó según la documentación. Este conteo no incluye las propuestas de Parte 5. Fuente: [tabla comparativa de Parte 2](TP3_Optimizacion/Parte%202%20-%20Consultas%20lentas,%20EXPLAIN%20y%20optimizacion%20medida/tabla_comparativa.md).

**Parte 3 — Lectura crítica.** Se contrastaron afirmaciones con el plan real: tres resultaron incorrectas y una correcta, correspondiente al tiempo total de 0.908 ms.

**Parte 4 — Consultas bajo especificación.** Se construyeron alternativas de agregación frente a CTE y subconsulta IN frente a JOIN, verificando equivalencia mediante EXCEPT en ambos sentidos.

**Parte 5 — Competencia de optimización.** La medición pasó de **286.909 ms a 200.606 ms**, aproximadamente 1.43 veces, para la estrategia evaluada. Se distinguen sus componentes:

- `idx_p5_pedido_estado` **fue utilizado** mediante Parallel Bitmap Heap Scan y mantuvo el paralelismo. La medición de esa propuesta por separado fue aproximadamente 264 ms.
- `idx_p5_producto_categoria_activo` **no fue utilizado directamente**: el plan conservó Seq Scan sobre producto. La bitácora lo mantuvo como parte de la estrategia, pero la desaparición del sort a disco y el resultado de 200.606 ms **no demuestran una mejora causada por ese índice parcial**.
- El índice adicional sobre `detalle_pedido(id_pedido)` se descartó por evidencia previa de que el planificador lo ignoraba.

Los scripts de ensayo terminaron con ROLLBACK. La bitácora distingue esas pruebas de cualquier aplicación permanente mediante comandos manuales posteriores; no se deduce el estado actual de una base a partir de la aceptación histórica.

Fuentes: [bitácora de Parte 5](TP3_Optimizacion/Parte%205%20-Competencia%20de%20optimizacion%20entre%20equipos/bitacora_p5.md), [plan posterior](TP3_Optimizacion/Parte%205%20-Competencia%20de%20optimizacion%20entre%20equipos/planes/plan_p5_despues.txt) y [DUIA consolidada](TP3_Optimizacion/DUIA_COMPLETA.md).

## TP4 — Reportes analíticos asistidos por IA

Continuación sobre `foodstore_tp3_carga`, con joins múltiples, funciones de ventana y subconsultas correlacionadas.

**Parte 1 — Consultas analíticas e índices.**

| Consulta | Tiempo anterior | Tiempo posterior | Resultado |
|---|---:|---:|---|
| A — Facturación por categoría y mes | 699.550 ms | 164.254 ms | Índice utilizado; mejora observada de aproximadamente 4.26 veces |
| B — Ranking de clientes por gasto | 304.753 ms | 305.604 ms | Índice no utilizado; sin mejora |

En A, `idx_tp4_a_estado_id` permitió Parallel Index Only Scan con Heap Fetches: 0. Los algoritmos Hash Join y Parallel Hash Join y los dos workers se conservaron: el cambio relevante fue el acceso a pedido.

En B, el índice parcial conservaba la mayoría de las filas y el planificador mantuvo Parallel Seq Scan. Una prueba independiente con work_mem de 64 MB dio 250.280 ms; ese resultado corresponde al cambio de memoria, no al índice.

**Ambos ensayos de índices terminaron con ROLLBACK y no dejaron esos índices aplicados.** La decisión “aceptar” de A expresa la evaluación favorable del ensayo, no una instalación permanente.

Fuentes: [tabla comparativa](TP4_Reportes_Analiticos/Parte1/tabla_comparativa.md), [plan A posterior](TP4_Reportes_Analiticos/Parte1/plan_a_despues.md) y [plan B posterior](TP4_Reportes_Analiticos/Parte1/plan_b_despues.md).

**Parte 2 — Lectura crítica del plan A.** La tabla contiene **siete afirmaciones: cinco correctas, una parcialmente correcta y una falsa**. La parcial atribuye Heap Fetches: 0 solo a que el índice contiene las columnas necesarias, omitiendo el mapa de visibilidad. La falsa equipara el costo estimado con milisegundos. Fuente: [tabla de lectura crítica](TP4_Reportes_Analiticos/Parte2/plan_a_explicacion_ia.md).

**Parte 3 — Consultas bajo especificación.** La alternativa inicial al ranking DENSE_RANK, basada en COUNT(*), produjo 19433 diferencias y fue rechazada. Se corrigió a COUNT(DISTINCT total_gastado), con cero diferencias en ambos sentidos. La alternativa con JOIN sobre un promedio preagregado también fue equivalente a la subconsulta correlacionada y redujo sustancialmente su tiempo. Fuente: [DUIA de Parte 3](TP4_Reportes_Analiticos/Parte3/DUIA_Parte3.md).

**Parte 4 — Competencia de optimización.** El cuello de botella fue un Sort con derrame a disco. Subir work_mem local a 8 MB eliminó el derrame. Se conservan los resultados históricos de las distintas etapas: **621.0 ms → 539.1 ms** en la comparación inicial en bloques y **571.4 ms** para solo work_mem en el control intercalado posterior.

El control A-B-A-B-A-B obtuvo el mismo promedio de **571.4 ms** con y sin el índice parcial adicional, por lo que se descartó atribuirle una mejora. La estrategia final no dejó cambios permanentes de esquema: work_mem se configura localmente para ejecutar la consulta. Fuente: [registro de competencia](TP4_Reportes_Analiticos/Parte4/registro_competencia.md).

## TP5 — Índices, vistas y vista materializada

Se integraron las tres partes sobre el esquema y la base masiva heredados, con especificaciones y revisión de las propuestas.

**Parte A — Plan de indexado.** Se documentó la aplicación de dos índices: Q6, con aproximadamente 41 % de mejora, y Q2, con aproximadamente 37 % y cambio de Seq Scan a Bitmap Heap Scan.

Se descartaron:

- El índice parcial de Q5, ignorado por baja selectividad.
- El índice de `detalle_pedido(id_pedido)`, redundante con la PK compuesta.
- El BRIN de fecha_hora, con correlación física próxima a cero.
- El B-tree de fecha_hora de Q4, inicialmente aceptado con aproximadamente 8.9 %, pero descartado después de tres rondas archivadas sin mejora consistente.

El costo de escritura se midió en producto, con aproximadamente **47 % adicional** con los dos índices, y en detalle_pedido, sin efecto relevante. Fuentes: [informe de mediciones](TP5_Indices_Vistas/informe_mediciones.md) y [DUIA](TP5_Indices_Vistas/duia.md).

**Parte B — Vistas y seguridad.** Se crearon cinco vistas, incluida `v_usuario_publico`, que omite contrasena. Se agregó usuario sin modificar cliente. El rol `tp5_reportes`, NOLOGIN, recibió SELECT sobre las vistas y no sobre las tablas base; se registró un intento real de acceso denegado. Las vistas se contrastaron con consultas manuales mediante EXCEPT bidireccional.

**Parte C — Vista materializada.** Se documentó `mv_resumen_ventas_categoria_mes`, con facturación, pedidos y unidades por categoría y mes, WITH DATA e índice único para REFRESH CONCURRENTLY.

La medición archivada fue **976.1 ms → 0.054 ms**, en tres rondas. Se conserva la distinción respecto de la medición anterior de 618 ms → 0.073 ms, que no había quedado archivada. Se ejecutó y midió REFRESH CONCURRENTLY y se analizó la desactualización entre refrescos, recomendándose un refresco diario nocturno para ese reporte.

La documentación registra una aplicación permanente posterior a una prueba reversible. Esto describe la decisión y ejecución históricas de TP5, no una verificación actual de todas las bases o copias. Fuente: [DUIA de TP5](TP5_Indices_Vistas/duia.md).

Algunos scripts de medición de TP5 confirman cambios de índices para comparar escenarios sobre la base de carga. Esa característica histórica no debe generalizarse a los ensayos de TP4 o TP6 que finalizaron con ROLLBACK.

## TP6 — FNBC y desnormalización controlada

Se trabajó sobre `foodstore_copia_trabajo`. ChatGPT y Codex CLI se utilizaron para el análisis, las propuestas SQL, la revisión de evidencias y la documentación, con revisión y autorización humana. Las mediciones fueron ejecutadas por el grupo; no se presentan como pruebas realizadas por la IA.

Documentación: [README de TP6](TP6_FNBC_Desnormalizacion/README.md), [informe final Markdown](TP6_FNBC_Desnormalizacion/informe_final_tp6.md) e [informe final PDF](TP6_FNBC_Desnormalizacion/informe_final_tp6.pdf).

### Parte 1 — FNBC

Se analizó R(L,D,C), con L = lote, D = depósito y C = responsable de control, y las dependencias **LD → C** y **C → D**. La pertenencia a depósito corresponde a responsables de control; no implica que todos los usuarios tengan depósito ni que un depósito tenga un solo responsable.

Las claves candidatas completas son **LD y LC**, ambas mínimas. Todos los atributos son primos. La relación cumple 3FN, pero viola FNBC porque C → D tiene un determinante que no es superclave: C⁺ = CD.

Se descompuso en:

- `responsable_deposito(C,D)`, con PK C.
- `control_lote(L,C)`, con PK LC.

Ambas relaciones quedan en FNBC. La reunión es **sin pérdida** porque el atributo común C determina CD. Sin embargo, **LD → C no se preserva mediante las restricciones locales**: dos responsables del mismo depósito podrían controlar el mismo lote sin violar las PK/FK descompuestas. Controlar esa regla exigiría una validación entre tablas, no implementada en esta parte.

La migración se realizó mediante INSERT ... SELECT DISTINCT y se reconstruyó la relación con una vista. El EXCEPT bidireccional fue vacío, los conteos fueron **3/2/3/3** y se reconstruyeron exactamente:

| Lote | Depósito | Responsable |
|---|---|---|
| 501 | 30 | 801 |
| 502 | 30 | 801 |
| 503 | 31 | 802 |

El script terminó con **ROLLBACK**, por lo que la migración no quedó persistida.

Fuentes: [informe de Parte 1](TP6_FNBC_Desnormalizacion/Parte1_FNBC/informe_parte1_fnbc.md), [script](TP6_FNBC_Desnormalizacion/Parte1_FNBC/tp_fnbc_control_lote.sql) y [evidencia](TP6_FNBC_Desnormalizacion/Parte1_FNBC/evidencias/evidencia_fnbc_20261008_222128.txt).

### Parte 2 — Desnormalización del top diario

Se adaptó la consulta al esquema real mediante `dp.id_pedido`, `dp.id_producto`, `pr.id_categoria` y un intervalo semiabierto sobre `ped.fecha_hora`. Se conservó SUM(subtotal), GROUP BY nombre y LIMIT 5.

La fecha histórica reproducible fue **25/06/2026 en America/Buenos_Aires**, en sustitución de CURRENT_DATE porque la carga no contenía pedidos del día de ejecución. El ensayo corregido incorpora `pedido.eliminado` y `detalle_pedido.eliminado`, ambos BOOLEAN NOT NULL DEFAULT FALSE, como estados propios independientes. La consulta normalizada exige `dp.eliminado = FALSE AND ped.eliminado = FALSE`; la desnormalizada exige `dp.eliminado = FALSE AND dp.pedido_eliminado_cache = FALSE`, sin volver a unir pedido. No se agregan filtros por estado ni por activo.

La carga contiene **200005 pedidos, 499571 detalles, 50003 productos y 2 categorías**. El límite de cinco se mantiene, aunque solo se obtienen dos categorías.

Se eligieron columnas precalculadas con disparadores porque el plan inicial histórico mostró un recorrido de pedido y búsquedas repetidas en producto. Copiar al detalle los atributos de consulta permite evitar esos recorridos y sincronizar cambios dentro de la transacción. Una vista materializada con refresco nocturno no satisface el requisito de actualización frecuente. La medición inicial corregida realizada por el grupo registró **62.538 ms** y **8455 shared hit**; es una referencia previa a las copias y no interviene en el cálculo de mejora entre rondas.

Dentro del ensayo se agregaron los atributos propios de borrado lógico y tres copias redundantes: `fecha_hora_pedido_cache`, `id_categoria_cache` y `pedido_eliminado_cache`, manteniendo el índice sobre la fecha copiada. Los triggers recalculan las tres copias al insertar o actualizar detalles y propagan cambios de fecha o eliminado del pedido y categoría del producto. `pedido_eliminado_cache` copia exclusivamente `pedido.eliminado`, sin modificar el estado propio del detalle. Restaurar el pedido no restaura detalles eliminados individualmente. El nombre de categoría no se copia: se conserva el JOIN con categoria. Retirar la desnormalización permitiría volver a la consulta normalizada conservando los atributos propios de borrado lógico.

**Resultados corregidos de Parte 2 — ejecución del grupo del 09/10/2026.**

La comparación directa se realizó después de cargar, indexar y ejecutar ANALYZE:

| Medición | Normalizada (ms) | Desnormalizada (ms) | Normalizada shared hit | Desnormalizada shared hit |
|---|---:|---:|---:|---:|
| Ronda 1 | 49.291 | 1.980 | 10942 | 565 |
| Ronda 2 | 47.556 | 1.323 | 10942 | 565 |
| Promedio | 48.4235 | 1.6515 | 10942 | 565 |

La reducción temporal calculada sobre los promedios es **96.59 %**, con cociente normalizada/desnormalizada de **29.32**. La mejora corresponde al **conjunto columnas redundantes más índice**, sin separar el aporte de cada componente. Los **62.538 ms** iniciales no intervienen en estos cálculos. Los shared hit representan accesos resueltos en caché, no lecturas físicas ni páginas únicas.

Ambas consultas corregidas devolvieron **Bebidas: 5589534.40** y **Pizzas: 5215387.22**. Las evidencias aportadas por el grupo registran auditoría inicial y posterior sin diferencias, EXCEPT bidireccional del top vacío y **EXCEPT ALL bidireccional de filas participantes vacío**. La auditoría incluye también registros eliminados.

Se superaron las pruebas secuenciales de las cuatro combinaciones lógicas, restauraciones independientes, inserción bajo pedido eliminado, traslado del detalle a un pedido vigente y retorno, cambio simultáneo de fecha y eliminado y corrección de cache arbitrario, además de las pruebas anteriores de sincronización y DELETE/CASCADE. Los fixtures se deshicieron mediante **ROLLBACK TO SAVEPOINT antes de medir**, sin consumir secuencias.

Ambos ensayos corregidos de Parte 2 contienen DDL transaccional —incluida la medición inicial, que ya no es READ ONLY— y terminaron con **ROLLBACK final**, registrado en los TXT completos. Según la comprobación posterior informada por el grupo, quedaron **cero columnas añadidas**, **200005 pedidos** y **499571 detalles**; ese control posterior no está incluido en los dos TXT.

**Antecedentes históricos del 08/10/2026 — versión sin filtros de borrado lógico.** La medición inicial histórica fue de **47.151 ms**. Las siguientes rondas, sus buffers y su reducción corresponden a esa versión; se conservan sin mezclarlos con los resultados corregidos.

La comparación directa, posterior a carga, indexación y ANALYZE, fue:

| Medición | Normalizada (ms) | Desnormalizada (ms) | Normalizada shared hit | Desnormalizada shared hit |
|---|---:|---:|---:|---:|
| Ronda 1 | 42.807 | 1.855 | 10942 | 564 |
| Ronda 2 | 41.920 | 1.815 | 10942 | 564 |
| Promedio | 42.3635 | 1.835 | 10942 | 564 |

La reducción de tiempo observada fue **95.67 %**, con cociente **23.09**, atribuible al **conjunto columnas más índice**. Los 47.151 ms iniciales no se usaron para calcular esa mejora.

La normalizada mantiene Parallel Seq Scan de pedido y búsquedas mediante Nested Loop en detalle y producto. La desnormalizada utiliza Bitmap Index Scan y Bitmap Heap Scan sobre detalle y conserva únicamente el JOIN con categoria.

Ambas devolvieron **Bebidas: 5589534.40** y **Pizzas: 5215387.22**. La auditoría completa de las copias y el EXCEPT bidireccional fueron vacíos. Se superaron pruebas secuenciales de inserción, actualización, cambio de padres, propagación, cambio de nombre, borrado y CASCADE, deshechas con SAVEPOINT antes de medir y sin consumir secuencias.

**Límites:** la sincronización soporta READ COMMITTED y puede generar interbloqueos que requieran reintentar la transacción completa. **La concurrencia entre sesiones no fue probada y el costo adicional de escritura no fue cuantificado.** Los cambios de padres pueden propagar actualizaciones a muchos detalles.

Las mediciones ocurrieron dentro de la transacción de carga, con calentamiento previo, orden alternado y bloqueos ACCESS EXCLUSIVE que impidieron actividad concurrente. No hubo VACUUM. Dos rondas y dos categorías no constituyen un benchmark exhaustivo.

El script terminó con **ROLLBACK**: las columnas, el índice y los triggers no quedaron instalados.

Fuentes: [informe de Parte 2](TP6_FNBC_Desnormalizacion/Parte2_Desnormalizacion/informe_parte2_desnormalizacion.md), [medición inicial](TP6_FNBC_Desnormalizacion/Parte2_Desnormalizacion/medir_top_categorias_antes.sql), [script de desnormalización](TP6_FNBC_Desnormalizacion/Parte2_Desnormalizacion/tp_desnormalizacion_top_categorias.sql).

Evidencias corregidas aportadas por el grupo:
[medición inicial con borrado lógico](TP6_FNBC_Desnormalizacion/Parte2_Desnormalizacion/evidencias/evidencia_top_antes_logico_20261009_092704.txt) y
[pruebas, auditoría y comparación corregidas](TP6_FNBC_Desnormalizacion/Parte2_Desnormalizacion/evidencias/evidencia_top_desnormalizacion_logico_20261009_092837.txt).

Antecedentes históricos sin filtros lógicos:
[medición inicial anterior](TP6_FNBC_Desnormalizacion/Parte2_Desnormalizacion/evidencias/evidencia_top_antes_20261008_225517.txt) y
[comparación anterior](TP6_FNBC_Desnormalizacion/Parte2_Desnormalizacion/evidencias/evidencia_top_desnormalizacion_20261008_232126.txt).

## Conclusión

Los seis trabajos muestran una progresión desde el diseño relacional hasta la optimización y la redundancia controlada. Las propuestas de IA se sometieron a revisión humana y las afirmaciones de equivalencia o rendimiento se contrastaron con evidencias, sin confundir costos estimados con tiempos ni decisiones de aceptación con instalaciones permanentes.

Las revisiones permitieron identificar problemas concretos: aleatorización no correlacionada en TP3, diferencias entre COUNT(*) y COUNT(DISTINCT ...) en TP4, sesgo de caché en mediciones de índices y un caso límite de transición de estado en TP2. TP6 añadió la distinción entre reunión sin pérdida y preservación de dependencias, y una comparación medida de columnas redundantes más índice.

El informe conserva los resultados históricos y sus condiciones. Los ensayos de índices de TP4 Parte 1 y las dos implementaciones de TP6 finalizaron con ROLLBACK. Las aplicaciones permanentes registradas en otras etapas no se extrapolan al estado actual de `foodstore_copia_trabajo`.

La validación de TP6 demuestra equivalencia y sincronización secuencial para los casos ensayados, pero deja pendientes las pruebas concurrentes y la cuantificación del costo de escritura. Por ello, los resultados de lectura respaldan la adaptación evaluada sin presentarla como una instalación persistente ni como una garantía de rendimiento bajo cualquier carga.
