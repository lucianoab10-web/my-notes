# ==============================================================================
# Script de publicación para Quartz (Drive Links + Índice Histórico)
# ==============================================================================

$quartzContentDir = "C:\Users\Luciano\Documents\my-notes-quartz\content"
$obsidianVault = "C:\Users\Luciano\iCloudDrive\iCloud~md~obsidian\my-notes\compartidos"
$RclonePath = "C:\Users\Luciano\Tools\rclone\rclone.exe"
$RemotePath = "gdrive:compartidos-varios"

# Añadimos 'clases-pasadas' a la lista de sincronización
$carpetasASincronizar = @("clases", "clases-pasadas", "notas-y-apuntes")

Write-Host "1. Limpiando directorio content antiguo..." -ForegroundColor Cyan
if (Test-Path $quartzContentDir) {
    Get-ChildItem -Path $quartzContentDir | Remove-Item -Recurse -Force
} else {
    New-Item -ItemType Directory -Path $quartzContentDir | Out-Null
}

Write-Host "2. Copiando carpetas de Obsidian a Quartz..." -ForegroundColor Cyan
foreach ($carpeta in $carpetasASincronizar) {$origen = Join-Path -Path $obsidianVault -ChildPath$carpeta
    if (Test-Path $origen) {
        Copy-Item -Path $origen -Destination$quartzContentDir -Recurse -Force
    }
}

Write-Host "3. Autogenerando el Índice Histórico (index.md)..." -ForegroundColor Cyan
$indexContent = "# Índice de Apuntes`n`n"

# Categoría: Ramos Activos
$indexContent += "## Ramos Activos`n"
$clasesPath = Join-Path -Path $quartzContentDir -ChildPath "clases"
if (Test-Path $clasesPath) {
    $archivosClases = Get-ChildItem -Path $clasesPath -Filter "*.md"
    foreach ($archivo in $archivosClases) {
        $indexContent += "- [[$($archivo.BaseName)]]`n"
    }
}

# Categoría: Ramos Pasados
$indexContent += "`n## Ramos Pasados`n"
$pasadasPath = Join-Path -Path$quartzContentDir -ChildPath "clases-pasadas"
if (Test-Path $pasadasPath) {
    $archivosPasados = Get-ChildItem -Path$pasadasPath -Filter "*.md"
    foreach ($archivo in $archivosPasados) {$indexContent += "- [[$($archivo.BaseName)]]`n"
    }
}

# Categoría: Otros Apuntes
$indexContent += "`n## Compartidos y Otros Apuntes`n"
$notasPath = Join-Path -Path $quartzContentDir -ChildPath "notas-y-apuntes"
if (Test-Path $notasPath) {
    $archivosNotas = Get-ChildItem -Path $notasPath -Filter "*.md"
    foreach ($archivo in $archivosNotas) {
        $indexContent += "- [[$($archivo.BaseName)]]`n"
    }
}

[System.IO.File]::WriteAllText("$quartzContentDir\index.md", $indexContent, [System.Text.Encoding]::UTF8)

Write-Host "4. Obteniendo IDs de Google Drive usando rclone..." -ForegroundColor Cyan
$json = &$RclonePath lsjson $RemotePath --files-only 2>$null

if ($json) {$archivosDrive = $json \vert{} ConvertFrom-Json$diccionario = @{}
    
    foreach ($archivo in$archivosDrive) {
        if ($archivo.Name -match "\.pdf$") {
            $url = "https://drive.google.com/file/d/$($archivo.ID)/view"
            $diccionario[$archivo.Name] =$url
        }
    }

    Write-Host "5. Inyectando enlaces de Google Drive en notas matrices..." -ForegroundColor Cyan
    $archivosMd = Get-ChildItem -Path$quartzContentDir -Filter "*.md" -Recurse
    foreach ($archivo in$archivosMd) {
        $contenido = [System.IO.File]::ReadAllText($archivo.FullName, [System.Text.Encoding]::UTF8)
        $modificado =$false

        foreach ($nombrePdf in $diccionario.Keys) {$regex = "\[\[" + [regex]::Escape($nombrePdf) + "\]\]"
            if ($contenido -match $regex) {$urlDrive = $diccionario[$nombrePdf]
                $reemplazo = "[$nombrePdf ↗ Abrir en Drive]($urlDrive)"
                $contenido =$contenido -replace $regex,$reemplazo
                $modificado =$true
            }
        }
        if ($modificado) {
            [System.IO.File]::WriteAllText($archivo.FullName, $contenido, [System.Text.Encoding]::UTF8)
        }
    }
} else {
    Write-Host "ADVERTENCIA: No se pudo conectar con rclone para obtener los links." -ForegroundColor Yellow
}

Write-Host "6. Eliminando archivos PDF fisicos para no saturar GitHub..." -ForegroundColor Cyan
Get-ChildItem -Path $quartzContentDir -Filter "*.pdf" -Recurse | Remove-Item -Force

Write-Host "7. Subiendo a GitHub..." -ForegroundColor Cyan
cd C:\Users\Luciano\Documents\my-notes-quartz
git add .
git commit -m "Actualizacion automatica: Notas, Enlaces Drive e Indice Historico"
git push origin main

