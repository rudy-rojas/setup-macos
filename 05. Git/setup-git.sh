#!/usr/bin/env bash
# =============================================================================
# 05. Git & GitHub — git + gh, config global de TNB y auth (solo si falta).
# Identidad configurable con GIT_USER_NAME / GIT_USER_EMAIL.
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HERE/../lib/common.sh"
load_brew

step "Git & GitHub"

GIT_USER_NAME="${GIT_USER_NAME:-TheNationalBuilders}"
GIT_USER_EMAIL="${GIT_USER_EMAIL:-tnb@thenationalbuilders.com}"

# 1. git + gh + jq (brew install es idempotente; jq lo usa el módulo 06).
brew_ensure git gh jq

# 2. Config global (git config --global es idempotente: sobrescribe el valor).
git config --global user.name  "$GIT_USER_NAME"
git config --global user.email "$GIT_USER_EMAIL"
git config --global init.defaultBranch main
git config --global pull.rebase false
git config --global core.editor "code --wait"
ok "git config global aplicado ($GIT_USER_NAME <$GIT_USER_EMAIL>)"

# 3. Autenticación de GitHub SOLO si no está autenticado (no re-prompt).
if gh auth status --hostname github.com >/dev/null 2>&1; then
  ok "gh ya autenticado en github.com"
else
  warn "gh no autenticado → abriendo login web (paso interactivo)…"
  gh auth login --hostname github.com --git-protocol https --web
fi

ok "Módulo Git & GitHub completado."
