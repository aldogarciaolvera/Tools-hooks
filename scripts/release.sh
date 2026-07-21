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

SCRIPT_DIR="$(
    cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &&
    pwd
)"

PROJECT_CHECK="$SCRIPT_DIR/project-check.sh"

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

CHANGELOG_TMP="${REPO_ROOT}/.CHANGELOG.md.tools-hooks.$$"

cleanup() {
    rm -f -- "$CHANGELOG_TMP"
}

trap cleanup EXIT

{
    printf '## [%s] - %s\n\n' "$NEW_VERSION" "$DATE"
    printf '### Changed\n\n'
    printf -- '- Preparación de la versión %s.\n\n' "$NEW_VERSION"
    cat CHANGELOG.md
} > "$CHANGELOG_TMP"

mv -- "$CHANGELOG_TMP" CHANGELOG.md

git add VERSION CHANGELOG.md
git commit -m "chore: release $NEW_VERSION"

TAG="v$NEW_VERSION"
git tag -a "$TAG" -m "Release $TAG"

echo
read -r -p "¿Publicar rama y etiqueta en origin? [Y/n]: " ans
case "${ans:-Y}" in
    n|N|no|NO)
        printf '\n'
printf 'Release creada localmente.\n\n'
printf 'Commit:\n'
printf '  %s\n\n' "$(git rev-parse --short HEAD)"
printf 'Tag:\n'
printf '  %s\n\n' "$TAG"
printf 'Para publicarla más tarde ejecuta:\n\n'
printf '  git push origin %s\n' "$(git branch --show-current)"
printf '  git push origin %s\n' "$TAG"
        ;;
    *)
        git push origin "$CURRENT_BRANCH"
        git push origin "$TAG"
        echo "Release publicada correctamente."
        ;;
esac
