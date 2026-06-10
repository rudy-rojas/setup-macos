#!/usr/bin/env bash
# =============================================================================
# setup.sh — idempotent orchestrator for setup-macos
#
# Usage:
#   ./setup.sh                  Run all modules in order
#   ./setup.sh 04               Run only module 04
#   ./setup.sh --from 03        From module 03 onward
#   ./setup.sh --skip 11 --skip 12
#   ./setup.sh --list           List the detected modules
#   ./setup.sh --dry-run        Show what would run, without executing
#
# A module = folder "NN. Name/" that contains a "setup-*.sh".
# Each module can also be run separately.
#
# If any module to run uses sudo (02 Homebrew/CLT, 11 Android, 12 iOS), the
# password is asked ONCE at the start. For the duration of setup, a temporary
# drop-in is installed in /etc/sudoers.d (validated with visudo) so that the
# cask .pkg installers don't ask for it either; it is ALWAYS removed on exit.
# --list and --dry-run ask for nothing.
#
# INTERACTIVE app authentications (e.g. the GitHub web login) are deferred to
# the END, after everything is installed, so they don't interrupt the process.
#
# When started from Terminal.app, setup hands off to iTerm2 after the Terminals
# module (01) so Terminal.app can be closed and its Gruvbox profile persists,
# then continues there. Automatic; opt out with NO_TERMINAL_HANDOFF=1.
# =============================================================================
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
source "$HERE/lib/common.sh"

# Local configuration (gitignored): if setup.env exists, it is sourced and
# EXPORTED entirely (set -a) so the modules inherit GIT_USER_*, PG_DATABASES,
# MYSQL_ROOT_PASSWORD, INSTALL_IOS, etc. without prompts mid-install.
# Template: setup.env.example. Without the file, the defaults are used.
if [[ -f "$HERE/setup.env" ]]; then
  set -a; source "$HERE/setup.env"; set +a
  ok "configuration loaded from setup.env"
fi

ONLY=""; FROM=""; DRY=0; LIST=0; SKIPS=" "; RESUME_ITERM=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from)          FROM="${2:-}"; shift 2 ;;
    --skip)          SKIPS="${SKIPS}${2:-} "; shift 2 ;;
    --list|-l)       LIST=1; shift ;;
    --dry-run|-n)    DRY=1; shift ;;
    # Internal: set by the Terminal.app→iTerm2 hand-off when it relaunches setup in
    # iTerm2. Closes Terminal.app and re-applies its profile, then continues. Not
    # meant to be used by hand.
    --resume-iterm)  RESUME_ITERM=1; shift ;;
    -h|--help)       sed -n '3,27p' "$0"; exit 0 ;;
    [0-9][0-9])      ONLY="$1"; shift ;;
    *)               die "Unrecognized option: '$1' (use --help)" ;;
  esac
done

# ── Discover modules: folders "NN. *" with a setup-*.sh inside ───────────────
mods=()
for dir in "$HERE"/[0-9][0-9].*/; do
  [[ -d "$dir" ]] || continue
  script=""
  for s in "$dir"setup-*.sh; do [[ -f "$s" ]] && { script="$s"; break; }; done
  [[ -n "$script" ]] || continue          # e.g. "00. Inventory" has no script
  mods+=("$dir|$script")
