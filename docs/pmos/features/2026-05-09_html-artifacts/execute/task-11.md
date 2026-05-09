---
task_number: 11
task_name: "Index generator (index.html + _index.json)"
task_goal_hash: t11-index-generator
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
status: done
started_at: 2026-05-09T20:50:00Z
completed_at: 2026-05-09T20:54:00Z
files_touched:
  - plugins/pmos-toolkit/skills/_shared/html-authoring/index-generator.md
---

## T11 — index-generator algorithm

**Outcome:** done. 122-line algorithm document at `plugins/pmos-toolkit/skills/_shared/html-authoring/index-generator.md`. FR-20, FR-21, FR-22, FR-41, §9.0, §9.1 satisfied.

### Plan-order deviation (informational)

Plan document orders T11 *after* T8 (lines 721 vs 582), but T8 declares `Depends on: T1..T7, T11` while T11 declares `Depends on: T1, T2, T3` only. /execute dep-graph enforcement requires T11 before T8. Running in topological order: T7 ✅ → **T11 ✅** → T8 → T9/T10. Document-order is informational; the dep DAG is canonical.

### Sections

1. **Inputs** — feature_folder + glob set (top-level HTML, top-level legacy MD, externally-indexed nested dirs, flat date-stamped artifacts).
2. **Manifest construction** — per-entry field-source table (id, title, phase, path, format, sections_path, external_index). Title-extraction policy: skill in-memory `<h1>` is canonical at write time; cheap first-`<h1>` slice on re-glob.
3. **Ordering (§9.1)** — phase-rank table (00 Pipeline → ... → Legacy at rank 99), within-phase ascending Unicode codepoint order, deterministic NFR-07.
4. **Inlining into `index.html` (FR-41)** — `<script type="application/json" id="pmos-index">` block; explicit note that no on-disk `_index.json` file is written despite the spec's content-shape name (initial drafts had an on-disk file; FR-41 collapsed it to inline). Reader: `JSON.parse(document.getElementById('pmos-index').textContent)`.
5. **`index.html` template** — fills T1's `template.html` slots (title/asset_prefix/plugin_version/source_path/content); content slot describes the chrome (sidebar groups, iframe, JSON script). Wireframes W01 + W03 cited for sidebar shape and legacy-group placement.
6. **`schema_version` (§9.0)** — `1`; forward-compat read rules; additive-fields-no-bump policy.
7. **Wireframes / Prototype nesting** — single `external_index: true` entry per nested skill; viewer doesn't walk into nested folders at this level (FR-15).
8. **Idempotence + atomicity** — same inputs → byte-identical `index.html` (apart from `generated_at`); temp-write-then-rename per FR-10.2.

### Inline verification

All 4 plan-defined assertions pass:

```
test -f plugins/pmos-toolkit/skills/_shared/html-authoring/index-generator.md  → exit 0
grep -q "phase-rank"                                                            → match (heading + table)
grep -q "schema_version"                                                        → match (§4 + §6)
grep -q '<script type="application/json" id="pmos-index">'                      → match (§4 inline example)
```

### Decisions / deviations

- **Length:** 122 lines vs plan's "≈80 lines" target. Denser because §2's per-entry field table + §3's full phase-rank table land verbatim — no scope creep, just exhaustive rendering of FR-21/§9.1.
- **No on-disk `_index.json`.** Spec FR-41 prevailed — manifest inlined as `<script type="application/json">`. Documented this explicitly in §4 because the filename `_index.json` still appears in spec/plan text as the content-shape name, and a future reader could otherwise expect a sibling JSON file.
- **Title extraction.** Two-path: skill in-memory `<h1>` at write time (canonical), cheap first-`<h1>` slice on re-glob of pre-existing artifacts (no full HTML parser; OK because `<h1>` is the first heading per `template.html` lines 11-12).
- **Self-test (Step 2) deferred.** Plan Step 2 says "Self-test by manually running the algorithm on the THIS feature folder (after Phase 4 fixture exists in T15)." Phase 4 fixtures don't exist yet — self-test will run when T15 lands. Not blocking T11 done-criteria; Step 2 is "after Phase 4 fixture exists in T15" — explicitly future-conditional.

### Spec compliance

| FR / § | Requirement | Satisfied by |
|---|---|---|
| FR-20 | Index generator algorithm exists | This file |
| FR-21 | Sidebar nav built from `_index.json` (inline manifest) at viewer-load | §4 + §5 (viewer reads via `getElementById('pmos-index')`) |
| FR-22 | Legacy MD entries surfaced via FR-22 shim | §1 (legacy glob + sibling-html exclusion) + §3 phase rank 99 |
| FR-41 | NO `fetch()` of sibling JSON; inlined `<script type="application/json">` | §4 explicit |
| §9.0 | schema_version forward-compat | §6 |
| §9.1 | Phase-rank-then-ascending ordering, deterministic | §3 + NFR-07 cited |
| FR-15 | Wireframes/Prototype as single externally-indexed entry | §7 |

T8 runbook now has T11's algorithm available to cite. T15 + T17 will fixture-test the algorithm by running affected skills end-to-end.

