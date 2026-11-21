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

PROJECT_CHECK="$TOOLS_HOOKS_ROOT/scripts/project-check.sh"
[[ -f "$PROJECT_CHECK" ]] ||
    die "No se encontro project-check.sh en: $PROJECT_CHECK"

NEW_VERSION=""
CREATE_CHANGELOG=0
SKIP_CHANGELOG=0
PUSH_MODE="ask"

show_help() {
    cat <<'EOF'
Uso:
  git-release [opciones] <version>

Opciones:
  --changelog      Crea CHANGELOG.md si no existe antes de actualizarlo.
  --no-changelog   Omite la actualizacion de CHANGELOG.md (solo VERSION y tag).
  --push           Publica rama y tag sin preguntar.
  --no-push        Mantiene commit y tag unicamente en local.
  -h, --help       Muestra esta ayuda.

Ejemplo:
  git-release 1.2.0
  git-release --no-push 0.1.0
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --changelog)
            CREATE_CHANGELOG=1
            shift
            ;;
        --no-changelog)
            SKIP_CHANGELOG=1
            shift
            ;;
        --push)
            PUSH_MODE="yes"
            shift
            ;;
        --no-push)
            PUSH_MODE="no"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        -*)
            die "Opcion desconocida: $1"
            ;;
        *)
            [[ -z "$NEW_VERSION" ]] || die "Solo debes indicar una version."
            NEW_VERSION="$1"
            shift
            ;;
    esac
done

[[ -n "$NEW_VERSION" ]] || {
    show_help
    exit 1
}

is_semver "$NEW_VERSION" ||
    die "La version debe usar el formato X.Y.Z, por ejemplo 1.2.0"

require_git_repo

CURRENT_BRANCH="$(git branch --show-current)"
[[ -n "$CURRENT_BRANCH" ]] ||
    die "No puedes crear una release en estado detached HEAD. Cambia a una rama primero."

bash "$PROJECT_CHECK"

[[ -z "$(git status --porcelain)" ]] ||
    die "Hay cambios sin confirmar."

TAG="v$NEW_VERSION"
git rev-parse --verify --quiet "refs/tags/$TAG" >/dev/null &&
    die "La etiqueta $TAG ya existe."

CURRENT_VERSION="$(tr -d '[:space:]' < VERSION)"
[[ "$CURRENT_VERSION" != "$NEW_VERSION" ]] ||
    die "La version ya es $NEW_VERSION"

printf '%s\n' "$NEW_VERSION" > VERSION

CHANGELOG_UPDATED=0
CHANGELOG_TMP=""

cleanup() {
    if [[ -n "$CHANGELOG_TMP" ]]; then
        rm -f -- "$CHANGELOG_TMP"
    fi
}
trap cleanup EXIT

