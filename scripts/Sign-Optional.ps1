param(
    [Parameter(Mandatory = $true)]
    [string]$Path,
    [string]$Thumbprint,
    [string]$TimestampUrl = 'http://timestamp.digicert.com'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

if (-not (Test-Path -LiteralPath $Path)) {
    throw "No se encontro el archivo a firmar: $Path"
}

if ([string]::IsNullOrWhiteSpace($Thumbprint)) {
    Write-Host "[Sign-Optional] No se ha indicado certificado. Se omite la firma para $Path"
    return
}

$cert = Get-ChildItem Cert:\CurrentUser\My,Cert:\LocalMachine\My -CodeSigningCert | Where-Object Thumbprint -eq $Thumbprint | Select-Object -First 1
if (-not $cert) {
    throw "No se encontro un certificado de firma con thumbprint $Thumbprint."
}

if (-not (Get-Command signtool.exe -ErrorAction SilentlyContinue)) {
    throw "No se encontro signtool.exe en PATH."
}

& signtool.exe sign /sha1 $Thumbprint /fd SHA256 /tr $TimestampUrl /td SHA256 $Path
