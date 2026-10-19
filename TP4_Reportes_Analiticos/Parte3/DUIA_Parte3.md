# DUIA — TP4 Parte 3

**Materia:** Base de Datos II
**Trabajo práctico:** TP4 — Unidad 2: Reportes analíticos sobre Food Store
**Parte:** 3 — Consultas resumen, rankings y subconsultas bajo especificación precisa
**Alumnos:** Mateo Lautaro Liendo, Lucas Avila y Amanda Pagano  
**Comision:** 4 
**Proyecto:** Food Store
**Docente:** Sergio Neira 
**Motor:** PostgreSQL 17
**Base de trabajo:** `foodstore_tp3_carga`

## Registro de usos de IA

| Herramienta | Para qué se usó | Prompt / spec (resumen) | Se aceptó / se descartó |
|---|---|---|---|
| Kiro | Generar la Consulta A (ranking con función de ventana) v1 y una v2 con estructura distinta, y verificar equivalencia con EXCEPT | Spec precisa: ranking de clientes por gasto (`DENSE_RANK`), sin filtro de borrado lógico en cliente/detalle_pedido (no existe esa columna en el esquema), empates comparten puesto | La primera V2 propuesta (subconsulta correlacionada con `COUNT(*)`) fue **rechazada**: el EXCEPT dio 19.433 filas de diferencia — no era equivalente a V1. Causa: `COUNT(*)` replica la semántica de `RANK()` (deja huecos tras un empate), no de `DENSE_RANK()`. Se corrigió a `COUNT(DISTINCT total_gastado)`, y el EXCEPT confirmó 0 filas en ambos sentidos — **aceptada** |
| Kiro | Generar la Consulta B (subconsulta correlacionada) v1 y v2 (JOIN con promedio pre-agregado), verificar equivalencia | Spec precisa: productos activos con precio mayor al promedio de su categoría activa | **Aceptada de entrada:** 0 filas de diferencia en el EXCEPT en ambos sentidos. V1 tardó minutos por ser O(n²) sobre 50k productos; V2 (pre-agregada) resolvió en segundos — mismo resultado, rendimiento muy distinto |

## Criterio de aceptación

Ninguna versión se dio por buena solo porque "corría sin error": las dos
consultas se verificaron formalmente con `EXCEPT` en ambos sentidos
contra la base masiva `foodstore_tp3_carga`. Cuando la primera V2 de la
Consulta A no resultó equivalente (19.433 filas de diferencia), no se
descartó el hallazgo ni se maquilló el resultado — se diagnosticó la
causa exacta (diferencia semántica entre `RANK()` y `DENSE_RANK()` al
implementar el ranking manualmente con subconsulta correlacionada) y se
corrigió antes de aceptar la consulta.

## Ver también

- `consulta_a_ranking.sql` — especificación, V1, V2 (con el intento
  fallido documentado como nota de proceso), y verificación de
  equivalencia con resultado real.
- `consulta_b_subconsulta.sql` — especificación, V1, V2, y verificación
  de equivalencia con resultado real.
- `../DUIA_TP4.md` — declaración consolidada de las 4 partes del TP4.