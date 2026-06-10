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

# Verify (poll: the socket may take a moment right after the service starts).
redis_pong() { redis-cli ping 2>/dev/null | grep -qi PONG; }
if wait_for "redis to respond PONG" redis_pong; then
  ok "redis responds PONG"
else
  warn "redis has not responded to PING after ${SETUP_TIMEOUT}s (check: brew services list)."
fi

ok "Redis module completed."
