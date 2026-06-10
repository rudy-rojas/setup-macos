export const meta = {
  name: 'review-visual-orchestrator',
  description: 'Adversarial multi-lens review of the setup.sh visual/restructure diff',
  phases: [
    { title: 'Review', detail: '4 independent lenses over the uncommitted diff' },
    { title: 'Verify', detail: '3 adversarial verifiers per finding' },
  ],
}

const REPO = '/Volumes/DevLab/Workspace/lupbuck/setup-macos'

const FINDINGS = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          title: { type: 'string' },
          file: { type: 'string' },
          detail: { type: 'string', description: 'What is wrong, where (line refs), and the concrete failure scenario' },
          severity: { type: 'string', enum: ['critical', 'major', 'minor'] },
        },
        required: ['title', 'file', 'detail', 'severity'],
      },
    },
  },
  required: ['findings'],
}

const VERDICT = {
  type: 'object',
  properties: {
    refuted: { type: 'boolean', description: 'true if the finding is NOT a real problem' },
    reason: { type: 'string' },
  },
  required: ['refuted', 'reason'],
}

const COMMON = `Repo: ${REPO} (do NOT modify any file; read-only review).
The uncommitted diff is the change under review: run \`git -C "${REPO}" diff\` and read the full current setup.sh, lib/common.sh, scripts/check.sh and .github/workflows/ci.yml as needed.
Context: setup.sh is a macOS provisioning orchestrator that now (in this diff) adds: a screen clear + banner box on real runs, [N/M] per-module progress headers, per-module + total timing, a final summary box, and a restructure that pre-filters modules into a to_run array (replacing inline filtering in three places). It must keep working under macOS /bin/bash 3.2.57 with set -euo pipefail. --list/--dry-run must stay plain (they run in CI on a non-TTY macOS runner via scripts/check.sh and .github/workflows/ci.yml). There is also a Terminal.app→iTerm2 hand-off feature (handoff_to_iterm_if_applicable / resume_terminal_reapply / SETUP_HANDOFF_DONE / HANDOFF_IN_PROGRESS) that must keep functioning identically.
Report ONLY problems introduced or exposed by this diff (not pre-existing style nits). For each finding give the concrete failure scenario. If you find nothing for your lens, return an empty findings array — do NOT invent findings.`

