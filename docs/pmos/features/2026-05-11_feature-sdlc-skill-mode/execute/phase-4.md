---
phase: 4
phase_name: "state-schema.md → schema v4"
status: done
tasks: [T15]
completed_at: 2026-05-12T00:00:00Z
---

# Phase 4 — `state-schema.md` → schema v4 — sealed

Single task, done and committed: **T15** — `feature-sdlc/reference/state-schema.md` bumped to schema v4 (`pipeline_mode` top-level field, mode-conditional `phases[]` membership, the three new phase ids/hardness — `feedback-triage` hard / `skill-tier-resolve` infra / `skill-eval` hard — the `skill_eval` substructure, the v3→v4 auto-migration block, and a skill-feedback worked example alongside the updated feature-mode one). See task-15.md.

The `phases[]` membership sets and the new phase ids/hardness in the schema doc match the SKILL.md phase prose written in Phase 3 (T12) — checked by reading both.

## Next

Phase 5 (T16–T22) — `/skill-sdlc` thin alias + archive `create-skill`/`update-skills` + README/CLAUDE.md/plugin.json edits + learnings bootstrap. Then Phase 6 / TN — final verification + `/verify`.
