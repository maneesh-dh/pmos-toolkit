---
task_number: 15
task_name: "Exemption reconciliation — matching/orphan/informational + expiry"
task_goal_hash: "sha256:t15-exemption-reconcile-fr65-fr66-e10-e11"
plan_path: "docs/pmos/features/2026-05-13_architecture-principles-skill/03_plan.html"
branch: "feat/architecture-principles-skill"
worktree_path: "/Users/maneeshdhabria/Desktop/Projects/agent-skills-architecture-principles-skill"
status: done
started_at: 2026-05-13T16:25:00Z
completed_at: 2026-05-13T16:40:00Z
files_touched:
  - plugins/pmos-toolkit/skills/architecture/tools/run-audit.sh
  - plugins/pmos-toolkit/skills/architecture/tests/fixtures/adr-reconcile/{matching,orphan,informational,expired}/
---

## Summary

Reconciliation lands (FR-65/66 + E10/E11). After findings are built and
BEFORE ADR write, an inline python3 block:

1. Scans `<scan-root>/<adr_path>/` for `ADR-NNNN-*.md` files and parses each
   trailing `## Suppresses` block via regex into
   `[{rule, file, line}, …]`.
2. Walks each exemption row from project `principles.yaml`:
   - `expires:` in the past (FR-66) → `status=expired`, finding surfaces,
     counted into `.exemptions.expired`; stderr summary emits
     `note: <N> exemption(s) expired; suppression lifted. Re-affirm via ADR
     or remove the row.`
   - matched ADR Suppresses entry → `status=applied`, finding suppressed
     silently.
   - exemption row but no matching ADR (or ADR missing the Suppresses entry)
     → `status=orphan`; finding STILL suppressed (user-explicit intent per
     FR-65); stderr warn `warn: orphan exemption: <rid> <file>:<line> (no
     matching ADR at …)`; counted into `.exemptions.orphan`.
3. Informational ADRs (Suppresses entry with no matching non-expired
   exemption row) → finding surfaces; `.exemptions.informational[]` carries
   `"ADR-NNNN documents suppression but no exemption row in
   principles.yaml"`.

Schema shift: `.exemptions` becomes the summary object
`{applied, orphan, expired, informational[], rows[]}` (per plan §T15 step 6
and FR-65 wording). Each row carries its raw fields plus the resolved
`status`. T4's `exemption-row` regression now asserts on
`.exemptions.rows[0]` instead of `.exemptions[0]` (the raw passthrough is
preserved inside `rows`).

Reconcile runs BEFORE ADR write so already-exempted block findings don't
spawn new ADRs (matching: silently suppressed, no ADR write; orphan: silently
suppressed, no ADR write; informational: surfaces, ADR writer treats as
normal block finding; expired: surfaces, ADR writer treats as normal block
finding).

Also fixed: PyYAML auto-coerces unquoted ISO dates (`expires: 2025-01-01`)
to `datetime.date` objects, which `json.dumps` refuses. Loader now
stringifies any `datetime.date`/`datetime.datetime` inside the exemption
tree so the JSON pipeline stays string-typed regardless of YAML quoting.
The expired fixture quotes the date defensively too.

## TDD red → green

- **Red:** Pre-T15 audit on `adr-reconcile/matching` emits the U009 finding
  even though the exemption row + ADR `## Suppresses` block claim to mute
  it; `.exemptions` is the raw row array, not a summary object.
- **Green:**
  - `matching/` → `.findings == []`, `.exemptions.applied == 1`.
  - `orphan/` → `.findings == []`, `.exemptions.orphan == 1`, stderr warn.
  - `informational/` → 1 U009 finding surfaces, `.exemptions.informational
    | length == 1`.
  - `expired/` → 1 U009 finding surfaces, `.exemptions.expired == 1`, stderr
    note.

## Runtime evidence (4 primary + 13 regressions = 17/17 PASS)

| # | Test | Result |
|---|------|--------|
| 1 | **matching** — `.findings == []`, `.exemptions.applied == 1`, no stderr | PASS |
| 2 | **orphan** — `.findings == []`, `.exemptions.orphan == 1`, stderr warn `warn: orphan exemption: U009 src/a.ts:2 …` | PASS |
| 3 | **informational** — `.findings | length == 1`, `.exemptions.informational[0]` exact text, ADR-0001 named | PASS |
| 4 | **expired** — `.findings | length == 1`, `.exemptions.expired == 1`, stderr note `note: 1 exemption(s) expired; suppression lifted. …` | PASS |
| 5 | `tracer/` — `["U004","U007"]` | PASS |
| 6 | `exemption-row/` (T4 reshape) — `.exemptions.rows | length == 1`, `rows[0].rule == "U004"` | PASS |
| 7 | `l1-size/` — `["U001","U002","U003","U006","U007"]` | PASS |
| 8 | `l1-hygiene/` — `["U004","U005","U007","U008"]` | PASS |
| 9 | `l1-security/` — `["U009","U010"]` | PASS |
| 10 | `l3-override/` — `["U004","U007"]` | PASS |
| 11 | `gitignore-deny/` — scanned=1, findings=[] | PASS |
| 12 | `ts-circular/` — `["TS001"]` | PASS |
| 13 | `py-tidy-imports/` — `["PY001","PY004"]` | PASS |
| 14 | `tool-missing/` — tools_skipped contract intact | PASS |
| 15 | `vue-mixed/` — `frontend_declarative_coverage == 0.70` | PASS |
| 16 | `adr-write/` (T13) — 1 ADR written, exemption summary empty | PASS |
| 17 | `adr-cap/` (T14, writes enabled) — 5 written, 7 truncated, stderr cap note byte-exact | PASS |

