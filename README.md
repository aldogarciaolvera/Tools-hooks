# Tools-hooks

Herramientas reutilizables para configurar un flujo de trabajo consistente con Git en Linux, macOS y Windows.

Tools-hooks instala hooks globales, valida mensajes con Conventional Commits, prepara repositorios y automatiza la creación y publicación de versiones.

## Características

- Hooks globales reutilizables.
- Prefijo automático con iniciales y rama actual.
- Validación de Conventional Commits.
- Validación de scripts Bash antes de confirmar cambios.
- Validaciones específicas de cada repositorio.
- Inicialización de proyectos con `git-project-init`.
- Validación de proyectos con `git-project-check`.
- Releases con Semantic Versioning mediante `git-release`.
- Actualización automática de `VERSION` y `CHANGELOG.md`.
- Creación de commits y tags de release.
- Push automático de la rama y el tag después de confirmarlo.
- Instalación compatible con Linux, macOS y Windows.

## Plataformas compatibles

| Plataforma | Instalación recomendada | Uso de comandos |
|---|---|---|
| Linux | `install.sh` | Terminal Bash |
| macOS | `install.sh` | Terminal Bash/Zsh |
| Windows | `install.ps1` | PowerShell, CMD o Windows Terminal |
| Windows con Git Bash | `install.sh` o `install.ps1` | Git Bash |

En Windows, los scripts siguen ejecutándose mediante **Git Bash**, pero el instalador de PowerShell crea comandos `.cmd`, por lo que pueden invocarse directamente desde PowerShell, CMD o Windows Terminal.

## Requisitos

### Linux y macOS

- Git.
- Bash.
- Utilidades estándar como `grep`, `sed`, `mktemp` y `date`.

### Windows

- Windows 10 o Windows 11.
- Git for Windows, incluyendo Git Bash.
- PowerShell 5.1 o superior.

## Estructura

```text
Tools-hooks/
├── git-hooks/
│   ├── commit-msg
│   ├── pre-commit
│   ├── prepare-commit-msg
│   └── pre-push
├── scripts/
│   ├── project-check.sh
│   ├── project-init.sh
│   └── release.sh
├── CHANGELOG.md
├── install.ps1
├── install.sh
├── LICENSE
├── README.md
└── VERSION
```

## Instalación en Linux o macOS

Clona el repositorio:

```bash
git clone https://github.com/aldogarciaolvera/Tools-hooks.git
cd Tools-hooks
```

Concede permisos de ejecución cuando sea necesario:

```bash
chmod +x install.sh scripts/*.sh git-hooks/*
```

Ejecuta el instalador:

```bash
./install.sh
```

El instalador:

- configura `core.hooksPath`;
- instala `git-project-init`;
- instala `git-project-check`;
- instala `git-release`;
- agrega `~/.local/bin` al `PATH` cuando sea necesario.

Después de instalar, abre una terminal nueva o ejecuta:

```bash
source ~/.bashrc
```

En macOS con Zsh, puede ser necesario abrir una terminal nueva o cargar `~/.zshrc`.

## Instalación en Windows

Primero instala **Git for Windows** y asegúrate de incluir Git Bash.

Después, abre PowerShell y ejecuta:

```powershell
git clone https://github.com/aldogarciaolvera/Tools-hooks.git
cd Tools-hooks
```

Ejecuta el instalador:

```powershell
powershell -ExecutionPolicy Bypass -File .\install.ps1
```

