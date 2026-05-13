# T19 — §8: Opt-in dual gate

**Commit:** `1b1d9a2` — `feat(T19): opt-in dual gate + git-add-only stage (FR-UP-4 + FR-UP-5)`

## Deliverable

Appended `### §8: Opt-in dual gate` to `plugins/pmos-toolkit/skills/readme/SKILL.md` between §7 (`### §7: Update-mode flow`) and `## Anti-Patterns`. Documents:

- **FR-UP-4 dual-flag check:** user-global `~/.pmos/readme/config.yaml :: phase_7_6_hook_enabled` AND per-run `.pmos/complete-dev.lastrun.yaml :: readme_update_hook`. Both must be `true`; absent treated as `false`; otherwise no-op + single-line warn.
- **FR-UP-5 staging-only contract:** on rubric pass, `git add <readme-path>` only — no `git commit`, no `git push`. /complete-dev owns the release commit.
- 6-row resolution table covering true/false/absent permutations.
- Re-enablement recipes for both flags.
- "Why dual" rationale: global = one-time enablement, per-run = per-release confirmation.

## Constraints verified

| Check | Target | Actual |
|---|---|---|
| SKILL.md line count | ≤480 | 418 |
| Lines added | n/a | 42 |
| P11 removed lines vs 06b9357 | 0 | 0 |
| Grep `phase_7_6_hook_enabled\|readme_update_hook\|FR-UP-4\|FR-UP-5` | ≥4 | 12 |
| Files touched | SKILL.md only | SKILL.md only |

## Deviations

None. §8 content matches the T19 spec block verbatim. The forward-pointer `[§8: Opt-in dual gate](#8-opt-in-dual-gate)` from §7 (added in T18) now resolves.

## Next

T20 — per the Phase 6 plan.
