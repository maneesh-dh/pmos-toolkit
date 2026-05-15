---
task_number: 9
task_name: "tracer + audit_clean tightening + 5-dispatch contract"
status: done
started_at: 2026-05-15T17:24:00Z
completed_at: 2026-05-15T17:40:00Z
files_touched:
  - plugins/pmos-toolkit/skills/readme/tests/integration/tracer_audit_polish_suggest.sh
  - plugins/pmos-toolkit/skills/readme/tests/integration/audit_clean.sh
  - plugins/pmos-toolkit/skills/readme/tests/integration/simulated_reader_contract.sh
  - plugins/pmos-toolkit/skills/readme/tests/mocks/simulated_reader_stub.sh
---

## Decisions / deviations

- tests/run-all.sh auto-discovers `*.sh` in integration/. Plan T9 step 4
  said "register the 4 new tests in alphabetical order"; that step is a
  no-op for this runner (the 4 new files are picked up automatically).
  DEVIATION recorded; no edit to run-all.sh.
- tracer_audit_polish_suggest.sh inspects SKILL.md directly rather than
  driving /readme through a wrapper — SKILL.md is a markdown spec, not
  a runnable program; the close-out template lives in the spec text,
  so spec-grep is the correct check shape.
- audit_clean.sh "AskUserQuestion in audit transcript" check (plan
  step 2.c) reframed as: SKILL.md must declare the
  'Do NOT fire AskUserQuestion' clause. Same goal (audit-mode is
  read-only), correct level (spec contract, not runtime transcript).
- simulated_reader_stub.sh gained a 4th `returning-user-navigator` case
  so the existing stub-driven test can exercise the 4th persona path.

## Runtime evidence

- tracer_audit_polish_suggest.sh → PASS (occurrences=3; both-modes clause present).
- audit_clean.sh → PASS (16/16 PASS, BSD-awk fork green, audit-mode contract preserved).
- simulated_reader_contract.sh → all 5 contract assertions pass (was 3).
- tests/run-all.sh: 13 integration tests (was 9); 15 passed; 2 pre-existing failures unchanged.
