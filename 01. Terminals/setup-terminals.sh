#!/usr/bin/env bash
# ╔════════════════════════════════════════════════════════════════════╗
# ║  setup-terminal.sh — Modern, unified terminal environment (macOS)  ║
# ║                                                                    ║
# ║  • Alacritty  → Tokyo Night theme                                  ║
# ║  • iTerm2     → Ayu Mirage theme (dynamic profile, amber cursor)   ║
# ║  • Terminal   → Gruvbox theme (native profile)                     ║
# ║  • Shared font: JetBrainsMono Nerd Font (unified visual identity)  ║
# ║  • Extras: Starship, lsd, zsh-syntax-highlighting                  ║
# ║                                                                    ║
# ║  Features: idempotent · automatic backups · thorough validation ·  ║
# ║  robust error handling · detailed logging.                         ║
# ╚════════════════════════════════════════════════════════════════════╝
#
# Usage:
#   ./setup-terminal.sh [options]
#
# Options:
#   -h, --help        Show this help and exit.
#   -v, --version     Show the script version and exit.
#       --no-color    Disable colored output.
#
# Notes:
#   • The script is safe to run multiple times (idempotent).
#   • Any modified file is backed up to ~/.terminal-setup-backups/.
#   • Close Terminal.app before running so the profile persists.
# ---------------------------------------------------------------------------

# ── Strict mode ─────────────────────────────────────────────────────────────
# -e            : abort on the first command that fails.
# -u            : treat unset variables as an error.
# -o pipefail   : a pipeline fails if any stage fails, not just the last.
# -E (errtrace) : the ERR trap is inherited by functions/subshells, so on_error
#                 actually fires for failures inside functions (where all the
#                 real work happens), not only at top level.
set -Eeuo pipefail
IFS=$'\n\t'

# ── Shared library (setup-macos) ────────────────────────────────────────────
# Pull in the common helpers — chiefly the arch-aware Homebrew detection
# ($BREW / $BREW_PREFIX), shared with the rest of the setup.sh modules. This
# module keeps its own richer logging, traps, backups and step numbering; it
# only borrows the brew-detection base so all modules agree on the prefix.
_TERM_HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
# shellcheck source=../lib/common.sh
source "${_TERM_HERE}/../lib/common.sh"

# ── Metadata ────────────────────────────────────────────────────────────────
readonly SCRIPT_VERSION="2.6.0"
readonly SCRIPT_NAME="${0##*/}"

# ── Shared visual identity (single source of truth) ─────────────────────────
# Font shared by all three terminals for a consistent experience.
readonly FONT_CASK="font-jetbrains-mono-nerd-font"
readonly FONT_FAMILY="JetBrainsMono Nerd Font"           # Family name (Alacritty)
readonly FONT_PS_DEFAULT="JetBrainsMonoNerdFont-Regular" # Fallback if it can't be resolved
FONT_PS="${FONT_PS_DEFAULT}"                             # PostScript name (resolved at runtime)
readonly FONT_SIZE="14"

# Shared window opacity (0 = transparent, 1 = opaque) for all 3 terminals.
readonly OPACITY="0.75"

# Default window size (columns x rows) for all 3 terminals.
readonly COLS="140"
readonly ROWS="23"

# Names of the profiles created in each app.
readonly ITERM_PROFILE_NAME="Ayu Mirage"
readonly ITERM_GUID="ayu-mirage-unified-0001"       # Stable GUID → idempotency
readonly TERMINAL_PROFILE_NAME="Gruvbox"

# Homebrew formulae to install (casks are handled in install_dependencies).
readonly FORMULAE=("lsd" "starship" "zsh-syntax-highlighting")

# ── Working paths ───────────────────────────────────────────────────────────
readonly ALACRITTY_DIR="${HOME}/.config/alacritty"
readonly ALACRITTY_CONF="${ALACRITTY_DIR}/alacritty.toml"
readonly STARSHIP_CONF="${HOME}/.config/starship.toml"
# Gruvbox variant of the Starship config (orange path); used only by Terminal.app.
readonly STARSHIP_GRUVBOX_CONF="${HOME}/.config/starship-gruvbox.toml"
readonly LSD_DIR="${HOME}/.config/lsd"
readonly LSD_ICONS_CONF="${LSD_DIR}/icons.yaml"
readonly ITERM_PROFILE_DIR="${HOME}/Library/Application Support/iTerm2/DynamicProfiles"
readonly ITERM_PROFILE_FILE="${ITERM_PROFILE_DIR}/ayu-mirage.json"
# Profile files created by previous versions (removed on run).
readonly ITERM_PROFILE_LEGACY=("${ITERM_PROFILE_DIR}/tokyo-night.json")
readonly TERMINAL_PLIST="${HOME}/Library/Preferences/com.apple.Terminal.plist"
readonly ZSHRC="${HOME}/.zshrc"
readonly ZSHRC_MARKER_START="# >>> terminal-setup >>>"
readonly ZSHRC_MARKER_END="# <<< terminal-setup <<<"

# Backup directory (created only if something is backed up) and log.
RUN_STAMP="$(date +%Y%m%d-%H%M%S)"; readonly RUN_STAMP
readonly BACKUP_ROOT="${HOME}/.terminal-setup-backups/${RUN_STAMP}"
readonly LOG_FILE="${TMPDIR:-/tmp}/terminal-setup-${RUN_STAMP}.log"

# Python helper script (generated at runtime).
GEN_PY=""                 # Path assigned in main().
PYTHON_BIN=""             # Basic interpreter (JSON tasks, no AppKit).
PYTHON_APPKIT=""          # Interpreter with AppKit/pyobjc (Terminal.app and font).

# Global state.
USE_COLOR=1
TERMINAL_ONLY=0           # --terminal-only: re-apply ONLY the Terminal.app profile.
BACKUP_MADE=0
declare -a WARNINGS=()    # Accumulates non-fatal warnings for the final summary.
STEP=0
# Color vars default to empty so the loggers and the ERR trap are safe under
# `set -u` even before init_colors() runs (the trap is armed earlier, in main).
RESET=''; BOLD=''; DIM=''; RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''

# ── Colors and logging ──────────────────────────────────────────────────────
init_colors() {
  if [[ "${USE_COLOR}" -eq 1 && -t 1 ]]; then
    RESET=$'\033[0m'; BOLD=$'\033[1m'; DIM=$'\033[2m'
    RED=$'\033[0;31m'; GREEN=$'\033[0;32m'
    YELLOW=$'\033[0;33m'; BLUE=$'\033[0;34m'; CYAN=$'\033[0;36m'
  else
    RESET=""; BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; CYAN=""
  fi
}

