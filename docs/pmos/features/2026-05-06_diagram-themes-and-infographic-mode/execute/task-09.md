---
task_number: 9
task_name: "Stable rubric IDs; theme-aware waive/add loader"
status: done
started_at: 2026-05-06T13:32:00Z
completed_at: 2026-05-06T13:36:00Z
files_touched:
  - plugins/pmos-toolkit/skills/diagram/eval/rubric.md
  - plugins/pmos-toolkit/skills/diagram/tests/run.py
  - plugins/pmos-toolkit/skills/diagram/tests/test_rubric_loader.py
  - plugins/pmos-toolkit/skills/diagram/SKILL.md
---

## Outcome
- 7 stable kebab-case IDs replace numeric keys throughout (rubric, sidecar, SKILL.md reviewer JSON shape).
- `build_rubric_prompt(theme)` in run.py materializes the prompt; honors waive/add.
- 3/3 rubric_loader tests pass; 19/19 total; selftest green.
- Mapping note added to rubric.md.

## Decisions
- Kept RUBRIC_CORE_ITEMS as a Python list-of-dicts in run.py rather than a separate file. Simpler; the IDs are part of the sidecar contract so they belong with the code that reads/writes that contract.
- Reserved `role-style-consistency` and `eyebrow-mono-uppercase-applied` as candidate add-items in rubric.md so editorial (T12) and editorial defect tests (T13) have stable references.
