![Version](https://img.shields.io/badge/version-2.0.1-blue)
![Platform](https://img.shields.io/badge/platform-Windows-0078D6?logo=windows)
![Language](https://img.shields.io/badge/language-PowerShell-5391FE?logo=powershell)
![License](https://img.shields.io/badge/license-MIT-green)

# SNPDrumPad (SNP Plantillas Pro)

Rebuild completo (v2) orientado a uso real en soporte: ventana mini, tema claro profesional, editor visual y empaquetado MSI doble.

## Lo importante

- Ventana pequena, movible y redimensionable.
- Tema claro moderno y legible.
- Busqueda instantanea y filtro por seccion.
- Modo `Solo copiar` o `Copiar + pegar`.
- Atajos `1-9` para las primeras plantillas visibles.
- Gestor visual para crear, editar, duplicar y borrar secciones/plantillas.
- Importacion/exportacion JSON.
- Guinos de autoria para S. Navarro en la experiencia.

## Ejecutar

```powershell
powershell -ExecutionPolicy Bypass -File .\scripts\Run.ps1
```

## Configuracion (schema v2)

Archivo: `config\templates.json`

```json
{
  "schemaVersion": 2,
  "app": {
    "nombre": "SNP Plantillas Pro",
    "desarrollador": "S. Navarro",
    "actualizacion": "2026-04-01T13:00:00"
  },
  "secciones": [
    {
      "id": "guid",
      "nombre": "Soporte diario",
      "icono": "SD",
      "plantillas": [
        {
          "id": "guid",
          "titulo": "Saludo inicial",
          "descripcion": "Inicio rapido",
          "texto": "Hola, gracias por contactar...",
          "favorita": true
        }
      ]
    }
  ]
}
```

La app mantiene compatibilidad de lectura con formato legacy (`sections/templates`) y migra automaticamente.

## Build y MSI

- Preparar payload:
`powershell -ExecutionPolicy Bypass -File .\scripts\Build.ps1 -Clean`
- Compilar MSI instalable y MSI portable:
`powershell -ExecutionPolicy Bypass -File .\scripts\Build-MSI.ps1 -Version 2.0.1.0`
- Generar bundle final:
`powershell -ExecutionPolicy Bypass -File .\scripts\Create-ReleaseBundle.ps1 -Version 2.0.1`

MSI generados:

- `release\artifacts\SNPDrumPad-2.0.1.0-x64.msi`
- `release\artifacts\SNPDrumPad-Portable-2.0.1.0-x64.msi`

## Documentacion

- [Manual de usuario](docs/UserGuide.md)
- [Guia de administracion](docs/AdminGuide.md)
- [Instalacion MSI](docs/MSIInstallGuide.md)
