---
task_number: 3
task_name: "Create /msf-wf/SKILL.md with PSYCH"
task_goal_hash: T3-create-msf-wf-skill
plan_path: "docs/features/2026-05-08_msf-skill-split/03_plan.md"
branch: "feature/msf-skill-split"
worktree_path: ".worktrees/msf-skill-split"
status: done
started_at: 2026-05-08T00:10:00Z
completed_at: 2026-05-08T00:18:00Z
files_touched:
  - plugins/pmos-toolkit/skills/msf-wf/SKILL.md
---

# T3: Create `/msf-wf/SKILL.md` — done

## Outcome

Created `plugins/pmos-toolkit/skills/msf-wf/SKILL.md` with frontmatter, all 11 phases (Phase 0..10), 4 disjoint trigger phrases, --apply-edits gating, PSYCH rubric with directional language and Medium-40 default, and sequential-journey-walking discipline.

## Verification

- Frontmatter `name: msf-wf`, `argument-hint: "<path-to-wireframes-folder> [--apply-edits]"` ✓
- 4 FR-05 trigger phrases present; 0 FR-04 phrases (disjoint per FR-06) ✓
- Phase 0 Pipeline Setup block present (FR-38) ✓
- All 11 phases present ✓
- "Entry context: Medium (40, default)" header line specified (FR-36) ✓
- "directional indicator" / "directional danger" language present (softened thresholds per spec non-goal) ✓
- "MUST NOT call Edit or Write ... when --apply-edits is absent" — FR-12 contract present ✓
- Anti-patterns forbid `--default-scope`, `--wireframes`, `--skip-psych` (FR-34) ✓

## Deviations

None.
