param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$WixVersion = '6.0.2',
    [string]$DotnetRuntimeVersion = '6.0.36',
    [switch]$KeepDownloads
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Info {
    param([string]$Message)
    Write-Host "[Setup-LocalWix] $Message"
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

$toolsDir = Join-Path $Root 'tools'
$dotnetInstallScript = Join-Path $toolsDir 'dotnet-install.ps1'
$dotnetDir = Join-Path $toolsDir 'dotnet6'
$wixLocalDir = Join-Path $toolsDir 'wix_local'
$wixNupkgPath = Join-Path $toolsDir "wix.$WixVersion.nupkg"
$wixZipPath = Join-Path $toolsDir "wix.$WixVersion.zip"

Ensure-Directory -Path $toolsDir

$wixUrl = "https://www.nuget.org/api/v2/package/wix/$WixVersion"
Write-Info "Descargando WiX $WixVersion..."
Invoke-WebRequest -Uri $wixUrl -OutFile $wixNupkgPath

Copy-Item -LiteralPath $wixNupkgPath -Destination $wixZipPath -Force
if (Test-Path -LiteralPath $wixLocalDir) {
    Remove-Item -LiteralPath $wixLocalDir -Recurse -Force
}
Expand-Archive -LiteralPath $wixZipPath -DestinationPath $wixLocalDir -Force

Write-Info "Descargando instalador local de runtime .NET..."
Invoke-WebRequest -Uri 'https://dot.net/v1/dotnet-install.ps1' -OutFile $dotnetInstallScript

Write-Info "Instalando runtime .NET $DotnetRuntimeVersion en modo local..."
powershell -ExecutionPolicy Bypass -File $dotnetInstallScript `
    -Runtime dotnet `
    -Version $DotnetRuntimeVersion `
    -InstallDir $dotnetDir `
    -NoPath

$wixExe = Join-Path $wixLocalDir 'tools\net6.0\any\wix.exe'
if (-not (Test-Path -LiteralPath $wixExe)) {
    throw "No se encontro wix.exe en $wixExe"
}

$env:DOTNET_ROOT = $dotnetDir
$env:PATH = "$dotnetDir;$([IO.Path]::GetDirectoryName($wixExe));$env:PATH"

$versionOutput = & $wixExe --version
Write-Info "WiX local listo. Version detectada: $versionOutput"

if (-not $KeepDownloads) {
    Remove-Item -LiteralPath $wixNupkgPath -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $wixZipPath -Force -ErrorAction SilentlyContinue
}

Write-Host ''
Write-Host 'Para esta sesion, exporta estas variables antes de compilar MSI:'
Write-Host "  `$env:DOTNET_ROOT='$dotnetDir'"
Write-Host "  `$env:PATH='$([IO.Path]::GetDirectoryName($wixExe));`$env:DOTNET_ROOT;`$env:PATH'"
