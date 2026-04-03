Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase, System.Xaml, System.Windows.Forms | Out-Null

if (-not ('SNP.Native' -as [type])) {
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
namespace SNP {
  public static class Native {
    [StructLayout(LayoutKind.Sequential)] public struct INPUT { public int type; public InputUnion U; }
    [StructLayout(LayoutKind.Explicit)] public struct InputUnion { [FieldOffset(0)] public KEYBDINPUT ki; }
    [StructLayout(LayoutKind.Sequential)] public struct KEYBDINPUT { public ushort wVk; public ushort wScan; public uint dwFlags; public uint time; public IntPtr dwExtraInfo; }
    [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
    [DllImport("user32.dll")] [return: MarshalAs(UnmanagedType.Bool)] public static extern bool SetForegroundWindow(IntPtr hWnd);
    [DllImport("user32.dll")] public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);
    const int INPUT_KEYBOARD = 1; const uint KEYEVENTF_KEYUP = 0x0002;
    public static void SendCtrlV() {
      INPUT[] i = new INPUT[4];
      i[0].type = INPUT_KEYBOARD; i[0].U.ki.wVk = 0x11;
      i[1].type = INPUT_KEYBOARD; i[1].U.ki.wVk = 0x56;
      i[2].type = INPUT_KEYBOARD; i[2].U.ki.wVk = 0x56; i[2].U.ki.dwFlags = KEYEVENTF_KEYUP;
      i[3].type = INPUT_KEYBOARD; i[3].U.ki.wVk = 0x11; i[3].U.ki.dwFlags = KEYEVENTF_KEYUP;
      SendInput((uint)i.Length, i, Marshal.SizeOf(typeof(INPUT)));
    }
  }
}
"@
}

function Get-RootPath { Split-Path -Parent $PSScriptRoot }
function Get-AppPath([string]$Relative) { Join-Path (Get-RootPath) $Relative }

function Get-ShortTag([string]$Name) {
    $clean = ([string]$Name).Trim() -replace '\s+', ''
    if ([string]::IsNullOrWhiteSpace($clean)) { return 'SN' }
    return $clean.Substring(0, [Math]::Min(2, $clean.Length)).ToUpperInvariant()
}

