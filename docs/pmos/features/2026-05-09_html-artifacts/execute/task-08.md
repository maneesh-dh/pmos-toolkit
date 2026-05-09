---
task_number: 8
task_name: "Author per-skill HTML-rewrite runbook + apply to /requirements as self-test [pilot]"
task_goal_hash: t8-runbook-pilot
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
status: done
started_at: 2026-05-09T21:00:00Z
completed_at: 2026-05-09T21:15:00Z
files_touched:
  - docs/pmos/features/2026-05-09_html-artifacts/per-skill-rewrite-runbook.md
  - docs/pmos/features/2026-05-09_html-artifacts/wireframes/01_index-default_desktop-web.html
  - plugins/pmos-toolkit/skills/requirements/SKILL.md
---

## T8 — per-skill HTML-rewrite runbook + /requirements pilot + W01 ⌘K removal

**Outcome:** done. All 8 plan steps executed (Step 3 via inline pilot per user direction). Runbook authored at `per-skill-rewrite-runbook.md`; runbook §§2-6 applied to `/requirements/SKILL.md` (7 Edit operations, slightly above the plan's `~6` estimate due to one cleanup-on-prose pass); W01 ⌘K affordance removed (FR-27); per-skill edge-cases section populated with 6 entries.

### Steps executed

| Step | Status | Evidence |
|---|---|---|
| 1. Author runbook | ✅ | `per-skill-rewrite-runbook.md`, 8 main sections + per-skill edge-cases appendix + idempotence note |
| 2. Apply runbook to /requirements | ✅ | 7 Edits: argument-hint, Phase 0 addendum, Phase 1 step 3 resolver+drift, Phase 4 write phase, Templates heading-id paragraph, 3 residual-MD fixes (lines 162/246/692/19), 1 substrate-glob refinement post-pilot |
| 3. Pilot run on scratch fixture | ✅ (inline pilot) | `/tmp/pmos-pilot/2026-05-09_pilot/` exercised: 8/8 fidelity gates PASS (HTML primary, sections.json, asset copy of 7 files, index.html with inlined `<script type="application/json" id="pmos-index">`, no on-disk `_index.json`, no MD primary in default `output_format=html`, 0 missing heading IDs, schemas parse). Pilot folder cleaned post-verification. |
| 4. T20 inline-substitute grep | ✅ | `grep -nE '01_requirements\.md\b' SKILL.md` filtered against legacy/sidecar/resolver/format-both/html-to-md exclusions returns zero matches |
| 5. Refine runbook based on pilot edge cases | ✅ | One refinement: §3 asset-copy switched from enumerated file list to `assets/*` glob (avoids drift when substrate gains files). Same change mirrored in `/requirements/SKILL.md`. |
| 6. W01 ⌘K removal (FR-27, F1 fix) | ✅ | `grep -cE "⌘K\|cmd.*k\|ctrl.*k" wireframes/01_index-default_desktop-web.html` → 0 |
| 7. Per-skill edge cases section | ✅ | 6 rows: /wireframes+/prototype skip, /simulate-spec spec-patches-via-Edit unchanged (F3 fix), /feature-sdlc no-sections.json, /artifact carve-out, wireframe ⌘K caveat, /grill argument-derived phase |
| 8. Commit | ✅ (this commit) | T8 trailer in subject |

### Decisions / deviations

- **Step 3 dispatched as inline pilot, not subagent.** Plan says "running `/pmos-toolkit:requirements --feature html-artifacts-fixture-pilot` on a small fixture". User-confirmed lightweight inline pilot — manually walked the runbook on `/tmp/pmos-pilot/2026-05-09_pilot/` using direct tool calls (Write, Bash cp, Bash node-parse). Validated: substrate copy (7 files), HTML primary atomic write, sections.json companion, index.html regen with inlined manifest, FR-41 (no on-disk `_index.json`), FR-12 default html (no MD primary), FR-03.1 (0 missing h2/h3 ids), schema sanity (sections.json schema_version=1; manifest schema_version=1). Real subagent dispatch deferred to T15 + T18 fixture runs which exercise /requirements end-to-end on the canonical fixture.
- **Phase 0 addendum lives outside `<!-- pipeline-setup-block -->`.** The pipeline-setup-block region is auto-managed; per-skill edits inside would be clobbered on a future re-inline. Runbook §2 documents this placement decision (between block-end and `<!-- non-interactive-block:start -->`) so T9 fanout follows the same pattern.
- **Forward-dep on T20 (`tests/scripts/assert_no_md_to_html.sh`) substituted with inline `grep -nE` filtered against canonical excepts.** Inline gate passed on /requirements; T20 will replace this inline grep with the canonical script in Phase 4.
- **Forward-dep on T22 (`assert_heading_ids.sh`) substituted with inline `grep -oE "<h[23][^>]*>" | grep -v 'id='`.** Returned 0 missing IDs on pilot HTML.
- **Runbook length:** ~178 lines vs plan's "≈150-200 lines" target. Within scope.
- **/requirements is the first-stage skill** so runbook §5 (resolver for upstream reads) is a no-op for the pilot. The §5 contract still applied: Phase 1 step 3 (existing-doc check) was rewritten to use the resolver pattern even though there's no upstream artifact, since /requirements may be invoked on a folder containing a prior-run `01_requirements.{html,md}` and needs format-aware lookup.
- **3 residual `01_requirements.md` mentions** at lines 162, 246, 692 (input-mode taxonomy, update-path entry, defensive-write rule) updated to `01_requirements.{html,md}` shape. One prose mention at line 19 ("acid test (b): write `02_spec.md` from this") updated similarly.

### Spec compliance

| FR | Requirement | Satisfied by |
|---|---|---|
| FR-10 | Substrate copied to feature folder | Pilot copy of 7 substrate files; runbook §3 glob pattern |
| FR-10.1 | Asset prefix per-folder relative | Runbook §3 + /requirements Phase 4 |
| FR-10.2 | Atomic write via temp+rename | Runbook §3 explicit |
| FR-10.3 | Cache-bust `?v=<plugin-version>` | Pilot HTML + runbook §3 |
| FR-12 | output_format settings/flag honoured | Phase 0 addendum (`output_format` resolution) |
| FR-12.1 | `both` mode emits MD sidecar | Phase 4 write-phase Mixed-format paragraph |
| FR-13 | Snapshot-commit preserved | Phase 4 Pre-write safety + runbook §6 |
| FR-14 | Re-runs idempotent | Runbook idempotence note + cp -n / rsync --update |
| FR-15 | Wireframes/prototype unmodified | Runbook §"Per-skill edge cases" row 1 (explicit exclusion); /requirements not a wireframe skill |
| FR-22 | Index regen after each write | Runbook §3 + cites `index-generator.md` (T11) |
| FR-27 | W01 ⌘K removed | Removed; grep returns 0 |
| FR-33 | No bypassing the resolver | Runbook §5 + Phase 1 step 3 + DO-NOT line in /requirements |
| FR-41 | No on-disk `_index.json`; manifest inlined | Pilot index.html has inlined script; no `_index.json` written |
| FR-71 | Substrate-version visibility | Cache-bust `?v=2.32.0` in pilot |
| FR-90 | Stable IDs across regenerations | Runbook §4 cites `_shared/html-authoring/conventions.md` §3 algorithm |
| FR-03.1 | Heading IDs on h2/h3 | Pilot HTML: 0 missing; runbook §4 + /requirements Templates note |
| FR-105 | TDD: prose-edit task, no behavior tests | Plan correctly tagged `TDD: no`; verification is inline grep + pilot fidelity gates |

### Forward-dependencies handled

- **T20 (`assert_no_md_to_html.sh`):** runbook §7 explicitly notes inline-grep substitute until T20 lands; T20 implementer will replace the inline grep with the script.
- **T22 (`assert_heading_ids.sh`):** runbook §4 cites it; pilot used inline grep substitute.
- **T11 (`index-generator.md`):** already complete; runbook §3 cites it.
- **T15 / T18 (fixture runs):** real /requirements end-to-end run deferred there.

### Inline verification (plan-defined)

```
test -f docs/pmos/features/2026-05-09_html-artifacts/per-skill-rewrite-runbook.md      → exit 0
grep -c "⌘K|cmd.*k|ctrl.*k" wireframes/01_index-default_desktop-web.html               → 0  (FR-27)
grep -c "Per-skill edge cases" per-skill-rewrite-runbook.md                            → ≥1 (F3)
Pilot run wrote expected files (step 3)                                                → 8/8 fidelity gates PASS
[T20 substitute] grep '01_requirements.md\b' /requirements/SKILL.md (filtered)         → 0 residual matches
grep -c "01_requirements.html" /requirements/SKILL.md                                  → 6 (≥1)
grep -c "01_requirements.md\b" outside legacy/sidecar/resolver/format-both/html-to-md  → 0
```

T9 fanout (apply runbook to 9 remaining SKILL.md files) is now unblocked.
