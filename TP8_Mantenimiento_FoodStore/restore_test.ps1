<#
.SYNOPSIS
    Restaura el backup .dump mas reciente en una base descartable foodstore_restore_test
    y ejecuta un bloque de validacion SQL. Ejecutar posicionado en TP8_Mantenimiento_FoodStore.
#>

$ErrorActionPreference = 'Stop'

$backupDir = Join-Path -Path (Get-Location) -ChildPath 'backups'

$dumpFile = Get-ChildItem -Path $backupDir -Filter '*.dump' |
    Sort-Object -Property LastWriteTime -Descending |
    Select-Object -First 1

if (-not $dumpFile) {
    Write-Error "No se encontro ningun archivo .dump en .\backups\"
}

Write-Host "Usando archivo de respaldo: $($dumpFile.FullName)" -ForegroundColor Cyan

# 1. Crear base de datos descartable
Write-Host "Creando base de datos foodstore_restore_test..." -ForegroundColor Cyan
createdb -U postgres foodstore_restore_test

# 2. Restaurar con pg_restore
Write-Host "Restaurando con pg_restore (--no-owner --no-privileges)..." -ForegroundColor Cyan
pg_restore -U postgres --no-owner --no-privileges -d foodstore_restore_test "$($dumpFile.FullName)"

# 3. Bloque de validacion SQL
$sql = @"
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
"@

Write-Host "Ejecutando validacion SQL..." -ForegroundColor Cyan
psql -U postgres -d foodstore_restore_test -v ON_ERROR_STOP=1 -c "$sql"

Write-Host "Restauracion y validacion completadas." -ForegroundColor Green

# 4. Eliminar base temporal
Write-Host "Eliminando base temporal foodstore_restore_test..." -ForegroundColor Cyan
dropdb -U postgres foodstore_restore_test
Write-Host "Base temporal eliminada." -ForegroundColor Green
