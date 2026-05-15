---
task_number: 6
task_name: "SKILL.md mode-branch + close-out + Suggest:/polish"
status: done
started_at: 2026-05-15T17:00:00Z
completed_at: 2026-05-15T17:10:00Z
files_touched:
  - plugins/pmos-toolkit/skills/readme/SKILL.md
---

## Decisions / deviations

- Inlined the close-out column-shape spec at §1 step 4 (not a separate
  §1.7) to stay within the FR-AC-C +15-25 line envelope. Final delta
  from baseline 489 → 511 = +22 lines.
- Audit-mode "do NOT fire AskUserQuestion" stated as a hard contract,
  not a softer suggestion — T9 audit_clean.sh will hard-fail on its
  presence in audit-mode transcripts.

## Runtime evidence

- `wc -l SKILL.md` → 511 (+22 from 489 baseline; within envelope).
- `grep -c "Suggest: /polish" SKILL.md` → 3 (T9 tracer expects 1-3).
- `grep -n "Audit mode|Scaffold / update mode"` → 4 hits (2 per step).
- `tests/run-all.sh`: 12/14 passing; 2 pre-existing failures unchanged.
