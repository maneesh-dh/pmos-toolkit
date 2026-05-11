---
task_number: 6
task_name: "Write the test fixtures (clean-skill + dirty-skill)"
plan_path: "docs/pmos/features/2026-05-11_feature-sdlc-skill-mode/03_plan.html"
branch: "feat/feature-sdlc-skill-mode"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-feature-sdlc-skill-mode"
status: done
started_at: 2026-05-11T19:30:00Z
completed_at: 2026-05-11T19:30:00Z
files_touched:
  - plugins/pmos-toolkit/skills/feature-sdlc/tests/fixtures/clean-skill/SKILL.md
  - plugins/pmos-toolkit/skills/feature-sdlc/tests/fixtures/dirty-skill/SKILL.md
  - plugins/pmos-toolkit/skills/feature-sdlc/tests/fixtures/dirty-skill/reference/big.md
  - plugins/pmos-toolkit/skills/feature-sdlc/tests/README.md
---
clean-skill: 71-line well-formed CSV→markdown skill, every applicable [D] check passes. dirty-skill: 1091-line body with planted defects — name Dirty_Skill (fails a-name-lowercase-hyphen + a-name-matches-dir), body >800 lines (c-body-size), no ## Platform Adaptation (d-platform-adaptation), no learnings-load line / no numbered Capture-Learnings phase (d-learnings-load-line, d-capture-learnings-phase), hard-coded /Users/.../script.sh (c-portable-paths), reference/big.md 168 lines no ToC + linked from body (c-reference-toc); no argument-hint while body parses --foo/--bar → also fails f-cc-user-invocable under --target claude-code. tests/README.md explains the setup.