# Write to the log file (color-free) and to the console.
# Strip ANSI escapes from the message so the log stays clean even if a caller
# embedded color vars in it; the console copy keeps its color.
_log_file() {
  local _msg; _msg="$(printf '%s' "$2" | LC_ALL=C sed $'s/\033\\[[0-9;]*m//g')"
  printf '%s [%s] %s\n' "$(date '+%H:%M:%S')" "$1" "${_msg}" >>"${LOG_FILE}"
}

# Console label and log tag match (e.g. [FAIL] ↔ FAIL) so grepping the log for
# what you saw on screen works.
info()    { _log_file "INFO" "$1"; printf '%s%s[INFO]%s  %s\n'  "${BLUE}"  "${BOLD}" "${RESET}" "$1"; }
success() { _log_file "OK"   "$1"; printf '%s%s[ OK ]%s  %s\n'  "${GREEN}" "${BOLD}" "${RESET}" "$1"; }
warning() { _log_file "WARN" "$1"; printf '%s%s[WARN]%s  %s\n'  "${YELLOW}" "${BOLD}" "${RESET}" "$1"; WARNINGS+=("$1"); }
error()   { _log_file "FAIL" "$1"; printf '%s%s[FAIL]%s  %s\n'  "${RED}"   "${BOLD}" "${RESET}" "$1" >&2; }
step()    { STEP=$((STEP + 1)); _log_file "STEP" "$1"; printf '\n%s%s── %d. %s%s\n' "${CYAN}" "${BOLD}" "${STEP}" "$1" "${RESET}"; }

# ── Error handling ──────────────────────────────────────────────────────────
# Trap fired on any failed command (thanks to `set -e`).
on_error() {
  local exit_code=$?
  local line_no=$1
  error "Unexpected failure (line ${line_no}, code ${exit_code})."
  error "Command: ${BASH_COMMAND}"
  error "Full log at: ${LOG_FILE}"
  [[ "${BACKUP_MADE}" -eq 1 ]] && error "Your previous configs are safe at: ${BACKUP_ROOT}"
  exit "${exit_code}"
}
trap 'on_error ${LINENO}' ERR

# Cleanup on exit (always runs).
on_exit() {
  [[ -n "${GEN_PY}" && -f "${GEN_PY}" ]] && rm -f "${GEN_PY}"
  return 0
}
trap on_exit EXIT

# ── General utilities ───────────────────────────────────────────────────────
have() { command -v "$1" >/dev/null 2>&1; }

ensure_dir() { [[ -d "$1" ]] || mkdir -p "$1"; }

# Are Xcode's Command Line Tools installed?
clt_present() { xcode-select -p >/dev/null 2>&1; }

# Ask the user a yes/no question (default No). Only interacts if there's a TTY;
# in non-interactive runs it returns the default without blocking.
# Usage: ask_yes_no "Question" && do_something
ask_yes_no() {
  local prompt="$1" reply=""
  if [[ ! -t 0 ]]; then
    info "Non-interactive input; assuming 'No' for: ${prompt}"
    return 1
  fi
  printf '%s%s%s [y/N]: ' "${BOLD}" "${prompt}" "${RESET}" >&2
  read -r reply || true
  [[ "${reply}" =~ ^[yY]$ ]]
}

# Back up a file (if it exists) to today's backup directory.
backup_file() {
  local src="$1"
  [[ -e "${src}" ]] || return 0
  ensure_dir "${BACKUP_ROOT}"
  local rel="${src#"${HOME}"/}"
  local dest="${BACKUP_ROOT}/${rel//\//__}"
  cp -p "${src}" "${dest}"
  BACKUP_MADE=1
  info "Backup created: ${DIM}${src}${RESET} → ${dest}"
}

# Write content (from stdin) to a file, backing up the previous one.
write_file() {
  local dest="$1"
  ensure_dir "$(dirname "${dest}")"
  backup_file "${dest}"
  cat >"${dest}"
}

# ── 0. Command-line arguments ───────────────────────────────────────────────
print_help() {
  sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//; s/^#//'
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "${1:-}" in
      -h|--help)    print_help; exit 0 ;;
      -v|--version) printf '%s %s\n' "${SCRIPT_NAME}" "${SCRIPT_VERSION}"; exit 0 ;;
      --no-color)   USE_COLOR=0 ;;
      # Re-apply ONLY the Terminal.app profile. Used by the orchestrator after it
      # hands off to iTerm2 and closes Terminal.app, so the profile finally persists
      # (Terminal.app rewrites its prefs on quit, clobbering an earlier write).
      --terminal-only) TERMINAL_ONLY=1 ;;
      *) printf 'Unknown option: %s\n' "$1" >&2; exit 2 ;;
    esac
    shift
  done
}

# ── 1. Preflight checks ─────────────────────────────────────────────────────
preflight() {
  step "System checks"

  # 1.1 macOS only.
  if [[ "$(uname -s)" != "Darwin" ]]; then
    error "This script is designed exclusively for macOS."
    exit 1
  fi
  success "Operating system: macOS"

  # 1.2 Don't run as root (Homebrew rejects it and it breaks permissions).
  if [[ "${EUID}" -eq 0 ]]; then
    error "Do not run this script as root or with sudo."
    exit 1
  fi

  # 1.3 macOS version (warns if older than the supported minimum; never hard-fails).
  #     The threshold MACOS_MIN_MAJOR is the single source of truth in lib/common.sh.
  local ver major
  ver="$(sw_vers -productVersion 2>/dev/null || echo '0')"
  major="${ver%%.*}"
  if [[ "${major}" =~ ^[0-9]+$ ]] && (( major < MACOS_MIN_MAJOR )); then
    warning "macOS ${ver} is older than the supported minimum (macOS ${MACOS_MIN_MAJOR}); some features may vary."
  else
    success "macOS version: ${ver} (supported: macOS ${MACOS_MIN_MAJOR}+)"
  fi

  # 1.4 Basic connectivity (needed for Homebrew and downloads).
  if ! /usr/bin/nc -z -G 5 github.com 443 >/dev/null 2>&1; then
    warning "Couldn't verify the connection to github.com; continuing anyway."
  else
    success "Network connectivity verified"
  fi

  # 1.5 Xcode command-line tools (required by Homebrew and pyobjc).
  if ! clt_present; then
    warning "Xcode's Command Line Tools are not installed."
    warning "They provide compilers, git, and the AppKit-enabled Python that Terminal.app needs."
    if ask_yes_no "Do you want to install them now?"; then
      info "Launching the Command Line Tools installer..."
      xcode-select --install >/dev/null 2>&1 || true
      info "Apple's installation window has opened."
      if [[ -t 0 ]]; then
        printf '%sPress ENTER when the installation has finished...%s' "${BOLD}" "${RESET}" >&2
        read -r _ || true
      fi
      # Brief active wait in case the system is still registering the installation.
      local _w=0
      while ! clt_present && (( _w < 30 )); do sleep 2; _w=$((_w + 1)); done
      if clt_present; then
        success "Command Line Tools installed"
      else
        warning "Still not detected; the script continues and will skip whatever requires them."
      fi
    else
      warning "Continuing without them; Terminal.app and the iTerm2 font may not be configured."
    fi
  else
    success "Xcode Command Line Tools present"
  fi

  info "Log for this run: ${DIM}${LOG_FILE}${RESET}"
}

