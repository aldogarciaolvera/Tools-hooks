#!/usr/bin/env bash

# Generadores modulares e idempotentes de archivos para proyectos.

SUPPORTED_TEMPLATES="blank react astro angular reactnative dotnet python"

normalize_template_name() {
    local template="${1:-}"
    case "$template" in
        .net)
            printf 'dotnet\n'
            ;;
        *)
            printf '%s\n' "$template"
            ;;
    esac
}

validate_template_name() {
    local template
    template="$(normalize_template_name "${1:-}")"

    case "$template" in
        ""|blank|react|astro|angular|reactnative|dotnet|python)
            return 0
            ;;
        *)
            die "Plantilla desconocida: $1. Opciones validas: $SUPPORTED_TEMPLATES."
            ;;
    esac
}

find_license_file() {
    local candidate
    for candidate in LICENSE LICENSE.md LICENSE.txt; do
        if [[ -e "$candidate" ]]; then
            printf '%s\n' "$candidate"
            return 0
        fi
    done
    return 1
}

create_version_file() {
    local version="${1:-0.0.1}"

    if [[ -e VERSION ]]; then
        info "VERSION ya existe. No se modificara."
        return 0
    fi

    printf '%s\n' "$version" > VERSION
    info "Creado: VERSION ($version)"
}

create_mit_license_file() {
    local existing
    if existing="$(find_license_file)"; then
        info "El proyecto ya contiene un archivo de licencia ($existing). No se modificara."
        return 0
    fi

    local current_year
    local copyright_holder

    current_year="$(date +'%Y')"
    copyright_holder="$(git config --get user.name 2>/dev/null || true)"
    if [[ -z "$copyright_holder" ]]; then
        copyright_holder="${USER:-${USERNAME:-Unknown}}"
    fi

    cat > LICENSE <<EOF
MIT License

Copyright (c) $current_year $copyright_holder

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
EOF

    info "Creado: LICENSE (MIT)"
}

create_changelog_file() {
    local version="${1:-0.0.1}"

    if [[ -e CHANGELOG.md ]]; then
        info "CHANGELOG.md ya existe. No se modificara."
        return 0
    fi

    local current_date
    current_date="$(date +'%Y-%m-%d')"

    cat > CHANGELOG.md <<EOF
# Changelog

Todos los cambios relevantes de este proyecto se documentaran en este archivo.

El formato esta basado en Keep a Changelog y el proyecto utiliza Semantic Versioning.

## [$version] - $current_date

### Added

- Inicializacion del proyecto.
EOF

    info "Creado: CHANGELOG.md"
}

