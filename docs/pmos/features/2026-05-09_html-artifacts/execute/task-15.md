---
task_number: 15
task_name: "Build fixture feature folder"
task_goal_hash: t15-fixture-feature-folder
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
status: done
started_at: 2026-05-10T01:55:00Z
completed_at: 2026-05-10T02:05:00Z
files_touched:
  - tests/fixtures/repos/node/docs/pmos/features/2026-05-09_html-artifacts-fixture/01_requirements.html
  - tests/fixtures/repos/node/docs/pmos/features/2026-05-09_html-artifacts-fixture/01_requirements.sections.json
  - tests/fixtures/repos/node/docs/pmos/features/2026-05-09_html-artifacts-fixture/02_spec.html
  - tests/fixtures/repos/node/docs/pmos/features/2026-05-09_html-artifacts-fixture/02_spec.sections.json
  - tests/fixtures/repos/node/docs/pmos/features/2026-05-09_html-artifacts-fixture/03_legacy.md
  - tests/fixtures/repos/node/docs/pmos/features/2026-05-09_html-artifacts-fixture/index.html
  - tests/fixtures/repos/node/docs/pmos/features/2026-05-09_html-artifacts-fixture/_index.json
  - tests/fixtures/repos/node/docs/pmos/features/2026-05-09_html-artifacts-fixture/assets/style.css
  - tests/fixtures/repos/node/docs/pmos/features/2026-05-09_html-artifacts-fixture/assets/viewer.js
  - tests/fixtures/repos/node/docs/pmos/features/2026-05-09_html-artifacts-fixture/assets/serve.js
  - tests/fixtures/repos/node/docs/pmos/features/2026-05-09_html-artifacts-fixture/assets/turndown.umd.js
  - tests/fixtures/repos/node/docs/pmos/features/2026-05-09_html-artifacts-fixture/assets/turndown-plugin-gfm.umd.js
  - tests/fixtures/repos/node/docs/pmos/features/2026-05-09_html-artifacts-fixture/assets/html-to-md.js
  - tests/fixtures/repos/node/docs/pmos/features/2026-05-09_html-artifacts-fixture/grills/2026-05-09_test.html
  - tests/fixtures/repos/node/docs/pmos/features/2026-05-09_html-artifacts-fixture/grills/2026-05-09_test.sections.json
  - tests/fixtures/repos/node/docs/pmos/features/2026-05-09_html-artifacts-fixture/simulate-spec/2026-05-09-trace.html
  - tests/fixtures/repos/node/docs/pmos/features/2026-05-09_html-artifacts-fixture/simulate-spec/2026-05-09-trace.sections.json
  - tests/fixtures/repos/node/docs/pmos/features/2026-05-09_html-artifacts-fixture/verify/2026-05-09-report.html
  - tests/fixtures/repos/node/docs/pmos/features/2026-05-09_html-artifacts-fixture/verify/2026-05-09-report.sections.json
---

## T15 — fixture feature folder seed

**Outcome:** done. Realistic mixed-state fixture seeded at
`tests/fixtures/repos/node/docs/pmos/features/2026-05-09_html-artifacts-fixture/`.
Exercises happy-path HTML, legacy MD sibling, nested-folder asset paths,
and bidirectional cross-doc anchors.

### Inventory (19 files)

| Surface | Files | Purpose |
|---|---|---|
| Requirements artifact | `01_requirements.html` + `.sections.json` | 3 sections + 2 h3; cross-doc anchor → `02_spec.html#goals` |
| Spec artifact | `02_spec.html` + `.sections.json` | 4 sections + 1 h3; exercises `<table>`, `<dl>`, `<pre><code>`; cross-doc anchor → `01_requirements.html#goals` |
| Legacy MD | `03_legacy.md` | Plain MD sibling — exercises resolver mixed-state path |
| Index | `index.html` + `_index.json` | 5 entries in canonical order |
| Assets | `assets/{style.css,viewer.js,serve.js,turndown.umd.js,turndown-plugin-gfm.umd.js,html-to-md.js}` | Copied byte-identical from `_shared/html-authoring/assets/` |
| Nested grill | `grills/2026-05-09_test.html` + `.sections.json` | Doubly-nested asset path `../assets/`; cross-doc → `../01_requirements.html#goals` |
| Nested simulate | `simulate-spec/2026-05-09-trace.html` + `.sections.json` | Same pattern; cross-doc → `../02_spec.html#fr-table` |
| Nested verify | `verify/2026-05-09-report.html` + `.sections.json` | Same pattern (no cross-doc anchor — keeps fixture realistic) |

### Inline verification (Phase-4-T15 plan checks)

```
$ find FIXTURE -name "*.html" | wc -l
6   ✅ (plan target: ≥6)

$ find FIXTURE -name "*.sections.json" | wc -l
5   ✅ (plan target: ≥3)

$ test -f FIXTURE/03_legacy.md
✅

$ test -f FIXTURE/_index.json
✅
```

### Holistic checks (forward-deps satisfied)

```
$ for html in fixture/*.html; do
    bad=$(awk '/<h[23][[:space:]>]/' "$html" | grep -vE 'id=' | wc -l)
    echo "$html bad=$bad"
  done
0/5 HTMLs have heading without id   ✅ (T22 will enforce)

$ cross-doc anchor walk → 4/4 hrefs resolve to a real id in target sections.json   ✅ (T23 will enforce)
```

### Spec compliance

| FR / Goal | Requirement | Satisfied by |
|---|---|---|
| §14.1 | Realistic mixed-state fixture | 19 files spanning 6 HTML + 1 legacy MD + 5 sections.json + 6 assets + 1 _index.json |
| §14.2 | Test fixtures usable by per-skill harnesses | Fixture root is canonical input for T16-T23 assert scripts |
| FR-03.1 | Heading-id contract | All h2/h3 carry kebab-case ids (sanity-checked) |
| FR-92 | Cross-doc anchor resolution | 4 anchors all resolve (sanity-checked) |
| FR-10.1 | Doubly-nested asset paths | grills/, simulate-spec/, verify/ all reference `../assets/` |
| Decision Log P5 | Single canonical fixture for all per-skill assert scripts | this fixture, consumed by T16-T23 |

### Forward-dependencies

- **T16** (resolve-input): consumes a copy + 4 sub-fixtures (only-md/only-html/both/neither).
- **T17** (sections-contract): consumes this fixture root.
- **T22** (heading-ids): consumes this fixture root; sanity-checked above.
- **T23** (cross-doc anchors): consumes this fixture root; sanity-checked above.

T15 complete. Next: T16 (assert_resolve_input.sh).
