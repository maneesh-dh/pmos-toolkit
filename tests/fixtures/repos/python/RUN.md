# Manual Integration Run (T39 + T41 portion)

This sub-repo exercises /plan v2 against a Tier-1 bug-fix spec. Cannot be driven from inside the same Claude Code session that authored /plan v2.

## T39 — Tier 1 bug-fix

```bash
cd tests/fixtures/repos/python
# In a FRESH Claude Code session:
#   /pmos-toolkit:plan @docs/pmos/features/2026-05-09_fixture-bugfix/02_spec.md
# After /plan completes:
bash ../../../../tests/scripts/assert_t39.sh
```

Expected: `PASS`.
