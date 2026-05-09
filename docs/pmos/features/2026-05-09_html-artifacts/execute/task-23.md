---
task_number: 23
task_name: "assert_cross_doc_anchors.sh"
task_goal_hash: t23-assert-cross-doc-anchors
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
status: done
started_at: 2026-05-10T02:18:00Z
completed_at: 2026-05-10T02:20:00Z
files_touched:
  - tests/scripts/assert_cross_doc_anchors.sh
---

## T23 — assert_cross_doc_anchors.sh

**Outcome:** done. PASS on T15 fixture (4 cross-doc anchors all resolve).
Negative test (mutated `02_spec.html#goals` → `#nonexistent`) FAILs as
expected.

### Inline verification

```
$ bash tests/scripts/assert_cross_doc_anchors.sh
PASS: assert_cross_doc_anchors.sh   ✅

$ # negative: mutate one anchor target
$ sed -i '' 's|02_spec.html#goals|02_spec.html#nonexistent|' fixture/01_requirements.html
$ bash tests/scripts/assert_cross_doc_anchors.sh
FAIL: ...01_requirements.html#nonexistent → 02_spec.sections.json has no matching id
exit=1   ✅ (revert applied)
```

### Coverage

4 cross-doc anchors resolved:
- `01_requirements.html#goals` → `02_spec.sections.json#goals` ✅
- `02_spec.html#overview` → `01_requirements.sections.json#goals` ✅ (reverse direction)
- `grills/2026-05-09_test.html` → `../01_requirements.sections.json#goals` ✅ (nested → root)
- `simulate-spec/2026-05-09-trace.html` → `../02_spec.sections.json#fr-table` ✅ (nested → root)

### Spec compliance

| FR | Requirement | Satisfied by |
|---|---|---|
| FR-92 | every cross-doc anchor resolves to a real section id in target | jq lookup against target .sections.json with relative-path normalization for ../ targets |

T23 complete.
