$ErrorActionPreference='Stop';$quartzRepoDir='C:\Users\Luciano\Documents\my-notes-quartz';
$quartzContentDir="$quartzRepoDir\content";
$quartzConfigPath="$quartzRepoDir\quartz.config.yaml";
$obsidianVault='C:\Users\Luciano\iCloudDrive\iCloud~md~obsidian\my-notes\compartidos';$RclonePath='C:\Users\Luciano\Tools\rclone\rclone.exe';
$RemotePath='gdrive:compartidos-varios';$expectedBaseUrl='lucianoab10-web.github.io/my-notes';

$clasesOrigen="$obsidianVault\clases";
$clasesPasadasOrigen="$clasesOrigen\clases-pasadas";
$notasOrigen="$obsidianVault\notas-y-apuntes";

$carpetasASincronizar=@(
    [pscustomobject]@{Nombre='clases';Ruta=$clasesOrigen};
    [pscustomobject]@{Nombre='clases-pasadas';Ruta=$clasesPasadasOrigen};
    [pscustomobject]@{Nombre='notas-y-apuntes';Ruta=$notasOrigen}
);

if(-not(Test-Path -LiteralPath:$quartzRepoDir -PathType:Container)){throw "No repo: $quartzRepoDir";}
if(-not(Test-Path -LiteralPath:$quartzConfigPath -PathType:Leaf)){throw "No config: $quartzConfigPath";}
if(-not(Test-Path -LiteralPath:$obsidianVault -PathType:Container)){throw "No vault: $obsidianVault";}
if(-not(Test-Path -LiteralPath:$RclonePath -PathType:Leaf)){throw "No rclone: $RclonePath";}

foreach($carpeta in($carpetasASincronizar)){
    if(-not(Test-Path -LiteralPath:($carpeta.Ruta) -PathType:Container)){throw "No carpeta: $($carpeta.Ruta)";}
}

Write-Host('1. Obteniendo PDFs de Drive...') -ForegroundColor:Cyan;
$previousErrorActionPreference=$ErrorActionPreference;
try{
    $ErrorActionPreference='Continue';
    $jsonLines=&$RclonePath --log-level ERROR lsjson $RemotePath --files-only --recursive 2>$null;
    $rcloneExitCode=$LASTEXITCODE;
}finally{
    $ErrorActionPreference=$previousErrorActionPreference;
}

if($rcloneExitCode -ne 0){throw "rclone error $rcloneExitCode";}
$jsonText=@($jsonLines) -join "`n";
if([string]::IsNullOrWhiteSpace($jsonText)){throw "rclone no archivos.";}

$archivosDrive=@(ConvertFrom-Json -InputObject:$jsonText);
$pdfUrlByPath=@{};
$pdfUrlByName=@{};
$duplicatePdfNames=@{};
$pdfCount=0;

