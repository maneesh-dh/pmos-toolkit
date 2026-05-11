---
task_number: 2
task_name: "Write the static-check test script + skill-local test fixtures"
plan_path: "docs/pmos/features/2026-05-11_survey-design-skill/03_plan.html"
branch: "feat/survey-design-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-survey-design-skill"
status: done
started_at: 2026-05-11
completed_at: 2026-05-11
files_touched:
  - tests/scripts/assert_survey_design_skill.sh
  - plugins/pmos-toolkit/skills/survey-design/tests/fixtures/sample-brief.txt
  - plugins/pmos-toolkit/skills/survey-design/tests/expected.yaml
---

## T2 — static-check script + fixtures (the "red" check)

Wrote `tests/scripts/assert_survey_design_skill.sh` (skill-shell sections, >=5 trigger phrases, 3 reference files non-trivial, A1-E6 catalog coverage, >=33 'detection heuristic' lines, platform coverage incl. QSF + downgrade docs, survey-preview.js: no http(s)/no ESM/ASCII-only/`node --check`/12 type names/`#survey-data`/`skip_logic`, manifest version sync at 2.36.0, README + CHANGELOG greps). Added `tests/fixtures/sample-brief.txt` (hybrid-mode brief: trial-churn study, 30-day non-upgraders, ~5 min, Google Forms target) and `tests/expected.yaml` (property-based, mirrors polish/diagram layout).

TDD: this IS the test artifact (D-P3). Ran `bash tests/scripts/assert_survey_design_skill.sh` -> exit 1 (FAIL) as expected: placeholders only, no manifest bump, no survey-preview.js, no README/CHANGELOG. Confirms the check actually checks. Will go green at TN once T3-T9 land.
