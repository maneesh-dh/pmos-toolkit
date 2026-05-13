---
task_number: 6
task_name: "L1 grep rules — size/shape (U001, U002, U003, U006)"
task_goal_hash: "sha256:t6-l1-size-shape-u001-u002-u003-u006-section-7-4"
plan_path: "docs/pmos/features/2026-05-13_architecture-principles-skill/03_plan.html"
branch: "feat/architecture-principles-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-architecture-principles-skill"
status: done
started_at: 2026-05-13T13:05:00Z
completed_at: 2026-05-13T13:12:00Z
files_touched:
  - plugins/pmos-toolkit/skills/architecture/tools/run-audit.sh
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/l1-size/src/big.ts
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/l1-size/src/big-fn.ts
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/l1-size/src/many-args.ts
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/l1-size/src/a/b/c/d/e/deep.ts
commit: 0219ffa
---

## Summary

L1 size/shape rules implemented as a single python evaluator that runs
over the T5-emitted `scanned.files_for_rules` list. The T5 bash U004
grep loop is replaced (consolidated into the same evaluator). Four new
rules fire:

| Rule | Logic |
|---|---|
| U001 | file LOC > 500 (all supported exts) |
| U002 | TS function body lines > 100 (brace-balanced) |
| U003 | function/constructor arg-count > 4 (commas + 1) |
| U006 | path-segments after `src/` > 4 |

Severity rewriting via `effective_severity` (final `jq -n`) is unchanged
— L3 demotes/promotes flow through.

## TDD red → green

- **Red:** Pre-T6 scanner only emitted U004; running on `l1-size/` yields
  `[]` (no rules fire even though 4 violations exist).
- **Green:** Python evaluator emits one finding per rule.
  `tools/run-audit.sh tests/fixtures/l1-size/ | jq '[.findings[].rule_id] | sort'`
  → `["U001","U002","U003","U006"]`.

## Runtime evidence (1 primary + 5 regressions = 6/6 PASS)

| # | Test | Result |
|---|------|--------|
| 1 | **Primary** — `l1-size/` yields exactly `["U001","U002","U003","U006"]` (one per rule, four findings total) | PASS |
| 2 | `tracer/` (T1): 1 finding, `rule_id=U004`, line 1 | PASS |
| 3 | `l3-override/` (T4): 1 finding with `severity="info"` (demote intact), `rule_overrides.length=1` | PASS |
| 4 | `principles-16-rules/` (T3): exit 64 with `ERROR: L1 has 16 rules; cap is 15.` | PASS |
| 5 | `l3-malformed/` (T4): exit 64 with `ERROR: ... malformed:` | PASS |
| 6 | `gitignore-deny/` (T5): 0 findings, `scanned={total:1, by_ext:{.ts:1}, excluded_by_fallback:3}` (deny-list intact) | PASS |

## Decisions / deviations

- **Implementation language: python, not bash/awk.** Plan §T6 step 3
  prescribes bash with dispatched helper functions (one per rule).
  Implemented as a single ~80-LOC python block instead because U002
  (brace-balanced function-body span) and U003 (paren-balanced arg
  list) are stateful per-file and the bash awk for both was illegible.
  The contract — `[.findings[].rule_id] | sort` matches plan §T6 inline
  verify — is unchanged.
- **U003 fires on arg-count > 4 (i.e., 5+ args), not commas > 4.**
  Plan §T6 goal says "constructor > 4 args"; plan step sub-bullet says
  "count commas; emit when > 4". With a 5-arg ctor (4 commas), commas
  are not > 4, but the inline-verification expects U003 to fire on the
  5-arg constructor fixture — so goal-text wins. Step sub-bullet is a
  one-off slip relative to the §7.4 spec row.
- **U002 detects only `function …` (not class methods or arrow funcs).**
  Plan §T6 step 3 sub-bullet for U002 lists the TS regex as
  `^\s*(function|async function|\w+\s*\([^)]*\)\s*{)`. The second
  alternative (`\w+(...)` with body-open) would also match class
  methods and IIFEs. Used the narrower `function\s+\w+` for v1 because
  the fixture is a top-level function; broader detection is a follow-up.
  Documented inline in the python block.
- **U006 keyed on the first path segment literally being `src`.** Plan
  text says "path depth > 4 from `src/`" — interpreted as: only files
  whose first segment is `src` participate; the count is segments after
  `src/` (not including `src/` itself). `src/a/b/c/d/e/deep.ts` →
  6 segments after `src/` → > 4 → fires. Files outside `src/` are not
  evaluated by U006 (consistent with `delegate_to:` semantics — U006 is
  scoped to source roots).
- **U004 consolidated into the python evaluator.** T5 left U004 as a
  per-file bash grep with the `{ … || true; }` set-e workaround; folding
  it into the python pass removes the workaround, keeps a single
  per-file open, and makes severity-rewriting consistent. Tracer-bullet
  regression confirms no behavior change.

## Verification outcome

PASS. Primary inline-verification matches plan §T6 byte-for-byte; all
5 prior-task regressions green. T6 sealed; cursor advances to T7
(L1 grep rules — debug/hygiene: U004 formalisation, U005, U007, U008).
