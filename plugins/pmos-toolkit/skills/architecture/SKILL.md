---
name: architecture
description: Audit a repo against tiered architectural principles (L1 universal ≤15 rules, L2 stack-specific, L3 per-repo overrides); emit JSON report with rule citations; promote ≤5 block findings to Nygard ADRs. Use when the user says "audit my codebase against principles", "run an architecture review", "check for circular imports", "promote architectural decisions to ADRs", "/architecture", or "lint my repo against universal rules".
user-invocable: true
argument-hint: "audit [path] [--no-adr] [--non-interactive]"
target: generic
---

# /architecture

Audits a repository against tiered architectural principles and emits a JSON report. L1 universal rules (≤15) ship with the plugin; L2 adds stack-specific rules (TypeScript via dependency-cruiser, Python via ruff); L3 lets a project override severity, exempt files, or add rules at `<repo>/.pmos/architecture/principles.yaml`. Block-severity findings can be promoted to Architecture Decision Records (Nygard template); ADR writes are capped at 5 per run.

**Announce at start:** "Using /architecture to audit the repo against tiered principles."

The skill is read-mostly. It writes ADR files (under `<repo>/docs/adrs/`, capped at 5 per run) and a JSON report to stdout. It does NOT modify source code. The skill's own shape conforms to the generic skill-authoring conventions at `plugins/pmos-toolkit/skills/feature-sdlc/reference/skill-patterns.md §A–§F` (the standing acceptance criteria).

## Platform Adaptation

Reference tool names below are Claude Code. In other environments:

- **Codex / no `AskUserQuestion`:** the only interactive prompt is the optional ADR-promotion confirmation (Phase 5). On Codex, present a numbered free-form prompt with the same options. `--non-interactive` skips the prompt and defaults to "promote" for block-severity findings within the ADR cap.
- **No subagent / Task tool:** rule evaluation is fully sequential in v1 — no subagent dispatch. The skill works identically with or without a Task tool.
- **No Playwright / MCP:** unused by this skill.
- **TaskCreate / TodoWrite missing:** the skill body works without task tracking; the JSON report is the canonical artifact.
- **Non-interactive contract:** the audit emits the same JSON whether interactive or not; the ADR-promotion prompt is the only check point that defers under `--non-interactive`.

## Phase 0: Prerequisites

The audit harness shells out to `jq`, `python3` (with PyYAML), and optionally to `npx dependency-cruiser` (for TS/Vue) and `ruff` (for Python). Prerequisite gates:

1. **Required:** `jq`, `python3`. Missing → stderr `ERROR: /architecture requires <tool>. Install via brew/apt/dnf, then re-run.` and exit 64. (FR-30, P0 prereq gate.)
2. **Optional (graceful degrade):** `npx dependency-cruiser`, `ruff`. Missing → emit a `tools_errored[]` entry in the JSON report; the corresponding L2 rules are skipped for this run. The audit still succeeds; the report records the gap. (FR-32.)

If `jq` or `python3` is missing, the run halts; the report is NOT emitted (the report renderer itself uses `jq`).

## Phase 1: Resolve scan root

Parse the argument string:

- Positional `[path]` is the scan root. Default: `.` (cwd).
- `--no-adr` suppresses ADR writes entirely; findings still emit. (FR-67.)
- `--non-interactive` suppresses the ADR-promotion prompt; defaults to "promote within cap" for block-severity findings.

Resolve `~`/symlinks once (no recursive follow). The resolved absolute path is recorded in the JSON report under `config.scan_root`. Unknown flags → stderr usage line, exit 64.

## Phase 2: Load rules — 3-tier merge

Rule loading is delegated to the harness (`tools/run-audit.sh`); cite this phase, do not re-implement it. The loader:

1. **L1 + L2 (plugin-owned):** reads `plugins/pmos-toolkit/skills/architecture/principles.yaml` shipped with this plugin. The L1 set is capped at 15 rules (FR-21).
2. **Stack detection:** scans the resolved root for stack markers (`tsconfig.json`, `package.json`, `pyproject.toml`, `*.vue`); only matching L2 rules participate. (FR-22.)
3. **L3 (project-owned):** if `<scan_root>/.pmos/architecture/principles.yaml` exists, merge per-rule overrides + exemptions on top of the plugin set. L3 may override `severity` or add new rules; it may NOT raise an L1 universal rule's severity below `warn`. (FR-11, FR-13, FR-20.)

The full L1 rule list, rationales, and source citations live at [`reference/l1-rationales.md`](reference/l1-rationales.md) (progressive disclosure — FR-82). The gap-map rationale (why each rule delegates to grep / dep-cruiser / ruff) lives at [`reference/gap-map-rationale.md`](reference/gap-map-rationale.md).

## Phase 3: Scan files

The scanner walks the resolved root and enumerates files for rule evaluation:

- Honors `.gitignore` when the scan root is a git repo (uses `git check-ignore`). (FR-40.)
- Applies a hardcoded deny-list for paths that are universally noise: `node_modules/`, `.git/`, `dist/`, `build/`, `.next/`, `.venv/`, `__pycache__/`, `.pytest_cache/`. (FR-41, D15.)
- Filters by extension per the rule set's needs (`.ts`, `.tsx`, `.vue`, `.js`, `.jsx`, `.py`, plus a configurable extra). (FR-42, FR-43.)
- Records counts under `scanned.{total, by_ext, excluded_by_gitignore, excluded_by_fallback}` in the JSON report.

## Phase 4: Evaluate rules

Each loaded rule dispatches by `delegate_to`:

