---
task_number: 8
task_name: "Write SKILL.md — part 2 (Phases 4-9 + Anti-Patterns + Release prereqs + Capture Learnings + edge cases)"
plan_path: "docs/pmos/features/2026-05-11_survey-design-skill/03_plan.html"
branch: "feat/survey-design-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-survey-design-skill"
status: done
started_at: 2026-05-11
completed_at: 2026-05-11
files_touched:
  - plugins/pmos-toolkit/skills/survey-design/SKILL.md
---

## T8 — SKILL.md part 2

Appended the second half (replaced the `<!-- continued ... -->` marker): Phase 4 (one reviewer subagent; prompt carries the context object + survey.json + the two reference files + `[mode: …]`; the return contract specified IN the prompt — `question-eval.md` = one `## <question-id>` per question with the `Severity|Defect|Message|Proposed fix` table and the structured-finding shape, `survey-eval.md` = the seven survey-level sections; parent writes both, validates `count(## <id>) == count(questions)` with one re-dispatch + surface-and-proceed, handles subagent failure with retry-or-proceed); Phase 5 (apply via batched AskUserQuestion `Fix as proposed (Recommended) / Modify / Skip / Defer`, mutate survey.json, re-render, append `## Dispositions`, commit "survey-design: apply review for <slug>"); Phase 6 (simulated-respondent once per persona, default 1; return `{persona, estimated_minutes, per_question[], dropoff_risk_points[], overall_notes}`; parent writes simulation.md, derives a fix list, compares to budget with concrete cut proposals, batched AskUserQuestion `Apply (Recommended) / Modify / Skip / Defer`, commit "survey-design: apply simulation fixes for <slug>", states the heuristic-stand-in disclaimer); Phase 7 (cp serve.js etc., regenerate index.html, tell the view command); Phase 8 (skip on `--skip-export`; else AskUserQuestion multiSelect Typeform/SurveyMonkey/Google Forms (Recommended)/Skip-export (+Qualtrics only if shipped); per-platform transform recipes citing reference/platform-export.md, map-down unsupported types + document downgrades, write export/README.md with import steps+auth+caveats, commit "survey-design: add <platforms> export for <slug>"; unsupported-platform handling); Phase 9 (summary + drop-off/overage flag + _open_questions.md path; then Capture Learnings); `## Anti-Patterns (DO NOT)`; `## Release prerequisites`; `## Capture Learnings`; `## Edge cases` table E1-E14.

Self-checks: all §13.1 grep targets present (`Platform Adaptation`, `Release prerequisites`, `Anti-Patterns`, `Capture Learnings`, `non-interactive-block:start`, `reviewer`, `simulated-respondent`, `FormApp`, `typeform.json`); no `reference/*` content inlined (no literal "detection heuristic"); NI block still byte-identical to canonical. Reworded three prose/table mentions that contained the literal `AskUserQuestion` (an anti-pattern bullet + two edge-table rows) so they aren't mis-detected as checkpoints. `bash plugins/pmos-toolkit/tools/audit-recommended.sh -- .../survey-design/SKILL.md` → PASS (8 calls, 7 Recommended, 1 defer-only, 0 unmarked). 374 lines total. TDD: no — SKILL.md prose (FR-105).
