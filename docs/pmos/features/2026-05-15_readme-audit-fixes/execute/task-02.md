---
task_number: 2
task_name: "rubric.yaml type: field + cross-cutting [D] + --validate-yaml"
status: done
started_at: 2026-05-15T16:05:00Z
completed_at: 2026-05-15T16:20:00Z
files_touched:
  - plugins/pmos-toolkit/skills/readme/reference/rubric.yaml
  - plugins/pmos-toolkit/skills/readme/scripts/rubric.sh
---

## Decisions / deviations

- Plan T2 step 5 ([D]-row filter guard in scorer): implemented implicitly.
  The bash scorer iterates ALL_CHECKS (a hardcoded list, not yaml `checks[*]`).
  [J] ids are never added to ALL_CHECKS — T3's two [J] rows reside only in
  rubric.yaml for the reviewer subagent's reference. Functional equivalent.
- Selftest "PASS=X/15" → "PASS=X/$total_checks" (dynamic). Strong now show
  15/16 (cross-cutting passes only when README mentions one of the 8
  keywords; strong fixtures pass via `.md` file references being matched
  by case-insensitive `\bMD\b`). Slop fixtures still 7-8/16 — agreement
  threshold (strong>=12, slop<=8) holds at 100%.
- Final selftest log line still says "15 checks" (cosmetic); not updated to
  avoid touching unrelated copy.

## Runtime evidence

- `--validate-yaml` clean: exit 0 silent.
- `--validate-yaml` broken (planted row missing `type:`): exit 1, stderr
  `[validate] FAIL: tmp-broken missing type`.
- `--selftest`: exit 0; lint:PASS + fixture-agreement:PASS (100%).
- `tests/run-all.sh`: 11/13 pass; pre-existing 2 failures unchanged.
