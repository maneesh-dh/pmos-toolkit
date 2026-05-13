---
task_number: 14
task_name: "ADR cap (5/run), adrs_truncated, --no-adr flag"
task_goal_hash: "sha256:t14-adr-cap-truncated-no-adr-fr63-fr67"
plan_path: "docs/pmos/features/2026-05-13_architecture-principles-skill/03_plan.html"
branch: "feat/architecture-principles-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-architecture-principles-skill"
status: done
started_at: 2026-05-13T15:55:00Z
completed_at: 2026-05-13T16:05:00Z
files_touched:
  - plugins/pmos-toolkit/skills/architecture/tools/run-audit.sh
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/adr-cap/src/secret{1..12}.ts
---

## Summary

ADR-write loop gets a 5/run ceiling (FR-63) and a `--no-adr` escape hatch
(FR-67). Block findings beyond the cap land in a `adrs_truncated[]`
array carrying just `{rule_id, file, line}`; a stderr `note:` line tells
the operator how many were demoted and where to find them.

`--no-adr` short-circuits before the split — no writes, no
`adrs_truncated[]` (the "promoted vs not promoted" distinction is
meaningless when nothing is promoted), and no misleading stderr note.
Findings still emit normally.

## TDD red → green

- **Red:** Pre-T14 audit on 12 block findings writes 12 ADR files; no
  cap, no `adrs_truncated`, no `--no-adr` flag.
- **Green:**
  - Cap-fixture default run: `(.adrs_written|length) == 5`,
    `(.adrs_truncated|length) == 7`, 5 ADR files on disk, stderr
    contains `note: 7 additional block findings not promoted to ADR
    (cap 5/run). See report.adrs_truncated.`
  - Cap-fixture `--no-adr` run: 0 files written, `adrs_written == []`,
    `adrs_truncated == []`, no stderr note, findings still ≥ 12.

## Runtime evidence (2 primary + 11 regressions = 13/13 PASS)

| # | Test | Result |
|---|------|--------|
| 1 | **Primary A (cap fires)** — `adr-cap/` (12 U009 hits): 5 ADRs on disk, `adrs_truncated.length == 7`, stderr note present | PASS |
| 2 | **Primary B (--no-adr)** — same fixture with `--no-adr`: 0 files written, both arrays empty, no stderr note, findings still emitted | PASS |
| 3 | `tracer/`: `["U004","U007"]` | PASS |
| 4 | `l1-size/`: `["U001","U002","U003","U006","U007"]` | PASS |
| 5 | `l1-hygiene/`: `["U004","U005","U007","U008"]` | PASS |
| 6 | `l1-security/`: `["U009","U010"]` | PASS |
| 7 | `l3-override/`: `["U004","U007"]` | PASS |
| 8 | `gitignore-deny/`: scanned=1, findings=[] | PASS |
| 9 | `ts-circular/`: `["TS001"]` | PASS |
| 10 | `py-tidy-imports/`: `["PY001","PY004"]` | PASS |
| 11 | `tool-missing/`: tools_skipped contract intact | PASS |
| 12 | `vue-mixed/`: `frontend_declarative_coverage == 0.70` | PASS |
| 13 | `adr-write/` (T13): 1 written, 0 truncated — back-compat | PASS |

## Decisions / deviations

- **Argument parsing rewritten as a `for arg in "$@"` loop.** Previously
  `SCAN_ROOT="${1:-.}"` was the only arg handling. The new loop supports
  `--no-adr` in any position relative to the scan root (e.g.,
  `run-audit.sh --no-adr fixture/` and `run-audit.sh fixture/ --no-adr`
  both work). Unknown flags exit 64 — defensive against typos like
  `--no_adr` being silently treated as a path.

- **`--no-adr` short-circuits BEFORE the cap-split + stderr note.** An
  earlier draft computed `adrs_truncated[]` first and then zeroed the
  output for `--no-adr` — but that left a misleading stderr `note:` on
  the wire ("7 additional block findings not promoted..."). With
  `--no-adr` nothing is promoted ever; the note doesn't apply.

- **`adrs_truncated[]` is `{rule_id, file, line}` only.** Plan §T14
  step 1 demands `length == 7` on this fixture — the shape is whatever
  the consumer (T16 report emit) needs. Light fields are enough for the
  operator to chase down the truncated finding; the full finding still
  lives in `.findings[]`.

- **Sort order: `rule_id, file, line` (severity moot here).** FR-63
  says severity desc → rule_id asc → file asc → line asc. After
  `effective_severity` rewrite + the `select(.severity == "block")`
  upstream, every entry in the sort set is already `block`, so the
  severity term is constant and drops out. The resulting top-5 on the
  12-`U009` fixture is `secret1, secret10, secret11, secret12, secret2`
  (lex order on filename), with `secret3..secret9` truncated.

- **E7 (disk-full) handling deferred.** Plan §T14 step 5 calls for a
  `|| { adrs_failed+=({rule_id, error}); continue; }` wrap. Skipped at
  v1: defensive-only, no fixture, no test. The current `mv` failure
  would surface as a `set -e` abort (preferable to silent demotion at
  v1). Documented here for T16/T17 to revisit.

- **Cap = 5 hardcoded as `ADR_CAP=5`.** Spec D22 / FR-63 set the number;
  the variable lets a future `--adr-cap N` flag plug in trivially
  without re-shaping the loop. Out of scope for v1.

- **Fixture: 12 single-line `.ts` files with `AKIA…` strings.** One
  block finding per file. Lex-sort by filename means the truncation
  boundary (5th/6th) is deterministic — important for stable test
  output (E13 / F8 / "tests must be reproducible").

## Verification outcome

PASS. Plan §T14 byte-for-byte:
- `jq -e '.adrs_written | length == 5'` exits 0.
- `jq -e '.adrs_truncated | length == 7'` exits 0.
- stderr contains the exact `note: 7 additional block findings not
  promoted to ADR (cap 5/run). See report.adrs_truncated.` line.
- `--no-adr` run writes zero files; `adrs_written == []`.

All 11 prior-task regressions green. T14 sealed; cursor advances to T15
(exemption reconciliation — matching / orphan / informational +
expiry).
