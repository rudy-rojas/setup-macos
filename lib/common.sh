#!/usr/bin/env bash
# =============================================================================
# lib/common.sh — helpers compartidos para los módulos de setup-macos
# Idempotente y arch-aware. Se sourcea desde setup.sh y desde cada módulo:
#   HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
#   source "$HERE/../lib/common.sh"
# Compatible con el bash 3.2 de macOS (sin arrays asociativos ni mapfile).
# =============================================================================
set -euo pipefail

# ── Colores / logging ────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  C_RST=$'\033[0m'; C_BLU=$'\033[34m'; C_GRN=$'\033[32m'
  C_YLW=$'\033[33m'; C_RED=$'\033[31m'; C_DIM=$'\033[2m'; C_BLD=$'\033[1m'
else
  C_RST=''; C_BLU=''; C_GRN=''; C_YLW=''; C_RED=''; C_DIM=''; C_BLD=''
fi
log()  { printf '%s▶%s %s\n'  "$C_BLU" "$C_RST" "$*"; }
ok()   { printf '%s✓%s %s\n'  "$C_GRN" "$C_RST" "$*"; }
warn() { printf '%s!%s %s\n'  "$C_YLW" "$C_RST" "$*" >&2; }
die()  { printf '%s✗%s %s\n'  "$C_RED" "$C_RST" "$*" >&2; exit 1; }
step() { printf '\n%s━━ %s%s %s━━%s\n' "$C_BLU$C_BLD" "$*" "$C_RST" "$C_BLU$C_BLD" "$C_RST"; }

# ── Plataforma / arquitectura ────────────────────────────────────────────────
[[ "$(uname -s)" == "Darwin" ]] || die "setup-macos es solo para macOS."
ARCH="$(uname -m)"
# Prefiere un brew YA instalado (robusto bajo Rosetta: un shell x86_64 en Apple
# Silicon reporta x86_64 aunque el brew nativo viva en /opt/homebrew). Si todavía
# no hay brew (equipo nuevo), decide el prefijo por arquitectura.
if   [[ -x /opt/homebrew/bin/brew ]]; then BREW_PREFIX="/opt/homebrew"
elif [[ -x /usr/local/bin/brew   ]]; then BREW_PREFIX="/usr/local"
else
  case "$ARCH" in
    arm64)  BREW_PREFIX="/opt/homebrew" ;;   # Apple Silicon
    x86_64) BREW_PREFIX="/usr/local"    ;;   # Intel
    *)      die "Arquitectura no soportada: $ARCH" ;;
  esac
fi
BREW="$BREW_PREFIX/bin/brew"

# Archivos de init de zsh — respeta ZDOTDIR igual que el instalador de Homebrew.
# (Si ZDOTDIR está definido, ~/.zprofile NUNCA se sourcea y brew no llegaría al PATH.)
ZDOTDIR_EFF="${ZDOTDIR:-$HOME}"
ZPROFILE="$ZDOTDIR_EFF/.zprofile"
ZSHRC="$ZDOTDIR_EFF/.zshrc"

# ── Utilidades base ──────────────────────────────────────────────────────────
need_cmd() { command -v "$1" >/dev/null 2>&1; }

# Carga Homebrew en la sesión ACTUAL del script (para usar brew/binarios ya).
load_brew() {
  [[ -x "$BREW" ]] || die "Homebrew no está en $BREW (corre primero el módulo 02)."
  eval "$("$BREW" shellenv)"
}

# Añade una línea a un archivo SOLO si aún no existe (idempotencia de dotfiles).
#   append_once <archivo> <línea>
append_once() {
  local file="$1" line="$2"
  [[ -e "$file" ]] || { mkdir -p "$(dirname "$file")"; : > "$file"; }
  if grep -qsF -- "$line" "$file"; then
    return 0
  fi
  printf '%s\n' "$line" >> "$file"
  ok "añadido a $(basename "$file"): ${C_DIM}${line}${C_RST}"
}

# ── Homebrew: instalar solo si falta ─────────────────────────────────────────
brew_ensure() {                       # brew_ensure formula1 formula2 ...
  local f
  for f in "$@"; do
    if "$BREW" list --formula --versions "$f" >/dev/null 2>&1; then
      ok "brew: $f (ya instalado)"
    else
      log "brew install $f"; "$BREW" install "$f"
    fi
  done
}
cask_ensure() {                       # cask_ensure cask1 cask2 ...
  local c
  for c in "$@"; do
    if "$BREW" list --cask --versions "$c" >/dev/null 2>&1; then
      ok "cask: $c (ya instalado)"
    else
      log "brew install --cask $c"; "$BREW" install --cask "$c"
    fi
  done
}
tap_ensure() {                        # tap_ensure user/repo
  local t="$1"
  if "$BREW" tap | grep -qxF "$t"; then ok "tap: $t (ya añadido)"
  else log "brew tap $t"; "$BREW" tap "$t"; fi
}

# Instala desde un Brewfile (idempotente por diseño).
bundle_install() {                    # bundle_install /ruta/al/Brewfile
  local file="$1"
  [[ -f "$file" ]] || die "No existe el Brewfile: $file"
  log "brew bundle install --file=$file"
  "$BREW" bundle install --file="$file"
}

# ── Servicios brew: iniciar solo si no está corriendo ────────────────────────
service_ensure() {                    # service_ensure postgresql@16
  local svc="$1"
  if "$BREW" services list | awk -v s="$svc" '$1==s && $2=="started"{found=1} END{exit found?0:1}'; then
    ok "servicio $svc (ya corriendo)"
  else
    log "brew services start $svc"; "$BREW" services start "$svc"
  fi
}
