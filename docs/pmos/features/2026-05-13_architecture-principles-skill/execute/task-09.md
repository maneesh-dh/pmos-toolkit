---
task_number: 9
task_name: "Dep Cruiser shell-out + .depcruise.cjs (TS001–TS004)"
task_goal_hash: "sha256:t9-dep-cruiser-shell-out-ts001-ts004-fr30-fr32-fr33"
plan_path: "docs/pmos/features/2026-05-13_architecture-principles-skill/03_plan.html"
branch: "feat/architecture-principles-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-architecture-principles-skill"
status: done
started_at: 2026-05-13T13:55:00Z
completed_at: 2026-05-13T14:20:00Z
files_touched:
  - plugins/pmos-toolkit/skills/architecture/tools/run-audit.sh
  - plugins/pmos-toolkit/skills/architecture/tools/.depcruise.cjs
  - plugins/pmos-toolkit/skills/architecture/package.json
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/ts-circular/src/a.ts
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/ts-circular/src/b.ts
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/ts-circular/package.json
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/ts-circular/tsconfig.json
  - .gitignore
---

## Summary

First L2 delegated tool lands. `dependency-cruiser` is shelled out via
`npx --no-install depcruise --output-type json --config tools/.depcruise.cjs`
to evaluate TS001–TS004. Violations are mapped 1:1 by rule name into the
audit's `findings[]`; severities flow through the L3 `effective_severity`
rewrite. Graceful-degrade per FR-32 lands as a partial — `tools_skipped`
gains `"dependency-cruiser"` when npx/depcruise is absent.

| Rule | Encoding in `.depcruise.cjs` |
|---|---|
| TS001 | `forbidden{ to.circular: true }`, severity error |
| TS002 | `from.path: src/ui/`, `to.path: src/db/`, severity error |
| TS003 | `from.orphan: true` (pathNot tests/scripts/.d.ts), severity warn |
| TS004 | `from.path: src/`, `to.dependencyTypes: [npm-dev]`, severity error |

## TDD red → green

- **Red:** Pre-T9 audit on `tests/fixtures/ts-circular/` yields zero TS
  findings; only the now-noise U007 (no purpose comment) fires.
- **Green:**
  `tools/run-audit.sh tests/fixtures/ts-circular/ | jq '[.findings[] | select(.rule_id|startswith("TS"))]'`
  → `[{rule_id:"TS001", severity:"block", file:"src/a.ts", line:1, source_citation:"principles.yaml#TS001"}]`
  (severity rewritten from depcruise `error` → audit `block` via the
   `effective_severity` table; the L3-merge sort still applies.)

## Runtime evidence (1 primary + 1 graceful-degrade + 7 regressions = 9/9 PASS)

| # | Test | Result |
|---|------|--------|
| 1 | **Primary** — `ts-circular/` yields exactly 1 TS001 finding (severity=block, file=src/a.ts, line=1) | PASS |
| 2 | **Graceful degrade** (FR-32) — fake `npx` returning exit 127 on PATH: `tools_skipped=["dependency-cruiser"]`, TS findings = 0, `[warn] dependency-cruiser not available …` on stderr | PASS |
| 3 | `tracer/` (T1): U004 still fires; rule_ids = `["U004","U007"]` | PASS |
| 4 | `l1-size/` (T6): rule_ids = `["U001","U002","U003","U006","U007"]` | PASS |
| 5 | `l1-hygiene/` (T7): rule_ids = `["U004","U005","U007","U008"]` | PASS |
| 6 | `l1-security/` (T8): rule_ids = `["U009","U010"]` | PASS |
| 7 | `l3-override/` (T4): rule_ids = `["U004","U007"]`, demote intact | PASS |
| 8 | `gitignore-deny/` (T5): scanned=1, excluded_by_fallback=3, findings=0 | PASS |
| 9 | `principles-16-rules/` (T3) via `RUN_AUDIT_PLUGIN_YAML=…`: exit 64, FR-21 cap error intact | PASS |

## Decisions / deviations

- **TS-stack gate.** The depcruise shell-out runs only when `stacks_detected`
  includes `"ts"` (resolved by T3's loader). On a pure-Python tree the
  call is skipped entirely — neither `tools_skipped` nor a delegated-tool
  log line fires. Keeps the audit fast on stacks the rule doesn't apply
  to and avoids spurious `[warn]` noise.

- **dc_cwd fallback (SCAN_ROOT → SKILL_DIR).** Depcruise needs the
  `typescript` peer to parse `.ts` files. The implementation first tries
  to run from `$SCAN_ROOT` so a project's own `typescript` is picked up;
  on failure it falls back to `$SKILL_DIR` (which ships dep-cruiser +
  typescript as devDeps). This lets the audit work on hosts that don't
  install typescript themselves, while still honouring the project's
  toolchain when present. Decision logged inline.

- **`timeout` is GNU, not BSD.** The plan's `timeout 60` doesn't exist
  on default macOS. Detect `timeout` → `gtimeout` → no-timeout and emit
  the chosen invocation in the `[delegated]` log line so /verify can
  confirm the actual command run. Documented inline.

- **Rule names = rule_ids 1:1.** The `.depcruise.cjs` names rules
  `TS001`–`TS004` (not the depcruise-canonical `no-circular` /
  `no-orphans` etc.) so the run-audit.sh jq mapper can use
  `.rule.name` directly as `rule_id`. Cuts a translation table.

- **`source_citation` from `rule.name`.** Format is
  `principles.yaml#TS00N` — matches the L1 rules' citation format
  (T6/T7/T8). The plan's "source_citation from principles.yaml" was
  ambiguous; canonicalised on the L1 shape for consistency.

- **Severity mapping: depcruise → audit.** `error → block`, `warn → warn`,
  anything else → `info`. The final `jq -n` then rewrites via
  `effective_severity[.rule_id]` so L3 demotes/promotes still flow.

- **Line number = 1 (placeholder).** Depcruise emits a module-level
  violation; the canonical "where" is the importer module, not a
  specific line. Line 1 is the conventional default; a future
  refinement could parse the import-statement line, but TS001-style
  cycle violations are typically reported at module scope.

- **`tools_skipped` field shipped now, not deferred to T11.** The plan
  lists the field as part of T11 (the formal FR-32 task) but T9 needs
  to populate it for the dep-cruiser slot; the field is shipped here
  as a string-array, T11 will extend the shape if needed (likely with
  a peer `tools_errored` field per the plan's T11 outline).

- **typescript as devDep on the skill.** `package.json` ships both
  `dependency-cruiser` and `typescript` as devDependencies; the skill's
  own `node_modules/` is gitignored. `/complete-dev` will not commit
  it — a fresh clone re-runs `npm install` in the skill dir.

## Verification outcome

PASS. Primary inline-verification matches plan §T9 byte-for-byte
("findings include `{rule_id:'TS001'}`, length == 1"); FR-32 graceful-
degrade verified by injecting a failing `npx` shim; all 7 prior-task
regressions green. T9 sealed; cursor advances to T10 (ruff shell-out
for PY001–PY004).
