#!/usr/bin/env bash
# =============================================================================
# 02. Homebrew — installs Homebrew (arch-aware) and adds it to the zsh PATH.
# Idempotent: installs only if missing and adds the shellenv line exactly once.
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HERE/../lib/common.sh"

step "Homebrew & Shell"

# 0. Ensure the Xcode Command Line Tools (a Homebrew dependency) BEFORE
#    installing brew. Idempotent: no-op if CLT or the full Xcode is already present.
ensure_clt

# 1. Install Homebrew only if missing (non-interactive, no prompts).
if [[ -x "$BREW" ]]; then
  ok "Homebrew already installed at $BREW"
else
  log "Installing Homebrew at $BREW_PREFIX (non-interactive)…"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  [[ -x "$BREW" ]] || die "The Homebrew installation did not place the binary at $BREW."
fi

# 2. Add 'brew shellenv' to the zsh login (respects ZDOTDIR), exactly once.
#    Uses the absolute brew path so arm64/x86_64 generate their correct line.
append_once "$ZPROFILE" "eval \"\$($BREW shellenv)\""

# 3. Activate brew in the current script session (no need to reopen the terminal).
load_brew
ok "brew $("$BREW" --version | head -1 | awk '{print $2}') active"

# 4. Update indexes and install the base CLI tools.
log "brew update…"
"$BREW" update >/dev/null 2>&1 || warn "brew update returned a warning (continuing)"
brew_ensure jq tree            # jq is used by later modules (e.g. 06 VS Code)

ok "Homebrew module completed."
