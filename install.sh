#!/usr/bin/env bash

set -Eeuo pipefail

TOOLS_HOOKS_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
    pwd
)"

HOOKS_DIR="$TOOLS_HOOKS_DIR/git-hooks"
SCRIPTS_DIR="$TOOLS_HOOKS_DIR/scripts"
LOCAL_BIN="$HOME/.local/bin"

show_help() {
    cat <<'EOF'
Uso:
  ./install.sh [opciones]

Opciones:
  -h, --help    Muestra esta ayuda.

El instalador realiza únicamente estas acciones:

- Instala los hooks globales de Git.
- Configura ~/.local/bin en PATH cuando sea necesario.
- Instala los comandos globales:
    git-project-init
    git-project-check
    git-release
EOF
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

parse_arguments() {
    if [[ $# -eq 0 ]]; then
        return
    fi

    case "$1" in
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            die "Opción desconocida: $1"
            ;;
    esac
}

validate_dependencies() {
    command -v git >/dev/null 2>&1 ||
        die "Git no está instalado o no está disponible en PATH"

    command -v bash >/dev/null 2>&1 ||
        die "Bash no está instalado o no está disponible en PATH"
}

validate_files() {
    local required_files=(
        "$HOOKS_DIR/prepare-commit-msg"
        "$HOOKS_DIR/commit-msg"
        "$HOOKS_DIR/pre-commit"
        "$HOOKS_DIR/pre-push"
        "$SCRIPTS_DIR/project-init.sh"
        "$SCRIPTS_DIR/project-check.sh"
        "$SCRIPTS_DIR/release.sh"
    )

    local required_file

    for required_file in "${required_files[@]}"; do
        [[ -f "$required_file" ]] ||
            die "No existe el archivo requerido: $required_file"

        bash -n "$required_file" ||
            die "El archivo contiene errores de sintaxis: $required_file"
    done
}

install_hooks() {
    chmod +x \
        "$HOOKS_DIR/prepare-commit-msg" \
        "$HOOKS_DIR/commit-msg" \
        "$HOOKS_DIR/pre-commit" \
        "$HOOKS_DIR/pre-push"

    git config --global core.hooksPath "$HOOKS_DIR"

    local configured_hooks_path
    configured_hooks_path="$(
        git config --global --get core.hooksPath ||
        true
    )"

    [[ "$configured_hooks_path" == "$HOOKS_DIR" ]] ||
        die "No se pudo configurar core.hooksPath"

    printf 'Hooks globales instalados en:\n'
    printf '  %s\n' "$HOOKS_DIR"
}

detect_shell_config() {
    case "${SHELL:-}" in
        */zsh)
            printf '%s\n' "$HOME/.zshrc"
            ;;
        */bash)
            printf '%s\n' "$HOME/.bashrc"
            ;;
        *)
            if [[ -f "$HOME/.bashrc" ]]; then
                printf '%s\n' "$HOME/.bashrc"
            elif [[ -f "$HOME/.zshrc" ]]; then
                printf '%s\n' "$HOME/.zshrc"
            else
                printf '%s\n' "$HOME/.profile"
            fi
            ;;
    esac
}

configure_path() {
    # shellcheck disable=SC2016
    local path_line='export PATH="$HOME/.local/bin:$PATH"'
    local shell_config

    shell_config="$(detect_shell_config)"

    mkdir -p "$LOCAL_BIN"
    touch "$shell_config"

    if [[ ":$PATH:" == *":$LOCAL_BIN:"* ]]; then
        printf '%s ya está incluido en PATH.\n' "$LOCAL_BIN"
        return 0
    fi

    if grep -Fqx "$path_line" "$shell_config" 2>/dev/null; then
        printf '%s ya está configurado en %s.\n' \
            "$LOCAL_BIN" \
            "$shell_config"
    else
        printf '\n%s\n' "$path_line" >> "$shell_config"

        printf '%s fue agregado a PATH mediante:\n' \
            "$LOCAL_BIN"
        printf '  %s\n' "$shell_config"
    fi

    export PATH="$LOCAL_BIN:$PATH"
}

install_command() {
    local source_file="$1"
    local command_name="$2"
    local target_file="$LOCAL_BIN/$command_name"

    chmod +x "$source_file"

    ln -sfn "$source_file" "$target_file"

    [[ -L "$target_file" ]] ||
        die "No se pudo crear el enlace para $command_name"

    printf '  %-20s -> %s\n' \
        "$command_name" \
        "$source_file"
}

install_commands() {
    mkdir -p "$LOCAL_BIN"

    printf 'Instalando comandos globales:\n'

    install_command \
        "$SCRIPTS_DIR/project-init.sh" \
        "git-project-init"

    install_command \
        "$SCRIPTS_DIR/project-check.sh" \
        "git-project-check"

    install_command \
        "$SCRIPTS_DIR/release.sh" \
        "git-release"
}

verify_installation() {
    local failed=0
    local command_name

    printf '\nVerificando instalación...\n'

    for command_name in \
        git-project-init \
        git-project-check \
        git-release
    do
        if [[ -x "$LOCAL_BIN/$command_name" ]]; then
            printf 'OK: %s\n' "$LOCAL_BIN/$command_name"
        else
            printf 'ERROR: No se pudo instalar %s\n' \
                "$command_name" >&2
            failed=1
        fi
    done

    local hooks_path
    hooks_path="$(
        git config --global --get core.hooksPath ||
        true
    )"

    if [[ "$hooks_path" == "$HOOKS_DIR" ]]; then
        printf 'OK: core.hooksPath=%s\n' "$hooks_path"
    else
        printf 'ERROR: core.hooksPath no está configurado correctamente.\n' \
            >&2
        failed=1
    fi

    [[ "$failed" -eq 0 ]] ||
        die "La instalación no pudo verificarse correctamente"
}

print_summary() {
    local shell_config

    shell_config="$(detect_shell_config)"

    printf '\n'
    printf 'Instalación completada correctamente.\n'

    printf '\nConfiguración global:\n'
    printf '  Hooks:   %s\n' \
        "$(git config --global --get core.hooksPath)"
    printf '  Binarios: %s\n' "$LOCAL_BIN"

    printf '\nComandos disponibles:\n'
    printf '  git-project-init\n'
    printf '  git-project-check\n'
    printf '  git-release\n'

    if [[ ":$PATH:" != *":$LOCAL_BIN:"* ]]; then
        printf '\nPara actualizar la terminal actual ejecuta:\n'
        printf '  source %s\n' "$shell_config"
    else
        printf '\nLos comandos ya están disponibles en esta terminal.\n'
    fi
}

main() {
    parse_arguments "$@"
    validate_dependencies
    validate_files

    printf 'Instalando Tools Hooks...\n\n'

    install_hooks

    printf '\n'
    configure_path

    printf '\n'
    install_commands

    verify_installation
    print_summary
}

main "$@"
