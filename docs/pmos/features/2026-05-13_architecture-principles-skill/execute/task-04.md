---
task_number: 4
task_name: "Project L3 loader + exemption rows + extra_ignore"
task_goal_hash: "sha256:t4-project-l3-merge-fr20-exemptions-fr13-config-fr14-malformed-fr23"
plan_path: "docs/pmos/features/2026-05-13_architecture-principles-skill/03_plan.html"
branch: "feat/architecture-principles-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-architecture-principles-skill"
status: done
started_at: 2026-05-13T00:03:00Z
completed_at: 2026-05-13T00:03:30Z
files_touched:
  - plugins/pmos-toolkit/skills/architecture/tools/run-audit.sh
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/l3-override/src/a.ts
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/l3-override/.pmos/architecture/principles.yaml
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/l3-malformed/.pmos/architecture/principles.yaml
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/exemption-row/src/a.ts
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/exemption-row/.pmos/architecture/principles.yaml
commit: cfba9e8
---

## Summary

L3 override merge (FR-11/20), exemption-row parsing (FR-13), and config keys
`adr_path` / `scan_root` / `extra_ignore` (FR-14) plumbed into the inline
python3 loader in `run-audit.sh`. Scanner findings now flow through an
`effective_severity` lookup so an L3 demote like `U004: warn → info` rewrites
the finding's severity at emit time. Exemption reconciliation against ADRs
stays deferred to T15 — T4 only parses the rows. Tracer T1 + T3 L1-cap
regressions both preserved.

## TDD red → green

- **Red:** L3 override fixture loaded silently — finding severity stayed
  `warn`; no `rule_overrides[]` emitted; no `config` / `exemptions` keys in
  the JSON report.
- **Green:** Override merge applied per FR-20 (L3 > L1); diff captured in
  `rule_overrides[]`; exemption rows + config keys parsed; severity rewrite
  flowing through to findings.

## Runtime evidence (5/5 PASS)

| # | Test | Result |
|---|------|--------|
| 1 | `l3-override/` → finding severity = `info`; `rule_overrides[0]` has `severity {warn→info}` + `tier {1→3}`; `l3_present=true` | PASS |
| 2 | `l3-malformed/` → exit 64; stderr `^ERROR: .*malformed:` per FR-23 | PASS |
| 3 | `exemption-row/` → `exemptions.length=1` with full FR-13 shape; `config.adr_path=docs/adr/`; `config.extra_ignore=["generated/", "vendor/"]`; `l3_present=true`; 1 finding still emitted | PASS |
| 4 | Tracer `tests/fixtures/tracer/` → 1 finding, `l3_present=false`, `tier_1=10`, `rule_overrides=[]` (T1 regression intact) | PASS |
| 5 | `principles-16-rules/` fixture → exit 64 with exact FR-21 message (T3 L1 cap regression intact) | PASS |

## Decisions / deviations

- **`tier_3` counts NEW L3-only rules, not overrides.** An L3 row whose `id`
  matches a plugin rule mutates the existing entry (recorded in
  `rule_overrides[]`); it does not increment `tier_3`. Only an L3 row with a
  brand-new `id` adopts `tier: 3` and bumps the counter. Matches spec FR-20
  ("Lower-tier rule fields override higher-tier; missing fields inherit") —
  override is mutation, not addition.
- **`effective_severity` map drives finding severity at jq emit time.** The
  scanner stub still emits a hardcoded `"warn"` from awk; the final jq
  pipeline replaces it with `effective_severity[.rule_id] // .severity`.
  Keeps the T1 awk path untouched and gives T5+ scanners a free path to
  honor L3 demotes without re-walking the merged-rules table.
- **Exemption parsing is passthrough; reconciliation deferred to T15** per
  plan §T4 step (3). T4 surfaces `exemptions[]` in the JSON report so T15
  can match them against `## Suppresses` blocks in ADR files; today no
  reconciliation, no `suppressed_by` population beyond the T1 stub `null`.
- **L3 file top-level must be a mapping.** `yaml.safe_load` happily returns
  a bare string for nonsense input like `:::: not yaml ::::` — added an
  explicit `isinstance(l3, dict)` check that raises the FR-23 malformed
  message rather than silently treating a string as empty config.
- **`config` defaults emit even when L3 is absent.** When no L3 file is
  present, `config = {adr_path: "docs/adr/", scan_root: ".", extra_ignore: []}`
  ships in the report. T5+ wireframes a single read path: the scanner
  always reads `config.extra_ignore` without a presence check.

## Verification outcome

PASS. All 5 inline assertions green. Phase 2 cursor advances to seal.
