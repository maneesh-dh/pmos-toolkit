---
task_number: 7
task_name: "Write feature-sdlc/tools/skill-eval-check.sh (TDD — new feature)"
plan_path: "docs/pmos/features/2026-05-11_feature-sdlc-skill-mode/03_plan.html"
branch: "feat/feature-sdlc-skill-mode"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-feature-sdlc-skill-mode"
status: done
started_at: 2026-05-11T19:30:00Z
completed_at: 2026-05-11T19:30:00Z
files_touched:
  - plugins/pmos-toolkit/skills/feature-sdlc/tools/skill-eval-check.sh
---
Red→green: confirmed script absent (red), then implemented. Bash, set -euo pipefail, SCRIPT_DIR + SKILL_EVAL_MD=../reference/skill-eval.md. Header documents purpose/usage/exit codes (0 pass / 1 fail / 2 script error)/deps (bash 3.2 + coreutils, no Node/jq). Arg parsing: --target (default generic, validated), --selftest, --, positional skill_dir. --selftest: parses [D] table rows from skill-eval.md, asserts set == DET_CHECKS (20), asserts every check row names exactly one skill-patterns.md §-rule. Scoring mode: 20 [D] predicates with applies_when gates (group E skipped when no scripts; reference-only group-C N/A when no reference dir; group F skipped under --target generic); TSV check_id\tverdict\tevidence on stdout; FAILS counter → exit 0/1. Green: bash -n OK; --selftest on real feature-sdlc dir exit 0; clean fixture exit 0 all-pass; dirty fixture --target generic exit 1 with 8 planted [D] fails; --target claude-code exit 1 with 9 (adds f-cc-user-invocable); mismatched skill-eval.md copy → selftest exit 1; missing skill-eval.md / bad --target → exit 2. chmod +x.
