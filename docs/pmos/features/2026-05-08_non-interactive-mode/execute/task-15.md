---
task_number: 15
task_name: "Author the per-skill rollout runbook + apply to /artifact"
task_goal_hash: 1b315c54e2271851291f0a16a66ab5a277174357b561cd01401cc07f81cf9bdf
plan_path: "docs/pmos/features/2026-05-08_non-interactive-mode/03_plan.md"
branch: "feature/non-interactive-mode"
worktree_path: ".worktrees/non-interactive-mode"
status: done
started_at: 2026-05-08T15:19:02Z
completed_at: 2026-05-08T15:42:00Z
files_touched:
  - plugins/pmos-toolkit/tests/non-interactive/per-skill-rollout-runbook.md
  - plugins/pmos-toolkit/skills/artifact/SKILL.md
  - plugins/pmos-toolkit/skills/_shared/non-interactive.md
  - plugins/pmos-toolkit/skills/requirements/SKILL.md
---

## Outcome

Runbook authored (150 lines) at `plugins/pmos-toolkit/tests/non-interactive/per-skill-rollout-runbook.md` (overwrote T6 stub). /artifact rollout: lint OK, audit exit 0, `18 calls, 0 Recommended, 18 defer-only, 0 unmarked`.

## Plan deviations

1. **Plan estimate "≤4 defer-only tags"** was wrong — /artifact's prose describes calls semantically without enumerating option lists, so all 18 real call sites required defer-only tags (2 destructive, 7 free-form, 9 ambiguous). T16–T39 should expect higher tag counts than projected.

2. **Anchor B (no inline pipeline-setup-block) is the common case** — 17 of 26 user-invokable skills lack an inlined pipeline-setup-block. Plan only mentioned Anchor A. Runbook documents both.

3. **Step 5 (false-positive prose rephrasing) is new** — 4 lines in /artifact contained the literal `AskUserQuestion` token in non-call contexts (Platform Adaptation note, parenthetical asides, headings). Tagging them would pollute the runtime OQ buffer with phantom DEFERs; rephrasing removes the token. Adopted as runbook step 5.

4. **Canonical extractor bug fixed.** The awk extractor's marker regexes `/<!-- non-interactive-block:start -->/` and `/<!-- non-interactive-block:end -->/` matched the awk script's OWN self-references (lines 78–79 of an inlined block contain those literal substrings inside awk syntax). This flipped `in_inlined` off mid-block, so line 94 (the awk's own `/AskUserQuestion/` rule) escaped the skip region and got reported as an unmarked call site in every rolled-out skill. Fix: anchor the regexes to whole-line (`/^<!-- non-interactive-block:start -->$/` and `/^<!-- non-interactive-block:end -->$/`). Updated canonical `_shared/non-interactive.md` and re-applied to /requirements (the only previously-rolled-out skill). T6 didn't surface this because /requirements pre-rollout was expected to fail audit.

## Runtime evidence

```
$ bash plugins/pmos-toolkit/tools/lint-non-interactive-inline.sh 2>&1 | grep -E '^(OK|DRIFT)'
OK:      artifact/SKILL.md
OK:      requirements/SKILL.md
DRIFT:   <24 other not-yet-rolled-out skills>

$ bash plugins/pmos-toolkit/tools/audit-recommended.sh plugins/pmos-toolkit/skills/artifact/SKILL.md
plugins/pmos-toolkit/skills/artifact/SKILL.md: 18 calls, 0 Recommended, 18 defer-only, 0 unmarked
PASS: all calls in 1 skill(s) are marked.
exit=0

$ bats plugins/pmos-toolkit/tests/non-interactive/  # 51 ok / 0 fail / 1 skip — no regression from canonical fix
```

## Inline check verification

- `bash plugins/pmos-toolkit/tools/audit-recommended.sh plugins/pmos-toolkit/skills/artifact/SKILL.md` → exit 0 ✓
- `grep -c '<!-- defer-only:' plugins/pmos-toolkit/skills/artifact/SKILL.md` → 19 (= K=18 audited tags + 1 prose mention inside the canonical block) ✓
- `wc -l plugins/pmos-toolkit/tests/non-interactive/per-skill-rollout-runbook.md` → 150 (≥ 80) ✓
