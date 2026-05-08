---
task_number: 5
task_name: "runbook addendum + final verification"
task_goal_hash: "n/a-tier1-docs"
plan_path: "docs/pmos/features/2026-05-08_update-skills-diagram-on-failure/03_plan.md"
branch: "feature/diagram-on-failure"
worktree_path: "."
status: done
started_at: 2026-05-08T00:00:00Z
completed_at: 2026-05-08T00:00:00Z
files_touched:
  - plugins/pmos-toolkit/tests/non-interactive/per-skill-rollout-runbook.md
---

# T5 — Runbook addendum + final verification

Done.

## Acceptance criteria checklist

- [x] **AC1** argument-hint advertises `--on-failure` with all 3 values (line 5).
- [x] **AC2** Phase 0 documents validation + default + interactive-advisory (lines 48–51).
- [x] **AC3a** drop → no SVG, no sidecar, Exit 3 (line 361).
- [x] **AC3b** ship-with-warning → warning comment, Exit 0 (line 362).
- [x] **AC3c** exit-nonzero → no SVG, no sidecar, Exit 4 (line 363).
- [x] **AC3d** default `exit-nonzero` documented (lines 50, 357, 391).
- [x] **AC4** interactive AUQ unchanged — 3 options still present.
- [x] **AC5** Exit-Code contract table present (lines 384+).
- [x] **AC6** `<!-- non-interactive: handled-via on-failure-flag -->` tag present (line 367).
- [x] **AC7** bats 7/7 green.
- [x] **AC8** sidecar schema diff empty.
- [x] **Lint** `lint-non-interactive-inline.sh` OK for diagram/SKILL.md.
- [x] **Audit** `audit-recommended.sh` PASS (10 calls, 10 defer-only, 0 unmarked).
- [x] **No collateral damage** canonical non-interactive-block (lines ~80–163) untouched in diff.

## Final state

5 commits on `feature/diagram-on-failure`:
1. `chore: /update-skills orchestration — pipeline status to execute`
2. `feat(T1): add --on-failure flag to argument-hint and Phase 0 parse`
3. `feat(T2): mode-gated Phase 6.5 dispatch + Exit-Code contract`
4. `test(T3): bats contract assertions for --on-failure`
5. `docs(T5): runbook addendum for /diagram --on-failure`

(T4 was a read-only verification step with no commit.)

## Cleanup
None — no temp files, no containers, no flags.
