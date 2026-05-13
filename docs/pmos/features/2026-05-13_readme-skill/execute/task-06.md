---
task_number: 6
task_name: "reference/opening-shapes.md — per-type opening patterns"
plan_path: "docs/pmos/features/2026-05-13_readme-skill/03_plan.html"
branch: "feat/readme-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-readme-skill"
status: done
started_at: 2026-05-13T13:00:00Z
completed_at: 2026-05-13T13:18:00Z
commit_sha: db44017
review_report: "docs/pmos/features/2026-05-13_readme-skill/verify/2026-05-13-phase-2-wave-1/report.md"
files_touched:
  - plugins/pmos-toolkit/skills/readme/reference/opening-shapes.md
---

## Outcome

DONE. 204 lines. §1 5-block pattern × 5 type subsections + §2 map+identity × 2 + §3 5 anti-patterns. All 7 worked-example annotations cite real rubric.yaml check IDs. Combined Phase-2-Wave-1 reviewer: PASS.

## Deviation flagged for T7
Subagent's 1.4 (app) annotation claims "Download:" lines should count as quickstart-equivalent, but rubric.yaml `install-or-quickstart-presence` only matches `Install|Quickstart|Getting Started` headings. T7 author should either widen the regex to match a Download: pattern or T6 should soften that annotation.

Bonus content: 2 extra anti-patterns (logo-only opening, badge-wall opening) beyond the 3 in the brief. Pushed length to 204 (target 150-200, +4 within ±50 tolerance). Combined reviewer accepted.

Commit: `db44017`.
