# SPEC U6 — Plan de Mantenimiento: base `foodstore` (PostgreSQL 16)

**Proyecto:** FoodStore — UTN FRM · Base de Datos II · Comisión 1PRO4  
**Integrantes:** Lucas Avila · Amanda Pagano · Mateo Lautaro Liendo

---

## Condiciones de trabajo

- **No eliminar la base principal.** Toda operación destructiva o de prueba se realiza sobre una copia (`foodstore_copia_trabajo`) o base temporal separada.
- **Formato custom** (`-Fc`) para todos los respaldos con `pg_dump`. Genera archivos binarios comprimidos portables para `pg_restore`.
- **Sin contraseñas en scripts.** La autenticación se delega al archivo `~/.pgpass` o a la variable de entorno `PGPASSWORD` definida en la sesión del operador; nunca se escribe una contraseña en texto plano dentro de un script.

---

## Tabla de tareas

| # | Tarea | Frecuencia | Comando / Acción principal | Evidencia de éxito |
|---|-------|-----------|----------------------------|--------------------|
| 1 | **Respaldo de `foodstore`** | Diaria | `pg_dump -Fc -d foodstore -f respaldo_foodstore_YYYYMMDD.dump` | Archivo `.dump` generado con fecha del día, tamaño > 0 bytes y entrada en el log del operador con hora de inicio y fin. |
| 2 | **Chequeo de salud** | Diaria | Consulta SQL: `SELECT schemaname, tablename, n_live_tup, n_dead_tup, last_analyze, last_vacuum FROM pg_stat_user_tables ORDER BY tablename;` | Salida devuelve las 5 tablas del esquema (`categoria`, `cliente`, `producto`, `pedido`, `detalle_pedido`) con `last_vacuum` y `last_analyze` no nulos; `n_dead_tup` por debajo del umbral aceptable (< 10 % de `n_live_tup`). |
| 3 | **Revisión de mantenimiento** | Semanal | `VACUUM ANALYZE;` ejecutado sobre `foodstore`; revisar índices con `SELECT indexname, idx_scan, idx_tup_read FROM pg_stat_user_indexes ORDER BY idx_scan;` | Comando `VACUUM ANALYZE` finaliza sin errores; log de sesión muestra `VACUUM` para cada tabla; tabla de estadísticas de índices refleja al menos un escaneo en los índices activos del período. |
| 4 | **Restauración de prueba** | Semanal | `createdb foodstore_test_YYYYMMDD` → `pg_restore -d foodstore_test_YYYYMMDD respaldo_foodstore_YYYYMMDD.dump` → verificar con `SELECT COUNT(*) FROM pedido;` → `dropdb foodstore_test_YYYYMMDD` | Base temporal restaurada correctamente; conteo de `pedido` coincide con el de `foodstore`; base temporal eliminada al finalizar; resultado anotado en el log de la semana. |

---

## Notas operativas

- Los archivos `.dump` se almacenan **fuera del repositorio**, en directorio fechado acordado por el grupo.
- Cualquier `COMMIT` o `DROP DATABASE` sobre la base principal requiere autorización explícita del grupo conforme al protocolo de seguridad.
- Este documento es un plan; la ejecución de cada tarea queda registrada en el log del operador y no modifica el esquema instalado.
