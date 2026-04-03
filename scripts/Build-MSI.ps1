param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$Version = '2.0.0.0',
    [switch]$SkipPortable
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Info {
    param([string]$Message)
    Write-Host "[Build-MSI] $Message"
}

function Resolve-WixCommand {
    $wixCommand = Get-Command wix -ErrorAction SilentlyContinue
    if ($wixCommand) {
        return $wixCommand.Source
    }

    $localWix = Join-Path $Root 'tools\wix_local\tools\net6.0\any\wix.exe'
    $localDotnet = Join-Path $Root 'tools\dotnet6'
    if (Test-Path -LiteralPath $localWix) {
        if (-not (Test-Path -LiteralPath $localDotnet)) {
            throw @"
Se encontro WiX local en:
  $localWix
Pero falta runtime .NET 6 en:
  $localDotnet

Instala runtime local:
  powershell -ExecutionPolicy Bypass -File tools\dotnet-install.ps1 -Runtime dotnet -Version 6.0.36 -InstallDir tools\dotnet6 -NoPath
"@
        }

        $env:DOTNET_ROOT = $localDotnet
        $env:PATH = "$localDotnet;$([IO.Path]::GetDirectoryName($localWix));$env:PATH"
        return $localWix
    }

    throw @"
No se encontro WiX en PATH ni en la ruta local esperada.

Opciones:
1) Instalar WiX (administrador):
   winget install WiXToolset.WiXToolset

2) Usar WiX local sin admin:
   - Ejecuta: powershell -ExecutionPolicy Bypass -File scripts\Setup-LocalWix.ps1
   - Las variables de entorno se configuran automaticamente
"@
}

function New-SanitizedId {
    param([string]$Value)
    $id = ($Value -replace '[^A-Za-z0-9_]', '_')
    if ($id -match '^[0-9]') {
        $id = "id_$id"
    }
    return $id
}