function Write-Log([hashtable]$State,[string]$Message,[string]$Level='INFO') {
    try {
        $logPath = if ($State -and $State.LogPath) { $State.LogPath } else { Join-Path (Get-RootPath) 'logs\SNPDrumPad.log' }
        $logDir = Split-Path -Parent $logPath
        if (-not (Test-Path -LiteralPath $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
        Add-Content -LiteralPath $logPath -Value ("[{0}] [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message) -Encoding UTF8
    } catch { }
}

function New-DefaultConfig {
    [pscustomobject]@{
        schemaVersion = 2
        app = [pscustomobject]@{ nombre='SNP Plantillas Pro'; desarrollador='S. Navarro'; actualizacion=(Get-Date).ToString('s') }
        secciones = @(
            [pscustomobject]@{
                id=[guid]::NewGuid().Guid; nombre='Soporte diario'; icono='SD'
                plantillas=@(
                    [pscustomobject]@{ id=[guid]::NewGuid().Guid; titulo='Saludo inicial'; descripcion='Inicio rapido'; texto='Hola, gracias por contactar con soporte. Estoy revisando tu caso.'; favorita=$true },
                    [pscustomobject]@{ id=[guid]::NewGuid().Guid; titulo='Pedir evidencias'; descripcion='Logs y captura'; texto='Para avanzar, comparte por favor numero de ticket, captura y hora del error.'; favorita=$false }
                )
            },
            [pscustomobject]@{
                id=[guid]::NewGuid().Guid; nombre='Cierre'; icono='CI'
                plantillas=@(
                    [pscustomobject]@{ id=[guid]::NewGuid().Guid; titulo='Seguimiento'; descripcion='Caso en curso'; texto='Dejo el caso en seguimiento y te actualizo en cuanto tenga novedades.'; favorita=$true }
                )
            }
        )
    }
}

function Normalize-Config([object]$cfg) {
    if (-not $cfg.schemaVersion) { $cfg | Add-Member schemaVersion 2 -Force }
    if (-not $cfg.app) { $cfg | Add-Member app ([pscustomobject]@{ nombre='SNP Plantillas Pro'; desarrollador='S. Navarro'; actualizacion=(Get-Date).ToString('s') }) -Force }
    if (-not $cfg.secciones) { $cfg | Add-Member secciones @() -Force }
    foreach ($s in @($cfg.secciones)) {
        if (-not $s.id) { $s | Add-Member id ([guid]::NewGuid().Guid) -Force }
        if (-not $s.nombre) { $s | Add-Member nombre 'Seccion' -Force }
        if (-not $s.icono) { $s | Add-Member icono (Get-ShortTag ([string]$s.nombre)) -Force }
        if (-not $s.plantillas) { $s | Add-Member plantillas @() -Force }
        foreach ($p in @($s.plantillas)) {
            if (-not $p.id) { $p | Add-Member id ([guid]::NewGuid().Guid) -Force }
            if (-not $p.titulo) { $p | Add-Member titulo 'Plantilla' -Force }
            if (-not $p.descripcion) { $p | Add-Member descripcion '' -Force }
            if (-not $p.texto) { $p | Add-Member texto '' -Force }
            if ($null -eq $p.favorita) { $p | Add-Member favorita $false -Force }
        }
    }
    if (@($cfg.secciones).Count -eq 0) { $cfg.secciones = (New-DefaultConfig).secciones }
    $cfg.app.actualizacion = (Get-Date).ToString('s')
    $cfg
}

function Convert-Legacy([object]$raw) {
    if ($raw.secciones) { return (Normalize-Config $raw) }
    if ($raw.sections) {
        $c = [pscustomobject]@{ schemaVersion=2; app=[pscustomobject]@{ nombre='SNP Plantillas Pro'; desarrollador='S. Navarro'; actualizacion=(Get-Date).ToString('s') }; secciones=@() }
        foreach ($s in @($raw.sections)) {
            $legacyName = [string]$s.name
            $sec = [pscustomobject]@{ id=[guid]::NewGuid().Guid; nombre=$legacyName; icono=(Get-ShortTag $legacyName); plantillas=@() }
            foreach ($p in @($s.templates)) { $sec.plantillas += [pscustomobject]@{ id=[guid]::NewGuid().Guid; titulo=[string]$p.name; descripcion=[string]$p.description; texto=[string]$p.text; favorita=$false } }
            $c.secciones += $sec
        }
        return (Normalize-Config $c)
    }
    return (Normalize-Config (New-DefaultConfig))
}

function Load-Config([string]$Path) {
    if (-not (Test-Path -LiteralPath $Path)) { $d=New-DefaultConfig; Save-Config $Path $d; return $d }
    try { $raw=(Get-Content -LiteralPath $Path -Raw -Encoding UTF8 | ConvertFrom-Json); return (Convert-Legacy $raw) } catch { return (New-DefaultConfig) }
}
function Save-Config([string]$Path,[object]$Cfg) { $folder=Split-Path -Parent $Path; if(-not(Test-Path $folder)){New-Item -ItemType Directory -Path $folder -Force|Out-Null}; Set-Content -LiteralPath $Path -Value ((Normalize-Config $Cfg)|ConvertTo-Json -Depth 20) -Encoding UTF8 }
function Set-Status([hashtable]$st,[string]$txt,[switch]$Error){$st.Ctrl.Status.Text=$txt;$st.Ctrl.Status.Foreground=if($Error){'#FFC62828'}else{'#FF415A77'}}
function Capture-Target([hashtable]$st){$h=[SNP.Native]::GetForegroundWindow(); if($h -ne [IntPtr]::Zero -and $h -ne $st.MainHandle){$st.Target=$h}}

function Get-Visible([hashtable]$st){
    $f=$st.Filter.ToLowerInvariant();$sec=[string]$st.Sec; $out=@()
    foreach($s in @($st.Config.secciones)){
        if($sec -and $sec -ne 'Todas' -and $s.nombre -ne $sec){continue}
        foreach($p in @($s.plantillas)){
            if($st.OnlyFav -and -not [bool]$p.favorita){continue}
            $hay=("{0} {1} {2} {3}" -f $s.nombre,$p.titulo,$p.descripcion,$p.texto).ToLowerInvariant()
            if($f -and -not $hay.Contains($f)){continue}
            $out += [pscustomobject]@{id=$p.id; seccion=$s.nombre; icono=$s.icono; titulo=$p.titulo; descripcion=$p.descripcion; texto=$p.texto; favorita=[bool]$p.favorita}
        }
    }
    $out
}

function Execute-Template([hashtable]$st,[object]$item){
    try{
        Set-Clipboard -Value $item.texto
        if($st.CopyOnly){Set-Status $st "Copiado: $($item.titulo)"; return}
        if($st.Target -eq [IntPtr]::Zero){Set-Status $st "Copiado '$($item.titulo)'. Sin ventana destino."; return}
        [SNP.Native]::SetForegroundWindow($st.Target)|Out-Null; Start-Sleep -Milliseconds 70; [SNP.Native]::SendCtrlV(); Set-Status $st "Pegado rapido: $($item.titulo)"
    }catch{Set-Status $st "Error: $($_.Exception.Message)" -Error}
}

function Render-Pads([hashtable]$st){
    $panel=$st.Ctrl.Pads; $panel.Children.Clear(); $st.Visible=Get-Visible $st
    if(@($st.Visible).Count -eq 0){$t=New-Object System.Windows.Controls.TextBlock -Property @{Text='Sin resultados';Foreground='#FF607D9B';Margin='8'};[void]$panel.Children.Add($t);$st.Ctrl.Resume.Text='0 plantillas';return}
    $i=0
    foreach($it in $st.Visible){
        $b=New-Object System.Windows.Controls.Button -Property @{Width=176;Height=74;Margin='5';Tag=$it}
        $b.Style = $st.Ctrl.Window.FindResource('PadCardStyle')
        $g=New-Object System.Windows.Controls.Grid; $g.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width='Auto'}))|Out-Null; $g.ColumnDefinitions.Add((New-Object System.Windows.Controls.ColumnDefinition -Property @{Width='*'}))|Out-Null
        $badge=New-Object System.Windows.Controls.Border -Property @{Width=22;Height=22;CornerRadius='11';Background='#FF2F80ED';Margin='0,0,8,0'}
        $bt=New-Object System.Windows.Controls.TextBlock -Property @{Text=if($i -lt 9){[string]($i+1)}else{' '};Foreground='White';HorizontalAlignment='Center';VerticalAlignment='Center';FontWeight='Bold'}
        $badge.Child=$bt
        $s=New-Object System.Windows.Controls.StackPanel -Property @{Orientation='Vertical'}
        [void]$s.Children.Add((New-Object System.Windows.Controls.TextBlock -Property @{Text=$it.titulo;FontWeight='SemiBold';Foreground='#FF1F2D3D';TextTrimming='CharacterEllipsis';MaxWidth=136}))
        [void]$s.Children.Add((New-Object System.Windows.Controls.TextBlock -Property @{Text=("{0} {1}" -f $it.icono,$it.seccion);FontSize=11;Foreground='#FF4E6785';TextTrimming='CharacterEllipsis';MaxWidth=136}))
        [void]$s.Children.Add((New-Object System.Windows.Controls.TextBlock -Property @{Text=if([string]::IsNullOrWhiteSpace($it.descripcion)){'Sin descripcion'}else{$it.descripcion};FontSize=10;Foreground='#FF7086A2';TextTrimming='CharacterEllipsis';MaxWidth=136}))
        [System.Windows.Controls.Grid]::SetColumn($badge,0); [System.Windows.Controls.Grid]::SetColumn($s,1); [void]$g.Children.Add($badge); [void]$g.Children.Add($s)
        $b.Content=$g; $b.ToolTip=$it.texto
        $b.Add_Click({param($sender) Execute-Template $script:AppState $sender.Tag})
        [void]$panel.Children.Add($b); $i++
    }
    $st.Ctrl.Resume.Text = "{0} plantillas" -f @($st.Visible).Count
}

