# DUIA - TP4 Parte 2

## Declaracion de Uso de Inteligencia Artificial

**Materia:** Base de Datos II  
**Trabajo practico:** TP4 - Unidad 2: Reportes analiticos sobre Food Store  
**Parte:** 2 - Lectura critica de planes de JOIN  
**Proyecto:** FoodStore  
**Alumnos:** Mateo Lautaro Liendo, Lucas Avila y Amanda Pagano  
**Comision:** 4  
**Docente:** Sergio Neira  
**Motor objetivo:** PostgreSQL 17  

## Registro de usos de IA

| Herramienta | Para que se uso | Prompt o especificacion | Decision y verificacion |
|---|---|---|---|
| Kiro | Generar una explicacion en lenguaje natural del plan real de la Consulta A, identificando los nodos de `JOIN`, el uso del indice, el paralelismo y la diferencia entre costo estimado y tiempo real. | Se proporciono el plan `EXPLAIN ANALYZE` sin contexto adicional y se solicito una explicacion nodo por nodo, incluyendo las entradas externa e interna de cada `Hash Join`. | La explicacion se uso como hipotesis de analisis. Cada afirmacion se contrasto con el texto del plan antes de incorporarla al informe. |
| GitHub Copilot - Agente de Visual Studio Code | Organizar y revisar la lectura critica, comparando la respuesta de Kiro con la evidencia del plan y corrigiendo imprecisiones tecnicas. | Se solicito estructurar la explicacion, completar la tabla de afirmaciones y verificar especialmente `Heap Fetches: 0`, `Workers Planned/Launched` y `cost` frente a `Execution Time`. | Se aceptaron las afirmaciones respaldadas por el plan. Se corrigio que `Heap Fetches: 0` depende tambien del mapa de visibilidad y que el costo del optimizador no representa milisegundos. |

## Criterio de aceptacion

La IA asistio en la interpretacion y organizacion del material, pero la conclusion final se tomo mediante la lectura del plan real. No se aceptaron afirmaciones automaticamente: se verificaron los tres niveles de `Hash Join`, el `Parallel Index Only Scan`, los dos workers lanzados, `Heap Fetches: 0` y la diferencia entre costo estimado y tiempo real.
