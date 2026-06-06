#!/usr/bin/env bash
# =============================================================================
# 13. Ops / VPS — sshpass (con fallback al tap si no está en homebrew-core).
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HERE/../lib/common.sh"
load_brew

step "Ops / VPS"

if need_cmd sshpass; then
  ok "sshpass ya instalado"
elif "$BREW" install sshpass 2>/dev/null; then
  ok "sshpass instalado (homebrew-core)"
else
  warn "sshpass no está en homebrew-core; usando el tap hudochenkov/sshpass…"
  "$BREW" install hudochenkov/sshpass/sshpass
  ok "sshpass instalado (tap)"
fi

ok "Módulo Ops/VPS completado."
