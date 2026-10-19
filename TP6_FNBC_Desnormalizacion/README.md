# TP6 — FNBC y desnormalización controlada

Este directorio reúne el análisis, los scripts de validación y las evidencias del TP6 sobre FoodStore.

## Índice

- [Informe final](informe_final_tp6.md)
- [Informe final en PDF — versión corregida con borrado lógico](informe_final_tp6.pdf)
- [Parte 1 — FNBC](#parte-1--fnbc)
- [Parte 2 — Desnormalización controlada](#parte-2--desnormalización-controlada)
- [Seguridad y ejecución](#seguridad-y-ejecución)
- [Resultados y límites](#resultados-y-límites)

## Parte 1 — FNBC

- [Script de normalización](Parte1_FNBC/tp_fnbc_control_lote.sql)
- [Informe de Parte 1](Parte1_FNBC/informe_parte1_fnbc.md)
- [Evidencia de ejecución](Parte1_FNBC/evidencias/evidencia_fnbc_20261008_222128.txt)

Se analiza la relación de control de lotes con dependencias LD → C y C → D. Sus claves candidatas son LD y LC; cumple 3FN y viola FNBC.

La descomposición en responsable_deposito y control_lote tiene reunión sin pérdida. La dependencia LD → C no queda preservada mediante las restricciones locales y requeriría un control adicional entre tablas.

### Requisitos de Parte 1

El script requiere `public.usuario` con `id BIGINT GENERATED ALWAYS AS IDENTITY`. Comprueba la ausencia de conflictos con los objetos que crea y con los IDs 801 y 802 y los correos de los usuarios de prueba. Se detiene ante conflictos; no reutiliza ni sobrescribe objetos o usuarios existentes.

## Parte 2 — Desnormalización controlada

- [Medición inicial de la consulta normalizada](Parte2_Desnormalizacion/medir_top_categorias_antes.sql)
- [Script de desnormalización, auditoría y mediciones](Parte2_Desnormalizacion/tp_desnormalizacion_top_categorias.sql)
- [Informe de Parte 2](Parte2_Desnormalizacion/informe_parte2_desnormalizacion.md)
- [Evidencia de la medición inicial corregida con borrado lógico](Parte2_Desnormalizacion/evidencias/evidencia_top_antes_logico_20261009_092704.txt)
- [Evidencia corregida de desnormalización, pruebas y comparación](Parte2_Desnormalizacion/evidencias/evidencia_top_desnormalizacion_logico_20261009_092837.txt)
- [Antecedente histórico de la medición inicial — sin filtros lógicos](Parte2_Desnormalizacion/evidencias/evidencia_top_antes_20261008_225517.txt)
- [Antecedente histórico de desnormalización — sin filtros lógicos](Parte2_Desnormalizacion/evidencias/evidencia_top_desnormalizacion_20261008_232126.txt)

### Capturas históricas — versión sin filtros lógicos

- [Plan normalizado — ronda 1](Parte2_Desnormalizacion/capturas/antes_ronda1.png)
- [Plan desnormalizado — ronda 1](Parte2_Desnormalizacion/capturas/despues_ronda1.png)
- [Auditoría y pruebas de sincronización](Parte2_Desnormalizacion/capturas/auditoria.png)

### Capturas del ensayo corregido — 09/10/2026

- [Plan normalizado corregido — ronda 1](Parte2_Desnormalizacion/capturas/antes_logico_ronda1.png): filtros de borrado lógico, **49.291 ms** y **shared hit=10942**.
- [Plan desnormalizado corregido — ronda 1](Parte2_Desnormalizacion/capturas/despues_logico_ronda1.png): ambos filtros, **1.980 ms** y **shared hit=565**.
- [Auditoría y equivalencia corregidas](Parte2_Desnormalizacion/capturas/auditoria_logico.png): pruebas secuenciales superadas, auditoría, diferencias del top y EXCEPT ALL de filas vacíos.

El **ROLLBACK** visible en `auditoria_logico.png` corresponde a **ROLLBACK TO SAVEPOINT**, que descarta las filas de prueba. El **ROLLBACK final** de la transacción está registrado en el [TXT completo del ensayo corregido](Parte2_Desnormalizacion/evidencias/evidencia_top_desnormalizacion_logico_20261009_092837.txt).

La adaptación agrega fecha_hora_pedido_cache, id_categoria_cache y pedido_eliminado_cache a detalle_pedido, con sincronización mediante los disparadores existentes y el mismo índice sobre la fecha copiada. Conserva el JOIN con categoria y el cálculo SUM(subtotal).

La fecha de medición es 2026-06-25 en America/Buenos_Aires, mediante un intervalo diario semiabierto. El ensayo incorpora pedido.eliminado y detalle_pedido.eliminado, ambos BOOLEAN NOT NULL DEFAULT FALSE, como estados propios independientes. pedido_eliminado_cache copia exclusivamente el estado del pedido: restaurarlo no restaura detalles eliminados individualmente. La consulta normalizada filtra ambos estados propios; la desnormalizada filtra el estado propio del detalle y el cache del pedido, sin volver a unir pedido. No se agregan filtros por estado o activo.

### Requisitos de Parte 2

Parte 2 requiere el esquema FoodStore y la carga masiva utilizada: 200005 pedidos, 499571 detalles, 50003 productos y 2 categorías. Las mediciones publicadas corresponden al **25/06/2026**; otro conjunto de datos puede producir resultados y tiempos diferentes. Estos conteos describen la carga medida, no una aserción de conteos implementada en los scripts.

El script de desnormalización comprueba que pedido, detalle_pedido, producto, categoria y cliente existan como tablas ordinarias sin RLS, que `session_replication_role` sea `origin` y que no existan conflictos con las columnas, funciones, triggers, restricciones, índice o vistas temporales que utiliza. También verifica la existencia de los padres y categorías de los detalles, y el modo habilitado de los triggers de usuario que pudiera encontrar. Las pruebas requieren un cliente existente e IDs y nombres de prueba disponibles.

La carga inicial no exige que la cantidad de un detalle histórico sea menor o igual al stock actual. No se modifican cantidades ni stock de filas originales ni se instalan los triggers de TP2. Su presencia en scripts del repositorio no implica que estén instalados en la copia utilizada.

## Seguridad y ejecución

Antes de cualquier ejecución, revisar:

- [AGENTS.md del repositorio](../AGENTS.md)
- [Protocolo de seguridad](../protocolo_seguridad.md)

Todas las pruebas se realizan exclusivamente sobre foodstore_copia_trabajo. No deben ejecutarse sobre foodstore_dev.

Los scripts que contienen DDL requieren un respaldo previo conforme al protocolo. Los comandos siguientes se muestran para una ejecución futura revisada y autorizada; no crean la copia ni generan el respaldo.

### Comandos desde la raíz del repositorio

Parte 1:

```bash
psql -X -h localhost -U postgres -d foodstore_copia_trabajo -v ON_ERROR_STOP=1 -P pager=off -f "TP6_FNBC_Desnormalizacion/Parte1_FNBC/tp_fnbc_control_lote.sql"
```

Medición inicial de Parte 2:

```bash
psql -X -h localhost -U postgres -d foodstore_copia_trabajo -v ON_ERROR_STOP=1 -P pager=off -f "TP6_FNBC_Desnormalizacion/Parte2_Desnormalizacion/medir_top_categorias_antes.sql"
```

Validación de la desnormalización:

```bash
psql -X -h localhost -U postgres -d foodstore_copia_trabajo -v ON_ERROR_STOP=1 -P pager=off -f "TP6_FNBC_Desnormalizacion/Parte2_Desnormalizacion/tp_desnormalizacion_top_categorias.sql"
```

Los tres scripts utilizan ON_ERROR_STOP y terminan con ROLLBACK. La medición inicial corregida de Parte 2 también contiene DDL dentro de una transacción explícita y requiere respaldo previo; ya no abre una transacción READ ONLY.

Si una ejecución se detiene por un error antes del ROLLBACK final, debe descartarse la transacción mediante ROLLBACK en la misma sesión o cerrando la conexión. No reemplazar el cierre por COMMIT.

Ambos scripts de Parte 2 toman bloqueos ACCESS EXCLUSIVE durante el ensayo. Pueden impedir temporalmente el acceso de otras sesiones a las tablas involucradas; corresponden a pruebas de laboratorio.

## Resultados y límites

Parte 1 reconstruyó las tres filas originales, con diferencias vacías en ambos sentidos y conteos 3/2/3/3.

En la ejecución corregida de Parte 2 del 09/10/2026, ambas consultas devolvieron:

| Categoría | Total vendido |
|---|---:|
| Bebidas | 5589534.40 |
| Pizzas | 5215387.22 |

La comparación directa corregida registró:

| Medición | Normalizada (ms) | Desnormalizada (ms) |
|---|---:|---:|
| Ronda 1 | 49.291 | 1.980 |
| Ronda 2 | 47.556 | 1.323 |
| Promedio | 48.4235 | 1.6515 |

Los shared hit fueron **10942 y 565**. Sobre los promedios, la reducción temporal es **96.59 %** y el cociente normalizada/desnormalizada es **29.32**, atribuibles al conjunto columnas más índice. La medición inicial corregida de **62.538 ms** es una referencia previa a las copias y no interviene en esos cálculos. Los shared hit representan accesos en caché, no lecturas físicas ni páginas únicas.

La auditoría completa, incluida la comparación de pedido_eliminado_cache y los registros eliminados, el EXCEPT bidireccional del top y el EXCEPT ALL bidireccional de filas participantes devolvieron cero filas. Las pruebas secuenciales de las cuatro combinaciones, restauraciones independientes, inserción bajo pedido eliminado, traslado a pedido vigente y retorno, cambio simultáneo de fecha y eliminado y corrección de cache arbitrario fueron superadas, junto con las pruebas anteriores de sincronización y DELETE/CASCADE. Los fixtures se deshicieron mediante ROLLBACK TO SAVEPOINT antes de ANALYZE y las mediciones.

Ambos ensayos corregidos de Parte 2 finalizaron con ROLLBACK. Según el control posterior informado por el grupo, quedaron **cero columnas añadidas** y se conservaron **200005 pedidos y 499571 detalles**. Ese control posterior no figura en los dos TXT de ejecución.

### Antecedentes históricos de Parte 2 — sin filtros lógicos, 08/10/2026

La comparación anterior registró:

| Medición | Normalizada (ms) | Desnormalizada (ms) |
|---|---:|---:|
| Ronda 1 | 42.807 | 1.855 |
| Ronda 2 | 41.920 | 1.815 |
| Promedio | 42.3635 | 1.835 |

Los buffers históricos shared hit fueron 10942 para la normalizada y 564 para la desnormalizada. La reducción temporal fue 95.67 % y el cociente 23.09, correspondientes al conjunto de dos columnas más índice, sin filtros lógicos. Los 47.151 ms de la medición inicial histórica no intervinieron en ese cálculo. Estos resultados se conservan como antecedentes, sin mezclarlos con las rondas corregidas.

La auditoría y el EXCEPT del top históricos también devolvieron cero filas, y las pruebas secuenciales anteriores se deshicieron mediante SAVEPOINT antes de medir. Esos antecedentes no validan por sí solos las pruebas nuevas de borrado lógico.

### Límites del ensayo

La concurrencia entre sesiones no fue probada. La sincronización soporta READ COMMITTED y puede generar interbloqueos que requieran reintentar la transacción completa.

Las mediciones se realizaron dentro de la transacción de carga, después de indexar y ejecutar ANALYZE, con calentamiento previo y orden alternado. No se ejecutó VACUUM. Solo existen dos categorías y se realizaron dos rondas; los resultados no constituyen un benchmark exhaustivo. El costo adicional de escritura no fue cuantificado.

Ambos scripts de implementación terminaron con ROLLBACK: la migración de Parte 1 y la instalación de Parte 2 no quedaron persistidas.

Las rutas antiguas que aparecen dentro de evidencias y capturas se conservan como parte del registro histórico de ejecución.
