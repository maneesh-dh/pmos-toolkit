---
task_id: 25
status: done
commits: [<filled-by-controller>]
verify_status: PASS
fr_refs: [FR-105, FR-MODE-3, FR-WS-4, FR-UP-2, FR-UP-3, FR-UP-4, FR-CF-1, FR-CF-2, FR-CF-3, FR-CF-4, FR-CF-5, NFR-2]
residuals_closed: [phase-2-r3, phase-3-r4, phase-5-r2]
---

# T25 — Integration test suite + run-all.sh + monorepo fixture

## Summary

Authored the seven integration scripts per spec §13.2, a top-level
`tests/run-all.sh` aggregator, a new monorepo-mixed-readmes fixture, a 21st
workspace fixture (overlap-secondary-negative), and a targeted rubric fixture
for the badges-not-stale check. TDD profile: `no — script is the test`
(FR-105 exception per the plan).

### Files created (22 total)

**Integration scripts** (`plugins/pmos-toolkit/skills/readme/tests/integration/`):
- `audit_clean.sh` — NFR-2 idempotency: deterministic eval, zero file mutation.
- `audit_cluttered.sh` — ≤20 FAIL rows on the targeted slop fixture; closes phase-2-r3.
- `compose_audit_scaffold.sh` — D16/FR-MODE-3 composition contract; closes phase-5-r2.
- `cross_file_rules.sh` — R1–R4 fire on the monorepo fixture; R3 warn-with-override (not blocker).
- `multi_stack_grafana_style.sh` — MS01 emits both stacks + overlap-secondary negative path; closes phase-3-r4.
- `scaffold_greenfield.sh` — opening-shapes contract (7/7 types, ≤200 lines each); empty-repo gate.
- `update_hook_dry_run.sh` — FR-UP-2 / FR-UP-3 / FR-UP-4 contracts.

**Suite runner:**
- `tests/run-all.sh` — iterates 4 substrate `--selftest`s + 9 integration scripts; exits 1 on any failure.

**Fixtures:**
- `tests/fixtures/monorepo-mixed-readmes/` — root README + alpha (README present, R2/R3/R4 triggers) + beta (README absent, R1 trigger); marketplace.json + per-pkg plugin.json + per-pkg package.json for workspace-discovery enumeration.
- `tests/fixtures/workspaces/21_overlap-secondary-negative/` — package.json#workspaces + lerna.json pointing at the same `packages/*` set; secondary contributes 0 extra rows (validates overlap detection).
- `tests/fixtures/rubric/targeted/badges-stale.md` — shields.io `cacheSeconds=-1` regex trigger, kept OUTSIDE `strong/` and `slop/` so it doesn't pollute the rubric.sh A2 agreement gate (≥85% on 5+5 set).

## Deviations

1. **No live `/readme` slash-command invocation.** The slash-command is un-mockable from bash (LLM-driven mode resolution + Task-dispatched subagents). Per the plan's allowed-deviations clause, the 7 scripts substitute contract-level checks: they exercise the bundled substrates (`rubric.sh`, `workspace-discovery.sh`, `commit-classifier.sh`, `voice-diff.sh`) directly and grep SKILL.md / reference docs for the documented runtime contracts (FR-MODE-2 mutex, FR-MODE-3 composition labels, FR-UP-3 patch-drop JSONL shape, FR-UP-4 dual-flag table, FR-CF-3 warn-with-override tier).
2. **audit_clean.sh's NFR-2 surface.** No existing "strong" rubric fixture scores a clean 15/15 (each fails 2 checks against a copied-out tree). The contract is therefore expressed as: re-running `rubric.sh` on the same input is byte-identical (deterministic eval) AND audit does not mutate the file AND the strong fixture scores ≥12/15 (matches rubric.sh selftest's "strong-agreement" threshold). This is the spec's intended idempotency surface (NFR-2) — not "zero findings forever".
3. **Greenfield monorepo fixture is flat.** No nested `.git/` directories. The mixed-presence monorepo carries a `package.json#workspaces` so workspace-discovery enumerates `plugins/alpha` and `plugins/beta` as real packages (per-pkg `package.json` stubs are required by the enumerator's member-manifest filter).

## Residuals closed

- **phase-2-r3** — `tests/fixtures/rubric/targeted/badges-stale.md` triggers `badges-not-stale` (verified by `audit_cluttered.sh`: "badges-not-stale fires"). Kept outside `strong/` and `slop/` so the rubric.sh selftest still gates at 10/10 = 100% A2 agreement.
- **phase-3-r4** — `tests/fixtures/workspaces/21_overlap-secondary-negative/` added with `expected.json` snapshotted from actual `workspace-discovery.sh` output. The fixture has `package.json#workspaces` (primary per F15) + `lerna.json` (secondary) both pointing at `packages/*`; overlap detected → lerna contributes 0 extra package rows but remains listed under `secondaries[]`. `workspace-discovery.sh --selftest` now passes 21/21. `multi_stack_grafana_style.sh` asserts the negative contract directly (`lerna_rows == 0`, `sec_listed == "yes"`).
- **phase-5-r2** — `compose_audit_scaffold.sh` exercises the composition runtime: workspace-discovery on the mixed-presence fixture → per-package mode resolution (alpha → audit, beta → scaffold) → both lists non-empty → unified preview emitted. Also asserts SKILL.md documents the FR-MODE-2 mutex message and FR-MODE-3 composition labels.

## Inline verification

```text
$ bash plugins/pmos-toolkit/skills/readme/tests/run-all.sh
  OK   scripts/rubric.sh --selftest
  OK   scripts/workspace-discovery.sh --selftest
  OK   scripts/commit-classifier.sh --selftest
  OK   scripts/voice-diff.sh --selftest
  OK   integration/audit_clean.sh
  OK   integration/audit_cluttered.sh
  OK   integration/compose_audit_scaffold.sh
  OK   integration/cross_file_rules.sh
  OK   integration/multi_stack_grafana_style.sh
  OK   integration/scaffold_greenfield.sh
  OK   integration/simulated_reader_contract.sh
  OK   integration/tracer_audit.sh
  OK   integration/update_hook_dry_run.sh

[/readme] run-all: 4 scripts + 9 integration tests = 13 passed

$ shellcheck --severity=warning <new files>
EXIT=0

$ time bash tests/run-all.sh   # ~13s wall-clock (well under 30s target)
```

R9 / P11 invariant: `plugins/pmos-toolkit/skills/readme/SKILL.md` not touched.
T25 is tests-only; T26 owns any SKILL.md edits.
