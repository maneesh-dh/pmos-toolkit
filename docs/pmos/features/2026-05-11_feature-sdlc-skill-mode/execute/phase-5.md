---
phase: 5
phase_name: "/skill-sdlc alias + archival + repo edits"
status: done
tasks: [T16, T17, T18, T19, T20, T21, T22]
completed_at: 2026-05-12T00:00:00Z
---

# Phase 5 — `/skill-sdlc` alias + archival + repo edits — sealed

All seven tasks done and committed:

- **T16** — created `plugins/pmos-toolkit/skills/skill-sdlc/SKILL.md` (12-line thin alias: `name: skill-sdlc`, 6-trigger description, full `argument-hint`, body instructing immediate verbatim forwarding to `/pmos-toolkit:feature-sdlc skill <args>` with two worked examples; no learnings-load line, no numbered phases). `audit-recommended.sh` → exit 0 (vacuous). See task-16.md.
- **T17** — `git mv plugins/pmos-toolkit/skills/{create-skill,update-skills} → archive/skills/` (`spec-template.md` rode along under `create-skill/reference/`; `update-skills/reference/` was already empty post-T8). No live skill/README/CLAUDE.md references the old paths. See task-17.md.
- **T18** — created `archive/skills/README.md` (retired-in-2.38.0 notice, the three replacements, the loader-path reason, pointers to `feature-sdlc/SKILL.md` + `skill-patterns.md` + `skill-eval.md`, an "old phase → now" mapping table). See task-18.md.
- **T19** — `README.md`: `/feature-sdlc` row extended to mention the `skill` subcommand; new `/skill-sdlc` row; `/update-skills` + `/create-skill` rows replaced with `_Archived in 2.38.0…_` notes; standalone line updated (− `/create-skill` − `/update-skills` + `/skill-sdlc`); "Adding New Skills" line re-pointed to `/feature-sdlc skill`. See task-19.md.
- **T20** — `CLAUDE.md`: new `## Skill-authoring conventions` section (items a–e: canonical path, post-move `ls` check, the skill SDLC via `/feature-sdlc skill`, the `skill-patterns.md` single-source pointer mirrored 1:1 by `skill-eval.md`, see-also cross-links); the stale "`/create-skill` Phase 7 enforces this" line re-pointed to `/feature-sdlc skill` + the `a-name-matches-dir` eval check. Existing canonical-path / version-sync / release-entry sections intact. See task-20.md.
- **T21** — both `plugin.json` (`.claude-plugin` + `.codex-plugin`) bumped `2.37.0` → `2.38.0` in one commit, byte-identical (pre-push sync hook will pass); no per-command description fields exist (P5); `"skills": "./skills/"` is a dir pointer, no array edit needed. See task-21.md.
- **T22** — `~/.pmos/learnings.md` already had `## /feature-sdlc` (line 201) → idempotent no-op; no `## /skill-sdlc` header added (D19). Not committed (outside the repo). See task-22.md.

## Deployable slice

`/skill-sdlc` works as a thin alias; `/create-skill` and `/update-skills` are gone from the loader (archived with a redirect README); the repo docs (README, CLAUDE.md) and manifests are consistent at 2.38.0.

## Next

Phase 6 / TN — final verification: `bash -n` the eval-check script, the FR-85 `^## Phase` sequence, `--selftest` exit-0 + the deliberately-mismatched exit-1, the clean/dirty/thin-alias fixture runs, manifest version sync, archival listings, no-dangling-refs grep, CLAUDE.md + README greps, the patterns↔eval bijection, the `/skill-sdlc` forwarding shape, `audit-recommended.sh` exit-0, the non-interactive-block byte-identity, remove `.plan.lock` + `*.tmp`, then `/pmos-toolkit:verify` on `02_spec.html`.
