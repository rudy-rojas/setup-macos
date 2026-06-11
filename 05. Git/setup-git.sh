#!/usr/bin/env bash
# =============================================================================
# 05. Git & GitHub — git + gh, TNB global config and auth (only if missing).
# Identity configurable with GIT_USER_NAME / GIT_USER_EMAIL.
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HERE/../lib/common.sh"
load_brew

step "Git & GitHub"

# 1. git + gh + jq (brew install is idempotent; jq is used by module 06).
brew_ensure git gh jq

# 2. Global config. The identity must NOT clobber a personal one already set on the
#    machine: only an EXPLICIT override (GIT_USER_NAME/_EMAIL in setup.env or inline)
#    wins; otherwise an existing value is kept, and the TNB default is applied only
#    when nothing is configured yet.
apply_git_identity() {           # apply_git_identity <key> <env-override> <tnb-default>
  local key="$1" override="$2" def="$3" cur
  cur="$(git config --global --get "$key" 2>/dev/null || true)"
  if [[ -n "$override" ]]; then
    git config --global "$key" "$override"; ok "git $key = $override (from setup.env/inline)"
  elif [[ -n "$cur" ]]; then
    ok "git $key kept (existing: $cur)"
  else
    git config --global "$key" "$def"; ok "git $key = $def (TNB default)"
  fi
}
apply_git_identity user.name  "${GIT_USER_NAME:-}"  "TheNationalBuilders"
apply_git_identity user.email "${GIT_USER_EMAIL:-}" "tnb@thenationalbuilders.com"

# These are project conventions (not personal), safe to set unconditionally.
git config --global init.defaultBranch main
git config --global pull.rebase false
ok "global git conventions applied (init.defaultBranch, pull.rebase)"
# core.editor ("code --wait") is set by module 06, where the 'code' CLI is
# guaranteed present — this module runs before VS Code is installed, so setting it
# here would point git at a 'code' that may not exist yet.

# 3. GitHub authentication ONLY if missing. In an orchestrated run it is DEFERRED
#    to the end (request_auth) so as not to interrupt the install; when run alone it
#    runs immediately. Idempotent: no re-prompt if already authenticated.
if gh auth status --hostname github.com >/dev/null 2>&1; then
  ok "gh already authenticated on github.com"
else
  request_auth github
fi

ok "Git & GitHub module completed."
