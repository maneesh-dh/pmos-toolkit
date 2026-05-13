---
task_number: 8
task_name: "L1 grep rules — security/safety (U009, U010 block)"
task_goal_hash: "sha256:t8-l1-security-safety-u009-u010-block-fr73-sort-section-7-4"
plan_path: "docs/pmos/features/2026-05-13_architecture-principles-skill/03_plan.html"
branch: "feat/architecture-principles-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-architecture-principles-skill"
status: done
started_at: 2026-05-13T13:25:00Z
completed_at: 2026-05-13T13:40:00Z
files_touched:
  - plugins/pmos-toolkit/skills/architecture/tools/run-audit.sh
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/l1-security/src/secret.ts
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/l1-security/src/tbd.py
commit: add22c8
---

## Summary

Final L1 batch. Two block-severity rules + the findings sort contract:

| Rule | Logic |
|---|---|
| U009 | regex `AKIA[0-9A-Z]{16}`, `sk-[a-zA-Z0-9]{20,}`, `(api[-_]?key\|secret\|password\|token)\s*=\s*["'][...]{16,}["']`, `-----BEGIN ... PRIVATE KEY-----`; block |
| U010 | regex `raise NotImplementedError` or `throw new Error\(["']TBD`; path-segment excludes `tests/` and `scripts/`; block |
| FR-73 sort | final `jq sort_by` keys block (0) → warn (1) → info (2), then file, line, rule_id for determinism |

## TDD red → green

- **Red:** Pre-T8 audit on `l1-security/` yields zero findings; the
  fixture's `sk-…` key and `raise NotImplementedError()` go undetected.
- **Green:** Both fire block-severity.
  `tools/run-audit.sh tests/fixtures/l1-security/ | jq '.findings'`
  → `[{rule_id:"U009", severity:"block", file:"src/secret.ts", line:2},
       {rule_id:"U010", severity:"block", file:"src/tbd.py",    line:3}]`

## Runtime evidence (1 primary + 7 regressions = 8/8 PASS)

| # | Test | Result |
|---|------|--------|
| 1 | **Primary** — `l1-security/` yields exactly `[{U009, block, secret.ts:2}, {U010, block, tbd.py:3}]`; severities array is `["block","block"]` (FR-73 block-first order) | PASS |
| 2 | `tracer/` (T1): U004 still fires on `src/a.ts:1` (T7 U007 noise also surfaces) | PASS |
| 3 | `l3-override/` (T4): severities=`["info","info"]`, `rule_overrides.length=1` (demote intact) | PASS |
| 4 | `principles-16-rules/` (T3) with `RUN_AUDIT_PLUGIN_YAML=…`: exit 64, `ERROR: L1 has 16 rules; cap is 15.` (FR-21 intact) | PASS |
| 5 | `l3-malformed/` (T4): exit 64 with FR-23 malformed error | PASS |
| 6 | `gitignore-deny/` (T5): `scanned.total=1`, `excluded_by_fallback=3`, findings=0 (deny-list intact) | PASS |
| 7 | `l1-size/` (T6): U001/U002/U003/U006 still fire (+ T7 U007 noise) | PASS |
| 8 | `l1-hygiene/` (T7): U004/U005/U007/U008 still fire | PASS |

## Decisions / deviations

- **Bash 3.2 single-quote workaround: `[\x22\x27]` in U009 / U010.** The
  same heredoc-inside-`$(...)` miscount that bit T7 (double quotes)
  fires on odd single-quote counts. U010_RE as `r'…["\']TBD'` has 3
  single quotes (open, escaped, close) → odd → bash refuses to parse
  the script. Rewrote both U009 and U010 quote classes to use the hex
  escapes `\x22` (`"`) and `\x27` (`'`) — same regex semantics, no
  literal quote characters in the python body. Documented inline.

- **U009 includes a PEM private-key matcher** (`-----BEGIN ... PRIVATE
  KEY-----`) per principles.yaml#U009; plan §T8 step 3 lists three
  patterns but principles.yaml is the source of truth. Carried it
  forward as a fourth alternative.

- **U009 applies to ALL paths; U010 honours `tests/` / `scripts/`
  exclusion.** Plan §T8 step 2 says "main-code-path = not under
  `tests/` or `scripts/`" for U010 only. Interpreted U009 as
  unrestricted — a secret in a test fixture is still an incident — and
  U010 as path-scoped (TBD stubs in tests/ are expected). Matches
  principles.yaml.

- **U010 regex requires explicit `raise NotImplementedError` /
  `throw new Error("TBD")`** — does not match `NotImplementedError`
  declarations / definitions. Plan §goal text says "on a main code
  path", which I read as a callable site (raise / throw) not a class
  declaration.

- **FR-73 sort key precedence: severity → file → line → rule_id.**
  Plan §T8 step 3 only specifies severity-desc. Added the file/line/
  rule_id secondary keys to make output stable across re-runs (the
  same scan with the same fixture must yield byte-identical findings
  order — otherwise diffing reports across CI runs is noisy).

- **Severity-index fallback `// 9` in jq filter.** Unknown severity
  values sort last. Defensive — principles.yaml validation already
  rejects unknown severities, but a future extension could grow the
  set. The `// 9` keeps the audit emitting findings rather than
  failing on the sort if an unexpected severity slips through.

## Verification outcome

PASS. Primary inline-verification matches plan §T8 byte-for-byte
("findings include `{rule_id:U009, severity:block}` and
`{rule_id:U010, severity:block}`"); FR-73 block-first ordering
verified; all 7 prior-task regressions green. T8 sealed; Phase 3
(L1 grep rules) complete. Cursor advances to T9 (Phase 4 — Dep
Cruiser shell-out for TS001–TS004).