function Prompt-Text([string]$Title,[string]$Label,[string]$Value=''){
    $x=@"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml' Title='$Title' Width='420' Height='190' ResizeMode='NoResize' WindowStartupLocation='CenterOwner' Background='#FFF7FAFF' Foreground='#FF1F2D3D'><Grid Margin='12'><Grid.RowDefinitions><RowDefinition Height='Auto'/><RowDefinition Height='Auto'/><RowDefinition Height='Auto'/></Grid.RowDefinitions><TextBlock Text='$Label' Margin='0,0,0,8' FontWeight='SemiBold'/><TextBox x:Name='Val' Grid.Row='1' Background='White' BorderBrush='#FFD2DEEC' Foreground='#FF1F2D3D' Padding='8'/><StackPanel Grid.Row='2' Orientation='Horizontal' HorizontalAlignment='Right' Margin='0,10,0,0'><Button x:Name='Ok' Content='Aceptar' Width='90' Margin='0,0,8,0'/><Button x:Name='No' Content='Cancelar' Width='90'/></StackPanel></Grid></Window>
"@
    $w=[System.Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$x)));$tb=$w.FindName('Val');$ok=$w.FindName('Ok');$no=$w.FindName('No');$tb.Text=$Value
    $script:TxtResult=$null
    $ok.Add_Click({$script:TxtResult=$tb.Text.Trim();$w.DialogResult=$true;$w.Close()});$no.Add_Click({$w.DialogResult=$false;$w.Close()})
    if($w.ShowDialog()){$script:TxtResult}else{$null}
}

