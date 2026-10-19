# Parte 2 - Lectura crítica del plan de la Consulta A

## 1. Objetivo

Se seleccionó el plan optimizado de la Consulta A porque contiene tres niveles de `JOIN`, paralelismo, agregación, ordenamiento y un `Index Only Scan`. Esto permite contrastar varias afirmaciones de la explicación generada por IA con la evidencia concreta del plan real.

## 2. Solicitud realizada a la IA

Se proporcionó el siguiente plan EXPLAIN ANALYZE a una IA sin contexto adicional:

```
Incremental Sort (cost=15617.57..26686.93 rows=61812 width=166)
  -> Finalize GroupAggregate (cost=15589.45..23621.14 rows=61812)
       -> Gather Merge (cost=15589.45..22178.86 rows=51510)
            Workers Planned: 2  Workers Launched: 2
            -> Partial GroupAggregate (cost=14589.43..15233.31 rows=25755)
                 -> Sort (cost=14589.43..14653.82 rows=25755)
                      -> Hash Join (cost=3557.05..10851.05 rows=25755)
                           Hash Cond: (dp.id_producto = p.id)
                           -> Parallel Hash Join (cost=1825.22..8604.12 rows=51509)
                                Hash Cond: (dp.id_pedido = pdo.id)
                                -> Parallel Seq Scan on detalle_pedido dp
                                   actual rows=166203 loops=3
                                -> Parallel Hash
                                     -> Parallel Index Only Scan using idx_tp4_a_estado_id on pedido pdo
                                          Index Cond: (pdo.estado = 'ENTREGADO')
                                          actual rows=49633 loops=1
                                          Heap Fetches: 0
                           -> Hash
                                -> Hash Join (cost=16.66..1419.31 rows=25002)
                                     Hash Cond: (p.id_categoria = c.id)
                                     -> Seq Scan on producto p
                                        actual rows=50003 loops=3
                                     -> Seq Scan on categoria c
                                        Filter: c.activo
                                        actual rows=2 loops=3
```

**Pregunta:** Explica este plan nodo por nodo, identificando:
1. Cuál es la tabla externa e interna en cada join.
2. Qué índice se usa y por qué.
3. Por qué hay 2 workers planificados pero aparentemente se lanzan también (Workers Launched: 2).
4. Qué significa "Heap Fetches: 0" en el Index Only Scan.
5. El costo total estimado vs. el tiempo de ejecución real (164.254 ms).

---

## 3. Explicación organizada de la IA

### 3.1 Flujo general

El plan trabaja con `detalle_pedido`, `pedido`, `producto` y `categoria`. Primero une los detalles con los pedidos entregados; después une ese resultado con los productos y, finalmente, con las categorías activas. Luego realiza una agregación parcial y final, y ordena el resultado.

### 3.2 Nodos de join

**Join 1: `Parallel Hash Join` entre `detalle_pedido` y `pedido`**

- Lado externo o entrada izquierda: `detalle_pedido dp`, leído mediante `Parallel Seq Scan`.
- Lado interno o build side: `pedido pdo`, cuyos registros entregados se cargan en una estructura hash mediante `Parallel Hash`.
- Condición: `dp.id_pedido = pdo.id`.

**Join 2: `Hash Join` entre el resultado anterior y `producto`**

- Lado externo: resultado del primer join.
- Lado interno o build side: `producto p`, leído dentro del `Hash`.
- Condición: `dp.id_producto = p.id`.

**Join 3: `Hash Join` entre `producto` y `categoria`**

- Lado externo: `producto p`.
- Lado interno o build side: `categoria c`, filtrada por `c.activo` y cargada en el hash.
- Condición: `p.id_categoria = c.id`.

En estos `Hash Join`, “externo” e “interno” describen el rol de cada entrada del operador, no necesariamente el orden físico en que se leyeron las tablas. La entrada interna es la que se utiliza para construir el hash y la externa es la que se compara contra él.

### 3.3 Índice utilizado

