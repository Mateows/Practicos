# Practicos Base de Datos II
Entrega de Practicos para la Materia BDII, desde un repositorio de GIT
Alumnos: Liendo Mateo, Avila Lucas, Pagano Amanda.
Comisión: 4.
Profesor: Neira Sergio.

## Estructura del repositorio

Todo el trabajo gira en torno a un mismo proyecto integrador: **FoodStore**, un sistema de pedidos tipo delivery (categorías, clientes, productos, pedidos y detalle de pedidos). Cada TP retoma y amplía ese mismo esquema.

```
Practicos/
├── TP1_FoodStore/                         # TP1: modelado ER, normalización y DDL en PostgreSQL
│   ├── schema.sql
│   ├── dbdiagram_code.dbml
│   ├── diagrama_er.png / diagrama_er.pdf
│   └── README.md
├── TP2_Concurrencia_IA/                   # TP2: integridad, transacciones y concurrencia
│   ├── parte1/                            # Restricciones de integridad (triggers)
│   │   ├── restricciones_integridad.sql
│   │   ├── respaldo_foodstore_copia_trabajo.sql
│   │   └── DUIA_parte1.md
│   ├── parte2/                            # Laboratorio de concurrencia
│   │   ├── informe_concurrencia.md
│   │   └── DUIA_Parte2.md
│   ├── parte3/                            # Lectura crítica de scripts SQL
│   │   ├── ejercicio_lectura_critica.md
│   │   └── DUIA_Parte3.md
│   └── README.md
├── protocolo_seguridad.md                 # Protocolo de seguridad — TP2 Parte 0
├── AGENTS.md
├── TP3_Optimizacion/                      # TP3: optimización de consultas con IA (EXPLAIN ANALYZE, índices)
│   ├── DUIA_COMPLETA.md
│   ├── TP3_Semana3_Unidad2_Practica.pdf
│   ├── Parte 1 - Poblar la base masivamente con datos generados por IA/   # Amanda
│   ├── Parte 2 - Consultas lentas, EXPLAIN y optimizacion medida/         # Amanda
│   ├── Parte 3 - Lectura critica de planes interpretados por IA/         # Mateo
│   ├── Parte 4 - Consultas resumen y subconsultas bajo especificacion precisa/  # Mateo
│   └── Parte 5 -Competencia de optimizacion entre equipos/               # Equipo completo
├── TP4_Reportes_Analiticos/               # TP4: reportes analíticos (joins, rankings, subconsultas)
│   ├── DUIA_TP4.md
│   ├── TP4_Semana4_Unidad2_Practica.pdf
│   ├── Parte1/                            # Mateo — consultas analíticas lentas
│   ├── Parte2/                            # Lucas — lectura crítica de planes de join
│   ├── Parte3/                            # Amanda — rankings y subconsultas bajo spec precisa
│   └── Parte4/                            # Amanda — competencia de optimización
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

Trabajo práctico sobre la misma base FoodStore, ahora poblada masivamente (~200.000 pedidos, ~500.000 líneas de detalle), para medir y optimizar con `EXPLAIN ANALYZE`. Cinco partes repartidas entre el equipo.

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

- **Parte 4** (Amanda) — Competencia de optimización sobre una consulta propia (top 3 productos por facturación y categoría). El cuello de botella real resultó ser un `Sort` con *spill* a disco, resuelto subiendo `work_mem` de sesión; un índice adicional propuesto se descartó tras confirmar, con un control de orden de mediciones intercaladas, que su aparente mejora era enteramente un efecto de caché acumulado.

DUIA consolidada de las 4 partes en `DUIA_TP4.md`.