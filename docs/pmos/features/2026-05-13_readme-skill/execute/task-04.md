---
task_number: 4
task_name: "reference/rubric.yaml — 15 binary checks + banned-phrase list + rubric-development.md"
plan_path: "docs/pmos/features/2026-05-13_readme-skill/03_plan.html"
branch: "feat/readme-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-readme-skill"
status: done
started_at: 2026-05-13T13:00:00Z
completed_at: 2026-05-13T13:18:00Z
commit_sha: 996af23
review_report: "docs/pmos/features/2026-05-13_readme-skill/verify/2026-05-13-phase-2-wave-1/report.md"
files_touched:
  - plugins/pmos-toolkit/skills/readme/reference/rubric.yaml
  - plugins/pmos-toolkit/skills/readme/reference/rubric-development.md
---

## Outcome

DONE. rubric.yaml: 15 checks (4 blocker / 7 friction / 4 nit), 14 banned phrases, 7 variants. rubric-development.md: 77 lines, ToC + 6 sections citing FR-E3 / FR-RUB-4 / banned-phrases.yaml extension path. Combined Phase-2-Wave-1 reviewer: PASS.

## Residuals for T7
- Variant `add:` directives reference undefined check IDs (`plugin-manifest-mentioned`, `contents-table-presence`, `per-package-link-table`, `link-up-to-root`, `per-plugin-link-table`). T7 must handle warn-and-skip or require pre-definition.
- No variant fixtures yet under `tests/fixtures/rubric/variants/<slug>/`.

## Review (combined reviewer deviation)
Per-task two-stage review (spec-compliance + code-quality) replaced with one combined reviewer for Phase 2 Wave 1 because these are declarative config/docs not behavioral code. Documented in the wave-1 report. T7 onward gets full two-stage review per task.

Commit: `996af23`.
