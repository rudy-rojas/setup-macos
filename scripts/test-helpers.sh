#!/usr/bin/env bash
# =============================================================================
# scripts/test-helpers.sh — unit tests for the idempotent dotfile helpers in
# lib/common.sh (append_once, set_managed_line). Idempotency is the project's
# central promise, so it is worth asserting in CI instead of only by hand.
#
# Side-effect-free: operates only on a temp file. Sources lib/common.sh, which
# refuses to run off macOS, so this is driven by the macOS CI job and by
# scripts/check.sh (never the Linux lint job).
# =============================================================================
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")/.." && pwd)"
# shellcheck source=../lib/common.sh
source "$ROOT/lib/common.sh"
set +e   # this harness does its own assertions; tolerate `grep -c` exit 1 (count 0)

pass=0; fail=0
chk() {                               # chk <label> <got> <want>
  if [[ "$2" == "$3" ]]; then pass=$((pass + 1))
  else printf '  FAIL: %s (got "%s", want "%s")\n' "$1" "$2" "$3"; fail=$((fail + 1)); fi
}

tmpd="$(mktemp -d)"; trap 'rm -rf "$tmpd"' EXIT
f="$tmpd/dotfile"

# ── append_once: adds a line once, never duplicates on re-run ────────────────
append_once "$f" 'export FOO=1' >/dev/null
append_once "$f" 'export FOO=1' >/dev/null
chk "append_once is idempotent" "$(grep -cxF 'export FOO=1' "$f")" 1

# ── set_managed_line: idempotent on same value, replaces on change ───────────
set_managed_line "$f" demo 'export BAR=16' >/dev/null
set_managed_line "$f" demo 'export BAR=16' >/dev/null
chk "set_managed_line idempotent (same value)" "$(grep -cF 'setup-macos:demo' "$f")" 1

set_managed_line "$f" demo 'export BAR=17' >/dev/null            # version bump
chk "set_managed_line single line after bump" "$(grep -cF 'setup-macos:demo' "$f")" 1
chk "set_managed_line drops the stale value"  "$(grep -cF 'BAR=16' "$f")" 0
chk "set_managed_line keeps the new value"    "$(grep -cF 'BAR=17' "$f")" 1

# ── set_managed_line cleans up a legacy untagged line (old append_once form) ─
printf '%s\n' 'export BAZ=1' >> "$f"
set_managed_line "$f" baz 'export BAZ=1' >/dev/null
chk "set_managed_line cleans legacy untagged copy" "$(grep -cF 'BAZ=1' "$f")" 1

# ── distinct tags coexist (no cross-tag clobbering) ──────────────────────────
chk "managed tags coexist" "$(grep -cF 'setup-macos:' "$f")" 2

if [[ "$fail" -eq 0 ]]; then
  printf 'helper tests: OK (%d passed)\n' "$pass"; exit 0
else
  printf 'helper tests: FAILED (%d failed, %d passed)\n' "$fail" "$pass"; exit 1
fi
