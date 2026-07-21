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

git diff --quiet || die "Hay cambios sin confirmar."

CURRENT_BRANCH="$(git branch --show-current)"
CURRENT_VERSION="$(tr -d '[:space:]' < VERSION)"

[[ "$CURRENT_VERSION" != "$NEW_VERSION" ]] || die "La versión ya es $NEW_VERSION"

printf '%s\n' "$NEW_VERSION" > VERSION

DATE="$(date +%F)"
TMP="$(mktemp)"
{
echo "## [$NEW_VERSION] - $DATE"
echo
echo "### Changed"
echo
echo "- Preparación de la versión $NEW_VERSION."
echo
cat CHANGELOG.md
} > "$TMP"
mv "$TMP" CHANGELOG.md

git add VERSION CHANGELOG.md
git commit -m "chore: release $NEW_VERSION"

TAG="v$NEW_VERSION"
git tag -a "$TAG" -m "Release $TAG"

echo
read -r -p "¿Publicar rama y etiqueta en origin? [Y/n]: " ans
case "${ans:-Y}" in
    n|N|no|NO)
        echo "Release creada localmente."
        ;;
    *)
        git push origin "$CURRENT_BRANCH"
        git push origin "$TAG"
        echo "Release publicada correctamente."
        ;;
esac
