# Tools-hooks

Herramientas modulares y reutilizables para configurar un flujo de trabajo consistente con Git en Linux, macOS y Windows.

Tools-hooks instala hooks globales, valida mensajes con Conventional Commits, inicializa proyectos desde una base mínima (`VERSION` + licencia opcional) hasta stacks completos, y automatiza releases con Semantic Versioning y tags.

## Características

- Hooks globales reutilizables (`prepare-commit-msg`, `commit-msg`, `pre-commit`, `pre-push`).
- Prefijo automático con iniciales (configurables o derivadas de `git config user.name`) y rama actual.
- Validación de Conventional Commits (incluyendo `revert`, `cherry-pick` y `rebase` sin duplicar prefijos).
- Validación de sintaxis Bash sobre contenido en *stage* antes de confirmar cambios.
- Inicialización modular con `git-project-init`: `VERSION` (`0.0.1`) obligatorio siempre, y todo lo demás opcional (licencia, docs, plantillas, Docker, `autoskills`).
- Modo en blanco (`--blank` / `--minimal`) ideal para repositorios ligeros o skills de agentes que solo necesitan `VERSION`, `LICENSE` y tags.
- Diagnóstico y agregado selectivo de archivos faltantes con `git-project-update`.
- Validación flexible con `git-project-check` (`VERSION` obligatorio, opcionales validados si existen, más modo `--strict`).
- Releases con Semantic Versioning mediante `git-release`, con `CHANGELOG.md` opcional y creación automática de commits y tags.
- Instalación y desinstalación (`--uninstall` / `-Uninstall`) compatibles con Linux, macOS y Windows.

## Plataformas compatibles

| Plataforma | Instalación recomendada | Uso de comandos |
|---|---|---|
| Linux | `install.sh` | Terminal Bash |
| macOS | `install.sh` | Terminal Bash/Zsh |
| Windows | `install.ps1` | PowerShell, CMD o Windows Terminal |
| Windows con Git Bash | `install.sh` o `install.ps1` | Git Bash |

En Windows, los scripts se ejecutan mediante **Git Bash**, y `install.ps1` crea wrappers `.cmd` y wrappers Bash con finales de línea `LF` en `%USERPROFILE%\.local\bin`.

## Requisitos

### Linux y macOS

- Git.
- Bash.
- Utilidades estándar como `awk`, `grep`, `sed`, `mktemp`, `date` y `curl` (opcional para `.gitignore` remoto; incluye respaldo offline).

### Windows

- Windows 10 o Windows 11.
- Git for Windows (incluyendo Git Bash).
- PowerShell 5.1 o superior.

## Estructura

```text
Tools-hooks/
├── git-hooks/
│   ├── commit-msg
│   ├── pre-commit
│   ├── pre-push
│   └── prepare-commit-msg
├── scripts/
│   ├── lib/
│   │   ├── common.sh
│   │   └── generators.sh
│   ├── project-check.sh
│   ├── project-init.sh
│   ├── project-update.sh
│   └── release.sh
├── tests/
│   └── run-tests.sh
├── CHANGELOG.md
├── install.ps1
├── install.sh
├── LICENSE
├── README.md
└── VERSION
```

## Instalación en Linux o macOS

Clona el repositorio y ejecuta el instalador:

```bash
git clone https://github.com/aldogarciaolvera/Tools-hooks.git
cd Tools-hooks
chmod +x install.sh scripts/*.sh scripts/lib/*.sh git-hooks/*
./install.sh
```

El instalador:

- respalda `core.hooksPath` previo si existía y configura los hooks globales;
- configura `tools-hooks.root`;
- enlaza en `~/.local/bin`: `git-project-init`, `git-project-check`, `git-project-update` y `git-release`;
- agrega `~/.local/bin` al `PATH` cuando hace falta.

## Instalación en Windows

Abre PowerShell y ejecuta:

