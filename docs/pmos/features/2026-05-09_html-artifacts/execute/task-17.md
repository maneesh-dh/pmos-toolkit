---
task_number: 17
task_name: "assert_sections_contract.sh"
task_goal_hash: t17-assert-sections-contract
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
status: done
started_at: 2026-05-10T02:08:00Z
completed_at: 2026-05-10T02:10:00Z
files_touched:
  - tests/scripts/assert_sections_contract.sh
---

## T17 — assert_sections_contract.sh

**Outcome:** done. PASS on T15 fixture (5 sections.json files); FAIL on
synthetic duplicate-id state (negative test).

### Inline verification

```
$ bash tests/scripts/assert_sections_contract.sh
PASS: assert_sections_contract.sh   ✅

$ # negative: inject dup id
$ jq '.sections += [{"id":"goals",...}]' 01_requirements.sections.json > tmp; mv tmp 01_requirements.sections.json
$ bash tests/scripts/assert_sections_contract.sh
FAIL: ...has duplicate ids: goals
exit=1   ✅
```

### Spec compliance

| FR | Requirement | Satisfied by |
|---|---|---|
| FR-70 | Every HTML artifact has a sibling .sections.json | per-html test-f check |
| FR-71 | sections.json ids are unique and resolve to HTML id attrs | jq dup check + grep id= match |

T17 complete.