También puedes habilitar temporalmente la ejecución de scripts solo para la sesión actual:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\install.ps1
```

El instalador de Windows:

- localiza Git for Windows y Git Bash;
- configura los hooks globales;
- crea wrappers `.cmd` en `%USERPROFILE%\.local\bin`;
- instala:
  - `git-project-init`;
  - `git-project-check`;
  - `git-release`;
- agrega esa carpeta al `PATH` del usuario.

Cierra y vuelve a abrir PowerShell, CMD o Windows Terminal después de instalar.

### Verificación en Windows

```powershell
git config --global --get core.hooksPath
where.exe git-project-init
where.exe git-project-check
where.exe git-release
```

## Importante: ubicación del repositorio

No muevas ni elimines la carpeta `Tools-hooks` después de instalar.

Los comandos instalados y `core.hooksPath` apuntan a sus scripts mediante una ruta absoluta. Si cambias la ubicación del repositorio, vuelve a ejecutar el instalador correspondiente:

```bash
./install.sh
```

o en Windows:

```powershell
.\install.ps1
```

## Flujo de trabajo recomendado

### 1. Crear un repositorio

```bash
mkdir MiProyecto
cd MiProyecto
git init
```

Configura el remoto cuando corresponda:

```bash
git remote add origin https://github.com/usuario/MiProyecto.git
```

### 2. Inicializar el proyecto

```bash
git-project-init --version 0.1.0
```

El comando crea, solamente cuando no existan:

```text
VERSION
CHANGELOG.md
LICENSE
.githooks/pre-commit
.githooks/pre-push
```

No sobrescribe archivos existentes.

### 3. Trabajar normalmente

```bash
git add .
git commit -m "feat(api): agrega autenticación"
```

Los hooks globales validan el mensaje y delegan las comprobaciones específicas a los hooks del repositorio.

### 4. Validar manualmente

```bash
git-project-check
```

### 5. Crear y publicar una versión

```bash
git-release 1.2.0
```

El comando:

1. ejecuta `git-project-check`;
2. comprueba que no existan cambios sin confirmar;
3. actualiza `VERSION`;
4. agrega una entrada a `CHANGELOG.md`;
5. crea el commit de release;
6. crea el tag anotado `v1.2.0`;
7. pregunta si deseas publicar;
8. si aceptas, ejecuta:

```bash
git push origin <rama-actual>
git push origin v1.2.0
```

Si rechazas la publicación, el commit y el tag permanecen creados localmente.

## Comandos disponibles

### `git-project-init`

Inicializa la estructura mínima de un repositorio.

```bash
git-project-init
```

Usar una versión inicial específica:

```bash
git-project-init --version 1.0.0
```

Crear una licencia MIT sin preguntar:

```bash
git-project-init --license
```

No crear una licencia:

```bash
git-project-init --no-license
```

Mostrar ayuda:

```bash
git-project-init --help
```

### `git-project-check`

Comprueba que el proyecto tenga una estructura válida.

```bash
git-project-check
```

Entre otras validaciones, revisa:

- que exista `VERSION`;
- que la versión utilice el formato `MAJOR.MINOR.PATCH`;
- que exista `CHANGELOG.md`;
- que el changelog contenga `# Changelog`;
- si existe una licencia;
- si la licencia detectada parece ser MIT.

El comando devuelve un código distinto de cero cuando encuentra un error bloqueante.

### `git-release`

Crea una nueva versión:

```bash
git-release 1.2.0
```

La versión debe usar Semantic Versioning:

```text
MAJOR.MINOR.PATCH
```

Ejemplos:

```text
1.0.0
1.2.0
1.2.1
2.0.0
```

Antes de utilizarlo:

- confirma todos los cambios;
- asegúrate de tener configurado `origin`;
- verifica que la rama actual pueda publicarse;
- usa una versión diferente de la actual.

## Hooks instalados

### `prepare-commit-msg`

Agrega automáticamente las iniciales del autor y la rama actual.

Comando:

```bash
git commit -m "feat: agrega una funcionalidad"
```

Resultado:

```text
[AGO] - main - feat: agrega una funcionalidad
```

Las iniciales pueden personalizarse:

#### Linux/macOS

```bash
export GIT_AUTHOR_INITIALS=ABC
```

#### Windows PowerShell

Solo para la sesión actual:

```powershell
$env:GIT_AUTHOR_INITIALS = "ABC"
```

De forma persistente para el usuario:

```powershell
[Environment]::SetEnvironmentVariable(
    "GIT_AUTHOR_INITIALS",
    "ABC",
    "User"
)
```

### `commit-msg`

Valida que el mensaje utilice Conventional Commits.

Formato:

```text
tipo: descripción
```

o:

```text
tipo(scope): descripción
```

Ejemplos:

```text
feat: agrega autenticación JWT
fix(api): corrige validación de usuarios
docs(readme): mejora la instalación
```

### `pre-commit`

Valida la sintaxis de los scripts Bash agregados al commit.

También ejecuta, cuando existe y tiene permisos de ejecución:

```text
.githooks/pre-commit
```

### `pre-push`

Ejecuta, cuando existe y tiene permisos de ejecución:

```text
.githooks/pre-push
```

Si la validación falla, Git cancela el push.

## Conventional Commits

