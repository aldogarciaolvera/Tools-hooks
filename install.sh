#!/usr/bin/env bash

set -Eeuo pipefail

TOOLS_HOOKS_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
    pwd
)"

HOOKS_DIR="$TOOLS_HOOKS_DIR/git-hooks"
SCRIPTS_DIR="$TOOLS_HOOKS_DIR/scripts"
LIB_DIR="$SCRIPTS_DIR/lib"
LOCAL_BIN="$HOME/.local/bin"

ACTION="install"
PATH_WAS_CONFIGURED=0

normalize_git_path() {
    local p="$1"
    if command -v cygpath >/dev/null 2>&1; then
        cygpath -m "$p"
    else
        printf '%s\n' "$p"
    fi
}

HOOKS_GIT_PATH="$(normalize_git_path "$HOOKS_DIR")"
ROOT_GIT_PATH="$(normalize_git_path "$TOOLS_HOOKS_DIR")"

show_help() {
    cat <<'EOF'
Uso:
  ./install.sh [opciones]

Opciones:
  --uninstall   Desinstala hooks y enlaces creados por Tools-hooks.
  -h, --help    Muestra esta ayuda.

El instalador realiza unicamente estas acciones:

- Instala los hooks globales de Git.
- Configura ~/.local/bin en PATH cuando sea necesario.
- Instala los comandos globales:
    git-project-init
    git-project-check
    git-project-update
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
        --uninstall)
            ACTION="uninstall"
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            die "Opcion desconocida: $1"
            ;;
    esac
}

validate_dependencies() {
    command -v git >/dev/null 2>&1 ||
        die "Git no esta instalado o no esta disponible en PATH"

    command -v bash >/dev/null 2>&1 ||
        die "Bash no esta instalado o no esta disponible en PATH"
}

validate_files() {
    local required_files=(
        "$HOOKS_DIR/prepare-commit-msg"
        "$HOOKS_DIR/commit-msg"
        "$HOOKS_DIR/pre-commit"
        "$HOOKS_DIR/pre-push"
        "$LIB_DIR/common.sh"
        "$LIB_DIR/generators.sh"
        "$SCRIPTS_DIR/project-init.sh"
        "$SCRIPTS_DIR/project-check.sh"
        "$SCRIPTS_DIR/project-update.sh"
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

    local previous_hooks_path
    previous_hooks_path="$(git config --global --get core.hooksPath || true)"
    if [[ -n "$previous_hooks_path" && "$previous_hooks_path" != "$HOOKS_GIT_PATH" && "$previous_hooks_path" != "$HOOKS_DIR" ]]; then
        printf 'AVISO: core.hooksPath ya apuntaba a: %s\n' "$previous_hooks_path" >&2
        printf '       Se respalda en git config tools-hooks.previous-hooks-path.\n' >&2
        git config --global tools-hooks.previous-hooks-path "$previous_hooks_path"
    fi

    git config --global core.hooksPath "$HOOKS_GIT_PATH"
    git config --global tools-hooks.root "$ROOT_GIT_PATH"

    local configured_hooks_path
    configured_hooks_path="$(
        git config --global --get core.hooksPath ||
        true
    )"

    [[ "$configured_hooks_path" == "$HOOKS_GIT_PATH" ]] ||
        die "No se pudo configurar core.hooksPath"

    printf 'Hooks globales instalados en:\n'
    printf '  %s\n' "$HOOKS_GIT_PATH"
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
        PATH_WAS_CONFIGURED=1
        printf '%s ya esta incluido en PATH.\n' "$LOCAL_BIN"
        return 0
    fi

    if grep -Fqx "$path_line" "$shell_config" 2>/dev/null; then
        printf '%s ya esta configurado en %s.\n' \
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

    [[ -L "$target_file" || -f "$target_file" ]] ||
        die "No se pudo crear el enlace para $command_name"

    printf '  %-20s -> %s\n' \
        "$command_name" \
        "$source_file"
}

