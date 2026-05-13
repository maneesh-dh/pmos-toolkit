---
task_number: 7
task_name: "L1 grep rules — debug/hygiene (U004, U005, U007, U008)"
task_goal_hash: "sha256:t7-l1-debug-hygiene-u004-u005-u007-u008-section-7-4"
plan_path: "docs/pmos/features/2026-05-13_architecture-principles-skill/03_plan.html"
branch: "feat/architecture-principles-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-architecture-principles-skill"
status: done
started_at: 2026-05-13T13:00:00Z
completed_at: 2026-05-13T13:25:00Z
files_touched:
  - plugins/pmos-toolkit/skills/architecture/tools/run-audit.sh
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/l1-hygiene/src/log.ts
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/l1-hygiene/src/old-todo.ts
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/l1-hygiene/src/no-purpose.ts
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/l1-hygiene/src/commented.ts
commits:
  - 2d96193  # fixture, backdated GIT_COMMITTER_DATE=2025-01-01 for U005 blame
  - 02e8f9a  # T7 evaluator extension
---

## Summary

L1 debug/hygiene rules folded into the same single-pass python evaluator
T6 introduced. Four behaviours land:

| Rule | Logic |
|---|---|
| U004 (formalised) | regex `console\.log\|print\(` across all rule-pipeline files; path-segment exclude `tests/`, `scripts/` |
| U005 | TODO/FIXME/XXX line whose `git blame --line-porcelain` committer-time > 90 days ago |
| U007 | first non-blank line not starting with `//`, `#`, or `/*` — info-severity |
| U008 | consecutive `//`/`#` line run > 5 with code-like content (any of `(){};=`) |

Severity rewriting via `effective_severity` (final `jq -n`) is unchanged.

## TDD red → green

- **Red:** Pre-T7 audit on `l1-hygiene/` yields the single T6 rule-set
  (U001/U002/U003/U006) plus T6's narrow U004 — none of U005/U007/U008.
- **Green:** Python evaluator emits one finding per rule.
  `tools/run-audit.sh tests/fixtures/l1-hygiene/ | jq '[.findings[].rule_id] | sort | unique'`
  → `["U004","U005","U007","U008"]`.

## Runtime evidence (1 primary + 6 regressions = 7/7 PASS)

| # | Test | Result |
|---|------|--------|
| 1 | **Primary** — `l1-hygiene/` yields exactly `["U004","U005","U007","U008"]` (4 distinct rule_ids; 5 findings total: U004×1, U005×1, U007×2, U008×1) | PASS |
| 2 | `tracer/` (T1): U004 still fires (rule_id=U004 on `src/a.ts:1`). New U007 also fires (tracer's `a.ts` has no purpose comment) — expected from T7's new rule. Primary T1 contract intact. | PASS |
| 3 | `l3-override/` (T4): severity demote intact (`severity="info"`), `rule_overrides.length=1`. U007 also surfaces (also `severity="info"` per principles.yaml#U007 default). | PASS |
| 4 | `principles-16-rules/` (T3): `RUN_AUDIT_PLUGIN_YAML=<fixture>/principles.yaml bash tools/run-audit.sh tests/fixtures/tracer/` → exit 64, `ERROR: L1 has 16 rules; cap is 15.` (FR-21 cap intact) | PASS |
| 5 | `l3-malformed/` (T4): exit 64 with `ERROR: ... malformed:` (FR-23 intact) | PASS |
| 6 | `gitignore-deny/` (T5): `scanned.total=1`, `excluded_by_fallback=3`, `findings=0` (deny-list intact) | PASS |
| 7 | `l1-size/` (T6): U001/U002/U003/U006 still fire. U007 also surfaces (`big.ts`, `big-fn.ts`, `many-args.ts`, `deep.ts` lack purpose comments) — expected from T7's new rule. Primary T6 contract intact. | PASS |

## Decisions / deviations

- **U005 fixture: backdated outer-repo commit, not nested git init.** Plan
  §T7 step 1 calls for `GIT_COMMITTER_DATE="2025-01-01T00:00:00Z"` on the
  TODO commit. Implemented via a fixture-only commit (`2d96193`) with
  both `GIT_COMMITTER_DATE` and `GIT_AUTHOR_DATE` set to 2025-01-01.
  `git blame --line-porcelain` on `src/old-todo.ts` then reports
  `committer-time 1735689600` (= 2025-01-01 UTC) → > 90 days from
  today's 2026-05-13. Avoids the nested-.git-in-repo complication
  (the outer repo would treat a nested `.git/` as a submodule
  boundary; gitignore noise + cloning friction).

- **U005 graceful degrade for unavailable git.** Plan §T7 step 3 says
  "U005: git blame --line-porcelain → committer-time per line". The
  implementation wraps the subprocess in try/except for OSError +
  TimeoutExpired, with a 10s per-file timeout, and skips the rule
  (returns None) when `returncode != 0`. Per FR-32's
  "graceful-degrade when a delegated tool is unavailable" principle.

- **U007 is info-severity, not warn.** principles.yaml#U007 carries
  `severity: info`; the evaluator emits `severity: "info"` accordingly.
  The final `jq -n` severity rewrite still applies L3 overrides on top.
  Plan §T7 calls it "warn-only" — interpreted as "non-blocking, info
  severity" rather than literally the `warn` severity tier (the
  principles.yaml field is the source of truth for default severity).

- **U008 emits one finding per qualifying run, at the run-start line.**
  Plan §T7 step 3 specifies the heuristic but not the emission shape.
  Each consecutive `//`/`#` block that exceeds 5 lines AND contains any
  of `(){};=` produces a single finding with `line` set to the first
  line of the run. Multiple runs in one file → multiple findings.

- **U004 now applies to all extensions, not TS-only.** T6 emitted U004
  only when `is_ts` (the T5 bash loop was TS-only). T7 formalises per
  principles.yaml — regex `console\.log|print\(` runs against every
  rule-pipeline file regardless of extension. Path-segment exclusion
  drops files under any `tests/` or `scripts/` segment.

- **Bash 3.2 heredoc-in-`"$(...)"` quote-counting bug.** Bash 3.2.57
  (default macOS) miscounts double quotes across a quoted heredoc
  embedded inside `"$(...)"` once the body grows past a threshold —
  the T7 python block tripped this (T6 happened to balance evenly).
  Worked around by dropping the outer `"` from the command substitution
  on line 269 (`findings_json=$(...)` not `findings_json="$(...)"`).
  Bash preserves the variable value verbatim across assignment;
  downstream `--argjson f "$findings_json"` still quotes correctly.
  Documented inline above the assignment.

- **Pre-existing regressions remain green; new U007 noise is expected.**
  Tracer and l1-size fixtures lack top-of-file purpose comments, so
  T7's new U007 rule fires on those files. The PRIMARY assertion of
  each prior task (U004 fires on tracer; U001/U002/U003/U006 fire on
  l1-size) is intact. Fixture cleanup (adding purpose comments) is a
  separate cosmetic change, deferred to avoid scope creep into T7.

## Verification outcome

PASS. Primary inline-verification matches plan §T7 byte-for-byte
("4 rule_ids surface on fixture; tracer fixture still produces U004
(regression)"); all 6 prior-task regressions green. T7 sealed;
cursor advances to T8 (L1 grep rules — security/safety: U009, U010).
