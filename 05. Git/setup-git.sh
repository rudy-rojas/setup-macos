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

GIT_USER_NAME="${GIT_USER_NAME:-TheNationalBuilders}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-tnb@thenationalbuilders.com}"

# 1. git + gh + jq (brew install is idempotent; jq is used by module 06).
brew_ensure git gh jq

# 2. Global config (git config --global is idempotent: it overwrites the value).
git config --global user.name  "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.editor "code --wait"
ok "global git config applied ($GIT_USER_NAME <$GIT_USER_EMAIL>)"

# 3. GitHub authentication ONLY if missing. In an orchestrated run it is DEFERRED
#    to the end (request_auth) so as not to interrupt the install; when run alone it
#    runs immediately. Idempotent: no re-prompt if already authenticated.
if gh auth status --hostname github.com >/dev/null 2>&1; then
  ok "gh already authenticated on github.com"
else
  request_auth github
fi

ok "Git & GitHub module completed."
