---
task_number: 3
task_name: "Modify Phase 9 — fetch + 3-way pre-flight + recovery hookup"
plan_path: "docs/pmos/features/2026-05-08_update-skills-complete-dev-merge/03_plan.md"
branch: "feature/complete-dev-rebase-version-bump"
worktree_path: "."
status: done
started_at: 2026-05-08
completed_at: 2026-05-08
files_touched:
  - plugins/pmos-toolkit/skills/complete-dev/SKILL.md
---

Phase 9 now contains: Step 1 (`git fetch origin main` with timeout note), Step 2 (`main_v` read), Step 3 (`branch_point_v` via `git merge-base`), Step 4 (decision table), Step 4a (stale-bump AskUserQuestion), Step 5 (bump prompt with resolved baseline). Pointer to `reference/version-bump-recovery.md` added. FRs covered: FR-06..14, FR-17, NFR-01, NFR-03.

DEVIATION: live Phase 9 at line 345 (plan said 214). Same root cause as T2.
