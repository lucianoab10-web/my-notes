# ============================================================================
# Publicación de notas para Quartz 5 (Versión Inmune a errores de copiado)
# ============================================================================
# Uso manual:  .\publish-notes-visible.ps1            (queda abierta hasta que presiones Enter)
# Automatico:  .\publish-notes-visible.ps1 -NoPause   (lo usa Sincronizar-y-Publicar.ps1)
# Codigos de salida: 0 = ok (puede haber avisos de PDF sin enlazar), 1 = error, 2 = ya habia otra publicacion en curso
# ============================================================================

param([switch]$NoPause)

$ErrorActionPreference = 'Stop';

# Evita dos publicaciones a la vez (tarea programada + ejecucion manual): una pisaria a la otra.
$mutexPublicar = New-Object System.Threading.Mutex($false, 'Global\PublicarNotasQuartz');
$tengoLock = $false;
try { $tengoLock = $mutexPublicar.WaitOne(0); } catch [System.Threading.AbandonedMutexException] { $tengoLock = $true; }
if (-not $tengoLock) {
    Write-Host 'Ya hay otra publicacion en curso; no hago nada para no pisarla.' -ForegroundColor Yellow;
    $mutexPublicar.Dispose();
    if (-not $NoPause -and [Environment]::UserInteractive -and -not [Console]::IsInputRedirected) { Read-Host -Prompt 'Presiona Enter para salir...' | Out-Null; }
    exit 2;
}

