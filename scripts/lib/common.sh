#!/usr/bin/env bash

# Utilidades compartidas para los comandos de Tools-hooks.

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

info() {
    printf '%s\n' "$*"
}

ok() {
    printf 'OK: %s\n' "$*"
}

warn() {
    printf 'AVISO: %s\n' "$*" >&2
}

is_semver() {
    [[ "$1" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]]
}

resolve_path_dir() {
    local target="$1"
    local dir

    while [[ -L "$target" ]]; do
        dir="$(cd -P -- "$(dirname -- "$target")" && pwd)"
        target="$(readlink "$target")"
        [[ "$target" == /* ]] || target="$dir/$target"
    done

    cd -P -- "$(dirname -- "$target")" && pwd
}

resolve_tools_hooks_root() {
    local configured_root
    configured_root="$(git config --global --get tools-hooks.root 2>/dev/null || true)"

    if [[ -n "$configured_root" && -d "$configured_root/scripts" ]]; then
        printf '%s\n' "$configured_root"
        return 0
    fi

    local caller_source="${1:-${BASH_SOURCE[0]}}"
    local script_dir
    local candidate_root

    script_dir="$(resolve_path_dir "$caller_source")"
    candidate_root="$(cd -P -- "$script_dir/.." && pwd)"

    if [[ -d "$candidate_root/scripts" ]]; then
        printf '%s\n' "$candidate_root"
        return 0
    fi

    candidate_root="$(cd -P -- "$script_dir/../.." && pwd)"
    if [[ -d "$candidate_root/scripts" ]]; then
        printf '%s\n' "$candidate_root"
        return 0
    fi

    die "No se pudo resolver la ruta de Tools-hooks. Ejecuta ./install.sh o install.ps1"
}

require_git_repo() {
    git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
        die "Debes ejecutar este comando dentro de un repositorio Git"

    REPOSITORY_ROOT="$(git rev-parse --show-toplevel)"
    cd "$REPOSITORY_ROOT"
}

ask_yes_no() {
    local prompt="$1"
    local default="${2:-N}"
    local suffix="[y/N]"
    local answer=""

    if [[ "$default" == "Y" ]]; then
        suffix="[Y/n]"
    fi

    if ! IFS= read -r -p "$prompt $suffix: " answer; then
        answer=""
    fi

    if [[ -z "$answer" ]]; then
        [[ "$default" == "Y" ]]
        return $?
    fi

    case "$answer" in
        y|Y|yes|YES|si|SI|s|S)
            return 0
            ;;
        n|N|no|NO)
            return 1
            ;;
        *)
            [[ "$default" == "Y" ]]
            return $?
            ;;
    esac
}
