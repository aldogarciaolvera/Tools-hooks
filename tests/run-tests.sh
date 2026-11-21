#!/usr/bin/env bash

set -Eeuo pipefail

REPO_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS_DIR="$REPO_ROOT/scripts"
HOOKS_DIR="$REPO_ROOT/git-hooks"

TMP_ROOT="$(mktemp -d)"
cleanup() {
    rm -rf -- "$TMP_ROOT"
}
trap cleanup EXIT

TESTS_PASSED=0
TESTS_FAILED=0

assert_eq() {
    local expected="$1"
    local actual="$2"
    local msg="$3"
    if [[ "$expected" != "$actual" ]]; then
        printf 'FAIL: %s (esperado="%s", actual="%s")\n' "$msg" "$expected" "$actual" >&2
        return 1
    fi
}

assert_file_exists() {
    local path="$1"
    [[ -f "$path" ]] || {
        printf 'FAIL: Se esperaba archivo: %s\n' "$path" >&2
        return 1
    }
}

assert_file_missing() {
    local path="$1"
    [[ ! -e "$path" ]] || {
        printf 'FAIL: No deberia existir: %s\n' "$path" >&2
        return 1
    }
}

run_test() {
    local name="$1"
    shift
    if ( set -Eeuo pipefail; "$@" ); then
        printf 'PASS: %s\n' "$name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        printf 'FAIL: %s\n' "$name" >&2
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

new_sandbox_repo() {
    local name="$1"
    local dir="$TMP_ROOT/$name"
    mkdir -p "$dir"
    git -C "$dir" init -q -b main
    git -C "$dir" config user.name "Aldo Garcia"
    git -C "$dir" config user.email "aldo@example.com"
    git -C "$dir" config core.hooksPath "$HOOKS_DIR"
    printf '%s\n' "$dir"
}

test_syntax_all_scripts() {
    bash -n \
        "$REPO_ROOT/install.sh" \
        "$SCRIPTS_DIR"/*.sh \
        "$SCRIPTS_DIR/lib"/*.sh \
        "$HOOKS_DIR"/* \
        "$REPO_ROOT/tests/run-tests.sh"
}

test_init_minimal_blank() {
    local repo
    repo="$(new_sandbox_repo "init-minimal")"

    (
        cd "$repo"
        bash "$SCRIPTS_DIR/project-init.sh" --minimal --license
    ) >/dev/null

    assert_file_exists "$repo/VERSION"
    assert_eq "0.0.1" "$(tr -d '[:space:]' < "$repo/VERSION")" "VERSION inicial"
    assert_file_exists "$repo/LICENSE"
    assert_file_missing "$repo/CHANGELOG.md"
    assert_file_missing "$repo/README.md"
    assert_file_missing "$repo/DESIGN.md"
    assert_file_missing "$repo/AGENTS.md"
    assert_file_missing "$repo/ARCHITECTURE.md"
    assert_file_missing "$repo/.prettierrc"
    assert_file_missing "$repo/.editorconfig"
    assert_file_missing "$repo/.githooks"
}

test_init_interactive_default_blank() {
    local repo
    repo="$(new_sandbox_repo "init-interactive-blank")"

    (
        cd "$repo"
        printf '\n\n' | bash "$SCRIPTS_DIR/project-init.sh"
    ) >/dev/null

    assert_file_exists "$repo/VERSION"
    assert_file_exists "$repo/LICENSE"
    assert_file_missing "$repo/README.md"
    assert_file_missing "$repo/CHANGELOG.md"
}

test_init_modular_flags() {
    local repo
    repo="$(new_sandbox_repo "init-modular")"

    (
        cd "$repo"
        bash "$SCRIPTS_DIR/project-init.sh" -v 0.2.0 --no-license --readme --changelog --editorconfig --yes
    ) >/dev/null

    assert_file_exists "$repo/VERSION"
    assert_eq "0.2.0" "$(tr -d '[:space:]' < "$repo/VERSION")" "VERSION custom"
    assert_file_missing "$repo/LICENSE"
    assert_file_exists "$repo/README.md"
    assert_file_exists "$repo/CHANGELOG.md"
    assert_file_exists "$repo/.editorconfig"
    assert_file_missing "$repo/.prettierrc"
    assert_file_missing "$repo/DESIGN.md"
}

test_check_minimal_and_strict() {
    local repo
    repo="$(new_sandbox_repo "check-modes")"
    printf '0.0.1\n' > "$repo/VERSION"

    (cd "$repo" && bash "$SCRIPTS_DIR/project-check.sh" >/dev/null)

    if (cd "$repo" && bash "$SCRIPTS_DIR/project-check.sh" --strict >/dev/null 2>&1); then
        printf 'FAIL: --strict debio fallar sin LICENSE ni CHANGELOG.md\n' >&2
        return 1
    fi

    printf 'bad\n' > "$repo/VERSION"
    if (cd "$repo" && bash "$SCRIPTS_DIR/project-check.sh" >/dev/null 2>&1); then
        printf 'FAIL: VERSION invalido debio fallar\n' >&2
        return 1
    fi
}

test_update_validates_and_adds_selected() {
    local repo
    repo="$(new_sandbox_repo "update-selective")"
    printf '1.2.3\n' > "$repo/VERSION"
    printf '# Mi README\n' > "$repo/README.md"

    (
        cd "$repo"
        bash "$SCRIPTS_DIR/project-update.sh" --changelog --readme --editorconfig
    ) >/dev/null

    assert_eq "1.2.3" "$(tr -d '[:space:]' < "$repo/VERSION")" "update conserva VERSION"
    assert_eq "# Mi README" "$(head -n 1 "$repo/README.md")" "update conserva README"
    assert_file_exists "$repo/CHANGELOG.md"
    assert_file_exists "$repo/.editorconfig"
    assert_file_missing "$repo/DESIGN.md"
    assert_file_missing "$repo/.prettierrc"
}

test_release_minimal_without_changelog() {
    local repo
    repo="$(new_sandbox_repo "release-minimal")"

    (
        cd "$repo"
        bash "$SCRIPTS_DIR/project-init.sh" --minimal --license >/dev/null
        printf '# Skill\n' > SKILL.md
        git add VERSION LICENSE SKILL.md
        git commit -q -m "feat: skill inicial"
        bash "$SCRIPTS_DIR/release.sh" --no-push 0.1.0 >/dev/null
    )

    assert_eq "0.1.0" "$(tr -d '[:space:]' < "$repo/VERSION")" "VERSION actualizado"
    assert_file_missing "$repo/CHANGELOG.md"
    git -C "$repo" rev-parse --verify --quiet refs/tags/v0.1.0 >/dev/null
}

test_release_changelog_header_and_grouping() {
    local repo
    repo="$(new_sandbox_repo "release-changelog")"

    (
        cd "$repo"
        bash "$SCRIPTS_DIR/project-init.sh" --minimal --license --changelog >/dev/null
        git add VERSION LICENSE CHANGELOG.md
        git commit -q -m "feat(core): base inicial"
        printf 'x\n' > algo.txt
        git add algo.txt
        git commit -q -m "fix(api)!: corrige borde - feat: falso positivo"
        bash "$SCRIPTS_DIR/release.sh" --no-push 0.1.0 >/dev/null
    )

    local first_line
    first_line="$(head -n 1 "$repo/CHANGELOG.md")"
    assert_eq "# Changelog" "$first_line" "CHANGELOG mantiene encabezado arriba"

    grep -Fq "## [0.1.0]" "$repo/CHANGELOG.md"
    grep -Fq -- "- **core:** base inicial" "$repo/CHANGELOG.md"
    grep -Fq -- "- [BREAKING] **api:** corrige borde - feat: falso positivo" "$repo/CHANGELOG.md"
}

test_hooks_revert_and_no_double_prefix() {
    local repo
    repo="$(new_sandbox_repo "hooks-behavior")"

    (
        cd "$repo"
        printf '0.0.1\n' > VERSION
        git add VERSION
        GIT_AUTHOR_INITIALS=AGO git commit -q -m "feat: primer commit"

        local msg1
        msg1="$(git log -1 --pretty=%s)"
        assert_eq "[AGO] - main - feat: primer commit" "$msg1" "prefijo inicial"

        printf 'a\n' > "file with spaces.sh"
        printf 'echo ok\n' > "file with spaces.sh"
        git add "file with spaces.sh"
        GIT_AUTHOR_INITIALS=AGO git commit -q -m "[XYZ] - other - feat: commit existente"

        local msg2
        msg2="$(git log -1 --pretty=%s)"
        assert_eq "[XYZ] - other - feat: commit existente" "$msg2" "no duplica prefijo previo"

        git revert --no-edit HEAD >/dev/null
    )
}

test_precommit_checks_staged_not_workdir() {
    local repo
    repo="$(new_sandbox_repo "precommit-staged")"

    (
        cd "$repo"
        printf 'echo valid\n' > "my script.sh"
        git add "my script.sh"
        # Introducir error de sintaxis solo en disco, no en stage
        printf 'if then\n' > "my script.sh"
        GIT_AUTHOR_INITIALS=AGO git commit -q -m "feat: script valido en stage"

        # Ahora si stagear error de sintaxis y verificar que falla
        git add "my script.sh"
        if GIT_AUTHOR_INITIALS=AGO git commit -q -m "fix: roto" 2>/dev/null; then
            printf 'FAIL: pre-commit debio rechazar script roto en stage\n' >&2
            return 1
        fi
    )
}

test_init_skills_only_when_requested() {
    local repo
    repo="$(new_sandbox_repo "init-skills-opt")"
    local mock_bin="$TMP_ROOT/mockbin"
    local log_file="$TMP_ROOT/npx.log"
    mkdir -p "$mock_bin"
    rm -f -- "$log_file"

    cat > "$mock_bin/npx" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$log_file"
EOF
    chmod +x "$mock_bin/npx"

    (
        cd "$repo"
        PATH="$mock_bin:$PATH" bash "$SCRIPTS_DIR/project-init.sh" --all --license --yes >/dev/null
    )
    assert_file_missing "$log_file"

    (
        cd "$repo"
        PATH="$mock_bin:$PATH" bash "$SCRIPTS_DIR/project-init.sh" --minimal --license --skills --yes >/dev/null
    )
    assert_file_exists "$log_file"
    assert_eq "-y autoskills@latest" "$(cat "$log_file")" "npx autoskills llamado con -y"
}

test_update_creates_missing_version_and_interactive() {
    local repo
    repo="$(new_sandbox_repo "update-interactive")"

    (
        cd "$repo"
        # Responder: y (agregar faltantes), y (LICENSE), n (CHANGELOG), y (README), resto n
        printf 'y\ny\nn\ny\nn\nn\nn\nn\nn\nn\nn\n' | bash "$SCRIPTS_DIR/project-update.sh" >/dev/null
    )

    assert_file_exists "$repo/VERSION"
    assert_eq "0.0.1" "$(tr -d '[:space:]' < "$repo/VERSION")" "update crea VERSION si falta"
    assert_file_exists "$repo/LICENSE"
    assert_file_exists "$repo/README.md"
    assert_file_missing "$repo/CHANGELOG.md"
    assert_file_missing "$repo/.prettierrc"
}

test_hooks_derived_initials_and_detached_head() {
    local repo
    repo="$(new_sandbox_repo "hooks-detached")"

    (
        cd "$repo"
        unset GIT_AUTHOR_INITIALS || true
        printf '0.0.1\n' > VERSION
        git add VERSION
        git commit -q -m "feat: commit inicial"

        local msg1
        msg1="$(git log -1 --pretty=%s)"
        assert_eq "[AG] - main - feat: commit inicial" "$msg1" "iniciales derivadas de user.name"

        git checkout -q --detach HEAD
        printf 'dato\n' > data.txt
        git add data.txt
        git commit -q -m "fix: en detached head"

        local msg2
        msg2="$(git log -1 --pretty=%s)"
        assert_eq "[AG] - detached - fix: en detached head" "$msg2" "soporte detached head"
    )
}

test_install_sh_sandbox_and_uninstall() {
    local fake_home="$TMP_ROOT/fakehome"
    local fake_gitconfig="$TMP_ROOT/fakegitconfig"
    local prev_hooks="$TMP_ROOT/prev_hooks"
    local expected_hooks="$HOOKS_DIR"
    local expected_root="$REPO_ROOT"

    if command -v cygpath >/dev/null 2>&1; then
        prev_hooks="$(cygpath -m "$prev_hooks")"
        expected_hooks="$(cygpath -m "$expected_hooks")"
        expected_root="$(cygpath -m "$expected_root")"
    fi

    mkdir -p "$fake_home"
    touch "$fake_home/.bashrc" "$fake_gitconfig"

    git config --file "$fake_gitconfig" core.hooksPath "$prev_hooks"

    HOME="$fake_home" GIT_CONFIG_GLOBAL="$fake_gitconfig" SHELL="/bin/bash" \
        bash "$REPO_ROOT/install.sh" >/dev/null

    assert_eq "$expected_hooks" "$(git config --file "$fake_gitconfig" --get core.hooksPath)" "install configura hooksPath"
    assert_eq "$expected_root" "$(git config --file "$fake_gitconfig" --get tools-hooks.root)" "install configura root"
    assert_file_exists "$fake_home/.local/bin/git-project-init"
    assert_file_exists "$fake_home/.local/bin/git-project-update"
    assert_file_exists "$fake_home/.local/bin/git-project-check"
    assert_file_exists "$fake_home/.local/bin/git-release"

    HOME="$fake_home" GIT_CONFIG_GLOBAL="$fake_gitconfig" SHELL="/bin/bash" \
        bash "$REPO_ROOT/install.sh" --uninstall >/dev/null

    assert_eq "$prev_hooks" "$(git config --file "$fake_gitconfig" --get core.hooksPath)" "uninstall restaura hooksPath previo"
    assert_file_missing "$fake_home/.local/bin/git-project-init"
    assert_file_missing "$fake_home/.local/bin/git-release"
}

run_test "Sintaxis bash -n de todos los scripts y hooks" test_syntax_all_scripts
run_test "project-init --minimal --license crea solo VERSION y LICENSE" test_init_minimal_blank
run_test "project-init interactivo por defecto crea plantilla en blanco" test_init_interactive_default_blank
run_test "project-init soporta flags modulares individuales" test_init_modular_flags
run_test "project-check valida VERSION obligatorio y --strict" test_check_minimal_and_strict
run_test "project-update diagnostica y agrega solo faltantes solicitados" test_update_validates_and_adds_selected
run_test "release funciona en repo minimo sin CHANGELOG.md" test_release_minimal_without_changelog
run_test "release mantiene # Changelog arriba y agrupa commits" test_release_changelog_header_and_grouping
run_test "hooks manejan revert, espacios y no duplican prefijos" test_hooks_revert_and_no_double_prefix
run_test "pre-commit valida contenido en stage con espacios en nombre" test_precommit_checks_staged_not_workdir
run_test "project-init solo ejecuta autoskills cuando se pasa --skills" test_init_skills_only_when_requested
run_test "project-update crea VERSION faltante e interactua selectivamente" test_update_creates_missing_version_and_interactive
run_test "hooks derivan iniciales y soportan detached HEAD" test_hooks_derived_initials_and_detached_head
run_test "install.sh instala y --uninstall restaura hooks previos" test_install_sh_sandbox_and_uninstall

printf '\nResumen: %d pasaron, %d fallaron.\n' "$TESTS_PASSED" "$TESTS_FAILED"
[[ "$TESTS_FAILED" -eq 0 ]]