```powershell
git clone https://github.com/aldogarciaolvera/Tools-hooks.git
cd Tools-hooks
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

Cierra y vuelve a abrir PowerShell, CMD o Windows Terminal después de instalar.

### Verificación en Windows

```powershell
git config --global --get core.hooksPath
where.exe git-project-init
where.exe git-project-check
where.exe git-project-update
where.exe git-release
```

## Importante: ubicación del repositorio

No muevas ni elimines la carpeta `Tools-hooks` después de instalar. Si la cambias de ruta, vuelve a ejecutar `./install.sh` o `.\install.ps1`.

## Flujo de trabajo recomendado

### Caso A: Plantilla en blanco / Repositorio de skills

Ideal para repositorios ligeros donde solo necesitas control de versiones y tags sin archivos de relleno:

```bash
mkdir MiSkill
cd MiSkill
git init
git-project-init --minimal --license
```

Esto crea únicamente:

- `VERSION` (`0.0.1`)
- `LICENSE` (MIT)

Después puedes hacer tus commits y generar etiquetas de versión directamente con:

```bash
git-release 0.1.0
```

### Caso B: Proyecto completo o con plantilla de stack

```bash
mkdir MiProyecto
cd MiProyecto
git init
git-project-init -t react --all
```

O selecciona módulos individuales:

```bash
git-project-init -v 0.1.0 --license --readme --changelog --gitignore --hooks
```

Si quieres ejecutar `autoskills` (`npx -y autoskills@latest`), actívalo explícitamente con `--skills` (o respondiendo `y` en el asistente interactivo).

## Comandos disponibles

### `git-project-init`

Inicializa el repositorio garantizando `VERSION` (`0.0.1` por defecto). Todo lo demás es opcional (por flags o de forma interactiva).

```bash
git-project-init [opciones]
```

Opciones principales:

- `-v, --version X.Y.Z`: Versión inicial (por defecto `0.0.1`).
- `-t, --template TIPO`: `blank` (por defecto), `react`, `astro`, `angular`, `reactnative`, `dotnet`, `python`.
- `--blank`, `--minimal`: Solo `VERSION` y licencia (sin preguntas de extras).
- `--license` / `--no-license`: Crear o omitir licencia MIT sin preguntar.
- `--changelog`: Crea `CHANGELOG.md`.
- `--readme`: Crea `README.md`.
- `--docs` (o individuales `--design`, `--agents`, `--architecture`): Documentación de proyecto.
- `--editorconfig`: Crea `.editorconfig`.
- `--prettier`: Crea `.prettierrc`.
- `--gitignore`: Crea o complementa `.gitignore` (usa toptal y cuenta con respaldo local offline).
- `--docker`: Crea `Dockerfile` y `.dockerignore` (requiere `-t` distinto de `blank`).
- `--hooks`: Crea `.githooks/pre-commit` y `.githooks/pre-push`.
- `--skills`: Ejecuta `npx -y autoskills@latest` (desactivado por defecto).
- `--all`: Activa todos los archivos opcionales (excepto `--skills`).
- `-y, --yes`: Modo no interactivo.
- `-h, --help`: Muestra la ayuda.

No sobrescribe archivos existentes.

### `git-project-update`

Inspecciona el proyecto, valida qué archivos existen y qué falta, garantiza `VERSION` si no existe (sin modificarlo si ya existe) y te permite agregar selectivamente los archivos opcionales faltantes.

```bash
git-project-update [opciones]
```

Ejemplos:

```bash
# Modo diagnóstico + selección interactiva de faltantes
git-project-update

# Agregar únicamente README y CHANGELOG si faltan
git-project-update --readme --changelog

# Solo validar estado sin prompts
git-project-update -y
```

### `git-project-check`

Valida la estructura del proyecto:

```bash
git-project-check [--strict]
```

- **Obligatorio:** `VERSION` existente y con formato SemVer `MAJOR.MINOR.PATCH`.
- **Opcionales (se validan si están presentes):** `LICENSE*`, `CHANGELOG.md` (encabezado `# Changelog`), `README.md`, `DESIGN.md`, `AGENTS.md`, `ARCHITECTURE.md`, `.editorconfig`, `.prettierrc`, `.gitignore`, `Dockerfile`, `.dockerignore` y sintaxis de `.githooks/*`.
- `--strict`: exige además `LICENSE` y `CHANGELOG.md`.