# ── 2. Homebrew ─────────────────────────────────────────────────────────────
ensure_homebrew() {
  step "Homebrew"

  if ! have brew; then
    warning "Homebrew not found. Installing in non-interactive mode..."
    NONINTERACTIVE=1 /bin/bash -c \
      "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    success "Homebrew installed"
  else
    success "Homebrew is already installed"
  fi

  # Ensure `brew` is on the PATH using the shared arch-aware detection
  # (lib/common.sh exports $BREW for both /opt/homebrew and /usr/local).
  have brew || eval "$("$BREW" shellenv)"
  have brew || { error "Couldn't locate 'brew' on the PATH after installation."; exit 1; }

  # Update the formula indexes (silent, not critical if it fails).
  info "Updating Homebrew indexes..."
  brew update >>"${LOG_FILE}" 2>&1 || warning "Couldn't update Homebrew; using the current index."
}

# ── 3. Dependency installation (idempotent) ─────────────────────────────────
brew_cask_installed()    { brew list --cask "$1" >/dev/null 2>&1; }
brew_formula_installed() { brew list --formula "$1" >/dev/null 2>&1; }

# Run a (possibly slow) brew command, retrying on a transient network failure.
# Cask/bottle downloads can stall on a flaky CDN edge; lib/common.sh sets a curl
# low-speed timeout so a stalled transfer aborts instead of hanging, and brew
# resumes the partial file on the next attempt — so a retry here is cheap and
# usually succeeds on a fresh edge (it automates the old "Ctrl-C + re-run").
# Output is appended to the log; the caller prints the human-facing status.
#   _brew_retry <label> -- brew install ...
_brew_retry() {
  local label="$1"; shift
  [[ "${1:-}" == "--" ]] && shift
  local attempt=1 max=3
  while (( attempt <= max )); do
    (( attempt > 1 )) && info "Retrying ${label} (attempt ${attempt}/${max})…"
    if "$@" >>"${LOG_FILE}" 2>&1; then
      return 0
    fi
    attempt=$(( attempt + 1 ))
    sleep 3
  done
  return 1
}

# Install a cask idempotently.
#   $1 = cask name
#   $2 = (optional) app path to detect installations made outside Homebrew
install_cask() {
  local name="$1" app_path="${2:-}"
  if brew_cask_installed "${name}"; then
    info "Cask '${name}' already managed by Homebrew, skipping."
    return 0
  fi
  # Common case: the app already exists but was installed manually (not via Homebrew).
  # Homebrew would refuse to overwrite it; we try to "adopt" it and, failing that, leave it.
  if [[ -n "${app_path}" && -d "${app_path}" ]]; then
    info "Adopting '${name}' into Homebrew (already at ${app_path})…"
    if _brew_retry "adopt ${name}" -- brew install --cask --adopt "${name}"; then
      success "Cask '${name}' adopted by Homebrew (was already installed)."
    else
      info "'${name}' is already installed at ${app_path} (outside Homebrew), leaving it."
    fi
    return 0
  fi
  info "Downloading and installing '${name}' (cask)… large apps can take a while; progress is logged."
  if _brew_retry "install cask ${name}" -- brew install --cask "${name}"; then
    success "Installed (cask): ${name}"
  else
    warning "Couldn't install cask '${name}'. Check the log: ${LOG_FILE}"
  fi
}

install_formula() {
  local name="$1"
  if brew_formula_installed "${name}"; then
    info "Formula '${name}' already installed, skipping."
  elif _brew_retry "install formula ${name}" -- brew install "${name}"; then
    success "Installed (formula): ${name}"
  else
    warning "Couldn't install formula '${name}'. Check the log: ${LOG_FILE}"
  fi
}

install_dependencies() {
  step "Installing apps and tools"

  # GUI apps: the path is provided to detect manual installs.
  install_cask "alacritty" "/Applications/Alacritty.app"
  install_cask "iterm2"    "/Applications/iTerm.app"

  # Font: if JetBrainsMono Nerd Font files are already installed, skip.
  if brew_cask_installed "${FONT_CASK}"; then
    info "Cask '${FONT_CASK}' already managed by Homebrew, skipping."
  elif ls "${HOME}/Library/Fonts/"JetBrainsMono*NerdFont* >/dev/null 2>&1 \
       || ls "/Library/Fonts/"JetBrainsMono*NerdFont* >/dev/null 2>&1; then
    info "JetBrainsMono Nerd Font is already present on the system, skipping."
  else
    install_cask "${FONT_CASK}"
  fi

  local item
  for item in "${FORMULAE[@]}"; do install_formula "${item}"; done
}

# ── 4. Python / AppKit support ──────────────────────────────────────────────
# Terminal.app requires archived color data (NSColor), and resolving the font
# requires AppKit, i.e. the pyobjc bridge. The system Python
# (/usr/bin/python3, part of the Command Line Tools) includes it. If it's not
# available, a pyobjc virtual environment is created as a fallback.

# Create (or reuse) a pyobjc virtual environment and, on success, assign its
# interpreter to PYTHON_APPKIT. Idempotent: reuses an existing venv.
build_pyobjc_venv() {
  local base=""
  if clt_present && [[ -x /usr/bin/python3 ]]; then
    base="/usr/bin/python3"
  elif have python3; then
    base="$(command -v python3)"
  else
    info "Installing Python with Homebrew to enable AppKit..."
    install_formula python || true
    have python3 && base="$(command -v python3)"
  fi
  [[ -n "${base}" ]] || { warning "No base Python 3 to create the pyobjc environment."; return 1; }

  local venv="${HOME}/.cache/terminal-setup/pyobjc-venv"
  if [[ -x "${venv}/bin/python3" ]] && "${venv}/bin/python3" -c 'import AppKit' >/dev/null 2>&1; then
    PYTHON_APPKIT="${venv}/bin/python3"
    info "Reusing existing pyobjc environment."
    return 0
  fi

  info "Creating pyobjc virtual environment (this may take a moment)..."
  ensure_dir "$(dirname "${venv}")"
  rm -rf "${venv}"
  if "${base}" -m venv "${venv}" >>"${LOG_FILE}" 2>&1 \
     && "${venv}/bin/python3" -m pip install --quiet --upgrade pip >>"${LOG_FILE}" 2>&1 \
     && "${venv}/bin/python3" -m pip install --quiet pyobjc-framework-Cocoa >>"${LOG_FILE}" 2>&1 \
     && "${venv}/bin/python3" -c 'import AppKit' >/dev/null 2>&1; then
    PYTHON_APPKIT="${venv}/bin/python3"
    success "pyobjc environment created at ${venv}"
    return 0
  fi
  warning "Couldn't create the pyobjc environment."
  return 1
}

