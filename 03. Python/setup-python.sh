#!/usr/bin/env bash
# =============================================================================
# 03. Python — uv + Python (PYTHON_VERSION, default 3.12) as the default python3.
# uv manages the interpreters; the shims live in ~/.local/bin (same on arm64/x86_64).
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HERE/../lib/common.sh"
load_brew

step "Python (uv)"

# 1. Install uv with the official installer (no prior Python needed).
if need_cmd uv; then
  ok "uv already installed ($(uv --version 2>/dev/null))"
else
  log "Installing uv (astral.sh)…"
  curl -LsSf https://astral.sh/uv/install.sh | sh
fi

# 2. Load uv in the current session and ensure ~/.local/bin is on the PATH.
[[ -f "$HOME/.local/bin/env" ]] && . "$HOME/.local/bin/env"
export PATH="$HOME/.local/bin:$PATH"
require_cmd uv "open a new terminal or check that ~/.local/bin is on your PATH."
ok "uv $(uv --version 2>/dev/null | awk '{print $2}')"

# 3. Install Python (pinned in lib/common.sh: PYTHON_VERSION) and set it as the
#    default (creates the python/python3 shims).
log "uv python install $PYTHON_VERSION --default…"
uv python install "$PYTHON_VERSION" --default
# Ensures ~/.local/bin on the PATH of FUTURE shells (idempotent; tolerates old uv versions).
uv python update-shell 2>/dev/null || warn "uv python update-shell unavailable; make sure ~/.local/bin is on your PATH."
hash -r 2>/dev/null || true

# 4. Verify.
ok "python3 → $(command -v python3)"
python3 --version
uv python list

ok "Python module completed."
