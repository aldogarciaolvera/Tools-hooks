#!/usr/bin/env bash
set -Eeuo pipefail

die(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }

usage(){
cat <<EOF
Uso:
  git-release <version>
EOF
}

[[ $# -eq 1 ]] || { usage; exit 1; }

NEW_VERSION="$1"

TOOLS_HOOKS_ROOT="$(git config --global --get tools-hooks.root || true)"

if [[ -z "$TOOLS_HOOKS_ROOT" ]]; then
    die "tools-hooks.root no está configurado. Ejecuta ./install.sh"
fi

PROJECT_CHECK="$TOOLS_HOOKS_ROOT/scripts/project-check.sh"

[[ -f "$PROJECT_CHECK" ]] ||
    die "No se encontró project-check.sh en: $PROJECT_CHECK"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    die "No estás dentro de un repositorio Git"

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

bash "$PROJECT_CHECK"

[[ -z "$(git status --porcelain)" ]] ||
    die "Hay cambios sin confirmar."

is_semver() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

is_semver "$NEW_VERSION" ||
    die "La versión debe usar el formato X.Y.Z, por ejemplo 1.2.0"
TAG="v$NEW_VERSION"

git rev-parse --verify --quiet "refs/tags/$TAG" >/dev/null &&
    die "La etiqueta $TAG ya existe."
CURRENT_BRANCH="$(git branch --show-current)"
CURRENT_VERSION="$(tr -d '[:space:]' < VERSION)"

[[ "$CURRENT_VERSION" != "$NEW_VERSION" ]] || die "La versión ya es $NEW_VERSION"

printf '%s\n' "$NEW_VERSION" > VERSION

DATE="$(date +%F)"

CHANGELOG_TMP="$(mktemp "${REPO_ROOT}/.CHANGELOG.md.XXXXXX")"

cleanup() {
    rm -f -- "$CHANGELOG_TMP"
}

trap cleanup EXIT

LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")

if [[ -z "$LATEST_TAG" ]]; then
    COMMITS=$(git log --pretty=format:"%s")
else
    COMMITS=$(git log ${LATEST_TAG}..HEAD --pretty=format:"%s")
fi

get_commits_by_type() {
    local type="$1"
    echo "$COMMITS" | grep -iE "(^| - )${type}(\([^)]*\))?:" | sed -E "s/.* - (${type}(\([^)]*\))?:)/\1/i" || true
}

FEATURES=$(get_commits_by_type "feat")
FIXES=$(get_commits_by_type "fix")
DOCS=$(get_commits_by_type "docs")
REFACTOR=$(get_commits_by_type "refactor")
PERF=$(get_commits_by_type "perf")

write_section() {
    local title="$1"
    local items="$2"
    if [[ -n "$items" ]]; then
        printf '### %s\n\n' "$title"
        while IFS= read -r line; do
            [[ -n "$line" ]] && printf -- '- %s\n' "$line"
        done <<< "$items"
        printf '\n'
    fi
}

{
    printf '## [%s] - %s\n\n' "$NEW_VERSION" "$DATE"
    
    write_section "Features" "$FEATURES"
    write_section "Bug Fixes" "$FIXES"
    write_section "Performance" "$PERF"
    write_section "Refactoring" "$REFACTOR"
    write_section "Documentation" "$DOCS"
    
    if [[ -z "$FEATURES" && -z "$FIXES" && -z "$PERF" && -z "$REFACTOR" && -z "$DOCS" ]]; then
        printf '### Changed\n\n'
        printf -- '- Preparación de la versión %s.\n\n' "$NEW_VERSION"
    fi
    
    cat CHANGELOG.md
} > "$CHANGELOG_TMP"

mv -- "$CHANGELOG_TMP" CHANGELOG.md

git add VERSION CHANGELOG.md
git commit -m "mnto: release $NEW_VERSION"

TAG="v$NEW_VERSION"
git tag -a "$TAG" -m "Release $TAG"

REMOTE="$(git config "branch.${CURRENT_BRANCH}.remote" || echo "origin")"

echo
read -r -p "¿Publicar rama y etiqueta en $REMOTE? [Y/n]: " ans
case "${ans:-Y}" in
    n|N|no|NO)
        printf '\n'
printf 'Release creada localmente.\n\n'
printf 'Commit:\n'
printf '  %s\n\n' "$(git rev-parse --short HEAD)"
printf 'Tag:\n'
printf '  %s\n\n' "$TAG"
printf 'Para publicarla más tarde ejecuta:\n\n'
printf '  git push %s %s\n' "$REMOTE" "$CURRENT_BRANCH"
printf '  git push %s %s\n' "$REMOTE" "$TAG"
        ;;
    *)
        git push "$REMOTE" "$CURRENT_BRANCH"
        git push "$REMOTE" "$TAG"
        echo "Release publicada correctamente."
        ;;
esac