### `git-release`

Genera una nueva versión y su etiqueta Git:

```bash
git-release [opciones] <version>
```

Opciones:

- `--changelog`: Crea `CHANGELOG.md` si no existía y agrega la entrada.
- `--no-changelog`: Actualiza únicamente `VERSION` y el tag.
- `--push` / `--no-push`: Publica automáticamente o mantiene la release local sin preguntar.

Comportamiento:

1. valida versión SemVer, rama activa (no *detached HEAD*) y árbol limpio;
2. ejecuta `git-project-check`;
3. actualiza `VERSION`;
4. si existe `CHANGELOG.md` (o se pasó `--changelog`), agrupa commits (`Features`, `Bug Fixes`, `Performance`, `Refactoring`, `Documentation`) desde el último tag e inserta la nueva versión debajo de `# Changelog`;
5. crea el commit `mnto: release X.Y.Z` y el tag anotado `vX.Y.Z`;
6. si existe el remoto configurado, pregunta si deseas hacer `git push` de la rama y el tag.

## Hooks instalados

### `prepare-commit-msg`

Agrega automáticamente `[INICIALES] - rama - ` al inicio del mensaje.

- Usa `GIT_AUTHOR_INITIALS` si está definida; si no, deriva las iniciales automáticamente de `git config user.name` (con respaldo `DEV`).
- Respeta `merge`, `squash`, `Revert`, `fixup!`, `squash!`, `amend!` y mensajes que ya tengan prefijo `[INICIALES] - rama - `.
- Funciona también durante `rebase -i` o *detached HEAD*.

Para fijar iniciales manualmente:

```bash
export GIT_AUTHOR_INITIALS=AGO
```

En PowerShell:

```powershell
[Environment]::SetEnvironmentVariable("GIT_AUTHOR_INITIALS", "AGO", "User")
```

### `commit-msg`

Valida el formato `[INICIALES] - rama - tipo(scope opcional): descripción`.

Tipos permitidos: `feat`, `fix`, `docs`, `refactor`, `test`, `mnto`, `build`, `ci`, `perf`, `style`, `revert` (soporta `!` para *breaking changes*).

### `pre-commit` y `pre-push`

- `pre-commit`: valida con `bash -n` el contenido **en stage** de scripts `.sh`, `.bash`, `git-hooks/*`, `.githooks/*` y archivos con shebang shell; después ejecuta `.githooks/pre-commit` si existe.
- `pre-push`: ejecuta `.githooks/pre-push` si existe.

## Pruebas y calidad

Ejecutar la suite de pruebas automatizadas en Bash / Git Bash:

```bash
bash tests/run-tests.sh
```

Validar sintaxis manualmente:

```bash
bash -n install.sh scripts/*.sh scripts/lib/*.sh git-hooks/* tests/*.sh
```

Validar PowerShell en Windows:

```powershell
$errors = $null
[System.Management.Automation.Language.Parser]::ParseFile(
    (Resolve-Path .\install.ps1),
    [ref]$null,
    [ref]$errors
) | Out-Null
$errors
```

## Desinstalación

### Linux/macOS

```bash
./install.sh --uninstall
```

### Windows

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1 -Uninstall
```

Ambos restauran un `core.hooksPath` anterior (si había uno respaldado) o lo eliminan, quitan `tools-hooks.root` y borran los comandos instalados en `.local/bin`.

## Roadmap

- Soporte para más licencias.
- Configuración por proyecto (`.tools-hooksrc`).
- Integración con GitHub Actions para ejecutar `tests/run-tests.sh` y ShellCheck automáticamente.

## Licencia

Este proyecto está disponible bajo la licencia MIT.
