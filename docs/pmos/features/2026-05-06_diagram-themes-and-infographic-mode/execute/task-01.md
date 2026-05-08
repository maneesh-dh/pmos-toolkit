---
task_number: 1
task_name: "Write themes/_schema.json (strict positive-list JSON Schema)"
plan_path: "docs/superpowers/specs/2026-05-06-diagram-themes-and-infographic-mode-plan.md"
branch: "feature/diagram-themes-infographic"
worktree_path: "(fallback: branch only — sandbox blocked .worktrees creation)"
status: done
started_at: 2026-05-06T12:50:00Z
completed_at: 2026-05-06T12:54:44Z
files_touched:
  - plugins/pmos-toolkit/skills/diagram/themes/_schema.json
  - plugins/pmos-toolkit/skills/diagram/tests/test_theme_schema.py
---

## Outcome
4/4 schema tests pass. Schema enforces positive-list of top-level keys; layout keys (direction/canvas/nodePositions/readingOrder/placement/layout) and `extends` are rejected via `additionalProperties: false`.

## Decisions
- Added `chips` and `nodeChrome` as optional top-level objects (per spec §5 example shape) — schema marks them not-required.
- Pattern-validated all hex colors with `^#[0-9A-Fa-f]{6}$` (3-digit hex rejected — themes should use full 6-digit form).
- Constrained `connectors.byRole[*].shape` to `orthogonal|curve|straight` enum.
- `arrowheads.sizes.default` required by inner schema; additional named sizes allowed.
- Added `definitions.typeBlock` for reuse across body/display/mono/eyebrow.
- `palette.accents[].pinnedRole` enum matches the relationship-role enum from §4.

## Verification
```
$ python3 -c "import pytest, sys; sys.exit(pytest.main(['plugins/.../tests/test_theme_schema.py', '-v']))"
4 passed in 0.05s
```

## Notes
- Sandbox blocked git worktree directory creation despite git accepting metadata. Fell back to a regular feature branch — skill's documented fallback.
- `pytest` binary not on PATH; using `python3 -c "import pytest; pytest.main(...)"` invocation throughout.
