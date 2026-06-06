# 02 · Homebrew

Instala Homebrew **arch-aware** y lo deja en el PATH de zsh, de forma idempotente.

- Detecta el prefijo por arquitectura: **arm64 → `/opt/homebrew`**, **x86_64 → `/usr/local`** (vía `lib/common.sh`).
- Instala solo si falta (`NONINTERACTIVE=1`, sin prompts); re-ejecutar es no-op.
- Añade `eval "$(<prefix>/bin/brew shellenv)"` a `${ZDOTDIR:-$HOME}/.zprofile` **una sola vez** (`append_once`).
- Activa brew en la sesión actual y deja CLI base: `jq`, `tree` (jq lo usa el módulo 06).

## Uso
```bash
./setup.sh 02                       # desde la raíz del repo
"02. Homebrew/setup-homebrew.sh"    # o directo
```

## Notas
- En **Apple Silicon**, sin la línea de `shellenv` aparece `zsh: command not found: brew` porque `/opt/homebrew/bin` no está en el PATH por defecto — este módulo lo resuelve.
- macOS mínimo soportado por Homebrew: **14.0 (Sonoma)**.
- Requiere los Command Line Tools de Xcode; el instalador los instala solo (puede tardar varios minutos y necesita red/`sudo`).
- El set completo de paquetes que usas hoy está en **`00. Inventory/Brewfile`** → reproducible con `brew bundle install --file="00. Inventory/Brewfile"`.
