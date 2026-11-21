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

INITIAL_VERSION="0.0.1"
LICENSE_MODE="ask"
TEMPLATE_NAME="blank"
TEMPLATE_EXPLICIT=0
MINIMAL_MODE=0
NON_INTERACTIVE=0
EXPLICIT_MODULES=0

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
  git-project-init [opciones]

Por defecto inicializa una plantilla en blanco minima:
  - VERSION (0.0.1, obligatorio siempre)
  - LICENSE (MIT, opcional o interactivo)
Todos los demas archivos, plantillas y skills son opcionales.

Opciones generales:
  -v, --version X.Y.Z   Version inicial. Por defecto: 0.0.1
  -t, --template TIPO   Plantilla (blank, react, astro, angular, reactnative, dotnet, python).
  --blank, --minimal    Solo VERSION y licencia (sin preguntas de extras).
  --license             Crea licencia MIT sin preguntar.
  --no-license          No crea archivo de licencia.
  -y, --yes             Modo no interactivo (sin preguntas).
  -h, --help            Muestra esta ayuda.

Modulos opcionales:
  --changelog           Crea CHANGELOG.md
  --readme              Crea README.md
  --docs                Crea DESIGN.md, AGENTS.md y ARCHITECTURE.md
  --design              Crea DESIGN.md
  --agents              Crea AGENTS.md
  --architecture        Crea ARCHITECTURE.md
  --editorconfig        Crea .editorconfig
  --prettier            Crea .prettierrc
  --gitignore           Crea o complementa .gitignore
  --docker              Crea Dockerfile y .dockerignore (requiere plantilla != blank)
  --hooks               Crea .githooks/pre-commit y .githooks/pre-push
  --skills              Ejecuta npx -y autoskills@latest (desactivado por defecto)
  --all                 Activa todos los archivos opcionales (excepto --skills)

Ejemplos:
  git-project-init --minimal --license        # Ideal para repo de skills o plantilla limpia
  git-project-init -v 0.1.0 --readme --license
  git-project-init -t react --gitignore --docker --all
  git-project-init --skills --readme
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -v|--version)
            [[ $# -ge 2 ]] || die "Debes indicar una version despues de $1"
            INITIAL_VERSION="$2"
            shift 2
            ;;
        -t|--template)
            [[ $# -ge 2 ]] || die "Debes indicar una tecnologia despues de $1"
            TEMPLATE_NAME="$(normalize_template_name "$2")"
            TEMPLATE_EXPLICIT=1
            shift 2
            ;;
        --blank|--minimal)
            TEMPLATE_NAME="blank"
            MINIMAL_MODE=1
            shift
            ;;
        --license)
            LICENSE_MODE="yes"
            shift
            ;;
        --no-license)
            LICENSE_MODE="no"
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

is_semver "$INITIAL_VERSION" ||
    die "La version debe tener el formato X.Y.Z (por ejemplo 0.0.1)"

validate_template_name "$TEMPLATE_NAME"
require_git_repo

prompt_template_selection() {
    local choice=""
    info ""
    info "Plantillas disponibles: $SUPPORTED_TEMPLATES"
    if ! IFS= read -r -p "Elige una plantilla [blank]: " choice; then
        choice=""
    fi
    choice="${choice:-blank}"
    choice="$(normalize_template_name "$choice")"
    validate_template_name "$choice"
    TEMPLATE_NAME="$choice"
}

