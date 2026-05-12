---
task_number: 20
task_name: "Add ## Skill-authoring conventions to CLAUDE.md"
status: done
started_at: 2026-05-12T00:00:00Z
completed_at: 2026-05-12T00:00:00Z
files_touched:
  - CLAUDE.md
tdd: "no — prose"
---

## What changed (`CLAUDE.md`)

- Added a `## Skill-authoring conventions` section (placed between "## Canonical skill path (pmos-toolkit)" and "## Plugin manifest version sync") with items (a)–(e): (a) canonical path + lowercase-hyphenated `<skill-name>`, cross-linking the existing "## Canonical skill path" section rather than duplicating it; (b) "after any move/copy/rename run `ls plugins/pmos-toolkit/skills/`"; (c) the SDLC for skills — `/feature-sdlc skill <description>` / `--from-feedback <…>` (or `/skill-sdlc`), running requirements → spec → plan → execute → skill-eval → verify with binary scoring before merge, noting `/create-skill` + `/update-skills` were retired in 2.38.0 (→ `archive/skills/README.md`); (d) the authoring guide pointer — `feature-sdlc/reference/skill-patterns.md` is the single source of truth (used by the requirements/spec/execute/verify stages) and is mirrored 1:1 by `feature-sdlc/reference/skill-eval.md`; (e) "see also" cross-link to the existing "## Plugin manifest version sync" and "## Release entry point" sections (left intact — they're the pmos-specific release rules referenced by FR-62).
- Updated the now-stale line in "## Canonical skill path": "`/create-skill` Phase 7 enforces this at write-time" → "`/feature-sdlc skill` enforces this — its skill-eval rubric's `a-name-matches-dir` check fails when the frontmatter `name` doesn't match the directory." (kept the "manual edits don't get that check — this rule is the backstop" sentence).

## Verification

- `grep -in 'skill-authoring conventions' CLAUDE.md` → hits (the new `##` heading). ✓
- `grep -F 'feature-sdlc/reference/skill-patterns.md' CLAUDE.md` → hits. ✓
- `grep -i 'lowercase-hyphenated' CLAUDE.md` → hits (both the existing canonical-path section and the new section). ✓
- `grep -F 'plugins/pmos-toolkit/skills/<skill-name>/SKILL.md' CLAUDE.md` → hits (the canonical path, in both sections). ✓
- Existing "## Canonical skill path", "## Plugin manifest version sync", "## Release entry point" sections intact (cross-linked, not duplicated). ✓
