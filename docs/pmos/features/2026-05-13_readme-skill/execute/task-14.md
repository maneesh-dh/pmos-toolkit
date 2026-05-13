---
task_number: 14
task_name: "Mode resolver — --scaffold + composition (D16) + --update exclusion"
plan_path: "docs/pmos/features/2026-05-13_readme-skill/03_plan.html"
branch: "feat/readme-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-readme-skill"
status: done
started_at: 2026-05-13T15:10:00Z
completed_at: 2026-05-13T15:18:00Z
commit_sha: acb0de1
files_touched:
  - plugins/pmos-toolkit/skills/readme/SKILL.md
---

## Outcome

DONE. Appended `### §4: Mode resolution` to SKILL.md below §3 and above `## Anti-Patterns`. New subsection (35 lines added) documents:

1. **FR-MODE-1** — three primary modes (`audit` / `scaffold` / `update`), exactly one active per invocation (or composition).
2. **FR-MODE-2** — full resolution truth table covering 7 input/flag combinations with explicit exit-64 cases (`--audit` without README; `--update` mutex with `--audit`/`--scaffold`).
3. **FR-MODE-3** — `audit+scaffold` composition per D16 for mixed-presence monorepos, with the multi-line chat-log emission format.
4. **FR-MODE-4** — single observable chat-log line `mode: <resolved> (source: cli|default-readme-present|default-readme-absent)`.
5. **Error cases** — three exit-64 conditions enumerated.
6. **Cross-refs** — back to §1 for argv parsing, forward to §5 (T15, dangling until next dispatch — acknowledged in spec).

P11 append-only honored: §1, §2, §3, Phase 0, Phase 0b, non-interactive-block, awk-extractor, Anti-Patterns, Phase N untouched.

## Deviations

None. Followed the dispatched §4 content verbatim, including the deliberately dangling §5 cross-ref (T15 will land it).

## Residuals

1. §5 anchor `#5-repo-miner-subagent` will dangle until T15 lands the repo-miner subagent subsection.
2. `--scope` flag (referenced in FR-MODE-3 parenthetical) is a T22 follow-up; argv parsing not yet wired.
3. Runtime enforcement of the truth table (the actual resolver shell logic) lives in §1's argv loop today as defaults-only; the mutex/error-exits are documentation-as-contract until the runner script (T15+) consumes them.

## Verification

- `wc -l` → 254 lines (≤480 cap, P8 ✓).
- `grep -c "FR-MODE-1\|FR-MODE-2\|FR-MODE-3\|FR-MODE-4"` → 6 (≥4 ✓).
- `grep -c "Resolved mode"` → 1 (truth table present ✓).
- `git diff 3bf8620 -- plugins/pmos-toolkit/skills/readme/SKILL.md | grep '^-' | grep -v '^---' | wc -l` → 0 (P11 append-only ✓).
- Only `plugins/pmos-toolkit/skills/readme/SKILL.md` touched; reference/, scripts/, tests/ untouched ✓.

Commit: `acb0de1`.