prompt_optional_modules() {
    info ""
    if [[ "$TEMPLATE_EXPLICIT" -eq 0 ]]; then
        if ! ask_yes_no "Deseas agregar archivos, plantillas o skills opcionales? (No = plantilla en blanco: VERSION y licencia)" "N"; then
            return 0
        fi
        prompt_template_selection
    else
        if ! ask_yes_no "Deseas agregar archivos o skills opcionales adicionales (CHANGELOG, README, docs, Docker, hooks, skills)?" "N"; then
            return 0
        fi
    fi

    ask_yes_no "Agregar CHANGELOG.md?" "N" && OPT_CHANGELOG=1
    ask_yes_no "Agregar README.md?" "N" && OPT_README=1
    ask_yes_no "Agregar documentacion (DESIGN.md, AGENTS.md, ARCHITECTURE.md)?" "N" && {
        OPT_DESIGN=1
        OPT_AGENTS=1
        OPT_ARCHITECTURE=1
    }
    ask_yes_no "Agregar .editorconfig?" "N" && OPT_EDITORCONFIG=1
    ask_yes_no "Agregar .prettierrc?" "N" && OPT_PRETTIER=1
    ask_yes_no "Agregar o complementar .gitignore?" "N" && OPT_GITIGNORE=1
    ask_yes_no "Agregar hooks locales (.githooks/)?" "N" && OPT_HOOKS=1

    if [[ "$TEMPLATE_NAME" != "blank" ]]; then
        ask_yes_no "Agregar Dockerfile y .dockerignore para $TEMPLATE_NAME?" "N" && OPT_DOCKER=1
    fi

    ask_yes_no "Ejecutar autoskills (npx autoskills@latest)?" "N" && OPT_SKILLS=1
    return 0
}

info "Inicializando proyecto en:"
info "  $REPOSITORY_ROOT"
info ""

# 1. VERSION es obligatorio siempre.
create_version_file "$INITIAL_VERSION"

# 2. Licencia (por defecto en blanco incluye pregunta [Y/n] o creacion en --yes).
case "$LICENSE_MODE" in
    yes)
        create_mit_license_file
        ;;
    no)
        info "La licencia no fue creada."
        ;;
    ask)
        if [[ "$NON_INTERACTIVE" -eq 1 ]]; then
            create_mit_license_file
        elif ask_yes_no "Deseas agregar la licencia MIT?" "Y"; then
            create_mit_license_file
        else
            info "La licencia no fue creada."
        fi
        ;;
esac

# 3. Modulos y plantillas opcionales.
if [[ "$MINIMAL_MODE" -eq 0 && "$EXPLICIT_MODULES" -eq 0 && "$NON_INTERACTIVE" -eq 0 ]]; then
    prompt_optional_modules
fi

if [[ "$TEMPLATE_NAME" != "blank" ]]; then
    install_project_template "$TEMPLATE_NAME"
fi

[[ "$OPT_GITIGNORE" -eq 1 ]] && create_gitignore_file "$TEMPLATE_NAME"
if [[ "$OPT_DOCKER" -eq 1 && "$TEMPLATE_NAME" != "blank" ]]; then
    create_docker_files "$TEMPLATE_NAME"
elif [[ "$OPT_DOCKER" -eq 1 && "$TEMPLATE_NAME" == "blank" && "$EXPLICIT_MODULES" -eq 1 ]]; then
    warn "Se omitio --docker porque la plantilla es 'blank'."
fi
[[ "$OPT_EDITORCONFIG" -eq 1 ]] && create_editorconfig_file
[[ "$OPT_PRETTIER" -eq 1 ]] && create_prettierrc_file
[[ "$OPT_CHANGELOG" -eq 1 ]] && create_changelog_file "$INITIAL_VERSION"
[[ "$OPT_README" -eq 1 ]] && create_readme_file
[[ "$OPT_DESIGN" -eq 1 ]] && create_design_file
[[ "$OPT_AGENTS" -eq 1 ]] && create_agents_file
[[ "$OPT_ARCHITECTURE" -eq 1 ]] && create_architecture_file "$TEMPLATE_NAME"
[[ "$OPT_HOOKS" -eq 1 ]] && create_githooks_files
[[ "$OPT_SKILLS" -eq 1 ]] && run_autoskills

info ""
info "Validando resultado..."
info ""

bash "$PROJECT_CHECK"

info ""
info "Proyecto inicializado correctamente."
