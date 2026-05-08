---
task_number: 11
task_name: "refusal.bats (2 cases for FR-07)"
task_goal_hash: "n/a-fresh-execution"
plan_path: "docs/pmos/features/2026-05-08_non-interactive-mode/03_plan.md"
branch: "feature/non-interactive-mode"
worktree_path: ".worktrees/non-interactive-mode"
status: done
started_at: 2026-05-08T01:14:00Z
completed_at: 2026-05-08T01:19:00Z
files_touched:
  - plugins/pmos-toolkit/tests/non-interactive/test_helper.bash
  - plugins/pmos-toolkit/tests/non-interactive/refusal.bats
  - plugins/pmos-toolkit/tests/non-interactive/fixtures/refusal-msf-req-shape.md
---

## Outcome

2/2 pass.

**DEVIATION:** Plan's sed regex for the alternative field was `[^-]+` (anything-but-hyphen), but real alternatives contain hyphens (e.g., `--apply-edits`). Replaced with `(.+)[[:space:]]+-->[[:space:]]*$` (greedy capture up to closing comment marker).

Committed: `test(T11): refusal.bats (2 cases — FR-07.1, FR-07.2)`.
