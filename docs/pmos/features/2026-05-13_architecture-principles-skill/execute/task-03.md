---
task_number: 3
task_name: "Rule loader with 3-tier precedence + L1 cap (FR-21)"
task_goal_hash: "sha256:t3-rule-loader-3tier-precedence-l1-cap-fr21-stack-detection-l3-presence"
plan_path: "docs/pmos/features/2026-05-13_architecture-principles-skill/03_plan.html"
branch: "feat/architecture-principles-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-architecture-principles-skill"
status: done
started_at: 2026-05-13T00:02:00Z
completed_at: 2026-05-13T00:02:45Z
files_touched:
  - plugins/pmos-toolkit/skills/architecture/tools/run-audit.sh
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/principles-16-rules/principles.yaml
commit: 7460ada
---

## Summary

`run-audit.sh` now loads `principles.yaml` via an inline python3 block: enforces FR-21 L1 cap, FR-22 stack detection, FR-23 L3 presence. Report payload extended with `rules_loaded.{tier_1, tier_2, tier_3, total}`, `l3_present`, `stacks_detected`. Tracer fixture (U004 grep) still emits 1 finding — T1 regression preserved. T4 will wire L3 overrides + exemptions on top.

## TDD red → green

- **Red:** L1 cap fixture loaded silently under the T2 validator stub (no cap enforcement).
- **Green:** Loader rejects 16-rule fixture with exact FR-21 message, exit 64.

## Runtime evidence (5/5 PASS)

| # | Test | Result |
|---|------|--------|
| 1 | L1 cap fixture → stderr `ERROR: L1 has 16 rules; cap is 15. Demote rules to L2 or remove.`, exit 64 | PASS |
| 2 | Tracer fixture → 1 finding (U004), `rules_loaded.tier_1=10`, `l3_present=false`, `stacks_detected=[]` | PASS |
| 3 | `/tmp/ts-scan` (package.json + tsconfig.json) → `tier_2=4`, `stacks_detected=["ts"]` | PASS |
| 4 | `/tmp/py-scan` (pyproject.toml) → `tier_2=4`, `stacks_detected=["py"]` | PASS |
| 5 | L3 malformed (`/tmp/l3-bad/.pmos/architecture/principles.yaml`) → exit 64 with FR-23 message; valid L3 → `l3_present=true` | PASS |

## Decisions / deviations

- **Loader implemented as inline python3 heredoc** rather than a separate `.py` file. Keeps T3 a single-file change; T4 (L3 override merge) and beyond may extract once the logic grows. Plan §P1 endorses bash+jq+python3 as the core stack.
- **Stack-detection requires BOTH `package.json` AND `tsconfig.json`** for `ts` per FR-22 verbatim. A JS-only repo (no tsconfig) yields `stacks_detected=[]` — the v1 spec ships TS-only L2 rules, so this matches the intended behavior. A future PY002 vs JS divergence is a v1.1+ concern.
- **L3 override merge deferred to T4** (separately tracked in plan). T3 only asserts L3 presence/malformed-rejection; the loader output schema already carries `l3_present` so T4's merge is a localized addition.
- **`grep` no-match (exit 1) under `set -euo pipefail`** killed the loader on manifest-only fixtures (no `.ts` files). Wrapped with `|| true` per the established `grep -r` idiom — preserves T1's tracer behavior and unblocks ts-only / py-only fixtures.
- **`rules_loaded.tier_3` always 0** until T4 wires L3 overrides. Schema kept stable so downstream report consumers see a fixed shape.

## Verification outcome

PASS. All 5 inline assertions green; commit `7460ada` lands cleanly. Tracer T1 regression intact. Phase 2 cursor advances to T4.
