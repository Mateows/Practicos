**TECNICATURA UNIVERSITARIA EN PROGRAMACIÓN**
**UTN FRM — Base de Datos II**

# Protocolo de seguridad — Origen en TP2 y aplicación a TP2–TP6

Alumnos: Liendo Mateo, Avila Lucas, Pagano Amanda.

Comisión: 4.

Profesor: Neira Sergio.

Este protocolo nació en TP2 Concurrencia e IA, adaptando los tres pasos de la cátedra —copia, transacción y respaldo— al entorno PostgreSQL 17 en Windows, administrado mediante psql desde Git Bash. Su aplicación se extiende a los trabajos posteriores.

El entorno original de TP2 documentó PostgreSQL 17.11. Esta referencia histórica no constituye una comprobación de la versión instalada actualmente.

## Autorización humana

El agente puede leer, analizar y proponer. Cada modificación de archivos requiere autorización explícita del grupo y debe respetar el alcance aprobado.

Guardar un script no autoriza ejecutarlo. Conectarse a PostgreSQL, ejecutar consultas, generar respaldos, crear o restaurar bases y realizar operaciones destructivas requieren autorización específica. Tampoco se realizan git add, commit o push sin autorización.

Un resultado correcto permite evaluar una propuesta, pero no autoriza COMMIT ni otros cambios persistentes.

## Paso 1 — Copia y selección del entorno

No se ejecutan pruebas sobre foodstore_dev. Antes de una ejecución autorizada se debe identificar la base de destino y revisar el origen y contenido de la copia.

### Bases y antecedentes

| Base | Uso o antecedente documentado |
|---|---|
| foodstore_dev | Base de desarrollo del esquema FoodStore de TP1. No es destino de pruebas. |
| foodstore_copia_trabajo — etapa inicial | En TP2 se creó como copia de foodstore_dev. Ese origen no garantiza que conserve idéntico contenido después de trabajos posteriores. |
| foodstore_tp3_carga | Base de carga masiva utilizada en las mediciones históricas de TP3, TP4 y TP5. |
| foodstore_copia_trabajo — TP6 Parte 2 | Copia de trabajo con la carga masiva utilizada para medir la desnormalización. No debe confundirse con la copia pequeña inicial. |
| foodstore_copia_tp6_parte1 | Copia pequeña conservada para TP6 Parte 1, según lo informado por el grupo. No se considera equivalente a la copia masiva. |

La carga utilizada en TP6 Parte 2 se documentó con 200005 pedidos, 499571 detalles, 50003 productos y 2 categorías. Sus consultas midieron el día histórico 25/06/2026 en America/Buenos_Aires.

Estos antecedentes no son una comprobación actual de existencia, contenido o procedencia de todas las bases. Deben revisarse antes de una operación autorizada.

Fuentes: [documentación de TP2](TP2_Concurrencia_IA/README.md), [DUIA de TP3](TP3_Optimizacion/DUIA_COMPLETA.md) e [informe de TP6 Parte 2](TP6_FNBC_Desnormalizacion/Parte2_Desnormalizacion/informe_parte2_desnormalizacion.md). El nombre foodstore_copia_tp6_parte1 se incorpora conforme a la información del grupo.

### Compatibilidad con los scripts de TP6

Los scripts actuales de TP6 comprueban que el destino sea foodstore_copia_trabajo. La copia conservada foodstore_copia_tp6_parte1 no habilita ejecutar esos scripts sin revisar antes su destino.

No cambiar las comprobaciones, renombrar bases ni reemplazar una copia automáticamente para adaptar el entorno.

## Paso 2 — Transacción y validación

Los INSERT, UPDATE, DELETE y cambios estructurales que PostgreSQL admite dentro de una transacción se validan mediante un bloque explícito:

```sql
BEGIN;

-- Operaciones previamente revisadas y autorizadas.
-- Comprobaciones de resultados y estructura.

ROLLBACK;
```

ROLLBACK es el cierre por defecto, también cuando las comprobaciones son correctas. Para una aplicación persistente, el grupo debe autorizar explícitamente los cambios y el COMMIT.

No ejecutar un script en forma parcial o cambiar su cierre sin revisar qué efectos quedarían pendientes. Si ocurre un error antes del cierre, descartar la transacción en la misma sesión o cerrar la conexión; no confirmar para intentar resolver el error.

### Operaciones fuera de la transacción

CREATE DATABASE y DROP DATABASE no pueden ejecutarse dentro de BEGIN...ROLLBACK. Las utilidades createdb y dropdb realizan esas operaciones y no quedan protegidas por el ROLLBACK de un script de validación.

Su autorización debe ser específica y previa. No encadenar borrado y recreación como recuperación automática.

Otros comandos con restricciones transaccionales deben revisarse individualmente antes de proponer su ejecución.

