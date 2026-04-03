# Changelog

Todos los cambios relevantes de SNPDrumPad se documentan en este archivo.

## [2.0.1] - 2026-04-01

### Fixed

- Corregido el arranque del MSI portable en algunos entornos.
- Nuevo runtime launcher `Run-SNPDrumPad.ps1` incluido en payload.
- Atajos MSI actualizados para ejecutar con PowerShell 64-bit y launcher dedicado.
- Mejorado el manejo de errores en runtime.

## [2.0.0] - 2026-04-01

### Added

- Reescritura completa de la app principal (`src/SNPDrumPad.ps1`).
- Interfaz mini redisenada y 100% en espanol.
- Gestor visual de secciones y plantillas.
- Importacion/exportacion JSON desde interfaz.
- Nuevo schema de configuracion v2 (`secciones`, `plantillas`) con migracion legacy.
- Correccion de estabilidad en el gestor (runtime al listar favoritas).
- Logging de errores en `logs\SNPDrumPad.log`.
- Tema claro moderno con mejor contraste general.
- Generacion de `SNPDrumPad-2.0.0.0-x64.msi` (instalable).
- Generacion de `SNPDrumPad-Portable-2.0.0.0-x64.msi` (portable mode).
- Nuevas guias de usuario y administracion actualizadas.
- Release notes de la version v2.0.0.

### Notes

- Esta version sustituye la UX inicial y marca el nuevo baseline funcional del producto.

## [1.0.0] - 2026-04-01

### Added

- Primera version funcional de SNPDrumPad.
- Ventana compacta para acceso rapido a plantillas.
- Organizacion por secciones y botones de pegado.
- Configuracion basada en JSON.
- Flujo de copia al portapapeles y pegado rapido.
- Branding inicial y materiales de release.
- Documentacion de usuario, administracion e instalacion.
- Pipeline MSI con WiX y scripts de build firmable.
- Script `Setup-LocalWix.ps1` para compilar MSI sin permisos admin.
- Script `Create-ReleaseBundle.ps1` para generar paquete final de distribucion con checksums.

### Notes

- La version 1.0.0 se considera la base inicial del producto.
- Cualquier ajuste posterior de comportamiento, apariencia o empaquetado debe registrarse a partir de esta linea base.
