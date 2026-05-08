# Manual Integration Run (T40 + T41)

This sub-repo exercises /plan v2 against a Tier-3 feature spec with wireframes. Cannot be driven from inside the same Claude Code session that authored /plan v2.

## T40 — Tier 3 feature

```bash
cd tests/fixtures/repos/node
# In a FRESH Claude Code session:
#   /pmos-toolkit:plan @docs/pmos/features/2026-05-09_fixture-feature/02_spec.md
# After /plan completes:
bash ../../../../tests/scripts/assert_t40.sh
```

Expected: `PASS`.

## T41 — Defect handoff round-trip

After T40 plan exists, simulate a T7 defect: edit one task's `**Files:**` to reference a nonexistent path, then in a FRESH Claude Code session:

```bash
cd tests/fixtures/repos/node
# /pmos-toolkit:execute @docs/pmos/features/2026-05-09_fixture-feature/03_plan.md
# /execute fails on T7, writes 03_plan_defect_T7.md
bash ../../../../tests/scripts/assert_t41.sh   # PASS — defect file present

# Then in another fresh session:
# /pmos-toolkit:plan --fix-from T7 @docs/pmos/features/2026-05-09_fixture-feature/02_spec.md
# Resume: /pmos-toolkit:execute --resume
# After T7 succeeds, defect file should be removed:
test ! -f docs/pmos/features/2026-05-09_fixture-feature/03_plan_defect_T7.md && echo PASS
```
