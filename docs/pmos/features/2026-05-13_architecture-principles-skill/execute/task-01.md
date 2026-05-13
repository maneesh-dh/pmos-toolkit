---
task_number: 1
task_name: "Tracer bullet — single grep rule, single fixture, JSON to stdout"
task_goal_hash: "sha256:t1-tracer-bullet-narrowest-audit-pipeline-console-log-grep-json-stdout"
plan_path: "docs/pmos/features/2026-05-13_architecture-principles-skill/03_plan.html"
branch: "feat/architecture-principles-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-architecture-principles-skill"
status: done
started_at: 2026-05-13T00:00:11Z
completed_at: 2026-05-13T00:00:12Z
files_touched:
  - plugins/pmos-toolkit/skills/architecture/tools/run-audit.sh
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/tracer/src/a.ts
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/tracer/expected.json
---

## Summary

Tracer-bullet audit harness implemented. Single-rule, hardcoded `console.log` grep over `.ts` files; emits JSON schema_version=1 with one finding to stdout; exits 0. Proves the audit pipeline end-to-end before any rule-loader or scanner widening.

## TDD red → green

- **Red:** `run-audit.sh` didn't exist → `bash: No such file or directory`.
- **Green:** After implementation, fixture `tests/fixtures/tracer/src/a.ts` (one `console.log("hi");`) audited cleanly.

## Runtime evidence (CLI task; FR-70/FR-71 minimal subset)

Six inline assertions all PASS:
- `.schema_version == 1`
- `.findings | length == 1`
- `.findings[0].rule_id == "U004"`
- `.findings[0].severity == "warn"`
- `.findings[0].line == 1`
- `.findings[0].file` ends with `src/a.ts`

Stdout produces a valid JSON document parseable by `jq`. `run` sub-object carries ISO-8601 `started_at` / `finished_at` (the timestamp surface FR-73's determinism strip will target — `jq 'del(.run)'`).

## Decisions / deviations

- `printf` replaces the plan snippet's `print` in awk — `printf` with positional `%s/%d` arguments produces cleaner JSON than embedded shell-quote dance.
- Added the FR-23 jq presence gate at the top of the script (one task earlier than T17 strictly requires) — costs nothing and removes a footgun if T2+ widening introduces jq calls elsewhere.
- File path emitted as the path passed by `grep -rn` (relative to cwd, prefixed by `$SCAN_ROOT`). T5 (file scanner) will normalize to repo-relative when the real loader lands.

## Verification outcome

PASS. All 6 inline assertions green; exit 0; JSON parseable.