setup_python() {
  step "Python and AppKit support"

  PYTHON_APPKIT=""
  # 1) System Python with AppKit (avoid invoking it if the CLT aren't present, so
  #    Apple's install dialog isn't triggered again).
  if clt_present && [[ -x /usr/bin/python3 ]] && /usr/bin/python3 -c 'import AppKit' >/dev/null 2>&1; then
    PYTHON_APPKIT="/usr/bin/python3"
  # 2) Any python3 on the PATH that already ships AppKit.
  elif have python3 && python3 -c 'import AppKit' >/dev/null 2>&1; then
    PYTHON_APPKIT="$(command -v python3)"
  # 3) Fallback: pyobjc virtual environment.
  else
    build_pyobjc_venv || true
  fi

  # Basic interpreter (no AppKit) to generate iTerm2 JSON.
  if [[ -n "${PYTHON_APPKIT}" ]]; then
    PYTHON_BIN="${PYTHON_APPKIT}"
  elif clt_present && [[ -x /usr/bin/python3 ]]; then
    PYTHON_BIN="/usr/bin/python3"
  elif have python3; then
    PYTHON_BIN="$(command -v python3)"
  else
    PYTHON_BIN=""
  fi

  if [[ -n "${PYTHON_APPKIT}" ]]; then
    success "AppKit support enabled (${PYTHON_APPKIT})"
  else
    warning "AppKit unavailable: Terminal.app will be skipped and the iTerm2 font will use the default name."
  fi
}

# Resolve the actual installed font's PostScript name (via AppKit) so that
# iTerm2 and Terminal.app apply it without falling back to a glyph-less font (Nerd Font).
resolve_font() {
  local resolved=""
  if [[ -n "${PYTHON_APPKIT}" && -n "${GEN_PY}" ]]; then
    resolved="$("${PYTHON_APPKIT}" "${GEN_PY}" fontname "${FONT_FAMILY}" 2>>"${LOG_FILE}" || true)"
  fi
  if [[ -n "${resolved}" ]]; then
    FONT_PS="${resolved}"
    info "Font resolved: '${FONT_FAMILY}' → PostScript name '${FONT_PS}'"
  else
    FONT_PS="${FONT_PS_DEFAULT}"
    info "Using default font name: '${FONT_PS}'"
  fi
}

