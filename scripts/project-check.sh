#!/usr/bin/env bash

set -Eeuo pipefail

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

is_semver() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    die "Debes ejecutar este comando dentro de un repositorio Git"

REPOSITORY_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPOSITORY_ROOT"

FAILED=0

validate_file() {
    local file="$1"

    if [[ ! -s "$file" ]]; then
        printf 'ERROR: Falta el archivo requerido: %s\n' "$file" >&2
        FAILED=1
    else
        printf 'OK: %s\n' "$file"
    fi
}

validate_license() {
    local license_file=""

    for candidate in LICENSE LICENSE.md LICENSE.txt; do
        if [[ -s "$candidate" ]]; then
            license_file="$candidate"
            break
        fi
    done

    if [[ -n "$license_file" ]]; then
        printf 'OK: Archivo de licencia encontrado: %s\n' "$license_file"

        if grep -Fq 'MIT License' "$license_file"; then
            printf 'OK: Se detectó una licencia MIT.\n'
        else
            printf 'AVISO: La licencia no parece ser MIT.\n'
        fi
    else
        printf 'AVISO: El proyecto no contiene un archivo de licencia.\n'
    fi
}

printf 'Validando archivos del proyecto...\n\n'

validate_file "VERSION"
validate_file "CHANGELOG.md"
validate_license

if [[ -s VERSION ]]; then
    VERSION_VALUE="$(tr -d '[:space:]' < VERSION)"

    if is_semver "$VERSION_VALUE"; then
        printf 'OK: VERSION contiene una versión válida: %s\n' \
            "$VERSION_VALUE"
    else
        printf 'ERROR: VERSION no utiliza el formato X.Y.Z: %s\n' \
            "$VERSION_VALUE" >&2
        FAILED=1
    fi
fi

if [[ -s CHANGELOG.md ]]; then
    if grep -Fq '# Changelog' CHANGELOG.md; then
        printf 'OK: CHANGELOG.md tiene un encabezado válido.\n'
    else
        printf 'ERROR: CHANGELOG.md no contiene "# Changelog".\n' >&2
        FAILED=1
    fi
fi

printf '\n'

if [[ "$FAILED" -ne 0 ]]; then
    printf 'La validación del proyecto falló.\n' >&2
    exit 1
fi

printf 'Validación completada correctamente.\n'
