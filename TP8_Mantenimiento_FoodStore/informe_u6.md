# Informe Unidad 6 — Simulacro de desastre y recuperación

**Materia:** Base de Datos II  
**Institución:** UTN FRM — Tecnicatura Universitaria en Programación  
**Comisión:** 1PRO4  
**Integrante:** Mateo Liendo  
**Fecha de ejecución:** 19/10/2026  

---

## 1. Objetivo del simulacro

Verificar el procedimiento completo de respaldo y restauración de la base de datos `foodstore` mediante un simulacro controlado. Se busca confirmar que:

- El archivo de respaldo generado con `pg_dump -Fc` es válido y restaurable.
- La restauración sobre una base temporal descartable (`foodstore_restore_test`) conserva la integridad de las 5 tablas del esquema.
- Las reglas de negocio de integridad (precios y stocks no negativos, cantidades y precios unitarios de detalle válidos) se cumplen tras la restauración.
- Se pueden medir los tiempos de recuperación (RTO) y el punto de recuperación (RPO) del proceso.

---

## 2. Entorno de trabajo

| Elemento | Valor |
|----------|-------|
| Sistema operativo | Windows 10 |
| Motor de base de datos | PostgreSQL 17 |
| Base de datos origen | `foodstore` |
| Base de datos destino (prueba) | `foodstore_restore_test` |
| Formato de respaldo | Custom (`-Fc`), binario comprimido |
| Archivo de respaldo | `respaldo_foodstore_20261019_201905.dump` (17.47 KB) |
| Archivo de log | `backup_log_20261019_201905.txt` |

---

## 3. Procedimiento ejecutado paso a paso

El simulacro se ejecutó desde la carpeta `TP8_Mantenimiento_FoodStore` en PowerShell.

### Paso 1 — Generación del respaldo

Se ejecutó el script de respaldo, que utiliza `pg_dump` con formato custom (`-Fc`), genera el archivo con marca de tiempo en `backups/` y registra el resultado en `logs/`.

```powershell
.\backup_foodstore.ps1
```

Resultado del respaldo:
- Inicio: 20:19:05
- Fin: 20:19:06
- Archivo generado: `backups/respaldo_foodstore_20261019_201905.dump` (17.47 KB)

### Paso 2 — Creación de la base temporal para prueba

Se creó la base de datos descartable `foodstore_restore_test`.

```powershell
createdb -U postgres foodstore_restore_test
```

### Paso 3 — Restauración del respaldo

Se restauró el archivo `.dump` más reciente sobre la base temporal, aplicando `--no-owner` y `--no-privileges` para evitar conflictos de propietarios y privilegios en el entorno de prueba.

```powershell
pg_restore -U postgres --no-owner --no-privileges -d foodstore_restore_test .\backups\respaldo_foodstore_20261019_201905.dump
```

### Paso 4 — Validación de integridad

Se ejecutó un bloque SQL sobre `foodstore_restore_test` que:

1. Cuenta las filas de las 5 tablas mediante `UNION ALL`.
2. Verifica que no existan productos con precio o stock negativo.
3. Verifica que no existan detalles con cantidad menor o igual a cero ni precio unitario negativo.

```powershell
psql -U postgres -d foodstore_restore_test -c "
SELECT 'categoria' AS tabla, COUNT(*) AS filas FROM categoria
UNION ALL
SELECT 'cliente', COUNT(*) FROM cliente
UNION ALL
SELECT 'producto', COUNT(*) FROM producto
UNION ALL
SELECT 'pedido', COUNT(*) FROM pedido
UNION ALL
SELECT 'detalle_pedido', COUNT(*) FROM detalle_pedido;

SELECT COUNT(*) AS productos_invalidos FROM producto WHERE precio_lista < 0 OR stock < 0;

SELECT COUNT(*) AS detalles_invalidos FROM detalle_pedido WHERE cantidad <= 0 OR precio_unitario < 0;
"
```

### Paso 5 — Eliminación de la base temporal

Al finalizar la validación, la base de prueba fue eliminada para no dejar residuos en el servidor.

```powershell
dropdb -U postgres foodstore_restore_test
```

---

## 4. Resultados y evidencias

### Conteo de filas por tabla tras la restauración

