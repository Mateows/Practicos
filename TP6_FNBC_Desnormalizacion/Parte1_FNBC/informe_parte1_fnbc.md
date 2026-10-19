# TP6 — FNBC y desnormalización controlada
## Parte 1 — Normalización del control de lotes

### 1. Relación y dependencias funcionales

Se analiza la relación:

**R(LoteID, DepositoID, ResponsableControlID)**

Para simplificar la notación se utilizan L, D y C, respectivamente. Las dependencias funcionales dadas por el dominio son:

- **LD → C:** para un lote y un depósito determinados existe un único responsable de control.
- **C → D:** cada responsable de control pertenece a un único depósito y no controla lotes de otros depósitos.

La pertenencia corresponde únicamente a responsables de control, no a todos los usuarios. Un depósito puede tener varios responsables: no se establece D → C.

La instancia inicial es:

| LoteID | DepositoID | ResponsableControlID |
|---|---|---|
| 501 | 30 | 801 |
| 502 | 30 | 801 |
| 503 | 31 | 802 |

Las dependencias se obtienen de las reglas del dominio. No se infieren dependencias adicionales por coincidencias de esta muestra.

### 2. Clausuras de los subconjuntos

Respecto de **F = {LD → C, C → D}**, las clausuras son:

| Subconjunto X | Clausura X⁺ |
|---|---|
| ∅ | ∅ |
| L | L |
| D | D |
| C | CD |
| LD | LDC |
| LC | LCD |
| DC | DC |
| LDC | LDC |

C permite obtener D. LD permite obtener C y, por lo tanto, todos los atributos. LC también permite obtener todos los atributos mediante C → D.

### 3. Claves candidatas y atributos primos

Las claves candidatas son **LD y LC**.

LD es mínima porque ni L ni D por separado determinan todos los atributos. LC también es mínima: L⁺ = L y C⁺ = CD.

El conjunto de claves es completo porque ninguna dependencia permite obtener L a partir de otros atributos. Toda clave debe contener L y, para determinar la relación completa, debe acompañarse de D o C. LDC es superclave, pero no es mínima.

**Todos los atributos son primos:** L pertenece a ambas claves candidatas; D pertenece a LD y C pertenece a LC. No existen atributos no primos.

La clave primaria elegida para la relación original es LD. Esta elección no elimina la clave candidata alternativa LC.

### 4. Evaluación de 3FN y FNBC

Suponiendo atributos atómicos, la relación cumple **tercera forma normal (3FN)**. Para toda dependencia no trivial X → A, 3FN exige que X sea superclave o que A sea primo. En LD → C, LD es superclave. En C → D, C no es superclave, pero D es primo. Como todos los atributos son primos, las dependencias derivadas tampoco violan este criterio.

La relación **no cumple FNBC**, porque esta forma normal exige que todo determinante de una dependencia no trivial sea superclave. La dependencia violatoria es **C → D**: C⁺ = CD y no contiene L. Por lo tanto, C no es superclave.

### 5. Anomalías de la relación original

**Inserción.** Si se incorpora el responsable 803 al depósito 30, pero todavía no se le asigna ningún lote, la relación original no permite registrar únicamente esa pertenencia: necesita un LoteID para completar su clave primaria. Esta anomalía supone que el negocio necesita registrar responsables antes de asignarles controles.

**Borrado.** Si se elimina la fila (503,31,802) porque finaliza ese control, también desaparece la única información que vincula al responsable 802 con el depósito 31. Se pierde la pertenencia del responsable aunque esta continúe vigente.

**Actualización.** Si el responsable 801 pasa al depósito 32 y sus asignaciones de control se trasladan con él, deben actualizarse las filas de los lotes 501 y 502. Si solo se modifica una, podrían quedar (501,32,801) y (502,30,801), violando C → D. La pertenencia repetida exige mantener varias filas sincronizadas.

### 6. Descomposición y reunión sin pérdida

Se descompone mediante la dependencia violatoria C → D:

- **responsable_deposito(C,D)**, con clave primaria C.
- **control_lote(L,C)**, con clave primaria LC.

Ambas relaciones quedan en FNBC. En responsable_deposito, C → D tiene como determinante una clave. En control_lote no existen dependencias funcionales no triviales proyectadas a partir de F.

El atributo común es C:

**responsable_deposito ∩ control_lote = {C}**

