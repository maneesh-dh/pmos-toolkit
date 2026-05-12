---
task_number: 9
task_name: "Read feature-sdlc/SKILL.md end-to-end + map the renumber"
plan_path: "docs/pmos/features/2026-05-11_feature-sdlc-skill-mode/03_plan.html"
branch: "feat/feature-sdlc-skill-mode"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-feature-sdlc-skill-mode"
status: done
started_at: 2026-05-12T00:10:00Z
completed_at: 2026-05-12T00:10:00Z
files_touched: []
---
Read repo plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md (585 lines; structurally identical to the injected 2.36.0 body — feature-sdlc/SKILL.md unchanged by the 2.37.0 release). Renumber map → new linear sequence (FR-85): 0 (setup+load-learnings+subcommand-dispatch) · 0a (worktree+slug+branch) · 0b (resume) · 0c (feedback triage — NEW, skill-feedback only) · 0d (skill-tier-resolve — NEW, skill modes) · 1 (init state, schema v4) · 2 (/requirements + folded /msf-req) · 2a (/grill, Tier 2+) · 3 (enhancement-gates container) · 3a (/creativity) · 3b (/wireframes — feature only, suppressed in skill modes) · 3c (/prototype — feature only, suppressed) · 4 (/spec + folded /simulate-spec) · 5 (/plan) · 6 (/execute) · 6a (skill-eval gate — NEW, skill modes) · 7 (/verify, non-skippable) · 8 (/complete-dev) · 8a (/retro gate) · 9 (final summary) · 10 (capture learnings). The "Phase 2: Compact checkpoint" recurring micro-phase loses its number → "## Compact checkpoint (recurring micro-phase)", firing before 3b/3c/6/7 in feature mode and before 6/7 only in skill modes. Done-when grep target: `grep '^## Phase' SKILL.md` → "0, 0a, 0b, 0c, 0d, 1, 2, 2a, 3, 3a, 3b, 3c, 4, 5, 6, 6a, 7, 8, 8a, 9, 10" (21 lines). Byte-preserve regions: the entire `<!-- non-interactive-block:start --> … :end -->` block (incl. the awk extractor) and the `### Phase 0 Subcommand Dispatch` `list` short-circuit + `### list logic` subsection.
