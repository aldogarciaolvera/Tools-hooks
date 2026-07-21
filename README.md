
# Tools-hooks

Tools-hooks es una colección de utilidades para estandarizar el flujo de trabajo
con Git en cualquier proyecto.

## Características

- Hooks globales de Git.
- Validación de Conventional Commits.
- Prefijo automático de commits.
- Inicialización de proyectos (`git-project-init`).
- Validación de proyectos (`git-project-check`).
- Creación de releases (`git-release`).

## Instalación

```bash
git clone git@github.com:aldogarciaolvera/Tools-hooks.git
cd Tools-hooks
./install.sh
```

El instalador:

- Configura `core.hooksPath`.
- Instala:
  - `git-project-init`
  - `git-project-check`
  - `git-release`

> **Importante:** No muevas ni elimines la carpeta `Tools-hooks` después de
> ejecutar `install.sh`, ya que los hooks y comandos apuntan a esa ubicación.

## Flujo recomendado

### 1. Crear un proyecto

```bash
git init
git-project-init --version 0.1.0
```

Se crearán, si no existen:

- VERSION
- CHANGELOG.md
- LICENSE (opcional)
- .githooks/pre-commit
- .githooks/pre-push

### 2. Trabajar normalmente

```bash
git add .
git commit -m "feat: agrega autenticación"
```

Los hooks validarán automáticamente el mensaje y ejecutarán las validaciones del
proyecto.

### 3. Publicar una versión

```bash
git-release 1.1.0
```

El comando:

1. Ejecuta `git-project-check`.
2. Verifica que el repositorio esté limpio.
3. Actualiza `VERSION`.
4. Agrega una entrada al `CHANGELOG.md`.
5. Crea el commit de release.
6. Crea la etiqueta `vX.Y.Z`.
7. Pregunta si deseas publicar.
8. Si aceptas, ejecuta:
   - `git push origin <rama>`
   - `git push origin vX.Y.Z`

## Conventional Commits

| Tipo | Descripción |
|------|-------------|
| feat | Nueva funcionalidad |
| fix | Corrección de errores |
| docs | Documentación |
| refactor | Refactorización sin cambiar comportamiento |
| test | Pruebas |
| chore | Mantenimiento |
| build | Compilación |
| ci | Integración continua |
| perf | Rendimiento |
| style | Formato del código |
| revert | Revierte cambios |

## Licencia

MIT.
