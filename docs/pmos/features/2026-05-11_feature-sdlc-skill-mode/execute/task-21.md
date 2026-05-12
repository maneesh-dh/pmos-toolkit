---
task_number: 21
task_name: "Bump both plugin.json files (synced minor) 2.37.0 → 2.38.0"
status: done
started_at: 2026-05-12T00:00:00Z
completed_at: 2026-05-12T00:00:00Z
files_touched:
  - plugins/pmos-toolkit/.claude-plugin/plugin.json
  - plugins/pmos-toolkit/.codex-plugin/plugin.json
tdd: "no — config edit (FR-105 carve-out); verification is jq + the pre-push sync hook"
---

## What changed

- `plugins/pmos-toolkit/.claude-plugin/plugin.json`: `"version": "2.37.0"` → `"version": "2.38.0"`.
- `plugins/pmos-toolkit/.codex-plugin/plugin.json`: `"version": "2.37.0"` → `"version": "2.38.0"` — byte-identical string.
- No per-command description fields exist in either manifest (`jq keys` shows only `author / description / homepage / keywords / license / name / repository / skills / version` for claude and `author / description / interface / name / skills / version` for codex; the plugin-level `description` is unchanged — the SKILL.md frontmatter is the per-command description source per Decision P5).
- `"skills": "./skills/"` is a directory pointer, not a hardcoded list — skills are auto-discovered, so archiving create-skill/update-skills and adding skill-sdlc needs no manifest array edit (FR-95).

## Verification

- `jq -r .version` on both → `2.38.0`. ✓
- `diff <(jq -r .version …claude…) <(jq -r .version …codex…)` → empty (synced — pre-push hook will pass). ✓
- `jq empty` on both → valid JSON. ✓
- `git diff --stat` → exactly 2 files, 1 line each. ✓
