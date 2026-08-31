## Escenario 1 — Lectura no repetible

### Cómo se reprodujo

**Sesión A**
```sql
BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT precio_lista FROM producto WHERE id = 1;
-- resultado: 1050.00
```

**Sesión B**
```sql
BEGIN;
UPDATE producto SET precio_lista = 1200.00 WHERE id = 1;
COMMIT;
```

**Sesión A (misma transacción, sin cerrar)**
```sql
SELECT precio_lista FROM producto WHERE id = 1;
-- resultado: 1200.00
ROLLBACK;
```

### Qué se observó
Dentro de la misma transacción de Sesión A, la consulta sobre `producto.precio_lista` (id=1, Muzzarella) devolvió dos valores distintos: 1050.00 en la primera lectura y 1200.00 en la segunda, después de que Sesión B confirmara un `UPDATE` en el medio.

### Explicación de la IA
En el nivel `READ COMMITTED`, cada sentencia dentro de una transacción toma su propio snapshot al momento de ejecutarse, no al momento del `BEGIN`. Por eso, si otra transacción confirma un cambio entre dos lecturas, la segunda lectura ve el dato ya actualizado, aunque ambas consultas pertenezcan a la misma transacción de Sesión A.

*Fuente: Claude (asistente de codificación), consulta del 29/08/2026.*

### Verificación en el motor
Se reseteó la copia de trabajo (`dropdb` + `createdb -T foodstore_dev`) para volver a precio_lista = 1050.00, y se repitió el mismo experimento con `REPEATABLE READ`:

```sql
-- Sesión A
BEGIN;
SET TRANSACTION ISOLATION LEVEL REPEATABLE READ;
SELECT precio_lista FROM producto WHERE id = 1;
-- resultado: 1050.00

-- Sesión B
BEGIN;
UPDATE producto SET precio_lista = 1200.00 WHERE id = 1;
COMMIT;

-- Sesión A (misma transacción)
SELECT precio_lista FROM producto WHERE id = 1;
-- resultado: 1050.00 (se mantiene)
ROLLBACK;
```

### Conclusión
La explicación de la IA se confirmó en el motor real. `REPEATABLE READ` evita la lectura no repetible porque fija el snapshot de datos al inicio de la transacción: aunque Sesión B confirmó el cambio a 1200.00, Sesión A siguió viendo 1050.00 hasta cerrar su propia transacción con `ROLLBACK`.

---
## Escenario 2 — Lectura fantasma

*Nota: se reseteó la copia de trabajo (dropdb + createdb -T foodstore_dev) antes de este escenario, partiendo del dataset original.*

### Cómo se reprodujo

**Sesión A**
```sql
BEGIN;
SET TRANSACTION ISOLATION LEVEL READ COMMITTED;
SELECT COUNT(*) FROM pedido WHERE id_cliente = 1;
-- resultado: 2
```

**Sesión B**
```sql
BEGIN;
INSERT INTO pedido (id_cliente, forma_pago) VALUES (1, 'EFECTIVO');
COMMIT;
```

**Sesión A (misma transacción, sin cerrar)**
```sql
SELECT COUNT(*) FROM pedido WHERE id_cliente = 1;
-- resultado: 3
ROLLBACK;
```

### Qué se observó
Dentro de la misma transacción de Sesión A, el conteo de pedidos del cliente id=1 (Ana Gómez) cambió de 2 a 3 entre dos lecturas consecutivas, porque Sesión B insertó y confirmó un pedido nuevo que cumple la condición del `WHERE` en el medio.

### Explicación de la IA
El fenómeno de lectura fantasma ocurre cuando, dentro de una misma transacción, una consulta agregada (`COUNT`, `SUM`, etc.) se repite y el conjunto de filas que cumple la condición cambió porque otra transacción insertó (o eliminó) filas nuevas y las confirmó en el medio. En `READ COMMITTED`, cada sentencia ve el estado más reciente confirmado, por lo que el fantasma se manifiesta libremente.

*Fuente: Claude (asistente de codificación), consulta del 29/08/2026.*

### Verificación en el motor
Se reseteó la copia de trabajo y se repitió el experimento con `SERIALIZABLE` en Sesión A:

```sql
-- Sesión A
BEGIN;
SET TRANSACTION ISOLATION LEVEL SERIALIZABLE;
SELECT COUNT(*) FROM pedido WHERE id_cliente = 1;
-- resultado: 2

-- Sesión B
BEGIN;
INSERT INTO pedido (id_cliente, forma_pago) VALUES (1, 'EFECTIVO');
COMMIT;
-- se inserta y confirma sin bloqueo ni error

-- Sesión A (misma transacción)
SELECT COUNT(*) FROM pedido WHERE id_cliente = 1;
-- resultado: 2 (se mantiene)
ROLLBACK;
```

### Conclusión
La explicación de la IA se confirmó en el motor real. `SERIALIZABLE` evita la lectura fantasma porque, al igual que `REPEATABLE READ`, fija el snapshot de datos al inicio de la transacción de Sesión A: aunque Sesión B insertó y confirmó una fila nueva que cumplía el `WHERE`, Sesión A siguió viendo el conteo original (2) hasta cerrar su propia transacción.


---
## Escenario 3 — Espera por bloqueo (`FOR UPDATE`)

### Cómo se reprodujo

**Sesión A**
```sql
BEGIN;
-- Sin SET explícito: corre en READ COMMITTED (nivel por defecto de PostgreSQL)
SELECT * FROM producto WHERE id = 2 FOR UPDATE;
-- devuelve la fila de Napolitana y toma el lock
```

**Sesión B**
```sql
BEGIN;
SELECT * FROM producto WHERE id = 2 FOR UPDATE;
-- queda esperando, no devuelve nada
```

**Sesión A**
```sql
COMMIT;
```

**Sesión B (se destraba automáticamente)**
```sql
-- devuelve ahora la fila de Napolitana
ROLLBACK;
```

### Qué se observó
Sesión B quedó bloqueada, sin devolver ningún resultado, desde el momento en que pidió `FOR UPDATE` sobre la misma fila que Sesión A ya tenía tomada. Recién se destrabó y mostró el resultado en el instante en que Sesión A confirmó su transacción con `COMMIT`.

### Explicación de la IA
`SELECT ... FOR UPDATE` adquiere un bloqueo exclusivo de fila que impide que otra transacción tome el mismo tipo de lock sobre esa fila hasta que la primera transacción termine con `COMMIT` o `ROLLBACK`. Cualquier otra sesión que pida `FOR UPDATE` sobre esa fila queda en espera, no falla ni se cancela.

*Fuente: Claude (asistente de codificación), consulta del 29/08/2026.*

### Verificación en el motor
Confirmada directamente: Sesión B permaneció "colgada" (sin devolver el prompt) durante todo el tiempo en que Sesión A mantuvo el lock, y se liberó exactamente al hacer `COMMIT` en Sesión A. El mecanismo funcionó bajo `READ COMMITTED` (nivel por defecto de la sesión, sin `SET` explícito), confirmando que el bloqueo de fila es independiente del nivel de aislamiento configurado.

### Conclusión
La explicación de la IA se confirmó en el motor real. El bloqueo explícito de fila mediante `FOR UPDATE` es el mecanismo (no un nivel de aislamiento) que coordina el acceso concurrente a una misma fila, evitando que dos transacciones la modifiquen a la vez: la segunda debe esperar a que la primera libere el lock.