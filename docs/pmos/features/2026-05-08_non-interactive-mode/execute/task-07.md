---
task_number: 7
task_name: "Bats — resolver.bats (9) + classifier.bats (6)"
task_goal_hash: "n/a-fresh-execution"
plan_path: "docs/pmos/features/2026-05-08_non-interactive-mode/03_plan.md"
branch: "feature/non-interactive-mode"
worktree_path: ".worktrees/non-interactive-mode"
status: done
started_at: 2026-05-08T00:42:00Z
completed_at: 2026-05-08T00:55:00Z
files_touched:
  - plugins/pmos-toolkit/tests/non-interactive/test_helper.bash
  - plugins/pmos-toolkit/tests/non-interactive/resolver.bats
  - plugins/pmos-toolkit/tests/non-interactive/classifier.bats
  - plugins/pmos-toolkit/skills/_shared/non-interactive.md
  - plugins/pmos-toolkit/skills/requirements/SKILL.md
---

## Outcome

resolver.bats: 9/9 pass. classifier.bats: 6/6 pass after fixing the awk extractor.

**DEVIATION:** The plan's awk extractor only detected `(Recommended)` on the same line as `AskUserQuestion`. In real SKILL.md files (and the plan's own classifier fixtures), `(Recommended)` appears on subsequent option lines. Replaced the simple per-line emit with a state-machine: the call site becomes a "pending call" that is emitted when closed by a blank line, a defer-only tag, another `AskUserQuestion`, or EOF. Any non-blank line between open and close that contains `(Recommended)` flips `has_recc`. This matches both the plan-provided fixtures and real SKILL.md patterns.

After re-syncing the canonical block into /requirements: lint OK; audit reports 16 unmarked calls (still expected pre-tagging, T22).

Committed: `test(T7): resolver.bats (9) + classifier.bats (6); fix awk to detect (Recommended) in option block`.
