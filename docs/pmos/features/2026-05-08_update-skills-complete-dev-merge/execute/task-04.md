---
task_number: 4
task_name: "Append anti-pattern entry — SHA-equality test caveat"
plan_path: "docs/pmos/features/2026-05-08_update-skills-complete-dev-merge/03_plan.md"
branch: "feature/complete-dev-rebase-version-bump"
worktree_path: "."
status: done
started_at: 2026-05-08
completed_at: 2026-05-08
files_touched:
  - plugins/pmos-toolkit/skills/complete-dev/SKILL.md
---

Anti-pattern #14 appended after #13 (line 640). Text matches FR-15 verbatim. `grep -q 'necessary-but-not-sufficient'` confirms.

DEVIATION (non-blocking): plan's `grep -c '^[0-9]\+\. \*\*'` expected `14` but live count is 24 — the regex matches numbered items in other phases, not just anti-patterns. Manual inspection confirms entry #14 is the new SHA-equality entry. The plan's count assertion was naive; the named-grep check is sufficient.
