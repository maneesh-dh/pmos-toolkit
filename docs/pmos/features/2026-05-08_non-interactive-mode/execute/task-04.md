---
task_number: 4
task_name: "Implement tools/lint-non-interactive-inline.sh"
task_goal_hash: "n/a-fresh-execution"
plan_path: "docs/pmos/features/2026-05-08_non-interactive-mode/03_plan.md"
branch: "feature/non-interactive-mode"
worktree_path: ".worktrees/non-interactive-mode"
status: done
started_at: 2026-05-08T00:18:00Z
completed_at: 2026-05-08T00:23:00Z
files_touched:
  - plugins/pmos-toolkit/tools/lint-non-interactive-inline.sh
  - plugins/pmos-toolkit/tests/non-interactive/lint-script.bats
---

## Outcome

Lint script clones lint-pipeline-setup-inline.sh shape; canonical file = `_shared/non-interactive.md`; supported-skills list derived dynamically (excludes `_shared`, `learnings`, and any skill carrying `<!-- non-interactive: refused`). 26 supported skills detected — matches plan. lint-script.bats: 3 pass + 1 skip (refused-skill case verified post-T26).

Committed: `feat(T4): lint-non-interactive-inline.sh + bats coverage`.
