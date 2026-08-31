# TP2 — Concurrencia e IA

Trabajo Práctico de Laboratorio — Base de Datos II (UTN FRM)
Unidad 1 · Integridad, Transacciones y Concurrencia — Semana 2

Alumnos: Liendo Mateo, Avila Lucas, Pagano Amanda — Comisión 4
Trabajo grupal, sobre el esquema del proyecto integrador FoodStore (ver `TP1_FoodStore/`).

## Entorno de trabajo

- PostgreSQL 17.11, instalado y administrado localmente por línea de comandos (`psql`, Git Bash).
- Base de desarrollo: `foodstore_dev`, cargada desde `TP1_FoodStore/schema.sql`.
- Base de trabajo/pruebas: `foodstore_copia_trabajo`, copia exacta de `foodstore_dev` usada para todas las pruebas riesgosas.
- Herramientas de IA: OpenCode (Parte 1), Claude (Parte 2) y Kiro (Parte 3 y steering docs de contexto del proyecto).

## Estructura de esta carpeta

```
TP2_Concurrencia_IA/
├── parte1/
│   ├── restricciones_integridad.sql           # Triggers de integridad generados con OpenCode
│   ├── respaldo_foodstore_copia_trabajo.sql   # Respaldo previo a aplicar los triggers (protocolo de seguridad)
│   └── DUIA_parte1.md                         # Declaración de Uso de IA — Parte 1
├── parte2/
│   ├── informe_concurrencia.md                # Informe de laboratorio de concurrencia
│   └── DUIA_Parte2.md                         # Declaración de Uso de IA — Parte 2
└── parte3/
    ├── ejercicio_lectura_critica.md           # Análisis y corrección de scripts SQL con errores
    └── DUIA_Parte3.md                         # Declaración de Uso de IA — Parte 3
```

## Contenido por parte

- **Parte 0** — Protocolo de seguridad: ver `protocolo_seguridad.md` en la raíz del repositorio.

- **Parte 1** — Integridad versionada con OpenCode (`parte1/`): tres restricciones de negocio garantizadas en el motor mediante triggers PL/pgSQL:
  1. Un pedido en estado `ENTREGADO` o `CANCELADO` no puede transicionar a ningún otro estado (estado final irreversible).
  2. La `fecha_hora` de un pedido no puede ser posterior al momento actual.
  3. La `cantidad` de una línea de `detalle_pedido` no puede superar el `stock` disponible del producto.

  Cada restricción se probó dentro de una transacción sobre `foodstore_copia_trabajo`, con casos inválidos (que deben fallar) y un caso válido (que debe aplicarse sin problema), antes de confirmar con `COMMIT`.

- **Parte 2** — Laboratorio de anomalías de concurrencia (`parte2/`): reproducción de tres escenarios con dos sesiones `psql` concurrentes sobre `foodstore_copia_trabajo`:
  1. Lectura no repetible — demostrada en `READ COMMITTED`, resuelta con `REPEATABLE READ`.
  2. Lectura fantasma — demostrada en `READ COMMITTED`, resuelta con `SERIALIZABLE`.
  3. Espera por bloqueo (`FOR UPDATE`) — demostrada con dos sesiones sobre la misma fila de `producto`.

  Para cada escenario se verificó la explicación de la IA en el motor real.

- **Parte 3** — Lectura crítica de scripts SQL (`parte3/`): análisis de dos scripts proporcionados por la cátedra con errores de lógica:
  1. `UPDATE` sin cláusula `WHERE` que afecta todas las filas de la tabla.
  2. `DELETE` con `NOT IN` que falla silenciosamente ante valores `NULL` en la subconsulta.

  Para cada script se documenta el efecto real, por qué no coincide con la intención declarada, y la versión corregida.
