---
task_number: 19
task_name: "Update README.md"
status: done
started_at: 2026-05-12T00:00:00Z
completed_at: 2026-05-12T00:00:00Z
files_touched:
  - README.md
tdd: "no — prose"
---

## What changed (`README.md`)

- **### Pipeline orchestrators**: `/pmos-toolkit:feature-sdlc` row description extended to mention the `skill` subcommand (`/feature-sdlc skill <description>` / `skill --from-feedback <…>` drive the same pipeline to author/revise skills, scoring each against a binary eval rubric before merge). Added a new row `| /pmos-toolkit:skill-sdlc | Thin alias for /feature-sdlc skill … — create a new skill or apply retro/feedback to existing skill(s) via the full SDLC pipeline |`. Replaced the `/pmos-toolkit:update-skills` row with `_Archived in 2.38.0 — superseded by /feature-sdlc skill --from-feedback; see archive/skills/README.md_`.
- **### Utilities**: replaced the `/pmos-toolkit:create-skill` row with `_Archived in 2.38.0 — superseded by /feature-sdlc skill <description> (or the /skill-sdlc alias); see archive/skills/README.md_`.
- **Standalone line**: removed `/create-skill` and `/update-skills`; added `/skill-sdlc`; kept `/feature-sdlc`.
- **## Adding New Skills**: "Use `/pmos-toolkit:create-skill` inside a session" → "Use `/pmos-toolkit:feature-sdlc skill <description>` (or the `/skill-sdlc` alias) inside a session".
- **Pipeline-flow ASCII**: unchanged — it lists pipeline *stages*, not orchestrators; `/create-skill`/`/update-skills` never appeared in it.

## Verification

- `grep -c 'skill-sdlc' README.md` → ≥ 1 (the new row + the standalone line + the "Adding New Skills" line). ✓
- `grep 'feature-sdlc' README.md` → the orchestrator row now mentions the `skill` subcommand. ✓
- `grep -E 'pmos-toolkit:create-skill|pmos-toolkit:update-skills' README.md` → only inside `_Archived_` notes (no live "use this skill" framing). ✓
- The standalone line includes `/skill-sdlc` and not `/create-skill`/`/update-skills`. ✓
