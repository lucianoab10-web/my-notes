# ============================================================================== 
# Script de publicación para Quartz (enlaces de Drive + índice histórico)
# ============================================================================== 

$ErrorActionPreference = "Stop"

$quartzContentDir = "C:\Users\Luciano\Documents\my-notes-quartz\content"
$obsidianVault = "C:\Users\Luciano\iCloudDrive\iCloud~md~obsidian\my-notes\compartidos"
$RclonePath = "C:\Users\Luciano\Tools\rclone\rclone.exe"
$RemotePath = "gdrive:compartidos-varios"
$quartzRepoDir = "C:\Users\Luciano\Documents\my-notes-quartz"

# Las clases pasadas están dentro de "clases" en el vault de Obsidian.
$clasesOrigen = Join-Path -Path $obsidianVault -ChildPath "clases"
$clasesPasadasOrigen = Join-Path -Path $clasesOrigen -ChildPath "clases-pasadas"
$notasOrigen = Join-Path -Path $obsidianVault -ChildPath "notas-y-apuntes"

$carpetasASincronizar = @(
    [pscustomobject]@{ Nombre = "clases"; Ruta = $clasesOrigen }
    [pscustomobject]@{ Nombre = "clases-pasadas"; Ruta = $clasesPasadasOrigen }
    [pscustomobject]@{ Nombre = "notas-y-apuntes"; Ruta = $notasOrigen }
)

# Comprobaciones previas: evitar borrar content si las rutas de origen no existen.
if (-not (Test-Path -LiteralPath $obsidianVault -PathType Container)) {
    throw "No se encuentra el vault de Obsidian: $obsidianVault. No se modificó content."
}
if (-not (Test-Path -LiteralPath $RclonePath -PathType Leaf)) {
    throw "No se encuentra rclone.exe: $RclonePath. No se modificó content."
}
foreach ($carpeta in $carpetasASincronizar) {
    if (-not (Test-Path -LiteralPath $carpeta.Ruta -PathType Container)) {
        throw "No se encuentra la carpeta de Obsidian '$($carpeta.Nombre)': $($carpeta.Ruta). No se modificó content."
    }
}

Write-Host "1. Limpiando directorio content antiguo..." -ForegroundColor Cyan
if (Test-Path -LiteralPath $quartzContentDir -PathType Container) {
    Get-ChildItem -LiteralPath $quartzContentDir -Force | Remove-Item -Recurse -Force
} else {
    New-Item -ItemType Directory -Path $quartzContentDir -Force | Out-Null
}

Write-Host "2. Copiando carpetas de Obsidian a Quartz..." -ForegroundColor Cyan

# Copiar las clases activas, excluyendo la subcarpeta de clases pasadas.
# Así, las clases pasadas solo aparecen en content\clases-pasadas.
$clasesDestino = Join-Path -Path $quartzContentDir -ChildPath "clases"
New-Item -ItemType Directory -Path $clasesDestino -Force | Out-Null
Get-ChildItem -LiteralPath $clasesOrigen -Force |
    Where-Object { $_.Name -ne "clases-pasadas" } |
    ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $clasesDestino -Recurse -Force
    }

# Copiar las clases pasadas al nivel raíz de content, como espera el índice.
Copy-Item -LiteralPath $clasesPasadasOrigen -Destination $quartzContentDir -Recurse -Force

# Copiar la carpeta de apuntes compartidos.
Copy-Item -LiteralPath $notasOrigen -Destination $quartzContentDir -Recurse -Force

Write-Host "3. Autogenerando el Índice Histórico (index.md)..." -ForegroundColor Cyan
$indexContent = "# Índice de Apuntes`n`n"

$indexContent += "## Ramos Activos`n"
$clasesPath = Join-Path -Path $quartzContentDir -ChildPath "clases"
if (Test-Path -LiteralPath $clasesPath -PathType Container) {
    foreach ($archivo in (Get-ChildItem -LiteralPath $clasesPath -Filter "*.md" -File)) {
        $indexContent += "- [[$($archivo.BaseName)]]`n"
    }
}

$indexContent += "`n## Ramos Pasados`n"
$pasadasPath = Join-Path -Path $quartzContentDir -ChildPath "clases-pasadas"
if (Test-Path -LiteralPath $pasadasPath -PathType Container) {
    foreach ($archivo in (Get-ChildItem -LiteralPath $pasadasPath -Filter "*.md" -File)) {
        $indexContent += "- [[$($archivo.BaseName)]]`n"
    }
}

