#!/usr/bin/env bash

set -Eeuo pipefail

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

TOOLS_HOOKS_ROOT="$(git config --global --get tools-hooks.root || true)"

if [[ -z "$TOOLS_HOOKS_ROOT" ]]; then
    die "tools-hooks.root no está configurado. Ejecuta ./install.sh"
fi

PROJECT_CHECK="$TOOLS_HOOKS_ROOT/scripts/project-check.sh"

[[ -f "$PROJECT_CHECK" ]] ||
    die "No se encontró project-check.sh en: $PROJECT_CHECK"

INITIAL_VERSION="0.0.1"
LICENSE_MODE="ask"
TEMPLATE_NAME=""

show_help() {
    cat <<'EOF'
Uso:
  git-project-init [opciones]

Opciones:
  --version X.Y.Z   Versión inicial. Por defecto: 0.0.1
  --license         Crea la licencia MIT sin preguntar.
  --no-license      No crea ninguna licencia.
  --template TIPO   Instala una plantilla básica (react, astro, angular, reactnative, dotnet, python).
  -h, --help        Muestra esta ayuda.

Ejemplos:
  git-project-init
  git-project-init --version 0.0.1  
  git-project-init --version 0.0.1 --license
  git-project-init --template react
EOF
}

is_semver() {
    [[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

create_version() {
    if [[ -e VERSION ]]; then
        printf 'VERSION ya existe. No se modificará.\n'
        return
    fi

    printf '%s\n' "$INITIAL_VERSION" > VERSION
    printf 'Creado: VERSION (%s)\n' "$INITIAL_VERSION"
}

create_changelog() {
    if [[ -e CHANGELOG.md ]]; then
        printf 'CHANGELOG.md ya existe. No se modificará.\n'
        return
    fi

    local current_date
    current_date="$(date +'%Y-%m-%d')"

    cat > CHANGELOG.md <<EOF
# Changelog

Todos los cambios relevantes de este proyecto se documentarán en este archivo.

El formato está basado en Keep a Changelog y el proyecto utiliza Semantic Versioning.

## [$INITIAL_VERSION] - $current_date

### Added

- Inicialización del proyecto.
EOF

    printf 'Creado: CHANGELOG.md\n'
}

create_docs_files() {
    if [[ -e DESIGN.md ]]; then
        printf 'DESIGN.md ya existe. No se modificará.\n'
    else
        cat > DESIGN.md <<'EOF'
# Diseño del Proyecto

<!-- Agrega aquí la documentación sobre la arquitectura, diseño y decisiones técnicas del proyecto -->
EOF
        printf 'Creado: DESIGN.md\n'
    fi

    if [[ -e AGENTS.md ]]; then
        printf 'AGENTS.md ya existe. No se modificará.\n'
    else
        cat > AGENTS.md <<'EOF'
# Agentes y Automatización

<!-- Agrega aquí la configuración, roles o instrucciones para los agentes (por ejemplo, IA, flujos de trabajo) -->
EOF
        printf 'Creado: AGENTS.md\n'
    fi
}

create_base_config_files() {
    local project_name
    project_name="$(basename "$REPOSITORY_ROOT")"

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
}

setup_gitignore() {
    local template="$1"
    local ignore_type=""

    case "$template" in
        react|angular|reactnative|astro)
            ignore_type="node"
            ;;
        dotnet|.net)
            ignore_type="dotnetcore"
            ;;
        python)
            ignore_type="python"
            ;;
        *)
            ignore_type="macos,windows,linux"
            ;;
    esac

    if command -v curl >/dev/null 2>&1; then
        if [[ ! -e .gitignore ]]; then
            curl -sL "https://www.toptal.com/developers/gitignore/api/$ignore_type" > .gitignore
            printf 'Creado: .gitignore (basado en %s)\n' "$ignore_type"
        else
            # Solo añadir un salto de línea y adjuntar lo descargado para complementar
            echo "" >> .gitignore
            echo "# --- Adiciones automáticas de git-project-init ($ignore_type) ---" >> .gitignore
            curl -sL "https://www.toptal.com/developers/gitignore/api/$ignore_type" >> .gitignore
            printf 'Actualizado: .gitignore (complementado con %s)\n' "$ignore_type"
        fi
    else
        printf 'AVISO: curl no está instalado, no se pudo descargar .gitignore avanzado.\n'
    fi
}

