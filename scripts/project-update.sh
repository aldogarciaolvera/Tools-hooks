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
# shellcheck source=scripts/lib/generators.sh
source "$TOOLS_HOOKS_ROOT/scripts/lib/generators.sh"

PROJECT_CHECK="$TOOLS_HOOKS_ROOT/scripts/project-check.sh"
[[ -f "$PROJECT_CHECK" ]] ||
    die "No se encontro project-check.sh en: $PROJECT_CHECK"

TEMPLATE_NAME="blank"
NON_INTERACTIVE=0
EXPLICIT_MODULES=0
OPT_ALL=0

OPT_LICENSE=0
OPT_CHANGELOG=0
OPT_README=0
OPT_DESIGN=0
OPT_AGENTS=0
OPT_ARCHITECTURE=0
OPT_EDITORCONFIG=0
OPT_PRETTIER=0
OPT_GITIGNORE=0
OPT_DOCKER=0
OPT_HOOKS=0
OPT_SKILLS=0

show_help() {
    cat <<'EOF'
Uso:
  git-project-update [opciones]

Inspecciona el estado actual del repositorio, garantiza VERSION (si falta)
y permite agregar de forma selectiva los archivos opcionales faltantes
sin sobrescribir archivos existentes.

Opciones:
  -t, --template TIPO   Plantilla para ARCHITECTURE.md/.gitignore/Docker (blank, react, astro, angular, reactnative, dotnet, python).
  --license             Agrega LICENSE (MIT) si falta.
  --changelog           Agrega CHANGELOG.md si falta.
  --readme              Agrega README.md si falta.
  --docs                Agrega DESIGN.md, AGENTS.md y ARCHITECTURE.md si faltan.
  --design              Agrega DESIGN.md si falta.
  --agents              Agrega AGENTS.md si falta.
  --architecture        Agrega ARCHITECTURE.md si falta.
  --editorconfig        Agrega .editorconfig si falta.
  --prettier            Agrega .prettierrc si falta.
  --gitignore           Agrega o complementa .gitignore.
  --docker              Agrega Dockerfile y .dockerignore (requiere -t != blank).
  --hooks               Agrega .githooks/pre-commit y .githooks/pre-push si faltan.
  --skills              Ejecuta npx -y autoskills@latest.
  --all                 Agrega todos los archivos opcionales faltantes (excepto --skills).
  -y, --yes             Modo no interactivo (solo valida o aplica flags indicadas).
  -h, --help            Muestra esta ayuda.
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -t|--template)
            [[ $# -ge 2 ]] || die "Debes indicar una tecnologia despues de $1"
            TEMPLATE_NAME="$(normalize_template_name "$2")"
            shift 2
            ;;
        --license)
            OPT_LICENSE=1
            EXPLICIT_MODULES=1
            shift
            ;;
        --changelog)
            OPT_CHANGELOG=1
            EXPLICIT_MODULES=1
            shift
            ;;
        --readme)
            OPT_README=1
            EXPLICIT_MODULES=1
            shift
            ;;
        --docs)
            OPT_DESIGN=1
            OPT_AGENTS=1
            OPT_ARCHITECTURE=1
            EXPLICIT_MODULES=1
            shift
            ;;
        --design)
            OPT_DESIGN=1
            EXPLICIT_MODULES=1
            shift
            ;;
        --agents)
            OPT_AGENTS=1
            EXPLICIT_MODULES=1
            shift
            ;;
        --architecture)
            OPT_ARCHITECTURE=1
            EXPLICIT_MODULES=1
            shift
            ;;
        --editorconfig)
            OPT_EDITORCONFIG=1
            EXPLICIT_MODULES=1
            shift
            ;;
        --prettier)
            OPT_PRETTIER=1
            EXPLICIT_MODULES=1
            shift
            ;;
        --gitignore)
            OPT_GITIGNORE=1
            EXPLICIT_MODULES=1
            shift
            ;;
        --docker)
            OPT_DOCKER=1
            EXPLICIT_MODULES=1
            shift
            ;;
        --hooks)
            OPT_HOOKS=1
            EXPLICIT_MODULES=1
            shift
            ;;
        --skills|--autoskills)
            OPT_SKILLS=1
            EXPLICIT_MODULES=1
            shift
            ;;
        --all)
            OPT_ALL=1
            OPT_LICENSE=1
            OPT_CHANGELOG=1
            OPT_README=1
            OPT_DESIGN=1
            OPT_AGENTS=1
            OPT_ARCHITECTURE=1
            OPT_EDITORCONFIG=1
            OPT_PRETTIER=1
            OPT_GITIGNORE=1
            OPT_HOOKS=1
            OPT_DOCKER=1
            EXPLICIT_MODULES=1
            shift
            ;;
        -y|--yes|--no-interactive)
            NON_INTERACTIVE=1
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

validate_template_name "$TEMPLATE_NAME"
require_git_repo

project_name="$(basename "$REPOSITORY_ROOT")"
info "Validando proyecto: $project_name"
info ""

# 1. Diagnostico actual del repositorio.
MISSING_OPTIONAL=0

report_status() {
    local label="$1"
    local path="$2"
    if [[ -s "$path" ]]; then
        printf '  [OK]       %s\n' "$label"
    elif [[ -e "$path" ]]; then
        printf '  [VACIO]    %s\n' "$label"
    else
        printf '  [FALTA]    %s (opcional)\n' "$label"
        MISSING_OPTIONAL=1
    fi
}

