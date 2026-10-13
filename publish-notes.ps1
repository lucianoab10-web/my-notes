# ==============================================================================
# Script de sincronización de Obsidian a Quartz (PowerShell)
# ==============================================================================

# 1. Definir rutas
$quartzContentDir = "C:\Users\Luciano\Documents\my-notes-quartz\content"
$obsidianVault = "C:\Users\Luciano\iCloudDrive\iCloud~md~obsidian\my-notes\compartidos"

# Las carpetas específicas que SI quieres copiar a la web
$carpetasASincronizar = @(
    "clases",
    "notas-y-apuntes"
)

Write-Host "Iniciando sincronización con Quartz..." -ForegroundColor Cyan

# 2. Limpiar la carpeta content actual de Quartz (para evitar archivos fantasma viejos)
if (Test-Path $quartzContentDir) {
    Write-Host "Limpiando directorio content antiguo..."
    # Se borra todo EXCEPTO el archivo index.md principal (si quieres conservarlo)
    Get-ChildItem -Path $quartzContentDir -Exclude "index.md" | Remove-Item -Recurse -Force
} else {
    New-Item -ItemType Directory -Path $quartzContentDir | Out-Null
}

# 3. Copiar las carpetas seleccionadas
foreach ($carpeta in $carpetasASincronizar) {
    $origen = Join-Path -Path $obsidianVault -ChildPath $carpeta
    $destino = Join-Path -Path $quartzContentDir -ChildPath $carpeta
    
    if (Test-Path $origen) {
        Write-Host "Copiando: $carpeta ..." -ForegroundColor Yellow
        Copy-Item -Path $origen -Destination $quartzContentDir -Recurse -Force
    } else {
        Write-Host "ADVERTENCIA: No se encontro la carpeta $origen" -ForegroundColor Red
    }
}

Write-Host "Archivos copiados con exito." -ForegroundColor Green

# 4. Construir Quartz y subir a GitHub (npx quartz sync)
Write-Host "Construyendo el sitio y subiendo a GitHub..." -ForegroundColor Cyan
cd C:\Users\Luciano\Documents\my-notes-quartz

# El comando 'quartz sync' hace todo: git add, git commit y git push
npx quartz sync

Write-Host "¡Proceso terminado exitosamente! Tu web se actualizara en unos minutos." -ForegroundColor Green

Read-Host -Prompt "Presiona Enter para salir..."