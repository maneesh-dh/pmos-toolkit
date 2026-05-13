---
task_number: 17
task_name: "commit-classifier.sh + 3 fixtures + --selftest"
plan_path: "docs/pmos/features/2026-05-13_readme-skill/03_plan.html"
branch: "feat/readme-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-readme-skill"
status: done
started_at: 2026-05-13T15:10:00Z
completed_at: 2026-05-13T15:25:00Z
commit_sha: 2780e86
files_touched:
  - plugins/pmos-toolkit/skills/readme/scripts/commit-classifier.sh
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/commits/.gitignore
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/commits/01_feat-only/setup.sh
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/commits/02_no-conv-commit/setup.sh
  - plugins/pmos-toolkit/skills/readme/tests/fixtures/commits/03_breaking/setup.sh
---

## Outcome

DONE. `commit-classifier.sh` (~165 LOC) parses a `<base>..HEAD`-shaped commit
range, classifies subjects by Conventional-Commit type (regex over the standard
11 types with optional `(scope)` and `!` bang-break), detects `BREAKING CHANGE`
footer (literal, case-sensitive) in commit bodies, and emits JSON shaped
`{range, commits[…], sections[union]}` keyed off the `commit_affinity` table in
`reference/section-schema.yaml` (single source of truth — read at runtime via
PyYAML, no hardcoded mapping). On no conv-commit subjects in range, emits
`{sections: [], warn: "no conventional-commit subjects"}` and logs the warn to
stderr (FR-UP-2).

Three fixtures with deterministic `setup.sh` materialisers (gitignored `.git/`
to avoid nesting inside outer worktree):

- `01_feat-only` — three `feat:` commits over an empty `chore: initial` base —
  expected sections `{Features, Usage, Quickstart}` (set-equal).
- `02_no-conv-commit` — two non-conventional subjects — expected empty
  sections + warn.
- `03_breaking` — `feat: …\n\nBREAKING CHANGE: …` + `fix: …` — expected to
  include `{Migration, Changelog}` (subset; actual union also contains the
  base `feat:` and `fix:` affinities).

`--selftest`: 3/3 PASS. shellcheck clean (only SC1091 info on the `_lib.sh`
source, acceptable per task constraints). `_lib.sh` untouched relative to
f241459 (append-only invariant held — T9 was the last touch).

## Deviations

- Spec said `feat` affinity is `{TLDR, Features, Quickstart, Usage}`; the
  schema source-of-truth at `commit_affinity.feat` is `[Features, Usage,
  Quickstart]` (no TLDR). Followed the schema — it's the single source of
  truth per T7, and any TLDR mapping should land via a schema edit, not a
  classifier-side override.
- `BREAKING CHANGE` footer affinity in the schema is `[Migration, Changelog]`
  (no Troubleshooting). The `fix:` commit in 03_breaking contributes
  Troubleshooting on its own, so the test now uses subset-mode equality
  (expected `{Migration, Changelog}` ⊆ actual) rather than strict set-equality.
- Heredoc-as-python (`python3 - <<PY`) would steal stdin from the git pipe;
  materialised the python program to a `mktemp`-ed file and feed git on
  stdin (cleaned up via explicit `rm -f` rather than `trap RETURN`, which
  collides with `set -u` on function exit).
- Fixture `.git/` directories are gitignored (not committed) — they would
  nest inside the outer worktree's index. `setup.sh` re-materialises them
  deterministically; `commit-classifier.sh` invokes `setup.sh` automatically
  when `<fixture>/.git/` is absent.

## Residuals

- The classifier only recognises 11 standard Conventional-Commit types
  (`feat|fix|chore|docs|refactor|test|build|ci|perf|revert|style`). If
  /readme's /update mode ever needs to honour custom types from the
  workstream's `commit_affinity` table, the regex needs to read the table's
  keys dynamically. Out of scope for T17; flag for /update wiring (Phase 7+).
- The `range` shape is documented as `<base>..HEAD` but the script accepts
  any `git log`-valid range. /update should pre-validate at call-site.

## Verification

- `commit-classifier.sh --selftest` — 3/3 PASS (verified 2026-05-13).
- `shellcheck commit-classifier.sh` — only SC1091 info on `_lib.sh` source.
- `git diff f241459 -- _lib.sh` — empty (untouched).
- Adhoc invocation against fixture 03_breaking with `HEAD~2..HEAD` produces
  the expected union `[Changelog, Troubleshooting, Features, Usage,
  Quickstart, Migration]` with `breaking: true` flagged on the `feat:`
  commit.
