---
task_number: 5
task_name: "SKILL.md Phase 0 theme load + Phase 3 theme tokens"
status: done
started_at: 2026-05-06T13:09:30Z
completed_at: 2026-05-06T13:13:00Z
files_touched:
  - plugins/pmos-toolkit/skills/diagram/SKILL.md
---

## Outcome
Phase 0 now resolves --theme, loads theme.yaml, validates against schema. Phase 3 cites theme tokens (palette/typography/stroke/radii from theme; connector dispatch via byRole when mixingPermitted; pinned-role accents). File map and anti-patterns updated.

## Notes
- Forward-references `mixingPermitted: true` and `byRole` dispatch which take effect in Phase 2 (T11). Documented now to keep Phase 0 + Phase 3 stable across both themes.
- Pinned-role anti-pattern uses editorial as illustrative example.
