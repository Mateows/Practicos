# TP5 — Índices, Vistas y Vistas Materializadas (Unidad 3, Semana 5)

Continúa el proyecto integrador **Food Store** sobre la base masiva
`foodstore_tp3_carga` (poblada en TP3, ~200.000 pedidos, 499.571
líneas de detalle).

## Estado actual

- ✅ **Parte A** (plan de indexado) — completa: 3 casos medidos (Q5,
  Q6, Q4), punto 5 (costo de escritura) y punto 6 (descarte por
  sobreindexación) resueltos.
- ✅ **Parte B** (vistas y seguridad por roles) — completa: 5 vistas
  en `vistas.sql`, rol `tp5_reportes` en `seguridad_roles.sql`,
  verificación en `verificacion_vistas.sql`.
- ✅ **Parte C** (vista materializada) — completa: `mv_resumen_ventas_categoria_mes`
  aplicada en firme, mejora medida ~8468x (618ms → 0.073ms).

## Estructura

TP5_Indices_Vistas/
├── schema.sql                    # heredado de TP1, sin modificar
├── data.sql                      # referencia al script de carga de TP3
├── queries.sql                   # consultas reales de TP3/TP4
├── duia.md                       # bitácora de uso de IA
├── informe_mediciones.md         # EXPLAIN ANALYZE antes/después (Parte A)
├── README.md
├── Parte_A_Indices/
│   ├── indices.sql
│   ├── plan_q4_antes.txt
│   ├── plan_q4_despues.txt
│   ├── plan_q5_antes.txt
│   ├── plan_q5_despues_workmem.txt
│   ├── plan_q5_despues_indice_descartado.txt
│   ├── plan_q6_antes.txt
│   ├── plan_q6_despues.txt
│   └── specs/
├── Parte_B_Vistas/
│   ├── usuarios.sql
│   ├── vistas.sql
│   ├── seguridad_roles.sql
│   ├── verificacion_vistas.sql
│   └── specs/
└── Parte_C_Vista_Materializada/
    ├── vista_materializada.sql
    ├── README.md
    └── specs/

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
-- Caso 2 (Q6): covering index parcial, mejora final ~41% real (271.2s -> 158.7s tras
-- VACUUM ANALYZE; medicion inicial fue ~19%)
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
propone** (specs en `Parte_A_Indices/specs/`, `Parte_B_Vistas/specs/`
y `Parte_C_Vista_Materializada/specs/`, uno por pieza) → **OpenCode
genera y ejecuta** dentro de `BEGIN...ROLLBACK` cuando aplica → se lee
y verifica el resultado real antes de decidir → se documenta en
`duia.md` y `informe_mediciones.md`, se acepte o se descarte la
propuesta.

## Cómo reproducir/verificar Parte B

```bash
psql -U postgres -d foodstore_tp3_carga -f Parte_B_Vistas/usuarios.sql
psql -U postgres -d foodstore_tp3_carga -f Parte_B_Vistas/vistas.sql
psql -U postgres -d foodstore_tp3_carga -f Parte_B_Vistas/seguridad_roles.sql
psql -U postgres -d foodstore_tp3_carga -f Parte_B_Vistas/verificacion_vistas.sql
```

El último script debe: mostrar las columnas de `v_usuario_publico`
sin `contrasena`, devolver 0 filas en cada bloque de equivalencia
(punto 3 de la consigna), y fallar solo en la consulta comentada
final (`SELECT * FROM usuario` bajo `SET ROLE`).

## Cómo reproducir Parte C

```bash
psql -U postgres -d foodstore_tp3_carga -f Parte_C_Vista_Materializada/vista_materializada.sql
```

Para comparar tiempos, correr `EXPLAIN ANALYZE` de la consulta base
(ver `Parte_C_Vista_Materializada/README.md`) contra
`SELECT * FROM mv_resumen_ventas_categoria_mes;`.