function Prompt-Template([object]$Config,[object]$Current=$null){
    $x=@"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml' Title='Plantilla' Width='560' Height='430' WindowStartupLocation='CenterOwner' Background='#FFF7FAFF' Foreground='#FF1F2D3D'><Grid Margin='12'><Grid.RowDefinitions><RowDefinition Height='Auto'/><RowDefinition Height='Auto'/><RowDefinition Height='Auto'/><RowDefinition Height='*'/><RowDefinition Height='Auto'/></Grid.RowDefinitions><Grid.ColumnDefinitions><ColumnDefinition Width='110'/><ColumnDefinition Width='*'/></Grid.ColumnDefinitions><TextBlock Text='Seccion' Margin='0,0,10,8' FontWeight='SemiBold'/><ComboBox x:Name='Sec' Grid.Column='1' Margin='0,0,0,8' Background='White' BorderBrush='#FFD2DEEC' Foreground='#FF1F2D3D'/><TextBlock Grid.Row='1' Text='Titulo' Margin='0,0,10,8' FontWeight='SemiBold'/><TextBox x:Name='Tit' Grid.Row='1' Grid.Column='1' Margin='0,0,0,8' Background='White' BorderBrush='#FFD2DEEC' Foreground='#FF1F2D3D' Padding='8'/><TextBlock Grid.Row='2' Text='Descripcion' Margin='0,0,10,8' FontWeight='SemiBold'/><TextBox x:Name='Des' Grid.Row='2' Grid.Column='1' Margin='0,0,0,8' Background='White' BorderBrush='#FFD2DEEC' Foreground='#FF1F2D3D' Padding='8'/><TextBlock Grid.Row='3' Text='Texto' Margin='0,0,10,8' FontWeight='SemiBold'/><TextBox x:Name='Txt' Grid.Row='3' Grid.Column='1' AcceptsReturn='True' TextWrapping='Wrap' VerticalScrollBarVisibility='Auto' Background='White' BorderBrush='#FFD2DEEC' Foreground='#FF1F2D3D' Padding='8'/><StackPanel Grid.Row='4' Grid.ColumnSpan='2' Orientation='Horizontal' HorizontalAlignment='Right' Margin='0,10,0,0'><CheckBox x:Name='Fav' Content='Favorita' Margin='0,0,12,0'/><Button x:Name='Ok' Content='Guardar' Width='90' Margin='0,0,8,0'/><Button x:Name='No' Content='Cancelar' Width='90'/></StackPanel></Grid></Window>
"@
    $w=[System.Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$x)))
    $sec=$w.FindName('Sec');$tit=$w.FindName('Tit');$des=$w.FindName('Des');$txt=$w.FindName('Txt');$fav=$w.FindName('Fav');$ok=$w.FindName('Ok');$no=$w.FindName('No')
    foreach($s in @($Config.secciones)){[void]$sec.Items.Add($s.nombre)}; if($sec.Items.Count -gt 0){$sec.SelectedIndex=0}
    if($Current){$sec.SelectedItem=$Current.seccion;$tit.Text=$Current.titulo;$des.Text=$Current.descripcion;$txt.Text=$Current.texto;$fav.IsChecked=[bool]$Current.favorita}
    $script:TplResult=$null
    $ok.Add_Click({
        if([string]::IsNullOrWhiteSpace($tit.Text) -or [string]::IsNullOrWhiteSpace($txt.Text) -or [string]::IsNullOrWhiteSpace([string]$sec.SelectedItem)){[System.Windows.MessageBox]::Show('Seccion, titulo y texto son obligatorios.','Validacion')|Out-Null;return}
        $script:TplResult=[pscustomobject]@{seccion=[string]$sec.SelectedItem;titulo=$tit.Text.Trim();descripcion=$des.Text.Trim();texto=$txt.Text;favorita=[bool]$fav.IsChecked}
        $w.DialogResult=$true;$w.Close()
    })
    $no.Add_Click({$w.DialogResult=$false;$w.Close()})
    if($w.ShowDialog()){$script:TplResult}else{$null}
}

