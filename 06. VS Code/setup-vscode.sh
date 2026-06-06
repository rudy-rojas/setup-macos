#!/usr/bin/env bash
# =============================================================================
# 06. VS Code — cask + extensiones (idempotente) + settings (merge sin pisar).
# El merge de settings.json usa jq (.[0]*.[1]): preserva tus claves, gestiona
# solo las nuestras (format on save, Prettier, ESLint).
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HERE/../lib/common.sh"
load_brew

step "VS Code"

# 1. VS Code (--adopt: adopta una copia arrastrada a /Applications en vez de fallar).
if "$BREW" list --cask visual-studio-code >/dev/null 2>&1; then
  ok "VS Code ya instalado"
else
  log "brew install --cask --adopt visual-studio-code"
  "$BREW" install --cask --adopt visual-studio-code
fi

# 2. Asegurar el CLI 'code' en el PATH (lo provee el cask; fallback al bundle).
command -v code >/dev/null 2>&1 || export PATH="/Applications/Visual Studio Code.app/Contents/Resources/app/bin:$PATH"
command -v code >/dev/null 2>&1 || die "El CLI 'code' no está disponible aún (abre VS Code una vez y reintenta)."

# 3. Extensiones esenciales del stack TNB (idempotente).
EXTS=(
  anthropic.claude-code        # integración con Claude Code
  dbaeumer.vscode-eslint       # ESLint
  esbenp.prettier-vscode       # Prettier
  bradlc.vscode-tailwindcss    # Tailwind (PLUS)
  expo.vscode-expo-tools       # Expo / React Native (tnb-mobile)
)
for ext in "${EXTS[@]}"; do
  if code --list-extensions | grep -qix "$ext"; then
    ok "ext: $ext (ya)"
  else
    log "code --install-extension $ext"; code --install-extension "$ext"
  fi
done

# 4. settings.json: merge profundo con jq (preserva lo existente).
need_cmd jq || brew_ensure jq
SETTINGS="$HOME/Library/Application Support/Code/User/settings.json"
mkdir -p "$(dirname "$SETTINGS")"
[[ -s "$SETTINGS" ]] || printf '{}' > "$SETTINGS"
DESIRED='{"editor.formatOnSave":true,"editor.defaultFormatter":"esbenp.prettier-vscode","editor.codeActionsOnSave":{"source.fixAll.eslint":"explicit"},"eslint.format.enable":false,"[javascript]":{"editor.defaultFormatter":"esbenp.prettier-vscode"},"[typescript]":{"editor.defaultFormatter":"esbenp.prettier-vscode"},"[typescriptreact]":{"editor.defaultFormatter":"esbenp.prettier-vscode"},"[json]":{"editor.defaultFormatter":"esbenp.prettier-vscode"}}'
tmp="$(mktemp)"
if jq -s '.[0] * .[1]' "$SETTINGS" <(printf '%s' "$DESIRED") > "$tmp" 2>/dev/null; then
  mv "$tmp" "$SETTINGS"; ok "settings.json actualizado (merge: tus claves preservadas)"
else
  rm -f "$tmp"
  warn "settings.json no es JSON estricto (¿// comentarios?); no lo modifiqué. Aplica los ajustes a mano o quita los comentarios."
fi

ok "Módulo VS Code completado."