create_readme_file() {
    if [[ -e README.md ]]; then
        info "README.md ya existe. No se modificara."
        return 0
    fi

    local project_name
    project_name="$(basename "$REPOSITORY_ROOT")"

    cat > README.md <<EOF
# $project_name

<!-- Agrega una breve descripcion de tu proyecto aqui -->

## Instalacion

\`\`\`bash
# Instrucciones de instalacion
\`\`\`

## Uso

\`\`\`bash
# Instrucciones de uso
\`\`\`
EOF

    info "Creado: README.md"
}

create_design_file() {
    if [[ -e DESIGN.md ]]; then
        info "DESIGN.md ya existe. No se modificara."
        return 0
    fi

    cat > DESIGN.md <<'EOF'
# Diseno del Proyecto

<!-- Agrega aqui la documentacion sobre la arquitectura, diseno y decisiones tecnicas del proyecto -->
EOF

    info "Creado: DESIGN.md"
}

create_agents_file() {
    if [[ -e AGENTS.md ]]; then
        info "AGENTS.md ya existe. No se modificara."
        return 0
    fi

    cat > AGENTS.md <<'EOF'
# Agentes y Automatizacion

<!-- Agrega aqui la configuracion, roles o instrucciones para los agentes (por ejemplo, IA, flujos de trabajo) -->
EOF

    info "Creado: AGENTS.md"
}

create_architecture_file() {
    local template
    template="$(normalize_template_name "${1:-blank}")"

    if [[ -e ARCHITECTURE.md ]]; then
        info "ARCHITECTURE.md ya existe. No se modificara."
        return 0
    fi

    local content=""

    case "$template" in
        react|reactnative)
            content="# Arquitectura del Proyecto (React / React Native)

Este proyecto promueve una Clean Architecture o Feature-Sliced Design.

## Estructura Sugerida

- \`src/assets/\`: Recursos estaticos.
- \`src/components/\`: Componentes UI reutilizables.
- \`src/features/\`: Modulos agrupados por funcionalidad.
- \`src/hooks/\`: Hooks personalizados.
- \`src/services/\`: Integracion con APIs externas.
- \`src/store/\`: Manejo de estado.
- \`src/utils/\`: Utilidades generales."
            ;;
        angular)
            content="# Arquitectura del Proyecto (Angular)

Este proyecto promueve modularidad y arquitectura limpia.

## Estructura Sugerida

- \`src/app/core/\`: Servicios singleton y configuraciones.
- \`src/app/shared/\`: Componentes y directivas comunes.
- \`src/app/features/\`: Modulos especificos (lazy loaded)."
            ;;
        dotnet)
            content="# Arquitectura del Proyecto (.NET)

Este proyecto promueve una Clean Architecture.

## Estructura Sugerida

- \`Core/\`: Entidades, interfaces y reglas de negocio.
- \`Application/\`: Casos de uso y DTOs.
- \`Infrastructure/\`: Acceso a datos y servicios externos.
- \`API/\`: Controladores y configuracion web."
            ;;
        python)
            content="# Arquitectura del Proyecto (Python)

Este proyecto promueve una separacion de responsabilidades, siguiendo principios de Clean Architecture.

## Estructura Sugerida

- \`app/api/\`: Endpoints de la API.
- \`app/core/\`: Configuraciones centrales.
- \`app/models/\`: Modelos de dominio y Base de Datos.
- \`app/services/\`: Logica de negocio.
- \`app/tests/\`: Pruebas."
            ;;
        astro)
            content="# Arquitectura del Proyecto (Astro)

Este proyecto utiliza arquitectura en islas.

## Estructura Sugerida

- \`src/components/\`: Componentes UI.
- \`src/layouts/\`: Plantillas de vista.
- \`src/pages/\`: Enrutamiento por archivos.
- \`src/lib/\`: Utilidades compartidas."
            ;;
        *)
            content="# Arquitectura del Proyecto

<!-- Agrega aqui la documentacion sobre la arquitectura, patron de diseno o estructura utilizada. -->"
            ;;
    esac

    printf '%s\n' "$content" > ARCHITECTURE.md
    info "Creado: ARCHITECTURE.md"
}

create_docs_files() {
    local template="${1:-blank}"
    create_design_file
    create_agents_file
    create_architecture_file "$template"
}

create_editorconfig_file() {
    if [[ -e .editorconfig ]]; then
        info ".editorconfig ya existe. No se modificara."
        return 0
    fi

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

    info "Creado: .editorconfig"
}

create_prettierrc_file() {
    if [[ -e .prettierrc ]]; then
        info ".prettierrc ya existe. No se modificara."
        return 0
    fi

    cat > .prettierrc <<'EOF'
{
  "tabWidth": 2,
  "useTabs": false,
  "semi": true,
  "singleQuote": true,
  "trailingComma": "es5"
}
EOF

    info "Creado: .prettierrc"
}

write_fallback_gitignore() {
    local ignore_type="$1"

    cat <<'EOF'
# Sistema operativo y editores
.DS_Store
Thumbs.db
*.swp
*.swo
*~
.env
.env.*
!.env.example
EOF

    case "$ignore_type" in
        node)
            cat <<'EOF'

# Node / JS / TS
node_modules/
dist/
build/
.output/
.astro/
.expo/
*.log
EOF
            ;;
        dotnetcore)
            cat <<'EOF'

# .NET
bin/
obj/
.vs/
*.user
*.suo
EOF
            ;;
        python)
            cat <<'EOF'

# Python
venv/
.venv/
__pycache__/
*.py[cod]
.pytest_cache/
EOF
            ;;
    esac
}

create_gitignore_file() {
    local template
    template="$(normalize_template_name "${1:-blank}")"
    local ignore_type=""

    case "$template" in
        react|angular|reactnative|astro)
            ignore_type="node"
            ;;
        dotnet)
            ignore_type="dotnetcore"
            ;;
        python)
            ignore_type="python"
            ;;
        *)
            ignore_type="macos,windows,linux"
            ;;
    esac

    local marker="# --- Adiciones automaticas de git-project-init ($ignore_type) ---"

    if [[ -e .gitignore ]] && grep -Fq "$marker" .gitignore 2>/dev/null; then
        info ".gitignore ya contiene la configuracion de $ignore_type. No se modificara."
        return 0
    fi

    local tmp_ignore
    tmp_ignore="$(mktemp "${REPOSITORY_ROOT}/.gitignore.XXXXXX")"
    local downloaded=0

    if command -v curl >/dev/null 2>&1; then
        if curl -fsSL --connect-timeout 5 --max-time 15 \
            "https://www.toptal.com/developers/gitignore/api/$ignore_type" > "$tmp_ignore" 2>/dev/null \
            && [[ -s "$tmp_ignore" ]]; then
            downloaded=1
        fi
    fi

    if [[ "$downloaded" -eq 0 ]]; then
        write_fallback_gitignore "$ignore_type" > "$tmp_ignore"
    fi

    if [[ ! -e .gitignore ]]; then
        mv -- "$tmp_ignore" .gitignore
        if [[ "$downloaded" -eq 1 ]]; then
            info "Creado: .gitignore (basado en $ignore_type)"
        else
            info "Creado: .gitignore (plantilla local basica para $ignore_type)"
        fi
    else
        {
            printf '\n%s\n' "$marker"
            cat "$tmp_ignore"
        } >> .gitignore
        rm -f -- "$tmp_ignore"
        if [[ "$downloaded" -eq 1 ]]; then
            info "Actualizado: .gitignore (complementado con $ignore_type)"
        else
            info "Actualizado: .gitignore (complementado localmente con $ignore_type)"
        fi
    fi
}

create_githooks_files() {
    mkdir -p .githooks

    if [[ ! -e .githooks/pre-commit ]]; then
        cat > .githooks/pre-commit <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

git-project-check
EOF
        chmod +x .githooks/pre-commit
        info "Creado: .githooks/pre-commit"
    else
        info ".githooks/pre-commit ya existe. No se modificara."
    fi

    if [[ ! -e .githooks/pre-push ]]; then
        cat > .githooks/pre-push <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

git-project-check
EOF
        chmod +x .githooks/pre-push
        info "Creado: .githooks/pre-push"
    else
        info ".githooks/pre-push ya existe. No se modificara."
    fi
}

create_dockerignore_file() {
    if [[ -e .dockerignore ]]; then
        info ".dockerignore ya existe. No se modificara."
        return 0
    fi

    cat > .dockerignore <<'EOF'
.git
.githooks
.gitignore
node_modules
venv
.venv
__pycache__
bin
obj
.vs
*.log
.env
.env.*
EOF

    info "Creado: .dockerignore"
}

create_docker_files() {
    local template
    template="$(normalize_template_name "${1:-blank}")"

    if [[ -z "$template" || "$template" == "blank" ]]; then
        warn "Dockerfile requiere una plantilla tecnologica distinta de 'blank'."
        return 0
    fi

    local project_name
    project_name="$(basename "$REPOSITORY_ROOT")"

    if [[ -e Dockerfile ]]; then
        info "Dockerfile ya existe. No se modificara."
    else
        case "$template" in
            react|astro)
                cat > Dockerfile <<'EOF'
# Build stage
FROM node:26-alpine AS build
WORKDIR /app
COPY package.json pnpm-lock.yaml* ./
RUN npm install -g pnpm && pnpm install
COPY . .
RUN pnpm run build

# Serve stage
FROM nginx:alpine
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF
                ;;
            angular)
                cat > Dockerfile <<'EOF'
# Build stage
FROM node:26-alpine AS build
WORKDIR /app
COPY package.json pnpm-lock.yaml* ./
RUN npm install -g pnpm && pnpm install
COPY . .
RUN pnpm run build \
    && mkdir -p /app/out \
    && if [ -d /app/dist/*/browser ]; then cp -r /app/dist/*/browser/* /app/out/; else cp -r /app/dist/* /app/out/; fi

# Serve stage
FROM nginx:alpine
COPY --from=build /app/out /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF
                ;;
            reactnative)
                cat > Dockerfile <<'EOF'
FROM node:26-alpine
WORKDIR /app
COPY package.json pnpm-lock.yaml* ./
RUN npm install -g pnpm && pnpm install
COPY . .
EXPOSE 8081
CMD ["pnpm", "start"]
EOF
                ;;
            dotnet)
                cat > Dockerfile <<EOF
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src
COPY *.csproj ./
RUN dotnet restore
COPY . .
RUN dotnet publish -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .
EXPOSE 8080
# Asegurate de que el nombre del DLL coincida con tu archivo .csproj
ENTRYPOINT ["dotnet", "${project_name}.dll"]
EOF
                ;;
            python)
                cat > Dockerfile <<'EOF'
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
EOF
                ;;
        esac

        if [[ -s Dockerfile ]]; then
            info "Creado: Dockerfile"
        fi
    fi

    create_dockerignore_file
}

copy_template_dir_safely() {
    local src_dir="$1"
    rm -rf -- "$src_dir/.git"

    local item
    local name
    shopt -s dotglob nullglob
    for item in "$src_dir"/*; do
        name="$(basename -- "$item")"
        if [[ -e "$REPOSITORY_ROOT/$name" ]]; then
            warn "Se conserva archivo existente: $name"
            continue
        fi
        cp -a -- "$item" "$REPOSITORY_ROOT/"
    done
    shopt -u dotglob nullglob
}

install_project_template() {
    local template
    template="$(normalize_template_name "${1:-blank}")"

    if [[ -z "$template" || "$template" == "blank" ]]; then
        return 0
    fi

    validate_template_name "$template"
    info ""
    info "Instalando plantilla para: $template"

    local tmp_dir=""
    case "$template" in
        react|astro|angular|reactnative)
            command -v pnpm >/dev/null 2>&1 ||
                die "pnpm no esta instalado. Instalalo para usar la plantilla $template."
            tmp_dir="$(mktemp -d "${REPOSITORY_ROOT}/.template.XXXXXX")"
            ;;
    esac

    case "$template" in
        react)
            pnpm create vite@latest "$tmp_dir/app" --template react
            copy_template_dir_safely "$tmp_dir/app"
            rm -rf -- "$tmp_dir"
            pnpm install
            ;;
        astro)
            pnpm create astro@latest "$tmp_dir/app" --template minimal --install no --git no --yes
            copy_template_dir_safely "$tmp_dir/app"
            rm -rf -- "$tmp_dir"
            pnpm install
            ;;
        angular)
            command -v npx >/dev/null 2>&1 || {
                rm -rf -- "$tmp_dir"
                die "npx no esta instalado. Instalalo para usar la plantilla angular."
            }
            npx -y @angular/cli@latest new app --directory "$tmp_dir/app" --package-manager pnpm --skip-git --skip-install --defaults
            copy_template_dir_safely "$tmp_dir/app"
            rm -rf -- "$tmp_dir"
            pnpm install
            ;;
        reactnative)
            pnpm create expo-app "$tmp_dir/app" --template blank-typescript
            copy_template_dir_safely "$tmp_dir/app"
            rm -rf -- "$tmp_dir"
            pnpm install
            ;;
        dotnet)
            command -v dotnet >/dev/null 2>&1 ||
                die "dotnet no esta instalado. Instalalo para usar la plantilla dotnet."
            dotnet new webapi
            ;;
        python)
            local python_cmd=""
            if command -v python3 >/dev/null 2>&1; then
                python_cmd="python3"
            elif command -v python >/dev/null 2>&1; then
                python_cmd="python"
            else
                die "python no esta instalado. Instalalo para usar la plantilla python."
            fi

            "$python_cmd" -m venv venv

            local pip_bin=""
            if [[ -f "venv/Scripts/pip" || -f "venv/Scripts/pip.exe" ]]; then
                pip_bin="venv/Scripts/pip"
            elif [[ -f "venv/bin/pip" ]]; then
                pip_bin="venv/bin/pip"
            else
                die "No se encontro pip dentro de venv."
            fi

            "$pip_bin" install "fastapi[standard]"
            if [[ ! -e requirements.txt ]]; then
                "$pip_bin" freeze | grep -viE '^(pywin32|wincertstore)==' > requirements.txt
            fi

            if [[ ! -e main.py ]]; then
                cat > main.py <<'EOF'
from fastapi import FastAPI

app = FastAPI()


@app.get("/")
def read_root():
    return {"message": "Hello World API"}
EOF
            fi
            ;;
    esac

    info "Plantilla $template instalada correctamente."
}

run_autoskills() {
    info ""
    info "Ejecutando autoskills..."
    if command -v npx >/dev/null 2>&1; then
        npx -y autoskills@latest
    else
        warn "npx no esta instalado. Se omitira autoskills."
    fi
}
