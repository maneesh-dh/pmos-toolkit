---
task_number: 8
task_name: "External doc audit + CHANGELOG"
task_goal_hash: T8-external-doc-audit
plan_path: "docs/features/2026-05-08_msf-skill-split/03_plan.md"
branch: "feature/msf-skill-split"
worktree_path: ".worktrees/msf-skill-split"
status: done
started_at: 2026-05-08T00:42:00Z
completed_at: 2026-05-08T00:50:00Z
files_touched:
  - README.md
  - CHANGELOG.md
  - plugins/pmos-toolkit/skills/wireframes/SKILL.md
  - plugins/pmos-toolkit/skills/msf-wf/reference/psych-output-format.md
  - plugins/pmos-toolkit/skills/prototype/reference/friction-thresholds.md
---

# T8 — done

## Outcome

- README.md line 86: pipeline diagram updated.
- CHANGELOG.md created with 2.22.0 entry: breaking changes, migration notes, internal changes.
- Discovered + fixed 4 stale refs missed by T5: 2 anti-pattern bullets in /wireframes referencing the deleted Phase 7 (lines ~551–552), 2 dead bash lines in the Phase 8 commit instructions referencing `docs/msf/*.md` (lines ~497–498).
- Updated cross-skill prose:
  - `prototype/reference/friction-thresholds.md` — re-wrote the "/msf's job" line to point at /msf-req and /msf-wf.
  - `msf-wf/reference/psych-output-format.md` — updated the file's purpose statement to describe the new artifact location (Section B of `msf-findings.md`) with a parenthetical for the pre-2.22 history.

## Verification

- Zero bare `/msf` in README ✓
- CHANGELOG mentions 2.22.0, /msf-req, /msf-wf ✓
- Historical docs (`docs/plans/`, `docs/specs/`) intentionally untouched per FR-40.

## Deviations

T5's grep verification missed 4 stale refs in /wireframes/SKILL.md because the regex looked for "PSYCH"/"psych-findings"/"psych-output-format" tokens but those lines used `/msf` directly without the PSYCH keyword. Fixed during T8 audit. Worth a Phase 4 review-loop note: **plan T5.4 grep should also look for bare `/msf` references after the rewrite**, not just the PSYCH-token set.