| Tabla | Filas |
|-------|-------|
| categoria | 2 |
| cliente | 3 |
| producto | 3 |
| pedido | 5 |
| detalle_pedido | 7 |

### Validación de reglas de integridad

| Validación | Condición | Resultado |
|------------|-----------|-----------|
| Productos inválidos | `precio_lista < 0 OR stock < 0` | 0 |
| Detalles inválidos | `cantidad <= 0 OR precio_unitario < 0` | 0 |

Todas las tablas fueron restauradas correctamente y las consultas de integridad devolvieron cero registros inválidos, lo que indica que el respaldo y la restauración preservaron los datos del conjunto de prueba TP1.

---

## 5. Métricas RTO y RPO

| Métrica | Valor medido | Aclaración |
|---------|--------------|------------|
| RPO (Punto de Recuperación) | ~0 minutos | El respaldo se generó inmediatamente antes del simulacro, por lo que no hubo ventana de pérdida de datos entre el último respaldo y el evento simulado. |
| RTO (Tiempo de Recuperación) | ~1 segundo | Tiempo transcurrido entre la creación de `foodstore_restore_test`, la restauración con `pg_restore` y la validación SQL. Corresponde al dataset mínimo de TP1 (17.47 KB, 5 tablas pequeñas). |

**Nota:** Estos valores son referenciales para el entorno de prueba con datos reducidos. En una base productiva con volumen real, el RTO y el RPO dependerán del tamaño del respaldo, la infraestructura de almacenamiento y la frecuencia de los respaldos programados.

---

## 6. Problemas encontrados y correcciones aplicadas

Durante la ejecución del simulacro se detectaron y resolvieron los siguientes inconvenientes:

| Problema | Causa | Corrección aplicada |
|----------|-------|---------------------|
| Ruta incorrecta de `pg_dump.exe` | El script apuntaba a `C:\Program Files\PostgreSQL\16\bin\pg_dump.exe`, pero el entorno instalado es PostgreSQL 17. | Se actualizó la ruta a `C:\Program Files\PostgreSQL\17\bin\pg_dump.exe`. |
| Falta de usuario en comandos de base | `restore_test.ps1` no especificaba `-U postgres` en `createdb`, `pg_restore` ni `psql`, lo que provocaba fallos de autenticación en el entorno Windows. | Se agregó `-U postgres` a los tres comandos. |
| Nombre de columna incorrecto en validación | El bloque SQL referenciaba la columna `precio`, pero el esquema real de TP1 utiliza `precio_lista` en la tabla `producto`. | Se corrigió la consulta de validación a `precio_lista < 0 OR stock < 0`. |

---

## 7. Uso de herramientas de IA

Los scripts del TP (`backup_foodstore.ps1`, `health_check.sql`, `maintenance.sql`, `restore_test.ps1` y `SPEC_U6.md`) fueron generados y corregidos con asistencia de **Kiro** (IDE con agente IA). El informe fue redactado con asistencia de **OpenCode**.

En ambos casos, la revisión humana se realizó antes de ejecutar cualquier comando: se verificó la ruta de `pg_dump.exe`, se confirmó la ausencia de contraseñas en texto plano, se validó que el nombre de la base coincidiera con el entorno local y se leyó cada script antes de correrlo en PowerShell.

---

## 8. Conclusión

El simulacro de desastre y recuperación se ejecutó con éxito el 19/10/2026 sobre la base `foodstore` en PostgreSQL 17 (Windows 10). El respaldo en formato custom (`-Fc`) se generó correctamente, se restauró sobre una base temporal descartable sin propietarios ni privilegios, y la validación de integridad confirmó que los datos se recuperaron íntegros (5 tablas con sus filas esperadas y cero registros inválidos en precios, stocks, cantidades y precios unitarios).

La base temporal `foodstore_restore_test` fue eliminada al finalizar, dejando el entorno limpio. Los tiempos medidos (RPO ~0 minutos, RTO ~1 segundo) son válidos para el dataset reducido de TP1 y deben ser re-evaluados cuando se disponga de un volumen de datos productivo real.

El procedimiento documentado en este informe cumple con los requisitos del Trabajo Práctico Unidad 6 y puede servir como referencia para futuros simulacros de recuperación ante desastres.