# ── 5. Generating the Python helper script ──────────────────────────────────
# Builds iTerm2's colors (JSON) and applies the Terminal.app profile.
# The palettes live here as the single source of truth for colors.
write_gen_py() {
  GEN_PY="${TMPDIR:-/tmp}/terminal-setup-gen-${RUN_STAMP}.py"
  cat >"${GEN_PY}" <<'PYEOF'
#!/usr/bin/env python3
"""Color configuration generator for iTerm2 and Terminal.app."""
import sys
import json

# Tokyo Night — Alacritty reference (its config is written to the .toml).
TOKYO = {
    "bg": "1a1b26", "fg": "c0caf5",
    "cursor": "c0caf5", "cursor_text": "1a1b26",
    "selection_bg": "283457", "selection_text": "c0caf5",
    "black": "15161e", "red": "f7768e", "green": "9ece6a", "yellow": "e0af68",
    "blue": "7aa2f7", "magenta": "bb9af7", "cyan": "7dcfff", "white": "a9b1d6",
    "br_black": "414868", "br_red": "f7768e", "br_green": "9ece6a", "br_yellow": "e0af68",
    "br_blue": "7aa2f7", "br_magenta": "bb9af7", "br_cyan": "7dcfff", "br_white": "c0caf5",
}

# Ayu Mirage — used by iTerm2. Signature amber cursor (#FFCC66).
AYU_MIRAGE = {
    "bg": "1f2430", "fg": "cbccc6",
    "cursor": "ffcc66", "cursor_text": "1f2430",
    "selection_bg": "34455a", "selection_text": "cbccc6",
    "black": "1a1e29", "red": "f28779", "green": "bae67e", "yellow": "ffd580",
    "blue": "73d0ff", "magenta": "d4bfff", "cyan": "95e6cb", "white": "cbccc6",
    "br_black": "686868", "br_red": "f39b91", "br_green": "c6f587", "br_yellow": "ffe5bc",
    "br_blue": "9fdbff", "br_magenta": "dfbfff", "br_cyan": "95e6cb", "br_white": "ffffff",
}

# Gruvbox (dark, medium contrast) — used by Terminal.app. morhetz's canonical palette.
GRUVBOX = {
    "bg": "282828", "fg": "ebdbb2", "bold": "ebdbb2",
    "cursor": "ebdbb2", "selection": "504945",
    "black": "282828", "red": "cc241d", "green": "98971a", "yellow": "d79921",
    "blue": "458588", "magenta": "b16286", "cyan": "689d6a", "white": "a89984",
    "br_black": "928374", "br_red": "fb4934", "br_green": "b8bb26", "br_yellow": "fabd2f",
    "br_blue": "83a598", "br_magenta": "d3869b", "br_cyan": "8ec07c", "br_white": "ebdbb2",
}


def components(hexstr):
    """Convert '#RRGGBB' or 'RRGGBB' to an (r, g, b) tuple in the 0..1 range."""
    h = hexstr.lstrip("#")
    return (int(h[0:2], 16) / 255.0,
            int(h[2:4], 16) / 255.0,
            int(h[4:6], 16) / 255.0)


# ── iTerm2: dynamic profile in JSON format ──────────────────────────────────
def iterm_color(hexstr):
    r, g, b = components(hexstr)
    return {"Color Space": "sRGB", "Red Component": r,
            "Green Component": g, "Blue Component": b, "Alpha Component": 1}


def build_iterm(font_ps, size, name, guid, opacity, cols, rows):
    p = AYU_MIRAGE
    font = "%s %s" % (font_ps, size)
    # iTerm2 uses "Transparency" (0 = opaque, 1 = transparent), the inverse of opacity.
    transparency = round(1.0 - float(opacity), 4)
    profile = {
        "Name": name,
        "Guid": guid,
        "Columns": int(cols),
        "Rows": int(rows),
        # New windows, tabs, and split panes reuse the current session's
        # working directory. iTerm2 detects the cwd of local sessions on its
        # own; "Advanced" lets us set the behavior for all three contexts.
        "Custom Directory": "Advanced",
        "AWDS Window Option": "Recycle",
        "AWDS Window Directory": "",
        "AWDS Tab Option": "Recycle",
        "AWDS Tab Directory": "",
        "AWDS Pane Option": "Recycle",
        "AWDS Pane Directory": "",
        "Normal Font": font,
        "Non Ascii Font": font,
        "Use Non-ASCII Font": False,
        "Horizontal Spacing": 1.0,
        "Vertical Spacing": 1.0,
        "ASCII Anti Aliased": True,
        "Non-ASCII Anti Aliased": True,
        "Use Bold Font": True,
        "Use Italic Font": True,
        # No "bright bold": bold keeps the theme's real tone (it isn't
        # promoted to the bright color), like Alacritty's default.
        "Use Bright Bold": False,
        "Blinking Cursor": True,
        "Cursor Type": 2,
        "Transparency": transparency,
        "Blur": True,
        "Blur Radius": 8.0,
        "Background Color": iterm_color(p["bg"]),
        "Foreground Color": iterm_color(p["fg"]),
        "Bold Color": iterm_color(p["fg"]),
        "Cursor Color": iterm_color(p["cursor"]),
        "Cursor Text Color": iterm_color(p["cursor_text"]),
        "Selection Color": iterm_color(p["selection_bg"]),
        "Selected Text Color": iterm_color(p["selection_text"]),
        "Ansi 0 Color": iterm_color(p["black"]),
        "Ansi 1 Color": iterm_color(p["red"]),
        "Ansi 2 Color": iterm_color(p["green"]),
        "Ansi 3 Color": iterm_color(p["yellow"]),
        "Ansi 4 Color": iterm_color(p["blue"]),
        "Ansi 5 Color": iterm_color(p["magenta"]),
        "Ansi 6 Color": iterm_color(p["cyan"]),
        "Ansi 7 Color": iterm_color(p["white"]),
        "Ansi 8 Color": iterm_color(p["br_black"]),
        "Ansi 9 Color": iterm_color(p["br_red"]),
        "Ansi 10 Color": iterm_color(p["br_green"]),
        "Ansi 11 Color": iterm_color(p["br_yellow"]),
        "Ansi 12 Color": iterm_color(p["br_blue"]),
        "Ansi 13 Color": iterm_color(p["br_magenta"]),
        "Ansi 14 Color": iterm_color(p["br_cyan"]),
        "Ansi 15 Color": iterm_color(p["br_white"]),
    }
    return {"Profiles": [profile]}


def cmd_iterm(argv):
    font_ps, size, name, guid, opacity = argv[0], argv[1], argv[2], argv[3], argv[4]
    cols, rows = argv[5], argv[6]
    sys.stdout.write(json.dumps(
        build_iterm(font_ps, size, name, guid, opacity, cols, rows), indent=2))


# ── Font resolution: actual installed PostScript name ───────────────────────
def cmd_fontname(argv):
    """Print the PostScript name of a family's 'Regular' member."""
    family = argv[0]
    from AppKit import NSFontManager
    manager = NSFontManager.sharedFontManager()
    members = manager.availableMembersOfFontFamily_(family)
    if not members:
        return  # Not installed: the caller will use the default value.
    best = None
    for member in members:
        ps_name, style = str(member[0]), str(member[1])
        if style.lower() == "regular":
            best = ps_name
            break
    if best is None:
        best = str(members[0][0])
    sys.stdout.write(best)


# ── Terminal.app: native profile applied via CFPreferences ──────────────────
def cmd_terminal(argv):
    font_ps, size, name = argv[0], float(argv[1]), argv[2]
    # Terminal.app controls window translucency via the alpha channel
    # of the background color (there's no separate opacity key).
    opacity = float(argv[3]) if len(argv) > 3 else 1.0
    cols = int(argv[4]) if len(argv) > 4 else 110
    rows = int(argv[5]) if len(argv) > 5 else 30

    # These imports require pyobjc (present in /usr/bin/python3).
    from Foundation import NSKeyedArchiver, NSUserDefaults
    from AppKit import NSColor, NSFont

    def archive(obj):
        data, err = NSKeyedArchiver.\
            archivedDataWithRootObject_requiringSecureCoding_error_(obj, True, None)
        if data is None:
            raise RuntimeError("Could not archive the object: %s" % err)
        return data

    def col(hexstr, alpha=1.0):
        r, g, b = components(hexstr)
        return archive(NSColor.colorWithSRGBRed_green_blue_alpha_(r, g, b, alpha))

    font = NSFont.fontWithName_size_(font_ps, size)
    if font is None:  # Fallback if the font isn't available to the system yet.
        font = NSFont.userFixedPitchFontOfSize_(size)
    font_data = archive(font)

    p = GRUVBOX
    profile = {
        "name": name,
        "type": "Window Settings",
        "ProfileCurrentVersion": 2.07,
        "Font": font_data,
        "FontAntialias": True,
        "FontWidthSpacing": 1.0,
        "FontHeightSpacing": 1.0,
        "columnCount": cols,
        "rowCount": rows,
        "TerminalType": "xterm-256color",
        "UseBrightBold": True,
        "BlinkText": False,
        "CursorType": 0,
        "CursorBlink": True,
        # 0 = always close the window on exit (includes 'exit');
        # 1 = close only on clean exit; 2 = don't close (macOS default).
        "shellExitAction": 0,
        "BackgroundColor": col(p["bg"], opacity),
        "TextColor": col(p["fg"]),
        "TextBoldColor": col(p["bold"]),
        "CursorColor": col(p["cursor"]),
        "SelectionColor": col(p["selection"]),
        "ANSIBlackColor": col(p["black"]),
        "ANSIRedColor": col(p["red"]),
        "ANSIGreenColor": col(p["green"]),
        "ANSIYellowColor": col(p["yellow"]),
        "ANSIBlueColor": col(p["blue"]),
        "ANSIMagentaColor": col(p["magenta"]),
        "ANSICyanColor": col(p["cyan"]),
        "ANSIWhiteColor": col(p["white"]),
        "ANSIBrightBlackColor": col(p["br_black"]),
        "ANSIBrightRedColor": col(p["br_red"]),
        "ANSIBrightGreenColor": col(p["br_green"]),
        "ANSIBrightYellowColor": col(p["br_yellow"]),
        "ANSIBrightBlueColor": col(p["br_blue"]),
        "ANSIBrightMagentaColor": col(p["br_magenta"]),
        "ANSIBrightCyanColor": col(p["br_cyan"]),
        "ANSIBrightWhiteColor": col(p["br_white"]),
    }

    term_id = "com.apple.Terminal"
    defaults = NSUserDefaults.standardUserDefaults()
    domain = defaults.persistentDomainForName_(term_id)
    data = {} if domain is None else dict(domain)

    # Keep existing profiles and add/update ours (idempotent).
    window_settings = dict(data.get("Window Settings", {}))
    window_settings[name] = profile
    # Cleanup: remove profiles this script created in previous versions
    # (e.g. "Shades of Purple") to avoid piling up obsolete themes.
    for legacy in ("Shades of Purple",):
        if legacy != name:
            window_settings.pop(legacy, None)
    data["Window Settings"] = window_settings
    data["Default Window Settings"] = name
    data["Startup Window Settings"] = name

    defaults.setPersistentDomain_forName_(data, term_id)
    defaults.synchronize()


def main():
    if len(sys.argv) < 2:
        sys.stderr.write("usage: gen.py {iterm|terminal} ...\n")
        sys.exit(2)
    command, rest = sys.argv[1], sys.argv[2:]
    if command == "iterm":
        cmd_iterm(rest)
    elif command == "terminal":
        cmd_terminal(rest)
    elif command == "fontname":
        cmd_fontname(rest)
    else:
        sys.stderr.write("unknown command: %s\n" % command)
        sys.exit(2)


if __name__ == "__main__":
    main()
PYEOF
}

