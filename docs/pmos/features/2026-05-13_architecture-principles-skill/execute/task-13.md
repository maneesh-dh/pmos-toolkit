---
task_number: 13
task_name: "ADR write — Nygard template, monotonic NNNN, atomic write"
task_goal_hash: "sha256:t13-adr-write-nygard-monotonic-atomic"
plan_path: "docs/pmos/features/2026-05-13_architecture-principles-skill/03_plan.html"
branch: "feat/architecture-principles-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-architecture-principles-skill"
status: done
started_at: 2026-05-13T15:35:00Z
completed_at: 2026-05-13T15:50:00Z
files_touched:
  - plugins/pmos-toolkit/skills/architecture/tools/run-audit.sh
  - plugins/pmos-toolkit/skills/architecture/reference/adr-template.md
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/adr-write/src/secret.ts
  - .gitignore
---

## Summary

ADR write lands (FR-60/61/62). For each block-severity finding (post
`effective_severity` rewrite), the audit stamps a Nygard ADR at
`<scan-root>/<adr_path>/ADR-NNNN-<kebab-title>.md`:

- **Path:** `adr_path` from `LOADER_JSON.config.adr_path` (default
  `docs/adr/`, overridable via project `principles.yaml`).
- **Numbering:** scan the dir for the highest `ADR-NNNN-*.md`, start at
  `max+1`; monotonic across runs, never recycled (FR-61).
- **Atomic write:** `printf … > .tmp-$$-<NNNN>` then `mv` (FR-62).
- **Body:** rendered from `reference/adr-template.md` via bash
  `${var//{NNNN}/...}` substitution — covers `{NNNN, title, date,
  rule_id, severity, file, line}`.
- **JSON:** `adrs_written[]` array of
  `{nnnn, path, rule_id, file, title}` objects emitted at the top
  level alongside `findings`.

No cap yet — T14 adds the 5/run ceiling + `--no-adr`. T15 wires
exemption reconciliation against the `## Suppresses` block.

## TDD red → green

- **Red:** Pre-T13 audit emits block findings but never writes ADRs;
  the report has no `adrs_written` field.
- **Green:**
  - `bash tools/run-audit.sh tests/fixtures/adr-write` writes
    `docs/adr/ADR-0001-hardcoded-credential-api-key-pattern-detected.md`;
    JSON `.adrs_written | length == 1`; body contains `**Status:**
    Proposed` and `## Suppresses`.
  - Re-running the same audit yields ADR-0002 (monotonic; ADR-0001
    untouched).

## Runtime evidence (1 primary + 10 regressions + 6 side-effect = 17/17 PASS)

| # | Test | Result |
|---|------|--------|
| 1 | **Primary** — `adr-write/` writes ADR-0001 with `**Status:** Proposed` + `## Suppresses` block; `.adrs_written | length == 1`, `nnnn == "0001"` | PASS |
| 2 | Monotonic: 2nd run on the same fixture yields ADR-0002 | PASS |
| 3 | `tracer/`: `["U004","U007"]`, no ADRs (no block) | PASS |
| 4 | `l1-size/`: `["U001","U002","U003","U006","U007"]`, no ADRs | PASS |
| 5 | `l1-hygiene/`: `["U004","U005","U007","U008"]`, no ADRs | PASS |
| 6 | `l1-security/`: `["U009","U010"]`, 2 ADRs written (sweep cleans) | PASS |
| 7 | `l3-override/`: `["U004","U007"]`, no ADRs | PASS |
| 8 | `gitignore-deny/`: scanned=1, findings=[], no ADRs | PASS |
| 9 | `ts-circular/`: `["TS001"]`, 1 ADR written | PASS |
| 10 | `py-tidy-imports/`: `["PY001","PY004"]`, 1 ADR for PY004 (block) | PASS |
| 11 | `tool-missing/`: tools_skipped contract intact, no ADRs | PASS |
| 12 | `vue-mixed/`: `frontend_declarative_coverage == 0.70`, no ADRs | PASS |
| 13–17 | Side-effect sweep on tracer/l1-size/l1-hygiene/l3-override/gitignore-deny/vue-mixed: no `docs/adr/` created (zero block findings ⇒ zero writes) | PASS |

## Decisions / deviations

- **Bash-string substitution, not `sed`.** Findings carry messages and
  file paths that may contain `/`, `:`, or `|` — any `sed` delimiter
  becomes a footgun. `${body//\{NNNN\}/$nnnn}` is bash 3.2-safe and
  delimiter-agnostic.

- **Monotonic scan picks `max(NNNN) + 1` from `ls`, then runs a
  collision-guard loop.** FR-61 says scan-on-write picks `+1`; the
  inner `while [ -e "$target" ]` loop is a same-run guard for the
  pathological case where two block findings produce the same
  `title_slug` (e.g., two U009 hits in different files). Without it,
  same-run NNNN would still be unique because we increment before each
  write — but the `[ -e ]` check protects against pre-occupied numbers
  the scan missed (e.g., `ADR-0003` exists with an unusual suffix that
  didn't match the `ADR-[0-9]{4}-*.md` glob).

- **Title slug derived from `message`, not `rule_id`.** A human reading
  the ADR list wants `ADR-0001-hardcoded-credential-api-key-pattern-detected`,
  not `ADR-0001-u009`. Spec D19 supports a human-readable slug; plan §T13
  step 3 says exactly `echo "$message" | tr ... | sed ...`. Truncated to
  60 chars per plan.

- **Fallback slug for empty messages.** If a finding has no message
  (defensive — shouldn't happen with current rules), fall back to
  `<rule_id_lower>-finding`. Keeps the path well-formed.

- **`adrs_written[]` entries are objects, not bare paths.** Spec
  doesn't lock the shape; emitting `{nnnn, path, rule_id, file, title}`
  lets T15 reconcile against exemptions without re-parsing filenames.

- **No cap (T14's job).** A fixture with 12 block findings would write
  12 ADRs here. T14 enforces 5/run and emits `adrs_truncated[]`.

- **Fixture-side `docs/adr/` is gitignored.** Block-finding fixtures
  (`l1-security`, `ts-circular`, `py-tidy-imports`, `adr-write`) write
  ADRs as a side effect of every audit run. Committing those would
  pollute git diffs on every regression. Added the gitignore line
  `plugins/pmos-toolkit/skills/architecture/tests/fixtures/*/docs/` —
  the fixture-runner skill (T20) cleans them between runs anyway, but
  this is the safety net.

- **The audit's `mkdir -p "$ADR_DIR"` is unconditional once a block
  finding exists.** No prompt, no `--write-adr` flag at v1 — block
  findings ARE the trigger. T14's `--no-adr` is the only opt-out.

## Verification outcome

PASS. Plan §T13 byte-for-byte:
- `ls tests/fixtures/adr-write/docs/adr/ADR-0001-*.md` exits 0.
- ADR body contains `**Status:** Proposed` and `## Suppresses`.
- Monotonic re-run produces `ADR-0002`.

All 10 regressions green; the 6-fixture side-effect sweep confirms
zero ADR writes when there are no block findings. T13 sealed; cursor
advances to T14 (ADR cap + `--no-adr`).
