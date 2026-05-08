---
task_number: 8
task_name: "Add role to relationship schema; record in sidecar"
status: done
started_at: 2026-05-06T13:30:00Z
completed_at: 2026-05-06T13:31:00Z
files_touched:
  - plugins/pmos-toolkit/skills/diagram/SKILL.md
---

## Outcome
SKILL.md Phase 1 entity model now declares the `role?` enum and the mixingPermitted contract. Sidecar passthrough + test coverage already shipped in T6 (`test_v2_sidecar_relationships_carry_role`). 6/6 sidecar tests pass.
