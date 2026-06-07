#!/usr/bin/env bash
# =============================================================================
# lib/common.sh — shared helpers for the setup-macos modules
# Idempotent and arch-aware. Sourced from setup.sh and from each module:
#   HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
#   source "$HERE/../lib/common.sh"
# Compatible with macOS's bash 3.2 (no associative arrays or mapfile).
# =============================================================================
set -euo pipefail

# ── Colors / logging ─────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  C_RST=$'\033[0m'; C_BLU=$'\033[34m'; C_GRN=$'\033[32m'; C_CYN=$'\033[36m'
  C_YLW=$'\033[33m'; C_RED=$'\033[31m'; C_DIM=$'\033[2m'; C_BLD=$'\033[1m'
else
  C_RST=''; C_BLU=''; C_GRN=''; C_CYN=''; C_YLW=''; C_RED=''; C_DIM=''; C_BLD=''
fi
# Unified look across all modules (same tags/colors/titles as 01. Terminals):
# bracketed 6-char level tags [INFO]/[ OK ]/[WARN]/[FAIL] and cyan "── Title".
log()  { printf '%s%s[INFO]%s  %s\n' "$C_BLU" "$C_BLD" "$C_RST" "$*"; }
ok()   { printf '%s%s[ OK ]%s  %s\n' "$C_GRN" "$C_BLD" "$C_RST" "$*"; }
warn() { printf '%s%s[WARN]%s  %s\n' "$C_YLW" "$C_BLD" "$C_RST" "$*" >&2; }
die()  { printf '%s%s[FAIL]%s  %s\n' "$C_RED" "$C_BLD" "$C_RST" "$*" >&2; exit 1; }
step() { printf '\n%s%s── %s%s\n' "$C_CYN" "$C_BLD" "$*" "$C_RST"; }

# ── Platform / architecture ──────────────────────────────────────────────────
[[ "$(uname -s)" == "Darwin" ]] || die "setup-macos is for macOS only."
ARCH="$(uname -m)"
# Prefer an ALREADY installed brew (robust under Rosetta: an x86_64 shell on Apple
# Silicon reports x86_64 even though the native brew lives in /opt/homebrew). If there
# is no brew yet (new machine), decide the prefix by architecture.
if   [[ -x /opt/homebrew/bin/brew ]]; then BREW_PREFIX="/opt/homebrew"
elif [[ -x /usr/local/bin/brew   ]]; then BREW_PREFIX="/usr/local"
else
  case "$ARCH" in
    arm64)  BREW_PREFIX="/opt/homebrew" ;;   # Apple Silicon
    x86_64) BREW_PREFIX="/usr/local"    ;;   # Intel
    *)      die "Unsupported architecture: $ARCH" ;;
  esac
fi
BREW="$BREW_PREFIX/bin/brew"

# zsh init files — honor ZDOTDIR just like the Homebrew installer does.
# (If ZDOTDIR is set, ~/.zprofile is NEVER sourced and brew wouldn't reach the PATH.)
ZDOTDIR_EFF="${ZDOTDIR:-$HOME}"
ZPROFILE="$ZDOTDIR_EFF/.zprofile"
ZSHRC="$ZDOTDIR_EFF/.zshrc"

# ── Base utilities ───────────────────────────────────────────────────────────
need_cmd() { command -v "$1" >/dev/null 2>&1; }

# Load Homebrew into the CURRENT session of the script (to use brew/binaries now).
load_brew() {
  [[ -x "$BREW" ]] || die "Homebrew is not at $BREW (run module 02 first)."
  eval "$("$BREW" shellenv)"
}

# Append a line to a file ONLY if it doesn't already exist (dotfile idempotency).
#   append_once <file> <line>
append_once() {
  local file="$1" line="$2"
  [[ -e "$file" ]] || { mkdir -p "$(dirname "$file")"; : > "$file"; }
  if grep -qsF -- "$line" "$file"; then
    return 0
  fi
  printf '%s\n' "$line" >> "$file"
  ok "added to $(basename "$file"): ${C_DIM}${line}${C_RST}"
}

