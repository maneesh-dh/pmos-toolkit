---
task_number: 1
task_name: "argument-hint + Phase 0 parse for --on-failure"
task_goal_hash: "n/a-tier1-docs"
plan_path: "docs/pmos/features/2026-05-08_update-skills-diagram-on-failure/03_plan.md"
branch: "feature/diagram-on-failure"
worktree_path: "."
status: done
started_at: 2026-05-08T00:00:00Z
completed_at: 2026-05-08T00:00:00Z
files_touched:
  - plugins/pmos-toolkit/skills/diagram/SKILL.md
---

# T1 — Advertise + parse `--on-failure`

Done.

## Verification
- `grep -e --on-failure plugins/pmos-toolkit/skills/diagram/SKILL.md | wc -l` → 4 occurrences (frontmatter + 3 in Phase 0).
- `lint-non-interactive-inline.sh` → `OK: diagram/SKILL.md`.

## Notes
- Edits limited to lines 5 and ~45–47 — no canonical block touched.
