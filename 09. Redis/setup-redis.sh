#!/usr/bin/env bash
# =============================================================================
# 09. Redis — brew formula + service (used by Bull/queues in tnb-backend).
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HERE/../lib/common.sh"
load_brew

step "Redis"

# The 'redis' FORMULA (not the redis-stack cask: that one is NOT managed by brew services).
brew_ensure redis
service_ensure redis

# Verify.
if redis-cli ping 2>/dev/null | grep -qi PONG; then
  ok "redis responds PONG"
else
  warn "redis has not responded to PING yet (it may take a moment after starting)."
fi

ok "Redis module completed."
