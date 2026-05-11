---
task_number: 6
task_name: "Write assets/survey-preview.js"
plan_path: "docs/pmos/features/2026-05-11_survey-design-skill/03_plan.html"
branch: "feat/survey-design-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-survey-design-skill"
status: done
started_at: 2026-05-11
completed_at: 2026-05-11
files_touched:
  - plugins/pmos-toolkit/skills/survey-design/assets/survey-preview.js
  - tests/scripts/assert_survey_design_skill.sh
---

## T6 — assets/survey-preview.js

Implemented the standalone vanilla-JS preview engine per spec §10.2/§10.3: IIFE wired to DOMContentLoaded; parses `#survey-data` (renders a clear error if missing/invalid); IntroScreen with text + meta line + ConsentGate (Start disabled until "I agree" checked); one SectionView per survey section with progress text "Question X of Y" computed over the *active path* (recomputed when skip_logic changes the path), Back/Next, in-memory `answers` object (no browser storage); QuestionView dispatches on `question.type` for all 12 types -- single_select/dichotomous -> radios, multi_select -> checkboxes (+ "Other (please specify)" + opt_out_options after an `<hr>`), rating/nps -> scale buttons min..max with pole/mid labels, open_short -> text input, open_long -> textarea, ranking -> per-item `<select>` 1..N, matrix -> radio table (rows x scale columns), forced_choice_grid -> radio table (rows x Yes/No(/N/A)), constant_sum -> number inputs + running total vs `constant_sum_total`, statement -> display-only; help_text/reference_period rendered; required-gate validation blocks Next with an inline message; skip_logic `skip_to`/`end_survey` honoured on advance; Back walks a visited-screen stack; ThankYouScreen with the thank-you text + a "Show my answers (JSON)" toggle + Restart.

ASCII-only, no `http(s)://`, no ES module statements, no browser storage. Reworded two header comments so the static-check greps don't false-positive on "export" / "localStorage". `node --check` clean. Smoke-tested `init()` via a minimal DOM stub (Node) -- runs without throwing. ~600 lines. Full behavioural proof = the manual browser walk in TN. Also tightened the ESM regex in `assert_survey_design_skill.sh` to `^[[:space:]]*(import|export)[[:space:]]` (statement forms only). TDD: no -- browser-runtime JS with no harness (FR-105); verified by `node --check` + the TN browser walk.
