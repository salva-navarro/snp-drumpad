param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$Version = '2.0.1',
    [switch]$SkipPortable
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Info {
    param([string]$Message)
    Write-Host "[Create-ReleaseBundle] $Message"
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

$buildScript = Join-Path $PSScriptRoot 'Build.ps1'
& $buildScript -Root $Root -Clean

$buildMsiScript = Join-Path $PSScriptRoot 'Build-MSI.ps1'
$msiVersion = if ($Version -match '^\d+\.\d+\.\d+$') { "$Version.0" } else { $Version }
& $buildMsiScript -Root $Root -Version $msiVersion

$releaseDir = Join-Path $Root 'release'
$payloadDir = Join-Path $releaseDir 'payload'
$artifactDir = Join-Path $releaseDir 'artifacts'
$distributionRoot = Join-Path $releaseDir 'distribution'
$bundleName = "SNPDrumPad-v$Version"
$bundleDir = Join-Path $distributionRoot $bundleName

if (-not (Test-Path -LiteralPath $payloadDir)) {
    throw "No existe payload en $payloadDir"
}

$msiFiles = Get-ChildItem -LiteralPath $artifactDir -Filter '*.msi' -File |
    Where-Object { $_.Name -like "*-$msiVersion-x64.msi" } |
    Sort-Object Name
if (-not $msiFiles -or $msiFiles.Count -eq 0) {
    throw "No se encontro MSI en $artifactDir"
}

if (Test-Path -LiteralPath $bundleDir) {
    Remove-Item -LiteralPath $bundleDir -Recurse -Force
}
Ensure-Directory -Path $bundleDir

$portableRoot = Join-Path $bundleDir 'portable'
$installerRoot = Join-Path $bundleDir 'installer'
$docsRoot = Join-Path $bundleDir 'docs'
Ensure-Directory -Path $portableRoot
Ensure-Directory -Path $installerRoot
Ensure-Directory -Path $docsRoot

$portableApp = Join-Path $portableRoot 'SNPDrumPad'
Copy-Item -LiteralPath $payloadDir -Destination $portableApp -Recurse -Force

$portableLauncher = @'
param()
$ErrorActionPreference = 'Stop'
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    $launcher = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) { 'pwsh.exe' } else { 'powershell.exe' }
    & $launcher -Sta -ExecutionPolicy Bypass -File $PSCommandPath
    exit $LASTEXITCODE
}
. (Join-Path $PSScriptRoot 'src\SNPDrumPad.ps1')
'@
$portableLauncherPath = Join-Path $portableApp 'Run-SNPDrumPad.ps1'
Set-Content -LiteralPath $portableLauncherPath -Value $portableLauncher -Encoding UTF8

foreach ($msi in $msiFiles) {
    Copy-Item -LiteralPath $msi.FullName -Destination (Join-Path $installerRoot $msi.Name) -Force
}

$docsToCopy = @(
    (Join-Path $Root 'README.md'),
    (Join-Path $Root 'CHANGELOG.md'),
    (Join-Path $Root 'docs\UserGuide.md'),
    (Join-Path $Root 'docs\AdminGuide.md'),
    (Join-Path $Root 'docs\MSIInstallGuide.md')
)
foreach ($doc in $docsToCopy) {
    if (Test-Path -LiteralPath $doc) {
        Copy-Item -LiteralPath $doc -Destination $docsRoot -Force
    }
}

$portableZip = Join-Path $bundleDir "SNPDrumPad-portable-v$Version.zip"
if (Test-Path -LiteralPath $portableZip) { Remove-Item -LiteralPath $portableZip -Force }
Compress-Archive -LiteralPath $portableApp -DestinationPath $portableZip -CompressionLevel Optimal

$bundleZip = Join-Path $distributionRoot "$bundleName.zip"
if (Test-Path -LiteralPath $bundleZip) { Remove-Item -LiteralPath $bundleZip -Force }
Compress-Archive -LiteralPath $bundleDir -DestinationPath $bundleZip -CompressionLevel Optimal

$hashTargets = @()
foreach ($msi in $msiFiles) { $hashTargets += $msi.FullName }
$hashTargets += @($portableZip, $bundleZip)
$hashLines = foreach ($target in $hashTargets) {
    $h = Get-FileHash -Algorithm SHA256 -LiteralPath $target
    "{0}  {1}" -f $h.Hash, (Split-Path -Leaf $target)
}
Set-Content -LiteralPath (Join-Path $bundleDir 'SHA256SUMS.txt') -Value $hashLines -Encoding ASCII

Write-Info "Bundle listo en: $bundleDir"
Write-Info "Zip distribucion: $bundleZip"
