# Practicos Base de Datos II

Entrega de Practicos para la Materia BDII, desde un repositorio de GIT.

Alumnos: Liendo Mateo, Avila Lucas, Pagano Amanda.
Comisión: 4.
Profesor: Neira Sergio.

## Organización y lectura

Todo el trabajo gira en torno a un mismo proyecto integrador: **FoodStore**, un sistema de pedidos tipo delivery (categorías, clientes, productos, pedidos y detalle de pedidos). Cada TP retoma y amplía ese mismo esquema.

El repositorio conserva entregas, scripts de experimentación, respaldos y evidencias históricas. **No constituye una instalación que deba ejecutarse recorriendo todos los SQL en secuencia.** La presencia de un script tampoco implica que sus objetos estén instalados en la base utilizada actualmente. Antes de cualquier ejecución corresponde revisar los requisitos, el entorno y las instrucciones del TP correspondiente.

### Documentación principal

- [Instrucciones para agentes](AGENTS.md)
- [Protocolo de seguridad](protocolo_seguridad.md)
- [Informe integrador de TP1 a TP6](Informe_General.md)
- [README de TP1](TP1_FoodStore/README.md)
- [README de TP2](TP2_Concurrencia_IA/README.md)
- [DUIA consolidada de TP3](TP3_Optimizacion/DUIA_COMPLETA.md)
- [DUIA consolidada de TP4](TP4_Reportes_Analiticos/DUIA_TP4.md)
- [README de TP5](TP5_Indices_Vistas/README.md)
- [DUIA consolidada de TP5](TP5_Indices_Vistas/duia.md)
- [README de TP6](TP6_FNBC_Desnormalizacion/README.md)
- [Informe final de TP6 en Markdown](TP6_FNBC_Desnormalizacion/informe_final_tp6.md)
- [Informe final de TP6 en PDF](TP6_FNBC_Desnormalizacion/informe_final_tp6.pdf)

## Estructura del repositorio

Árbol resumido; cada carpeta conserva documentación y evidencias adicionales.

```text
Practicos/
├── AGENTS.md
├── protocolo_seguridad.md
├── Informe_General.md                     # Informe integrador de TP1 a TP6
├── TP1_FoodStore/                         # Modelado ER, normalización y DDL
│   ├── schema.sql
│   ├── dbdiagram_code.dbml
│   ├── diagrama_er.png
│   ├── diagrama_er.pdf
│   └── README.md
├── TP2_Concurrencia_IA/                   # Integridad, transacciones y concurrencia
│   ├── parte1/
│   │   ├── restricciones_integridad.sql
│   │   ├── respaldo_foodstore_copia_trabajo.sql
│   │   └── DUIA_parte1.md
│   ├── parte2/
│   │   ├── informe_concurrencia.md
│   │   └── DUIA_Parte2.md
│   ├── parte3/
│   │   ├── ejercicio_lectura_critica.md
│   │   └── DUIA_Parte3.md
│   └── README.md
├── TP3_Optimizacion/                      # EXPLAIN ANALYZE e índices
│   ├── DUIA_COMPLETA.md
│   ├── TP3_Semana3_Unidad2_Practica.pdf
│   ├── Parte 1 - Poblar la base masivamente con datos generados por IA/
│   ├── Parte 2 - Consultas lentas, EXPLAIN y optimizacion medida/
│   ├── Parte 3 - Lectura critica de planes interpretados por IA/
│   ├── Parte 4 - Consultas resumen y subconsultas bajo especificacion precisa/
│   └── Parte 5 -Competencia de optimizacion entre equipos/
├── TP4_Reportes_Analiticos/               # Joins, rankings y subconsultas
│   ├── DUIA_TP4.md
│   ├── TP4_Semana4_Unidad2_Practica.pdf
│   ├── Parte1/
│   ├── Parte2/
│   ├── Parte3/
│   └── Parte4/
├── TP5_Indices_Vistas/                    # Índices, vistas y vista materializada
│   ├── schema.sql
│   ├── data.sql
│   ├── queries.sql
│   ├── indices.sql
│   ├── views.sql
│   ├── specs/
│   ├── duia.md
│   ├── informe_mediciones.md
│   ├── README.md
│   ├── Parte_A_Indices/
│   ├── Parte_B_Vistas/
│   └── Parte_C_Vista_Materializada/
├── TP6_FNBC_Desnormalizacion/             # FNBC y desnormalización controlada
│   ├── README.md
│   ├── informe_final_tp6.md
│   ├── informe_final_tp6.pdf
│   ├── Parte1_FNBC/
│   │   ├── tp_fnbc_control_lote.sql
│   │   ├── informe_parte1_fnbc.md
│   │   └── evidencias/
│   │       └── evidencia_fnbc_20261008_222128.txt
│   └── Parte2_Desnormalizacion/
│       ├── medir_top_categorias_antes.sql
│       ├── tp_desnormalizacion_top_categorias.sql
│       ├── informe_parte2_desnormalizacion.md
│       ├── evidencias/
│       │   ├── evidencia_top_antes_20261008_225517.txt
│       │   └── evidencia_top_desnormalizacion_20261008_232126.txt
│       └── capturas/
│           ├── antes_ronda1.png
│           ├── despues_ronda1.png
│           └── auditoria.png
└── .kiro/steering/                        # Documentos de contexto generados con Kiro
```

