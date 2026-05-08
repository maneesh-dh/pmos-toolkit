---
task_number: 1
task_name: "Extract _shared/msf-heuristics.md from current /msf/SKILL.md"
task_goal_hash: T1-extract-shared-msf-heuristics
plan_path: "docs/features/2026-05-08_msf-skill-split/03_plan.md"
branch: "feature/msf-skill-split"
worktree_path: ".worktrees/msf-skill-split"
status: done
started_at: 2026-05-08T00:00:00Z
completed_at: 2026-05-08T00:05:00Z
files_touched:
  - plugins/pmos-toolkit/skills/_shared/msf-heuristics.md
---

# T1: Extract `_shared/msf-heuristics.md` — done

## Outcome

Created `plugins/pmos-toolkit/skills/_shared/msf-heuristics.md` containing persona alignment, M/F/S 24-consideration list (verbatim from /msf SKILL.md), and executive-summary template with mode-overrides marker.

## Verification

- File exists: ✓
- Bullet count: 30 (≥24 required for the 24 considerations + persona format bullets)
- No PSYCH leak: ✓ (after rewording one meta-line that incidentally contained the substring "PSYCH")
- Verbatim diff: ✓ — only structural differences (heading levels `####` → `##` and `---` separators); all 24 question bullets match exactly

## Deviations

None. One micro-fix during verification: original draft prose said "MUST NOT contain PSYCH scoring rubric — PSYCH lives in /msf-wf only", which the FR-08-style grep flagged as a leak. Reworded to "Scope: motivation, friction, and satisfaction analysis only. Wireframe-specific scoring rubrics live in their owning skill, not here." — same intent, no trigger word.
