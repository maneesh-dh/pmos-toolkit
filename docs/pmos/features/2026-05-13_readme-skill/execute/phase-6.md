---
phase_number: 6
phase_name: "Update mode + commit-classifier"
tasks_in_phase: [17, 18, 19]
plan_path: "docs/pmos/features/2026-05-13_readme-skill/03_plan.html"
branch: "feat/readme-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-readme-skill"
status: sealed
started_at: 2026-05-13T18:30:00Z
completed_at: 2026-05-13T20:15:00Z
verify_status: PASS_WITH_RESIDUALS
verify_reports:
  - "docs/pmos/features/2026-05-13_readme-skill/verify/2026-05-13-phase-6/report.md"
commits:
  - 2780e86  # T17 feat — commit-classifier.sh + 3 fixtures + --selftest
  - 711c8c5  # T17-log
  - 06b9357  # T18 feat — update-mode flow + FR-UP-3 patch-fail guard
  - e035e70  # T18-log
  - 1b1d9a2  # T19 feat — opt-in dual gate + git-add-only stage (FR-UP-4 + FR-UP-5)
  - 3888bc8  # T19-log
recommendation: PROCEED_TO_PHASE_7
waves:
  - wave: 1
    tasks: [17, 18]
    parallel: true
    review_style: "combined per-task + phase-boundary (disjoint files: scripts/+tests/ vs SKILL.md)"
  - wave: 2
    tasks: [19]
    parallel: false
    review_style: "combined per-task + phase-boundary (single-task SKILL.md wave)"
residuals: []
---

## Summary

Phase 6 closes the update-mode vertical:
- **T17** lands `scripts/commit-classifier.sh` (~165 LOC, FR-SS-3 commit_affinity) + 3 deterministic fixtures (`tests/fixtures/commits/{01_feat-only,02_no-conv-commit,03_breaking}` with gitignored `.git/` materialisers) + `--selftest` 3/3 PASS. Reads `commit_affinity` from `reference/section-schema.yaml` at runtime — single source of truth.
- **T18** lands `### §7: Update-mode flow` (FR-UP-1/2/3): 6-step runtime — commit-classifier dispatch → per-section AskUserQuestion (≤4 batch) → working-tree stage → re-run §1 rubric → FR-UP-3 patch-fail guard (revert + `.pmos/readme/update.log` JSONL + /retro finding + release proceeds unpatched) → defer staging to §8. E12 + E13 short-circuit paths included. Phase-5-r3 anchor fix folded in.
- **T19** lands `### §8: Opt-in dual gate` (FR-UP-4 + FR-UP-5): 2 flag reads (user-global `phase_7_6_hook_enabled` + per-run `readme_update_hook`), 6-row truth-table covering true/false/absent permutations, single-line warn, re-enablement recipes, "why dual" rationale, FR-UP-5 staging-only contract (`git add` only, no commit/no push).

SKILL.md at 418 / 480 lines (plan target met). P11 append-only verified: 2 deletions across Phase 6 (both the declared T18 anchor-fix cosmetics — phase-5-r3 closure).

## Demoability

The live commit-range path is real for the first time in this build. `bash scripts/commit-classifier.sh --selftest` runs against three real fixture git repos (materialised on-demand via `setup.sh`) and emits the section-affinity JSON the §7 flow consumes — selftest passes 3/3 against the FR-SS-3 commit_affinity table. The §7 + §8 SKILL.md flow remains documentation-as-contract for end-to-end `/readme --update` against a release branch (live AskUserQuestion + Task-tool wiring at T22+; PARTIAL by design P9).

## Deviations declared in waves

- **Wave 1 (T17)**: None. Clean disjoint-files commit chain.
- **Wave 1 (T18)**: 2-line anchor fix to §1 cross-refs at lines 244 + 325 (`#1-single-file-audit-flow` → `#single-file-audit-flow`). Declared in T18 log as **cosmetic surgery closing phase-5-r3**. Not a P11 violation — restores intra-document navigation broken at the spec-text level; touches no substantive §1-§6 content. 8 chars per edit.
- **Wave 2 (T19)**: None.
- Review style: Wave 1 disjoint-files (T17 in scripts/+tests/; T18 in SKILL.md) → combined per-task + phase-boundary reviewer per wave. Wave 2 single-task SKILL.md → same combined style.

## Next phase

**Phase 7 — Cross-file rules + monorepo (T20 / T21 / T22).** T20 lands cross-file consistency checks R1-R4 (probably extending `rubric.sh` or adding a sibling). T21 closes `[phase-2-r4]` (plugin-manifest-mentioned warn-and-skip) via the F15 user-override hook path. T22 composes the audit + scaffold + update modes into the monorepo unified-diff emission path and lands the `--scope` argv plumbing (closes `[phase-5-r4]`) + the final SKILL.md integration that closes the by-design P9 envelope (`[phase-4-r1/r2/r3]` + `[phase-5-r1]`).