setup_docker() {
    local template="$1"
    local project_name
    project_name="$(basename "$REPOSITORY_ROOT")"

    if [[ -z "$template" ]]; then
        return
    fi

    if [[ ! -e Dockerfile ]]; then
        case "$template" in
            react|astro|angular)
                cat > Dockerfile <<EOF
# Build stage
FROM node:26-alpine AS build
WORKDIR /app
COPY package.json pnpm-lock.yaml* ./
RUN npm install -g pnpm && pnpm install
COPY . .
RUN pnpm run build

# Serve stage
FROM nginx:alpine
# El directorio final de build puede variar (ej. dist, build, out)
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]
EOF
                ;;
            reactnative)
                cat > Dockerfile <<EOF
FROM node:26-alpine
WORKDIR /app
COPY package.json pnpm-lock.yaml* ./
RUN npm install -g pnpm && pnpm install
COPY . .
EXPOSE 8081
CMD ["pnpm", "start"]
EOF
                ;;
            dotnet|.net)
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
# Asegúrate de que el nombre del DLL coincida con el nombre de tu proyecto
ENTRYPOINT ["dotnet", "${project_name}.dll"]
EOF
                ;;
            python)
                cat > Dockerfile <<EOF
FROM python:3.11-slim
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
            printf 'Creado: Dockerfile\n'
        fi
    else
        printf 'Dockerfile ya existe. No se modificará.\n'
    fi
}

create_mit_license() {
    if [[ -e LICENSE ]] ||
       [[ -e LICENSE.md ]] ||
       [[ -e LICENSE.txt ]]; then
        printf 'El proyecto ya contiene un archivo de licencia.\n'
        return
    fi

    local current_year
    local copyright_holder

    current_year="$(date +'%Y')"
    copyright_holder="$(git config --get user.name 2>/dev/null || true)"

    if [[ -z "$copyright_holder" ]]; then
        copyright_holder="${USER:-Unknown}"
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

    printf 'Creado: LICENSE (MIT)\n'
}

handle_license() {
    local answer

    if [[ -e LICENSE ]] ||
       [[ -e LICENSE.md ]] ||
       [[ -e LICENSE.txt ]]; then
        printf 'El proyecto ya contiene un archivo de licencia.\n'
        return
    fi

    case "$LICENSE_MODE" in
        yes)
            create_mit_license
            ;;
        no)
            printf 'La licencia no fue creada.\n'
            ;;
        ask)
            printf '\n'
            read -r -p '¿Deseas agregar la licencia MIT? [y/N]: ' answer

            case "$answer" in
                y|Y|yes|YES|si|SI|sí|SÍ)
                    create_mit_license
                    ;;
                *)
                    printf 'La licencia no fue creada.\n'
                    ;;
            esac
            ;;
    esac
}

create_repository_validations() {
    mkdir -p .githooks

    if [[ ! -e .githooks/pre-commit ]]; then
       cat > .githooks/pre-commit <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

git-project-check
EOF

        chmod +x .githooks/pre-commit
        printf 'Creado: .githooks/pre-commit\n'
    else
        printf '.githooks/pre-commit ya existe. No se modificará.\n'
    fi

    if [[ ! -e .githooks/pre-push ]]; then
     cat > .githooks/pre-push <<'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail

git-project-check
EOF

        chmod +x .githooks/pre-push
        printf 'Creado: .githooks/pre-push\n'
    else
        printf '.githooks/pre-push ya existe. No se modificará.\n'
    fi
}

