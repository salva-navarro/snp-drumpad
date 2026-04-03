param()

$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $root 'config\templates.json'
if (-not (Test-Path -LiteralPath $configPath)) { throw "Missing config file: $configPath" }

$model = Get-Content -LiteralPath $configPath -Raw -Encoding UTF8 | ConvertFrom-Json

$sections = @()
if ($model.secciones) {
    $sections = @($model.secciones)
} elseif ($model.sections) {
    $sections = @($model.sections)
} else {
    throw 'No se encontraron secciones en config\templates.json.'
}

if ($sections.Count -eq 0) { throw 'La configuracion no contiene secciones.' }

foreach ($section in $sections) {
    $sectionName = if ($section.nombre) { [string]$section.nombre } else { [string]$section.name }
    if ([string]::IsNullOrWhiteSpace($sectionName)) { throw 'Hay una seccion sin nombre.' }

    $templates = if ($section.plantillas) { @($section.plantillas) } else { @($section.templates) }
    if ($null -eq $templates) { throw "La seccion '$sectionName' no tiene array de plantillas." }

    foreach ($template in $templates) {
        $templateName = if ($template.titulo) { [string]$template.titulo } else { [string]$template.name }
        $templateText = if ($template.texto) { [string]$template.texto } else { [string]$template.text }
        if ([string]::IsNullOrWhiteSpace($templateName)) { throw "Hay una plantilla sin titulo en '$sectionName'." }
        if ([string]::IsNullOrWhiteSpace($templateText)) { throw "La plantilla '$templateName' en '$sectionName' tiene texto vacio." }
    }
}

Write-Host 'Templates OK'
