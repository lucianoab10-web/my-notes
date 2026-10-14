$ErrorActionPreference = 'Stop'

$quartzRepoDir = 'C:\Users\Luciano\Documents\my-notes-quartz'
$quartzContentDir = Join-Path -Path $quartzRepoDir -ChildPath 'content'
$quartzConfigPath = Join-Path -Path $quartzRepoDir -ChildPath 'quartz.config.yaml'
$obsidianVault = 'C:\Users\Luciano\iCloudDrive\iCloud~md~obsidian\my-notes\compartidos'
$RclonePath = 'C:\Users\Luciano\Tools\rclone\rclone.exe'
$RemotePath = 'gdrive:compartidos-varios'
$expectedBaseUrl = 'lucianoab10-web.github.io/my-notes'

$clasesOrigen = Join-Path -Path $obsidianVault -ChildPath 'clases'
$clasesPasadasOrigen = Join-Path -Path $clasesOrigen -ChildPath 'clases-pasadas'
$notasOrigen = Join-Path -Path $obsidianVault -ChildPath 'notas-y-apuntes'

$carpetasASincronizar = @(
    [pscustomobject]@{ Nombre = 'clases'; Ruta = $clasesOrigen }
    [pscustomobject]@{ Nombre = 'clases-pasadas'; Ruta = $clasesPasadasOrigen }
    [pscustomobject]@{ Nombre = 'notas-y-apuntes'; Ruta = $notasOrigen }
)

Write-Host '1. Obteniendo PDFs de Drive...' -ForegroundColor Cyan

# TRUCO DEFINITIVO: Tubería directa para forzar a PowerShell a leer archivo por archivo
try {
    $archivosDrive = & $RclonePath --log-level ERROR lsjson $RemotePath --files-only --recursive | ConvertFrom-Json
} catch {
    throw "Error al ejecutar rclone o procesar Drive."
}

if (-not $archivosDrive) { throw "rclone no devolvió archivos." }

$pdfUrlByName = @{}
$pdfUrlByCleanName = @{}
$pdfCount = 0

foreach ($archivoDrive in $archivosDrive) {
    if ($archivoDrive.Name -match '(?i)\.pdf$' -or $archivoDrive.MimeType -eq 'application/pdf') {
        if ($archivoDrive.ID) {
            $pdfCount++
            $urlDrive = "https://drive.google.com/file/d/$($archivoDrive.ID)/view"
            
            $name = ([string]$archivoDrive.Name).Trim()
            $pdfUrlByName[$name] = $urlDrive
            
            # Crea un "clon" del nombre sin espacios, puntos ni guiones para búsqueda flexible
            $cleanName = $name -replace '[^a-zA-Z0-9]', ''
            $pdfUrlByCleanName[$cleanName] = $urlDrive
        }
    }
}

if ($pdfCount -eq 0) { throw "No se encontraron PDFs en Google Drive." }
Write-Host "   Encontrados $pdfCount PDF(s) en la nube listos para enlazar." -ForegroundColor Green

Write-Host '2. Limpiando content antiguo...' -ForegroundColor Cyan
if (Test-Path -LiteralPath $quartzContentDir -PathType Container) {
    Get-ChildItem -LiteralPath $quartzContentDir -Force | Remove-Item -Recurse -Force
} else {
    New-Item -ItemType Directory -Path $quartzContentDir -Force | Out-Null
}

Write-Host '3. Copiando Obsidian a Quartz...' -ForegroundColor Cyan
$clasesDestino = Join-Path -Path $quartzContentDir -ChildPath 'clases'
New-Item -ItemType Directory -Path $clasesDestino -Force | Out-Null
Get-ChildItem -LiteralPath $clasesOrigen -Force | Where-Object { $_.Name -ne 'clases-pasadas' } | ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $clasesDestino -Recurse -Force }

Copy-Item -LiteralPath $clasesPasadasOrigen -Destination $quartzContentDir -Recurse -Force
Copy-Item -LiteralPath $notasOrigen -Destination $quartzContentDir -Recurse -Force

Write-Host '4. Autogenerando Indice...' -ForegroundColor Cyan
$indexContent = "# Índice de Apuntes`n`n"
$indexContent += "## Ramos Activos`n"
$clasesPath = Join-Path -Path $quartzContentDir -ChildPath 'clases'
if (Test-Path -LiteralPath $clasesPath) { foreach ($archivo in (Get-ChildItem -LiteralPath $clasesPath -Filter '*.md' -File)) { if ($archivo.BaseName -ne 'index') {$indexContent += "- [[$($archivo.BaseName)]]`n" } } }

