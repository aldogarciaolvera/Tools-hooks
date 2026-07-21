#!/usr/bin/env bash

set -Eeuo pipefail

INITIAL_VERSION="0.1.0"
LICENSE_MODE="ask"

show_help() {
    cat <<'EOF'
Uso:
  git-project-init [opciones]

Opciones:
  --version X.Y.Z   Versión inicial. Por defecto: 0.1.0
  --license         Crea la licencia MIT sin preguntar.
  --no-license      No crea ninguna licencia.
  -h, --help        Muestra esta ayuda.

Ejemplos:
  git-project-init
  git-project-init --version 1.0.0
  git-project-init --version 1.0.0 --license
EOF
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

is_semver() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

create_version() {
    if [[ -e VERSION ]]; then
        printf 'VERSION ya existe. No se modificará.\n'
        return
    fi

    printf '%s\n' "$INITIAL_VERSION" > VERSION
    printf 'Creado: VERSION (%s)\n' "$INITIAL_VERSION"
}

create_changelog() {
    if [[ -e CHANGELOG.md ]]; then
        printf 'CHANGELOG.md ya existe. No se modificará.\n'
        return
    fi

    local current_date
    current_date="$(date +'%Y-%m-%d')"

    cat > CHANGELOG.md <<EOF
# Changelog

Todos los cambios relevantes de este proyecto se documentarán en este archivo.

El formato está basado en Keep a Changelog y el proyecto utiliza Semantic Versioning.

## [$INITIAL_VERSION] - $current_date

### Added

- Inicialización del proyecto.
EOF

    printf 'Creado: CHANGELOG.md\n'
}

create_mit_license() {
    if [[ -e LICENSE ]] ||
       [[ -e LICENSE.md ]] ||
       [[ -e LICENSE.txt ]]; then
        printf 'El proyecto ya contiene un archivo de licencia.\n'
        return
    fi

    local current_year
    local copyright_holder

    current_year="$(date +'%Y')"
    copyright_holder="$(git config --get user.name 2>/dev/null || true)"

    if [[ -z "$copyright_holder" ]]; then
        copyright_holder="${USER:-Unknown}"
    fi

    cat > LICENSE <<EOF
MIT License

Copyright (c) $current_year $copyright_holder

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

    printf 'Creado: LICENSE (MIT)\n'
}

handle_license() {
    local answer

    if [[ -e LICENSE ]] ||
       [[ -e LICENSE.md ]] ||
       [[ -e LICENSE.txt ]]; then
        printf 'El proyecto ya contiene un archivo de licencia.\n'
        return
    fi

    case "$LICENSE_MODE" in
        yes)
            create_mit_license
            ;;
        no)
            printf 'La licencia no fue creada.\n'
            ;;
        ask)
            printf '\n'
            read -r -p '¿Deseas agregar la licencia MIT? [y/N]: ' answer

            case "$answer" in
                y|Y|yes|YES|si|SI|sí|SÍ)
                    create_mit_license
                    ;;
                *)
                    printf 'La licencia no fue creada.\n'
                    ;;
            esac
            ;;
    esac
}

create_repository_validations() {
    mkdir -p .githooks

    if [[ ! -e .githooks/pre-commit ]]; then
        cat > .githooks/pre-commit <<'EOF'
#!/usr/bin/env bash

set -Eeuo pipefail

git-project-check
EOF

        chmod +x .githooks/pre-commit
        printf 'Creado: .githooks/pre-commit\n'
    else
        printf '.githooks/pre-commit ya existe. No se modificará.\n'
    fi

    if [[ ! -e .githooks/pre-push ]]; then
        cat > .githooks/pre-push <<'EOF'
#!/usr/bin/env bash

set -Eeuo pipefail

git-project-check
EOF

        chmod +x .githooks/pre-push
        printf 'Creado: .githooks/pre-push\n'
    else
        printf '.githooks/pre-push ya existe. No se modificará.\n'
    fi
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            [[ $# -ge 2 ]] ||
                die "Debes indicar una versión después de --version"

            INITIAL_VERSION="$2"
            shift 2
            ;;
        --license)
            LICENSE_MODE="yes"
            shift
            ;;
        --no-license)
            LICENSE_MODE="no"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            die "Opción desconocida: $1"
            ;;
    esac
done

is_semver "$INITIAL_VERSION" ||
    die "La versión debe tener el formato X.Y.Z"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    die "Debes ejecutar este comando dentro de un repositorio Git"

REPOSITORY_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPOSITORY_ROOT"

printf 'Inicializando archivos del proyecto en:\n'
printf '  %s\n\n' "$REPOSITORY_ROOT"

create_version
create_changelog
handle_license
create_repository_validations

printf '\n'
printf 'Validando resultado...\n\n'

git-project-check

printf '\nProyecto inicializado correctamente.\n'