## TP1 — FoodStore (modelado y DDL)

Proyecto integrador de Base de Datos I: diseño completo de la base de datos FoodStore, con modelo entidad-relación, derivación al modelo relacional, normalización hasta BCNF y el script DDL final (`schema.sql`) para PostgreSQL.

## TP2 — Concurrencia e IA

Trabajo práctico de laboratorio grupal sobre el mismo esquema FoodStore. Cubre integridad, transacciones y concurrencia. Todas las partes están terminadas.

- **Parte 0** (`protocolo_seguridad.md`, en la raíz): protocolo de tres pasos (copia, transacción, respaldo) para trabajar de forma segura con scripts generados por IA, adaptado al entorno real (PostgreSQL 17.11, Git Bash, `psql`).

- **Parte 1** (`TP2_Concurrencia_IA/parte1/`): tres restricciones de integridad implementadas como triggers PL/pgSQL, generadas con OpenCode (Gemini) en modo Plan → Build:
  1. Transición de estado: un pedido en `ENTREGADO` o `CANCELADO` no puede cambiar a ningún otro estado.
  2. Fecha no futura: `fecha_hora` de un pedido no puede ser posterior a `now()`.
  3. Validación de stock: `cantidad` en `detalle_pedido` no puede superar el `stock` disponible del producto.

  Probadas sobre `foodstore_copia_trabajo` con casos válidos e inválidos, dentro de una transacción. DUIA incluida en `DUIA_parte1.md`.

- **Parte 2** (`TP2_Concurrencia_IA/parte2/`): laboratorio de anomalías de concurrencia con dos sesiones `psql` simultáneas sobre `foodstore_copia_trabajo`, guiado con Claude. Tres escenarios documentados en `informe_concurrencia.md`:
  1. Lectura no repetible — demostrada en `READ COMMITTED`, resuelta con `REPEATABLE READ`.
  2. Lectura fantasma — demostrada en `READ COMMITTED`, resuelta con `SERIALIZABLE`.
  3. Espera por bloqueo (`FOR UPDATE`) — dos sesiones sobre la misma fila de `producto`.

  Cada explicación de la IA fue verificada en el motor real. DUIA incluida en `DUIA_Parte2.md`.