- **`grep`:** the harness's built-in evaluators (size/shape, debug/hygiene, security/safety) — see `tools/run-audit.sh` for the per-rule check expressions. These are the L1 universal rules (U001–U010).
- **`dependency-cruiser`:** shells out to `npx dependency-cruiser` with the plugin-owned `tools/.depcruise.cjs` config; parses the JSON output and surfaces findings against rules TS001–TS004. (FR-31.)
- **`ruff`:** shells out to `ruff check --format=json` against rules PY001–PY004. (Same shape — see FR-31.)

Findings are sorted by file path, then by line number, then by rule id (FR-73 — deterministic ordering).

Vue SFC coverage gap: dependency-cruiser does not parse `<script setup>` blocks. The harness counts `.vue` files in the scan and emits a `coverage_gaps[]` entry (`vue_sfc_unanalyzed`) when any are skipped — see FR-50/51/52. The user sees the gap; the audit does not silently misreport.

## Phase 5: Reconcile exemptions + ADR promotion

L3 may carry `exemptions:` rows that whitelist a `(rule, file)` pair, optionally with an `adr:` pointer and an `expires:` date.

1. **Matching exemptions** (an exemption row that matches an active finding): the finding is dropped from `findings[]` and surfaced under `exemptions_applied[]`.
2. **Orphan exemptions** (an exemption row that matches no active finding): surfaced under `exemptions_orphaned[]` (info-only — exemption can be retired).
3. **Expired exemptions** (`expires` date in the past): demoted — the finding re-emits and the row is logged under `exemptions_expired[]`.

ADR promotion (FR-60/61/62/63):

- Default: every `block`-severity finding without a matching exemption is a candidate. Capped at 5 ADRs written per run (`adrs_truncated[]` lists the dropped ones).
- ADRs are written to `<scan_root>/docs/adrs/NNNN-<slug>.md` using the Nygard template at [`reference/adr-template.md`](reference/adr-template.md). The `NNNN` is monotonic against the existing ADR directory.
- Atomic write: temp file + `rename(2)`. The skill NEVER overwrites an existing ADR file.
- `--no-adr` suppresses writes entirely.

In interactive mode, present a single `AskUserQuestion` summarising the candidates ("N block findings → write ADRs?") with options **Promote all (capped at 5) (Recommended)** / **Promote selected** / **Skip ADRs**. Under `--non-interactive`, default to "promote all (capped at 5)".

## Phase 6: Emit report

Stdout is the canonical artifact: a single JSON object with the shape locked in spec §FR-70/71/72/73. Top-level keys:

```
{
  "run": { "id, scan_root, started_at, finished_at, duration_ms" },
  "config": { "adr_path, scan_root, extra_ignore" },
  "rules": { "loaded, effective_severity, l3_overrides" },
  "scanned": { "total, by_ext, excluded_by_gitignore, excluded_by_fallback" },
  "findings": [ { "rule, severity, file, line?, message" } ],
  "exemptions_applied": [...],
  "exemptions_orphaned": [...],
  "exemptions_expired": [...],
  "adrs_written": [ { "rule, file, adr_path" } ],
  "adrs_truncated": [...],
  "coverage_gaps": [...],
  "tools_errored": [...]
}
```

Stderr carries a human summary: counts by severity, files scanned, ADRs written, tools errored. Findings are sorted (FR-73); the JSON is byte-identical across runs when source state is unchanged — see `tools/check-determinism.sh`.

## Anti-Patterns (DO NOT)

- Do NOT scan `node_modules/`, `.git/`, `dist/`, `build/`, `.venv/`, `__pycache__/` — the hardcoded deny-list excludes them; bypassing it floods the report.
- Do NOT promote a `warn`- or `info`-severity finding to an ADR. ADRs are reserved for `block`-severity findings only (FR-60).
- Do NOT delegate to a tool that is not on PATH — auto-skip and record in `tools_errored[]` (FR-32). Crashing the audit on a missing optional tool is the wrong default.
- Do NOT overwrite an existing ADR file. The atomic write uses a monotonic `NNNN`; if the target path exists, halt with an explicit error (FR-62).
- Do NOT emit text to stdout — stdout is JSON only. Human summary goes to stderr (FR-72).
- Do NOT raise an L1 universal rule's severity below `warn` via L3 override; L3 may relax severity but may not silently drop a universal rule (FR-11).
- Do NOT silently misreport Vue SFC coverage — every `.vue` file that dep-cruiser cannot analyse must surface under `coverage_gaps[]` (FR-50/51/52).
- Do NOT exceed the 5-ADR-per-run cap — overflow goes to `adrs_truncated[]`, not to disk (FR-63).
- Do NOT skip the exemption-reconciliation pass — orphan and expired exemptions are first-class report rows (FR-65/66).

## Tool version requirements

- `jq` ≥ 1.6 (required; report renderer)
- `python3` ≥ 3.8 with `pyyaml` (required; rule loader)
- `dependency-cruiser` ≥ 15 (optional; L2 TS rules)
- `ruff` ≥ 0.5 (optional; L2 Python rules)
- `git` ≥ 2.25 (required when scan root is a git repo; used for `.gitignore` honoring and blame queries)

## Reference

- [`reference/l1-rationales.md`](reference/l1-rationales.md) — full per-rule rationale + source citation for U001–U010.
- [`reference/adr-template.md`](reference/adr-template.md) — Nygard ADR template stamped on promotion.
- [`reference/gap-map-rationale.md`](reference/gap-map-rationale.md) — per-rule rationale for `delegate_to:` assignment.
