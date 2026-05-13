---
task_number: 10
task_name: "ruff shell-out (PY001–PY004)"
task_goal_hash: "sha256:t10-ruff-shell-out-py001-py004-fr31-fr32-fr33"
plan_path: "docs/pmos/features/2026-05-13_architecture-principles-skill/03_plan.html"
branch: "feat/architecture-principles-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-architecture-principles-skill"
status: done
started_at: 2026-05-13T14:25:00Z
completed_at: 2026-05-13T14:50:00Z
files_touched:
  - plugins/pmos-toolkit/skills/architecture/tools/run-audit.sh
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/py-tidy-imports/src/a.py
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/py-tidy-imports/src/b.py
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/py-tidy-imports/pyproject.toml
---

## Summary

Second L2 delegated tool. `ruff` is shelled out via
`ruff check --output-format=json --quiet --select=TID252,F401,F403,F405,B006 $SCAN_ROOT`
when the detected stack includes "py"; violations are mapped to PY001–PY004
by ruff code. Graceful-degrade per FR-32: missing/broken ruff →
`tools_skipped += "ruff"`, findings=[].

| ruff code | audit rule_id | source |
|---|---|---|
| TID252 | PY001 | flake8-tidy-imports relative imports |
| F401 | PY002 | unused import |
| F403 / F405 | PY003 | star imports |
| B006 | PY004 | mutable default argument |

## TDD red → green

- **Red:** Pre-T10 audit on `py-tidy-imports/` yields zero PY findings.
- **Green:**
  `tools/run-audit.sh tests/fixtures/py-tidy-imports/ | jq '[.findings[] | select(.rule_id|test("^PY"))]'`
  → 2 findings: `{PY001, warn, src/a.py:2}` (TID252 → relative import) and
  `{PY004, block, src/a.py:5}` (B006 → mutable default; block via L3
  `effective_severity` rewrite).

Plan inline verify: `length >= 1` → length=2 ✓.

## Runtime evidence (1 primary + 1 graceful-degrade + 8 regressions = 10/10 PASS)

| # | Test | Result |
|---|------|--------|
| 1 | **Primary** — `py-tidy-imports/` yields 2 PY-prefixed findings (PY001 warn, PY004 block) | PASS |
| 2 | **Graceful degrade** (FR-32) — fake ruff returning exit 127 on PATH: `tools_skipped=["ruff"]`, PY findings = 0, `[warn] ruff not available …` on stderr | PASS |
| 3 | `tracer/` (T1): rule_ids = `["U004","U007"]` | PASS |
| 4 | `l1-size/` (T6): `["U001","U002","U003","U006","U007"]` | PASS |
| 5 | `l1-hygiene/` (T7): `["U004","U005","U007","U008"]` | PASS |
| 6 | `l1-security/` (T8): `["U009","U010"]` | PASS |
| 7 | `l3-override/` (T4): `["U004","U007"]`, demote intact | PASS |
| 8 | `gitignore-deny/` (T5): scanned=1, excluded_by_fallback=3, findings=0 | PASS |
| 9 | `ts-circular/` (T9): `["TS001"]` | PASS |
| 10 | `principles-16-rules/` (T3) via env var: exit 64, FR-21 cap error intact | PASS |

## Decisions / deviations

- **`--quiet` flag mandatory.** ruff 0.15+ prints a trailing status line to
  stdout alongside the JSON unless `--quiet` is passed, which corrupts the
  `jq` parse downstream. Without it, `--output-format=json` emits valid
  JSON followed by a `\n` (1-byte output once piped through buffering
  weirdness — was the source of an initial dev-loop dead-end). Documented
  inline above the invocation.

- **Stronger availability check (`ruff --version`, not just `command -v`).**
  `command -v ruff` only verifies the binary is on PATH; it doesn't catch a
  broken/wrapper binary that exits non-zero. Audit now requires
  `command -v ruff >/dev/null 2>&1 && ruff --version >/dev/null 2>&1` —
  if either fails, FR-32 graceful-degrade fires. The T9 dep-cruiser path
  already gets this for free because its check (`npx --no-install
  depcruise --version`) actually invokes the tool. Parity now restored.

- **Py-stack gate.** Like T9, the shell-out runs only when `stacks_detected`
  includes `"py"`. Pure-TS trees skip ruff entirely — no `tools_skipped`
  entry, no log noise.

- **Code mapping in `run-audit.sh`, not `principles.yaml`.** The audit's
  `run_ruff()` carries the if/elif jq filter mapping `TID252→PY001`,
  `F401→PY002`, `F403/F405→PY003`, `B006→PY004`. Plan §T10 step 2
  specifies this. principles.yaml could carry a `delegate_to: ruff` +
  `delegate_code` field, but the simpler runtime mapping is fine for the
  4-rule set; reconsider when a 5th ruff rule is added.

- **TID252 needs `ban-relative-imports = "all"` in project pyproject.**
  The fixture's `pyproject.toml` sets it under
  `[tool.ruff.lint.flake8-tidy-imports]`. Audit does NOT inject this
  setting — projects opt into TID252 themselves; ruff's own config
  rules. Documented in the fixture pyproject.

- **`F401` non-fire on fixture is expected.** The fixture uses `from .b
  import value` and uses `value` in `f()`, so F401 (unused) doesn't fire.
  The primary contract was `length >= 1`, not "fires on all 4 rule_ids" —
  PY002/PY003 fires will land naturally in real-world audits.

- **`severity` mapping: ruff `error` → audit `warn` (default).** ruff
  classifies everything as `severity: error` in JSON; principles.yaml's
  default for PY001–PY004 are `warn` (TID252, F401, F403/F405) and
  `block` (B006). The final `jq -n` `effective_severity` rewrite picks
  up the principles.yaml-declared severities, so the in-pipe `warn`
  default is harmless. Verified: PY001=warn, PY004=block on output.

- **Mysterious interactive-shell rc=2.** During dev, ad-hoc `ruff check
  --output-format=json --select=… src/a.py` from the agent's shell
  produced rc=2 with empty output. Calling `/opt/homebrew/bin/ruff …`
  directly OR `bash -c '…'` worked fine (rc=1, full JSON). Run-audit.sh
  runs ruff via plain bash subprocess, so unaffected. Noted here for
  future debugging; not a skill-side issue.

## Verification outcome

PASS. Primary inline-verification matches plan §T10 byte-for-byte
("py-tidy-imports fixture produces at least 1 PY-prefixed finding");
FR-32 graceful-degrade verified by injecting a failing ruff shim;
all 8 prior-task regressions green. T10 sealed; Phase 4 (L2 delegated
tools + graceful-degrade partial) complete. Cursor advances to T11
(formal FR-32: `tools_skipped` + `tools_errored` final shape).
