#!/usr/bin/env bash
# =============================================================================
# 04. Node — fnm + Node LTS + pnpm (arch-aware).
# fnm gestiona las versiones de Node; pnpm se instala por el método que soporta
# cada arquitectura (el script standalone NO soporta Intel/darwin-x64).
# NO se usa corepack: se retira del core de Node en la 25+.
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HERE/../lib/common.sh"
load_brew

step "Node (fnm + pnpm)"

# 1. fnm (gestor de versiones de Node).
brew_ensure fnm

# 2. Hook de fnm en ~/.zshrc (shell interactivo; --use-on-cd necesita el hook chpwd), una vez.
append_once "$ZSHRC" 'eval "$(fnm env --use-on-cd --shell zsh)"'

# 3. Activar fnm en la sesión actual del script (este script corre en BASH).
#    Usamos --shell bash, NO zsh: el hook zsh de --use-on-cd emite 'autoload'/
#    'add-zsh-hook' (builtins solo de zsh) y revientan en bash. El hook interactivo
#    para zsh ya quedó en ~/.zshrc (paso 2); aquí solo necesitamos fnm en el PATH.
eval "$(fnm env --shell bash)"

# 4. Instalar Node LTS, activarlo y fijarlo como default.
log "fnm install --lts…"
fnm install --lts
fnm use --lts                        # IMPRESCINDIBLE: 'install' no activa el LTS en esta sesión
fnm default "$(fnm current)"         # fija el LTS activo (NO usar 'lts-latest': ese alias no existe)
ok "node $(node -v) / npm $(npm -v)"

# 5. pnpm — método según arquitectura.
if need_cmd pnpm; then
  ok "pnpm ya instalado ($(pnpm -v))"
elif [[ "$ARCH" == "arm64" ]]; then
  log "Instalando pnpm (script standalone, independiente de Node)…"
  curl -fsSL https://get.pnpm.io/install.sh | sh -
else
  log "Intel (darwin-x64): instalando pnpm vía brew (el script standalone no lo soporta)…"
  brew_ensure pnpm
fi

# 6. Verificar.
if need_cmd pnpm; then
  ok "pnpm $(pnpm -v)"
else
  warn "pnpm instalado; abre una terminal nueva para que PNPM_HOME entre en el PATH."
fi

ok "Módulo Node completado."