try {

$quartzRepoDir = 'C:\Users\Luciano\Documents\my-notes-quartz';
$quartzContentDir = Join-Path -Path $quartzRepoDir -ChildPath 'content';
$quartzConfigPath = Join-Path -Path $quartzRepoDir -ChildPath 'quartz.config.yaml';
$obsidianVault = 'C:\Users\Luciano\iCloudDrive\iCloud~md~obsidian\my-notes\compartidos';$RclonePath = 'C:\Users\Luciano\Tools\rclone\rclone.exe';
$RemotePath = 'gdrive:compartidos-varios';$expectedBaseUrl = 'lucianoab10-web.github.io/my-notes';

$clasesOrigen = Join-Path -Path $obsidianVault -ChildPath 'clases';
$clasesPasadasOrigen = Join-Path -Path $clasesOrigen -ChildPath 'clases-pasadas';
$notasOrigen = Join-Path -Path $obsidianVault -ChildPath 'notas-y-apuntes';

$carpetasASincronizar = @(
    [pscustomobject]@{ Nombre = 'clases'; Ruta = $clasesOrigen };
    [pscustomobject]@{ Nombre = 'clases-pasadas'; Ruta = $clasesPasadasOrigen };
    [pscustomobject]@{ Nombre = 'notas-y-apuntes'; Ruta = $notasOrigen }
);

if (-not (Test-Path -LiteralPath $quartzRepoDir -PathType Container)) { throw "No se encuentra el repositorio Quartz: $quartzRepoDir"; }
if (-not (Test-Path -LiteralPath $quartzConfigPath -PathType Leaf)) { throw "No se encuentra quartz.config.yaml: $quartzConfigPath"; }
if (-not (Test-Path -LiteralPath $obsidianVault -PathType Container)) { throw "No se encuentra el vault de Obsidian: $obsidianVault"; }
if (-not (Test-Path -LiteralPath $RclonePath -PathType Leaf)) { throw "No se encuentra rclone.exe: $RclonePath"; }

foreach ($carpeta in($carpetasASincronizar)) {
    if (-not (Test-Path -LiteralPath $carpeta.Ruta -PathType Container)) {
        throw "No se encuentra la carpeta de Obsidian '$($carpeta.Nombre)': $($carpeta.Ruta)";
    }
}

Write-Host '1. Obteniendo PDFs y sus IDs de Google Drive...' -ForegroundColor Cyan;

# Quita tildes y simbolos para comparar nombres de forma flexible: "Guía_ Solemne1.pdf" ~ "guia solemne1.pdf"
function Get-NombreLimpio([string]$Nombre) {
    $limpio = $Nombre.ToLowerInvariant();
    $limpio = $limpio -replace '[\u00e1\u00e0\u00e2\u00e4\u00e3\u00e5]', 'a';
    $limpio = $limpio -replace '[\u00e9\u00e8\u00ea\u00eb]', 'e';
    $limpio = $limpio -replace '[\u00ed\u00ec\u00ee\u00ef]', 'i';
    $limpio = $limpio -replace '[\u00f3\u00f2\u00f4\u00f6\u00f5]', 'o';
    $limpio = $limpio -replace '[\u00fa\u00f9\u00fb\u00fc]', 'u';
    $limpio = $limpio -replace '\u00f1', 'n';
    $limpio = $limpio -replace '\u00e7', 'c';
    return ($limpio -replace '[^a-z0-9]', '');
}

$previousOutputEncoding = $null;
$archivosDrive = $null;
$rcloneExitCode = 0;
try {
    # rclone escribe su JSON en UTF-8. Sin esto, Windows PowerShell lo lee con otra pagina de codigos
    # y los nombres con tildes o ñ no coinciden con los de tus notas.
    try { $previousOutputEncoding = [Console]::OutputEncoding; [Console]::OutputEncoding = [System.Text.Encoding]::UTF8; } catch { $previousOutputEncoding = $null; }

    # IMPORTANTE: la salida de rclone va DIRECTO a ConvertFrom-Json, sin envolverla en @(...).
    # En Windows PowerShell 5.1, ConvertFrom-Json entrega la lista completa como UN solo objeto y @(...)
    # la dejaba anidada: todos los archivos de Drive quedaban fundidos en uno y ninguna referencia se resolvia.
    $archivosDrive = & $RclonePath --log-level ERROR lsjson $RemotePath --files-only --recursive | ConvertFrom-Json;
    $rcloneExitCode = $LASTEXITCODE;
}
catch {
    throw "No pude leer la lista de Drive: $($_.Exception.Message)";
}
finally {
    if ($null -ne $previousOutputEncoding) { try { [Console]::OutputEncoding = $previousOutputEncoding; } catch { } }
}

if ($rcloneExitCode -ne 0) { throw "rclone no pudo listar '$RemotePath' (código $rcloneExitCode)."; }

# Aplanar por si acaso: segun la version de PowerShell la lista puede llegar como un arreglo dentro de otro arreglo
$listaDrive = New-Object System.Collections.Generic.List[object];
foreach ($elemento in @($archivosDrive)) {
    if ($null -eq $elemento) { continue; }
    if ($elemento -is [System.Array]) { foreach ($sub in $elemento) { [void]$listaDrive.Add($sub); } }
    else { [void]$listaDrive.Add($elemento); }
}
if ($listaDrive.Count -eq 0) { throw "rclone no devolvió archivos para '$RemotePath'."; }

$pdfUrlByPath = @{};
$pdfUrlByName = @{};
$duplicatePdfNames = @{};
$pdfUrlByCleanName = @{};
$duplicateCleanNames = @{};
$pdfCount = 0;

foreach ($archivoDrive in($listaDrive)) {
    if ($archivoDrive.Name -and $archivoDrive.ID -and $archivoDrive.Name -match '(?i)\.pdf$') {
        $pdfCount++;
        $urlDrive = "https://drive.google.com/file/d/$($archivoDrive.ID)/view";
        $relativePath = [string]$archivoDrive.Path;
        if ([string]::IsNullOrWhiteSpace($relativePath)) { $relativePath = [string]$archivoDrive.Name; }
        $relativePath = $relativePath.Replace('\', '/').TrimStart('/');
        $pdfUrlByPath[$relativePath] = $urlDrive;

        $name = [string]$archivoDrive.Name;
        if ($pdfUrlByName.ContainsKey($name)) {
            if ($pdfUrlByName[$name] -ne $urlDrive) {
                $duplicatePdfNames[$name] = $true;
                $pdfUrlByName.Remove($name);
            }
        }
        elseif (-not $duplicatePdfNames.ContainsKey($name)) {
            $pdfUrlByName[$name] = $urlDrive;
        }

        $nombreLimpio = Get-NombreLimpio $name;
        if ($nombreLimpio) {
            if ($pdfUrlByCleanName.ContainsKey($nombreLimpio)) {
                if ($pdfUrlByCleanName[$nombreLimpio] -ne $urlDrive) {
                    $duplicateCleanNames[$nombreLimpio] = $true;
                    $pdfUrlByCleanName.Remove($nombreLimpio);
                }
            }
            elseif (-not $duplicateCleanNames.ContainsKey($nombreLimpio)) {
                $pdfUrlByCleanName[$nombreLimpio] = $urlDrive;
            }
        }
    }
}

if ($pdfCount -eq 0) { throw "No se encontró ningún PDF en '$RemotePath'. Revisa rclone."; }
Write-Host "   Encontrados $pdfCount PDF(s), incluyendo subcarpetas." -ForegroundColor Gray;

Write-Host '2. Limpiando directorio content antiguo...' -ForegroundColor Cyan;
if (Test-Path -LiteralPath $quartzContentDir -PathType Container) {
    Get-ChildItem -LiteralPath $quartzContentDir -Force | Remove-Item -Recurse -Force;
} else {
    New-Item -ItemType Directory -Path $quartzContentDir -Force | Out-Null;
}

Write-Host '3. Copiando carpetas de Obsidian a Quartz...' -ForegroundColor Cyan;
$clasesDestino = Join-Path -Path $quartzContentDir -ChildPath 'clases';
New-Item -ItemType Directory -Path $clasesDestino -Force | Out-Null;
Get-ChildItem -LiteralPath $clasesOrigen -Force |
    Where-Object { $_.Name -ne 'clases-pasadas' } |
    ForEach-Object { Copy-Item -LiteralPath $_.FullName -Destination $clasesDestino -Recurse -Force; };

Copy-Item -LiteralPath $clasesPasadasOrigen -Destination $quartzContentDir -Recurse -Force;
Copy-Item -LiteralPath $notasOrigen -Destination $quartzContentDir -Recurse -Force;

Write-Host '4. Autogenerando el Índice Histórico (index.md)...' -ForegroundColor Cyan;
$indexContent = "# Índice de Apuntes`n`n";

$indexContent += "## Ramos Activos`n";
$clasesPath = Join-Path -Path $quartzContentDir -ChildPath 'clases';
if (Test-Path -LiteralPath $clasesPath) {
    foreach ($archivo in(Get-ChildItem -LiteralPath $clasesPath -Filter '*.md' -File)) {
        if ($archivo.BaseName -ne 'index') {$indexContent += "- [[$($archivo.BaseName)]]`n"; }
    }
}

$indexContent += "`n## Ramos Pasados`n";
$pasadasPath = Join-Path -Path $quartzContentDir -ChildPath 'clases-pasadas';
if (Test-Path -LiteralPath $pasadasPath) {
    foreach ($archivo in(Get-ChildItem -LiteralPath $pasadasPath -Filter '*.md' -File)) {
        if ($archivo.BaseName -ne 'index') { $indexContent += "- [[clases-pasadas/$($archivo.BaseName)]]`n"; }
    }
}

$indexContent += "`n## Compartidos y Otros Apuntes`n";
$notasPath = Join-Path -Path $quartzContentDir -ChildPath 'notas-y-apuntes';
if (Test-Path -LiteralPath $notasPath) {
    foreach ($archivo in(Get-ChildItem -LiteralPath $notasPath -Filter '*.md' -File)) {
        if ($archivo.BaseName -ne 'index') {$indexContent += "- [[notas-y-apuntes/$($archivo.BaseName)]]`n"; }
    }
}
[System.IO.File]::WriteAllText((Join-Path -Path $quartzContentDir -ChildPath 'index.md'), $indexContent, [System.Text.UTF8Encoding]::new($false));

Write-Host '5. Convirtiendo enlaces PDF a Google Drive...' -ForegroundColor Cyan;

# Busca un PDF de la nota en la lista de Drive. Orden: ruta exacta, nombre exacto, nombre aproximado.
# Si el nombre se repite en Drive (o hay varios parecidos) NO adivina: lo deja sin enlazar y lo avisa.
function Resolve-PdfUrl([string]$Target) {
    $normalizado = [Uri]::UnescapeDataString($Target).Replace('\', '/');
    $normalizado = ($normalizado -replace '^\./', '').TrimStart('/');
    $nombre = [System.IO.Path]::GetFileName($normalizado);
    $resultado = @{ Url = $null; Aproximado = $false; Motivo = 'no esta en Drive' };

    if ($pdfUrlByPath.ContainsKey($normalizado)) { $resultado.Url = $pdfUrlByPath[$normalizado]; return $resultado; }
    if ($duplicatePdfNames.ContainsKey($nombre)) { $resultado.Motivo = 'nombre repetido en Drive: pon la ruta en el enlace'; return $resultado; }
    if ($pdfUrlByName.ContainsKey($nombre)) { $resultado.Url = $pdfUrlByName[$nombre]; return $resultado; }

    $limpio = Get-NombreLimpio $nombre;
    if ($limpio) {
        if ($duplicateCleanNames.ContainsKey($limpio)) { $resultado.Motivo = 'varios archivos de Drive con nombre parecido'; return $resultado; }
        if ($pdfUrlByCleanName.ContainsKey($limpio)) { $resultado.Url = $pdfUrlByCleanName[$limpio]; $resultado.Aproximado = $true; return $resultado; }
    }
    return $resultado;
}

$unresolvedPdfLinks = [System.Collections.Generic.List[string]]::new();
$enlacesResueltos = 0;
$enlacesAproximados = 0;
$wikilinkPattern = '(?i)!?\[\[(?<target>[^\]|#]+\.pdf)(?:\|(?<alias>[^\]]+))?\]\]';
$markdownPdfPattern = '(?i)\[(?<label>[^\]]+)\]\((?<target>(?!https?://|mailto:)[^)\s]+\.pdf)(?:\s+"[^"]*")?\)';

foreach ($archivo in(Get-ChildItem -LiteralPath $quartzContentDir -Filter '*.md' -File -Recurse)) {
    $contenido = [System.IO.File]::ReadAllText($archivo.FullName, [System.Text.Encoding]::UTF8);
    $original = $contenido;

    foreach ($m in [regex]::Matches($contenido, $wikilinkPattern)) {
        $target = $m.Groups['target'].Value.Trim();
        $resultado = Resolve-PdfUrl $target;
        if ($resultado.Url) {
            $alias = $m.Groups['alias'].Value.Trim();
            if ([string]::IsNullOrWhiteSpace($alias)) { $alias = [System.IO.Path]::GetFileName($target.Replace('\', '/')); }
            $contenido = $contenido.Replace($m.Value, "[$alias ↗ Abrir en Drive]($($resultado.Url))");
            $enlacesResueltos++;
            if ($resultado.Aproximado) { $enlacesAproximados++; }
        }
        else {
            [void]$unresolvedPdfLinks.Add("$($archivo.FullName) :: $target ($($resultado.Motivo))");
        }
    }

    foreach ($m in [regex]::Matches($contenido, $markdownPdfPattern)) {
        $target = $m.Groups['target'].Value.Trim();
        $resultado = Resolve-PdfUrl $target;
        if ($resultado.Url) {
            $label = $m.Groups['label'].Value.Trim();
            if ($label -notmatch '(?i)abrir en drive') { $label = "$label ↗ Abrir en Drive"; }
            $contenido = $contenido.Replace($m.Value, "[$label]($($resultado.Url))");
            $enlacesResueltos++;
            if ($resultado.Aproximado) { $enlacesAproximados++; }
        }
        else {
            [void]$unresolvedPdfLinks.Add("$($archivo.FullName) :: $target ($($resultado.Motivo))");
        }
    }

    if ($contenido -ne $original) {
        [System.IO.File]::WriteAllText($archivo.FullName, $contenido, [System.Text.UTF8Encoding]::new($false));
    }
}

Write-Host "   $enlacesResueltos enlace(s) a PDF convertidos a Drive." -ForegroundColor Gray;
if ($enlacesAproximados -gt 0) { Write-Host "   ($enlacesAproximados se resolvieron por nombre aproximado: sin tildes ni simbolos)" -ForegroundColor Gray; }

if ($unresolvedPdfLinks.Count -gt 0) {
    $uniqueUnresolved = @($unresolvedPdfLinks | Sort-Object -Unique);
    Write-Host "AVISO: $($uniqueUnresolved.Count) referencia(s) PDF no se pudieron enlazar a Drive. Quedan sin convertir, pero el sitio se publica igual:" -ForegroundColor Yellow;
    foreach ($item in($uniqueUnresolved | Select-Object -First 30)) { Write-Host "   - $item" -ForegroundColor Yellow; }
    if ($uniqueUnresolved.Count -gt 30) { Write-Host "   ... y $($uniqueUnresolved.Count - 30) mas." -ForegroundColor Yellow; }
}

# Freno SOLO para el caso catastrofico: si ninguna referencia se pudo enlazar, algo falla al leer la lista de Drive.
$totalReferencias = $enlacesResueltos + $unresolvedPdfLinks.Count;
if ($enlacesResueltos -eq 0 -and $totalReferencias -ge 5) {
    throw "Ninguna de las $totalReferencias referencias a PDF coincidio con los $pdfCount PDF de Drive. Probablemente falla la lectura de la lista de Drive; no se publica para no romper los enlaces del sitio.";
}

Write-Host '6. Ajustando configuración de Quartz / Explorer...' -ForegroundColor Cyan;
$configText = [System.IO.File]::ReadAllText($quartzConfigPath, [System.Text.Encoding]::UTF8);
$configNewline = if ($configText.Contains("`r`n")) { "`r`n" } else { "`n" };

$baseUrlPattern = '(?m)^([ \t]*baseUrl:[ \t]*)[^\r\n]*';
if ([regex]::IsMatch($configText, $baseUrlPattern)) { $configText = ([regex]::new($baseUrlPattern)).Replace($configText, ('${1}' + $expectedBaseUrl), 1); }

$explorerHeadPattern = '(?m)^(?<indent>[ \t]*)-\s*source:\s*["'']@quartz-community/explorer["''][ \t]*\r?\n(?<childIndent>[ \t]+)enabled:\s*true[ \t]*\r?\n';
$explorerMatch = [regex]::Match($configText,$explorerHeadPattern);
if ($explorerMatch.Success) {$restStart = $explorerMatch.Index +$explorerMatch.Length;
    $restText = $configText.Substring($restStart);
    $nextPlugin = [regex]::Match($restText, '(?m)^[ \t]*-\s*source:');
    $blockEnd = if ($nextPlugin.Success) { $restStart +$nextPlugin.Index } else { $configText.Length };$explorerBlock = $configText.Substring($explorerMatch.Index, $blockEnd -$explorerMatch.Index);

    if ($explorerBlock -notmatch '(?m)^[ \t]*options:') {
        $indent =$explorerMatch.Groups['childIndent'].Value;
        $optionsText = @(($indent + 'options:'), ($indent + '  title: Explorer'), ($indent + '  folderClickBehavior: link'), ($indent + '  folderDefaultState: open'), ($indent + '  useSavedState: false')) -join $configNewline;
        $insertion =$explorerMatch.Value + $optionsText +$configNewline;
        $configText =$configText.Substring(0, $explorerMatch.Index) +$insertion + $configText.Substring($restStart);
    } else {
        $explorerBlockUpdated =$explorerBlock;
        $folderStatePattern = '(?m)^([ \t]*folderDefaultState:[ \t]*)[^\r\n]*';
        $savedStatePattern = '(?m)^([ \t]*useSavedState:[ \t]*)[^\r\n]*';
        if ([regex]::IsMatch($explorerBlockUpdated, $folderStatePattern)) { $explorerBlockUpdated = ([regex]::new($folderStatePattern)).Replace($explorerBlockUpdated, '${1}open', 1); }
        if ([regex]::IsMatch($explorerBlockUpdated, $savedStatePattern)) { $explorerBlockUpdated = ([regex]::new($savedStatePattern)).Replace($explorerBlockUpdated, '${1}false', 1); }
        $configText =$configText.Substring(0, $explorerMatch.Index) +$explorerBlockUpdated + $configText.Substring($blockEnd);
    }
}
[System.IO.File]::WriteAllText($quartzConfigPath, $configText, [System.Text.UTF8Encoding]::new($false));

Write-Host '7. Eliminando archivos PDF físicos para no saturar GitHub...' -ForegroundColor Cyan;
Get-ChildItem -LiteralPath $quartzContentDir -Filter '*.pdf' -File -Recurse | Remove-Item -Force;

Write-Host '8. Subiendo a GitHub...' -ForegroundColor Cyan;
Set-Location -LiteralPath $quartzRepoDir;

# Corre git sin que sus mensajes (que salen por stderr) se confundan con errores de PowerShell.
# Deja el codigo de salida en $script:CodigoGit y las lineas que imprimio en $script:SalidaGit.
function Invoke-Git([string[]]$GitArgs, [switch]$Silencioso) {
    $previousPreference = $ErrorActionPreference;
    $ErrorActionPreference = 'Continue';
    try {
        $salida = & git @GitArgs 2>&1;
        $script:CodigoGit = $LASTEXITCODE;
    }
    finally { $ErrorActionPreference = $previousPreference; }
    $script:SalidaGit = @();
    foreach ($linea in @($salida)) {
        if ($null -eq $linea) { continue; }
        $texto = "$linea";
        $script:SalidaGit += $texto;
        if (-not $Silencioso) { Write-Host "   $texto" -ForegroundColor Gray; }
    }
}

Invoke-Git @('add', '.');
if ($script:CodigoGit -ne 0) { throw 'git add fallo. No se publico nada.'; }

Invoke-Git @('status', '--porcelain') -Silencioso;
$cambiosPendientes = @($script:SalidaGit | Where-Object { $_.Trim() });

if ($cambiosPendientes.Count -gt 0) {
    Invoke-Git @('commit', '-m', 'Actualizacion automatica: enlaces Drive, Explorer e indice');
    if ($script:CodigoGit -ne 0) { throw 'git commit fallo. No se publico nada.'; }
} else {
    Write-Host '   No hay cambios nuevos respecto a lo ya publicado.' -ForegroundColor Gray;
}

Invoke-Git @('push', 'origin', 'main');
if ($script:CodigoGit -ne 0) { throw 'git push fallo: los cambios NO se publicaron en GitHub.'; }

Write-Host '¡Proceso terminado exitosamente!' -ForegroundColor Green;
}
finally {
    $mutexPublicar.ReleaseMutex();
    $mutexPublicar.Dispose();
}

if (-not $NoPause -and [Environment]::UserInteractive -and -not [Console]::IsInputRedirected) { Read-Host -Prompt 'Presiona Enter para salir...' | Out-Null; }