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
# Minimum supported macOS major version — single source of truth (module 01's
# preflight and the README reference this). Below it the run only WARNS, never
# hard-fails. Override with MACOS_MIN_MAJOR=… if you knowingly target an older OS.
MACOS_MIN_MAJOR="${MACOS_MIN_MAJOR:-14}"   # 14 = Sonoma
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

# ── Pinned toolchain versions (single source of truth) ───────────────────────
# Bump these here (or override per-run via setup.env / inline VAR=… ./setup.sh)
# instead of editing the modules. The dates are the upstream end-of-life / support
# windows — review and bump BEFORE they pass so the setup never goes stale silently.
PG_VERSION="${PG_VERSION:-16}"                       # PostgreSQL major — EOL 2028-11
PYTHON_VERSION="${PYTHON_VERSION:-3.12}"             # Python minor     — EOL 2028-10
JDK_VERSION="${JDK_VERSION:-17}"                     # Azul Zulu JDK — RN/Expo need 17, NOT 21+
ANDROID_API="${ANDROID_API:-36}"                     # Android platform / system-image API level
ANDROID_BUILD_TOOLS="${ANDROID_BUILD_TOOLS:-36.0.0}" # Android build-tools version

# Seconds to wait for a service (Postgres, MySQL, …) to become ready. Override
# with SETUP_TIMEOUT=… for slow machines / cold starts.
SETUP_TIMEOUT="${SETUP_TIMEOUT:-30}"

# Seconds to wait for the Xcode Command Line Tools GUI install to finish before
# giving up (much longer than a service check). Bounds the wait so a cancelled or
# failed install can't hang the run forever; raise it on slow links.
CLT_INSTALL_TIMEOUT="${CLT_INSTALL_TIMEOUT:-1800}"   # 30 min

