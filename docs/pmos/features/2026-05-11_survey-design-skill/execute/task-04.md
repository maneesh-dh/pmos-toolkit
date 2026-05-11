---
task_number: 4
task_name: "Write reference/question-antipatterns.md"
plan_path: "docs/pmos/features/2026-05-11_survey-design-skill/03_plan.html"
branch: "feat/survey-design-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-survey-design-skill"
status: done
started_at: 2026-05-11
completed_at: 2026-05-11
files_touched:
  - plugins/pmos-toolkit/skills/survey-design/reference/question-antipatterns.md
---

## T4 — reference/question-antipatterns.md

Authored from research-notes Stream 2: header explaining the two consumers (generator must produce none; reviewer walks each question against the detection heuristics), then the full catalog grouped A (stem framing) / B (respondent capability) / C (response options) / D (format & cognitive load) / E (structure, length & logic). Every id A1-A8/B1-B4/C1-C8/D1-D7/E1-E6 has a uniform block: category / harm / BAD / FIXED / detection heuristic. 35 "detection heuristic" lines (>=33). All catalog-id greps pass; `double-barreled`, `leading`, `unbalanced`, `select all`, `opt-out` all present. `## Sources` with Stream-2 citations. 278 lines. TDD: n/a — markdown catalog (FR-105), verified by the §13.1 id-coverage grep loop.
