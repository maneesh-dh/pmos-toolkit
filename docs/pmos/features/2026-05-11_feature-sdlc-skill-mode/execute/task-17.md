---
task_number: 17
task_name: "Archive create-skill/ and update-skills/"
status: done
started_at: 2026-05-12T00:00:00Z
files_touched:
  - archive/skills/create-skill/SKILL.md
  - archive/skills/create-skill/reference/spec-template.md
  - archive/skills/update-skills/SKILL.md
tdd: "no — file moves; verification is ls + grep for dangling refs"
---

## What changed

- `mkdir -p archive/skills`
- `git mv plugins/pmos-toolkit/skills/create-skill archive/skills/create-skill` — `SKILL.md` + `reference/spec-template.md` rode along (history preserved per P7). "Dropped" per FR-92 = no live skill references it, not deleted.
- `git mv plugins/pmos-toolkit/skills/update-skills archive/skills/update-skills` — only `SKILL.md` remained (its three reference files were `git mv`'d to `feature-sdlc/reference/` in T8; the now-empty `reference/` dir was removed by the parent move).

## Verification

- `ls archive/skills/` → `create-skill  update-skills`. ✓
- `ls plugins/pmos-toolkit/skills/ | grep -E 'create-skill|update-skills'` → empty. ✓
- `test -f archive/skills/create-skill/reference/spec-template.md` → exists (rode along; lives only under `archive/` now). ✓
- `git status --porcelain | grep '^R'` → 3 rename entries (the two SKILL.md + spec-template.md). ✓
- `grep -rn 'skills/create-skill/\|skills/update-skills/\|spec-template.md' plugins/pmos-toolkit/skills/ README.md CLAUDE.md` → one hit: `feature-sdlc/SKILL.md:721` referencing the **new** `archive/skills/create-skill/` path in the "Release prerequisites" prose (written by T14). Not a dangling ref to the old path — expected and correct.
