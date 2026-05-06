---
task_number: 6
task_name: "Sidecar v2 with theme/mode; drop v1 read"
status: done
started_at: 2026-05-06T13:13:30Z
completed_at: 2026-05-06T13:18:00Z
files_touched:
  - plugins/pmos-toolkit/skills/diagram/tests/run.py
  - plugins/pmos-toolkit/skills/diagram/tests/test_sidecar.py
  - plugins/pmos-toolkit/skills/diagram/reference/sidecar-schema.md
  - plugins/pmos-toolkit/skills/diagram/SKILL.md
---

## Outcome
- `read_sidecar(path)` returns `dict|None`; v1 → None (per D5), missing → None, >v2 → ValueError.
- `write_sidecar(path, payload)` stamps schemaVersion=2 if absent.
- 6/6 sidecar tests pass; full suite 16/16; regression diff empty.
- sidecar-schema.md fully rewritten for v2; documents `_svgId` binding-field convention.

## Decisions
- Did NOT extract sidecar helpers to a separate module (plan T6 step 3 made that conditional on run.py exceeding ~700 lines). Current size is ~770; split deferred to a future task — adding ~30 lines of helpers is not a strong enough trigger.

## Verification
- pytest: 16 passed in 0.09s
- selftest regression diff vs baseline: empty
