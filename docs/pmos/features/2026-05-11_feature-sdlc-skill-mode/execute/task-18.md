---
task_number: 18
task_name: "Create archive/skills/README.md"
status: done
started_at: 2026-05-12T00:00:00Z
completed_at: 2026-05-12T00:00:00Z
files_touched:
  - archive/skills/README.md
tdd: "no — prose"
---

## What changed

Created `archive/skills/README.md` — explains the archive and redirects users of the two retired commands: states they were retired in pmos-toolkit 2.38.0; lists the three replacements (`/feature-sdlc skill <description>`, `/feature-sdlc skill --from-feedback <…>`, `/skill-sdlc <…>`); explains the loader-path reason (loader reads only `plugins/pmos-toolkit/skills/`); points at `feature-sdlc/SKILL.md`, `feature-sdlc/reference/skill-patterns.md`, `feature-sdlc/reference/skill-eval.md`; includes an "Old phase → where it lives now" mapping table (covering `/create-skill` → `skill-new`, `spec-template.md` archived location, `/update-skills` → `skill-feedback` + Phase 0c `/feedback-triage`, and the three relocated reference files).

## Verification

- `test -f archive/skills/README.md` → exists. ✓
- `grep -F '/feature-sdlc skill' archive/skills/README.md` → hits. ✓
- `grep -F '/skill-sdlc' archive/skills/README.md` → hits. ✓
