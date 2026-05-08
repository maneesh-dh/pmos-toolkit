---
task_number: 4
task_name: "Refactor tests/run.py to be theme-aware"
status: done
started_at: 2026-05-06T13:01:30Z
completed_at: 2026-05-06T13:09:00Z
files_touched:
  - plugins/pmos-toolkit/skills/diagram/tests/run.py
  - plugins/pmos-toolkit/skills/diagram/tests/test_theme_loader.py
  - plugins/pmos-toolkit/skills/diagram/eval/code-metrics.md
---

## Outcome
- `load_theme(name)`, `build_palette_set(theme)` added.
- `evaluate(svg, theme='technical')` reads palette from theme.yaml at runtime.
- PyYAML + jsonschema imports gated at module load with install hints.
- Regression diff against `/tmp/diagram-baseline.txt`: **empty**.
- 5/5 new theme-loader tests pass; full test suite (10 tests) green.

## Decisions
- `_THEME_CACHE` module-level dict avoids re-reading + re-validating YAML on every `evaluate()` call. Tests patch `_THEME_CACHE` to `{}` when injecting alternate schemas.
- Schema malformed-theme test uses pytest's `tmp_path` + `monkeypatch` (avoids polluting the real themes dir).
- Did not yet split sidecar helpers into a separate module (T6 task). run.py is now ~700 lines; will reassess after T6.

## Verification
- Regression diff: empty.
- pytest: 10 passed in 0.06s.
- selftest exits 0 with all goldens + defect classifications unchanged.
