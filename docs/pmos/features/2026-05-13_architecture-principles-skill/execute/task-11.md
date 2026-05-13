---
task_number: 11
task_name: "Tool-missing graceful degrade + tools_errored (FR-32)"
task_goal_hash: "sha256:t11-tool-missing-graceful-degrade-tools-errored-fr32"
plan_path: "docs/pmos/features/2026-05-13_architecture-principles-skill/03_plan.html"
branch: "feat/architecture-principles-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-architecture-principles-skill"
status: done
started_at: 2026-05-13T14:55:00Z
completed_at: 2026-05-13T15:10:00Z
files_touched:
  - plugins/pmos-toolkit/skills/architecture/tools/run-audit.sh
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/tool-missing/src/a.ts
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/tool-missing/src/m.py
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/tool-missing/package.json
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/tool-missing/tsconfig.json
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/tool-missing/pyproject.toml
---

## Summary

Formal FR-32 close. Audit now distinguishes two failure modes for each
delegated tool and exits 0 in both:

| Mode | Trigger | Output field |
|---|---|---|
| Skipped | tool not on PATH OR `--version` non-zero | `tools_skipped[]` — names only |
| Errored | tool ran but exited non-zero AND emitted no parseable output | `tools_errored[]` — `{tool, exit_code, stderr (first 200 chars)}` |

Each delegated invocation captures `rc` and `stderr` separately
(`set +e` / `set -e` around the subshell so an erroring tool never
kills the audit). The audit always reaches the final `jq -n` emit;
exit 0 is the contract.

## TDD red → green

- **Red:** Pre-T11 audit with stripped PATH → `tools_skipped` already
  populated (T9/T10 partial), but no separate `tools_errored` field;
  a tool that ran but failed with rc=2 produced silent zero findings.
- **Green:**
  - `PATH=/tmp/fakebin:…` with fake `npx`/`ruff` returning exit 127:
    `tools_skipped=["dependency-cruiser","ruff"]`, exit 0, findings=[]
    (L1 only). ✓
  - Fake `ruff` that passes `--version` but exits 2 with stderr on a
    real py fixture: `tools_errored=[{tool:"ruff", exit_code:2,
    stderr:"fake-config-error"}]`, exit 0. ✓

## Runtime evidence (2 primary + 9 regressions = 11/11 PASS)

| # | Test | Result |
|---|------|--------|
| 1 | **Primary A (tools_skipped)** — fake npx + ruff (exit 127) on `tool-missing/`: `tools_skipped=["dependency-cruiser","ruff"]`, rc=0, findings=[] | PASS |
| 2 | **Primary B (tools_errored)** — fake ruff exits 2 with stderr on `py-tidy-imports/`: `tools_errored=[{ruff,2,"fake-config-error"}]`, rc=0 | PASS |
| 3 | `tracer/` (T1): `["U004","U007"]`, skipped=[], errored=0 | PASS |
| 4 | `l1-size/` (T6): `["U001","U002","U003","U006","U007"]` | PASS |
| 5 | `l1-hygiene/` (T7): `["U004","U005","U007","U008"]` | PASS |
| 6 | `l1-security/` (T8): `["U009","U010"]` | PASS |
| 7 | `l3-override/` (T4): `["U004","U007"]`, demote intact | PASS |
| 8 | `gitignore-deny/` (T5): scanned=1, excluded=3, findings=[] | PASS |
| 9 | `ts-circular/` (T9): `["TS001"]` | PASS |
| 10 | `py-tidy-imports/` (T10): `["PY001","PY004"]` | PASS |
| 11 | `principles-16-rules/` (T3) via env var: exit 64, FR-21 cap intact | PASS |

## Decisions / deviations

- **`set +e` / `set -e` brackets for delegated subshells.** The script
  uses `set -euo pipefail`; a non-zero exit from depcruise/ruff would
  otherwise kill the audit. The fix `set +e; rc=$?` captures the rc
  cleanly while `set -e` resumes after the brackets. Documented inline.

- **"Errored" criterion: rc != 0 AND no stdout.** A tool that exits
  non-zero but still emits valid JSON (e.g., depcruise exits 1 when
  violations are present — the *expected* case) is NOT recorded as
  errored. Only the silent-failure case (rc != 0, empty stdout) lands
  in `tools_errored`. For ruff specifically: `rc=1` is "violations
  found" (expected), `rc>=2` is "actual error" — so the threshold is
  `rc >= 2 && no output`. depcruise has no such convention; we use
  `rc != 0 && no output`.

- **stderr excerpt capped at 200 chars** per plan §T11 step 3. Avoids
  blowing up the JSON report when a delegated tool emits a long
  backtrace. `head -c 200` (binary char count, not lines) — keeps the
  excerpt deterministic across multi-byte locales.

- **`tools_errored` field defaults to `[]`, not omitted.** Consumers can
  always read `.tools_errored[]` without conditional. Same shape contract
  as `tools_skipped`.

- **`tool-missing/` fixture surfaces TS003 under normal PATH.** Expected:
  `useless` in `src/a.ts` is exported but never imported, so depcruise's
  no-orphans rule fires. The primary tests strip the tools, so the
  TS003 fire only appears in the regression-without-stripping pass.
  Not a contradiction — verifies that depcruise runs cleanly when
  available.

- **No fixture commit (the fixture is plain TS+Py with comments).** No
  backdated commits or special git state needed; the FR-32 verification
  is purely about audit behavior under PATH manipulation.

## Verification outcome

PASS. Plan §T11 byte-for-byte: stripped-PATH `tools_skipped == ["dependency-cruiser","ruff"]`, exit 0, only L1 findings (here zero, since the fixture is comment-clean). Both Primary A (skipped) and Primary B (errored) verified independently; all 9 prior-task regressions green; FR-21 cap intact. **Phase 4 complete.** Cursor advances to T12 (Vue SFC gap surfacing + frontend_declarative_coverage).
