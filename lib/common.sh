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

# ── Privilegios: una sola contraseña para toda la corrida ────────────────────
# Pide la contraseña UNA vez y, mientras dura el setup, instala un drop-in
# temporal en /etc/sudoers.d para que ni Homebrew, ni los Command Line Tools, ni
# los instaladores .pkg de los casks (p. ej. zulu@17) la vuelvan a pedir — macOS
# NO siempre honra el timestamp de sudo para esos .pkg, así que un keep-alive del
# timestamp no basta. El drop-in:
#   • usa un nombre FIJO (idempotente): un sobrante de una corrida abortada se
#     detecta y se reemplaza/elimina, no se acumula;
#   • se valida con `visudo -cf` ANTES de instalarse (un sudoers inválido podría
#     dejarte sin sudo); si no valida, se omite (los .pkg pedirán contraseña);
#   • se elimina SIEMPRE al salir (trap EXIT del orquestador) vía sudo_session_end.
# Limpieza manual si una corrida muere con kill -9:  sudo rm -f /etc/sudoers.d/setup-macos
SUDO_DROPIN="/etc/sudoers.d/setup-macos"

# Elimina el drop-in si existe. Idempotente y robusto: avisa si no pudo borrarlo.
sudo_session_end() {
  [[ -e "$SUDO_DROPIN" ]] || return 0
  if sudo rm -f "$SUDO_DROPIN" 2>/dev/null; then
    ok "sudoers temporal eliminado ($SUDO_DROPIN)"
  else
    warn "no pude eliminar $SUDO_DROPIN — bórralo a mano con: sudo rm -f $SUDO_DROPIN"
  fi
}
sudo_session_begin() {
  need_cmd sudo || { warn "sudo no disponible; algunos pasos podrían fallar."; return 0; }
  log "se pedirá tu contraseña una sola vez para toda la instalación…"
  sudo -v || die "Se requiere acceso sudo (Homebrew, Command Line Tools, casks .pkg)."
  # Reemplaza cualquier sobrante de una corrida previa (idempotente).
  sudo rm -f "$SUDO_DROPIN" 2>/dev/null || true
  local tmp; tmp="$(mktemp -t setup-macos-sudoers)"
  printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$(id -un)" > "$tmp"; chmod 0440 "$tmp"
  # Todo el alta en el 'if' para que un fallo parcial no dispare set -e.
  if sudo visudo -cf "$tmp" >/dev/null 2>&1 \
     && sudo cp "$tmp" "$SUDO_DROPIN" \
     && sudo chown root:wheel "$SUDO_DROPIN" \
     && sudo chmod 0440 "$SUDO_DROPIN"; then
    ok "sudo sin re-prompt activado durante el setup (se quita al terminar)"
  else
    warn "no pude activar el sudoers temporal; sigo sin él (los casks .pkg podrían pedir contraseña)."
    sudo rm -f "$SUDO_DROPIN" 2>/dev/null || true
  fi
  rm -f "$tmp"
}

# ── Autenticación (diferible al final del setup) ─────────────────────────────
# El orquestador difiere las autenticaciones INTERACTIVAS (p. ej. el login web de
# GitHub) para que NO interrumpan la instalación: cada módulo encola un "token"
# con request_auth y setup.sh ejecuta la cola al final con run_deferred_auth. Si
# no hay orquestador (módulo corrido en solitario), request_auth se ejecuta ya.
# OJO: el password de sudo NO entra aquí — hace falta DURANTE la instalación
# (Homebrew/CLT) y por eso no puede diferirse; eso lo cubre sudo_session_begin.

# Login de GitHub idempotente (no re-prompt si ya está autenticado).
gh_auth_ensure() {
  need_cmd gh || { warn "gh no instalado; omito la autenticación de GitHub."; return 0; }
  if gh auth status --hostname github.com >/dev/null 2>&1; then
    ok "gh ya autenticado en github.com"
  else
    warn "gh no autenticado → abriendo login web (paso interactivo)…"
    gh auth login --hostname github.com --git-protocol https --web
  fi
}

# Ejecuta la autenticación correspondiente a un token.
run_auth() {
  case "$1" in
    github) gh_auth_ensure ;;
    *)      warn "autenticación desconocida: $1" ;;
  esac
}

# Encola una autenticación para el FINAL si el orquestador habilitó la cola
# (SETUP_AUTH_QUEUE); si no, la ejecuta de inmediato.   request_auth <token>
request_auth() {
  local token="$1" q="${SETUP_AUTH_QUEUE:-}"
  if [[ -n "$q" && -w "$q" ]]; then
    grep -qxF "$token" "$q" 2>/dev/null || printf '%s\n' "$token" >> "$q"
    log "autenticación de '$token' diferida al final del setup."
  else
    run_auth "$token"
  fi
}

# Ejecuta al final todas las autenticaciones encoladas (sin duplicar).
run_deferred_auth() {
  local q="${SETUP_AUTH_QUEUE:-}" token
  [[ -n "$q" && -s "$q" ]] || return 0
  step "Autenticación (al final, ya instalado todo)"
  while IFS= read -r token; do
    [[ -n "$token" ]] && run_auth "$token"
  done < "$q"
}

# ── Command Line Tools de Xcode ──────────────────────────────────────────────
# Homebrew necesita las CLT (clang, headers, git). Las instala SOLO si faltan,
# de forma desatendida (softwareupdate) y, si eso no es posible, cae al instalador
# gráfico de Apple (xcode-select --install). Un Xcode completo también las provee,
# así que si ya hay un toolchain válido esto es no-op. (El Xcode completo se maneja
# aparte en el módulo 12 iOS; aquí solo garantizamos la dependencia de brew.)
clt_present() {
  local dir
  dir="$(xcode-select -p 2>/dev/null)" || return 1
  [[ -n "$dir" && -d "$dir" ]]
}
ensure_clt() {
  if clt_present; then
    ok "Command Line Tools / Xcode ya presentes ($(xcode-select -p))"
    return 0
  fi

  log "instalando los Command Line Tools de Xcode (desatendido)…"
  # Truco soportado por Apple: este archivo-bandera hace que 'softwareupdate -l'
  # liste las CLT como un update instalable sin abrir la GUI.
  local flag="/tmp/.com.apple.dt.CommandLineTools.installondemand.in-progress"
  touch "$flag"
  local label
  label="$(softwareupdate -l 2>/dev/null \
            | awk -F'Label: ' '/Label: Command Line Tools/{print $2}' \
            | sort -V | tail -n1)"
  local installed=1
  if [[ -n "$label" ]]; then
    log "softwareupdate -i \"$label\""
    if sudo softwareupdate -i "$label" --verbose; then installed=0; fi
  fi
  rm -f "$flag"

  # Fallback: instalador gráfico de Apple + espera a que el usuario lo complete.
  if [[ "$installed" -ne 0 ]] || ! clt_present; then
    warn "vía desatendida no disponible; abriendo el instalador gráfico de Apple…"
    xcode-select --install >/dev/null 2>&1 || true
    log "esperando a que termine la instalación de los Command Line Tools…"
    until clt_present; do sleep 5; done
  fi

  clt_present || die "No se pudieron instalar los Command Line Tools de Xcode."
  ok "Command Line Tools instalados ($(xcode-select -p))"
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