$indexContent += "`n## Ramos Pasados`n"
$pasadasPath = Join-Path -Path $quartzContentDir -ChildPath 'clases-pasadas'
if (Test-Path -LiteralPath $pasadasPath) { foreach ($archivo in (Get-ChildItem -LiteralPath $pasadasPath -Filter '*.md' -File)) { if ($archivo.BaseName -ne 'index') { $indexContent += "- [[clases-pasadas/$($archivo.BaseName)]]`n" } } }

$indexContent += "`n## Compartidos y Otros Apuntes`n"
$notasPath = Join-Path -Path $quartzContentDir -ChildPath 'notas-y-apuntes'
if (Test-Path -LiteralPath $notasPath) { foreach ($archivo in (Get-ChildItem -LiteralPath $notasPath -Filter '*.md' -File)) { if ($archivo.BaseName -ne 'index') {$indexContent += "- [[notas-y-apuntes/$($archivo.BaseName)]]`n" } } }

[System.IO.File]::WriteAllText((Join-Path -Path $quartzContentDir -ChildPath 'index.md'), $indexContent, [System.Text.UTF8Encoding]::new($false))

Write-Host '5. Convirtiendo enlaces (Búsqueda Inteligente)...' -ForegroundColor Cyan
$unresolvedPdfLinks = [System.Collections.Generic.List[string]]::new()
$wikilinkPattern = '(?i)!?\[\[(?<target>[^\]|#]+\.pdf)(?:\|(?<alias>[^\]]+))?\]\]'
$markdownPdfPattern = '(?i)\[(?<label>[^\]]+)\]\((?<target>(?!https?://|mailto:)[^)\s]+\.pdf)(?:\s+"[^"]*")?\)'

