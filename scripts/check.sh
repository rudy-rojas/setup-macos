#!/usr/bin/env bash
# =============================================================================
# scripts/check.sh — local quality gate for setup-macos (mirrors CI).
# Runs three cheap, side-effect-free checks over every *.sh in the repo:
#   1. shellcheck   — static analysis (warnings/errors fail; info is ignored)
#   2. bash -n      — syntax validation (catches typos without executing)
#   3. smoke        — ./setup.sh --list and --dry-run run without side effects
# Exit non-zero if any check fails. Run it before committing:  scripts/check.sh
# =============================================================================
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
cd "$ROOT"

# Excluded checks, with rationale (keep this list tight):
#   SC1090/SC1091 — `source "$HERE/../lib/common.sh"` is a dynamic path the linter can't follow
#   SC2034        — ZPROFILE/ZSHRC etc. are defined in common.sh and consumed in other sourced files
SHELLCHECK_EXCLUDES="SC1090,SC1091,SC2034"

fail=0
say() { printf '\n\033[1;36m── %s\033[0m\n' "$*"; }

# Collect every shell script except those under .git.
scripts=()
while IFS= read -r -d '' f; do scripts+=("$f"); done \
  < <(find . -name '*.sh' -not -path './.git/*' -print0)

say "shellcheck (${#scripts[@]} scripts)"
if command -v shellcheck >/dev/null 2>&1; then
  shellcheck -s bash -S warning -e "$SHELLCHECK_EXCLUDES" "${scripts[@]}" \
    && echo "shellcheck: OK" || fail=1
else
  echo "shellcheck not installed — skipping (install: brew install shellcheck)"
fi

say "bash -n (syntax)"
for f in "${scripts[@]}"; do
  bash -n "$f" || { echo "SYNTAX FAIL: $f"; fail=1; }
done
[[ "$fail" == 0 ]] && echo "syntax: OK"

say "smoke: --list / --dry-run (no side effects)"
./setup.sh --list   >/dev/null && echo "--list: OK"    || fail=1
./setup.sh --dry-run >/dev/null && echo "--dry-run: OK" || fail=1

say "helpers: idempotency (append_once / set_managed_line)"
bash "$ROOT/scripts/test-helpers.sh" || fail=1

say "result"
if [[ "$fail" == 0 ]]; then echo "all checks passed ✓"; else echo "checks FAILED ✗"; fi
exit "$fail"
