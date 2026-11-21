#!/usr/bin/env bash

set -Eeuo pipefail

resolve_bootstrap_root() {
    local src="${BASH_SOURCE[0]}"
    local dir
    while [[ -L "$src" ]]; do
        dir="$(cd -P -- "$(dirname -- "$src")" && pwd)"
        src="$(readlink "$src")"
        [[ "$src" == /* ]] || src="$dir/$src"
    done
    cd -P -- "$(dirname -- "$src")/.." && pwd
}

TOOLS_HOOKS_ROOT="$(resolve_bootstrap_root)"
# shellcheck source=scripts/lib/common.sh
source "$TOOLS_HOOKS_ROOT/scripts/lib/common.sh"

STRICT_MODE=0

show_help() {
    cat <<'EOF'
Uso:
  git-project-check [opciones]

Opciones:
  --strict    Exige tambien LICENSE y CHANGELOG.md ademas de VERSION.
  -h, --help  Muestra esta ayuda.

Valida la estructura del proyecto:
  - Obligatorio: VERSION (formato Semantic Versioning X.Y.Z).
  - Opcionales (se validan si existen): LICENSE, CHANGELOG.md, README.md,
    DESIGN.md, AGENTS.md, ARCHITECTURE.md, .editorconfig, .prettierrc,
    .gitignore, Dockerfile y .githooks/.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --strict)
            STRICT_MODE=1
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            die "Opcion desconocida: $1"
            ;;
    esac
done

require_git_repo

FAILED=0

validate_required_version() {
    if [[ ! -s VERSION ]]; then
        printf 'ERROR: Falta el archivo obligatorio: VERSION\n' >&2
        FAILED=1
        return
    fi

    local version_value
    version_value="$(tr -d '[:space:]' < VERSION)"

    if is_semver "$version_value"; then
        ok "VERSION ($version_value)"
    else
        printf 'ERROR: VERSION no utiliza el formato X.Y.Z: %s\n' "$version_value" >&2
        FAILED=1
    fi
}

validate_optional_license() {
    local license_file=""
    local candidate

    for candidate in LICENSE LICENSE.md LICENSE.txt; do
        if [[ -e "$candidate" ]]; then
            license_file="$candidate"
            break
        fi
    done

    if [[ -z "$license_file" ]]; then
        if [[ "$STRICT_MODE" -eq 1 ]]; then
            printf 'ERROR: Falta archivo de licencia (modo --strict).\n' >&2
            FAILED=1
        else
            info "OPCIONAL: No hay archivo de licencia."
        fi
        return
    fi

    if [[ ! -s "$license_file" ]]; then
        printf 'ERROR: El archivo de licencia esta vacio: %s\n' "$license_file" >&2
        FAILED=1
        return
    fi

    if grep -Fq 'MIT License' "$license_file"; then
        ok "$license_file (MIT)"
    else
        warn "$license_file encontrado, pero no parece ser MIT."
    fi
}

validate_optional_changelog() {
    if [[ ! -e CHANGELOG.md ]]; then
        if [[ "$STRICT_MODE" -eq 1 ]]; then
            printf 'ERROR: Falta CHANGELOG.md (modo --strict).\n' >&2
            FAILED=1
        else
            info "OPCIONAL: No existe CHANGELOG.md."
        fi
        return
    fi

    if [[ ! -s CHANGELOG.md ]]; then
        printf 'ERROR: CHANGELOG.md esta vacio.\n' >&2
        FAILED=1
        return
    fi

    local first_heading
    first_heading="$(grep -E '^#( |\[)|^## \[' CHANGELOG.md | head -n 1 | tr -d '\r' || true)"

    if ! grep -Eq '^# Changelog[[:space:]]*$' CHANGELOG.md; then
        printf 'ERROR: CHANGELOG.md no contiene el encabezado "# Changelog".\n' >&2
        FAILED=1
    elif [[ "$first_heading" != "# Changelog" ]]; then
        warn "CHANGELOG.md tiene '# Changelog' debajo de versiones existentes; conviene moverlo arriba."
    else
        ok "CHANGELOG.md"
    fi
}

validate_optional_file() {
    local file="$1"
    local check_stub="${2:-0}"

    if [[ ! -e "$file" ]]; then
        return
    fi

    if [[ ! -s "$file" ]]; then
        printf 'ERROR: El archivo opcional existe pero esta vacio: %s\n' "$file" >&2
        FAILED=1
        return
    fi

    if [[ "$check_stub" -eq 1 ]]; then
        local non_stub_lines
        non_stub_lines="$(grep -cvE '^(#.*|<!--.*-->|[[:space:]]*)$' "$file" || true)"
        if [[ "$non_stub_lines" -eq 0 ]]; then
            info "OK: $file (plantilla sin contenido aun)"
            return
        fi
    fi

    ok "$file"
}

validate_optional_hooks() {
    local hook
    for hook in .githooks/pre-commit .githooks/pre-push; do
        if [[ -f "$hook" ]]; then
            if bash -n "$hook"; then
                ok "$hook"
            else
                printf 'ERROR: Sintaxis invalida en %s\n' "$hook" >&2
                FAILED=1
            fi
        fi
    done
}

info "Validando estructura del proyecto..."
info ""

validate_required_version
validate_optional_license
validate_optional_changelog

validate_optional_file "README.md"
validate_optional_file "DESIGN.md" 1
validate_optional_file "AGENTS.md" 1
validate_optional_file "ARCHITECTURE.md" 1
validate_optional_file ".editorconfig"
validate_optional_file ".prettierrc"
validate_optional_file ".gitignore"
validate_optional_file "Dockerfile"
validate_optional_file ".dockerignore"
validate_optional_hooks

info ""

if [[ "$FAILED" -ne 0 ]]; then
    printf 'La validacion del proyecto fallo.\n' >&2
    exit 1
fi

info "Validacion completada correctamente."
