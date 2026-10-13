# ==============================================================================
# Script de publicación para Quartz (Inyecta enlaces de Drive usando rclone)
# ==============================================================================

$quartzContentDir = "C:\Users\Luciano\Documents\my-notes-quartz\content"
$obsidianVault = "C:\Users\Luciano\iCloudDrive\iCloud~md~obsidian\my-notes\compartidos"
$RclonePath = "C:\Users\Luciano\Tools\rclone\rclone.exe"
$RemotePath = "gdrive:compartidos-varios"

$carpetasASincronizar = @("clases", "notas-y-apuntes")

Write-Host "1. Limpiando directorio content antiguo..." -ForegroundColor Cyan
if (Test-Path $quartzContentDir) {
    Get-ChildItem -Path $quartzContentDir -Exclude "index.md" | Remove-Item -Recurse -Force
} else {
    New-Item -ItemType Directory -Path $quartzContentDir | Out-Null
}

Write-Host "2. Copiando carpetas de Obsidian a Quartz..." -ForegroundColor Cyan
foreach ($carpeta in $carpetasASincronizar) {
    $origen = Join-Path -Path $obsidianVault -ChildPath $carpeta
    if (Test-Path $origen) {
        Copy-Item -Path $origen -Destination $quartzContentDir -Recurse -Force
    }
}

Write-Host "3. Obteniendo IDs de Google Drive usando rclone..." -ForegroundColor Cyan
$json = & $RclonePath lsjson $RemotePath --files-only 2>$null

if ($json) {
    $archivosDrive = $json | ConvertFrom-Json
    $diccionario = @{}
    
    # Armar diccionario con los enlaces de los PDFs
    foreach ($archivo in $archivosDrive) {
        if ($archivo.Name -match "\.pdf$") {
            $url = "https://drive.google.com/file/d/$($archivo.ID)/view"
            $diccionario[$archivo.Name] = $url
        }
    }

    Write-Host "4. Inyectando enlaces de Google Drive en notas matrices..." -ForegroundColor Cyan
    $archivosMd = Get-ChildItem -Path $quartzContentDir -Filter "*.md" -Recurse
    foreach ($archivo in $archivosMd) {
        # Usando clase de .NET universal para evitar problemas de versión de PowerShell
        $contenido = [System.IO.File]::ReadAllText($archivo.FullName, [System.Text.Encoding]::UTF8)
        $modificado = $false

        foreach ($nombrePdf in $diccionario.Keys) {
            # Busca estrictamente [[nombre.pdf]]
            $regex = "\[\[" + [regex]::Escape($nombrePdf) + "\]\]"
            if ($contenido -match $regex) {
                $urlDrive = $diccionario[$nombrePdf]
                $reemplazo = "[$nombrePdf ↗ Abrir en Drive]($urlDrive)"
                $contenido = $contenido -replace $regex, $reemplazo
                $modificado = $true
            }
        }
        if ($modificado) {
            [System.IO.File]::WriteAllText($archivo.FullName, $contenido, [System.Text.Encoding]::UTF8)
        }
    }
} else {
    Write-Host "ADVERTENCIA: No se pudo conectar con rclone para obtener los links." -ForegroundColor Yellow
}

Write-Host "5. Eliminando archivos PDF fisicos para no saturar GitHub..." -ForegroundColor Cyan
Get-ChildItem -Path $quartzContentDir -Filter "*.pdf" -Recurse | Remove-Item -Force

Write-Host "6. Subiendo a GitHub..." -ForegroundColor Cyan
cd C:\Users\Luciano\Documents\my-notes-quartz
git add .
git commit -m "Actualizacion automatica: Notas y Enlaces rclone a Drive"
git push origin main

Write-Host "¡Proceso terminado exitosamente!" -ForegroundColor Green
Read-Host -Prompt "Presiona Enter para salir..."