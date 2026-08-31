**TECNICATURA UNIVERSITARIA EN PROGRAMACIÓN**                    **UTN FRM - Base de datos 2**

# Protocolo de Seguridad — TP2 Concurrencia e IA

Alumnos: Liendo Mateo, Avila Lucas, Pagano Amanda.

Comisión: 4.

Profesor: Neira Sergio.

Este documento adapta el protocolo de tres pasos de la cátedra (copia, transacción, respaldo) a mi entorno concreto: PostgreSQL 17 corriendo localmente en Windows, administrado por línea de comandos con psql desde Git Bash.

## Entorno de trabajo

- Motor: PostgreSQL 17.11, instalado localmente.
- Base de datos de desarrollo: foodstore_dev — contiene el esquema del proyecto integrador FoodStore (TP1), cargado desde TP1_FoodStore/schema.sql.
- Base de datos de trabajo/pruebas: foodstore_copia_trabajo copia exacta de foodstore_dev, creada específicamente para este TP.
- Cliente: psql desde la terminal (Git Bash).

## Paso 1 – Copia

Ningún script generado por IA, ni propio, se ejecuta directamente sobre foodstore_dev. Todo se prueba primero sobre una copia de trabajo.

**Comando usado para crear la copia:**

```
createdb -U postgres -T foodstore_dev foodstore_copia_trabajo
```

Esto crea foodstore_copia_trabajo a partir de la plantilla foodstore_dev, con la misma estructura y los mismos datos. Si en algún momento la copia queda en un estado inconsistente por una prueba fallida, se elimina y se vuelve a crear con el mismo comando (después de borrarla con dropdb -U postgres foodstore_copia_trabajo).

Cuándo se salta: nunca. Toda prueba de este TP se hace contra foodstore_copia_trabajo, no contra foodstore_dev.

## Paso 2 – Transacción

Todo script que modifica datos o estructura se ejecuta primero dentro de una transacción explícita, para poder revisar el efecto antes de confirmarlo.

**Cómo pruebo los cambios antes de aplicarlos**

Antes de tocar la base de verdad, todo lo que la IA (o yo misma) proponga como script lo corro primero dentro de una transacción, sobre la copia de trabajo (foodstore_copia_trabajo).

La lógica es simple: abro la transacción con BEGIN, corro el script, y antes de confirmar nada reviso qué pasó con un SELECT para ver si los datos quedaron como esperaba, o con \d nombre_tabla si lo que cambió fue la estructura.

Si todo cierra bien, recién ahí hago COMMIT. Si algo no se ve como debería, hago ROLLBACK y listo, como si nunca hubiera pasado nada.

Esto me sirve sobre todo para no confiar ciegamente en lo que la IA generó: puedo ver el efecto real antes de que sea definitivo, y si algo está mal, deshacerlo sin ningún costo.

**Flujo usado:**

```
BEGIN;

-- acá va el script generado por la IA o propio
-- se revisa el resultado con SELECT, \d, conteo de filas afectadas, etc.

ROLLBACK;
-- si algo no cierra, se descarta sin dejar rastro

-- o

COMMIT;
-- solo si el resultado fue el esperado
```

Nos conectamos a la copia de trabajo con: psql -U postgres -d foodstore_copia_trabajo

**Cuándo se salta:** nunca. Ningún INSERT, UPDATE, DELETE o cambio de estructura se ejecuta fuera de un bloque BEGIN...COMMIT/ROLLBACK.

## Paso 3 – Respaldo

Antes de aplicar cualquier cambio estructural (ALTER TABLE, DROP, CREATE INDEX, migraciones), se genera un respaldo independiente de la copia de trabajo, para poder restaurar sin depender del ROLLBACK de la transacción.

**Comando usado:**

```
pg_dump -U postgres -d foodstore_copia_trabajo -f respaldo_foodstore_copia_trabajo.sql
```

El archivo de respaldo se guarda dentro de la carpeta TP2_Concurrencia_IA/parte1/, junto con el script de restricciones y la DUIA de la Parte 1 (este protocolo vive en la raíz del repo, según lo pedido en la consigna),

fechado si hace falta generar más de uno.

Para restaurar en caso de que algo salga mal:

dropdb -U postgres foodstore_copia_trabajo

createdb -U postgres foodstore_copia_trabajo

psql -U postgres -d foodstore_copia_trabajo -f respaldo_foodstore_copia_trabajo.sql

**Cuándo se salta:** nunca. Todo cambio de tipo DDL se respalda antes de aplicarse.

## Regla de fondo

Se delega la escritura del script a la IA (OpenCode), nunca la decisión de aplicarlo. Todo lo que la IA proponga en este TP se lee línea por línea, se prueba sobre la copia de trabajo dentro de una transacción, y se defiende oralmente antes de darlo por bueno.
