# Guia de instalacion MSI y troubleshooting

## 1. MSI disponibles

- `SNPDrumPad-2.0.1.0-x64.msi`: instalacion clasica en Program Files (scope per-machine).
- `SNPDrumPad-Portable-2.0.1.0-x64.msi`: instalacion portable mode en LocalAppData (scope per-user, sin admin).

## 2. Instalacion

1. Ejecuta el MSI correspondiente.
2. Sigue el asistente.
3. Abre la app desde menu Inicio o escritorio.

## 3. Generar ambos MSI desde codigo

En `C:\Tools\SNPSupport\SNPDrumPad`:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Build-MSI.ps1 -Version 2.0.1.0
```

Salida:

- `release\artifacts\SNPDrumPad-2.0.1.0-x64.msi`
- `release\artifacts\SNPDrumPad-Portable-2.0.1.0-x64.msi`

## 4. Si no tienes WiX en PATH

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Setup-LocalWix.ps1
$env:DOTNET_ROOT='C:\Tools\SNPSupport\SNPDrumPad\tools\dotnet6'
$env:PATH='C:\Tools\SNPSupport\SNPDrumPad\tools\wix_local\tools\net6.0\any;$env:DOTNET_ROOT;$env:PATH'
powershell -ExecutionPolicy Bypass -File .\scripts\Build-MSI.ps1 -Version 2.0.1.0
```

## 5. Troubleshooting

### La app no arranca

- Ejecuta manualmente:
`powershell -ExecutionPolicy Bypass -File "C:\Program Files\SNPSupport\SNPDrumPad\src\SNPDrumPad.ps1"`
- Revisa log:
`logs\SNPDrumPad.log`

### Error al abrir Gestionar

- Actualiza a la build v2.0.1.0.

### No pega texto automaticamente

- Comprueba que `Solo copiar` este desactivado.
- Cambia el foco a la ventana destino y vuelve a pulsar plantilla.