extract_commits_by_type() {
    local target_type="$1"
    local commits_text="$2"

    printf '%s\n' "$commits_text" | awk -v target="$target_type" '
    {
        line = $0
        sub(/^\[[A-Za-z0-9_-]+\] - [^ ]+ - /, "", line)
        low = tolower(line)
        pat = "^" tolower(target) "(\\([^)]*\\))?!?:[[:space:]]*"
        if (low ~ pat) {
            rest = line
            sub(/^[^:(]+/, "", rest)
            scope = ""
            breaking = ""
            if (rest ~ /^\(/) {
                match(rest, /^\([^)]*\)/)
                scope = substr(rest, RSTART + 1, RLENGTH - 2)
                rest = substr(rest, RLENGTH + 1)
            }
            if (rest ~ /^!/) {
                breaking = "[BREAKING] "
                sub(/^!/, "", rest)
            }
            sub(/^:[[:space:]]*/, "", rest)
            if (scope != "") {
                printf "- %s**%s:** %s\n", breaking, scope, rest
            } else {
                printf "- %s%s\n", breaking, rest
            }
        }
    }'
}

write_section() {
    local title="$1"
    local items="$2"
    if [[ -n "$items" ]]; then
        printf '### %s\n\n%s\n\n' "$title" "$items"
    fi
}

build_release_entry() {
    local date_str="$1"
    local latest_tag
    local commits_text

    latest_tag="$(git describe --tags --abbrev=0 2>/dev/null || true)"
    if [[ -z "$latest_tag" ]]; then
        commits_text="$(git log --pretty=format:"%s")"
    else
        commits_text="$(git log "${latest_tag}..HEAD" --pretty=format:"%s")"
    fi

    local features fixes docs refactor perf
    features="$(extract_commits_by_type "feat" "$commits_text")"
    fixes="$(extract_commits_by_type "fix" "$commits_text")"
    perf="$(extract_commits_by_type "perf" "$commits_text")"
    refactor="$(extract_commits_by_type "refactor" "$commits_text")"
    docs="$(extract_commits_by_type "docs" "$commits_text")"

    printf '## [%s] - %s\n\n' "$NEW_VERSION" "$date_str"
    write_section "Features" "$features"
    write_section "Bug Fixes" "$fixes"
    write_section "Performance" "$perf"
    write_section "Refactoring" "$refactor"
    write_section "Documentation" "$docs"

    if [[ -z "$features" && -z "$fixes" && -z "$perf" && -z "$refactor" && -z "$docs" ]]; then
        printf '### Changed\n\n- Preparacion de la version %s.\n\n' "$NEW_VERSION"
    fi
}

if [[ "$SKIP_CHANGELOG" -eq 0 && ( -e CHANGELOG.md || "$CREATE_CHANGELOG" -eq 1 ) ]]; then
    DATE="$(date +%F)"

    if [[ ! -e CHANGELOG.md ]]; then
        cat > CHANGELOG.md <<'EOF'
# Changelog

Todos los cambios relevantes de este proyecto se documentaran en este archivo.

El formato esta basado en Keep a Changelog y el proyecto utiliza Semantic Versioning.
EOF
    fi

    CHANGELOG_TMP="$(mktemp "${REPOSITORY_ROOT}/.CHANGELOG.md.XXXXXX")"
    RELEASE_ENTRY="$(build_release_entry "$DATE")"
    export RELEASE_ENTRY

    # Inserta la nueva version despues del encabezado "# Changelog" (antes del primer "## [").
    awk '
        BEGIN { inserted = 0; entry = ENVIRON["RELEASE_ENTRY"] }
        /^## \[/ && !inserted {
            printf "%s\n\n", entry
            inserted = 1
        }
        {
            sub(/\r$/, "")
            print
        }
        END {
            if (!inserted) {
                printf "\n%s\n", entry
            }
        }
    ' CHANGELOG.md > "$CHANGELOG_TMP"

    mv -- "$CHANGELOG_TMP" CHANGELOG.md
    CHANGELOG_TMP=""
    CHANGELOG_UPDATED=1
fi

if [[ "$CHANGELOG_UPDATED" -eq 1 ]]; then
    git add VERSION CHANGELOG.md
else
    git add VERSION
    info "CHANGELOG.md omitido; solo se actualizo VERSION."
fi

git commit -m "mnto: release $NEW_VERSION"
git tag -a "$TAG" -m "Release $TAG"

REMOTE="$(git config "branch.${CURRENT_BRANCH}.remote" 2>/dev/null || echo "origin")"

print_local_release_summary() {
    info ""
    info "Release creada localmente."
    info ""
    info "Commit: $(git rev-parse --short HEAD)"
    info "Tag:    $TAG"
    info ""
    info "Para publicarla mas tarde ejecuta:"
    info "  git push $REMOTE $CURRENT_BRANCH"
    info "  git push $REMOTE $TAG"
}

if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then
    warn "No existe el remoto '$REMOTE'. Se omitio la publicacion."
    print_local_release_summary
    exit 0
fi

case "$PUSH_MODE" in
    no)
        print_local_release_summary
        ;;
    yes)
        git push "$REMOTE" "$CURRENT_BRANCH"
        git push "$REMOTE" "$TAG"
        info "Release publicada correctamente."
        ;;
    ask)
        info ""
        if ask_yes_no "Publicar rama '$CURRENT_BRANCH' y etiqueta '$TAG' en '$REMOTE'?" "Y"; then
            git push "$REMOTE" "$CURRENT_BRANCH"
            git push "$REMOTE" "$TAG"
            info "Release publicada correctamente."
        else
            print_local_release_summary
        fi
        ;;
esac