function Show-Manager([hashtable]$st){
    $work=(($st.Config|ConvertTo-Json -Depth 20)|ConvertFrom-Json)
    $x=@"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation' xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml' Title='Gestor de plantillas' Width='860' Height='530' WindowStartupLocation='CenterOwner' Background='#FFF7FAFF' Foreground='#FF1F2D3D'><Grid Margin='12'><Grid.ColumnDefinitions><ColumnDefinition Width='1.1*'/><ColumnDefinition Width='1.6*'/></Grid.ColumnDefinitions><Grid.RowDefinitions><RowDefinition Height='*'/><RowDefinition Height='Auto'/></Grid.RowDefinitions><GroupBox Header='Secciones' Margin='0,0,8,0'><DockPanel Margin='10'><StackPanel DockPanel.Dock='Bottom' Orientation='Horizontal' Margin='0,10,0,0'><Button x:Name='AddS' Content='Nueva' Width='74' Margin='0,0,8,0'/><Button x:Name='EdS' Content='Renombrar' Width='84' Margin='0,0,8,0'/><Button x:Name='DelS' Content='Eliminar' Width='74'/></StackPanel><ListBox x:Name='LstS' Background='White' BorderBrush='#FFD2DEEC' Foreground='#FF1F2D3D'/></DockPanel></GroupBox><GroupBox Grid.Column='1' Header='Plantillas'><DockPanel Margin='10'><StackPanel DockPanel.Dock='Bottom' Orientation='Horizontal' Margin='0,10,0,0'><Button x:Name='AddP' Content='Nueva' Width='74' Margin='0,0,8,0'/><Button x:Name='EdP' Content='Editar' Width='74' Margin='0,0,8,0'/><Button x:Name='DupP' Content='Duplicar' Width='74' Margin='0,0,8,0'/><Button x:Name='DelP' Content='Eliminar' Width='74'/></StackPanel><ListBox x:Name='LstP' Background='White' BorderBrush='#FFD2DEEC' Foreground='#FF1F2D3D'/></DockPanel></GroupBox><StackPanel Grid.Row='1' Grid.ColumnSpan='2' Orientation='Horizontal' HorizontalAlignment='Right' Margin='0,10,0,0'><Button x:Name='Save' Content='Guardar cambios' Width='130' Margin='0,0,8,0'/><Button x:Name='Close' Content='Cancelar' Width='92'/></StackPanel></Grid></Window>
"@
    $w=[System.Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$x)))
    $ls=$w.FindName('LstS');$lp=$w.FindName('LstP')
    $addS=$w.FindName('AddS');$edS=$w.FindName('EdS');$delS=$w.FindName('DelS');$addP=$w.FindName('AddP');$edP=$w.FindName('EdP');$dupP=$w.FindName('DupP');$delP=$w.FindName('DelP');$save=$w.FindName('Save');$close=$w.FindName('Close')
    function RefS{
        $ls.Items.Clear()
        foreach($s in @($work.secciones)){ [void]$ls.Items.Add($s.nombre) }
        if($ls.Items.Count -gt 0 -and $ls.SelectedIndex -lt 0){ $ls.SelectedIndex=0 }
    }
    function RefP{
        $lp.Items.Clear()
        $n=[string]$ls.SelectedItem
        if(-not $n){return}
        $s=@($work.secciones|Where-Object{$_.nombre -eq $n})[0]
        if(-not $s){return}
        foreach($p in @($s.plantillas)){
            $favMark = ''
            if([bool]$p.favorita){ $favMark = ' *' }
            [void]$lp.Items.Add(("{0}{1}" -f $p.titulo,$favMark))
        }
    }
    $ls.Add_SelectionChanged({RefP})
    $addS.Add_Click({
        $nRaw = Prompt-Text 'Nueva seccion' 'Nombre'
        if ($null -eq $nRaw) { return }
        $n = ([string]$nRaw).Trim()
        if([string]::IsNullOrWhiteSpace($n)){return}
        if(@($work.secciones|Where-Object{$_.nombre -eq $n}).Count -gt 0){return}
        $work.secciones += [pscustomobject]@{
            id=[guid]::NewGuid().Guid
            nombre=$n
            icono=(Get-ShortTag $n)
            plantillas=@()
        }
        RefS
        $ls.SelectedItem=$n
    })
    $edS.Add_Click({
        $old=[string]$ls.SelectedItem
        if(-not $old){return}
        $nRaw = Prompt-Text 'Renombrar seccion' 'Nuevo nombre' $old
        if ($null -eq $nRaw) { return }
        $n=([string]$nRaw).Trim()
        if([string]::IsNullOrWhiteSpace($n)){return}
        $s=@($work.secciones|Where-Object{$_.nombre -eq $old})[0]
        if($s){
            $s.nombre=$n
            $s.icono=(Get-ShortTag $n)
            RefS
            $ls.SelectedItem=$n
        }
    })
    $delS.Add_Click({$n=[string]$ls.SelectedItem;if(-not $n){return};if(@($work.secciones).Count -le 1){[System.Windows.MessageBox]::Show('Debe quedar al menos una seccion.','SNP')|Out-Null;return};if([System.Windows.MessageBox]::Show("Eliminar seccion '$n'?",'Confirmacion','YesNo','Warning') -ne 'Yes'){return};$work.secciones=@($work.secciones|Where-Object{$_.nombre -ne $n});RefS})
    $addP.Add_Click({$e=Prompt-Template $work;if(-not $e){return};$s=@($work.secciones|Where-Object{$_.nombre -eq $e.seccion})[0];if($s){$s.plantillas += [pscustomobject]@{id=[guid]::NewGuid().Guid;titulo=$e.titulo;descripcion=$e.descripcion;texto=$e.texto;favorita=[bool]$e.favorita};RefS;$ls.SelectedItem=$e.seccion;RefP}})
    $edP.Add_Click({$sec=[string]$ls.SelectedItem;if(-not $sec -or $lp.SelectedIndex -lt 0){return};$s=@($work.secciones|Where-Object{$_.nombre -eq $sec})[0];if(-not $s){return};$p=$s.plantillas[$lp.SelectedIndex];$e=Prompt-Template $work ([pscustomobject]@{seccion=$sec;titulo=$p.titulo;descripcion=$p.descripcion;texto=$p.texto;favorita=[bool]$p.favorita});if(-not $e){return};$p.titulo=$e.titulo;$p.descripcion=$e.descripcion;$p.texto=$e.texto;$p.favorita=[bool]$e.favorita;if($e.seccion -ne $sec){$s.plantillas=@($s.plantillas|Where-Object{$_.id -ne $p.id});$d=@($work.secciones|Where-Object{$_.nombre -eq $e.seccion})[0];if($d){$d.plantillas+=$p}};RefS;$ls.SelectedItem=$e.seccion;RefP})
    $dupP.Add_Click({$sec=[string]$ls.SelectedItem;if(-not $sec -or $lp.SelectedIndex -lt 0){return};$s=@($work.secciones|Where-Object{$_.nombre -eq $sec})[0];if(-not $s){return};$p=$s.plantillas[$lp.SelectedIndex];$s.plantillas += [pscustomobject]@{id=[guid]::NewGuid().Guid;titulo=("$($p.titulo) (copia)");descripcion=$p.descripcion;texto=$p.texto;favorita=[bool]$p.favorita};RefP})
    $delP.Add_Click({$sec=[string]$ls.SelectedItem;if(-not $sec -or $lp.SelectedIndex -lt 0){return};$s=@($work.secciones|Where-Object{$_.nombre -eq $sec})[0];if(-not $s){return};$p=$s.plantillas[$lp.SelectedIndex];if([System.Windows.MessageBox]::Show("Eliminar plantilla '$($p.titulo)'?",'Confirmacion','YesNo','Warning') -ne 'Yes'){return};$s.plantillas=@($s.plantillas|Where-Object{$_.id -ne $p.id});RefP})
    $script:MgrOk=$false;$save.Add_Click({$script:MgrOk=$true;$w.DialogResult=$true;$w.Close()});$close.Add_Click({$script:MgrOk=$false;$w.DialogResult=$false;$w.Close()})
    RefS;RefP
    if($w.ShowDialog() -and $script:MgrOk){Normalize-Config $work}else{$null}
}

