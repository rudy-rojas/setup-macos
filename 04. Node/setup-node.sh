#!/usr/bin/env bash
# =============================================================================
# 04. Node — fnm + Node LTS + pnpm (arch-aware).
# fnm manages the Node versions; pnpm is installed via the method each
# architecture supports (the standalone script does NOT support Intel/darwin-x64).
# corepack is NOT used: it is being removed from the Node core in 25+.
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HERE/../lib/common.sh"
load_brew

step "Node (fnm + pnpm)"

# 1. fnm (Node version manager).
brew_ensure fnm

# 2. fnm hook in ~/.zshrc (interactive shell; --use-on-cd needs the chpwd hook), once.
append_once "$ZSHRC" 'eval "$(fnm env --use-on-cd --shell zsh)"'

# 3. Activate fnm in the current script session (this script runs in BASH).
#    We use --shell bash, NOT zsh: the zsh hook for --use-on-cd emits 'autoload'/
#    'add-zsh-hook' (zsh-only builtins) and blows up in bash. The interactive hook
#    for zsh is already in ~/.zshrc (step 2); here we only need fnm on the PATH.
eval "$(fnm env --shell bash)"

# 4. Install Node LTS, activate it and pin it as the default.
#    'fnm install' accepts --lts, but 'fnm use'/'default' do NOT (at least in 1.39).
#    'install --lts' leaves the 'lts-latest' alias; we use it to activate and pin,
#    with a fallback to the highest installed version if that alias did not exist.
log "fnm install --lts…"
fnm install --lts
if fnm use lts-latest 2>/dev/null; then
  fnm default lts-latest
else
  NODE_LTS="$(fnm ls 2>/dev/null | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+' | sort -V | tail -n1)"
  [[ -n "$NODE_LTS" ]] || die "Could not determine the Node version installed by fnm."
  fnm use "$NODE_LTS"
  fnm default "$NODE_LTS"
fi
ok "node $(node -v) / npm $(npm -v)"

# 5. pnpm — method depends on architecture.
if need_cmd pnpm; then
  ok "pnpm already installed ($(pnpm -v))"
elif [[ "$ARCH" == "arm64" ]]; then
  log "Installing pnpm (standalone script, independent of Node)…"
  curl -fsSL https://get.pnpm.io/install.sh | sh -
else
  log "Intel (darwin-x64): installing pnpm via brew (the standalone script does not support it)…"
  brew_ensure pnpm
fi

# 6. Verify.
if need_cmd pnpm; then
  ok "pnpm $(pnpm -v)"
else
  warn "pnpm installed; open a new terminal so PNPM_HOME is added to the PATH."
fi

ok "Node module completed."
