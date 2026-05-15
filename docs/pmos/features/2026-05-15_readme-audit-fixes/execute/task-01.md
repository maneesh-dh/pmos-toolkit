---
task_number: 1
task_name: "BSD-awk fix + selftest drift-guard lint"
plan_path: "docs/pmos/features/2026-05-15_readme-audit-fixes/03_plan.html"
branch: "feat/readme-audit-fixes"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-readme-audit-fixes"
status: done
started_at: 2026-05-15T15:57:00Z
completed_at: 2026-05-15T16:05:00Z
files_touched:
  - plugins/pmos-toolkit/skills/readme/scripts/rubric.sh
---

## Decisions / deviations

- Pass A grep additionally filters shell-comment lines (`^[0-9]+:[[:space:]]*#`)
  to prevent the lint's own self-describing comment from false-positiving.
  Plan didn't specify this; discovered by running the lint on the freshly-
  edited rubric.sh.
- Pass B (multi-line awk-block tracking) reimplemented as state machine
  using `match()` + `substr()` (entering on `awk '` with no closing quote
  on the same line; exits on next single quote). Comment-line skip added
  defensively.

## Runtime evidence

- BSD-awk fix verified: `PATH=/usr/bin:$PATH bash …/rubric.sh
  …/strong/01_hero-line.md` now shows `install-or-quickstart-presence PASS`
  and `code-example-runnable-as-shown PASS` (previously FAIL).
- Lint verified: `--selftest` exits 0 on clean rubric.sh, emits
  `selftest: lint: PASS` + `selftest: fixture-agreement: PASS (100%)`.
- Lint regex catches planted `\b`: direct grep test on synthetic file with
  `awk '/\bmarker\b/{print}'` produces a hit.
- Full suite: `tests/run-all.sh` — 11 passed; 2 pre-existing failures
  (commit-classifier, update_hook_dry_run) unchanged.