- **Parte 3** (`TP2_Concurrencia_IA/parte3/`): lectura crítica de dos scripts SQL con errores de lógica, realizada con Kiro. Documentada en `ejercicio_lectura_critica.md`:
  1. `UPDATE` sin cláusula `WHERE` — afecta todas las filas de la tabla.
  2. `DELETE` con `NOT IN` — falla silenciosamente ante valores `NULL` en la subconsulta.

  Para cada script se documenta el efecto real, por qué no coincide con la intención declarada y la versión corregida. DUIA incluida en `DUIA_Parte3.md`.

## TP3 — Optimización de consultas asistida por IA

Trabajo práctico sobre la misma base FoodStore, ahora poblada masivamente (~200.000 pedidos, 499.571 líneas de detalle), para medir y optimizar con `EXPLAIN ANALYZE`. Cinco partes repartidas entre el equipo.

- **Parte 1** (Amanda) — Carga masiva de datos con un generador de la cátedra (`seed_masivo.sql`). Durante el proceso se detectó y corrigió un bug real de aleatorización no correlacionada en el script original (subconsultas tipo `ORDER BY random() LIMIT 1` que PostgreSQL resolvía una sola vez para toda la sentencia, degenerando la distribución de claves foráneas). Documentado en detalle en `DUIA_COMPLETA.md` y en la carpeta de la parte.

- **Parte 2** (Amanda) — Laboratorio de `EXPLAIN ANALYZE` sobre 3 consultas lentas, con propuestas de índice de Kiro justificadas por nodo del plan. De 4 índices propuestos, solo 1 mostró mejora real (~37x) y se mantuvo aplicado; los otros 3 se revirtieron tras medir, documentando por qué no funcionaron.

- **Parte 3** (Mateo) — Lectura crítica de un plan de ejecución interpretado por IA, contrastando afirmaciones contra el plan real.

- **Parte 4** (Mateo) — Consultas resumen y subconsultas bajo especificación precisa, con verificación de equivalencia por `EXCEPT`.

- **Parte 5** (equipo completo) — Competencia de optimización con una consulta propia (no llegó la consulta común de cátedra), documentada en `bitacora_p5.md`.

DUIA consolidada de las 5 partes en `DUIA_COMPLETA.md`.

## TP4 — Reportes analíticos asistidos por IA

Continuación de TP3 sobre la misma base masiva (`foodstore_tp3_carga`), ahora con foco en joins múltiples, funciones de ventana y subconsultas correlacionadas.

- **Parte 1** (Mateo) — Laboratorio de consultas analíticas lentas con múltiples `JOIN`, identificando el algoritmo elegido por el optimizador (`Hash Join`, `Parallel Hash Join`) antes y después de aplicar índices.

- **Parte 2** (Lucas) — Lectura crítica de un plan de join real (Consulta A de la Parte 1, con `Hash Join`, `Parallel Hash Join` y un `Parallel Index Only Scan`), explicado nodo por nodo por IA y contrastado contra el plan real. Se detectó una afirmación parcialmente incorrecta (`Heap Fetches: 0` no depende solo de que el índice sea covering, también del mapa de visibilidad) y una afirmación falsa (el costo estimado no equivale a milisegundos).

- **Parte 3** (Amanda) — Dos consultas bajo especificación precisa: un ranking con función de ventana (`DENSE_RANK`) y una subconsulta correlacionada, cada una con una segunda versión de estructura distinta y verificación de equivalencia con `EXCEPT`. En el camino se detectó y corrigió una no-equivalencia real entre `COUNT(*)` y `COUNT(DISTINCT ...)` al replicar manualmente la semántica de `DENSE_RANK`.

- **Parte 4** (Amanda) — Competencia de optimización sobre una consulta propia (top 3 productos por facturación y categoría). El cuello de botella real resultó ser un `Sort` con *spill* a disco, resuelto subiendo `work_mem` de sesión; un índice adicional propuesto se descartó porque el control con mediciones intercaladas no mostró una mejora adicional consistente del índice.

DUIA consolidada de las 4 partes en `DUIA_TP4.md`.

## TP5 — Índices, vistas y vista materializada