# ── Privileges: a single password for the whole run ──────────────────────────
# Ask for the password ONCE and, for the duration of setup, install a temporary
# drop-in in /etc/sudoers.d so that neither Homebrew, nor the Command Line Tools,
# nor the cask .pkg installers (e.g. zulu@17) ask for it again — macOS does NOT
# always honor the sudo timestamp for those .pkg, so a keep-alive of the timestamp
# is not enough. The drop-in:
#   • uses a FIXED name (idempotent): a leftover from an aborted run is detected
#     and replaced/removed, it doesn't accumulate;
#   • is validated with `visudo -cf` BEFORE being installed (an invalid sudoers
#     could leave you without sudo); if it doesn't validate, it is skipped (the .pkg will ask for the password);
#   • is ALWAYS removed on exit (the orchestrator's EXIT trap) via sudo_session_end.
# Manual cleanup if a run dies with kill -9:  sudo rm -f /etc/sudoers.d/setup-macos
SUDO_DROPIN="/etc/sudoers.d/setup-macos"

# Remove the drop-in if it exists. Idempotent and robust: warns if it couldn't delete it.
sudo_session_end() {
  [[ -e "$SUDO_DROPIN" ]] || return 0
  if sudo rm -f "$SUDO_DROPIN" 2>/dev/null; then
    ok "temporary sudoers removed ($SUDO_DROPIN)"
  else
    warn "could not remove $SUDO_DROPIN — delete it by hand with: sudo rm -f $SUDO_DROPIN"
  fi
}
sudo_session_begin() {
  need_cmd sudo || { warn "sudo not available; some steps could fail."; return 0; }
  log "you will be asked for your password once for the whole installation…"
  sudo -v || die "sudo access is required (Homebrew, Command Line Tools, cask .pkg)."
  # Replace any leftover from a previous run (idempotent).
  sudo rm -f "$SUDO_DROPIN" 2>/dev/null || true
  local tmp; tmp="$(mktemp -t setup-macos-sudoers)"
  printf '%s ALL=(ALL) NOPASSWD: ALL\n' "$(id -un)" > "$tmp"; chmod 0440 "$tmp"
  # Do the whole setup in the 'if' so a partial failure doesn't trip set -e.
  if sudo visudo -cf "$tmp" >/dev/null 2>&1 \
     && sudo cp "$tmp" "$SUDO_DROPIN" \
     && sudo chown root:wheel "$SUDO_DROPIN" \
     && sudo chmod 0440 "$SUDO_DROPIN"; then
    ok "sudo without re-prompt enabled during setup (removed when finished)"
  else
    warn "could not enable the temporary sudoers; continuing without it (the .pkg casks might ask for the password)."
    sudo rm -f "$SUDO_DROPIN" 2>/dev/null || true
  fi
  rm -f "$tmp"
}

# ── Authentication (deferrable to the end of setup) ──────────────────────────
# The orchestrator defers INTERACTIVE authentications (e.g. the GitHub web login)
# so they do NOT interrupt the installation: each module queues a "token" with
# request_auth and setup.sh runs the queue at the end with run_deferred_auth. If
# there is no orchestrator (module run standalone), request_auth runs right away.
# NOTE: the sudo password does NOT go here — it is needed DURING the installation
# (Homebrew/CLT) and therefore can't be deferred; sudo_session_begin covers that.

# Idempotent GitHub login (no re-prompt if already authenticated).
gh_auth_ensure() {
  need_cmd gh || { warn "gh not installed; skipping GitHub authentication."; return 0; }
  if gh auth status --hostname github.com >/dev/null 2>&1; then
    ok "gh already authenticated on github.com"
  else
    warn "gh not authenticated → opening web login (interactive step)…"
    gh auth login --hostname github.com --git-protocol https --web
  fi
}

# Run the authentication corresponding to a token.
run_auth() {
  case "$1" in
    github) gh_auth_ensure ;;
    *)      warn "unknown authentication: $1" ;;
  esac
}

