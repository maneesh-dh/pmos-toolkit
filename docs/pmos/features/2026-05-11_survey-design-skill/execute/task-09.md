---
task_number: 9
task_name: "Release wiring — manifests 2.36.0 + README row + CHANGELOG + learnings header"
plan_path: "docs/pmos/features/2026-05-11_survey-design-skill/03_plan.html"
branch: "feat/survey-design-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-survey-design-skill"
status: done
started_at: 2026-05-11
completed_at: 2026-05-11
files_touched:
  - plugins/pmos-toolkit/.claude-plugin/plugin.json
  - plugins/pmos-toolkit/.codex-plugin/plugin.json
  - README.md
  - CHANGELOG.md
---

## T9 — release wiring

Bumped `"version"` to `"2.36.0"` in both `plugins/pmos-toolkit/.claude-plugin/plugin.json` and `plugins/pmos-toolkit/.codex-plugin/plugin.json` (version lines now byte-identical — `diff` empty). Added a `/pmos-toolkit:survey-design` row under README's `### Utilities` table (after `/diagram`) and added `/survey-design` to the standalone-skills list. Prepended a `## pmos-toolkit 2.36.0 — 2026-05-11` section to `CHANGELOG.md` describing the new skill (the generate → reviewer-critique → simulated-respondent → export loop; canonical artifacts; the three platform export targets; the `reference/` material) + "Breaking changes — None" + "Migration — None". Appended a `## /survey-design` header to `~/.pmos/learnings.md` (outside the repo, not committed). TDD: no — config/docs edits (FR-105); verified by the §13.1 manifest-sync diff + README/CHANGELOG greps at TN.

DEVIATION: the CHANGELOG's most-recent existing entry is `2.26.0` (the running changelog narrative trails the release tags; `/complete-dev` regenerates it). T9 prepends the `2.36.0` section at the top in the existing style as planned; the version number itself is locked here.