function Get-FragmentXml {
    param(
        [string]$PayloadDir,
        [string]$InstallDirId = 'INSTALLFOLDER'
    )

    $files = Get-ChildItem -LiteralPath $PayloadDir -Recurse -File |
        Where-Object { $_.Name -ne 'package-manifest.json' } |
        Sort-Object FullName
    $componentRefs = New-Object System.Collections.Generic.List[string]
    $nodes = @{}

    function New-Node {
        param([string]$Name)

        [ordered]@{
            Name     = $Name
            Children = @{}
            Files    = New-Object System.Collections.Generic.List[string]
        }
    }

    $root = New-Node -Name ''

    foreach ($file in $files) {
        $relative = $file.FullName.Substring($PayloadDir.Length + 1)
        $segments = $relative -split '[\\]'
        $node = $root
        if ($segments.Count -gt 1) {
            for ($i = 0; $i -lt $segments.Count - 1; $i++) {
                $segment = $segments[$i]
                if (-not $node.Children.ContainsKey($segment)) {
                    $node.Children[$segment] = New-Node -Name $segment
                }
                $node = $node.Children[$segment]
            }
        }
        $node.Files.Add($relative) | Out-Null
    }

    function Emit-Node {
        param(
            [hashtable]$Node,
            [int]$Depth,
            [string]$ParentPath,
            [System.Text.StringBuilder]$Builder
        )

        $indent = '  ' * $Depth
        foreach ($childName in ($Node.Children.Keys | Sort-Object)) {
            $child = $Node.Children[$childName]
            $childPath = if ($ParentPath) { Join-Path $ParentPath $childName } else { $childName }
            $childId = New-SanitizedId ("dir_" + ($childPath -replace '[\\]', '_'))
            [void]$Builder.AppendLine("$indent<Directory Id=`"$childId`" Name=`"$childName`">")
            Emit-Node -Node $child -Depth ($Depth + 1) -ParentPath $childPath -Builder $Builder
            [void]$Builder.AppendLine("$indent</Directory>")
        }

        foreach ($relative in ($Node.Files | Sort-Object)) {
            $componentId = New-SanitizedId ("cmp_" + ($relative -replace '[\\\.]', '_'))
            $fileId = New-SanitizedId ("fil_" + ($relative -replace '[\\\.]', '_'))
            [void]$Builder.AppendLine("$indent<Component Id=`"$componentId`" Guid=`"*`">")
            [void]$Builder.AppendLine("$indent  <File Id=`"$fileId`" Source=`"`$(var.ReleaseDir)\$relative`" KeyPath=`"yes`" />")
            [void]$Builder.AppendLine("$indent</Component>")
            $componentRefs.Add($componentId) | Out-Null
        }
    }

    $xml = New-Object System.Text.StringBuilder
    [void]$xml.AppendLine('<Include xmlns="http://wixtoolset.org/schemas/v4/wxs">')
    [void]$xml.AppendLine('  <Fragment>')
    [void]$xml.AppendLine("    <DirectoryRef Id=`"$InstallDirId`">")
    Emit-Node -Node $root -Depth 2 -ParentPath '' -Builder $xml
    [void]$xml.AppendLine('    </DirectoryRef>')
    [void]$xml.AppendLine('    <ComponentGroup Id="ReleaseFileComponents">')
    foreach ($componentId in $componentRefs) {
        [void]$xml.AppendLine("      <ComponentRef Id=`"$componentId`" />")
    }
    [void]$xml.AppendLine('    </ComponentGroup>')
    [void]$xml.AppendLine('  </Fragment>')
    [void]$xml.AppendLine('</Include>')

    return $xml.ToString()
}

$wixExe = Resolve-WixCommand

$packageScript = Join-Path $PSScriptRoot 'Build.ps1'
& $packageScript -Root $Root -Clean

$payloadDir = Join-Path $Root 'release\payload'
$artifactDir = Join-Path $Root 'release\artifacts'
$wixDir = Join-Path $Root 'installer\wix'
$generatedFragment = Join-Path $wixDir 'GeneratedFiles.wxs'
$sourceWxs = Join-Path $wixDir 'SNPDrumPad.wxs'
$portableSourceWxs = Join-Path $wixDir 'SNPDrumPad.Portable.wxs'
$iconFile = Join-Path $payloadDir 'assets\brand\app.ico'

if (-not (Test-Path -LiteralPath $payloadDir)) {
    throw "No existe el payload preparado en $payloadDir"
}

if (-not (Test-Path -LiteralPath $sourceWxs)) {
    throw "No existe la definicion WiX en $sourceWxs"
}

if (-not (Test-Path -LiteralPath $portableSourceWxs)) {
    throw "No existe la definicion WiX portable en $portableSourceWxs"
}

if (-not (Test-Path -LiteralPath $iconFile)) {
    throw "No existe el icono esperado en $iconFile"
}

New-Item -ItemType Directory -Path $artifactDir -Force | Out-Null
Get-FragmentXml -PayloadDir $payloadDir | Set-Content -LiteralPath $generatedFragment -Encoding UTF8

function Invoke-WixBuild {
    param(
        [string]$SourceWxs,
        [string]$OutputFile
    )

    Write-Info "Compilando $OutputFile ..."
    & $wixExe build $SourceWxs `
        -arch x64 `
        -d ReleaseDir="$payloadDir" `
        -d IconFile="$iconFile" `
        -d ProductVersion="$Version" `
        -o $OutputFile

    if ($LASTEXITCODE -ne 0) {
        throw "WiX devolvio codigo de salida $LASTEXITCODE compilando $OutputFile."
    }

    if (-not (Test-Path -LiteralPath $OutputFile)) {
        throw "WiX no genero el MSI esperado en: $OutputFile"
    }
}

$standardMsiPath = Join-Path $artifactDir ("SNPDrumPad-$Version-x64.msi")
Invoke-WixBuild -SourceWxs $sourceWxs -OutputFile $standardMsiPath
Write-Info "MSI instalable generado en $standardMsiPath"

if (-not $SkipPortable) {
    $portableMsiPath = Join-Path $artifactDir ("SNPDrumPad-Portable-$Version-x64.msi")
    Invoke-WixBuild -SourceWxs $portableSourceWxs -OutputFile $portableMsiPath
    Write-Info "MSI portable generado en $portableMsiPath"
}
