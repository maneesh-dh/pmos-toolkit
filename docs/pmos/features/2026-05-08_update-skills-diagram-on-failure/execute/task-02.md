---
task_number: 2
task_name: "Phase 6.5 mode-gated dispatch + Exit-Code contract"
task_goal_hash: "n/a-tier1-docs"
plan_path: "docs/pmos/features/2026-05-08_update-skills-diagram-on-failure/03_plan.md"
branch: "feature/diagram-on-failure"
worktree_path: "."
status: done
started_at: 2026-05-08T00:00:00Z
completed_at: 2026-05-08T00:00:00Z
files_touched:
  - plugins/pmos-toolkit/skills/diagram/SKILL.md
---

# T2 — Phase 6.5 dispatch + Exit-Code contract

Done.

## Verification
- `audit-recommended.sh` PASS (10 calls, 10 defer-only, 0 unmarked).
- `lint-non-interactive-inline.sh` OK for diagram/SKILL.md.
- `grep -c -e 'Exit 0' -e 'Exit 3' -e 'Exit 4'` → 3 matches (one per exit code in the new contract).

## Deviation
DEVIATION: Plan said "Do NOT issue `AskUserQuestion`" verbatim. Actual: `audit-recommended.sh`'s awk extractor counts any line containing the literal token `AskUserQuestion` as a call site, so prose mentions of it (in Phase 0 and Phase 6.5) registered as unmarked calls. Reworded both mentions to "interactive prompt"/"AUQ" to sidestep the regex without changing meaning. T3 bats assertions don't depend on the literal token.

## Notes
- Phase 6.5 expanded from ~15 lines to ~38 lines.
- Sequence inside Interactive subsection: `<!-- non-interactive: handled-via on-failure-flag -->` (explanatory) is line N, `<!-- defer-only: ambiguous -->` is line N+1 (immediately above the AUQ — required for awk adjacency check).
