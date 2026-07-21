# Tools Hooks

Herramientas reutilizables para configurar un flujo de trabajo consistente con Git.

El proyecto instala hooks globales, proporciona un comando para generar releases y permite agregar una licencia MIT a los repositorios.

## Características

- Instalación de hooks globales para Git.
- Prefijo automático en mensajes de commit.
- Validación de Conventional Commits.
- Validación de scripts Bash antes de cada commit.
- Ejecución de validaciones específicas de cada repositorio.
- Validaciones antes de realizar un push.
- Creación de releases mediante Semantic Versioning.
- Actualización automática de `VERSION` y `CHANGELOG.md`.
- Creación automática de etiquetas Git.
- Instalación opcional de licencia MIT.

## Estructura

```text
Tools-hooks/
├── git-hooks/
│   ├── commit-msg
│   ├── pre-commit
│   ├── prepare-commit-msg
│   └── pre-push
├── scripts/
│   └── release.sh
├── CHANGELOG.md
├── install.sh
├── LICENSE
├── README.md
└── VERSION
```

## Requisitos

- Git
- Bash
- Linux o macOS

## Instalación

Clona el repositorio:

```bash
git clone git@github.com:aldogarciaolvera/Tools-hooks.git
```

Entra al directorio:

```bash
cd Tools-hooks
```

Ejecuta el instalador:

```bash
./install.sh
```

El instalador:

- configura los hooks globales;
- instala el comando `git-release`;
- agrega `~/.local/bin` al `PATH` cuando sea necesario;
- pregunta si deseas agregar una licencia MIT cuando el repositorio no tiene una.

## Opciones de instalación

Instalación interactiva:

```bash
./install.sh
```

Instalar la licencia MIT sin preguntar:

```bash
./install.sh --license
```

No instalar licencia ni mostrar la pregunta:

```bash
./install.sh --no-license
```

Mostrar ayuda:

```bash
./install.sh --help
```

## Hooks instalados

### `prepare-commit-msg`

Agrega automáticamente las iniciales y la rama actual al mensaje del commit.

Comando:

```bash
git commit -m "feat: agrega una funcionalidad"
```

Resultado:

```text
[AGO] - main - feat: agrega una funcionalidad
```

Las iniciales pueden personalizarse:

```bash
export GIT_AUTHOR_INITIALS=ABC
```

### `commit-msg`

Valida que los mensajes utilicen Conventional Commits.

Tipos permitidos:

```text
feat
fix
docs
refactor
test
chore
build
ci
perf
style
revert
```

Ejemplos:

```text
feat: agrega una funcionalidad
fix: corrige un error
docs: actualiza documentación
feat(auth): agrega autenticación
```

### `pre-commit`

Valida la sintaxis de los scripts Bash agregados al commit.

También ejecuta el siguiente archivo cuando existe y tiene permisos de ejecución:

```text
.githooks/pre-commit
```

### `pre-push`

Ejecuta el siguiente archivo cuando existe y tiene permisos de ejecución:

```text
.githooks/pre-push
```

Si la validación devuelve un error, el push se cancela.

## Releases

El instalador agrega el comando:

```bash
git-release
```

Para crear una release:

```bash
git-release 1.1.0
```

La versión debe utilizar el formato:

```text
MAJOR.MINOR.PATCH
```

El comando:

1. valida que el repositorio esté limpio;
2. valida la versión actual y la nueva;
3. actualiza `VERSION`;
4. agrega una entrada a `CHANGELOG.md`;
5. crea el commit de release;
6. crea una etiqueta anotada, por ejemplo `v1.1.0`.

La release se crea localmente. Para publicarla:

```bash
git push origin main
git push origin v1.1.0
```

## Licencia MIT

Durante la instalación, si el repositorio actual no contiene alguno de estos archivos:

```text
LICENSE
LICENSE.md
LICENSE.txt
```

el instalador pregunta si deseas crear una licencia MIT.

El nombre del titular se obtiene de:

```bash
git config user.name
```

## Desinstalación

Quita la configuración global de hooks:

```bash
git config --global --unset core.hooksPath
```

Elimina el comando global:

```bash
rm -f ~/.local/bin/git-release
```

Después puedes eliminar la carpeta del proyecto.

## Licencia

Este proyecto está disponible bajo la licencia MIT.