foreach($archivoDrive in($archivosDrive)){
    if($archivoDrive.Name -and $archivoDrive.ID -and $archivoDrive.Name -match '(?i)\.pdf$'){
        $pdfCount++;
        $urlDrive="https://drive.google.com/file/d/$($archivoDrive.ID)/view";
        $relativePath=[string]$archivoDrive.Path;
        if([string]::IsNullOrWhiteSpace($relativePath)){$relativePath=[string]$archivoDrive.Name;}
        $relativePath=$relativePath.Replace('\','/').TrimStart('/');
        $pdfUrlByPath[$relativePath]=$urlDrive;
        $name=[string]$archivoDrive.Name;
        if($pdfUrlByName.ContainsKey($name)){
            if($pdfUrlByName[$name] -ne $urlDrive){
                $duplicatePdfNames[$name]=$true;
                $pdfUrlByName.Remove($name);
            }
        }elseif(-not $duplicatePdfNames.ContainsKey($name)){
            $pdfUrlByName[$name]=$urlDrive;
        }
    }
}

if($pdfCount -eq 0){throw "No hay PDFs.";}
Write-Host("   Encontrados $pdfCount PDF(s).") -ForegroundColor:Gray;

Write-Host('2. Limpiando content antiguo...') -ForegroundColor:Cyan;
if(Test-Path -LiteralPath:$quartzContentDir -PathType:Container){
    Get-ChildItem -LiteralPath:$quartzContentDir -Force | Remove-Item -Recurse -Force;
}else{
    New-Item -ItemType:Directory -Path:$quartzContentDir -Force | Out-Null;
}

Write-Host('3. Copiando de Obsidian a Quartz...') -ForegroundColor:Cyan;
$clasesDestino="$quartzContentDir\clases";
New-Item -ItemType:Directory -Path:$clasesDestino -Force | Out-Null;
Get-ChildItem -LiteralPath:$clasesOrigen -Force | Where-Object{$_.Name -ne 'clases-pasadas'} | ForEach-Object{Copy-Item -LiteralPath:($_.FullName) -Destination:$clasesDestino -Recurse -Force;};

Copy-Item -LiteralPath:$clasesPasadasOrigen -Destination:$quartzContentDir -Recurse -Force;
Copy-Item -LiteralPath:$notasOrigen -Destination:$quartzContentDir -Recurse -Force;

Write-Host('4. Autogenerando Indice...') -ForegroundColor:Cyan;
$indexContent="# Índice de Apuntes`n`n";

$indexContent+="## Ramos Activos`n";
$clasesPath="$quartzContentDir\clases";
if(Test-Path -LiteralPath:$clasesPath){
    foreach($archivo in(Get-ChildItem -LiteralPath:$clasesPath -Filter:'*.md' -File)){
        if($archivo.BaseName -ne 'index'){$indexContent+="- [[$($archivo.BaseName)]]`n";}
    }
}

$indexContent+="`n## Ramos Pasados`n";
$pasadasPath="$quartzContentDir\clases-pasadas";
if(Test-Path -LiteralPath:$pasadasPath){
    foreach($archivo in(Get-ChildItem -LiteralPath:$pasadasPath -Filter:'*.md' -File)){
        if($archivo.BaseName -ne 'index'){$indexContent+="- [[clases-pasadas/$($archivo.BaseName)]]`n";}
    }
}

$indexContent+="`n## Compartidos y Otros Apuntes`n";
$notasPath="$quartzContentDir\notas-y-apuntes";
if(Test-Path -LiteralPath:$notasPath){
    foreach($archivo in(Get-ChildItem -LiteralPath:$notasPath -Filter:'*.md' -File)){
        if($archivo.BaseName -ne 'index'){$indexContent+="- [[notas-y-apuntes/$($archivo.BaseName)]]`n";}
    }
}
[System.IO.File]::WriteAllText("$quartzContentDir\index.md",$indexContent,[System.Text.UTF8Encoding]::new($false));

Write-Host('5. Convirtiendo enlaces...') -ForegroundColor:Cyan;
$unresolvedPdfLinks=[System.Collections.Generic.List[string]]::new();
$wikilinkPattern='(?i)!?\[\[(?<target>[^\]|#]+\.pdf)(?:\|(?<alias>[^\]]+))?\]\]';
$markdownPdfPattern='(?i)\[(?<label>[^\]]+)\]\((?<target>(?!https?://|mailto:)[^)\s]+\.pdf)(?:\s+"[^"]*")?\)';

foreach($archivo in(Get-ChildItem -LiteralPath:$quartzContentDir -Filter:'*.md' -File -Recurse)){
    $contenido=[System.IO.File]::ReadAllText($archivo.FullName,[System.Text.Encoding]::UTF8);
    $original=$contenido;

    $wikilinkScriptBlock={
        param($match);
        $target=$match.Groups['target'].Value.Trim();
        $normalizedTarget=[Uri]::UnescapeDataString($target).Replace('\','/');
        $normalizedTarget=$normalizedTarget -replace '^\./','';
        $normalizedTarget=$normalizedTarget.TrimStart('/');
        $url=$null;
        if($script:pdfUrlByPath.ContainsKey($normalizedTarget)){$url=$script:pdfUrlByPath[$normalizedTarget];}
        elseif($script:pdfUrlByName.ContainsKey([System.IO.Path]::GetFileName($normalizedTarget))){$url=$script:pdfUrlByName[[System.IO.Path]::GetFileName($normalizedTarget)];}
        if(-not $url){[void]$script:unresolvedPdfLinks.Add("$($archivo.FullName) :: $target");return $match.Value;}
        $alias=$match.Groups['alias'].Value.Trim();
        if([string]::IsNullOrWhiteSpace($alias)){$alias=[System.IO.Path]::GetFileName($target.Replace('\','/'));}
        return "[$alias ↗ Abrir en Drive]($url)";
    }.GetNewClosure();
    
    $wikilinkEvaluator=[System.Text.RegularExpressions.MatchEvaluator]$wikilinkScriptBlock;
    $contenido=[System.Text.RegularExpressions.Regex]::Replace($contenido,$wikilinkPattern,$wikilinkEvaluator);

    $markdownScriptBlock={
        param($match);
        $target=$match.Groups['target'].Value.Trim();
        $label=$match.Groups['label'].Value.Trim();
        $normalizedTarget=[Uri]::UnescapeDataString($target).Replace('\','/');
        $normalizedTarget=$normalizedTarget -replace '^\./','';
        $normalizedTarget=$normalizedTarget.TrimStart('/');
        $url=$null;
        if($script:pdfUrlByPath.ContainsKey($normalizedTarget)){$url=$script:pdfUrlByPath[$normalizedTarget];}
        elseif($script:pdfUrlByName.ContainsKey([System.IO.Path]::GetFileName($normalizedTarget))){$url=$script:pdfUrlByName[[System.IO.Path]::GetFileName($normalizedTarget)];}
        if(-not $url){[void]$script:unresolvedPdfLinks.Add("$($archivo.FullName) :: $target");return $match.Value;}
        if($label -notmatch '(?i)abrir en drive'){$label="$label ↗ Abrir en Drive";}
        return "[$label]($url)";
    }.GetNewClosure();

    $markdownEvaluator=[System.Text.RegularExpressions.MatchEvaluator]$markdownScriptBlock;
    $contenido=[System.Text.RegularExpressions.Regex]::Replace($contenido,$markdownPdfPattern,$markdownEvaluator);

    if($contenido -ne $original){[System.IO.File]::WriteAllText($archivo.FullName,$contenido,[System.Text.UTF8Encoding]::new($false));}
}

if($unresolvedPdfLinks.Count -gt 0){
    $uniqueUnresolved=@($unresolvedPdfLinks | Sort-Object -Unique);
    Write-Host("Errores de PDF:") -ForegroundColor:Red;
    foreach($item in($uniqueUnresolved | Select-Object -First:30)){Write-Host("   - $item") -ForegroundColor:Yellow;}
    throw 'Faltan PDFs en Drive.';
}

Write-Host('6. Ajustando Quartz...') -ForegroundColor:Cyan;
$configText=[System.IO.File]::ReadAllText($quartzConfigPath,[System.Text.Encoding]::UTF8);
$configNewline=if($configText.Contains("`r`n")){ "`r`n" }else{ "`n" };

$baseUrlPattern='(?m)^([ \t]*baseUrl:[ \t]*).*$';
if([regex]::IsMatch($configText,$baseUrlPattern)){$configText=[regex]::Replace($configText,$baseUrlPattern,('${1}'+$expectedBaseUrl),1);}

$explorerHeadPattern='(?m)^(?<indent>[ \t]*)-\s*source:\s*["'']@quartz-community/explorer["''][ \t]*\r?\n(?<childIndent>[ \t]+)enabled:\s*true[ \t]*\r?\n';
$explorerMatch=[regex]::Match($configText,$explorerHeadPattern);
if($explorerMatch.Success){$restStart=$explorerMatch.Index+$explorerMatch.Length;
    $restText=$configText.Substring($restStart);
    $nextPlugin=[regex]::Match($restText,'(?m)^[ \t]*-\s*source:');
    $blockEnd=if($nextPlugin.Success){$restStart+$nextPlugin.Index}else{$configText.Length};$explorerBlock=$configText.Substring($explorerMatch.Index,$blockEnd-$explorerMatch.Index);

    if($explorerBlock -notmatch '(?m)^[ \t]*options:'){
        $indent=$explorerMatch.Groups['childIndent'].Value;
        $optionsText=@(($indent+'options:'),($indent+'  title: Explorer'),($indent+'  folderClickBehavior: link'),($indent+'  folderDefaultState: open'),($indent+'  useSavedState: false')) -join$configNewline;
        $insertion=$explorerMatch.Value+$optionsText+$configNewline;
        $configText=$configText.Substring(0,$explorerMatch.Index)+$insertion+$configText.Substring($restStart);
    }else{
        $explorerBlockUpdated=$explorerBlock;
        if($explorerBlockUpdated -match '(?m)^([ \t]*folderDefaultState:[ \t]*).*$'){$explorerBlockUpdated=[regex]::Replace($explorerBlockUpdated,'(?m)^([ \t]*folderDefaultState:[ \t]*).*$','${1}open',1);}
        if($explorerBlockUpdated -match '(?m)^([ \t]*useSavedState:[ \t]*).*$'){$explorerBlockUpdated=[regex]::Replace($explorerBlockUpdated,'(?m)^([ \t]*useSavedState:[ \t]*).*$','${1}false',1);}
        $configText=$configText.Substring(0,$explorerMatch.Index)+$explorerBlockUpdated+$configText.Substring($blockEnd);
    }
}
[System.IO.File]::WriteAllText($quartzConfigPath,$configText,[System.Text.UTF8Encoding]::new($false));

Write-Host('7. Eliminando PDFs locales...') -ForegroundColor:Cyan;
Get-ChildItem -LiteralPath:$quartzContentDir -Filter:'*.pdf' -File -Recurse | Remove-Item -Force;

Write-Host('8. Subiendo a GitHub...') -ForegroundColor:Cyan;
Set-Location -LiteralPath:$quartzRepoDir;

git add .;
git commit -m 'Actualizacion automatica: enlaces Drive, Explorer e indice';
git push origin main;

Write-Host('¡Proceso terminado exitosamente!') -ForegroundColor:Green;
Read-Host -Prompt:'Presiona Enter para salir...';