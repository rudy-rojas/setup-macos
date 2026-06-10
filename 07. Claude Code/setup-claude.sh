#!/usr/bin/env bash
# =============================================================================
# 07. Claude Code — official native installer (binary at ~/.local/bin/claude).
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HERE/../lib/common.sh"

step "Claude Code"

# 1. Install with the native installer if missing (re-running updates in place).
if need_cmd claude; then
  ok "Claude Code already installed ($(claude --version 2>/dev/null | head -1))"
else
  log "Installing Claude Code (official native installer)…"
  curl -fsSL https://claude.ai/install.sh | bash
fi

# 2. Ensure ~/.local/bin is on the PATH of the current session.
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
need_cmd claude || die "claude is not on the PATH (~/.local/bin). Open a new terminal."

# 3. Verify. claude doctor is NOT run here: it renders an interactive screen that
#    blocks on "Enter to continue", stalling an unattended install.
claude --version
log "for install diagnostics (conflicting installations), run: claude doctor"

ok "Claude Code module completed."