# Queue an authentication for the END if the orchestrator enabled the queue
# (SETUP_AUTH_QUEUE); otherwise, run it immediately.   request_auth <token>
request_auth() {
  local token="$1" q="${SETUP_AUTH_QUEUE:-}"
  if [[ -n "$q" && -w "$q" ]]; then
    grep -qxF "$token" "$q" 2>/dev/null || printf '%s\n' "$token" >> "$q"
    log "authentication of '$token' deferred to the end of setup."
  else
    run_auth "$token"
  fi
}

# Run all queued authentications at the end (without duplicating).
run_deferred_auth() {
  local q="${SETUP_AUTH_QUEUE:-}" token
  [[ -n "$q" && -s "$q" ]] || return 0
  step "Authentication (at the end, everything installed)"
  while IFS= read -r token; do
    [[ -n "$token" ]] && run_auth "$token"
  done < "$q"
}

# ── Xcode Command Line Tools ─────────────────────────────────────────────────
# Homebrew needs the CLT (clang, headers, git). It installs them ONLY if missing,
# unattended (softwareupdate) and, if that isn't possible, falls back to Apple's
# graphical installer (xcode-select --install). A full Xcode also provides them,
# so if there is already a valid toolchain this is a no-op. (The full Xcode is handled
# separately in module 12 iOS; here we only guarantee the brew dependency.)
clt_present() {
  local dir
  dir="$(xcode-select -p 2>/dev/null)" || return 1
  [[ -n "$dir" && -d "$dir" ]]
}
ensure_clt() {
  if clt_present; then
    ok "Command Line Tools / Xcode already present ($(xcode-select -p))"
    return 0
  fi

  log "installing the Xcode Command Line Tools (unattended)…"
  # Apple-supported trick: this flag file makes 'softwareupdate -l' list the CLT
  # as an installable update without opening the GUI.
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

  # Fallback: Apple's graphical installer + wait for the user to complete it.
  if [[ "$installed" -ne 0 ]] || ! clt_present; then
    warn "unattended path not available; opening Apple's graphical installer…"
    xcode-select --install >/dev/null 2>&1 || true
    log "waiting for the Command Line Tools installation to finish…"
    until clt_present; do sleep 5; done
  fi

  clt_present || die "Could not install the Xcode Command Line Tools."
  ok "Command Line Tools installed ($(xcode-select -p))"
}

# ── Homebrew: install only if missing ────────────────────────────────────────
brew_ensure() {                       # brew_ensure formula1 formula2 ...
  local f
  for f in "$@"; do
    if "$BREW" list --formula --versions "$f" >/dev/null 2>&1; then
      ok "brew: $f (already installed)"
    else
      log "brew install $f"; "$BREW" install "$f"
    fi
  done
}
cask_ensure() {                       # cask_ensure cask1 cask2 ...
  local c
  for c in "$@"; do
    if "$BREW" list --cask --versions "$c" >/dev/null 2>&1; then
      ok "cask: $c (already installed)"
    else
      log "brew install --cask $c"; "$BREW" install --cask "$c"
    fi
  done
}
tap_ensure() {                        # tap_ensure user/repo
  local t="$1"
  if "$BREW" tap | grep -qxF "$t"; then ok "tap: $t (already added)"
  else log "brew tap $t"; "$BREW" tap "$t"; fi
}

# Install from a Brewfile (idempotent by design).
bundle_install() {                    # bundle_install /path/to/Brewfile
  local file="$1"
  [[ -f "$file" ]] || die "Brewfile does not exist: $file"
  log "brew bundle install --file=$file"
  "$BREW" bundle install --file="$file"
}

# ── brew services: start only if not running ─────────────────────────────────
service_ensure() {                    # service_ensure postgresql@16
  local svc="$1"
  if "$BREW" services list | awk -v s="$svc" '$1==s && $2=="started"{found=1} END{exit found?0:1}'; then
    ok "service $svc (already running)"
  else
    log "brew services start $svc"; "$BREW" services start "$svc"
  fi
}