if [[ -s VERSION ]]; then
    ver="$(tr -d '[:space:]' < VERSION)"
    if is_semver "$ver"; then
        printf '  [OK]       VERSION (%s)\n' "$ver"
    else
        printf '  [INVALIDO] VERSION (%s - requiere X.Y.Z)\n' "$ver"
    fi
else
    printf '  [FALTA]    VERSION (obligatorio)\n'
fi

if lic="$(find_license_file)"; then
    printf '  [OK]       %s\n' "$lic"
else
    printf '  [FALTA]    LICENSE (opcional)\n'
    MISSING_OPTIONAL=1
fi

report_status "CHANGELOG.md" "CHANGELOG.md"
report_status "README.md" "README.md"
report_status "DESIGN.md" "DESIGN.md"
report_status "AGENTS.md" "AGENTS.md"
report_status "ARCHITECTURE.md" "ARCHITECTURE.md"
report_status ".editorconfig" ".editorconfig"
report_status ".prettierrc" ".prettierrc"
report_status ".gitignore" ".gitignore"
report_status ".githooks/pre-commit" ".githooks/pre-commit"
report_status ".githooks/pre-push" ".githooks/pre-push"
if [[ "$TEMPLATE_NAME" != "blank" ]]; then
    report_status "Dockerfile" "Dockerfile"
    report_status ".dockerignore" ".dockerignore"
fi

info ""

# 2. Garantizar VERSION si no existe (sin tocar si ya existe).
if [[ ! -e VERSION ]]; then
    create_version_file "0.0.1"
fi

CURRENT_VERSION="0.0.1"
if [[ -s VERSION ]]; then
    CURRENT_VERSION="$(tr -d '[:space:]' < VERSION)"
fi

# 3. Agregar archivos opcionales faltantes.
if [[ "$EXPLICIT_MODULES" -eq 1 ]]; then
    [[ "$OPT_LICENSE" -eq 1 ]] && create_mit_license_file
    [[ "$OPT_CHANGELOG" -eq 1 ]] && create_changelog_file "$CURRENT_VERSION"
    [[ "$OPT_README" -eq 1 ]] && create_readme_file
    [[ "$OPT_DESIGN" -eq 1 ]] && create_design_file
    [[ "$OPT_AGENTS" -eq 1 ]] && create_agents_file
    [[ "$OPT_ARCHITECTURE" -eq 1 ]] && create_architecture_file "$TEMPLATE_NAME"
    [[ "$OPT_EDITORCONFIG" -eq 1 ]] && create_editorconfig_file
    [[ "$OPT_PRETTIER" -eq 1 ]] && create_prettierrc_file
    [[ "$OPT_GITIGNORE" -eq 1 ]] && create_gitignore_file "$TEMPLATE_NAME"
    [[ "$OPT_HOOKS" -eq 1 ]] && create_githooks_files
    if [[ "$OPT_DOCKER" -eq 1 && "$TEMPLATE_NAME" != "blank" ]]; then
        create_docker_files "$TEMPLATE_NAME"
    elif [[ "$OPT_DOCKER" -eq 1 && "$OPT_ALL" -eq 0 ]]; then
        warn "Se omitio --docker porque no indicaste una plantilla (-t distinto de blank)."
    fi
    [[ "$OPT_SKILLS" -eq 1 ]] && run_autoskills
elif [[ "$NON_INTERACTIVE" -eq 0 && "$MISSING_OPTIONAL" -eq 1 ]]; then
    if ask_yes_no "Deseas agregar alguno de los archivos opcionales faltantes?" "N"; then
        if ! find_license_file >/dev/null; then
            ask_yes_no "Agregar LICENSE (MIT)?" "N" && create_mit_license_file
        fi
        [[ ! -e CHANGELOG.md ]] && ask_yes_no "Agregar CHANGELOG.md?" "N" && create_changelog_file "$CURRENT_VERSION"
        [[ ! -e README.md ]] && ask_yes_no "Agregar README.md?" "N" && create_readme_file
        [[ ! -e DESIGN.md ]] && ask_yes_no "Agregar DESIGN.md?" "N" && create_design_file
        [[ ! -e AGENTS.md ]] && ask_yes_no "Agregar AGENTS.md?" "N" && create_agents_file
        [[ ! -e ARCHITECTURE.md ]] && ask_yes_no "Agregar ARCHITECTURE.md?" "N" && create_architecture_file "$TEMPLATE_NAME"
        [[ ! -e .editorconfig ]] && ask_yes_no "Agregar .editorconfig?" "N" && create_editorconfig_file
        [[ ! -e .prettierrc ]] && ask_yes_no "Agregar .prettierrc?" "N" && create_prettierrc_file
        [[ ! -e .gitignore ]] && ask_yes_no "Agregar .gitignore?" "N" && create_gitignore_file "$TEMPLATE_NAME"
        if [[ ! -e .githooks/pre-commit || ! -e .githooks/pre-push ]]; then
            ask_yes_no "Agregar hooks locales (.githooks/)?" "N" && create_githooks_files
        fi
        if [[ "$TEMPLATE_NAME" != "blank" && ! -e Dockerfile ]]; then
            ask_yes_no "Agregar Dockerfile y .dockerignore para $TEMPLATE_NAME?" "N" && create_docker_files "$TEMPLATE_NAME"
        fi
        ask_yes_no "Ejecutar autoskills (npx autoskills@latest)?" "N" && run_autoskills
    fi
elif [[ "$MISSING_OPTIONAL" -eq 0 ]]; then
    info "El proyecto ya cuenta con todos los archivos revisados."
fi

info ""
bash "$PROJECT_CHECK"
