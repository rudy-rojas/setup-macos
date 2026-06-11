#!/usr/bin/env bash
# =============================================================================
# 06. VS Code — cask + extensions (idempotent) + settings (merge without clobbering).
# The settings.json merge uses jq (.[0]*.[1]): it preserves your keys and manages
# only ours (format on save, Prettier, ESLint).
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HERE/../lib/common.sh"
load_brew

step "VS Code"

# 1. VS Code (--adopt: adopts a copy already dragged into /Applications instead of failing).
if "$BREW" list --cask visual-studio-code >/dev/null 2>&1; then
  ok "VS Code already installed"
else
  log "brew install --cask --adopt visual-studio-code"
  "$BREW" install --cask --adopt visual-studio-code
fi

# 2. Ensure the 'code' CLI is on the PATH (provided by the cask; fallback to the bundle).
command -v code >/dev/null 2>&1 || export PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin:$PATH"
require_cmd code "open VS Code once so it installs the 'code' CLI, then retry."

# 2b. Make VS Code git's editor now that the 'code' CLI is guaranteed present.
#     Module 05 (Git) runs before this one, so it can't set this without risking a
#     'code' that isn't installed yet; we set it here instead (git comes from 05).
if need_cmd git; then git config --global core.editor "code --wait"; ok "git core.editor = code --wait"; fi

# 3. Essential extensions of the TNB stack (idempotent).
EXTS=(
  anthropic.claude-code        # Claude Code integration
  dbaeumer.vscode-eslint       # ESLint
  esbenp.prettier-vscode       # Prettier
  bradlc.vscode-tailwindcss    # Tailwind (PLUS)
  expo.vscode-expo-tools       # Expo / React Native (tnb-mobile)
)
# Cache the installed list once (whole-line, case-insensitive, fixed-string match)
# instead of invoking 'code --list-extensions' once per extension.
INSTALLED_EXTS="$(code --list-extensions 2>/dev/null)"
for ext in "${EXTS[@]}"; do
  if printf '%s\n' "$INSTALLED_EXTS" | grep -qixF -- "$ext"; then
    ok "ext: $ext (already)"
  else
    log "code --install-extension $ext"; code --install-extension "$ext"
  fi
done

# 4. settings.json: deep merge with jq (preserves what already exists).
need_cmd jq || brew_ensure jq
SETTINGS="$HOME/Library/Application Support/Code/User/settings.json"
mkdir -p "$(dirname "$SETTINGS")"
[[ -s "$SETTINGS" ]] || printf '{}' > "$SETTINGS"
DESIRED='{"editor.formatOnSave":true,"editor.defaultFormatter":"esbenp.prettier-vscode","editor.codeActionsOnSave":{"source.fixAll.eslint":"explicit"},"eslint.format.enable":false,"[javascript]":{"editor.defaultFormatter":"esbenp.prettier-vscode"},"[typescript]":{"editor.defaultFormatter":"esbenp.prettier-vscode"},"[typescriptreact]":{"editor.defaultFormatter":"esbenp.prettier-vscode"},"[json]":{"editor.defaultFormatter":"esbenp.prettier-vscode"}}'
tmp="$(mktemp)"
if jq -s '.[0] * .[1]' "$SETTINGS" <(printf '%s' "$DESIRED") > "$tmp" 2>/dev/null; then
  mv "$tmp" "$SETTINGS"; ok "settings.json updated (merge: your keys preserved)"
else
  rm -f "$tmp"
  warn "settings.json is not strict JSON (// comments?); left it unchanged. Apply the settings by hand or remove the comments."
fi

ok "VS Code module completed."
