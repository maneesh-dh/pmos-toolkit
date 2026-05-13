---
task_number: 12
task_name: "Vue SFC coverage gap surfacing (FR-50/51/52)"
task_goal_hash: "sha256:t12-vue-sfc-coverage-gap-frontend-declarative-coverage"
plan_path: "docs/pmos/features/2026-05-13_architecture-principles-skill/03_plan.html"
branch: "feat/architecture-principles-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-architecture-principles-skill"
status: done
started_at: 2026-05-13T15:15:00Z
completed_at: 2026-05-13T15:30:00Z
files_touched:
  - plugins/pmos-toolkit/skills/architecture/tools/run-audit.sh
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/vue-mixed/src/Comp{1,2,3}.vue
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/vue-mixed/src/util{1..7}.ts
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/vue-mixed/package.json
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/vue-mixed/tsconfig.json
---

## Summary

The F3 honesty layer lands. The audit emits a `frontend_declarative_coverage`
field on any frontend tree (denominator > 0) and prints a `[F3]` stderr
note when coverage is below 1.0:

```
frontend_declarative_coverage = (TS/JS files) / (TS/JS + Vue SFC files)
```

Vue SFCs run L1 grep rules (the python evaluator already iterates all
rule-pipeline files including `.vue`); they do NOT run through the L2
dep-cruiser pipeline because no `.vue`-native declarative parser ships
today. F3 surfaces that asymmetry so operators know the gap exists.

## TDD red → green

- **Red:** Pre-T12 audit on a 3-Vue + 7-TS tree emits no coverage
  signal — operators can't tell that `.vue` files got lighter treatment.
- **Green:**
  - `tools/run-audit.sh tests/fixtures/vue-mixed/ | jq -e '.frontend_declarative_coverage == 0.70'` → exit 0.
  - Stderr contains: `[F3] frontend_declarative_coverage=0.7 — 3 .vue file(s) get L1-semantic treatment only (no L2 dep-cruiser pipeline)`.

## Runtime evidence (1 primary + 9 regressions = 10/10 PASS)

| # | Test | Result |
|---|------|--------|
| 1 | **Primary** — `vue-mixed/` (3 .vue + 7 .ts) yields `frontend_declarative_coverage == 0.70` (jq -e exit 0); F3 stderr note present with exact format | PASS |
| 2 | Pure TS tree (`ts-circular/`) → coverage = 1.0, no F3 note on stderr | PASS |
| 3 | Pure Py tree (`py-tidy-imports/`) → coverage = `null`, no F3 note | PASS |
| 4 | `tracer/` (T1): rule_ids = `["U004","U007"]`, cov=1 | PASS |
| 5 | `l1-size/` (T6): unchanged, cov=1 | PASS |
| 6 | `l1-hygiene/` (T7): unchanged, cov=1 | PASS |
| 7 | `l1-security/` (T8): unchanged, cov=1 | PASS |
| 8 | `l3-override/` (T4): demote intact, cov=1 | PASS |
| 9 | `gitignore-deny/` (T5): scanned=1, excluded=3, findings=[] | PASS |
| 10 | `tool-missing/` (T11): tools_skipped/errored contract intact, cov=1 | PASS |

## Decisions / deviations

- **Coverage 2-decimal precision via `(n / d * 100 | round / 100)`.** jq
  has no built-in `printf "%.2f"`; the multiply-round-divide idiom keeps
  the result as a JSON number (so `== 0.70` equality holds) rather than
  stringifying. 0.7 and 0.70 are the same JSON number — `jq -e` matches.

- **Coverage field is `null` (not `0.0` or `1.0`) on pure-Py / empty
  trees.** Distinct semantics: `null` = "no frontend present, the
  question doesn't apply"; `1.0` = "frontend present, fully covered by
  L2 declarative". Helps consumers (T17 stderr renderer) distinguish.

- **F3 note fires strictly below 1.0.** A `0.99`-coverage tree still
  surfaces the gap; a clean 1.0 tree is silent. Threshold is exact, not
  fuzzy — keeps the signal binary for CI consumption.

- **Vue files don't dispatch differently in the evaluator dispatch.**
  Plan §T12 step 2 says "when file ext == .vue, run L1 grep rules
  only". Today's evaluator already iterates *all* rule-pipeline files
  (via the python single-pass) and runs the L1 regexes on each; only
  the L2 path (dep-cruiser / ruff) is stack-gated. So .vue files already
  receive L1-only treatment naturally — no dispatch change needed. The
  F3 note captures the resulting gap.

- **F3 stderr line is a single line, includes `.vue` count.** Plan §T12
  step 4 says "emit just the F3 line when applicable"; format
  pragmatically chosen as
  `[F3] frontend_declarative_coverage=<v> — <N> .vue file(s) get L1-semantic treatment only (no L2 dep-cruiser pipeline)`
  for grep-friendliness. T17 (full stderr summary) may rewrap this.

- **Fixture coverage = 7/(7+3) = 0.70 exactly.** Plan §T12 inline verify
  is `jq -e '.frontend_declarative_coverage == 0.70'` → true, exit 0.

- **No principles.yaml change.** F3 is a report-shape concern, not a
  rule. The rules YAML stays at 18 entries.

## Verification outcome

PASS. Plan §T12 byte-for-byte: `jq -e '.frontend_declarative_coverage == 0.70'` exits 0 on the vue-mixed fixture; F3 stderr line present with the .vue count. Pure-TS tree emits `coverage=1.0` with no F3 note; pure-Py tree emits `null`. All 9 prior-task regressions green. T12 sealed; cursor advances to T13 (ADR Nygard write).
