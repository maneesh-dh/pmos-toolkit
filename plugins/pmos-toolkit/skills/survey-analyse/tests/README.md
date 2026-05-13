# survey-analyse — tests

Run all helper-module self-tests:

```bash
bash plugins/pmos-toolkit/skills/survey-analyse/tests/selftest.sh
```

Each helper module under `scripts/helpers/` ships a `--selftest` CLI entry
point with known-answer fixtures. `selftest.sh` walks every module and
exits non-zero on any failure. CI runs this on every push.

## Fixtures

`fixtures/` carries small response files for manual / integration testing of
the full skill (the helper self-tests are inline, not file-driven):

- `tiny-mixed.csv` — 12-row CSV covering 1 single-select, 1 multi-select,
  1 Likert, 1 NPS, 1 open-text column. Use to exercise the skill end-to-end
  in a smoke run.
