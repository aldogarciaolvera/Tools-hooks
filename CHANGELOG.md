# Changelog

Todos los cambios relevantes de este proyecto se documentarán en este archivo.

El formato está basado en Keep a Changelog y el proyecto utiliza Semantic Versioning.

## [1.0.0] - 2026-07-21

### Added

- Instalador global de herramientas Git.
- Configuración automática de `core.hooksPath`.
- Hook `prepare-commit-msg` para agregar iniciales y rama.
- Hook `commit-msg` para validar Conventional Commits.
- Hook global `pre-commit`.
- Soporte para validaciones específicas mediante `.githooks/pre-commit`.
- Hook global `pre-push`.
- Soporte para validaciones específicas mediante `.githooks/pre-push`.
- Comando global `git-release`.
- Validación de versiones con formato Semantic Versioning.
- Actualización automática de `VERSION`.
- Actualización automática de `CHANGELOG.md`.
- Creación automática del commit de release.
- Creación automática de etiquetas Git.
- Instalación opcional de licencia MIT.
