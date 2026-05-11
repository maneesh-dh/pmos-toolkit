---
task_number: 5
task_name: "Write reference/platform-export.md"
plan_path: "docs/pmos/features/2026-05-11_survey-design-skill/03_plan.html"
branch: "feat/survey-design-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-survey-design-skill"
status: done
started_at: 2026-05-11
completed_at: 2026-05-11
files_touched:
  - plugins/pmos-toolkit/skills/survey-design/reference/platform-export.md
---

## T5 — reference/platform-export.md

Authored from research-notes Stream 3: top note (Qualtrics = stretch, don't offer it in Phase 8 unless the QSF transformer ships; MS Forms not supported). One `##` section each for Typeform / SurveyMonkey / Google Forms / Qualtrics, each with: import mechanisms ranked best->worst, the exact artifact schema + a concrete minimal example, a full `survey.json`-type -> platform-type mapping table marking every downgrade (Typeform: constant_sum; SurveyMonkey: nps partial, constant_sum; Google Forms: nps->scale, ranking->grid, constant_sum->text items; Qualtrics: native), auth/plan limits + a README curl/instruction snippet, and the recommended emitted artifact. Plus a "Microsoft Forms — not supported" note and `## Sources` with Stream-3 citations. 252 lines. Greps for typeform/surveymonkey/google forms/qsf/downgrade/forms:write/FormApp//v3/surveys/nps/ranking/matrix all pass. TDD: n/a — markdown reference (FR-105).