# ── Resilient Homebrew downloads (avoid indefinitely stalled transfers) ───────
# Symptom this prevents: a cask/bottle download (e.g. Alacritty's .dmg, served
# from the GitHub release CDN) hangs "forever" even on a healthy connection,
# and only a Ctrl-C + re-run gets it moving again.
# Cause: Homebrew applies a low-speed timeout (--speed-limit/--speed-time) ONLY
# to its JSON API and to `git` updates — never to ARTIFACT downloads, which get
# just `--retry`. `--retry` fires on a hard error, not on a stalled-but-alive
# connection (a flaky CDN edge), so curl waits indefinitely.
# Fix: inject a low-speed timeout into every Homebrew curl via HOMEBREW_CURLRC.
# Homebrew runs `curl --disable --config <file>`, so this is scoped to Homebrew
# (the user's own ~/.curlrc is untouched) and, because Homebrew appends the
# API's own --speed-limit AFTER our --config, it only adds protection where
# there was none (artifacts) without changing API behavior. On a stall curl
# aborts (exit 28), --retry reconnects, and brew resumes the partial download
# (try_partial) — so the transfer self-heals instead of hanging.
export HOMEBREW_NO_AUTO_UPDATE="${HOMEBREW_NO_AUTO_UPDATE:-1}"  # modules update explicitly (02)
export HOMEBREW_CURL_RETRIES="${HOMEBREW_CURL_RETRIES:-5}"
if [[ "${HOMEBREW_CURLRC:-}" != /* ]]; then        # respect a user-provided config file
  _setup_curlrc="$HOME/.cache/setup-macos/homebrew-curlrc"
  if [[ ! -f "$_setup_curlrc" ]]; then
    # Abort a transfer that stays under 1 KB/s for 30 s (a real stall, not a
    # merely slow link); --retry then reconnects and brew resumes the partial.
    mkdir -p "$(dirname "$_setup_curlrc")" 2>/dev/null \
      && printf 'speed-limit = 1024\nspeed-time = 30\n' >"$_setup_curlrc" 2>/dev/null || true
  fi
  [[ -f "$_setup_curlrc" ]] && export HOMEBREW_CURLRC="$_setup_curlrc"
  unset _setup_curlrc
fi

# zsh init files — honor ZDOTDIR just like the Homebrew installer does.
# (If ZDOTDIR is set, ~/.zprofile is NEVER sourced and brew wouldn't reach the PATH.)
ZDOTDIR_EFF="${ZDOTDIR:-$HOME}"
ZPROFILE="$ZDOTDIR_EFF/.zprofile"
ZSHRC="$ZDOTDIR_EFF/.zshrc"

# ── Base utilities ───────────────────────────────────────────────────────────
need_cmd() { command -v "$1" >/dev/null 2>&1; }

# require_cmd <command> <hint> — fail fast with a clear, actionable message when a
# required command is missing (a cross-module prerequisite, or a tool that should
# already be on PATH after its own install step), instead of a cryptic later error.
#   require_cmd code "open VS Code once to install the 'code' CLI."
require_cmd() {
  need_cmd "$1" && return 0
  die "'$1' is required but was not found — $2"
}

# wait_for <description> <command...> — poll the command until it succeeds or
# SETUP_TIMEOUT seconds elapse. Returns 0 when ready, 1 on timeout, so the caller
# decides whether a timeout is fatal (die) or a warning. Standardizes the
# service-readiness loop that modules 08/09/10 used to hand-roll.
wait_for() {
  local desc="$1"; shift
  local tries=0
  log "waiting for $desc (up to ${SETUP_TIMEOUT}s)…"
  until "$@" >/dev/null 2>&1; do
    tries=$((tries + 1))
    [[ "$tries" -ge "$SETUP_TIMEOUT" ]] && return 1
    sleep 1
  done
  return 0
}

# Run a command with xtrace (set -x) temporarily OFF so any secret in its
# arguments never leaks to the log when the script is invoked with `bash -x`.
# (Defense in depth — prefer feeding secrets via stdin so they also stay out of `ps`.)
no_xtrace() {
  case "$-" in
    *x*) set +x; "$@"; local rc=$?; set -x; return $rc ;;
    *)   "$@" ;;
  esac
}

# This project writes shell-init lines (PATH, env) to the zsh files ~/.zprofile
# and ~/.zshrc. If the login shell isn't zsh those changes are silently never
# loaded — warn once (called by setup.sh) so it isn't a confusing surprise later.
check_login_shell() {
  case "${SHELL:-}" in
    */zsh) return 0 ;;
    *) warn "your login shell is '${SHELL:-unknown}', not zsh — setup writes PATH/env to ~/.zprofile and ~/.zshrc."
       warn "  add those files to your shell init, or switch with:  chsh -s /bin/zsh" ;;
  esac
}

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

