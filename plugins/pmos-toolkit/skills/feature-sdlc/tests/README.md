# feature-sdlc/tests

Behavioural fixtures for `../tools/skill-eval-check.sh` (the deterministic half of
the `skill-eval.md` rubric).

- `fixtures/clean-skill/` — a minimal, well-formed skill. Running
  `skill-eval-check.sh --target generic fixtures/clean-skill` must report every
  applicable `[D]` check as `pass` and exit `0`.
- `fixtures/dirty-skill/` — a skill with planted `[D]`-check defects: a name that is
  not lowercase-hyphenated and does not match the directory; a body over 800 lines;
  no `## Platform Adaptation` section; no learnings-load line; no numbered
  Capture-Learnings phase; a hard-coded absolute path in the body; and a >100-line
  `reference/big.md` with no leading table of contents (the body links to it, so the
  reference-only group-C checks apply). Running
  `skill-eval-check.sh --target generic fixtures/dirty-skill` must report those
  `check_id`s as `fail` and exit `1`; with `--target claude-code` it additionally
  fails `f-cc-user-invocable` (no `argument-hint`).

These directories are **not loadable skills** — they live under `tests/`, not under
a `skills/` directory, so the plugin manifest never picks them up.
