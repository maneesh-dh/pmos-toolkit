---
task_number: 4
task_name: "Parent-side validation + reviewer_subagent_contract.sh"
status: done
started_at: 2026-05-15T16:35:00Z
completed_at: 2026-05-15T16:48:00Z
files_touched:
  - plugins/pmos-toolkit/skills/readme/scripts/_reviewer_validate.sh
  - plugins/pmos-toolkit/skills/readme/SKILL.md
  - plugins/pmos-toolkit/skills/readme/tests/integration/reviewer_subagent_contract.sh
---

## Decisions / deviations

- Validation lib reads the declared [J] set live from rubric.yaml (rows
  where `type: "[J]"`), not from a hardcoded constant. This keeps the lib
  in sync with rubric.yaml automatically when new [J] checks are added.
- Test variants use `cat <<JSON ... JSON` heredocs with `"$HERO_QUOTE"`
  interpolation rather than the plan's `/tmp/t4-stubs/*.sh` files —
  cleaner, fewer file artifacts.
- SKILL.md §2 step 2 reframed from "Substring validation (FR-SR-3)" to
  "Substring validation (FR-SR-3 personas; FR-11/FR-12 reviewer)" to
  cover both substreams; persona-label list now includes
  `returning-user-navigator` (T5 will add it; line is forward-compatible).

## Runtime evidence

- Variant A (valid): readme::reviewer_validate exit 0.
- Variant B (sub-40 quote): exit 1, stderr matches
  `reviewer returned quote shorter than 40 chars`.
- Variant C (missing check_id): exit 1, stderr matches
  `reviewer returned check_ids that do not match rubric.yaml`.
- `tests/run-all.sh`: now 10 integration tests (was 9); 12 passed total;
  2 pre-existing failures unchanged.
