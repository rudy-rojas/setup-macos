#!/usr/bin/env bash
# =============================================================================
# 13. Ops / VPS — sshpass (with fallback to the tap if not in homebrew-core).
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HERE/../lib/common.sh"
load_brew

step "Ops / VPS"

if need_cmd sshpass; then
  ok "sshpass already installed"
elif "$BREW" install sshpass 2>/dev/null; then
  ok "sshpass installed (homebrew-core)"
else
  warn "sshpass is not in homebrew-core; using the hudochenkov/sshpass tap…"
  "$BREW" install hudochenkov/sshpass/sshpass
  ok "sshpass installed (tap)"
fi

ok "Ops/VPS module completed."
