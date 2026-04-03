param()

$ErrorActionPreference = 'Stop'

if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    $launcher = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) { 'pwsh.exe' } else { 'powershell.exe' }
    & $launcher -Sta -ExecutionPolicy Bypass -File $PSCommandPath
    exit $LASTEXITCODE
}

$scriptRoot = Split-Path -Parent $PSScriptRoot
. (Join-Path $scriptRoot 'src\SNPDrumPad.ps1')
