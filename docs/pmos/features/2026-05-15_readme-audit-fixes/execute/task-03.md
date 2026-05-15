---
task_number: 3
task_name: "reference/reviewer.md + [J] rows + READMER_REVIEWER_STUB"
status: done
started_at: 2026-05-15T16:20:00Z
completed_at: 2026-05-15T16:35:00Z
files_touched:
  - plugins/pmos-toolkit/skills/readme/reference/rubric.yaml
  - plugins/pmos-toolkit/skills/readme/reference/reviewer.md
  - plugins/pmos-toolkit/skills/readme/SKILL.md
  - plugins/pmos-toolkit/skills/readme/tests/mocks/reviewer_stub.sh
---

## Decisions / deviations

- reviewer_stub.sh derives the ≥40-char quote from the README's longest
  ≥40-char line (verbatim substring), falling back to a repeated line-1
  string. Always grep-matches the README source.
- Stub escape inserted as a NEW paragraph under SKILL.md §3, immediately
  after the existing READMER_PERSONA_STUB clause (not literally L217-221
  as the plan suggested; the spec's line refs were approximate).
- The [J] rows are placed under a section comment in rubric.yaml; they
  do NOT appear in ALL_CHECKS (so bash scorer skips them, scored only by
  reviewer subagent per FR-04 implicit filter — see task-02 decisions).

## Runtime evidence

- `bash reviewer_stub.sh fixtures/.../01_hero-line.md` → JSON array with
  both [J] check_ids, both quotes ≥40 chars (verified via python json
  parser).
- `--validate-yaml`: exit 0 (the 2 new [J] rows have all required fields).
- `--selftest`: exit 0; lint:PASS + fixture-agreement:PASS (100%).
- `tests/run-all.sh`: 11/13 pass; 2 pre-existing failures unchanged.