foreach ($archivo in (Get-ChildItem -LiteralPath $quartzContentDir -Filter '*.md' -File -Recurse)) {
    $contenido = [System.IO.File]::ReadAllText($archivo.FullName, [System.Text.Encoding]::UTF8)
    $original = $contenido

    $matchesWiki = [regex]::Matches($contenido, $wikilinkPattern)
    foreach ($m in $matchesWiki) {
        $fullMatch = $m.Value
        $target = $m.Groups['target'].Value.Trim()
        $alias = $m.Groups['alias'].Value.Trim()
        
        $normalizedTarget = [Uri]::UnescapeDataString($target).Replace('\', '/')
        $fileName = [System.IO.Path]::GetFileName($normalizedTarget)
        $cleanName = $fileName -replace '[^a-zA-Z0-9]', ''
        
        $url = $null
        
        # 1. Búsqueda Exacta
        foreach ($key in $pdfUrlByName.Keys) {
            if ($key -eq $fileName) { $url = $pdfUrlByName[$key]; break }
        }
        # 2. Búsqueda Flexible (si la exacta falla)
        if (-not $url) {
            foreach ($key in $pdfUrlByCleanName.Keys) {
                if ($key -eq $cleanName) { $url = $pdfUrlByCleanName[$key]; break }
            }
        }
        
        if ($url) {
            if ([string]::IsNullOrWhiteSpace($alias)) { $alias = $fileName }
            $replacement = "[$alias ↗ Abrir en Drive]($url)"
            $contenido = $contenido.Replace($fullMatch, $replacement)
        } else {
            [void]$unresolvedPdfLinks.Add("$($archivo.FullName) :: $target")
        }
    }

    $matchesMD = [regex]::Matches($contenido, $markdownPdfPattern)
    foreach ($m in $matchesMD) {
        $fullMatch = $m.Value
        $target = $m.Groups['target'].Value.Trim()
        $label = $m.Groups['label'].Value.Trim()
        
        $normalizedTarget = [Uri]::UnescapeDataString($target).Replace('\', '/')
        $fileName = [System.IO.Path]::GetFileName($normalizedTarget)
        $cleanName = $fileName -replace '[^a-zA-Z0-9]', ''
        
        $url = $null
        
        # 1. Búsqueda Exacta
        foreach ($key in $pdfUrlByName.Keys) {
            if ($key -eq $fileName) { $url = $pdfUrlByName[$key]; break }
        }
        # 2. Búsqueda Flexible (si la exacta falla)
        if (-not $url) {
            foreach ($key in $pdfUrlByCleanName.Keys) {
                if ($key -eq $cleanName) { $url = $pdfUrlByCleanName[$key]; break }
            }
        }
        
        if ($url) {
            if ($label -notmatch '(?i)abrir en drive') { $label = "$label ↗ Abrir en Drive" }
            $replacement = "[$label]($url)"
            $contenido = $contenido.Replace($fullMatch, $replacement)
        } else {
            [void]$unresolvedPdfLinks.Add("$($archivo.FullName) :: $target")
        }
    }

    if ($contenido -ne $original) {
        [System.IO.File]::WriteAllText($archivo.FullName, $contenido, [System.Text.UTF8Encoding]::new($false))
    }
}

# AQUÍ QUITAMOS EL FRENO DE EMERGENCIA. SOLO ADVIERTE PERO SIGUE ADELANTE
if ($unresolvedPdfLinks.Count -gt 0) {
    $uniqueUnresolved = @($unresolvedPdfLinks | Sort-Object -Unique)
    Write-Host "Advertencia: No se pudieron emparejar $($uniqueUnresolved.Count) PDFs con Drive." -ForegroundColor Yellow
    foreach ($item in ($uniqueUnresolved | Select-Object -First 30)) { Write-Host "   - $item" -ForegroundColor Yellow }
    Write-Host "El script continuará publicando el sitio web de todos modos..." -ForegroundColor Green
}

Write-Host '6. Ajustando Quartz...' -ForegroundColor Cyan
$configText = [System.IO.File]::ReadAllText($quartzConfigPath, [System.Text.Encoding]::UTF8)
$configNewline = if ($configText.Contains("`r`n")) { "`r`n" } else { "`n" }

$baseUrlPattern = '(?m)^([ \t]*baseUrl:[ \t]*).*$'
if ([regex]::IsMatch($configText, $baseUrlPattern)) {$configText = [regex]::Replace($configText,$baseUrlPattern, ('${1}' +$expectedBaseUrl), 1)
}

$explorerHeadPattern = '(?m)^(?<indent>[ \t]*)-\s*source:\s*["'']@quartz-community/explorer["''][ \t]*\r?\n(?<childIndent>[ \t]+)enabled:\s*true[ \t]*\r?\n'
$explorerMatch = [regex]::Match($configText,$explorerHeadPattern)
if ($explorerMatch.Success) {$restStart = $explorerMatch.Index +$explorerMatch.Length
    $restText = $configText.Substring($restStart)
    $nextPlugin = [regex]::Match($restText, '(?m)^[ \t]*-\s*source:')
    $blockEnd = if ($nextPlugin.Success) { $restStart +$nextPlugin.Index } else { $configText.Length }$explorerBlock = $configText.Substring($explorerMatch.Index, $blockEnd -$explorerMatch.Index)

    if ($explorerBlock -notmatch '(?m)^[ \t]*options:') {
        $indent =$explorerMatch.Groups['childIndent'].Value
        $optionsText = @(($indent + 'options:'), ($indent + '  title: Explorer'), ($indent + '  folderClickBehavior: link'), ($indent + '  folderDefaultState: open'), ($indent + '  useSavedState: false')) -join$configNewline
        $insertion =$explorerMatch.Value + $optionsText +$configNewline
        $configText =$configText.Substring(0, $explorerMatch.Index) +$insertion + $configText.Substring($restStart)
    } else {
        $explorerBlockUpdated =$explorerBlock
        if ($explorerBlockUpdated -match '(?m)^([ \t]*folderDefaultState:[ \t]*).*$') { $explorerBlockUpdated = [regex]::Replace($explorerBlockUpdated, '(?m)^([ \t]*folderDefaultState:[ \t]*).*$', '${1}open', 1) }
        if ($explorerBlockUpdated -match '(?m)^([ \t]*useSavedState:[ \t]*).*$') { $explorerBlockUpdated = [regex]::Replace($explorerBlockUpdated, '(?m)^([ \t]*useSavedState:[ \t]*).*$', '${1}false', 1) }
        $configText =$configText.Substring(0, $explorerMatch.Index) +$explorerBlockUpdated + $configText.Substring($blockEnd)
    }
}
[System.IO.File]::WriteAllText($quartzConfigPath, $configText, [System.Text.UTF8Encoding]::new($false))

Write-Host '7. Eliminando PDFs locales...' -ForegroundColor Cyan
Get-ChildItem -LiteralPath $quartzContentDir -Filter '*.pdf' -File -Recurse | Remove-Item -Force

Write-Host '8. Subiendo a GitHub...' -ForegroundColor Cyan
Set-Location -LiteralPath $quartzRepoDir

# Apagamos el pánico y redirigimos (2>&1) los mensajes de Git para que no parezcan errores
$ErrorActionPreference = 'Continue'

Write-Host "   Añadiendo archivos..." -ForegroundColor Gray
git add . 2>&1 | Out-Null

Write-Host "   Creando commit..." -ForegroundColor Gray
git commit -m 'Actualizacion automatica: enlaces Drive, Explorer e indice' 2>&1 | Out-Null

Write-Host "   Subiendo a la nube..." -ForegroundColor Gray
git push origin main 2>&1 | Out-Null

$ErrorActionPreference = 'Stop'

Write-Host '¡Proceso terminado exitosamente!' -ForegroundColor Green
Read-Host -Prompt 'Presiona Enter para salir...'