done
[[ ${#mods[@]} -gt 0 ]] || die "No modules found ('NN. Name/setup-*.sh') in $HERE."

# ── Terminal.app → iTerm2 hand-off ───────────────────────────────────────────
# Terminal.app rewrites its own preferences when it quits, so the Gruvbox profile
# written by module 01 is lost the moment you close the Terminal.app you launched
# setup from. The fix is to apply that profile while Terminal.app is NOT running:
# once module 01 has installed and configured everything (iTerm2 included), we
# relaunch the rest of setup INSIDE iTerm2, which then closes Terminal.app and
# re-applies its profile (now persisting) before continuing with modules 02→.
# Automatic on a multi-module run started from Terminal.app; opt out with
# NO_TERMINAL_HANDOFF=1. Guarded against re-entry by SETUP_HANDOFF_DONE.

# Build "--skip NN" flags from the current SKIPS set, to pass through on resume.
handoff_skip_flags() {
  local out="" tok skips_arr
  read -ra skips_arr <<< "$SKIPS"
  # Guard the expansion: in macOS's bash 3.2, "${arr[@]}" on an empty array errors
  # under `set -u`, and SKIPS=" " (no skips) is the common case.
  if [[ ${#skips_arr[@]} -gt 0 ]]; then
    for tok in "${skips_arr[@]}"; do out="$out --skip $tok"; done
  fi
  printf '%s' "$out"
}

# Hand off to iTerm2 to run the rest of setup. May exit the script; returns
# (no-op) when the hand-off doesn't apply, so the caller continues in Terminal.app.
#   handoff_to_iterm_if_applicable <next-module-NN>
handoff_to_iterm_if_applicable() {
  local next_nn="$1"
  [[ "${SETUP_HANDOFF_DONE:-0}" == 1 ]]      && return 0   # already resumed once
  [[ "${NO_TERMINAL_HANDOFF:-0}" == 1 ]]     && return 0   # user opted out
  [[ "${TERM_PROGRAM:-}" == "Apple_Terminal" ]] || return 0  # only when run FROM Terminal.app
  [[ -t 1 ]]                                  || return 0   # interactive only
  if [[ ! -d "/Applications/iTerm.app" ]]; then
    warn "iTerm2 not found; staying in Terminal.app (its profile may need a manual reselect)."
    return 0
  fi

  step "Switching to iTerm2"
  log "Terminal.app can't persist its own profile while it's open — continuing the setup in iTerm2."

  local resume="$HOME/.cache/setup-macos/resume-iterm.sh"
  mkdir -p "$(dirname "$resume")"
  {
    printf '#!/bin/zsh\n'
    printf '# Auto-generated by setup.sh to continue the install in iTerm2. Safe to delete.\n'
    printf 'cd %q || exit 1\n' "$HERE"
    printf 'SETUP_HANDOFF_DONE=1 ./setup.sh --resume-iterm --from %q%s\n' "$next_nn" "$(handoff_skip_flags)"
    printf 'exec %q -l\n' "${SHELL:-/bin/zsh}"   # drop into a login shell so the window stays open
  } > "$resume"
  chmod +x "$resume"

  if osascript >/dev/null 2>&1 <<OSA
tell application "iTerm"
  activate
  create window with default profile command "$resume"
end tell
OSA
  then
    # Tell the EXIT trap to KEEP the sudo drop-in: the resumed run reuses it, so the
    # password isn't asked a second time.
    HANDOFF_IN_PROGRESS=1
    ok "iTerm2 launched — the rest of the setup continues there. This window will close automatically."
    exit 0
  fi
  warn "Couldn't launch iTerm2; continuing in Terminal.app (its profile may need a manual reselect)."
  return 0
}

# Resume side (runs in iTerm2): close Terminal.app, wait for it to exit, then
# re-apply ONLY the Terminal.app profile (module 01 --terminal-only).
resume_terminal_reapply() {
  step "Resuming in iTerm2"
  if pgrep -x Terminal >/dev/null 2>&1; then
    log "closing Terminal.app so its profile can persist…"
    osascript -e 'tell application "Terminal" to quit' >/dev/null 2>&1 || true
    local i=0
    while pgrep -x Terminal >/dev/null 2>&1; do
      i=$((i + 1)); [[ "$i" -ge 20 ]] && { warn "Terminal.app is still running; its profile may not persist."; break; }
      sleep 0.5
    done
  fi
  local t01=""
  for s in "$HERE"/01.*/setup-*.sh; do [[ -f "$s" ]] && { t01="$s"; break; }; done
  if [[ -n "$t01" ]]; then
    bash "$t01" --terminal-only || warn "Terminal.app re-apply reported a problem (continuing)."
  else
    warn "Module 01 not found; skipped Terminal.app re-apply."
  fi
}

[[ "$LIST" == 1 ]] && echo "Detected modules:"

# ── Run preparation (only if we are actually going to execute) ───────────────
if [[ "$LIST" == 0 && "$DRY" == 0 ]]; then
  # The modules write PATH/env to the zsh init files; warn once up front if the
  # login shell isn't zsh so those changes aren't silently lost.
  check_login_shell

  # Marker for the modules: they run orchestrated, NOT standalone. Each module is
  # one step of many, so none should announce "installation complete" — that is
  # declared by setup.sh at the end (e.g. module 01 narrows its summary).
  export SETUP_ORCHESTRATED=1

  # Deferred authentication queue: interactive logins (GitHub, etc.) run at the
  # END, after everything is installed, so they don't interrupt the process. A
  # single EXIT trap closes the sudo session (removes the drop-in) and clears the queue.
  # On an iTerm2 hand-off (HANDOFF_IN_PROGRESS) the drop-in is KEPT so the resumed
  # run reuses it without a second password prompt.
  SETUP_AUTH_QUEUE="$(mktemp -t setup-macos-auth)"; export SETUP_AUTH_QUEUE
  trap '[[ -n "${HANDOFF_IN_PROGRESS:-}" ]] || sudo_session_end; rm -f "${SETUP_AUTH_QUEUE:-}"' EXIT

  # Open the sudo session (a single password) if any module to run needs it:
  # 02 (Homebrew/CLT), 11 (Android: cask zulu@17 .pkg) and 12 (iOS). The sudo is
  # NOT deferred: it is needed DURING the installation.
  for m in "${mods[@]}"; do
    nn="$(basename "${m%%|*}")"; nn="${nn:0:2}"
    [[ -n "$ONLY" && "$nn" != "$ONLY" ]] && continue
    [[ -n "$FROM" && "$nn" < "$FROM" ]] && continue
    case "$SKIPS" in *" $nn "*) continue ;; esac
    if [[ " 02 11 12 " == *" $nn "* ]]; then sudo_session_begin; break; fi
  done

  # If we were relaunched in iTerm2, close Terminal.app and re-apply its profile
  # before continuing with the remaining modules.
  [[ "$RESUME_ITERM" == 1 ]] && resume_terminal_reapply
fi

ran=0; did_01=0
for m in "${mods[@]}"; do
  dir="${m%%|*}"; script="${m#*|}"
  name="$(basename "$dir")"; nn="${name:0:2}"

  [[ -n "$ONLY" && "$nn" != "$ONLY" ]] && continue
  [[ -n "$FROM" && "$nn" < "$FROM" ]] && continue
  case "$SKIPS" in *" $nn "*) warn "skipping $name"; continue ;; esac

  if [[ "$LIST" == 1 ]]; then printf '  %s  →  %s\n' "$nn" "$name"; continue; fi
  if [[ "$DRY"  == 1 ]]; then printf '  (dry-run) %s\n' "$script"; continue; fi

  # After module 01 (Terminals) finishes, before the first later module, hand off
  # to iTerm2 if we're running from Terminal.app (so its profile can persist). This
  # may exit and relaunch setup in iTerm2 with --resume-iterm; checked only once.
  # (Modules run in numeric order, so the first iteration with did_01==1 is the
  # first module after 01 — that's the one we resume from.)
  if [[ "$did_01" == 1 ]]; then
    handoff_to_iterm_if_applicable "$nn"
    did_01=2
  fi

  step "Module $name"
  bash "$script"
  ok "Module $name completed"
  ran=$((ran + 1))
  [[ "$nn" == "01" ]] && did_01=1
done

[[ "$LIST" == 1 || "$DRY" == 1 ]] && exit 0
[[ -n "$ONLY" && "$ran" == 0 ]] && die "Module '$ONLY' does not exist."

# Deferred interactive authentications (GitHub, etc.): at the end, everything installed.
run_deferred_auth

step "Installation complete"
ok "setup-macos finished — $ran module(s) executed."
