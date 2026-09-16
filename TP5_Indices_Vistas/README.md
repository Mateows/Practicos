# TP5 — Índices, Vistas y Vistas Materializadas (Unidad 3, Semana 5)

Continúa el proyecto integrador **Food Store** sobre la base masiva
`foodstore_tp3_carga` (poblada en TP3, ~200.000 pedidos, ~500.000
líneas de detalle).

## Estado actual

- ✅ **Parte A** (plan de indexado) — completa: 3 casos medidos (Q5,
  Q6, Q4), punto 5 (costo de escritura) y punto 6 (descarte por
  sobreindexación) resueltos.
- ⏳ **Parte B** (vistas) — pendiente.
- ⏳ **Parte C** (vista materializada) — pendiente.

## Estructura

```
TP5_Indices_Vistas/
├── schema.sql                # heredado de TP1, sin modificar
├── data.sql                  # referencia al script de carga de TP3
├── queries.sql               # consultas reales de TP3/TP4 usadas como carga de trabajo
├── indices.sql               # CREATE INDEX aceptados y descartados, comentados
├── informe_mediciones.md     # EXPLAIN ANALYZE antes/después de cada caso
├── duia.md                   # bitácora de uso de IA
├── plan_q5_antes.txt         # plan real, Caso 1
├── plan_q6_antes.txt         # plan real, Caso 2
├── plan_q4_antes.txt         # plan real, Caso 3
└── specs/                    # especificaciones entregadas a Kiro
    ├── spec_01_pedido_estado_detalle_join.md
    ├── spec_02_producto_categoria_precio.md
    └── spec_03_pedido_fecha_brin.md
```

## Cómo reproducir las pruebas de la Parte A

### 1. Confirmar que la base existe y tiene el volumen esperado

```bash
psql -U postgres -d foodstore_tp3_carga -c "SELECT count(*) FROM detalle_pedido;"
```

Si no existe, recrearla desde TP3:
```bash
createdb -U postgres -T foodstore_dev foodstore_tp3_carga
psql -U postgres -d foodstore_tp3_carga -f "../TP3_Optimizacion/Parte 1 - Poblar la base masivamente con datos generados por IA/seed_masivo.sql"
```

### 2. Medir un plan "antes" de cualquiera de los 3 casos

```bash
psql -U postgres -d foodstore_tp3_carga -c "EXPLAIN ANALYZE <consulta de queries.sql>"
```

### 3. Probar un índice sin aplicarlo en firme (dentro de transacción reversible)

```bash
psql -U postgres -d foodstore_tp3_carga -c "
BEGIN;
CREATE INDEX ...;
ANALYZE <tabla>;
EXPLAIN ANALYZE <consulta>;
ROLLBACK;
"
```

### 4. Estado real de índices aplicados en firme sobre `foodstore_tp3_carga`

**Dos** de los candidatos probados en la Parte A quedaron aplicados en
firme (ver `indices.sql` y `duia.md` para el detalle completo de por
qué se aceptaron y por qué los demás se descartaron):

```sql
-- Caso 2 (Q6): covering index parcial, mejora ~19% real
CREATE INDEX idx_producto_categoria_precio_activo
    ON producto (id_categoria, precio_lista DESC)
    WHERE activo = TRUE;

-- Caso 3 (Q4): aceptado tras control de ruido de 3 rondas intercaladas
-- (la primera medicion aislada sugeria descartarlo; el control lo revirtio)
CREATE INDEX idx_pedido_fecha_hora_btree
    ON pedido (fecha_hora DESC);
```

Para verificar qué índices existen realmente en la base:
```bash
psql -U postgres -d foodstore_tp3_carga -c "SELECT tablename, indexname FROM pg_indexes WHERE schemaname='public' ORDER BY tablename;"
```

## Flujo de trabajo con IA

Todo el proceso siguió el flujo obligatorio: **Kiro especifica y
propone** (a partir de un spec en `specs/`) → **OpenCode genera y
ejecuta** dentro de `BEGIN...ROLLBACK` → se lee y verifica el
resultado real antes de decidir → se documenta en `duia.md` y
`informe_mediciones.md`, se acepte o se descarte la propuesta.