Continuación de la base masiva de TP3/TP4 (`foodstore_tp3_carga`, ~200.000 pedidos, 499.571 líneas de detalle). El trabajo se armó integrando el aporte de cada integrante del equipo sobre la misma base heredada, con specs propios en Kiro y verificación propia antes de aceptar cada pieza.

- **Parte A** (Amanda) — Plan de indexado sobre 4 consultas reales con Seq Scan (ranking de clientes, productos vs. promedio de categoría, top 3 por facturación en los últimos 6 meses y productos de una categoría en un rango de precio). Quedaron 2 índices aplicados en firme: el de Q6 (~41%) y el de Q2 (~37%, Seq Scan → Bitmap Heap Scan). Se descartaron el índice parcial de Q5 (ignorado por el planificador, baja selectividad), un índice sobre `detalle_pedido(id_pedido)` redundante con la PK, el BRIN sobre `fecha_hora` (correlación ~0) y el B-tree sobre `fecha_hora` de Q4: se había aceptado con ~8,9%, pero tras la devolución de la cátedra se remidió con 3 rondas archivadas, no mejoró de forma consistente y se descartó. El costo de escritura se midió en `producto` (+47% con los dos índices) y en `detalle_pedido` (sin efecto relevante), y las mediciones que sostienen cada decisión final tienen su salida archivada.

- **Parte B** (Lucas) — 5 vistas (`vistas.sql`): productos vigentes con categoría, ventas agregadas por cliente, pedidos con los datos del cliente, detalle de pedido con nombre de producto, y una vista de seguridad (`v_usuario_publico`) que expone `usuario` sin la columna `contrasena`. El esquema heredado usa `cliente` sin tabla de autenticación; se agregó una tabla `usuario` nueva sin tocar `cliente` (`usuarios.sql`). Un rol de solo lectura (`seguridad_roles.sql`) tiene `SELECT` sobre las vistas pero no sobre las tablas base. Cada vista se verificó contra una consulta manual equivalente con `EXCEPT` (`verificacion_vistas.sql`).

- **Parte C** (Mateo) — Vista materializada `mv_resumen_ventas_categoria_mes` (facturación, pedidos y unidades por categoría y mes), con `WITH DATA` e índice único que permite `REFRESH CONCURRENTLY`. Medición archivada: 976.1 ms la consulta directa contra 0.054 ms la vista (3 rondas). Se ejecutó y se midió `REFRESH CONCURRENTLY`, con el análisis de bloqueos, del dato desactualizado y de la frecuencia de refresco. Aplicada en firme.

DUIA consolidada en `TP5_Indices_Vistas/duia.md`.

## TP6 — FNBC y desnormalización controlada

Trabajo de Unidad 4 sobre `foodstore_copia_trabajo`, organizado en dos partes.

- [Parte1_FNBC](TP6_FNBC_Desnormalizacion/Parte1_FNBC/) — Análisis de `R(LoteID, DepositoID, ResponsableControlID)`, con dependencias LD → C y C → D. Las claves candidatas son LD y LC y todos los atributos son primos: la relación cumple 3FN, pero viola FNBC porque C no es superclave. Se descompuso en `responsable_deposito(C,D)` y `control_lote(L,C)`, ambas en FNBC, con reunión sin pérdida porque el atributo común C determina CD. La dependencia LD → C no queda preservada mediante las restricciones locales y requeriría un control adicional entre tablas. La prueba reconstruyó las tres filas originales, con EXCEPT bidireccional vacío y conteos 3/2/3/3.

