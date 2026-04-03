param(
    [string]$Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$PayloadDir = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'release\payload'),
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Write-Info {
    param([string]$Message)
    Write-Host "[Package-Release] $Message"
}

function Ensure-Directory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Copy-TreeIfPresent {
    param(
        [string]$SourcePath,
        [string]$DestinationPath
    )

    if (-not (Test-Path -LiteralPath $SourcePath)) {
        return $false
    }

    Ensure-Directory -Path $DestinationPath
    Get-ChildItem -LiteralPath $SourcePath -Force | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $DestinationPath -Recurse -Force
    }
    return $true
}

function New-SampleConfig {
    param([string]$ConfigFile)

    $sample = [ordered]@{
        schemaVersion = 1
        productName   = 'SNPDrumPad'
        sections      = @(
            [ordered]@{
                name      = 'General'
                templates = @(
                    [ordered]@{ name = 'Saludo'; text = 'Hola, gracias por contactar con soporte. Te ayudamos enseguida.' },
                    [ordered]@{ name = 'Pedir datos'; text = 'Para revisar el caso, necesito por favor el identificador, capturas y hora aproximada.' },
                    [ordered]@{ name = 'Cierre'; text = 'Dejamos el ticket en seguimiento. Si necesitas algo mas, avisanos por favor.' }
                )
            },
            [ordered]@{
                name      = 'Tickets'
                templates = @(
                    [ordered]@{ name = 'Apertura'; text = 'He registrado la incidencia y estoy revisando el origen.' },
                    [ordered]@{ name = 'Pendiente usuario'; text = 'Queda pendiente tu confirmacion para continuar con la validacion.' }
                )
            }
        )
    }

    $sample | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $ConfigFile -Encoding UTF8
}