const LENSES = [
  {
    key: 'bash32',
    prompt: `${COMMON}
LENS: bash 3.2 compatibility and set -euo pipefail pitfalls. Hunt specifically for: expansion of possibly-empty arrays ("\${arr[@]}" errors under set -u in bash 3.2 — length checks \${#arr[@]} are OK); arithmetic contexts that return nonzero and could trip set -e (bare (( )) ); 'local x=$(cmd)' masking; printf byte-vs-char padding with multibyte text (box-drawing chars, ✓, ·) and whether \${#var} char counting keeps the boxes aligned; ui_repeat/for-loop syntax on bash 3.2; SECONDS usage; anything in the new functions (ui_init/ui_repeat/ui_box/print_banner/step_module/fmt_duration/print_run_summary) that misbehaves on /bin/bash 3.2.57. Verify claims by actually running snippets with /bin/bash (it IS 3.2 on this machine).`,
  },
  {
    key: 'regression',
    prompt: `${COMMON}
LENS: behavior regressions vs the previous version (git show HEAD:setup.sh). Compare old vs new for: every CLI form (./setup.sh, NN, --from, --skip, --list, -l, --dry-run, -n, --help, --resume-iterm, combinations); exit codes; output format of --list and --dry-run lines; the 'Module NN does not exist' check (old: after loop; new: early — any case where old accepted and new dies, or vice versa? e.g. --from combined with NN, --skip of the ONLY module); sudo_session_begin trigger conditions (old filtered mods inline; new iterates to_run); the hand-off (did_01 progression, handoff receives the right next module NN, resume path ordering relative to banner/sudo); SETUP_ORCHESTRATED/auth queue/trap unchanged; whether 'skipping' warnings still appear in all modes they used to. Actually run the safe modes (--list, --dry-run, --list --skip X, 99 as nonexistent ONLY, --dry-run --from 99) and compare against 'git stash'-free expectations by reading the old code (do NOT stash or modify the working tree; derive old behavior by reading git show HEAD:setup.sh).`,
  },
  {
    key: 'edges',
    prompt: `${COMMON}
LENS: terminal/runtime edge cases of the new presentation code. Consider: TERM unset or dumb (tput cols failing) on a TTY; very narrow windows (<48 cols) and the clamp; non-TTY exec runs (piped real run — banner boxes print as plain unicode: acceptable? clear must NOT run); SETUP_NO_CLEAR; 'clear' availability under restricted PATH; whether die() messages can be wiped by a later clear (ordering: the ONLY-does-not-exist die happens before print_banner — confirm); ui_box with text longer than the box; step_module with index ≥ 100 modules or long names; fmt_duration with 0s and >1h; whether the clear could eat the sudo password prompt or any earlier warn (check_login_shell, skipped warnings ordering vs banner); interaction with the iTerm2 hand-off (resumed run clearing the new window is intended; the ORIGINAL window's 'Switching to iTerm2' message must not be cleared). Verify by running /bin/bash snippets where possible.`,
  },
  {
    key: 'docs',
    prompt: `${COMMON}
LENS: documentation and help consistency. Check: setup.sh header comment (lines 3-27 are printed by --help via sed -n '3,27p' — does the printed range still cover exactly the intended usage text after this diff, no more, no less? run ./setup.sh --help and inspect); README.md claims vs actual behavior (SETUP_NO_CLEAR row, banner/progress description); setup.env.example (SETUP_NO_CLEAR block accuracy); scripts/check.sh description still accurate; any stale comment inside setup.sh referring to removed code (e.g. comments about where 'Detected modules:' is echoed, the old run-preparation guard, etc.).`,
  },
]

phase('Review')
const results = await pipeline(
  LENSES,
  l => agent(l.prompt, { label: `review:${l.key}`, phase: 'Review', schema: FINDINGS }),
  (review, lens) => {
    if (!review || !review.findings || review.findings.length === 0) return []
    return parallel(review.findings.map(f => () =>
      parallel([1, 2, 3].map(n => () =>
        agent(
          `${COMMON}
You are adversarial verifier #${n}. A reviewer (lens: ${lens.key}) claims this problem in the uncommitted diff:
TITLE: ${f.title}
FILE: ${f.file}
SEVERITY: ${f.severity}
DETAIL: ${f.detail}
Try hard to REFUTE it: read the actual code, re-run the scenario with /bin/bash (3.2) where it is safe and side-effect-free (never run real module installs; --list/--dry-run/nonexistent-module runs are safe; standalone function snippets are safe). If the scenario cannot actually happen, or the behavior matches the old version, or the impact is imaginary, set refuted=true. Only confirm (refuted=false) if you can demonstrate the concrete failure. When uncertain, default to refuted=true.`,
          { label: `verify:${lens.key}:${f.title.slice(0, 30)}`, phase: 'Verify', schema: VERDICT },
        )
      )).then(votes => {
        const confirms = votes.filter(Boolean).filter(v => !v.refuted).length
        return { ...f, lens: lens.key, confirms, confirmed: confirms >= 2, votes: votes.filter(Boolean).map(v => v.reason) }
      })
    ))
  },
)

const all = results.filter(Boolean).flat()
const confirmed = all.filter(f => f.confirmed)
const rejected = all.filter(f => !f.confirmed)
log(`${all.length} raw findings → ${confirmed.length} confirmed, ${rejected.length} refuted`)
return { confirmed, rejected: rejected.map(r => ({ title: r.title, lens: r.lens })) }