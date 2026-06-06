# 00 · Inventario del entorno

Snapshot de las herramientas y versiones del **Mac actual** tomado el **2026-06-06**, antes de migrar/limpiar el equipo. Sirve para (1) reproducir el entorno en el Mac nuevo y (2) como base real para optimizar los scripts de `setup-macos`.

- **Sistema:** macOS 15.7.1 · **Intel (x86_64)** · Homebrew en `/usr/local`
- ⚠️ Si el Mac nuevo es **Apple Silicon**, Homebrew vivirá en `/opt/homebrew`: los comandos son los mismos, solo cambian las rutas de los binarios *keg-only* (p. ej. `postgresql@16`).

## Archivos

| Archivo | Qué contiene |
|---|---|
| `Brewfile` | Paquetes **top-level** de Homebrew (fórmulas + casks). Reproducible con `brew bundle`. |
| `tool-versions.md` | Tabla legible de versiones y rutas de cada herramienta. |
| `brew-formulae-versions.txt` | Todas las fórmulas instaladas con versión (incluye dependencias). |
| `brew-casks-versions.txt` | Casks instalados con versión. |
| `vscode-extensions.txt` | 52 extensiones de VS Code con versión. |
| `npm-global.txt` | Paquetes npm globales. |

## Reproducir en el Mac nuevo

```bash
# 1. Homebrew  →  ver el script principal del repo
# 2. Fórmulas + casks de una sola pasada:
brew bundle install --file="00. Inventory/Brewfile"

# 3. Extensiones de VS Code:
while read -r ext; do code --install-extension "${ext%@*}"; done < "00. Inventory/vscode-extensions.txt"

# 4. Paquetes npm globales (tras instalar Node): ver npm-global.txt
#    → eas-cli, n8n, uipro-cli (claude@0.1.1 es residual: usa el instalador nativo)
```

## Lo que NO gestiona Homebrew (cambio de gestor en el equipo nuevo)

| Herramienta | Estado actual | Plan en el equipo nuevo |
|---|---|---|
| **Node.js** v24.11.1 | Instalador oficial `.pkg` (binario root en `/usr/local/bin/node`) | Migrar a **fnm** |
| **Python** 3.14 | `python@3.11` + `python@3.14` por brew (`python3` → 3.14) | Migrar a **uv** (Python 3.12 fijo) |
| **MySQL** 8.0.44 | Instalador oficial Oracle en `/usr/local/mysql` | A decidir (brew `mysql` vs instalador) |
| **Java** 17.0.19 | `openjdk@17` por brew | Igual (el borrador mencionaba `zulu@17`) |
| **Claude Code** 2.1.167 | Instalador nativo en `~/.local/bin/claude` | Instalador nativo |

## Bases de datos y secretos

Los **volcados de PostgreSQL/MySQL**, los **dotfiles** (`.zshrc`, `.zprofile`, `.gitconfig`) y los `.env` **NO** están en git por contener datos/credenciales. Viven en `~/BackupsBeforeClean/` — la guía de carga está en **`~/BackupsBeforeClean/RESTORE.md`**.
