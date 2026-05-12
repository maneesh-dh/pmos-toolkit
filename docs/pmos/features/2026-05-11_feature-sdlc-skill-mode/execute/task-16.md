---
task_number: 16
task_name: "Create plugins/pmos-toolkit/skills/skill-sdlc/SKILL.md (the thin alias)"
status: done
started_at: 2026-05-12T00:00:00Z
files_touched:
  - plugins/pmos-toolkit/skills/skill-sdlc/SKILL.md
tdd: "no — a ~15-line forwarding skill; verification is grep + the §13.3 forwarding check in TN"
---

## What changed

Created `plugins/pmos-toolkit/skills/skill-sdlc/SKILL.md` — a 12-line thin alias:
- Frontmatter: `name: skill-sdlc`; `description:` (one-clause "what" + 6 trigger phrases incl. `/skill-sdlc`); `user-invocable: true`; `argument-hint:` enumerating `--from-feedback`, `<description|feedback>`, `--from-retro`, `--tier`, `--no-worktree`, `--format`, `--non-interactive|--interactive`, `--backlog`, `--minimal`.
- Body: one paragraph — "thin alias, runs no logic", instructs immediate verbatim forwarding to `/pmos-toolkit:feature-sdlc skill <args>` with two worked examples (`"a skill that lints YAML"` and `--from-feedback path/to/retro.md`), and a closing note that all skill-dev logic / worktree / resume / eval loop / learnings capture live in `/feature-sdlc`.
- NO "Load Learnings" line, NO numbered phases, NO `## Platform Adaptation` section — per FR-81 / D19, the thin-alias-gated eval checks (`d-learnings-load-line`, `d-capture-learnings-phase`, `d-progress-tracking`, `d-body-skeleton`) are `applies_when`-gated to "not a thin alias" and won't fire.

## Verification

- `wc -l SKILL.md` → 12 (≤ ~20). ✓
- `grep -c 'learnings.md'` → 0. ✓
- `grep -E '^name: skill-sdlc$'` → line 2. ✓
- `grep -cF 'feature-sdlc skill'` → 2 (the forwarding instruction + the second example). ✓
- `audit-recommended.sh` → exit 0 (0 AskUserQuestion calls → vacuously passes). ✓
- `grep -c '^## /skill-sdlc' ~/.pmos/learnings.md` will be 0 after T22 (T22 only adds `## /feature-sdlc`).
