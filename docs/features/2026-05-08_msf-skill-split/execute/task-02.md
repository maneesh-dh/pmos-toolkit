---
task_number: 2
task_name: "Create /msf-req/SKILL.md"
task_goal_hash: T2-create-msf-req-skill
plan_path: "docs/features/2026-05-08_msf-skill-split/03_plan.md"
branch: "feature/msf-skill-split"
worktree_path: ".worktrees/msf-skill-split"
status: done
started_at: 2026-05-08T00:05:00Z
completed_at: 2026-05-08T00:10:00Z
files_touched:
  - plugins/pmos-toolkit/skills/msf-req/SKILL.md
---

# T2: Create `/msf-req/SKILL.md` — done

## Outcome

Created `plugins/pmos-toolkit/skills/msf-req/SKILL.md` with frontmatter, all 9 phases (Phase 0 Pipeline Setup through Phase 8 Capture Learnings), 4 disjoint trigger phrases (FR-04), and recommendations-only contract.

## Verification

- Frontmatter: `name: msf-req`, `argument-hint: "<path-to-requirements-doc>"` ✓
- All 4 FR-04 trigger phrases present ✓
- Zero FR-05 (/msf-wf) trigger phrases ✓
- Phase 0 Pipeline Setup block present (FR-38) ✓
- All 9 phases (Phase 0..8) present ✓
- Anti-patterns forbid `--apply-edits`, `--wireframes`, `--skip-psych`, `--default-scope` (FR-34) ✓

## Deviations

Plan's verification used `grep -c` to count trigger phrases, expecting ≥4. All 4 phrases live on the same `description:` line (one frontmatter line), so `grep -c` returned 1. Switched to per-phrase `grep -q` loop — confirmed all 4 are present. Plan T2.5 verification command would benefit from this fix in future runs.