function New-LauncherScript {
    param([string]$LauncherFile)

    $launcher = @'
$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$baseDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$configPath = Join-Path $baseDir "config\templates.json"

function Load-Templates {
    if (-not (Test-Path -LiteralPath $configPath)) {
        throw "No se encontro el archivo de configuracion: $configPath"
    }

    $json = Get-Content -LiteralPath $configPath -Raw
    $data = $json | ConvertFrom-Json
    if (-not $data.sections) {
        throw "El archivo de configuracion no contiene secciones."
    }

    return $data
}

function Add-ButtonForTemplate {
    param(
        [System.Windows.Forms.FlowLayoutPanel]$Panel,
        [string]$Name,
        [string]$Text,
        [bool]$PasteAfterCopy
    )

    $button = New-Object System.Windows.Forms.Button
    $button.Width = 150
    $button.Height = 42
    $button.Text = $Name
    $button.Tag = [pscustomobject]@{
        Text  = $Text
        Paste = $PasteAfterCopy
    }
    $button.Add_Click({
        $payload = $this.Tag
        [System.Windows.Forms.Clipboard]::SetText([string]$payload.Text)
        if ($payload.Paste) {
            Start-Sleep -Milliseconds 120
            [System.Windows.Forms.SendKeys]::SendWait("^v")
        }
    })
    [void]$Panel.Controls.Add($button)
}

$templates = Load-Templates

$form = New-Object System.Windows.Forms.Form
$form.Text = "SNPDrumPad"
$form.StartPosition = "CenterScreen"
$form.Size = New-Object System.Drawing.Size(620, 520)
$form.MinimumSize = New-Object System.Drawing.Size(520, 380)
$form.TopMost = $true
$form.Font = New-Object System.Drawing.Font("Segoe UI", 9)

$header = New-Object System.Windows.Forms.Panel
$header.Dock = "Top"
$header.Height = 48
$header.Padding = New-Object System.Windows.Forms.Padding(10, 8, 10, 8)
$header.BackColor = [System.Drawing.Color]::FromArgb(34, 45, 60)

$title = New-Object System.Windows.Forms.Label
$title.AutoSize = $true
$title.ForeColor = [System.Drawing.Color]::White
$title.Font = New-Object System.Drawing.Font("Segoe UI Semibold", 11)
$title.Text = "SNPDrumPad - plantillas rapidas"
$title.Location = New-Object System.Drawing.Point(10, 13)

$topMostToggle = New-Object System.Windows.Forms.CheckBox
$topMostToggle.Text = "Siempre arriba"
$topMostToggle.Checked = $true
$topMostToggle.AutoSize = $true
$topMostToggle.ForeColor = [System.Drawing.Color]::White
$topMostToggle.Location = New-Object System.Drawing.Point(430, 14)
$topMostToggle.Add_CheckedChanged({ $form.TopMost = $topMostToggle.Checked })

$header.Controls.Add($title)
$header.Controls.Add($topMostToggle)

$toolbar = New-Object System.Windows.Forms.Panel
$toolbar.Dock = "Top"
$toolbar.Height = 54
$toolbar.Padding = New-Object System.Windows.Forms.Padding(10, 8, 10, 8)

$sectionLabel = New-Object System.Windows.Forms.Label
$sectionLabel.Text = "Seccion"
$sectionLabel.AutoSize = $true
$sectionLabel.Location = New-Object System.Drawing.Point(10, 20)

$sectionCombo = New-Object System.Windows.Forms.ComboBox
$sectionCombo.DropDownStyle = "DropDownList"
$sectionCombo.Width = 180
$sectionCombo.Location = New-Object System.Drawing.Point(65, 15)

$searchLabel = New-Object System.Windows.Forms.Label
$searchLabel.Text = "Buscar"
$searchLabel.AutoSize = $true
$searchLabel.Location = New-Object System.Drawing.Point(260, 20)

$searchBox = New-Object System.Windows.Forms.TextBox
$searchBox.Width = 160
$searchBox.Location = New-Object System.Drawing.Point(310, 15)

$pasteCheck = New-Object System.Windows.Forms.CheckBox
$pasteCheck.Text = "Pegar tras copiar"
$pasteCheck.Checked = $true
$pasteCheck.AutoSize = $true
$pasteCheck.Location = New-Object System.Drawing.Point(500, 18)

$toolbar.Controls.AddRange(@($sectionLabel, $sectionCombo, $searchLabel, $searchBox, $pasteCheck))

$panel = New-Object System.Windows.Forms.FlowLayoutPanel
$panel.Dock = "Fill"
$panel.AutoScroll = $true
$panel.WrapContents = $true
$panel.Padding = New-Object System.Windows.Forms.Padding(10)
$panel.FlowDirection = "LeftToRight"

$status = New-Object System.Windows.Forms.StatusStrip
$statusLabel = New-Object System.Windows.Forms.ToolStripStatusLabel
$statusLabel.Text = "Listo"
[void]$status.Items.Add($statusLabel)

$form.Controls.Add($panel)
$form.Controls.Add($status)
$form.Controls.Add($toolbar)
$form.Controls.Add($header)

$sectionCombo.Items.Add("Todas") | Out-Null
foreach ($section in $templates.sections) {
    [void]$sectionCombo.Items.Add($section.name)
}
$sectionCombo.SelectedIndex = 0

function Refresh-Templates {
    $panel.SuspendLayout()
    try {
        $panel.Controls.Clear()

        $sectionFilter = [string]$sectionCombo.SelectedItem
        $query = $searchBox.Text.Trim().ToLowerInvariant()
        $count = 0

        foreach ($section in $templates.sections) {
            if ($sectionFilter -ne 'Todas' -and $section.name -ne $sectionFilter) {
                continue
            }

            foreach ($template in $section.templates) {
                $name = [string]$template.name
                $text = [string]$template.text
                if ($query) {
                    $haystack = ($name + ' ' + $text).ToLowerInvariant()
                    if (-not $haystack.Contains($query)) {
                        continue
                    }
                }

                Add-ButtonForTemplate -Panel $panel -Name "$($section.name): $name" -Text $text -PasteAfterCopy $pasteCheck.Checked
                $count++
            }
        }

        $statusLabel.Text = if ($count -eq 0) { "Sin resultados" } else { "$count plantilla(s) visibles" }
    }
    finally {
        $panel.ResumeLayout()
    }
}

$sectionCombo.Add_SelectedIndexChanged({ Refresh-Templates })
$searchBox.Add_TextChanged({ Refresh-Templates })
$pasteCheck.Add_CheckedChanged({ Refresh-Templates })

Refresh-Templates
[void]$form.ShowDialog()
'@

    $launcher | Set-Content -LiteralPath $LauncherFile -Encoding UTF8
}

