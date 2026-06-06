#!/usr/bin/env bash
# =============================================================================
# 02. Homebrew — instala Homebrew (arch-aware) y lo deja en el PATH de zsh.
# Idempotente: instala solo si falta y añade la línea de shellenv una sola vez.
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HERE/../lib/common.sh"

step "Homebrew & Shell"

# 1. Instalar Homebrew solo si falta (no interactivo, sin prompts).
if [[ -x "$BREW" ]]; then
  ok "Homebrew ya instalado en $BREW"
else
  log "Instalando Homebrew en $BREW_PREFIX (no interactivo)…"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  [[ -x "$BREW" ]] || die "La instalación de Homebrew no dejó el binario en $BREW."
fi

# 2. Dejar 'brew shellenv' en el login de zsh (respeta ZDOTDIR), exactamente una vez.
#    Usa la ruta absoluta de brew para que arm64/x86_64 generen su línea correcta.
append_once "$ZPROFILE" "eval \"\$($BREW shellenv)\""

# 3. Activar brew en la sesión actual del script (sin reabrir terminal).
load_brew
ok "brew $("$BREW" --version | head -1 | awk '{print $2}') activo"

# 4. Actualizar índices e instalar CLI base.
log "brew update…"
"$BREW" update >/dev/null 2>&1 || warn "brew update devolvió un aviso (continúo)"
brew_ensure jq tree            # jq lo usan módulos posteriores (p. ej. 06 VS Code)

ok "Módulo Homebrew completado."
