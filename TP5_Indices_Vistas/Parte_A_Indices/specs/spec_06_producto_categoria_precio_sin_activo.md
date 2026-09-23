# spec: indice_producto_categoria_precio_sin_activo

Objetivo: acelerar Q2 de `queries.sql` (productos de una categoria en
un rango de precio), que hoy hace Seq Scan sobre `producto` pese a que
ya existen dos indices sobre `(id_categoria, ...)` en esa tabla.

Consulta afectada:
```sql
SELECT id, nombre, precio_lista, stock
FROM producto
WHERE id_categoria = 1 AND precio_lista BETWEEN 1000 AND 3000
ORDER BY precio_lista;
```

Frecuencia: consulta operativa, uso frecuente (listado de catalogo por
categoria y rango de precio, tipico de una pantalla de busqueda).

Medicion del plan actual (`Parte_A_Indices/plan_q2_antes.txt`):
`Seq Scan on producto`, `Filter: (precio_lista BETWEEN 1000 AND 3000
AND id_categoria = 1)`, `Rows Removed by Filter: 38955`, Execution Time
49.938 ms. (Correccion posterior: una primera corrida, no archivada,
habia dado 29.229 ms y ese numero quedo por error en esta spec; se
corrige al valor de la salida archivada. La comparacion de la decision
no usa este plan sino las 3 rondas de plan_q2_rondas_salida.txt.)

Por que los indices existentes no sirven: `idx_productos_categoria_activo
(id_categoria, activo) WHERE activo = TRUE` e
`idx_producto_categoria_precio_activo (id_categoria, precio_lista DESC)
WHERE activo = TRUE` son ambos **parciales** con la condicion
`WHERE activo = TRUE`. Para que el planificador use un indice parcial,
la consulta tiene que garantizar en su propio `WHERE` que esa condicion
se cumple (o una que la implique logicamente). Q2 no filtra por
`activo` en ningun lado -- pide productos de una categoria y un rango
de precio, sin importar si estan vigentes o no -- asi que ninguno de
los dos indices parciales es aplicable: usarlos daria un resultado
incorrecto (excluiria productos con `activo = FALSE` que Q2 si deberia
devolver).

Columnas candidatas: `id_categoria` (igualdad, alta selectividad
relativa) y `precio_lista` (rango, y ademas resuelve el `ORDER BY` si
el indice ya viene ordenado por esa columna dentro de cada categoria).
A diferencia de los indices existentes, este candidato **no debe ser
parcial** (sin `WHERE activo = TRUE`), porque Q2 no filtra por esa
columna.

Criterio de aceptacion: el plan pasa de `Seq Scan` a `Index Scan` o
`Bitmap Heap Scan` sobre `producto`, con mejora de tiempo real medible
en 3 rondas intercaladas (no una sola corrida), dentro de
`BEGIN...ROLLBACK`.

Nota de contexto importante (antes de medir): en **TP3**
(`TP3_Optimizacion/Parte 2 - Consultas lentas.../tabla_comparativa.md`)
ya se probo un candidato practicamente identico para esta misma
consulta, `idx_producto_categoria_precio (id_categoria, precio_lista)`
sin condicion parcial, y el resultado fue: "Ninguna (levemente mas
lento, dentro del ruido de medicion)" -- `Seq Scan + Sort` (12.384 ms)
vs. `Bitmap Heap Scan + Sort, el Sort NO desaparecio` (12.787 ms). El
indice no se aplico en firme en su momento. Es un antecedente fuerte
para esperar el mismo resultado hoy, pero no reemplaza la medicion real
de 3 rondas que exige esta consigna -- se mide igual.