install_template() {
    local template="$1"
    
    if [[ -z "$template" ]]; then
        return
    fi
    
    printf '\nInstalando plantilla para: %s\n' "$template"
    
    case "$template" in
        react)
            if ! command -v pnpm >/dev/null 2>&1; then
                printf 'AVISO: pnpm no está instalado. Instálalo para usar esta plantilla.\n'
                return
            fi
            pnpm create vite@latest temp-app --template react
            cp -a temp-app/. .
            rm -rf temp-app
            pnpm install
            ;;
        astro)
            if ! command -v pnpm >/dev/null 2>&1; then
                printf 'AVISO: pnpm no está instalado.\n'
                return
            fi
            pnpm create astro@latest temp-app --template minimal --install no --git no --yes
            cp -a temp-app/. .
            rm -rf temp-app
            pnpm install
            ;;
        angular)
            if ! command -v pnpm >/dev/null 2>&1; then
                printf 'AVISO: pnpm no está instalado.\n'
                return
            fi
            npx -y @angular/cli@latest new temp-app --package-manager pnpm --skip-git --skip-install --defaults
            cp -a temp-app/. .
            rm -rf temp-app
            pnpm install
            ;;
        reactnative)
            if ! command -v pnpm >/dev/null 2>&1; then
                printf 'AVISO: pnpm no está instalado.\n'
                return
            fi
            pnpm create expo-app temp-app --template blank
            cp -a temp-app/. .
            rm -rf temp-app
            pnpm install
            ;;
        dotnet|.net)
            if ! command -v dotnet >/dev/null 2>&1; then
                printf 'AVISO: dotnet no está instalado.\n'
                return
            fi
            dotnet new webapi
            ;;
        python)
            if command -v python3 >/dev/null 2>&1; then
                python3 -m venv venv
            elif command -v python >/dev/null 2>&1; then
                python -m venv venv
            else
                printf 'AVISO: python no está instalado.\n'
                return
            fi
            
            if [[ -f "venv/Scripts/pip" ]]; then
                venv/Scripts/pip install "fastapi[standard]"
                venv/Scripts/pip freeze > requirements.txt
            elif [[ -f "venv/bin/pip" ]]; then
                venv/bin/pip install "fastapi[standard]"
                venv/bin/pip freeze > requirements.txt
            fi

            cat > main.py <<'EOF'
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "Hello World API"}
EOF
            if grep -q "venv/" .gitignore 2>/dev/null; then
                :
            else
                echo 'venv/' >> .gitignore
            fi
            ;;
        *)
            die "Plantilla desconocida: $template. Opciones válidas: react, astro, angular, reactnative, dotnet, python."
            ;;
    esac
    printf 'Plantilla instalada correctamente.\n'
}


while [[ $# -gt 0 ]]; do
    case "$1" in
        --version)
            [[ $# -ge 2 ]] ||
                die "Debes indicar una versión después de --version"

            INITIAL_VERSION="$2"
            shift 2
            ;;
        --license)
            LICENSE_MODE="yes"
            shift
            ;;
        --no-license)
            LICENSE_MODE="no"
            shift
            ;;
        --template)
            [[ $# -ge 2 ]] ||
                die "Debes indicar una tecnología después de $1"
            TEMPLATE_NAME="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            die "Opción desconocida: $1"
            ;;
    esac
done

is_semver "$INITIAL_VERSION" ||
    die "La versión debe tener el formato X.Y.Z"

git rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
    die "Debes ejecutar este comando dentro de un repositorio Git"

REPOSITORY_ROOT="$(git rev-parse --show-toplevel)"
cd "$REPOSITORY_ROOT"

printf 'Inicializando archivos del proyecto en:\n'
printf '  %s\n\n' "$REPOSITORY_ROOT"

install_template "$TEMPLATE_NAME"
setup_gitignore "$TEMPLATE_NAME"
setup_docker "$TEMPLATE_NAME"

create_base_config_files
create_version
create_changelog
create_docs_files
handle_license
create_repository_validations

printf '\n'
printf 'Ejecutando autoskills...\n'
if command -v npx >/dev/null 2>&1; then
    npx autoskills@latest
else
    printf 'AVISO: npx no está instalado. Se omitirá autoskills.\n'
fi

printf '\n'
printf 'Validando resultado...\n\n'

[[ -f "$PROJECT_CHECK" ]] ||
    die "No se encontró project-check.sh en: $PROJECT_CHECK"

bash "$PROJECT_CHECK"

printf '\nProyecto inicializado correctamente.\n'

