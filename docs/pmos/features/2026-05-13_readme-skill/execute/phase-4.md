---
phase_number: 4
phase_name: "Simulated-reader (parallel personas)"
tasks_in_phase: [11, 12, 13]
plan_path: "docs/pmos/features/2026-05-13_readme-skill/03_plan.html"
branch: "feat/readme-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-readme-skill"
status: sealed
started_at: 2026-05-13T15:10:00Z
completed_at: 2026-05-13T16:30:00Z
verify_status: PASS
verify_reports:
  - "docs/pmos/features/2026-05-13_readme-skill/verify/2026-05-13-phase-4/report.md"
commits:
  - {sha: c9e6c80, subject: "feat(T11): simulated-reader.md — 3 personas + return-shape contract"}
  - {sha: 7ef1f23, subject: "execute(T11-log): per-task log"}
  - {sha: d718646, subject: "feat(T12): SKILL.md — parallel Task dispatch + FR-SR-3 validation"}
  - {sha: cbc6cf2, subject: "execute(T12-log): per-task log"}
  - {sha: 3bf8620, subject: "feat(T13): theater-check + --skip-simulated-reader + stub contract"}
  - {sha: a0ba1a4, subject: "execute(T13-log): per-task log"}
recommendation: PROCEED_TO_PHASE_5
waves:
  - {wave: 1, tasks: [11, 12], parallel: true, review_style: "combined per-task + phase-boundary (disjoint files: reference/simulated-reader.md vs SKILL.md)"}
  - {wave: 2, tasks: [13], parallel: false, review_style: "combined per-task + phase-boundary (SKILL.md §3 + new tests/mocks + tests/integration)"}
residuals:
  - "[phase-4-r1] Live Task-tool parallel dispatch unexercised — by design per P9; verified via env-var READMER_PERSONA_STUB stub. Closed at T22+."
  - "[phase-4-r2] FR-SR-5 theater-check re-dispatch has stub-trigger coverage only; live re-dispatch deferred to T22+ (same constraint as r1)."
  - "[phase-4-r3] FR-SR-4 dedupe rule documented in SKILL.md §2 step 4; end-to-end exercise deferred to T17+ when aggregator + section-schema lookup wire together."
---

## Summary

Phase 4 closes the simulated-reader vertical: a `reference/simulated-reader.md` (T11) carrying the three persona prompts + return-shape contract, an `## Implementation §2` block in SKILL.md (T12) documenting the parallel `Task` dispatch + FR-SR-3 substring validation + FR-SR-4 dedupe, and an `## Implementation §3` block (T13) layering FR-SR-5 theater-check + FR-SR-6 `--skip-simulated-reader` + the P9 `READMER_PERSONA_STUB` env-var contract-test escape with a 3-assertion shellcheck-clean contract harness.

All six FR-SR IDs are cited at point-of-use across the docs; P11 append-only invariant holds (0 removed lines T7→T12, 0 removed lines T12→T13); SKILL.md sits at 219 / 480 lines and `reference/simulated-reader.md` at 167 / 200 lines.

## Demoability

Demoable inside the env-var-gated stub surface: `READMER_PERSONA_STUB=1 bash tests/integration/simulated_reader_contract.sh` exercises (a) FR-SR-1 return-shape parsing, (b) FR-SR-3 substring-match positive, (c) FR-SR-3 1-char-slip hard-fail, (d) FR-SR-5 theater-check empty-friction trigger fixture. Live Task-tool parallel dispatch + live re-dispatch are NOT exercised in this phase — by design per P9, those land at T22+ when SKILL.md final integration completes.

## Deviations declared in waves

- **Wave 2 (T13)**: stub fixture content adapted from spec example (`acme-cli`) to actual T8 corpus (`ripgrep` README) — preserves spec intent (verbatim ≥40-char substring positive case + 1-char casing slip negative case), declared in `execute/task-13.md`. No spec drift.
- Per-task review style for Phase 4: combined per-task + phase-boundary for both waves. Wave 1's parallel-disjoint-files shape made independent per-task reviewers redundant given the boundary reviewer reads both diffs together.

## Next phase

**Phase 5 — Scaffold mode + repo-miner (T14-T16).** Plan rationale: T14 lands the `--scaffold` flag protocol in SKILL.md, T15 lands the repo-miner that harvests commit-affinity signals, T16 wires scaffold mode into the SKILL.md flow. Demoable after T16: invoking `/readme --scaffold` on a fresh repo produces a section spine with commit-affinity hints.
