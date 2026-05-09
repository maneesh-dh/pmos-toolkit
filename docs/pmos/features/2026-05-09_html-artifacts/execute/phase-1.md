---
phase_number: 1
phase_name: "Shared substrate"
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
verify_status: passed
verify_evidence: "docs/pmos/features/2026-05-09_html-artifacts/verify/2026-05-09-phase-1/"
verify_review: "docs/pmos/features/2026-05-09_html-artifacts/verify/2026-05-09-phase-1/review.md"
phase_tasks: [T1, T2, T3, T4, T5, T6]
started_at: 2026-05-09T18:50:00Z
completed_at: 2026-05-09T20:35:00Z
---

## Phase 1 — Shared substrate

### Outcome

All 6 tasks complete and verified. `/verify --scope phase 1` passed with 4 review-gate fixes landed (path-traversal, fallback-banner CSS class mismatch, manifest.id honoring, slugify rename).

### Tasks

| Task | Commit | Status |
|---|---|---|
| T1 — Scaffold `_shared/html-authoring/` | `65ccedf` | done |
| T2 — `assets/style.css` | `267c164` (+ verify-pass rename) | done |
| T3 — `assets/viewer.js` | `d8d440f` (+ verify-pass fixes) | done |
| T4 — `assets/serve.js` | `2d7a87e` (+ verify-pass safeJoin fix) | done |
| T5 — Vendor turndown + GFM | `5cdea32` | done |
| T6 — `assets/html-to-md.js` | `554343f` | done |

### Verify-pass fixes landed

1. **serve.js path-traversal (CVE-grade for dev, conf 88).** `safeJoin` now requires `path.sep` boundary; URL-encoded `%2E%2E/sibling/secret` no longer escapes root. New regression suite at `tests/scripts/serve.test.js` (4 tests: literal `..`, URL-encoded `..`, prefix-confusion, MIME map).
2. **fallback-banner class mismatch (conf 90).** style.css renamed `.pmos-file-fallback-banner` → `.pmos-fallback-banner` (4 occurrences) to match what viewer.js emits and tests assert.
3. **manifest.id honoring (conf 80).** viewer.js helper renamed `slugify` → `artifactSlug`; now prefers explicit `entry.id` (per spec §9.1) before falling back to path-derived kebab. New JSDOM test asserts the precedence.
4. **slugify name collision (conf 75).** Helper rename + comment block clarifies it's for manifest-entry identity, NOT conventions.md §3 heading-id derivation.

### Test surface (Phase 1 — closed)

- `tests/scripts/viewer.test.js` — 4 JSDOM tests (file:// fallback, sessionStorage, legacy-md shim, artifactSlug).
- `tests/scripts/serve.test.js` — 4 Node http tests (literal-`..`, URL-encoded-`..`, prefix-confusion, MIME).
- Both bootstrap jsdom via `HTML_TO_MD_JSDOM_PATH` / `/tmp/pmos-jsdom-boot` escape hatch (mirrors T6).

### Open follow-ups (deferred to Phase 2/4)

- `html-to-md.js` `HTML_TO_MD_JSDOM_PATH` doc/comment alignment (cosmetic; both shapes work).
- `conventions.md` §12 vocabulary enumeration of `data-pmos-*` attrs (T7 owner).
- viewer.js test gap — toolbar Copy-MD path coverage (T17 sections-contract).

### Phase 2 entry-readiness

Substrate is ready. Phase 2 (T7–T11) consumes:
- `template.html` (slot-fill in skill writers)
- `conventions.md` (heading-id rule)
- `assets/{style.css, viewer.js, serve.js, turndown.umd.js, turndown-plugin-gfm.umd.js, html-to-md.js}` (copy into each `{feature_folder}/assets/` per FR-10)
- `assets/LICENSE.turndown.txt` (preserved alongside vendored bundles)
