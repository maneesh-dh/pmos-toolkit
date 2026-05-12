---
task_number: 10
task_name: "Update feature-sdlc/SKILL.md frontmatter"
plan_path: "docs/pmos/features/2026-05-11_feature-sdlc-skill-mode/03_plan.html"
branch: "feat/feature-sdlc-skill-mode"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-feature-sdlc-skill-mode"
status: done
started_at: 2026-05-12T00:10:00Z
completed_at: 2026-05-12T00:15:00Z
files_touched:
  - plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md
---
Rewrote the description (1022 chars ≤ 1024): now covers `/feature-sdlc skill <description>` / `/feature-sdlc skill --from-feedback <text|path|--from-retro>` + the Phase-6a binary skill-eval gate + `/feature-sdlc list`; carries 12 user-spoken trigger phrases (6 feature-mode kept verbatim + 6 skill-authoring: "create a skill", "author a new skill", "build me a slash command", "turn this workflow into a skill", "apply this retro feedback to the skill", "process this skill feedback end-to-end"). argument-hint → "[skill [--from-feedback]] <description|idea> [--from-retro] [--tier 1|2|3] [--resume] [--no-worktree] [--format html|md|both] [--non-interactive | --interactive] [--backlog <id>] [--minimal] | list" (FR-06 — every parsed token/flag). H1 sub-line + "Announce at start" mention the skill modes and point at reference/skill-patterns.md + reference/skill-eval.md. Headings NOT touched (the FR-85 renumber is T12). Committed in 47ffcf2.
