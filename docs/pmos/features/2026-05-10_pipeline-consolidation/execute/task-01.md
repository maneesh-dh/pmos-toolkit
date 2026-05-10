---
task_number: 1
task_name: "Manifest argument-hint + description updates (no version bump)"
task_goal_hash: "n/a-structural"
plan_path: "docs/pmos/features/2026-05-10_pipeline-consolidation/03_plan.md"
branch: "feat/pipeline-consolidation"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-pipeline-consolidation"
status: done
started_at: 2026-05-10T05:05:00Z
completed_at: 2026-05-10T05:10:00Z
files_touched:
  - plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md
  - plugins/pmos-toolkit/skills/requirements/SKILL.md
  - plugins/pmos-toolkit/skills/wireframes/SKILL.md
  - plugins/pmos-toolkit/skills/spec/SKILL.md
  - plugins/pmos-toolkit/skills/retro/SKILL.md
---

## Outcome: PASS

DEVIATION (logged): plan T1 says edit `plugin.json` argument_hint fields. Actual layout: argument-hint lives in per-SKILL.md frontmatter; plugin.json holds version + plugin-level metadata only. Adapted T1 to edit SKILL.md frontmatters on the 5 affected skills (feature-sdlc, requirements, wireframes, spec, retro). complete-dev not edited (plan does not enumerate flags for it).

11 flags added across 5 SKILL.md frontmatters:
- feature-sdlc: +`--minimal`
- requirements: +`--skip-folded-msf`, `--msf-auto-apply-threshold N`
- wireframes: +`--skip-folded-msf-wf`, `--msf-auto-apply-threshold N`
- spec: +`--skip-folded-sim-spec`
- retro: +`--last N`, `--days N`, `--since YYYY-MM-DD`, `--project current|all`, `--skill <name>`, `--scan-all`, `--msf-auto-apply-threshold N`

## Verification
- `lint-non-interactive-inline.sh` → PASS (27/27)
- All 11 unique flags grep-visible across the 5 frontmatters
- Manifest version unchanged at 2.33.0 (T21 will bump)

## Baseline finding (DEVIATION, not regressed by T1)
`audit-recommended.sh` already fails on baseline with 13 unmarked AskUserQuestion calls (changelog 1, create-skill 2, execute 1, feature-sdlc 9). Pre-existing; T1 added zero unmarked calls.
