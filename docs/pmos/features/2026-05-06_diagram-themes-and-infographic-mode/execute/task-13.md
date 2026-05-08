---
task_number: 13
task_name: "Editorial goldens + defects; corpus iterates by theme"
status: done
started_at: 2026-05-06T13:50:00Z
completed_at: 2026-05-06T14:02:00Z
files_touched:
  - plugins/pmos-toolkit/skills/diagram/tests/run.py
  - plugins/pmos-toolkit/skills/diagram/tests/golden/editorial/editorial-flow-fanin.svg
  - plugins/pmos-toolkit/skills/diagram/tests/golden/editorial/editorial-flow-fanin.diagram.json
  - plugins/pmos-toolkit/skills/diagram/tests/golden/editorial/editorial-flow-fanin.expected.json
  - plugins/pmos-toolkit/skills/diagram/tests/golden/editorial/editorial-radial-mindmap.svg
  - plugins/pmos-toolkit/skills/diagram/tests/golden/editorial/editorial-radial-mindmap.diagram.json
  - plugins/pmos-toolkit/skills/diagram/tests/golden/editorial/editorial-radial-mindmap.expected.json
  - plugins/pmos-toolkit/skills/diagram/tests/defects/editorial/cream-but-mixed-connectors-within-one-role.svg
  - plugins/pmos-toolkit/skills/diagram/tests/defects/editorial/cream-but-mixed-connectors-within-one-role.diagram.json
  - plugins/pmos-toolkit/skills/diagram/tests/defects/editorial/eyebrow-not-uppercase.svg
---

## DEVIATIONS
**Plan called for editorial-infographic-full as a 3rd golden (Phase 1's "Done when" line listed it).** Skipped here — that golden requires the Phase 6.6 infographic wrapper which doesn't exist yet (Phase 3 work, T19+). Will be added when Phase 3 ships.

**`is_chrome_class` added to run.py.** The editorial dashed-container rect is a theme defining-move that fully encloses the diagram; without exclusion it triggers node-occlusion hard-fails for every inner node. Added a class-based opt-out (`bg|container|backdrop|chrome`) following the same pattern `has_legend_class` already uses. Documented the convention; both editorial fixtures use it.

## Outcome
- editorial-flow-fanin: code_score=1.0, no hard_fails. role-style-consistency exercised on 4 contribution edges.
- editorial-radial-mindmap: code_score=0.977, no hard_fails. Demonstrates theme ≠ layout.
- cream-but-mixed-connectors-within-one-role: hard_fail "role-style-consistency: role 'feedback' edge e1 uses ('path', '#1E3A8A', '6 4'), edge e2 uses ('path', '#1E3A8A', ''); expected one style per role".
- eyebrow-not-uppercase: vision-only skip (correct — code metrics can't see case).
- Full corpus 17 goldens+defects all classified correctly.
- Existing technical snapshots bit-identical to pre-T13 baseline.

## Notes
- Editorial fixtures use `class="bg"` and `class="container"` for the cream backdrop and dashed outer rect respectively.
- `_svgId` matches each `<line>`/`<path>` element's `id` attribute so role-style-consistency can look them up.