install_commands() {
    mkdir -p "$LOCAL_BIN"

    printf 'Instalando comandos globales:\n'

    install_command "$SCRIPTS_DIR/project-init.sh" "git-project-init"
    install_command "$SCRIPTS_DIR/project-check.sh" "git-project-check"
    install_command "$SCRIPTS_DIR/project-update.sh" "git-project-update"
    install_command "$SCRIPTS_DIR/release.sh" "git-release"
}

verify_installation() {
    local failed=0
    local command_name

    printf '\nVerificando instalacion...\n'

    for command_name in \
        git-project-init \
        git-project-check \
        git-project-update \
        git-release
    do
        if [[ -x "$LOCAL_BIN/$command_name" ]]; then
            printf 'OK: %s\n' "$LOCAL_BIN/$command_name"
        else
            printf 'ERROR: No se pudo instalar %s\n' "$command_name" >&2
            failed=1
        fi
    done

    local hooks_path
    local configured_root

    hooks_path="$(git config --global --get core.hooksPath || true)"
    if [[ "$hooks_path" == "$HOOKS_GIT_PATH" ]]; then
        printf 'OK: core.hooksPath=%s\n' "$hooks_path"
    else
        printf 'ERROR: core.hooksPath no esta configurado correctamente.\n' >&2
        failed=1
    fi

    configured_root="$(git config --global --get tools-hooks.root || true)"
    if [[ "$configured_root" == "$ROOT_GIT_PATH" ]]; then
        printf 'OK: tools-hooks.root=%s\n' "$configured_root"
    else
        printf 'ERROR: tools-hooks.root no esta configurado correctamente.\n' >&2
        failed=1
    fi

    [[ "$failed" -eq 0 ]] ||
        die "La instalacion no pudo verificarse correctamente"
}

print_summary() {
    local shell_config
    shell_config="$(detect_shell_config)"

    printf '\n'
    printf 'Instalacion completada correctamente.\n'

    printf '\nConfiguracion global:\n'
    printf '  Hooks:    %s\n' "$(git config --global --get core.hooksPath)"
    printf '  Binarios: %s\n' "$LOCAL_BIN"

    printf '\nComandos disponibles:\n'
    printf '  git-project-init\n'
    printf '  git-project-check\n'
    printf '  git-project-update\n'
    printf '  git-release\n'

    if [[ "$PATH_WAS_CONFIGURED" -eq 0 ]]; then
        printf '\nPara actualizar la terminal actual ejecuta:\n'
        printf '  source %s\n' "$shell_config"
    else
        printf '\nLos comandos ya estan disponibles en esta terminal.\n'
    fi
}

uninstall_tools_hooks() {
    printf 'Desinstalando Tools-hooks...\n\n'

    local current_hooks
    local previous_hooks
    current_hooks="$(git config --global --get core.hooksPath || true)"
    previous_hooks="$(git config --global --get tools-hooks.previous-hooks-path || true)"

    if [[ "$current_hooks" == "$HOOKS_GIT_PATH" || "$current_hooks" == "$HOOKS_DIR" ]]; then
        if [[ -n "$previous_hooks" ]]; then
            git config --global core.hooksPath "$previous_hooks"
            printf 'Restaurado core.hooksPath anterior: %s\n' "$previous_hooks"
        else
            git config --global --unset core.hooksPath || true
            printf 'Eliminado core.hooksPath global.\n'
        fi
    fi

    git config --global --unset tools-hooks.root 2>/dev/null || true
    git config --global --unset tools-hooks.previous-hooks-path 2>/dev/null || true

    local command_name
    for command_name in \
        git-project-init \
        git-project-check \
        git-project-update \
        git-release
    do
        if [[ -L "$LOCAL_BIN/$command_name" || -f "$LOCAL_BIN/$command_name" ]]; then
            rm -f -- "$LOCAL_BIN/$command_name"
            printf 'Eliminado: %s\n' "$LOCAL_BIN/$command_name"
        fi
    done

    printf '\nDesinstalacion completada.\n'
}

main() {
    parse_arguments "$@"
    validate_dependencies

    if [[ "$ACTION" == "uninstall" ]]; then
        uninstall_tools_hooks
        exit 0
    fi

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
