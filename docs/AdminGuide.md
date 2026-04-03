# Guia de administracion - SNP Plantillas Pro

## 1. Configuracion base

Archivo principal:

- `config\templates.json`

Estructura activa (schema v2):

- `schemaVersion`
- `app` (nombre, desarrollador, actualizacion)
- `secciones[]` con `id`, `nombre`, `icono`, `plantillas[]`
- `plantillas[]` con `id`, `titulo`, `descripcion`, `texto`, `favorita`

## 2. Compatibilidad

La app acepta configuraciones legacy (`sections/templates`) y las migra automaticamente al cargar.

## 3. Backup y restauracion

Backup:

1. Cierra la app.
2. Copia `config\templates.json`.
3. Guarda copia con fecha.

Restauracion:

1. Sustituye `config\templates.json` por el backup.
2. Ejecuta la app y valida secciones/plantillas.

## 4. Validacion automatica

```powershell
powershell -ExecutionPolicy Bypass -File .\tests\Validate-Templates.ps1
```

## 5. Distribucion

- MSI: `release\artifacts\*.msi`
- Bundle final: `release\distribution\SNPDrumPad-v2.0.1.zip`

Para regenerar:

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Build-MSI.ps1 -Version 2.0.1.0
powershell -ExecutionPolicy Bypass -File .\scripts\Create-ReleaseBundle.ps1 -Version 2.0.1
```
