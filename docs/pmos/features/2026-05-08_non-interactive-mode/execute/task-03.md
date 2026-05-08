---
task_number: 3
task_name: "Add Sections A/B/C to _shared/non-interactive.md"
task_goal_hash: "n/a-fresh-execution"
plan_path: "docs/pmos/features/2026-05-08_non-interactive-mode/03_plan.md"
branch: "feature/non-interactive-mode"
worktree_path: ".worktrees/non-interactive-mode"
status: done
started_at: 2026-05-08T00:12:00Z
completed_at: 2026-05-08T00:18:00Z
files_touched:
  - plugins/pmos-toolkit/skills/_shared/non-interactive.md
  - plugins/pmos-toolkit/tests/non-interactive/structure.bats
---

## Outcome

Sections A (refusal contract + exit 64), B (parser snippet), C (propagation prefix) appended. structure.bats: 8/8 pass. File now ~140 lines.

**DEVIATION:** Plan's parser snippet (Section B) was buggy — its second awk emitted `---` before every line, splitting each YAML key into a separate doc, so even valid input parsed to `[]`. Replaced with a corrected awk that strips fence markers and inserts `---` between successive yaml fenced blocks (a multi-doc stream), then `yq eval-all '[.]'` collects them into an array. Verified against three fixtures: single-entry block, multi-entry blocks (2 OQs → 2-element array), and missing section (`[]`). T12 (parser.bats) will codify these cases.

Committed: `feat(T3): shared non-interactive block — sections A/B/C (refusal, parser, propagation)`.
