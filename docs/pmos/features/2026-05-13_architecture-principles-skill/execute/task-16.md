---
task_number: 16
task_name: "Report emitter — JSON shape lock + stderr summary + determinism"
task_goal_hash: "sha256:t16-report-emit-fr70-fr71-fr72-fr73-nfr02"
plan_path: "docs/pmos/features/2026-05-13_architecture-principles-skill/03_plan.html"
branch: "feat/architecture-principles-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-architecture-principles-skill"
status: done
started_at: 2026-05-13T16:45:00Z
completed_at: 2026-05-13T16:58:00Z
files_touched:
  - plugins/pmos-toolkit/skills/architecture/tools/run-audit.sh
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/determinism/src/{a,b}.ts
---

## Summary

Three concrete deliverables, all on the audit's tail end:

1. **Findings sort lock (FR-73)** — reordered jq `sort_by` from
   `(severity, file, line, rule_id)` to `(severity, rule_id, file, line)`.
   Severity remains numeric-asc on the `{block:0, warn:1, info:2}` map (so
   block listings come first); the rest are lexical asc.
2. **`declarative_delegated_pct` (FR-71)** — computed in the python loader
   as `count(rules with delegate_to ∈ {dependency-cruiser, ruff}) /
   count(rules where tier ∈ {1, 2})`, rounded to 3 decimals. L3-only tier-3
   rules are excluded from the denominator: the metric tracks the shipped
   rule pack, not project add-ons. Emitted alongside `rules_loaded`.
3. **Stderr summary (FR-72)** — final emit now stages the report JSON into
   `REPORT_JSON`, prints it to stdout, then runs an inline python3 summarizer
   to stderr. Shape per FR-72: header + counts line + block listing verbatim
   + warn/info one-liners with samples + tail notes (orphan, expired, cap,
   tool-skip, informational) + ADR list. Respects `NO_COLOR` (skips ANSI
   when `NO_COLOR` is non-empty or stderr is not a TTY). Hard-capped at 30
   lines; on overflow a `... (<N> more lines truncated; see
   report.findings)` line replaces the tail. Quiet via `QUIET=1` env.

## TDD red → green

- **Red:**
  - Pre-T16 audit on `tests/fixtures/determinism/` had no determinism
    guarantee beyond timestamp-stripping (sort tiebreak was
    `file/line/rule_id` not `rule_id/file/line`).
  - `.declarative_delegated_pct` was absent from the JSON schema.
  - No stderr summary; audit emitted only an F3 line on Vue gaps + ad-hoc
    notes.
- **Green:**
  - `diff <(audit determinism | jq 'del(.run)') <(audit determinism | jq
    'del(.run)')` → empty.
  - `audit … | jq -e '.declarative_delegated_pct != null'` exits 0.
  - `audit … 2>&1 1>/dev/null | wc -l` ≤ 30 for clean repo (actual: 5).
  - `findings` array byte-identical when re-keyed `(severity, rule_id,
    file, line)`.

## Runtime evidence (4 primary + 15 regressions = 19/19 PASS)

| # | Test | Result |
|---|------|--------|
| 1 | **Determinism diff-empty** — two consecutive runs on `determinism/` diff to nothing after `jq 'del(.run)'` | PASS |
| 2 | **Schema lock** — `.declarative_delegated_pct` present on every audit invocation | PASS |
| 3 | **Sort lock** — findings array sorted on `(severity-num-asc, rule_id, file, line)` for `l1-security/` (U009, U010) | PASS |
| 4 | **Summary ≤ 30 lines** — clean `determinism/` run emits exactly 5 stderr lines | PASS |
| 5–19 | All T15 (4) + prior-task (11) regressions still green | PASS |

## Decisions / deviations

- **Sort key reorder, not "fix".** FR-73 explicitly orders `(severity desc,
  rule_id asc, file asc, line asc)`. The pre-T16 jq put `file` before
  `rule_id` — same five findings, different tie-break order — invisible
  until a fixture has two block findings on the same file. The reorder is
  the canonical FR-73 shape, not a deviation.

- **`declarative_delegated_pct` excludes L3.** A project that adds 30 tier-3
  grep rules should NOT see its declarative coverage tank — the metric
  measures the shipped rule pack's lean toward delegated tools (dep-cruiser,
  ruff), which is a property of the plugin, not the host project. Plan
  §T16 step 4's formula `tier ∈ [1, 2]` matches this read.

- **Stderr summary lives in inline python3, not bash + jq.** Composing the
  ≤30-line summary in bash + jq would have meant 30 lines of jq for the
  conditional adornments (warn sample, info sample, orphan/expired
  branches, ADR list, tool-skipped, NO_COLOR). Python keeps it readable in
  one place and reuses the loader's existing python3 dependency — no new
  deps. The summarizer reads the final JSON from an env var and prints to
  `sys.stderr` directly.

- **`NO_COLOR` honoured via env + TTY check.** Skip ANSI when EITHER
  `NO_COLOR` is non-empty (NO_COLOR convention) OR stderr is not a TTY
  (piped runs / CI / file redirect). Block tier is `1;31` (red bold), warn
  is `33` (yellow), info is `2` (dim). Stdout JSON is never tinted —
  jq-consumers don't want surprise escapes.

- **30-line hard cap with truncation marker.** A clean repo emits 3 base
  lines + 0 block + 0 warn + 0 info ≈ 3 lines. A noisy repo with 50 block
  findings would blow the cap — the cap protects terminals. The truncation
  marker references `report.findings` so the operator knows where the
  full list lives.

- **`QUIET=1` env opt-out.** Useful for shell pipelines / scripts that
  pipe the JSON straight to `jq` and don't want the human summary churning
  their terminal. Plan §T16 step 2 doesn't mandate it, but it's a one-line
  conditional that costs nothing.

- **`run.duration_s` still `0.0`.** FR-71 sample shows `duration_s: 4.2`
  but determinism (FR-73) strips `.run` for diffing, so a real timer wasn't
  required at v1. Computing wall-clock would re-introduce nondeterminism
  on the visible stderr (the summary header includes `duration=<X>s`); a
  future T (probably during T19 polish) can wire `START_EPOCH` and `END -
  START` into the summary. Deferred without a fixture.

- **Determinism fixture is intentionally low-finding.** Two `.ts` files,
  one with a `console.log` (U004 warn) — produces 3 findings (2 warn, 1
  info from U007 missing-purpose-comment on `b.ts`), zero block. Zero
  block keeps the audit from writing ADRs as a side effect, which would
  perturb determinism between runs (monotonic NNNN advances on every
  block). Plan §T16 step 3's `diff … → empty` requires this property.

## Verification outcome

PASS. Plan §T16 byte-for-byte:
- `diff <(tools/run-audit.sh determinism/ | jq 'del(.run)') <(tools/run-audit.sh
  determinism/ | jq 'del(.run)')` → empty.
- Stderr summary < 30 lines for clean repo (actual: 5).
- `declarative_delegated_pct` emitted on every run.
- Findings sorted per FR-73.

All 15 prior-task regressions green (T1-tracer / T4-exemption-row /
T6-l1-size / T7-l1-hygiene / T8-l1-security / L3-override / gitignore-deny /
T9-ts-circular / T10-py-tidy / T11-tool-missing / T12-vue-mixed plus the 4
T15 reconcile sub-fixtures). T16 sealed; cursor advances to T17 (SKILL.md
authoring).
