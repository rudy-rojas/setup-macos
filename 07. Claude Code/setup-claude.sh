#!/usr/bin/env bash
# =============================================================================
# 07. Claude Code — instalador nativo oficial (binario en ~/.local/bin/claude).
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HERE/../lib/common.sh"

step "Claude Code"

# 1. Instalar con el instalador nativo si falta (re-ejecutar actualiza en sitio).
if need_cmd claude; then
  ok "Claude Code ya instalado ($(claude --version 2>/dev/null | head -1))"
else
  log "Instalando Claude Code (instalador nativo oficial)…"
  curl -fsSL https://claude.ai/install.sh | bash
fi

# 2. Asegurar ~/.local/bin en el PATH de la sesión actual.
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
need_cmd claude || die "claude no quedó en el PATH (~/.local/bin). Abre una terminal nueva."

# 3. Verificar.
claude --version
claude doctor || true     # diagnóstico (detecta instalaciones en conflicto)

ok "Módulo Claude Code completado."
