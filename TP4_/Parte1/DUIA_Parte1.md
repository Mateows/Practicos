# DUIA - TP4 Parte 1

## Declaracion de Uso de Inteligencia Artificial

**Materia:** Base de Datos II  
**Trabajo practico:** TP4 - Unidad 2: Reportes analiticos sobre Food Store  
**Parte:** 1 - Laboratorio: consultas analiticas lentas  
**Proyecto:** FoodStore  
**Alumnos:** Mateo Lautaro Liendo, Lucas Avila y Amanda Pagano  
**Comision:** 4  
**Docente:** Sergio Neira  
**Motor objetivo:** PostgreSQL 17  
**Base de trabajo:** `foodstore_tp3_carga`

## Registro de usos de IA

| Herramienta | Para que se uso | Prompt o especificacion | Decision y verificacion |
|---|---|---|---|
| Kiro / GitHub Copilot | Analizar los planes iniciales de las consultas A y B e identificar algoritmos de JOIN, nodos costosos y propuestas posibles. | Se proporcionaron los planes reales de `EXPLAIN (ANALYZE, BUFFERS, VERBOSE)` sobre la base masiva y se pidio distinguir `Hash Join`, `Parallel Hash Join`, `Nested Loop` y `Merge Join`, junto con `cost`, `actual rows`, `actual time` y `Execution Time`. | Se conservaron las propuestas solo como hipotesis de prueba. La medicion real tuvo prioridad sobre la explicacion de la IA. |
| Kiro / GitHub Copilot | Revisar la consistencia entre consultas, planes, nombres de indices, tiempos y documentacion de TP4. Tambien se uso para ejecutar las mediciones reversibles y guardar los resultados. | Se solicito comparar los planes antes/despues, probar indices con `BEGIN`, `CREATE INDEX`, `ANALYZE`, `EXPLAIN ANALYZE` y `ROLLBACK`, y no aplicar cambios permanentes. | Se verifico que la base correcta era `foodstore_tp3_carga`, con 50.003 productos, 20.003 clientes, 200.005 pedidos y 498.608 detalles. Los indices temporales no quedaron aplicados. |
| Kiro / GitHub Copilot | Probar la propuesta de la Consulta A. | Se probo `idx_tp4_a_estado_id ON pedido (estado, id) INCLUDE (fecha_hora)` dentro de una transaccion reversible. | **Aceptada para la practica:** el plan uso `Parallel Index Only Scan`, con `Heap Fetches: 0`, mantuvo 2 workers y el tiempo observado paso de `699.550 ms` a `164.254 ms`. Los JOIN siguieron siendo `Hash Join` y `Parallel Hash Join`. |
| Kiro / GitHub Copilot | Probar la propuesta de la Consulta B y comparar su efecto con el plan inicial. | Se probo `idx_tp4_b_no_cancelado ON pedido (id) INCLUDE (id_cliente) WHERE estado <> 'CANCELADO'` dentro de una transaccion reversible. | **Rechazada:** el indice no fue utilizado; PostgreSQL mantuvo `Parallel Seq Scan`, los JOIN no cambiaron y el tiempo paso de `304.753 ms` a `305.604 ms`. |
| Kiro / GitHub Copilot | Revisar la documentacion final de la Parte 1. | Se compararon los cuatro archivos de plan con la tabla de resultados y se corrigieron la base, los nombres de indices, los tiempos y las decisiones. | Se acepto la documentacion luego de comprobar que coincidiera con los planes guardados. |

## Criterio de aceptacion

El equipo reviso las propuestas, ejecuto las mediciones y tomo la decision final. La IA asistio en el analisis, la prueba y la documentacion, pero ninguna propuesta se acepto solo por reducir el costo estimado.

La Consulta A se acepta porque el indice fue utilizado, elimino los accesos al heap en ese nodo, conservo el paralelismo y mejoro el tiempo observado. La Consulta B se rechaza porque el indice fue ignorado y no produjo una mejora real.

Todas las pruebas de indices terminaron con `ROLLBACK`; por lo tanto, no dejaron cambios permanentes en la base durante este laboratorio.
