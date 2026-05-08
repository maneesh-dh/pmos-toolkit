---
task_number: 5
task_name: "Implement tools/audit-recommended.sh"
task_goal_hash: "n/a-fresh-execution"
plan_path: "docs/pmos/features/2026-05-08_non-interactive-mode/03_plan.md"
branch: "feature/non-interactive-mode"
worktree_path: ".worktrees/non-interactive-mode"
status: done
started_at: 2026-05-08T00:23:00Z
completed_at: 2026-05-08T00:28:00Z
files_touched:
  - plugins/pmos-toolkit/tools/audit-recommended.sh
---

## Outcome

Audit script implemented per plan: extracts EXTRACTOR_AWK from canonical file, supports `--strict-keywords` mode, refused-skill exemption, default glob over all skills. Smoke run pre-rollout: 178 unmarked calls across 26 skills (FAIL exit 1). `--strict-keywords` on `/execute` emitted 2 WARN lines (advisory; doesn't affect exit code).

Committed: `feat(T5): audit-recommended.sh — assert every AskUserQuestion is marked (with --strict-keywords mode)`.
