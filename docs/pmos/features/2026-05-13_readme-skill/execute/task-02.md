---
task_number: 2
task_name: "rubric.sh skeleton + 1 check + --selftest (tracer bullet, layer 2 of 5)"
task_goal_hash: aed6528ddcbea0c8
plan_path: "docs/pmos/features/2026-05-13_readme-skill/03_plan.html"
branch: "feat/readme-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-readme-skill"
status: done
started_at: 2026-05-13T12:24:00Z
completed_at: 2026-05-13T12:33:00Z
commit_sha: 1bb1ee8
files_touched:
  - plugins/pmos-toolkit/skills/readme/scripts/_lib.sh
  - plugins/pmos-toolkit/skills/readme/scripts/rubric.sh
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/rubric/strong/01_hero-line.md
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/rubric/slop/01_no-hero.md
---

## Outcome

DONE_WITH_CONCERNS. rubric.sh applies 1 check (hero-line presence), emits TSV, ships with `--selftest`. _lib.sh provides `readme::log` / `readme::die`. 2 fixtures land the rubric/strong + rubric/slop convention that T7 will widen to 5+5.

## Key decisions

- **Hero-line awk strengthened.** Plan's verbatim awk pattern (`h1 && NF && !/^#/`) treats `- Fast` from the slop fixture as a hero line — the gate inverts (slop PASSes). Implementer subagent tightened the awk to exclude list items (`- * +`), blockquotes (`>`), and indented code (4-space). Fixture content kept verbatim per plan; only the awk pattern changed. The strengthened version matches the natural reading of "hero line = prose tagline" and makes the slop fixture FAIL as intended.
- **`shellcheck -x` (follow sourced) instead of plain `shellcheck`** to clean the SC1091 info-level note on the `source "$HERE/_lib.sh"` line. Plain shellcheck exits 1 with info-level note; `-x` exits 0 clean. T7 should standardize on `-x` in the widened test harness.
- **SC2015 cleanup** in the selftest gate: rewrote `[[ … ]] && { … } || { … }` as explicit `if/else` to silence the false-positive C-runs-after-A-true warning. No behavioral change.

## Verification

- Slop fixture: `EXIT=1`, stdout = `hero-line-presence\tFAIL\tHEAD\t1\tNo hero line found`.
- Strong fixture: `EXIT=0`, stdout = `hero-line-presence\tPASS\tHEAD\t1\t`.
- `--selftest`: `EXIT=0`, stderr = `[/readme] selftest: PASS`.
- `shellcheck -x rubric.sh _lib.sh`: clean (exit 0).
- Re-run `skill-eval-check.sh --target claude-code` after T2: gained `e-scripts-dir pass` (the scripts/ dir is now populated). 16/16 [D] checks pass.

## Runtime evidence

- `bash plugins/pmos-toolkit/skills/readme/scripts/rubric.sh --selftest` → `[/readme] selftest: PASS`, exit 0.
- TSV output shape verified on both fixtures (tab-separated, 5 fields: check-id / verdict / commit / line / message).

## Review notes — DELIBERATE /execute DEVIATION

Per-task two-stage review subagents SKIPPED for tracer-bullet phase (see task-01.md). Will be applied for Phase 4+.

Commit: `1bb1ee8`.
