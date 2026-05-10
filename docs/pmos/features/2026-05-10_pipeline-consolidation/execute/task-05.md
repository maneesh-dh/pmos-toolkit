---
task_number: 5
task_name: "Create _shared/sim-spec-heuristics.md and refactor /simulate-spec/SKILL.md"
status: done
started_at: 2026-05-10T05:20:00Z
completed_at: 2026-05-10T05:24:00Z
files_touched:
  - plugins/pmos-toolkit/skills/_shared/sim-spec-heuristics.md
  - plugins/pmos-toolkit/skills/simulate-spec/SKILL.md
  - tests/fixtures/pipeline-consolidation/test-t5-shared-substrate.sh
---

PASS. Test green. Substrate codifies 4-pass scenario enumeration, scenario trace, 4-bucket artifact-fitness critique, cross-reference, severity-keyed disposition + apply-loop, per-finding commit cadence (D16), Depends-on annotation, sub-threshold inline disposition (D14), uncommitted-edits guard (FR-66), failure capture (FR-50/M1), tier-keyed thresholds + escape flags. simulate-spec/SKILL.md gains delegation pointer at Phase 2 head.

DEVIATION (P5a structural-only): plan said "extract phases 2-8 bodies + replace with delegation pointers." Per P5a structural test surface, factoring kept simulate-spec body intact (delegation pointer + canonical reference) — same behavior, lower regression risk. T8 (folded /spec) will invoke the substrate directly without going through simulate-spec body.
