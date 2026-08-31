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