- [Parte2_Desnormalizacion](TP6_FNBC_Desnormalizacion/Parte2_Desnormalizacion/) — Adaptación del top cinco de categorías por monto vendido en el día. Se mantuvieron `SUM(subtotal)`, agrupación por nombre y `LIMIT 5`, usando los nombres reales de FoodStore y un intervalo semiabierto para el **25/06/2026 en America/Buenos_Aires**. El ensayo corregido incorpora `pedido.eliminado` y `detalle_pedido.eliminado`, ambos BOOLEAN NOT NULL DEFAULT FALSE, como estados propios independientes. La consulta normalizada filtra `dp.eliminado = FALSE AND ped.eliminado = FALSE`; la desnormalizada conserva esa semántica mediante `dp.eliminado = FALSE AND dp.pedido_eliminado_cache = FALSE`. Esta tercera copia redundante representa exclusivamente el estado del pedido: restaurarlo no restaura detalles eliminados individualmente. No se agregan filtros por estado ni por activo. Se eligieron columnas redundantes con sincronización transaccional mediante disparadores y un índice de fecha, conservando el JOIN con categoria; un refresco nocturno de una vista materializada no satisface el requisito de actualización frecuente.

### Resultados medidos de Parte 2

La carga documentada contiene 200005 pedidos, 499571 detalles, 50003 productos y 2 categorías. El grupo ejecutó los ensayos corregidos con borrado lógico el 09/10/2026. La medición normalizada inicial fue de **62.538 ms**, antes de incorporar las copias redundantes; no se utiliza para calcular la mejora entre rondas.

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

La comparación directa, después de cargar e indexar, registró:

| Medición | Normalizada (ms) | Desnormalizada (ms) |
|---|---:|---:|
| Ronda 1 | 42.807 | 1.855 |
| Ronda 2 | 41.920 | 1.815 |
| Promedio | 42.3635 | 1.835 |

Los buffers shared hit fueron **10942** frente a **564**. La reducción de tiempo observada fue de aproximadamente **95.67 %**, atribuible al conjunto **columnas más índice**. Los 47.151 ms iniciales no se utilizaron para calcular esta mejora.

Ambas consultas devolvieron Bebidas: 5589534.40 y Pizzas: 5215387.22. La auditoría completa y el EXCEPT bidireccional devolvieron cero filas; las pruebas secuenciales de sincronización fueron superadas y se deshicieron mediante SAVEPOINT antes de medir.

### Validación y límites de TP6

Ambos scripts de implementación se validaron dentro de transacciones que terminaron con **ROLLBACK**. La migración de Parte 1 y las columnas, índice y triggers de Parte 2 **no quedaron instalados**. El script de medición inicial también termina con ROLLBACK.

La sincronización propuesta soporta READ COMMITTED y puede producir interbloqueos que requieran reintentar la transacción completa. **La concurrencia entre sesiones de esta adaptación no fue probada y su costo adicional de escritura no fue cuantificado.**

Las mediciones se realizaron dentro de la transacción de carga, con ANALYZE, calentamiento previo, orden alternado y bloqueos que impidieron actividad concurrente. No se ejecutó VACUUM. Solo hay dos categorías y dos rondas: estos resultados no constituyen un benchmark exhaustivo ni garantizan los mismos tiempos bajo otras condiciones.

El README y el informe final de TP6, enlazados en la documentación principal, reúnen requisitos, scripts, evidencias y capturas reales.

Evidencias corregidas aportadas por el grupo:
[medición inicial con borrado lógico](TP6_FNBC_Desnormalizacion/Parte2_Desnormalizacion/evidencias/evidencia_top_antes_logico_20261009_092704.txt) y
[pruebas, auditoría y comparación corregidas](TP6_FNBC_Desnormalizacion/Parte2_Desnormalizacion/evidencias/evidencia_top_desnormalizacion_logico_20261009_092837.txt).

Antecedentes históricos sin filtros lógicos:
[medición inicial anterior](TP6_FNBC_Desnormalizacion/Parte2_Desnormalizacion/evidencias/evidencia_top_antes_20261008_225517.txt) y
[comparación anterior](TP6_FNBC_Desnormalizacion/Parte2_Desnormalizacion/evidencias/evidencia_top_desnormalizacion_20261008_232126.txt).
