#!/usr/bin/env bash
set -Eeuo pipefail

die(){ printf 'ERROR: %s\n' "$*" >&2; exit 1; }

git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    die "No estás dentro de un repositorio Git"

REPO_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPO_ROOT"

project_name="$(basename "$REPO_ROOT")"

printf 'Actualizando el proyecto %s...\n\n' "$project_name"

if [[ ! -e DESIGN.md ]]; then
    cat > DESIGN.md <<'EOF'
# Diseño del Proyecto

<!-- Agrega aquí la documentación sobre la arquitectura, diseño y decisiones técnicas del proyecto -->
EOF
    printf 'Creado: DESIGN.md\n'
else
    printf 'DESIGN.md ya existe. No se modificará.\n'
fi

if [[ ! -e AGENTS.md ]]; then
    cat > AGENTS.md <<'EOF'
# Agentes y Automatización

<!-- Agrega aquí la configuración, roles o instrucciones para los agentes (por ejemplo, IA, flujos de trabajo) -->
EOF
    printf 'Creado: AGENTS.md\n'
else
    printf 'AGENTS.md ya existe. No se modificará.\n'
fi

if [[ ! -e .editorconfig ]]; then
    cat > .editorconfig <<'EOF'
root = true

[*]
charset = utf-8
indent_style = space
indent_size = 2
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true
EOF
    printf 'Creado: .editorconfig\n'
else
    printf '.editorconfig ya existe. No se modificará.\n'
fi

if [[ ! -e .prettierrc ]]; then
    cat > .prettierrc <<'EOF'
{
  "tabWidth": 2,
  "useTabs": false,
  "semi": true,
  "singleQuote": true,
  "trailingComma": "es5"
}
EOF
    printf 'Creado: .prettierrc\n'
else
    printf '.prettierrc ya existe. No se modificará.\n'
fi

if [[ ! -e README.md ]]; then
    cat > README.md <<EOF
# $project_name

<!-- Agrega una breve descripción de tu proyecto aquí -->

## Instalación

\`\`\`bash
# Instrucciones de instalación
\`\`\`

## Uso

\`\`\`bash
# Instrucciones de uso
\`\`\`
EOF
    printf 'Creado: README.md\n'
else
    printf 'README.md ya existe. No se modificará.\n'
fi

printf '\n¡Actualización completada!\n'