Referencias oficiales: [CREATE DATABASE](https://www.postgresql.org/docs/17/sql-createdatabase.html) y [DROP DATABASE](https://www.postgresql.org/docs/17/sql-dropdatabase.html).

### Scripts históricos

La presencia de BEGIN o de una prueba previa no garantiza que un script termine en ROLLBACK. Algunos archivos históricos contienen COMMIT y pueden dejar cambios persistentes, por ejemplo:

- [Carga masiva de TP3](TP3_Optimizacion/Parte%201%20-%20Poblar%20la%20base%20masivamente%20con%20datos%20generados%20por%20IA/seed_masivo.sql).
- [Mediciones de Q4 de TP5](TP5_Indices_Vistas/Parte_A_Indices/medir_q4_rondas.sql).
- [Mediciones de escritura e índices en producto de TP5](TP5_Indices_Vistas/Parte_A_Indices/medir_escritura_producto_dos_indices.sql).

Se deben leer completos antes de ejecutarlos y obtener autorización acorde con sus efectos. No ejecutar todos los SQL del repositorio como una instalación secuencial.

## Paso 3 — Respaldo

Antes de una operación estructural autorizada, generar un respaldo independiente de la base de destino.

Los respaldos nuevos se conservan fechados fuera del repositorio, como los utilizados en `C:/Users/hp/Respaldos_BD2`. Esta ruta local corresponde a este equipo y no es portable a otros entornos.

Los respaldos pueden utilizar los siguientes formatos:

| Formato | Extensión habitual | Herramienta de restauración |
|---|---|---|
| SQL plano | .sql | psql |
| Custom | .dump | pg_restore |

Los respaldos de TP6 se generaron en formato custom, según lo informado por el grupo. La extensión es una convención: antes de restaurar se debe revisar el formato real del archivo y elegir la herramienta correspondiente. Un archivo custom no se restaura ejecutándolo como SQL con psql.

Un nombre de respaldo debe identificar la base, la fecha y hora y el motivo, por ejemplo:

- SQL plano: `respaldo_<base>_AAAAMMDD_HHMMSS_antes_<operacion>.sql`.
- Custom: `respaldo_<base>_AAAAMMDD_HHMMSS_antes_<operacion>.dump`.

No sobrescribir respaldos anteriores. Registrar la base de origen, el archivo y su formato, y comprobar que la generación haya finalizado correctamente. Que un archivo exista no demuestra por sí solo que pueda restaurarse.

Se conserva como antecedente el [respaldo histórico de TP2](TP2_Concurrencia_IA/parte1/respaldo_foodstore_copia_trabajo.sql), originalmente guardado junto al trabajo de integridad. No moverlo, sustituirlo ni asumir que representa la carga masiva usada posteriormente.

La ubicación y los antecedentes de respaldos no equivalen a una auditoría actual de su contenido o restaurabilidad.

## Restauración, recreación y errores

Ante una prueba fallida, primero descartar la transacción cuando corresponda y conservar la información del error. No borrar ni recrear automáticamente la copia.

Antes de proponer una restauración o recreación se debe revisar con el grupo:

1. Base de origen y estado que se desea recuperar.
2. Base de destino exacta y contenido que podría perderse.
3. Respaldo elegido, fecha, formato y alcance.
4. Operaciones necesarias, incluidas las que quedan fuera de transacción.

Presentar un plan concreto y esperar autorización específica. Cuando sea viable, preferir restaurar en una base nueva autorizada para comparar antes de reemplazar una existente. No asumir autorización para eliminar la base de destino, desconectar otras sesiones o sobrescribir información.

## Evidencias, resultados y objetos instalados

Los scripts, planes y decisiones de aceptación documentan trabajos realizados en un momento determinado. No prueban que sus índices, triggers, vistas o datos estén instalados actualmente en otra base o copia.

Las implementaciones de TP6 terminaron con ROLLBACK: ni la migración FNBC ni las columnas, índice y triggers de desnormalización quedaron persistidos por esos ensayos.

Las pruebas de sincronización de TP6 fueron secuenciales. La concurrencia entre sesiones no fue probada y el costo adicional de escritura no fue cuantificado.

Consultar:

- [README de TP6](TP6_FNBC_Desnormalizacion/README.md).
- [Informe de FNBC](TP6_FNBC_Desnormalizacion/Parte1_FNBC/informe_parte1_fnbc.md).
- [Informe de desnormalización](TP6_FNBC_Desnormalizacion/Parte2_Desnormalizacion/informe_parte2_desnormalizacion.md).
- [Informe integrador](Informe_General.md).

## Regla de fondo

La IA propone; el grupo revisa, autoriza y decide la aplicación. La autorización se limita a la operación aprobada. Ni una explicación convincente, ni una medición favorable, ni un script histórico sustituyen esa autorización.
