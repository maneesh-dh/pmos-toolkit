---
task_number: 7
task_name: "Write SKILL.md — part 1 (shell + Phases 0-3 + survey.json schema + rendering)"
plan_path: "docs/pmos/features/2026-05-11_survey-design-skill/03_plan.html"
branch: "feat/survey-design-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-survey-design-skill"
status: done
started_at: 2026-05-11
completed_at: 2026-05-11
files_touched:
  - plugins/pmos-toolkit/skills/survey-design/SKILL.md
---

## T7 — SKILL.md part 1

Authored the first half of SKILL.md: frontmatter (`name: survey-design`, `description:` with 7 quoted trigger phrases, `user-invocable: true`, `argument-hint`); title + announce line + 2-sentence what; `## Platform Adaptation` (AskUserQuestion -> numbered prompts, subagents -> sequential inline, browser none, TaskCreate optional; states this is a standalone utility that does NOT run pipeline first-run setup); a `## Reference files (loaded on demand)` note (progressive disclosure of the 3 reference/*); `## Phase 0 — Setup` (read settings/docs_path with the default-to-docs/pmos/ + one-warning behaviour, parse flags, output_format note, run-folder resolution with dedupe + never-overwrite, phase tracking, learnings); the canonical non-interactive block inlined **byte-identical** to `_shared/non-interactive.md` between the markers (verified by `diff`); `## Phase 1 — Intake` (nothing -> AskUserQuestion purpose+audience with the audience one `<!-- defer-only: free-form -->`; path -> best-effort parse; free text); `## Phase 2 — Variable interpretation` (infer {audience, time_budget_min, mode, max_questions}; batched AskUserQuestion with `(Recommended)` defaults; the rare audience-only ask `<!-- defer-only: free-form -->`; hard stop if no purpose); `## Phase 3 — Generate` (3.1 the survey.json schema verbatim, 3.2 the question object + type enum + schema invariants, 3.3 the FR-21 time-cost constants, 3.4 build survey.json applying best-practices + generating none of the antipatterns, 3.5 trim-to-budget, 3.6 render survey.json/survey.html-substrate-compliant+survey.sections.json/preview.html-standalone/cp survey-preview.js/cp assets/seed index.html, 3.7 commit "survey-design: initial draft for <slug>" + re-render policy).

Self-checks: NI block matches canonical (diff empty); >=5 description phrases (7); both block markers present; `Platform Adaptation`, `schema_version`, `survey-preview.js` all present; no `reference/*` content inlined (reworded two lines so the literal "detection heuristic" doesn't appear in SKILL.md, satisfying the §13.1 assert). Ran the canonical awk extractor against the file: 4 AskUserQuestion call sites, each with a `(Recommended)` option or a `defer-only: free-form` tag. TDD: no — SKILL.md prose (FR-105); verified by §13.1 static checks + §13.2 integration run at TN.
