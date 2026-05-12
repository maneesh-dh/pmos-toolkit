# Archived skills

These skills were retired in **pmos-toolkit 2.38.0**.

`/create-skill` and `/update-skills` are superseded by:

- `/feature-sdlc skill <description>` — author a **new** skill via the full SDLC pipeline (requirements → spec → plan → execute → skill-eval → verify), scoring it against a binary eval rubric before merge.
- `/feature-sdlc skill --from-feedback <text | path | --from-retro>` — apply feedback to **one or more existing** skills via the same pipeline.
- `/skill-sdlc <…>` — thin alias that forwards verbatim to `/feature-sdlc skill …`.

The pmos-toolkit plugin loader reads only `plugins/pmos-toolkit/skills/`, so these directories are no longer loadable — they are kept here for reference (history, prose that wasn't fully migrated). For the current behavior see:

- `plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md` — the orchestrator (the `skill` subcommand lives there).
- `plugins/pmos-toolkit/skills/feature-sdlc/reference/skill-patterns.md` — the SKILLS-standard authoring guide (frontmatter, description & triggering, structure & progressive disclosure, body & content, scripts & tooling).
- `plugins/pmos-toolkit/skills/feature-sdlc/reference/skill-eval.md` — the binary eval rubric (mirrors `skill-patterns.md` 1:1).

## Old phase → where it lives now

| Retired skill | Old behavior | Now |
|---|---|---|
| `/create-skill` | Author a new skill from a description | `/feature-sdlc skill <description>` (`pipeline_mode: skill-new`) |
| `/create-skill` | Spec-template authoring | folded into `/feature-sdlc`'s spec stage; `spec-template.md` archived here under `create-skill/reference/` |
| `/update-skills` | Apply retro/feedback to an existing skill | `/feature-sdlc skill --from-feedback <…>` (`pipeline_mode: skill-feedback`); Phase 0c `/feedback-triage` does the triage step |
| `/update-skills` | `retro-parser.md` / `triage-doc-template.md` / `seed-requirements-template.md` | moved to `plugins/pmos-toolkit/skills/feature-sdlc/reference/` |