El plan utiliza `idx_tp4_a_estado_id ON pedido (estado, id) INCLUDE (fecha_hora)` mediante un `Parallel Index Only Scan`. La condición `pdo.estado = 'ENTREGADO'` puede utilizar la primera columna del índice, mientras que `id` y `fecha_hora` están disponibles en el propio índice.

El índice fue creado dentro de una prueba transaccional y luego se ejecutó `ROLLBACK`, por lo que no quedó aplicado permanentemente.

### 3.4 Paralelismo

`Workers Planned: 2` indica que el planificador decidió usar dos procesos auxiliares. `Workers Launched: 2` confirma que ambos fueron efectivamente iniciados. El proceso líder también puede participar en el trabajo, por eso en el `Parallel Seq Scan` aparece `loops=3`: dos workers más el proceso líder.

### 3.5 `Heap Fetches: 0`

El `Index Only Scan` no tuvo que consultar la tabla heap para obtener las filas. Esto es posible porque las columnas necesarias están disponibles en el índice y las páginas correspondientes estaban marcadas como visibles en el mapa de visibilidad; por eso no fueron necesarios fetches adicionales al heap.

El dato no significa simplemente que todo `Index Only Scan` evita siempre el heap: si una página no estuviera marcada como totalmente visible, PostgreSQL podría tener que consultar el heap aunque el índice contuviera las columnas necesarias.

### 3.6 Costos y tiempo real

El costo del nodo raíz es `cost=15617.57..26686.93`. El primer valor es el costo estimado hasta producir la primera fila y el segundo es el costo estimado para producir todas las filas. Son unidades internas del optimizador, no milisegundos.

El tiempo real fue `Execution Time: 164.254 ms`. Ambos valores no se convierten directamente: el costo sirve para comparar planes y el tiempo depende, entre otros factores, de los datos, la caché, el hardware y la carga del sistema.

## 4. Tabla de lectura crítica

| Afirmación de la IA | ¿Correcta? | Corrección / evidencia del plan real |
|---|---|---|
| En el primer `Parallel Hash Join`, `detalle_pedido` es la entrada externa y `pedido` la interna. | Sí | `detalle_pedido` aparece como entrada izquierda y `pedido` dentro de `Parallel Hash`, que es el lado que construye la tabla hash. |
| En el segundo join, el resultado del join anterior se combina con `producto`. | Sí | El `Hash Join` tiene como entrada izquierda el resultado de `dp` con `pdo` y como entrada derecha el hash construido desde `producto`. |
| En el tercer join, `categoria` se filtra por `c.activo` antes de construir el hash. | Sí | El plan muestra `Seq Scan on categoria c` con `Filter: c.activo` dentro del nodo `Hash`. |
| El índice se usa porque `estado` es la primera columna de `idx_tp4_a_estado_id`. | Sí | El plan muestra `Index Cond: (pdo.estado = 'ENTREGADO')`, compatible con el primer atributo del índice. |
| `Heap Fetches: 0` significa que el índice es covering y no se accedió al heap. | Parcialmente | El índice contiene las columnas necesarias, pero el cero también depende de que las páginas estén visibles según el mapa de visibilidad. |
| Se planificaron y lanzaron dos workers. | Sí | El plan muestra explícitamente `Workers Planned: 2` y `Workers Launched: 2`. |
| El costo `26686.93` equivale a 26.686 milisegundos. | No | El costo está expresado en unidades internas del optimizador. El tiempo medido por `EXPLAIN ANALYZE` fue `164.254 ms`, sin conversión directa entre ambos. |

## 5. Conclusiones para la defensa

- El plan utiliza `Hash Join` y `Parallel Hash Join`; no utiliza `Nested Loop` ni `Merge Join`.
- La cadena principal de joins es `detalle_pedido` + `pedido` → `producto` → `categoria`.
- El índice probado cambió el acceso a `pedido` a `Parallel Index Only Scan`, pero no cambió el algoritmo global de los joins.
- El índice permitió leer los datos necesarios sin fetches al heap en esta ejecución y contribuyó a reducir el tiempo observado de `699.550 ms` a `164.254 ms`.
- La medición debe interpretarse como una observación de esa ejecución concreta, porque los tiempos pueden variar por caché y carga del sistema.
