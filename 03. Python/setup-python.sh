#!/usr/bin/env bash
# =============================================================================
# 03. Python — uv + Python 3.12 como python3 por defecto.
# uv gestiona los intérpretes; los shims viven en ~/.local/bin (igual en arm64/x86_64).
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HERE/../lib/common.sh"
load_brew

step "Python (uv)"

# 1. Instalar uv con el instalador oficial (no necesita Python previo).
if need_cmd uv; then
  ok "uv ya instalado ($(uv --version 2>/dev/null))"
else
  log "Instalando uv (astral.sh)…"
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# 2. Cargar uv en la sesión actual y asegurar ~/.local/bin en el PATH.
[[ -f "$HOME/.local/bin/env" ]] && . "$HOME/.local/bin/env"
export PATH="$HOME/.local/bin:$PATH"
need_cmd uv || die "uv no quedó disponible en el PATH."
ok "uv $(uv --version 2>/dev/null | awk '{print $2}')"

# 3. Instalar Python 3.12 y dejarlo como default (crea shims python/python3).
log "uv python install 3.12 --default…"
uv python install 3.12 --default
# Garantiza ~/.local/bin en el PATH de shells FUTUROS (idempotente; tolera uv antiguos).
uv python update-shell 2>/dev/null || warn "uv python update-shell no disponible; verifica que ~/.local/bin esté en tu PATH."
hash -r 2>/dev/null || true

# 4. Verificar.
ok "python3 → $(command -v python3)"
python3 --version
uv python list

ok "Módulo Python completado."
