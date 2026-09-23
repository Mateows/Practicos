# TP5 — Índices, Vistas y Vistas Materializadas (Unidad 3, Semana 5)

Continúa el proyecto integrador **Food Store** sobre la base masiva
`foodstore_tp3_carga` (poblada en TP3, ~200.000 pedidos, 499.571
líneas de detalle).

## Estado actual

- ✅ **Parte A** (plan de indexado) — completa: 4 casos medidos (Q5,
  Q6, Q4, Q2), con 2 índices aplicados en firme (Q6 y Q2), punto 5
  (costo de escritura) y punto 6 (descarte por sobreindexación)
  resueltos. Corregida tras la devolución de la cátedra: Q4 se remidió
  con salida archivada y su índice se descartó; se agregó el caso Q2.
- ✅ **Parte B** (vistas y seguridad por roles) — completa: 5 vistas
  en `vistas.sql`, rol `tp5_reportes` en `seguridad_roles.sql`,
  verificación en `verificacion_vistas.sql`.
- ✅ **Parte C** (vista materializada) — completa: `mv_resumen_ventas_categoria_mes`
  aplicada en firme. Medición archivada: 976.1 ms la consulta directa
  contra 0.054 ms la vista (3 rondas); `REFRESH CONCURRENTLY` ejecutado
  y analizado (ver `informe_mediciones.md`, sección Parte C).

## Estructura

TP5_Indices_Vistas/
├── schema.sql                    # heredado de TP1, sin modificar
├── data.sql                      # referencia al script de carga de TP3
├── queries.sql                   # consultas reales de TP3/TP4
├── indices.sql                   # punto de entrada Parte A (llama a Parte_A_Indices/indices.sql)
├── views.sql                     # punto de entrada Partes B y C, en el orden correcto
├── specs/README.md               # índice de los 6 specs y dónde está cada uno
├── duia.md                       # bitácora de uso de IA
├── informe_mediciones.md         # mediciones de las Partes A y C
├── README.md
├── Parte_A_Indices/
│   ├── indices.sql
│   ├── plan_q4_antes.txt
│   ├── plan_q4_despues.txt
│   ├── medir_q4_rondas.sql
│   ├── plan_q4_rondas_salida.txt
│   ├── correlacion_fecha_hora.sql
│   ├── correlacion_fecha_hora_salida.txt
│   ├── plan_q5_antes.txt
│   ├── plan_q5_despues_workmem.txt
│   ├── plan_q5_despues_indice_descartado.txt
│   ├── medir_q5_rondas.sql
│   ├── plan_q5_rondas_salida.txt
│   ├── medir_indice_redundante_q5.sql
│   ├── plan_q5_indice_redundante.txt
│   ├── plan_detalle_por_id_pedido.txt
│   ├── plan_q6_antes.txt
│   ├── plan_q6_despues.txt
│   ├── plan_q6_con_dos_indices.txt
│   ├── plan_q2_antes.txt
│   ├── medir_q2_rondas.sql
│   ├── plan_q2_rondas_salida.txt
│   ├── medir_escritura_producto_dos_indices.sql
│   ├── medicion_escritura_producto_dos_indices_salida.txt
│   ├── medir_escritura_detalle_pedido.sql
│   ├── medicion_escritura_detalle_pedido_salida.txt
│   └── specs/
├── Parte_B_Vistas/
│   ├── usuarios.sql
│   ├── usuarios_datos.sql
│   ├── vistas.sql
│   ├── seguridad_roles.sql
│   ├── verificacion_vistas.sql
│   ├── verificacion_vistas_salida.txt
│   ├── evidencia_permiso_denegado.txt
│   └── specs/
└── Parte_C_Vista_Materializada/
    ├── vista_materializada.sql
    ├── medir_refresh_parte_c.sql
    ├── medir_refresh_parte_c_salida.txt
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

### 2. Medir un plan "antes" de cualquiera de los 4 casos

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

-- Caso 4 (Q2): indice compuesto NO parcial, ~37% en 3 rondas intercaladas
-- (27.4 ms -> 17.2 ms), Seq Scan -> Bitmap Heap Scan
CREATE INDEX idx_producto_categoria_precio
    ON producto (id_categoria, precio_lista);
