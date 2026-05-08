---
task_number: 6
task_name: "Pilot — inline non-interactive block in /requirements SKILL.md"
task_goal_hash: "n/a-fresh-execution"
plan_path: "docs/pmos/features/2026-05-08_non-interactive-mode/03_plan.md"
branch: "feature/non-interactive-mode"
worktree_path: ".worktrees/non-interactive-mode"
status: done
started_at: 2026-05-08T00:28:00Z
completed_at: 2026-05-08T00:42:00Z
files_touched:
  - plugins/pmos-toolkit/skills/requirements/SKILL.md
  - plugins/pmos-toolkit/skills/_shared/non-interactive.md
  - plugins/pmos-toolkit/tools/lint-non-interactive-inline.sh
  - plugins/pmos-toolkit/tools/audit-recommended.sh
  - plugins/pmos-toolkit/tests/non-interactive/per-skill-rollout-runbook.md
---

## Outcome

Inlined the canonical non-interactive-block into `/requirements` SKILL.md's Phase 0 (immediately after `<!-- pipeline-setup-block:end -->`). Extended `argument-hint` with `[--non-interactive | --interactive]`. Lint reports `OK: requirements/SKILL.md`. Audit reports 16 unmarked calls in /requirements — expected because destructive tagging is part of T22 (Phase 3), not T6.

**Two plan deviations surfaced and fixed (documented in runbook stub):**
1. Refusal-marker grep was too loose — matched the prose mention inside the inlined block. Tightened to `^[[:space:]]*<!-- non-interactive: refused`.
2. Awk extractor matched `AskUserQuestion` substrings inside its own self-referencing comment text in the inlined block. Added skip rules at the top of the extractor for `<!-- non-interactive-block:start/end -->`.

Committed: `feat(T6): pilot non-interactive rollout — /requirements; tighten refusal grep + skip inlined block in awk`.
