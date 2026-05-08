---
task_number: 6
task_name: "Update /requirements + /spec /msf refs"
task_goal_hash: T6-update-req-spec-callers
plan_path: "docs/features/2026-05-08_msf-skill-split/03_plan.md"
branch: "feature/msf-skill-split"
worktree_path: ".worktrees/msf-skill-split"
status: done
started_at: 2026-05-08T00:35:00Z
completed_at: 2026-05-08T00:38:00Z
files_touched:
  - plugins/pmos-toolkit/skills/requirements/SKILL.md
  - plugins/pmos-toolkit/skills/spec/SKILL.md
---

# T6 — done

3 edits in /requirements (lines 13, 320, 554), 1 in /spec (line 13). Zero bare /msf references remain in either file.

## Deviation

Plan T6.3's verification used `/usr/bin/grep '/msf\b'` which incorrectly matched `/msf-req` (word boundary fires between `f` and `-`). Switched to `grep -E "/msf[^-a-zA-Z0-9_]|/msf$"` to catch only bare `/msf` not part of `/msf-req` or `/msf-wf`. Verification PASS.