# ── 6. Alacritty configuration (Tokyo Night) ────────────────────────────────
configure_alacritty() {
  step "Alacritty configuration (Tokyo Night)"

  write_file "${ALACRITTY_CONF}" <<EOF
# ╔════════════════════════════════════════════╗
# ║  Alacritty — Tokyo Night                   ║
# ║  Generated by ${SCRIPT_NAME} v${SCRIPT_VERSION}
# ╚════════════════════════════════════════════╝

# Startup directory for the first window (e.g. when launching Alacritty fresh
# from the Dock). Must be an absolute path. New windows opened with Cmd-N
# inherit the current shell's directory instead of this one — so a fresh
# launch starts at home, while Cmd-N follows you to your current directory.
working_directory = "${HOME}"

[window]
opacity         = ${OPACITY}
blur            = true
padding         = { x = 16, y = 14 }
dynamic_padding = false
option_as_alt   = "None"
# Initial window size (columns x rows).
dimensions      = { columns = ${COLS}, lines = ${ROWS} }
# Alacritty closes the window automatically when the shell exits ('exit'),
# so it needs no extra settings to fully close.

[font]
size = ${FONT_SIZE}.0

[font.normal]
family = "${FONT_FAMILY}"
style  = "Regular"

[font.bold]
family = "${FONT_FAMILY}"
style  = "Bold"

[font.italic]
family = "${FONT_FAMILY}"
style  = "Italic"

[font.bold_italic]
family = "${FONT_FAMILY}"
style  = "Bold Italic"

[font.offset]
x = 0
y = 2

[cursor]
style            = { shape = "Block", blinking = "On" }
blink_interval   = 600
unfocused_hollow = true

# ── Tokyo Night palette ─────────────────────────────────────
[colors.primary]
background = "#1a1b26"
foreground = "#c0caf5"

[colors.cursor]
text   = "#1a1b26"
cursor = "#c0caf5"

[colors.selection]
text       = "#c0caf5"
background = "#283457"

[colors.search.matches]
foreground = "#1a1b26"
background = "#7dcfff"

[colors.search.focused_match]
foreground = "#1a1b26"
background = "#9ece6a"

[colors.normal]
black   = "#15161e"
red     = "#f7768e"
green   = "#9ece6a"
yellow  = "#e0af68"
blue    = "#7aa2f7"
magenta = "#bb9af7"
cyan    = "#7dcfff"
white   = "#a9b1d6"

[colors.bright]
black   = "#414868"
red     = "#f7768e"
green   = "#9ece6a"
yellow  = "#e0af68"
blue    = "#7aa2f7"
magenta = "#bb9af7"
cyan    = "#7dcfff"
white   = "#c0caf5"

[scrolling]
history    = 10000
multiplier = 3

[bell]
animation = "EaseOutExpo"
duration  = 0

[mouse]
hide_when_typing = true

[[keyboard.bindings]]
key    = "N"
mods   = "Command"
action = "SpawnNewInstance"

[[keyboard.bindings]]
key    = "Plus"
mods   = "Command"
action = "IncreaseFontSize"

[[keyboard.bindings]]
key    = "Minus"
mods   = "Command"
action = "DecreaseFontSize"

[[keyboard.bindings]]
key    = "Key0"
mods   = "Command"
action = "ResetFontSize"
EOF
  success "Alacritty configuration written to ${ALACRITTY_CONF}"
}

# ── 7. iTerm2 configuration (Ayu Mirage) ────────────────────────────────────
configure_iterm() {
  step "iTerm2 configuration (Ayu Mirage)"

  if [[ -z "${PYTHON_BIN}" ]]; then
    warning "Python 3 unavailable; skipping iTerm2 configuration."
    return 0
  fi

  ensure_dir "${ITERM_PROFILE_DIR}"
  backup_file "${ITERM_PROFILE_FILE}"

  # Cleanup: remove dynamic profiles created by previous versions
  # (e.g. the Tokyo Night one) so no obsolete profiles linger in iTerm2.
  local legacy
  for legacy in "${ITERM_PROFILE_LEGACY[@]}"; do
    if [[ -f "${legacy}" && "${legacy}" != "${ITERM_PROFILE_FILE}" ]]; then
      backup_file "${legacy}"
      rm -f "${legacy}"
      info "Obsolete dynamic profile removed: ${legacy}"
    fi
  done

  # The dynamic profile lives in its own file; iTerm2 reads it on every launch
  # and never overwrites it, so rewriting it is fully idempotent.
  # Generate to a temp file and move (atomic write) with the resolved font.
  local tmp="${ITERM_PROFILE_FILE}.tmp"
  if "${PYTHON_BIN}" "${GEN_PY}" iterm \
      "${FONT_PS}" "${FONT_SIZE}" "${ITERM_PROFILE_NAME}" "${ITERM_GUID}" \
      "${OPACITY}" "${COLS}" "${ROWS}" >"${tmp}" 2>>"${LOG_FILE}"; then
    mv -f "${tmp}" "${ITERM_PROFILE_FILE}"
    success "iTerm2 profile '${ITERM_PROFILE_NAME}' created with font '${FONT_PS}'."
  else
    rm -f "${tmp}"
    warning "Couldn't generate the iTerm2 profile."
    return 0
  fi

  # Setting the profile as default is written to iTerm2's preferences.
  # If iTerm2 is open, it keeps its settings in memory and rewrites them on
  # quit, discarding this change. That's why we only apply it if it's NOT open.
  if pgrep -x "iTerm2" >/dev/null 2>&1; then
    warning "iTerm2 is open: quit it completely (⌘Q) and reopen it."
    warning "Profile '${ITERM_PROFILE_NAME}' is already available; select it or reopen iTerm2 to make it the default."
  else
    if defaults write com.googlecode.iterm2 "Default Bookmark Guid" -string "${ITERM_GUID}" >/dev/null 2>&1; then
      success "Profile '${ITERM_PROFILE_NAME}' set as default in iTerm2."
    else
      warning "Couldn't set the iTerm2 profile as default."
    fi
    # iTerm2 already closes the window when the shell exits ('exit'). So that it also
    # quits completely (the app exits when the last window closes, without
    # asking), we adjust these global preferences.
    defaults write com.googlecode.iterm2 QuitWhenAllWindowsClosed -bool true >/dev/null 2>&1 || true
    defaults write com.googlecode.iterm2 PromptOnQuit -bool false >/dev/null 2>&1 || true
  fi
}