# Like append_once, but for a line whose VALUE changes when a pinned version is
# bumped (e.g. a keg-only PATH export tied to PG_VERSION, or JAVA_HOME tied to
# JDK_VERSION). append_once would leave the OLD line behind on every bump, so the
# dotfile slowly fills with dead exports. set_managed_line tags the line with a
# trailing "# setup-macos:<tag>" marker and, on each run, removes any prior line
# carrying that tag (and the legacy untagged form an older append_once wrote)
# before writing the current one — so there is exactly one line per tag.
#   set_managed_line <file> <tag> <line>
# Idempotent: an unchanged line is detected and left untouched (silent no-op),
# so a same-version re-run does not rewrite the file. Use a unique <tag> per line.
set_managed_line() {
  local file="$1" tag="$2" line="$3"
  local marker="# setup-macos:${tag}"
  local tagged="${line}  ${marker}"
  [[ -e "$file" ]] || { mkdir -p "$(dirname "$file")"; : > "$file"; }
  # No-op fast path: the current tagged line is already the only one for this tag.
  if grep -qxF -- "$tagged" "$file" && [[ "$(grep -cF -- "$marker" "$file")" == 1 ]]; then
    return 0
  fi
  # Drop every prior line for this tag (matched by marker) and any legacy untagged
  # copy (exact match), then append the current tagged line. Strings go through the
  # environment so awk treats them literally (avoids -v backslash processing).
  local tmp; tmp="$(mktemp)"
  SML_MARKER="$marker" SML_LINE="$line" awk \
    'index($0, ENVIRON["SML_MARKER"]) == 0 && $0 != ENVIRON["SML_LINE"]' \
    "$file" > "$tmp"
  printf '%s\n' "$tagged" >> "$tmp"
  mv -f "$tmp" "$file"
  ok "set in $(basename "$file") [${tag}]: ${C_DIM}${line}${C_RST}"
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
#   • is ALWAYS removed on exit or interrupt (the orchestrator traps EXIT and
#     INT/TERM/HUP) via sudo_session_end; the next run also clears any leftover.
# Manual cleanup if a run dies with kill -9:  sudo rm -f /etc/sudoers.d/setup-macos
# LIMITATION (verified against man sudoers, not a live cask run): this covers
# sudo-based escalation only. A cask that uses macOS's GUI authorization dialog
# (osascript "… with administrator privileges") instead of sudo would still prompt;
# the sudoers drop-in does not affect that path.
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
  # Reuse an already-passwordless session instead of prompting again — this is the
  # hand-off case: the resumed iTerm2 leg inherits the drop-in that the Terminal.app
  # leg left in place (its EXIT trap keeps it during a hand-off). The check is
  # `sudo -n true` (run a real command non-interactively), NOT `sudo -v`: with
  # macOS's default `Defaults verifypw=all`, -v demands a password unless EVERY
  # matching sudoers entry is NOPASSWD — and the user's normal %admin entry isn't,
  # so -v would re-prompt even while the drop-in is active.
  if sudo -n true 2>/dev/null; then
    if [[ -e "$SUDO_DROPIN" ]]; then
      ok "sudo session reused (no password needed)"
      return 0
    fi
    # Passwordless via a cached timestamp but no drop-in yet → install it below
    # (needed for the cask .pkg installers), without prompting.
  else
    log "you will be asked for your password once for the whole installation…"
    sudo -v || die "sudo access is required (Homebrew, Command Line Tools, cask .pkg)."
  fi
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
    log "waiting for the Command Line Tools installation to finish (up to ${CLT_INSTALL_TIMEOUT}s)…"
    local waited=0
    until clt_present; do
      sleep 5; waited=$(( waited + 5 ))
      if (( waited >= CLT_INSTALL_TIMEOUT )); then
        die "Command Line Tools still absent after ${CLT_INSTALL_TIMEOUT}s. Finish/retry 'xcode-select --install' and re-run (or raise CLT_INSTALL_TIMEOUT)."
      fi
      if (( waited % 60 == 0 )); then log "  still waiting for the Command Line Tools… (${waited}s elapsed)"; fi
    done
  fi

  clt_present || die "Could not install the Xcode Command Line Tools."
  ok "Command Line Tools installed ($(xcode-select -p))"
}

# ── Homebrew: install only if missing ────────────────────────────────────────
# Run a downloading brew command, retrying on a transient network failure. The
# curl low-speed timeout set above makes a stalled download abort quickly and
# brew resumes the partial on retry, so this rarely loops — it just turns a
# flaky CDN edge into a brief retry instead of a failed run. Output stays live.
brew_retry() {                        # brew_retry "$BREW" install --cask foo
  local attempt=1 max=3
  while (( attempt <= max )); do
    if "$@"; then return 0; fi
    if (( attempt == max )); then return 1; fi
    warn "brew command failed (attempt $attempt/$max); retrying in 3s…"
    attempt=$(( attempt + 1 )); sleep 3
  done
}
brew_ensure() {                       # brew_ensure formula1 formula2 ...
  local f
  for f in "$@"; do
    if "$BREW" list --formula --versions "$f" >/dev/null 2>&1; then
      ok "brew: $f (already installed)"
    else
      log "brew install $f"; brew_retry "$BREW" install "$f"
    fi
  done
}
cask_ensure() {                       # cask_ensure cask1 cask2 ...
  local c
  for c in "$@"; do
    if "$BREW" list --cask --versions "$c" >/dev/null 2>&1; then
      ok "cask: $c (already installed)"
    else
      log "brew install --cask $c"; brew_retry "$BREW" install --cask "$c"
    fi
  done
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