```

El B-tree de Q4 (`idx_pedido_fecha_hora_btree`) se había aceptado con
~8.9%, pero al remedirlo con salida archivada no mejoró de forma
consistente (699.9 ms → 708.2 ms) y se **descartó**: se eliminó de la
base y quedó comentado en `indices.sql`.

Para verificar qué índices existen realmente en la base:
```bash
psql -U postgres -d foodstore_tp3_carga -c "SELECT tablename, indexname FROM pg_indexes WHERE schemaname='public' ORDER BY tablename;"
```

### 5. Scripts de medición archivados

Cada script deja su salida completa en el `.txt` indicado. Antes de
correrlos hay que tener en cuenta el estado de la base, porque algunos
crean o borran índices:

- `medir_q4_rondas.sql` → `plan_q4_rondas_salida.txt`. Empieza con
  `DROP INDEX idx_pedido_fecha_hora_btree` y termina dejándolo creado.
  Como ese índice ya se descartó, para reproducirlo hay que crearlo
  antes (`CREATE INDEX idx_pedido_fecha_hora_btree ON pedido (fecha_hora DESC);`)
  y borrarlo después (`DROP INDEX idx_pedido_fecha_hora_btree; ANALYZE pedido;`).
- `medir_q2_rondas.sql` → `plan_q2_rondas_salida.txt`. Crea el índice
  de Q2 dentro de `BEGIN...ROLLBACK` en cada ronda. Como ese índice ya
  está aplicado en firme, para reproducirlo hay que borrarlo antes
  (`DROP INDEX idx_producto_categoria_precio;`) y volver a crearlo después.
- `medir_escritura_producto_dos_indices.sql` →
  `medicion_escritura_producto_dos_indices_salida.txt`. Borra y vuelve a
  crear los dos índices de `producto` en cada ronda y termina con los
  dos creados. Después conviene correr `VACUUM ANALYZE producto;` para
  que Q6 conserve el `Index Only Scan` sin ir al heap.
- `medir_escritura_detalle_pedido.sql` →
  `medicion_escritura_detalle_pedido_salida.txt`. Los `DROP INDEX` van
  dentro de la misma transacción que el `INSERT` y se deshacen con el
  `ROLLBACK`, así que se puede correr sin preparar nada: la base queda
  igual que antes.
- `medir_q5_rondas.sql` → `plan_q5_rondas_salida.txt`. Repite las 9
  corridas del Caso 1 (Baseline, Índice A y `work_mem`, 3 rondas). No
  modifica la base: el índice y el `work_mem` van dentro de
  `BEGIN...ROLLBACK`.

## Flujo de trabajo con IA

Todo el proceso siguió el flujo obligatorio: **Kiro especifica y
propone** (specs en `Parte_A_Indices/specs/`, `Parte_B_Vistas/specs/`
y `Parte_C_Vista_Materializada/specs/`, uno por caso en la Parte A, uno para las 5 vistas de la Parte B y uno
para la Parte C; `spec_06` la
escribió Claude Code y el complemento de `spec_05`, Claude, en la
corrección posterior) → **OpenCode genera y ejecuta** (GitHub Copilot
en la Parte C) dentro de `BEGIN...ROLLBACK` cuando aplica → se lee
y verifica el resultado real antes de decidir → se documenta en
`duia.md` y `informe_mediciones.md`, se acepte o se descarte la
propuesta. En la corrección posterior a la devolución de la cátedra se
usó Claude Code (remedición de Q4, caso Q2 y costo de escritura en
`producto`) y Claude como asistente de chat (auditoría del repositorio,
datos de `usuario`, verificación de vistas, costo de escritura en
`detalle_pedido`, descarte por la PK, remedición de Q5 y medición del
`REFRESH` de la Parte C); `duia.md`
registra el prompt de cada pieza.

## Cómo reproducir/verificar Parte B

```bash
psql -U postgres -d foodstore_tp3_carga -f views.sql
psql -U postgres -d foodstore_tp3_carga -f Parte_B_Vistas/verificacion_vistas.sql
```

`views.sql` corre, en este orden, `usuarios.sql`, `usuarios_datos.sql`,
`vistas.sql`, la vista materializada de la Parte C y
`seguridad_roles.sql`. El orden importa: `seguridad_roles.sql` otorga
`SELECT` también sobre `mv_resumen_ventas_categoria_mes`, así que la
vista materializada tiene que existir antes. Si se corren los archivos
de a uno, hay que respetar ese mismo orden. En una base que ya tiene
todo aplicado, el `CREATE MATERIALIZED VIEW` y su índice dan
`already exists` y se pueden ignorar: el resto se vuelve a aplicar sin
problema, incluidos los `REFRESH` de la vista materializada.

El último script muestra las columnas de `v_usuario_publico` (sin
`contrasena`), consulta las vistas con `SET ROLE tp5_reportes` y
devuelve 0 filas en cada bloque de equivalencia (punto 3 de la
consigna). Al final, la sección 6 resume para cada vista las
diferencias con `EXCEPT` y la cantidad de filas de cada lado: tiene que
dar `diferencias = 0` y `filas_vista = filas_manual`. La salida
completa está en `Parte_B_Vistas/verificacion_vistas_salida.txt`. El
acceso directo a `usuario` está comentado en el script; su fallo por
falta de privilegios quedó en `evidencia_permiso_denegado.txt`.

## Cómo reproducir Parte C

```bash
psql -U postgres -d foodstore_tp3_carga -f Parte_C_Vista_Materializada/vista_materializada.sql
```

Para medir, correr `Parte_C_Vista_Materializada/medir_refresh_parte_c.sql`:
compara la consulta directa con la vista, el `REFRESH` normal con
`REFRESH CONCURRENTLY`, muestra los bloqueos de cada uno y el dato
desactualizado entre dos `REFRESH`, y deja la base igual que antes. La
salida archivada está en `medir_refresh_parte_c_salida.txt` y el
análisis, en `informe_mediciones.md`, sección Parte C.