param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

$packageScript = Join-Path $PSScriptRoot 'Package-Release.ps1'
$payloadDir = Join-Path $Root 'release\payload'

if ($Clean -and (Test-Path -LiteralPath $payloadDir)) {
    Remove-Item -LiteralPath $payloadDir -Recurse -Force
}

& $packageScript -Root $Root -PayloadDir $payloadDir -Clean:$Clean
