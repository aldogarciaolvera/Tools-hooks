# Dev Tools

Colección de herramientas para estandarizar el desarrollo de proyectos con Git.

Este proyecto reúne hooks globales, scripts y utilidades que automatizan tareas repetitivas, mantienen un flujo de trabajo consistente y ayudan a garantizar la calidad del código antes de realizar commits, pushes o releases.

---

# Características

- Prefijo automático de commits.
- Validación de Conventional Commits.
- Hooks globales reutilizables.
- Hooks específicos por proyecto.
- Validaciones automáticas antes de cada commit.
- Validaciones antes de publicar cambios.
- Gestión de versiones mediante Semantic Versioning.
- Creación automática de releases.

---

# Estructura

```
dev-tools/
├── git-hooks/
│   ├── prepare-commit-msg
│   ├── commit-msg
│   ├── pre-commit
│   └── pre-push
│
├── scripts/
│   └── release.sh
│
├── install.sh
├── README.md
└── LICENSE
```

---

# Requisitos

- Git 2.x o superior
- Bash
- Linux o macOS

---

# Instalación

Clonar el repositorio

```bash
git clone https://github.com/aldogarciaolvera/dev-tools.git
```

Entrar al proyecto

```bash
cd dev-tools
```

Ejecutar el instalador

```bash
./install.sh
```

El instalador configura automáticamente:

- Hooks globales de Git.
- Comando `git-release`.
- Permisos de ejecución.
- Configuración necesaria de Git.

---

# Hooks incluidos

## prepare-commit-msg

Agrega automáticamente las iniciales y la rama al mensaje del commit.

Ejemplo:

Antes

```
feat: agrega respaldo incremental
```

Después

```
[AGO] - main - feat: agrega respaldo incremental
```

---

## commit-msg

Valida que el mensaje siga el estándar Conventional Commits.

Tipos permitidos

```
feat
fix
docs
refactor
test
build
ci
perf
style
revert
chore
```

---

## pre-commit

Antes de permitir un commit ejecuta:

- Validación de sintaxis Bash.
- Validaciones globales.
- Validaciones específicas del repositorio si existe `.githooks/pre-commit`.

---

## pre-push

Antes de realizar un push ejecuta:

- Validaciones del repositorio.
- Pruebas automatizadas.
- Cualquier script definido en `.githooks/pre-push`.

Si alguna validación falla el push es cancelado.

---

# Releases

El proyecto incluye el comando:

```bash
git-release
```

Ejemplo

```bash
git-release 1.1.0
```

El script realiza automáticamente:

- Validación de la versión.
- Actualización del archivo VERSION.
- Actualización del CHANGELOG.
- Creación del commit.
- Creación del tag Git.

Posteriormente solo es necesario ejecutar

```bash
git push origin main
git push origin --tags
```

---

# Semantic Versioning

Se utiliza el estándar:

```
MAJOR.MINOR.PATCH
```

Ejemplos

```
1.0.0
1.0.1
1.1.0
2.0.0
```

---

# Hooks específicos por proyecto

Cada repositorio puede definir validaciones adicionales creando:

```
.githooks/
```

Ejemplo

```
proyecto/
│
├── .githooks/
│   ├── pre-commit
│   └── pre-push
```

Los hooks globales ejecutarán automáticamente estos scripts si existen.

---

# Flujo de trabajo recomendado

```
Modificar código
        │
        ▼
git add
        │
        ▼
git commit
        │
        ▼
prepare-commit-msg
        │
        ▼
commit-msg
        │
        ▼
pre-commit
        │
        ▼
Repositorio limpio
        │
        ▼
git-release
        │
        ▼
Git Tag
        │
        ▼
git push
        │
        ▼
pre-push
        │
        ▼
GitHub
```

---

# Personalización

Las iniciales utilizadas en los commits pueden cambiarse mediante la variable:

```bash
export GIT_AUTHOR_INITIALS=ABC
```

Resultado

```
[ABC] - develop - feat: nueva funcionalidad
```

---

# Licencia

MIT License.
