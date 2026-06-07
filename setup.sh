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

ONLY=""; FROM=""; DRY=0; LIST=0; SKIPS=" "
while [[ $# -gt 0 ]]; do
  case "$1" in
    --from)        FROM="${2:-}"; shift 2 ;;
    --skip)        SKIPS="${SKIPS}${2:-} "; shift 2 ;;
    --list|-l)     LIST=1; shift ;;
    --dry-run|-n)  DRY=1; shift ;;
    -h|--help)     sed -n '3,23p' "$0"; exit 0 ;;
    [0-9][0-9])    ONLY="$1"; shift ;;
    *)             die "Unrecognized option: '$1' (use --help)" ;;
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

[[ "$LIST" == 1 ]] && echo "Detected modules:"

# ── Run preparation (only if we are actually going to execute) ───────────────
if [[ "$LIST" == 0 && "$DRY" == 0 ]]; then
  # Marker for the modules: they run orchestrated, NOT standalone. Each module is
  # one step of many, so none should announce "installation complete" — that is
  # declared by setup.sh at the end (e.g. module 01 narrows its summary).
  export SETUP_ORCHESTRATED=1

  # Deferred authentication queue: interactive logins (GitHub, etc.) run at the
  # END, after everything is installed, so they don't interrupt the process. A
  # single EXIT trap closes the sudo session (removes the drop-in) and clears the queue.
  SETUP_AUTH_QUEUE="$(mktemp -t setup-macos-auth)"; export SETUP_AUTH_QUEUE
  trap 'sudo_session_end; rm -f "${SETUP_AUTH_QUEUE:-}"' EXIT

  # Open the sudo session (a single password) if any module to run needs it:
  # 02 (Homebrew/CLT), 11 (Android: cask zulu@17 .pkg) and 12 (iOS). The sudo is
  # NOT deferred: it is needed DURING the installation.
  for m in "${mods[@]}"; do
    nn="$(basename "${m%%|*}")"; nn="${nn:0:2}"
    [[ -n "$ONLY" && "$nn" != "$ONLY" ]] && continue
    [[ -n "$FROM" && "$nn" < "$FROM" ]] && continue
    case "$SKIPS" in *" $nn "*) continue ;; esac
    case " 02 11 12 " in *" $nn "*) sudo_session_begin; break ;; esac
  done
fi

ran=0
for m in "${mods[@]}"; do
  dir="${m%%|*}"; script="${m#*|}"
  name="$(basename "$dir")"; nn="${name:0:2}"

  [[ -n "$ONLY" && "$nn" != "$ONLY" ]] && continue
  [[ -n "$FROM" && "$nn" < "$FROM" ]] && continue
  case "$SKIPS" in *" $nn "*) warn "skipping $name"; continue ;; esac

  if [[ "$LIST" == 1 ]]; then printf '  %s  →  %s\n' "$nn" "$name"; continue; fi
  if [[ "$DRY"  == 1 ]]; then printf '  (dry-run) %s\n' "$script"; continue; fi

  step "Module $name"
  bash "$script"
  ok "Module $name completed"
  ran=$((ran + 1))
done

[[ "$LIST" == 1 || "$DRY" == 1 ]] && exit 0
[[ -n "$ONLY" && "$ran" == 0 ]] && die "Module '$ONLY' does not exist."

# Deferred interactive authentications (GitHub, etc.): at the end, everything installed.
run_deferred_auth

step "Installation complete"
ok "setup-macos finished — $ran module(s) executed."
