---
task_number: 22
task_name: "assert_heading_ids.sh"
task_goal_hash: t22-assert-heading-ids
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
status: done
started_at: 2026-05-10T02:16:00Z
completed_at: 2026-05-10T02:18:00Z
files_touched:
  - tests/scripts/assert_heading_ids.sh
---

## T22 — assert_heading_ids.sh

**Outcome:** done. PASS on T15 fixture (5 HTMLs scanned, 0 headings without id).
Negative test (synthetic `<h2>Goals</h2>` lacking id) FAILs at line 28 as
expected.

### Inline verification

```
$ bash tests/scripts/assert_heading_ids.sh
PASS: assert_heading_ids.sh   ✅

$ # negative
$ sed -i '' 's|<h2 id="goals">Goals</h2>|<h2>Goals</h2>|' fixture/01_requirements.html
$ bash tests/scripts/assert_heading_ids.sh
FAIL: ...01_requirements.html has 1 heading(s) without id:
28:       <h2>Goals</h2>
exit=1   ✅ (revert applied)
```

### Spec compliance

| FR | Requirement | Satisfied by |
|---|---|---|
| FR-03.1 | every h2/h3 carries a stable kebab-case id | awk + grep -v id= → 0 hits across fixture |
| FR-72 | /verify smoke hard-fails on missing id | exit 1 + per-line file:line:content report |

T22 complete.