function Refresh-All([hashtable]$st){
    $cmb=$st.Ctrl.CmbSec; $sel=[string]$cmb.SelectedItem; $cmb.Items.Clear(); [void]$cmb.Items.Add('Todas'); foreach($s in @($st.Config.secciones)){[void]$cmb.Items.Add($s.nombre)}
    if($sel -and $cmb.Items.Contains($sel)){$cmb.SelectedItem=$sel}else{$cmb.SelectedIndex=0}
    Render-Pads $st
}

function Start-App {
    $st=[ordered]@{ Root=(Get-RootPath); ConfigPath=(Get-AppPath 'config\templates.json'); LogPath=(Get-AppPath 'logs\\SNPDrumPad.log'); Brand=(Get-AppPath 'assets\brand\logo_icon.png'); Icon=(Get-AppPath 'assets\brand\app.ico'); Config=$null; Filter=''; Sec='Todas'; OnlyFav=$false; CopyOnly=$false; Target=[IntPtr]::Zero; MainHandle=[IntPtr]::Zero; Visible=@(); Ctrl=@{} }
    $st.Config=Load-Config $st.ConfigPath; Save-Config $st.ConfigPath $st.Config
    $x=@"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='SNP Plantillas Pro'
        Height='555' Width='445' MinHeight='470' MinWidth='390'
        ResizeMode='CanResize'
        WindowStartupLocation='CenterScreen'
        Background='#FFF4F7FC'
        Foreground='#FF1F2D3D'
        FontFamily='Segoe UI'>
  <Window.Resources>
    <Style x:Key='ActionButtonStyle' TargetType='Button'>
      <Setter Property='Background' Value='White'/>
      <Setter Property='Foreground' Value='#FF1F2D3D'/>
      <Setter Property='BorderBrush' Value='#FFD2DEEC'/>
      <Setter Property='BorderThickness' Value='1'/>
      <Setter Property='Padding' Value='10,5'/>
      <Setter Property='FontWeight' Value='SemiBold'/>
      <Style.Triggers>
        <Trigger Property='IsMouseOver' Value='True'>
          <Setter Property='Background' Value='#FFEFF5FF'/>
          <Setter Property='BorderBrush' Value='#FF90B4E8'/>
        </Trigger>
      </Style.Triggers>
    </Style>
    <Style x:Key='PadCardStyle' TargetType='Button'>
      <Setter Property='Background' Value='White'/>
      <Setter Property='Foreground' Value='#FF1F2D3D'/>
      <Setter Property='BorderBrush' Value='#FFD7E3F1'/>
      <Setter Property='BorderThickness' Value='1'/>
      <Setter Property='Padding' Value='8'/>
      <Style.Triggers>
        <Trigger Property='IsMouseOver' Value='True'>
          <Setter Property='Background' Value='#FFF2F7FF'/>
          <Setter Property='BorderBrush' Value='#FF6FA1E2'/>
        </Trigger>
      </Style.Triggers>
    </Style>
  </Window.Resources>
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height='Auto'/>
      <RowDefinition Height='Auto'/>
      <RowDefinition Height='Auto'/>
      <RowDefinition Height='*'/>
      <RowDefinition Height='Auto'/>
    </Grid.RowDefinitions>

    <Border Background='#FFE8F1FF' Padding='10' BorderBrush='#FFD1E2F6' BorderThickness='0,0,0,1'>
      <DockPanel>
        <StackPanel Orientation='Horizontal' DockPanel.Dock='Left'>
          <Border Width='34' Height='34' Background='White' CornerRadius='6' BorderBrush='#FFD4E2F3' BorderThickness='1' Margin='0,0,8,0'>
            <Image x:Name='Brand' Stretch='Uniform' Margin='2'/>
          </Border>
          <StackPanel>
            <TextBlock Text='SNP Plantillas Pro' FontWeight='Bold' FontSize='16' Foreground='#FF163A63'/>
            <TextBlock Text='Mini panel de soporte en espanol' FontSize='11' Foreground='#FF43658A'/>
          </StackPanel>
        </StackPanel>
      </DockPanel>
    </Border>

    <Border Grid.Row='1' Padding='10' Background='#FFF6FAFF' BorderBrush='#FFDCE9F7' BorderThickness='0,0,0,1'>
      <Grid>
        <Grid.ColumnDefinitions>
          <ColumnDefinition Width='*'/>
          <ColumnDefinition Width='118'/>
        </Grid.ColumnDefinitions>
        <TextBox x:Name='Search' Grid.Column='0' Margin='0,0,8,0' Background='White' BorderBrush='#FFD2DEEC' Foreground='#FF1F2D3D' Padding='8,4'/>
        <ComboBox x:Name='CmbSec' Grid.Column='1' Background='White' BorderBrush='#FFD2DEEC' Foreground='#FF1F2D3D'/>
      </Grid>
    </Border>

    <Border Grid.Row='2' Padding='10' Background='#FFF6FAFF' BorderBrush='#FFDCE9F7' BorderThickness='0,0,0,1'>
      <StackPanel Orientation='Horizontal'>
        <CheckBox x:Name='Fav' Content='Solo favoritas' Margin='0,0,10,0' Foreground='#FF1F2D3D'/>
        <CheckBox x:Name='Copy' Content='Solo copiar' Margin='0,0,10,0' Foreground='#FF1F2D3D'/>
        <CheckBox x:Name='Top' Content='Siempre arriba' Margin='0,0,12,0' Foreground='#FF1F2D3D'/>
        <Button x:Name='Manage' Content='Gestionar' Width='78' Margin='0,0,6,0' Style='{StaticResource ActionButtonStyle}'/>
        <Button x:Name='Import' Content='Importar' Width='70' Margin='0,0,6,0' Style='{StaticResource ActionButtonStyle}'/>
        <Button x:Name='Export' Content='Exportar' Width='70' Style='{StaticResource ActionButtonStyle}'/>
      </StackPanel>
    </Border>

    <Grid Grid.Row='3'>
      <Grid.RowDefinitions>
        <RowDefinition Height='Auto'/>
        <RowDefinition Height='*'/>
      </Grid.RowDefinitions>
      <TextBlock x:Name='Resume' Margin='10,10,10,6' Foreground='#FF5B7693' Text='0 plantillas'/>
      <ScrollViewer Grid.Row='1' VerticalScrollBarVisibility='Auto'>
        <WrapPanel x:Name='Pads' Margin='8'/>
      </ScrollViewer>
    </Grid>

    <Border Grid.Row='4' Padding='10' Background='#FFF0F6FF' BorderBrush='#FFDCE9F7' BorderThickness='0,1,0,0'>
      <DockPanel>
        <TextBlock x:Name='Status' DockPanel.Dock='Left' Foreground='#FF415A77' Text='Listo.'/>
        <TextBlock x:Name='Credit' DockPanel.Dock='Right' Foreground='#FF2D76D2' Text='Hecho por S. Navarro'/>
      </DockPanel>
    </Border>
  </Grid>
</Window>
"@
    $w=[System.Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader ([xml]$x)))
    $st.Ctrl.Window=$w; $st.Ctrl.Brand=$w.FindName('Brand'); $st.Ctrl.Search=$w.FindName('Search'); $st.Ctrl.CmbSec=$w.FindName('CmbSec'); $st.Ctrl.Fav=$w.FindName('Fav'); $st.Ctrl.Copy=$w.FindName('Copy'); $st.Ctrl.Top=$w.FindName('Top'); $st.Ctrl.Manage=$w.FindName('Manage'); $st.Ctrl.Import=$w.FindName('Import'); $st.Ctrl.Export=$w.FindName('Export'); $st.Ctrl.Pads=$w.FindName('Pads'); $st.Ctrl.Resume=$w.FindName('Resume'); $st.Ctrl.Status=$w.FindName('Status'); $st.Ctrl.Credit=$w.FindName('Credit')
    if(Test-Path $st.Brand){try{$st.Ctrl.Brand.Source=New-Object System.Windows.Media.Imaging.BitmapImage([Uri]$st.Brand)}catch{}}
    if(Test-Path $st.Icon){try{$s=[IO.File]::OpenRead($st.Icon);try{$d=New-Object System.Windows.Media.Imaging.IconBitmapDecoder($s,[System.Windows.Media.Imaging.BitmapCreateOptions]::None,[System.Windows.Media.Imaging.BitmapCacheOption]::OnLoad);if($d.Frames.Count -gt 0){$w.Icon=$d.Frames[0]}}finally{$s.Dispose()}}catch{}}
    $script:AppState=$st
    $w.Add_SourceInitialized({$helper=New-Object System.Windows.Interop.WindowInteropHelper($w);$script:AppState.MainHandle=$helper.Handle})
    $w.Add_Deactivated({Capture-Target $script:AppState})
    $st.Ctrl.Search.Add_TextChanged({$script:AppState.Filter=$script:AppState.Ctrl.Search.Text.Trim();Render-Pads $script:AppState})
    $st.Ctrl.CmbSec.Add_SelectionChanged({$script:AppState.Sec=[string]$script:AppState.Ctrl.CmbSec.SelectedItem;Render-Pads $script:AppState})
    $st.Ctrl.Fav.Add_Checked({$script:AppState.OnlyFav=$true;Render-Pads $script:AppState});$st.Ctrl.Fav.Add_Unchecked({$script:AppState.OnlyFav=$false;Render-Pads $script:AppState})
    $st.Ctrl.Copy.Add_Checked({$script:AppState.CopyOnly=$true;Set-Status $script:AppState 'Modo solo copiar activo.'});$st.Ctrl.Copy.Add_Unchecked({$script:AppState.CopyOnly=$false;Set-Status $script:AppState 'Modo pegar activo.'})
    $st.Ctrl.Top.Add_Checked({$w.Topmost=$true});$st.Ctrl.Top.Add_Unchecked({$w.Topmost=$false})
    $st.Ctrl.Credit.Add_MouseLeftButtonDown({if($_.ClickCount -ge 2){[System.Windows.MessageBox]::Show('Modo leyenda activado para S. Navarro.','SNP')|Out-Null}})
    $st.Ctrl.Manage.Add_Click({
        try {
            $updated=Show-Manager $script:AppState
            if($updated){
                $script:AppState.Config=$updated
                Save-Config $script:AppState.ConfigPath $script:AppState.Config
                Refresh-All $script:AppState
                Set-Status $script:AppState 'Cambios guardados.'
            }
        } catch {
            Write-Log $script:AppState $_.Exception.ToString() 'ERROR'
            Set-Status $script:AppState "Error en Gestionar: $($_.Exception.Message)" -Error
            [System.Windows.MessageBox]::Show($_.Exception.Message,'SNP Plantillas Pro') | Out-Null
        }
    })
    $st.Ctrl.Import.Add_Click({
        $o=New-Object System.Windows.Forms.OpenFileDialog -Property @{Filter='JSON (*.json)|*.json';Title='Importar configuracion'}
        if($o.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
            try{
                $j=Get-Content -LiteralPath $o.FileName -Raw -Encoding UTF8|ConvertFrom-Json
                $script:AppState.Config=Convert-Legacy $j
                Save-Config $script:AppState.ConfigPath $script:AppState.Config
                Refresh-All $script:AppState
                Set-Status $script:AppState "Importado: $([IO.Path]::GetFileName($o.FileName))"
            }catch{
                Write-Log $script:AppState $_.Exception.ToString() 'ERROR'
                Set-Status $script:AppState "Error importando: $($_.Exception.Message)" -Error
            }
        }
    })
    $st.Ctrl.Export.Add_Click({
        $s=New-Object System.Windows.Forms.SaveFileDialog -Property @{Filter='JSON (*.json)|*.json';FileName=("SNP_backup_{0}.json" -f (Get-Date -Format 'yyyyMMdd_HHmm'))}
        if($s.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
            try {
                Set-Content -LiteralPath $s.FileName -Value ($script:AppState.Config|ConvertTo-Json -Depth 20) -Encoding UTF8
                Set-Status $script:AppState "Backup exportado: $([IO.Path]::GetFileName($s.FileName))"
            } catch {
                Write-Log $script:AppState $_.Exception.ToString() 'ERROR'
                Set-Status $script:AppState "Error exportando: $($_.Exception.Message)" -Error
            }
        }
    })
    $w.Add_PreviewKeyDown({$m=@{D1=0;NumPad1=0;D2=1;NumPad2=1;D3=2;NumPad3=2;D4=3;NumPad4=3;D5=4;NumPad5=4;D6=5;NumPad6=5;D7=6;NumPad7=6;D8=7;NumPad8=7;D9=8;NumPad9=8};$k=[string]$_.Key;if($m.ContainsKey($k)){$i=[int]$m[$k];if($i -lt @($script:AppState.Visible).Count){Execute-Template $script:AppState $script:AppState.Visible[$i]};$_.Handled=$true}})
    Refresh-All $st; Set-Status $st 'Lista para trabajar.'; [void]$w.ShowDialog()
}

try {
    Start-App
} catch {
    Write-Log $null $_.Exception.ToString() 'FATAL'
    [System.Windows.MessageBox]::Show($_.Exception.Message,'SNP Plantillas Pro - Error fatal') | Out-Null
    throw
}