## Decisions / deviations

- **Reconcile runs BEFORE ADR write.** FR-65 says "at end of finding-
  collection, before report emission" — the ADR write is part of report
  emission and shouldn't auto-spawn ADRs for findings that the operator
  already explicitly muted. Running reconcile first keeps the audit
  idempotent: an exempted finding doesn't keep stamping new ADRs on every
  run.

- **`.exemptions` reshape (`array → object`) is intentional T4 breakage.**
  Plan §T15 step 6 mandates the new shape. T4's `exemption-row` regression
  was implicitly asserting on the raw array; the runtime regression list
  here asserts on `.exemptions.rows[0]` to compensate. The raw row data is
  preserved inside `rows[]` (with an added `status` field) — no information
  is lost.

- **Orphan path still suppresses the finding.** FR-65 wording is explicit:
  "orphan exemption (…): suppression still applied (user-explicit intent),
  BUT report carries warn-level entry". An exemption row IS the operator's
  decision to mute; the missing ADR is a documentation gap, not a mute
  revocation. The warn surfaces that gap.

- **Informational ADRs DO NOT suppress.** Symmetric to orphan: an ADR alone
  is not authorisation. The principles.yaml row is what mutes; an
  uncoupled `## Suppresses` block in an ADR is documentation. FR-65 spells
  this out.

- **Expiry classified BEFORE matching.** An expired row that happens to
  have a valid ADR is still treated as expired — the date wins. FR-66 is
  about lifting suppression after a deadline; the ADR remains as a
  historical record but doesn't gate suppression.

- **Date coercion in loader, not reconcile.** PyYAML's auto-date-parse is
  a footgun: `expires: 2025-01-01` produces a `date` object that survives
  through the LOADER_JSON serialisation only if we stringify in the loader.
  Adding a `_stringify_dates` walker there guarantees every JSON consumer
  downstream (jq, the reconcile python block, the final emit) sees strings,
  regardless of whether the operator quotes the date in YAML.

- **Stderr warn for orphan named the searched glob, not just the path.**
  Operators debugging a typo'd `adr: ADR-0042` need to see the exact glob
  the audit looked for, so the message ends `(no matching ADR at
  <adr_dir>/ADR-0042-*.md)`. Saves a round-trip to read principles.yaml.

- **Suppress match honours optional `line:`.** If an exemption row omits
  `line:`, any finding with matching `{rule, file}` is suppressed
  regardless of line — the operator's intent is "this file's instance of
  this rule, wherever it lives". When `line:` is present, exact line is
  required. Mirrors FR-65's `{rule, file, line?}` notation.

- **Pre-seeded ADRs live at fixture depth 3** (`adr-reconcile/<case>/docs/
  adr/ADR-*.md`). The existing `.gitignore` line `fixtures/*/docs/` only
  matches depth-2 paths — these depth-3 paths slip through naturally, so
  the seeded files commit cleanly without gitignore acrobatics. Regression
  runs use `--no-adr` to prevent runtime ADR writes from polluting these
  committed fixture trees.

- **No `.findings[].suppressed_by` populated yet.** Plan §T15 step 6
  mentions it but the orphan/applied paths drop the finding entirely from
  `.findings` (silent suppression per FR-65 wording). Carrying a
  `suppressed_by` link would require keeping the finding in `.findings`
  with a flag — a different schema decision deferred to T16's report-emit
  pass where shape is being finalised anyway.

## Verification outcome

PASS. Plan §T15 byte-for-byte:
- Matching fixture: `jq -e '.findings == [] and .exemptions.applied == 1'`
  exits 0.
- Orphan fixture: `jq -e '.findings == [] and .exemptions.orphan == 1'`
  exits 0; stderr contains the orphan warn line.
- Informational fixture: `jq -e '(.findings | length) == 1 and
  (.exemptions.informational | length) == 1'` exits 0.
- Expired fixture: `jq -e '(.findings | length) == 1 and
  .exemptions.expired == 1'` exits 0; stderr contains the expired note.

All 13 prior-task regressions green (including T4's reshape-adjusted
assertion and T14's cap-note byte-exact stderr). T15 sealed; cursor advances
to T16 (report emitter — JSON shape lock + stderr summary + determinism).