Como C → CD, el atributo común determina toda la relación responsable_deposito. Se cumple así el criterio de reunión sin pérdida para una descomposición binaria.

Por tanto, para cualquier instancia original que satisfaga F, la reunión natural de sus proyecciones por C reconstruye exactamente la relación original, sin introducir tuplas espurias.

### 7. Preservación de dependencias y limitación

La dependencia **C → D** queda preservada localmente mediante la clave primaria de responsable_deposito.

En cambio, **LD → C no queda preservada mediante las restricciones locales** de las tablas descompuestas. Las dependencias proyectadas solo permiten deducir C → D; bajo ellas, la clausura de LD sigue siendo LD y no permite obtener C.

El siguiente contraejemplo respeta las PK y FK locales:

**responsable_deposito**

| C | D |
|---|---|
| 801 | 30 |
| 803 | 30 |

**control_lote**

| L | C |
|---|---|
| 501 | 801 |
| 501 | 803 |

La reunión produce (501,30,801) y (501,30,803). El mismo lote y depósito quedan asociados a dos responsables diferentes, violando LD → C.

Esto no contradice la reunión sin pérdida. Esa propiedad garantiza reconstruir una instancia original válida a partir de sus proyecciones; no garantiza que cualquier estado permitido por las restricciones locales satisfaga todas las dependencias originales.

Para mantener LD → C ante futuras modificaciones sería necesario un control entre ambas tablas que impida asignar al mismo lote dos responsables del mismo depósito. También debería contemplar cambios de depósito y operaciones concurrentes. El script de esta parte no implementa triggers adicionales.

### 8. Adaptación a FoodStore

El archivo `tp_fnbc_control_lote.sql` adapta el ejercicio al esquema existente de FoodStore:

- Comprueba que la base sea `foodstore_copia_trabajo`, que exista `public.usuario` y que su identificador sea BIGINT con identity `GENERATED ALWAYS`.
- Se detiene si alguno de los objetos que necesita crear ya existe.
- Comprueba conflictos de IDs y correos antes de insertar los usuarios de ejemplo 801 y 802. No reutiliza ni actualiza usuarios existentes.
- Inserta esos IDs mediante `OVERRIDING SYSTEM VALUE`. Las contraseñas contienen marcadores explícitos de prueba, no hashes válidos ni credenciales utilizables.
- Crea las maestras mínimas lote y deposito, ambas con PK BIGINT.
- Crea control_lote_almacen con PK (lote_id, deposito_id) y FK hacia lote, deposito y usuario.
- Carga la instancia original y verifica C → D antes de migrar.
- Crea responsable_deposito y control_lote con sus PK y FK. La pertenencia se registra únicamente para responsables de control.
- Migra mediante `INSERT ... SELECT DISTINCT` desde la relación original.
- Crea `v_control_lote_almacen`, que reconstruye las tres columnas mediante JOIN por responsable_control_id.

La relación original se conserva durante la prueba para poder compararla con la reconstrucción.

### 9. Resultados de la prueba real

La evidencia registrada en `evidencia_fnbc_20261008_222128.txt` muestra que la comparación con `EXCEPT` en ambos sentidos devolvió **cero filas**. Por lo tanto, ambas diferencias fueron vacías:

- Original menos reconstruida.
- Reconstruida menos original.

La aserción finalizó sin error y emitió el aviso de equivalencia verificada. Los conteos obtenidos fueron:

| Relación | Cantidad de filas |
|---|---|
| control_lote_almacen | 3 |
| responsable_deposito | 2 |
| control_lote | 3 |
| v_control_lote_almacen | 3 |

La vista reconstruyó exactamente:

| lote_id | deposito_id | responsable_control_id |
|---|---|---|
| 501 | 30 | 801 |
| 502 | 30 | 801 |
| 503 | 31 | 802 |

Estos resultados verifican la migración y reconstrucción de la instancia utilizada. La garantía general de reunión sin pérdida se fundamenta en la demostración mediante el atributo común C.

### 10. Alcance y cierre de la prueba

El script se ejecuta dentro de una transacción explícita y termina con **ROLLBACK**, también registrado en la evidencia. Por ello, las tablas, la vista y los datos creados durante esta prueba se descartan: **la migración no queda persistida**.

Este informe corresponde únicamente a la Parte 1. No documenta una implementación de la Parte 2 de desnormalización controlada.
