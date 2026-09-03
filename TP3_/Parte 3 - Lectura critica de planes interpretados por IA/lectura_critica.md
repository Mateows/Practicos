# Parte 3: Lectura crítica de planes interpretados por IA

**Plan analizado:** `plan_q1_despues.txt` (Index Scan con Limit)

| Afirmación de la IA | ¿Correcta? (Sí/No) | Corrección / evidencia del plan real |
| :--- | :--- | :--- |
| "El tiempo de ejecución en este nodo fue de 6748.76 milisegundos." | No | Confunde el costo estimado máximo (`cost=...6748.76`) con el tiempo real. El costo no se mide en milisegundos, son unidades arbitrarias de I/O. El tiempo real de ese nodo fue `actual time=0.101..0.434`. |
| "El índice filtró y trajo exitosamente 50341 filas reales de la tabla pedido." | No | Confunde las filas estimadas por el planificador (`rows=50341`) con las filas reales procesadas. La evidencia muestra que solo procesó y devolvió 50 filas reales (`actual rows=50`), porque el nodo superior (`Limit`) cortó la ejecución. |
| "Gracias al nodo Limit, el costo inicial se redujo a 0.29." | No | Atribuye erróneamente el costo inicial de 0.29 al efecto del Limit. El valor `0.29` es el costo de arranque (startup cost) inherente a preparar el `Index Scan`, no un descuento aplicado por el nodo Limit. |
| "El tiempo total de ejecución fue rapidísimo de 0.908 milisegundos." | Sí | Es correcto. La evidencia en la última línea del plan lo confirma explícitamente: `Execution Time: 0.908 ms`. |