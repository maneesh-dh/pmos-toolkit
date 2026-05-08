---
task_number: 12
task_name: "role-style-consistency rubric add-item + code check"
status: done
started_at: 2026-05-06T13:46:30Z
completed_at: 2026-05-06T13:50:00Z
files_touched:
  - plugins/pmos-toolkit/skills/diagram/tests/run.py
  - plugins/pmos-toolkit/skills/diagram/tests/test_role_consistency.py
---

## Outcome
- `check_role_style_consistency()` enforces same-(tag,stroke,dasharray) per role.
- Wired into `evaluate()` only when active theme has `mixingPermitted: true` (technical theme is unaffected).
- 5/5 role-consistency tests pass; 30/30 total.
- Editorial theme.yaml already declares the rubric add-item (T10).

## Decisions
- The check uses the SIDECAR's `_svgId` as ground truth, not stroke clustering. D6: deterministic, no heuristics.
- Missing sidecar → pass (the check is conditional on having sidecar role tags). The rubric reviewer still gets the `role-style-consistency` add-item visible in the prompt; this is a code-side belt-and-suspenders.
- 5 tests instead of plan's 2 — added "no role tagged", "missing sidecar", "missing svgId" coverage; cheap and prevents silent passes when the sidecar is malformed.