function New-RuntimeLauncher {
    param([string]$LauncherFile)

    $launcher = @'
param()
$ErrorActionPreference = "Stop"

$appScript = Join-Path $PSScriptRoot "src\SNPDrumPad.ps1"
if (-not (Test-Path -LiteralPath $appScript)) {
    throw "No se encontro el script principal: $appScript"
}

if ([Threading.Thread]::CurrentThread.ApartmentState -eq 'STA') {
    . $appScript
    exit $LASTEXITCODE
}

$launcherExe = Join-Path $env:WINDIR "System32\WindowsPowerShell\v1.0\powershell.exe"
if (-not (Test-Path -LiteralPath $launcherExe)) {
    $launcherExe = "powershell.exe"
}

& $launcherExe -NoProfile -ExecutionPolicy Bypass -Sta -File $appScript
exit $LASTEXITCODE
'@

    $launcher | Set-Content -LiteralPath $LauncherFile -Encoding UTF8
}

function New-DefaultIconText {
    param([string]$IconFile)

    if (-not (Test-Path -LiteralPath $IconFile)) {
        throw "No se encontro el icono de marca en $IconFile"
    }
}

Ensure-Directory -Path $PayloadDir

if ($Clean -and (Test-Path -LiteralPath $PayloadDir)) {
    Remove-Item -LiteralPath $PayloadDir -Recurse -Force
    Ensure-Directory -Path $PayloadDir
}

$copiedAny = $false
foreach ($relative in @('src', 'config', 'assets')) {
    $sourcePath = Join-Path $Root $relative
    $destinationPath = Join-Path $PayloadDir $relative
    if (Copy-TreeIfPresent -SourcePath $sourcePath -DestinationPath $destinationPath) {
        $copiedAny = $true
    }
}

$configFile = Join-Path $PayloadDir 'config\templates.json'
$primaryRuntime = Join-Path $PayloadDir 'src\SNPDrumPad.ps1'
$launcherFile = Join-Path $PayloadDir 'SNPDrumPad.ps1'
$runtimeLauncherFile = Join-Path $PayloadDir 'Run-SNPDrumPad.ps1'
$iconFile = Join-Path $PayloadDir 'assets\brand\app.ico'

if (-not (Test-Path -LiteralPath $configFile)) {
    Ensure-Directory -Path (Split-Path -Parent $configFile)
    New-SampleConfig -ConfigFile $configFile
    $copiedAny = $true
}

if (-not (Test-Path -LiteralPath $primaryRuntime) -and -not (Test-Path -LiteralPath $launcherFile)) {
    New-LauncherScript -LauncherFile $launcherFile
    $copiedAny = $true
}

New-RuntimeLauncher -LauncherFile $runtimeLauncherFile
$copiedAny = $true

New-DefaultIconText -IconFile $iconFile

$manifest = [ordered]@{
    product    = 'SNPDrumPad'
    version    = '1.0.0'
    createdUtc = (Get-Date).ToUniversalTime().ToString('o')
    files      = Get-ChildItem -LiteralPath $PayloadDir -Recurse -File | ForEach-Object {
        [ordered]@{
            path = $_.FullName.Substring($PayloadDir.Length + 1)
            size = $_.Length
        }
    }
}

$manifestPath = Join-Path $PayloadDir 'package-manifest.json'
$manifest | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $manifestPath -Encoding UTF8

if (-not $copiedAny) {
    throw "No se ha encontrado ningun fichero runtime para empaquetar."
}

Write-Info "Payload preparado en $PayloadDir"
