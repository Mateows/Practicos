# ==============================================================================
# backup_foodstore.ps1
# Proyecto: FoodStore — UTN FRM · Base de Datos II
# Descripción: Genera un respaldo en formato custom (-Fc) de la base 'foodstore'
#              usando pg_dump. Registra el resultado en logs/.
#
# AUTENTICACIÓN: este script NO maneja contraseñas.
#   Opción A — Variable de entorno en la sesión actual:
#     $env:PGPASSWORD = "tu_contraseña"   (ejecutar manualmente antes de correr el script)
#   Opción B — Archivo pgpass.conf en:
#     %APPDATA%\postgresql\pgpass.conf
#     Formato por línea: hostname:port:database:username:password
# ==============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# ------------------------------------------------------------------------------
# 1. PARÁMETROS DE CONEXIÓN — ajustar según el entorno
# ------------------------------------------------------------------------------
$PG_HOST     = "localhost"
$PG_PORT     = "5432"
$PG_DB       = "foodstore"
$PG_USER     = "postgres"
# Ruta al ejecutable de pg_dump (ajustar si PostgreSQL está en otra ubicación)
$PG_DUMP     = "C:\Program Files\PostgreSQL\17\bin\pg_dump.exe"

# ------------------------------------------------------------------------------
# 2. RUTAS DE SALIDA
# ------------------------------------------------------------------------------
$ScriptDir   = Split-Path -Parent $MyInvocation.MyCommand.Path
$BackupDir   = Join-Path $ScriptDir "backups"
$LogDir      = Join-Path $ScriptDir "logs"

# Crear carpetas si no existen
foreach ($dir in @($BackupDir, $LogDir)) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir | Out-Null
    }
}

# ------------------------------------------------------------------------------
# 3. NOMBRES DE ARCHIVO CON MARCA DE TIEMPO
# ------------------------------------------------------------------------------
$Timestamp   = Get-Date -Format "yyyyMMdd_HHmmss"
$DumpFile    = Join-Path $BackupDir "respaldo_${PG_DB}_${Timestamp}.dump"
$LogFile     = Join-Path $LogDir    "backup_log_${Timestamp}.txt"

# ------------------------------------------------------------------------------
# 4. FUNCIÓN DE LOG
# ------------------------------------------------------------------------------
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $Line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    Add-Content -Path $LogFile -Value $Line
    Write-Host $Line
}

# ------------------------------------------------------------------------------
# 5. EJECUCIÓN DEL RESPALDO
# ------------------------------------------------------------------------------
Write-Log "Iniciando respaldo de la base '$PG_DB'."
Write-Log "Archivo de salida: $DumpFile"

# Verificar que pg_dump existe antes de intentar ejecutarlo
if (-not (Test-Path $PG_DUMP)) {
    Write-Log "pg_dump no encontrado en: $PG_DUMP" "ERROR"
    Write-Log "Ajusta la variable PG_DUMP en el script y vuelve a ejecutar." "ERROR"
    exit 1
}

# Ejecutar pg_dump — la autenticación depende de PGPASSWORD o pgpass.conf
& $PG_DUMP `
    --host=$PG_HOST `
    --port=$PG_PORT `
    --username=$PG_USER `
    --format=custom `
    --no-password `
    --file=$DumpFile `
    $PG_DB

# Capturar el código de salida inmediatamente
$ExitCode = $LASTEXITCODE

# ------------------------------------------------------------------------------
# 6. VERIFICACIÓN Y REGISTRO DEL RESULTADO
# ------------------------------------------------------------------------------
if ($ExitCode -ne 0) {
    Write-Log "pg_dump finalizó con código de error: $ExitCode." "ERROR"
    Write-Log "El archivo de respaldo puede estar incompleto o ausente." "ERROR"
    Write-Log "Respaldo FALLIDO." "ERROR"
    exit $ExitCode          # Detiene el script propagando el error al caller
}

# Confirmar que el archivo fue creado y tiene contenido
if (-not (Test-Path $DumpFile)) {
    Write-Log "pg_dump reportó éxito pero el archivo no fue encontrado: $DumpFile" "ERROR"
    exit 1
}

$FileSize = (Get-Item $DumpFile).Length
if ($FileSize -eq 0) {
    Write-Log "El archivo de respaldo existe pero está vacío (0 bytes)." "ERROR"
    exit 1
}

Write-Log "Respaldo completado exitosamente."
Write-Log "Tamaño del archivo: $([Math]::Round($FileSize / 1KB, 2)) KB"
Write-Log "Ruta: $DumpFile"
