---
task_number: 5
task_name: "4th persona + 5-Task dispatch"
status: done
started_at: 2026-05-15T16:48:00Z
completed_at: 2026-05-15T17:00:00Z
files_touched:
  - plugins/pmos-toolkit/skills/readme/reference/simulated-reader.md
  - plugins/pmos-toolkit/skills/readme/SKILL.md
---

## Decisions / deviations

- The 5-Task dispatch is documented as a single prose paragraph in
  SKILL.md §2 step 1 (with sub-bullets for persona vs reviewer vs stub
  escape) rather than a literal 5-call code snippet. The skill is a
  markdown spec; the runtime call shape is conveyed prescriptively.
- Stub escape mentions both env vars inline so the 5-call dispatch is
  fully self-documented at §2 step 1; the dedicated §3 paragraph for
  each env var remains as the long-form reference.

## Runtime evidence

- `grep -c "^### 1\." simulated-reader.md` → 4 (was 3).
- `grep "5 \`Task\` tool calls in ONE assistant response" SKILL.md` → 1 match.
- `wc -l SKILL.md` → 506 (delta from baseline 489 = +17; within FR-AC-C envelope).
- `tests/run-all.sh`: 12 passed; 2 pre-existing failures unchanged
  (existing simulated_reader_contract.sh still passes — its 3-persona
  assertion will be widened in T9).