| Tipo | Descripción | Ejemplo |
|---|---|---|
| `feat` | Agrega una funcionalidad. | `feat: agrega exportación a PDF` |
| `fix` | Corrige un error existente. | `fix: corrige creación de respaldos` |
| `docs` | Modifica documentación. | `docs: actualiza instalación` |
| `refactor` | Reestructura sin cambiar comportamiento. | `refactor: simplifica configuración` |
| `test` | Agrega o modifica pruebas. | `test: agrega pruebas de release` |
| `mnto` | Tareas generales de mantenimiento. | `mnto: actualiza dependencias` |
| `build` | Cambios de compilación o empaquetado. | `build: actualiza Dockerfile` |
| `ci` | Cambios de integración continua. | `ci: agrega GitHub Actions` |
| `perf` | Mejoras de rendimiento. | `perf: optimiza compresión` |
| `style` | Cambios de formato sin alterar lógica. | `style: aplica formato` |
| `revert` | Revierte cambios anteriores. | `revert: revierte cambio de configuración` |

### Scope opcional

El scope identifica la parte afectada:

```text
feat(auth): agrega autenticación JWT
fix(mysql): corrige restauración
docs(readme): mejora documentación
refactor(config): reorganiza variables
```

## Validaciones específicas por repositorio

Los hooks globales ejecutan los hooks locales del proyecto cuando existen.

Ejemplo para un proyecto .NET:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

git-project-check
dotnet test
```

Ejemplo para Node.js:

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

git-project-check
npm test
npm run lint
```

Guárdalo en:

```text
.githooks/pre-commit
```

En Linux/macOS:

```bash
chmod +x .githooks/pre-commit
```

En Windows, Git for Windows ejecuta los hooks a través de Git Bash. Conserva el encabezado:

```bash
#!/usr/bin/env bash
```

## Comprobación de calidad del proyecto

Validar sintaxis:

```bash
bash -n install.sh
bash -n scripts/*.sh
bash -n git-hooks/*
```

Ejecutar ShellCheck:

```bash
shellcheck install.sh
shellcheck scripts/*.sh
shellcheck git-hooks/*
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

Si no muestra errores, la sintaxis de `install.ps1` es válida.

## Desinstalación

### Linux/macOS

Quita la configuración global:

```bash
git config --global --unset core.hooksPath
```

Elimina los comandos:

```bash
rm -f ~/.local/bin/git-project-init
rm -f ~/.local/bin/git-project-check
rm -f ~/.local/bin/git-release
```

Después puedes eliminar el repositorio.

### Windows

Quita la configuración global:

```powershell
git config --global --unset core.hooksPath
```

Elimina los wrappers:

```powershell
Remove-Item "$HOME\.local\bin\git-project-init.cmd" -ErrorAction SilentlyContinue
Remove-Item "$HOME\.local\bin\git-project-check.cmd" -ErrorAction SilentlyContinue
Remove-Item "$HOME\.local\bin\git-release.cmd" -ErrorAction SilentlyContinue
```

Opcionalmente elimina `%USERPROFILE%\.local\bin` del `PATH` del usuario si ya no contiene otros comandos.

## Solución de problemas

### `Permission denied` en Linux

Concede permisos:

```bash
chmod +x install.sh scripts/*.sh git-hooks/*
```

Después ejecuta nuevamente:

```bash
./install.sh
```

### El comando no se encuentra

Abre una terminal nueva.

En Linux también puedes ejecutar:

```bash
source ~/.bashrc
```

En Windows revisa:

```powershell
$env:Path -split ';'
where.exe git-release
```

### PowerShell bloquea `install.ps1`

Ejecuta:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\install.ps1
```

Esto solamente modifica la política de la sesión actual.

### Se movió la carpeta Tools-hooks

Vuelve a ejecutar el instalador desde la nueva ubicación.

### `git-release` informa que hay cambios sin confirmar

Revisa:

```bash
git status
```

Confirma o descarta los cambios antes de volver a ejecutar el release.

### No existe `origin`

Configura el remoto:

```bash
git remote add origin https://github.com/usuario/repositorio.git
```

## Roadmap

- `git-project-update` para actualizar proyectos existentes.
- Soporte para más licencias.
- Plantillas de `.gitignore`.
- Plantillas opcionales de README.
- Configuración por proyecto.
- Pruebas automatizadas.
- GitHub Actions.
- Instalador de desinstalación dedicado.

## Licencia

Este proyecto está disponible bajo la licencia MIT.
