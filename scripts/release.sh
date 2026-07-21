#!/usr/bin/env bash

set -Eeuo pipefail

usage() {
    cat <<'EOF'
Uso:
  release.sh <version>

Ejemplo:
  release.sh 1.1.0
EOF
}

die() {
    echo "ERROR: $*" >&2
    exit 1
}

is_semver() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

if [[ $# -ne 1 ]]; then
    usage
    exit 1
fi

NEW_VERSION="$1"
TAG="v$NEW_VERSION"

is_semver "$NEW_VERSION" ||
    die "La versión debe usar el formato X.Y.Z, por ejemplo 1.1.0"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    die "Debes ejecutar este script dentro de un repositorio Git"

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

[[ -f VERSION ]] ||
    die "No existe el archivo VERSION"

[[ -f CHANGELOG.md ]] ||
    die "No existe el archivo CHANGELOG.md"

CURRENT_BRANCH="$(git symbolic-ref --quiet --short HEAD 2>/dev/null)" ||
    die "No se puede crear una release en detached HEAD"

if [[ -n "$(git status --porcelain)" ]]; then
    die "El repositorio tiene cambios sin confirmar"
fi

CURRENT_VERSION="$(tr -d '[:space:]' < VERSION)"

is_semver "$CURRENT_VERSION" ||
    die "La versión actual no es válida: $CURRENT_VERSION"

if [[ "$CURRENT_VERSION" == "$NEW_VERSION" ]]; then
    die "La versión $NEW_VERSION ya es la versión actual"
fi

if git rev-parse "$TAG" >/dev/null 2>&1; then
    die "La etiqueta $TAG ya existe"
fi

if git ls-remote --exit-code --tags origin "refs/tags/$TAG" \
    >/dev/null 2>&1; then
    die "La etiqueta $TAG ya existe en origin"
fi

echo
echo "Release:"
echo "  Repositorio: $REPO_ROOT"
echo "  Rama:        $CURRENT_BRANCH"
echo "  Actual:      $CURRENT_VERSION"
echo "  Nueva:       $NEW_VERSION"
echo "  Tag:         $TAG"
echo

read -r -p "¿Continuar? [y/N]: " CONFIRMATION

case "$CONFIRMATION" in
    y|Y|yes|YES|sí|SI|si)
        ;;
    *)
        echo "Release cancelada."
        exit 0
        ;;
esac

printf '%s\n' "$NEW_VERSION" > VERSION

RELEASE_DATE="$(date +'%Y-%m-%d')"
TEMP_CHANGELOG="$(mktemp)"

awk \
    -v version="$NEW_VERSION" \
    -v release_date="$RELEASE_DATE" '
    BEGIN {
        inserted = 0
    }

    /^## \[/ && inserted == 0 {
        print "## [" version "] - " release_date
        print ""
        print "### Changed"
        print ""
        print "- Preparación de la versión " version "."
        print ""
        inserted = 1
    }

    {
        print
    }

    END {
        if (inserted == 0) {
            print ""
            print "## [" version "] - " release_date
            print ""
            print "### Changed"
            print ""
            print "- Preparación de la versión " version "."
        }
    }
' CHANGELOG.md > "$TEMP_CHANGELOG"

mv "$TEMP_CHANGELOG" CHANGELOG.md

git add VERSION CHANGELOG.md

git commit -m "chore: release $TAG"
git tag -a "$TAG" -m "Release $TAG"

echo
echo "Release creada localmente:"
echo "  Commit: $(git rev-parse --short HEAD)"
echo "  Tag:    $TAG"
echo
echo "Para publicarla:"
echo
echo "  git push origin $CURRENT_BRANCH"
echo "  git push origin $TAG"