# ── 8. Terminal.app configuration (Gruvbox) ─────────────────────────────────
configure_terminal_app() {
  step "Terminal.app configuration (Gruvbox)"

  if [[ -z "${PYTHON_APPKIT}" ]]; then
    warning "AppKit unavailable; skipping Terminal.app configuration."
    warning "Re-run the script after installing Xcode's Command Line Tools."
    return 0
  fi

  # Warning: if Terminal.app is open, it may overwrite the profile when it closes.
  if pgrep -x "Terminal" >/dev/null 2>&1; then
    warning "Terminal.app is running; close it so the profile persists."
  fi

  backup_file "${TERMINAL_PLIST}"

  if "${PYTHON_APPKIT}" "${GEN_PY}" terminal \
      "${FONT_PS}" "${FONT_SIZE}" "${TERMINAL_PROFILE_NAME}" \
      "${OPACITY}" "${COLS}" "${ROWS}" 2>>"${LOG_FILE}"; then
    success "Profile '${TERMINAL_PROFILE_NAME}' applied in Terminal.app with font '${FONT_PS}'."
  else
    warning "Couldn't apply the Terminal.app profile. Check the log."
  fi
}

# ── 9. Starship configuration ───────────────────────────────────────────────
configure_starship() {
  step "Starship configuration"

  write_file "${STARSHIP_CONF}" <<'EOF'
# ╔═════════════════════════════════════════════════════════════════╗
# ║  Starship — colors by ANSI NAME (not fixed hex)                 ║
# ║                                                                 ║
# ║  By using names ('blue', 'green', 'purple'...) instead of hex,  ║
# ║  the prompt inherits each terminal's palette and stays true     ║
# ║  to its theme: Ayu Mirage in iTerm2, Tokyo Night in Alacritty,  ║
# ║  and Gruvbox in Terminal.app, without hard-coding colors.       ║
# ╚═════════════════════════════════════════════════════════════════╝

format = """
[╭─](bright-black) $directory$git_branch$git_status
[╰─](bright-black)$character """

add_newline = true

[directory]
style             = "bold blue"
truncation_length = 3
truncate_to_repo  = true

[character]
success_symbol = "[❯](bold green)"
error_symbol   = "[❯](bold red)"

[git_branch]
symbol = " "
style  = "purple"

[git_status]
style = "yellow"
EOF
  success "Starship configuration written to ${STARSHIP_CONF}"

  # Terminal.app (Gruvbox) variant: identical prompt, but the path is orange
  # instead of the theme's blue. Terminal.app supports only 256 colors (no
  # 24-bit truecolor), so we use xterm-256 color 208 (~#ff8700, a Gruvbox-style
  # orange) rather than a hex value — a hex would be ignored and the path would
  # fall back to the default color. ~/.zshrc selects this file only under Terminal.app.
  write_file "${STARSHIP_GRUVBOX_CONF}" < <(sed 's/"bold blue"/"bold 208"/' "${STARSHIP_CONF}")
  success "Starship Gruvbox variant written to ${STARSHIP_GRUVBOX_CONF}"
}

# ── 10. lsd icon configuration ───────────────────────────────────────────────
# lsd reads ~/.config/lsd/icons.yaml to customize the glyphs per file
# type. Here we set the directory icon to the Nerd Font folder glyph
# (U+F07B), the same typeface shared by all three terminals, so it
# displays correctly in every one of them.
configure_lsd() {
  step "lsd icon configuration"

  # Quoted heredoc (<<'EOF'): the content is written literally, so
  # "\uF07B" stays as-is in the file. lsd uses a YAML reader that
  # interprets that Unicode escape and turns it into the matching glyph.
  write_file "${LSD_ICONS_CONF}" <<'EOF'
# ╔════════════════════════════╗
# ║  lsd — icons by file type  ║
# ╚════════════════════════════╝
filetype:
  dir: "\uF07B"
EOF
  success "lsd icons written to ${LSD_ICONS_CONF}"
}

