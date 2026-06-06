#!/usr/bin/env bash
# =============================================================================
# 09. Redis — fórmula de brew + servicio (lo usa Bull/colas en tnb-backend).
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HERE/../lib/common.sh"
load_brew

step "Redis"

# La FÓRMULA 'redis' (no el cask redis-stack: ese NO lo gestiona brew services).
brew_ensure redis
service_ensure redis

# Verificar.
if redis-cli ping 2>/dev/null | grep -qi PONG; then
  ok "redis responde PONG"
else
  warn "redis aún no respondió a PING (puede tardar un instante tras arrancar)."
fi

ok "Módulo Redis completado."
