---
task_number: 16
task_name: "assert_resolve_input.sh"
task_goal_hash: t16-assert-resolve-input
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
status: done
started_at: 2026-05-10T02:05:00Z
completed_at: 2026-05-10T02:08:00Z
files_touched:
  - tests/scripts/assert_resolve_input.sh
  - tests/scripts/_resolve_input_harness.sh
  - tests/fixtures/resolve-input/only-md/01_requirements.md
  - tests/fixtures/resolve-input/only-html/01_requirements.html
  - tests/fixtures/resolve-input/both/01_requirements.html
  - tests/fixtures/resolve-input/both/01_requirements.md
  - tests/fixtures/resolve-input/neither/.gitkeep
---

## T16 — assert_resolve_input.sh

**Outcome:** done. 4 sub-fixtures + harness + assert script. PASS on all 4
cases (only-md → md; only-html → html; both → html preferred; neither → ERROR).

### Inline verification

```
$ bash tests/scripts/assert_resolve_input.sh
OK:   case=only-md → 01_requirements.md
OK:   case=only-html → 01_requirements.html
OK:   case=both → 01_requirements.html
OK:   case=neither → ERROR
PASS: assert_resolve_input.sh (4 cases)
exit: 0   ✅
```

### Spec compliance

| FR | Requirement | Satisfied by |
|---|---|---|
| FR-30 | Resolver prefers .html over .md when both present | "both" case → 01_requirements.html |
| FR-31 | Resolver falls back to .md when only .md present | "only-md" case → 01_requirements.md |
| FR-33 | Resolver returns explicit error when neither present | "neither" case → ERROR (exit-friendly token) |

T16 complete.