$indexContent += "`n## Compartidos y Otros Apuntes`n"
$notasPath = Join-Path -Path $quartzContentDir -ChildPath "notas-y-apuntes"
if (Test-Path -LiteralPath $notasPath -PathType Container) {
    foreach ($archivo in (Get-ChildItem -LiteralPath $notasPath -Filter "*.md" -File)) {
        $indexContent += "- [[$($archivo.BaseName)]]`n"
    }
}

[System.IO.File]::WriteAllText(
    (Join-Path -Path $quartzContentDir -ChildPath "index.md"),
    $indexContent,
    [System.Text.Encoding]::UTF8
)

Write-Host "4. Obteniendo IDs de Google Drive usando rclone..." -ForegroundColor Cyan

# rclone escribe NOTICE/ERROR en stderr. Con $ErrorActionPreference = Stop,
# algunas versiones de PowerShell pueden tratar ese texto como error terminante
# aunque rclone haya terminado correctamente. Ocultamos NOTICE y comprobamos
# explícitamente el código de salida para detectar fallos reales.
$previousErrorActionPreference = $ErrorActionPreference
try {
    $ErrorActionPreference = "Continue"
    $jsonLines = & $RclonePath --log-level ERROR lsjson $RemotePath --files-only 2>$null
    $rcloneExitCode = $LASTEXITCODE
}
finally {
    $ErrorActionPreference = $previousErrorActionPreference
}

if ($rcloneExitCode -ne 0) {
    throw "rclone no pudo listar '$RemotePath' (código $rcloneExitCode). No se continuará con la publicación."
}

$jsonText = @($jsonLines) -join "`n"
if ([string]::IsNullOrWhiteSpace($jsonText)) {
    $archivosDrive = @()
} else {
    $archivosDrive = ConvertFrom-Json -InputObject $jsonText
}

$diccionario = @{}
foreach ($archivo in @($archivosDrive)) {
    if ($archivo.Name -match "\.pdf$") {
        $diccionario[$archivo.Name] = "https://drive.google.com/file/d/$($archivo.ID)/view"
    }
}

Write-Host "5. Inyectando enlaces de Google Drive en notas matrices..." -ForegroundColor Cyan
foreach ($archivo in (Get-ChildItem -LiteralPath $quartzContentDir -Filter "*.md" -File -Recurse)) {
    $contenido = [System.IO.File]::ReadAllText($archivo.FullName, [System.Text.Encoding]::UTF8)
    $modificado = $false

    foreach ($nombrePdf in @($diccionario.Keys)) {
        $regex = '\[\[' + [regex]::Escape($nombrePdf) + '\]\]'
        if ($contenido -match $regex) {
            $url = $diccionario[$nombrePdf]
            $replacement = "[$nombrePdf ↗ Abrir en Drive]($url)"
            $reemplazador = [System.Text.RegularExpressions.MatchEvaluator]{
                param($coincidencia)
                $replacement
            }
            $contenido = [regex]::Replace($contenido, $regex, $reemplazador)
            $modificado = $true
        }
    }

    if ($modificado) {
        [System.IO.File]::WriteAllText($archivo.FullName, $contenido, [System.Text.Encoding]::UTF8)
    }
}

Write-Host "6. Eliminando archivos PDF físicos para no saturar GitHub..." -ForegroundColor Cyan
Get-ChildItem -LiteralPath $quartzContentDir -Filter "*.pdf" -File -Recurse | Remove-Item -Force

Write-Host "7. Subiendo a GitHub..." -ForegroundColor Cyan
Set-Location -LiteralPath $quartzRepoDir

git add .
if ($LASTEXITCODE -ne 0) {
    throw "git add falló. No se intentará publicar."
}

git diff --cached --quiet
$diffExitCode = $LASTEXITCODE
if ($diffExitCode -gt 1) {
    throw "No se pudo comprobar si hay cambios preparados en Git."
} elseif ($diffExitCode -eq 1) {
    git commit -m "Actualizacion automatica: Notas, Enlaces Drive e Indice Historico"
    if ($LASTEXITCODE -ne 0) {
        throw "git commit falló. No se intentará publicar."
    }
} else {
    Write-Host "No hay cambios nuevos que registrar." -ForegroundColor DarkGray
}

git push origin main
if ($LASTEXITCODE -ne 0) {
    throw "git push falló. Revisa la conexión y el estado del repositorio."
}

Write-Host "¡Proceso terminado exitosamente!" -ForegroundColor Green
Read-Host -Prompt "Presiona Enter para salir..."
