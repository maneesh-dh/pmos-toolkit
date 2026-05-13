---
task_number: 5
task_name: "File scanner — gitignore + deny-list + ext filter"
task_goal_hash: "sha256:t5-file-scanner-gitignore-deny-list-ext-filter-fr40-41-42-43-d15"
plan_path: "docs/pmos/features/2026-05-13_architecture-principles-skill/03_plan.html"
branch: "feat/architecture-principles-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-architecture-principles-skill"
status: done
started_at: 2026-05-13T12:35:00Z
completed_at: 2026-05-13T12:40:00Z
files_touched:
  - plugins/pmos-toolkit/skills/architecture/tools/run-audit.sh
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/gitignore-deny/.gitignore
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/gitignore-deny/src/a.ts
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/gitignore-deny/node_modules/junk.ts
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/gitignore-deny/.venv/lib.py
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/gitignore-deny/dist/bundle.js
commit: d8daccd
---

## Summary

File enumeration replaces the tracer's `grep --include` with a proper
two-mode enumerator (FR-40/41): `git ls-files --cached --others
--exclude-standard` inside a repo (gitignore-honoring), `find -type f
-not -path '*/.git/*'` otherwise. The hardcoded 14-entry deny-list
(D15 — `node_modules .venv __pycache__ dist build .pytest_cache
.ruff_cache .mypy_cache coverage .next .nuxt .git target vendor`) plus
L3 `extra_ignore` (FR-14) are applied as a path-segment match (FR-42).
Survivors are filtered to `.ts .tsx .js .jsx .mjs .cjs .vue .py` for the
rule pipeline (FR-43). The U004 grep now iterates `files_for_rules`
emitted by the python3 loader; the report carries `scanned.{total,
by_ext, excluded_by_gitignore, excluded_by_fallback}` (FR-40).

## TDD red → green

- **Red:** No `scanned` block in the report; the U004 grep walked all
  `*.ts` files regardless of gitignore/deny-list — the tracer accidentally
  worked because no fixture had populated `node_modules/`.
- **Green:** `scanned` emitted; gitignore-active fixture yields
  `excluded_by_gitignore=3`; gitignore-stripped variant yields
  `excluded_by_fallback=3`; only `src/a.ts` reaches the rule pipeline.

## Runtime evidence (6/6 PASS)

| # | Test | Result |
|---|------|--------|
| 1 | `gitignore-deny/` (git-init + `.gitignore`): `scanned.total=1`, `by_ext={".ts":1}`, `excluded_by_gitignore=3`, `excluded_by_fallback=0`, `findings=0` (src/a.ts is the safe `greet` source) | PASS |
| 2 | Same fixture minus `.git/` + `.gitignore`: `total=1`, `excluded_by_gitignore=0`, `excluded_by_fallback=3` (deny-list catches `node_modules/.venv/dist`); `findings=0` | PASS |
| 3 | Tracer `tests/fixtures/tracer/` regression: `findings.length=1`, finding for `src/a.ts:1` (T1 still green) | PASS |
| 4 | `l3-override/` regression: 1 finding with `severity="info"` + 1 `rule_overrides` entry (T4 demote intact) | PASS |
| 5 | `principles-16-rules/` regression: exit 64 with `ERROR: L1 has 16 rules; cap is 15.` (T3 cap intact) | PASS |
| 6 | `l3-malformed/` regression: exit 64 with `ERROR: ... malformed:` (T4 FR-23 intact) | PASS |

## Decisions / deviations

- **`scanned.total` counts only supported-ext survivors.** Plan §T5 step
  4 says "count others under `scanned.total`", but the inline-verification
  block asserts `total=1, by_ext={".ts":1}` on a fixture that contains a
  `.gitignore` dotfile (which would be a non-supported-ext survivor).
  Resolved by following the verification: `total` = `files_for_rules`
  count; non-supported survivors (`.gitignore`, README, configs) are
  dropped silently. `by_ext` is symmetric — only supported exts appear.
  Documented as a step-vs-verification reconciliation in the commit.
- **Newline-delimited file list, not NUL.** Initial design used
  `tr '\n' '\0'` + `read -r -d ''` to handle pathological filenames,
  but bash command substitution strips NUL bytes — `SCANNED_FILES_NUL`
  arrived empty, silently zeroing every finding loop. Switched to plain
  newline-delimited; filenames with embedded newlines are pathological
  for git itself.
- **`{ grep || true; }` wraps the per-file U004 grep.** Under
  `set -euo pipefail`, grep's exit-1-on-no-match propagated up through
  the pipeline in command substitution and killed the assignment
  silently (script exited 1 with empty stdout). The `|| true` keeps
  the no-match case as exit-0 inside the pipe.
- **`files_for_rules` is internal-only.** The python3 loader emits it
  for the scanner loop, but the final `jq -n` deletes it from the
  report (`scanned: ($loader.scanned | del(.files_for_rules))`) — a
  full repo's file list would balloon the JSON without informing the
  consumer.
- **Fixture excluded dirs must be `git add -f`'d.** The fixture ships
  its own `.gitignore` (the whole point of the test); without
  force-add, the outer worktree's git refuses to track
  `node_modules/junk.ts`, `.venv/lib.py`, `dist/bundle.js` — and the
  test then degrades to a no-op since the files-to-exclude don't
  exist on disk for the next checkout.
- **In-repo path uses `--cached --others --exclude-standard`, not the
  plan's `ls-files + check-ignore -q` pair.** The plan's two-step is
  equivalent for tracked files only; `--others --exclude-standard`
  also covers untracked-not-ignored files (new edits during local dev)
  which is the more correct behavior. `--exclude-standard` honors
  `.gitignore`, `.git/info/exclude`, and the global excludes file.
  The `excluded_by_gitignore` count comes from a separate `os.walk`
  pass diffed against the ls-files keep-set.

## Verification outcome

PASS. All 6 inline assertions green. T5 sealed; cursor advances to T6
(L1 grep rules — size/shape: U001, U002, U003, U006).