# ── 11. Updating ~/.zshrc (managed, idempotent block) ───────────────────────
configure_zshrc() {
  step "Updating ~/.zshrc"

  [[ -f "${ZSHRC}" ]] || : >"${ZSHRC}"
  backup_file "${ZSHRC}"

  # Remove any previous block managed by this script (idempotency).
  if grep -qF "${ZSHRC_MARKER_START}" "${ZSHRC}" 2>/dev/null; then
    local tmp="${ZSHRC}.tmp"
    awk -v s="${ZSHRC_MARKER_START}" -v e="${ZSHRC_MARKER_END}" '
      $0 == s { skip = 1; next }
      $0 == e { skip = 0; next }
      !skip   { print }
    ' "${ZSHRC}" >"${tmp}" && mv -f "${tmp}" "${ZSHRC}"
    info "Previous configuration block removed to regenerate it."
  fi

  # Add the updated block.
  cat >>"${ZSHRC}" <<EOF

${ZSHRC_MARKER_START}
# Generated by ${SCRIPT_NAME} v${SCRIPT_VERSION} — do not edit manually.

# File-type colors for lsd/ls via LS_COLORS. ANSI numeric codes
# (34, 36, 32...) are used, NOT truecolor, so folders and other types
# inherit each terminal's palette and stay true to its theme (Ayu Mirage,
# Tokyo Night, Gruvbox). No bold (no '01;') to avoid bright colors.
export LS_COLORS="di=34:ln=36:mh=00:pi=33:so=35:do=35:bd=33:cd=33:or=31:su=31:sg=31:tw=34:ow=34:st=34:ex=32:fi=00"

# lsd aliases (modern ls replacement)
if command -v lsd >/dev/null 2>&1; then
  alias ls='lsd'
  alias ll='lsd -la'
  alias lt='lsd --tree'
fi

# Syntax highlighting (must be loaded last)
if command -v brew >/dev/null 2>&1; then
  _zsh_hl="\$(brew --prefix)/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  [ -r "\${_zsh_hl}" ] && source "\${_zsh_hl}"
  unset _zsh_hl
fi

# Starship prompt
if command -v starship >/dev/null 2>&1; then
  # Terminal.app (Gruvbox) uses a variant config with an orange path; the other
  # terminals use the default config, whose path color adapts to each palette.
  if [ "\$TERM_PROGRAM" = "Apple_Terminal" ] && [ -r "\$HOME/.config/starship-gruvbox.toml" ]; then
    export STARSHIP_CONFIG="\$HOME/.config/starship-gruvbox.toml"
  fi
  eval "\$(starship init zsh)"
fi
${ZSHRC_MARKER_END}
EOF
  # shellcheck disable=SC2088  # literal ~ in a human-facing log line, not a path
  success "~/.zshrc updated"
}

# ── 12. Final verification ──────────────────────────────────────────────────
verify_install() {
  step "Final verification"

  local ok=1 item
  for item in alacritty starship lsd; do
    if have "${item}"; then success "Available: ${item}"
    else warning "Not available on PATH: ${item}"; ok=0; fi
  done

  [[ -d "/Applications/iTerm.app" ]] && success "iTerm2 installed" \
    || warning "iTerm2 not found in /Applications."

  for item in "${ALACRITTY_CONF}" "${STARSHIP_CONF}" "${STARSHIP_GRUVBOX_CONF}" "${LSD_ICONS_CONF}"; do
    [[ -f "${item}" ]] && success "Config present: ${item}" \
      || { warning "Missing configuration file: ${item}"; ok=0; }
  done

  return $((ok == 1 ? 0 : 0))   # Doesn't fail the install; informational only.
}

# ── 13. Summary ─────────────────────────────────────────────────────────────
print_summary() {
  # When run orchestrated by setup.sh (SETUP_ORCHESTRATED=1), this is just ONE
  # module of several: do NOT announce "Installation complete" (setup.sh does that
  # when EVERYTHING finishes). Scope the title to the terminal configuration.
  local mid='║          ✓  Installation complete          ║'
  if [[ "${SETUP_ORCHESTRATED:-0}" == "1" ]]; then
    mid='║         ✓  Terminal setup complete         ║'
  fi
  printf '\n%s%s╔════════════════════════════════════════════╗%s\n' "${GREEN}" "${BOLD}" "${RESET}"
  printf   '%s%s%s%s\n' "${GREEN}" "${BOLD}" "${mid}" "${RESET}"
  printf   '%s%s╚════════════════════════════════════════════╝%s\n\n' "${GREEN}" "${BOLD}" "${RESET}"

  printf '%sUnified experience summary%s\n' "${BOLD}" "${RESET}"
  printf '  • Shared font  : %s %spt%s\n' "${FONT_FAMILY}" "${FONT_SIZE}" ""
  printf '  • Alacritty    : Tokyo Night\n'
  printf '  • iTerm2       : Ayu Mirage (profile "%s", amber cursor)\n' "${ITERM_PROFILE_NAME}"
  printf '  • Terminal.app : Gruvbox (profile "%s")\n\n' "${TERMINAL_PROFILE_NAME}"

  printf '%sNext steps%s\n' "${BOLD}" "${RESET}"
  printf '  1. Open Alacritty → the Tokyo Night theme is already active.\n'
  printf '  2. Open iTerm2 → profile "%s" becomes the default once you restart it.\n' "${ITERM_PROFILE_NAME}"
  printf '  3. Open Terminal.app → select profile "%s" if it isn'\''t the default.\n' "${TERMINAL_PROFILE_NAME}"
  printf '  4. Reload your shell with: %sexec zsh%s (or open a new tab).\n\n' "${BOLD}" "${RESET}"

  if [[ "${BACKUP_MADE}" -eq 1 ]]; then
    printf '%sBackups%s of your previous configuration at: %s\n' "${BOLD}" "${RESET}" "${BACKUP_ROOT}"
  fi
  printf 'Detailed log: %s\n' "${LOG_FILE}"

  if [[ "${#WARNINGS[@]}" -gt 0 ]]; then
    printf '\n%s%sWarnings (%d)%s\n' "${YELLOW}" "${BOLD}" "${#WARNINGS[@]}" "${RESET}"
    local w
    for w in "${WARNINGS[@]}"; do printf '  • %s\n' "${w}"; done
  fi
  printf '\n'
}

# ── Entry point ─────────────────────────────────────────────────────────────
main() {
  parse_args "$@"
  init_colors

  printf '%s╔══════════════════════════════════════════════════╗%s\n' "${BOLD}" "${RESET}"
  printf '%s║   Terminal Setup — Unified Experience (v%s)   ║%s\n' "${BOLD}" "${SCRIPT_VERSION}" "${RESET}"
  printf '%s╚══════════════════════════════════════════════════╝%s\n' "${BOLD}" "${RESET}"

  # Fast path: re-apply ONLY the Terminal.app profile. Everything else (iTerm2,
  # Alacritty, fonts, ~/.zshrc) was already applied in the first pass and is
  # unaffected by Terminal.app being closed, so we skip it. Requires the Python
  # AppKit helper and the resolved font, which are cheap to recompute here.
  if [[ "${TERMINAL_ONLY}" -eq 1 ]]; then
    step "Re-applying Terminal.app profile"
    write_gen_py
    setup_python
    resolve_font
    configure_terminal_app
    success "Terminal.app profile re-applied (run from outside Terminal.app)."
    return 0
  fi

  preflight
  ensure_homebrew
  install_dependencies
  write_gen_py        # Generate the Python helper (needed to resolve the font).
  setup_python        # Resolve/install the AppKit interpreter.
  resolve_font        # Determine the actual installed font name.

  configure_alacritty
  configure_iterm
  configure_terminal_app
  configure_starship
  configure_lsd
  configure_zshrc

  verify_install
  print_summary
}

main "$@"
