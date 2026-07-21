#!/usr/bin/env bash

set -Eeuo pipefail

DEV_TOOLS_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
    pwd
)"

HOOKS_DIR="$DEV_TOOLS_DIR/git-hooks"
SCRIPTS_DIR="$DEV_TOOLS_DIR/scripts"
LOCAL_BIN="$HOME/.local/bin"

INSTALL_LICENSE="ask"

show_help() {
    cat <<'EOF'
Uso:
  ./install.sh [opciones]

Opciones:
  --license       Instala la licencia MIT sin preguntar.
  --no-license    No instala ninguna licencia.
  -h, --help      Muestra esta ayuda.

Sin opciones, el instalador preguntará si deseas agregar la licencia MIT
cuando se ejecute dentro de un repositorio Git sin archivo LICENSE.
EOF
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

is_git_repository() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1
}

install_mit_license() {
    local target_directory="$1"
    local license_file="$target_directory/LICENSE"
    local current_year
    local copyright_holder

    if [[ -e "$license_file" ]]; then
        printf 'LICENSE ya existe. No se modificará.\n'
        return 0
    fi

    current_year="$(date +'%Y')"

    copyright_holder="$(
        git config --get user.name 2>/dev/null ||
        true
    )"

    if [[ -z "$copyright_holder" ]]; then
        copyright_holder="${USER:-Unknown}"
    fi

    cat > "$license_file" <<EOF
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

    printf 'Licencia MIT creada en: %s\n' "$license_file"
}

ask_for_license() {
    local repository_root="$1"
    local answer

    printf '\n'
    printf 'El repositorio no contiene un archivo LICENSE.\n'
    read -r -p '¿Deseas agregar la licencia MIT? [y/N]: ' answer

    case "$answer" in
        y|Y|yes|YES|si|SI|sí|SÍ)
            install_mit_license "$repository_root"
            ;;
        *)
            printf 'La licencia no fue instalada.\n'
            ;;
    esac
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --license)
                INSTALL_LICENSE="yes"
                ;;
            --no-license)
                INSTALL_LICENSE="no"
                ;;
            -h|--help)
                show_help
                exit 0
                ;;
            *)
                die "Opción desconocida: $1"
                ;;
        esac

        shift
    done
}

validate_files() {
    local required_files=(
        "$HOOKS_DIR/prepare-commit-msg"
        "$HOOKS_DIR/commit-msg"
        "$HOOKS_DIR/pre-commit"
        "$HOOKS_DIR/pre-push"
        "$SCRIPTS_DIR/release.sh"
    )

    local required_file

    for required_file in "${required_files[@]}"; do
        [[ -f "$required_file" ]] ||
            die "No existe el archivo requerido: $required_file"
    done
}

install_hooks() {
    chmod +x \
        "$HOOKS_DIR/prepare-commit-msg" \
        "$HOOKS_DIR/commit-msg" \
        "$HOOKS_DIR/pre-commit" \
        "$HOOKS_DIR/pre-push"

    git config --global core.hooksPath "$HOOKS_DIR"

    printf 'Hooks globales instalados en: %s\n' "$HOOKS_DIR"
}

install_release_command() {
    mkdir -p "$LOCAL_BIN"

    chmod +x "$SCRIPTS_DIR/release.sh"

    ln -sfn \
        "$SCRIPTS_DIR/release.sh" \
        "$LOCAL_BIN/git-release"

    printf 'Comando git-release instalado en: %s\n' \
        "$LOCAL_BIN/git-release"
}

configure_path() {
    if [[ ":$PATH:" == *":$LOCAL_BIN:"* ]]; then
        return 0
    fi

    local shell_config="$HOME/.bashrc"
    local path_line='export PATH="$HOME/.local/bin:$PATH"'

    if ! grep -Fqx "$path_line" "$shell_config" 2>/dev/null; then
        printf '\n%s\n' "$path_line" >> "$shell_config"
        printf '%s fue agregado a PATH mediante %s\n' \
            "$LOCAL_BIN" \
            "$shell_config"
    fi

    export PATH="$LOCAL_BIN:$PATH"
}

handle_license() {
    local repository_root

    if ! is_git_repository; then
        printf '\n'
        printf 'No se detectó un repositorio Git en el directorio actual.\n'
        printf 'Se omite la instalación de LICENSE.\n'
        return 0
    fi

    repository_root="$(git rev-parse --show-toplevel)"

    if [[ -e "$repository_root/LICENSE" ]] ||
       [[ -e "$repository_root/LICENSE.md" ]] ||
       [[ -e "$repository_root/LICENSE.txt" ]]; then
        printf '\n'
        printf 'El repositorio ya contiene un archivo de licencia.\n'
        return 0
    fi

    case "$INSTALL_LICENSE" in
        yes)
            install_mit_license "$repository_root"
            ;;
        no)
            printf '\nLa licencia no fue instalada.\n'
            ;;
        ask)
            ask_for_license "$repository_root"
            ;;
    esac
}

main() {
    parse_arguments "$@"
    validate_files

    printf 'Instalando Dev Tools...\n\n'

    install_hooks
    configure_path
    install_release_command
    handle_license

    printf '\n'
    printf 'Instalación completada correctamente.\n'
    printf '\n'
    printf 'Configuración:\n'
    printf '  Hooks:   %s\n' \
        "$(git config --global --get core.hooksPath)"
    printf '  Release: %s\n' \
        "$LOCAL_BIN/git-release"
}

main "$@"
