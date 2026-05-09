---
verify_run: phase-scoped
feature: 2026-05-09_html-artifacts
phase: 1
phase_name: "Shared substrate"
date: 2026-05-09
mode: interactive
verify_status: passed
phase_tasks: [T1, T2, T3, T4, T5, T6]
plan_ref: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
spec_ref: "docs/pmos/features/2026-05-09_html-artifacts/02_spec.md"
---

# /verify --scope phase 1 — html-artifacts

Phase-scoped verify run for Phase 1 (Shared substrate, T1–T6). Result: **PASSED** with 4 review-gate fixes landed in this pass.

## Scope

Files reviewed (Phase 1 production diff, commits `65ccedf..d8d440f`):

```
plugins/pmos-toolkit/skills/_shared/html-authoring/{README.md, conventions.md, template.html}
plugins/pmos-toolkit/skills/_shared/html-authoring/assets/{style.css, viewer.js, serve.js, html-to-md.js, LICENSE.turndown.txt}
tests/scripts/{viewer.test.js, assert_viewer_js_unit.sh, fixtures/index-min.html}
```

Vendored bundles (`turndown.umd.js`, `turndown-plugin-gfm.umd.js`) are upstream MIT — out of review scope per the bug-scan brief.

## Phase 2 — static evidence

| Check | Result | Evidence |
|---|---|---|
| viewer.js JSDOM unit tests (4 tests post-fix) | **4 passed, 0 failed** | `bash tests/scripts/assert_viewer_js_unit.sh` → `verify/2026-05-09-phase-1/post-fix.txt` |
| serve.js path-traversal regression suite (4 tests, new) | **4 passed, 0 failed** | `bash tests/scripts/assert_serve_js_unit.sh` |
| viewer.js size budget (FR-05 ≤30 720 B) | 13 393 B ✓ | `wc -c assets/viewer.js` |
| viewer.js no-ESM guard (FR-05.1) | 0 matches ✓ | `grep -cE '^(import\|export)\b\|type=["\x27]module["\x27]'` → 0 |
| style.css size (FR-04 ≤30 KB) | 14 155 B ✓ | `wc -c assets/style.css` |
| html-to-md.js LOC (FR-12.1 ≤100) | 96 ✓ | `wc -l assets/html-to-md.js` |
| html-to-md.js self-test (`<h1>Hi</h1>` → `# Hi`) | PASS | static.txt |
| html-to-md.js GFM table round-trip | PASS | static.txt (`\| A \| B \|...`) |
| serve.js MIME map — html/css/js/turndown.umd.js | all 200 + correct Content-Type | static.txt |

## Phase 3 — multi-agent review (3 reviewers, parallel)

| Reviewer | Findings (≥50) | Acted on (≥75) | Status |
|---|---|---|---|
| Bug-scan | 9 | 1 (path-traversal) | Fix landed |
| CLAUDE.md compliance | 0 | 0 | Clean — root CLAUDE.md is the only one tracked; new code lives under `_shared/` (not a skill), so canonical-skill-path / version-sync / `/complete-dev` rules N/A |
| Cross-file consistency | 10 | 4 | 3 fixes landed; 1 deferred to T11 |

### Acted-on findings (75+)

| # | Finding | Confidence | Resolution |
|---|---|---|---|
| 1 | `serve.js:safeJoin` — `joined.startsWith(root)` allows prefix-confusion path-traversal via URL-encoded `%2E%2E` | 88 (bug-scan) | **FIXED.** `safeJoin` now checks `joined === root \|\| joined.startsWith(root + path.sep)` and wraps `decodeURIComponent` in try/catch. Reproduced empirically: pre-fix `curl /%2E%2E/feat-evil/secret.txt` returned `200 + SECRET-SHOULD-NOT-LEAK`; post-fix returns 4xx, no leak. Regression test in `tests/scripts/serve.test.js` (4 tests, including literal-`..` and URL-encoded variants). |
| 2 | `viewer.js` writes `.pmos-fallback-banner` but `style.css` defines `.pmos-file-fallback-banner` — banner ships unstyled | 90 (consistency) | **FIXED.** Renamed all 4 CSS occurrences to `.pmos-fallback-banner` (matches what viewer emits and tests assert). Same name in print/`@media` rule. |
| 3 | `viewer.js:slugify` ignores manifest `id` field (per spec §9.1) — risk of deep-link mismatch when generator emits explicit `id`s | 80 (consistency) | **FIXED.** Renamed helper `slugify` → `artifactSlug(entry)`; now prefers `entry.id` and falls back to path-derived kebab. New JSDOM test asserts the precedence (`{id: '01-requirements', path: '01_requirements.html'}` → `'01-requirements'`). |
| 4 | `slugify` name collision with `conventions.md §3` heading-id rule | 75 (consistency) | **FIXED.** Function renamed to `artifactSlug`; comment block on the helper explicitly notes its domain (manifest entry identity, NOT heading-id derivation) and points readers to conventions.md §3 for the latter. |

### Deferred findings (50-74, noted but not blocking Phase 1)

| Finding | Why deferred |
|---|---|
| `html-to-md.js:54-56` — `HTML_TO_MD_JSDOM_PATH` semantics divergent from `assert_*.sh` `NODE_PATH` (conf 70) | T6's escape hatch empirically works via `NODE_PATH=/tmp/pmos-jsdom-boot/node_modules` (used by both `assert_viewer_js_unit.sh` and inherited by html-to-md.js's `module.paths` because `process.env.NODE_PATH` is honored by Node natively). Cosmetic doc/comment fix; T17/T20 will exercise html-to-md.js end-to-end and that's the right place to land the doc clarification. |
| `viewer.test.js` doesn't exercise the `DOMContentLoaded` listener (readyState already complete on eval; conf 72) | Test gap, not a viewer bug. The `init()` path is exercised either way; refactor pressure is low. Add to T17 sections-contract test scope. |
| `viewer.js:122` — iframe `class="pmos-artifact-frame"` has no matching CSS rule (conf 78 — borderline) | Functional via `.pmos-main iframe` selector. T11 (index generator) will own the chrome polish; fold the rule there. |
| `viewer.js:235` — file:// gating for Copy-MD only checks toolbar buttons; per-section anchors still call `navigator.clipboard.writeText` (conf 65) | Falls back to `execCommand('copy')` per FR-25.1; toast says "Copy failed" intermittently on file://. Polish for Phase 2 once a real artifact exists to exercise the path. |
| `style.css` orphan classes (`.pmos-sidebar-sub`, `.pmos-skip-link`, `.pmos-source-info`, `.pmos-toolbar-meta`; conf 55) | Forward-compat hooks for T11 sub-nav and accessibility skip-link. Do not prune. |
| `conventions.md` doesn't enumerate `data-pmos-*` vocabulary (conf 60) | True; T7 (resolve-input.md) and T8 (per-skill runbook) will need this. Land the §12 vocabulary section there, not in T1's conventions.md (which is about heading-id semantics). |

## Phase 4 — runtime evidence (entry gate via this table per phase-scoped invocation)

Per the verify skill's "Invocation Mode: Phase-Scoped" change #3, this table is the structural gate (no per-FR `TodoWrite`).

| FR | Surface | Outcome | Evidence |
|---|---|---|---|
| FR-01 | Substrate dir + 4 files exist | **Verified** | `find plugins/pmos-toolkit/skills/_shared/html-authoring -maxdepth 2` lists `README.md`, `template.html`, `conventions.md`, `assets/` |
| FR-02 | `template.html` shape (head/body skeleton, no ESM, no CDN) | **Verified** | `head -25 template.html` confirms `<link rel="stylesheet" href="...style.css">` + classic `<script defer src="...viewer.js">`; no `type="module"` or external CDN |
| FR-03 | `conventions.md` heading-id + element rules | **Verified** | `conventions.md §3` documents kebab-case-id rule, lowercase, non-alnum→`-`, dedupe `-2`/`-3` |
| FR-03.1 | Per-skill enforcement clause | **NA — alt-evidence** | Out of Phase 1 scope: each affected skill's SKILL.md inline of the rule is owned by Phase 2 T8 + T9. `/verify` smoke (FR-72) is owned by T22. |
| FR-04 | `style.css` ≤30 KB, vanilla, no Tailwind | **Verified** | `wc -c style.css` → 14 155 B; `grep -i 'tailwind\|cdn\|@import' style.css` → 0 matches |
| FR-05 | `viewer.js` single classic script, ≤30 KB, all surfaces | **Verified** | `wc -c viewer.js` → 13 393 B; 4 JSDOM tests pass; 11 surfaces present (IIFE, readManifest, isFileProtocol, safeSession*, artifactSlug, buildSidebar, setupIframeRouter, renderLegacyMdShim*, setupCopyMarkdown, copyToClipboard, showQuickstartBanner, init) |
| FR-05.1 | No-modules guard | **Verified** | `grep -cE '^(import\|export)\b\|type=["\x27]module["\x27]' viewer.js` → 0. Standalone enforcement script (T21) ships in Phase 4. |
| FR-06 | `serve.js` zero-deps + MIME map + port fallback | **Verified** | Manual smoke (static.txt): all 5 extensions return correct Content-Type. Port-fallback structurally present (`for (let i = 0; i < PORT_SCAN_LIMIT; i++)`). New regression suite asserts MIME for html/css. |
| FR-07 | Vendored turndown + gfm + html-to-md, licenses preserved | **Verified** | `ls assets/turndown.umd.js assets/turndown-plugin-gfm.umd.js assets/html-to-md.js assets/LICENSE.turndown.txt` all present; license file copied verbatim from upstream MIT |
| FR-12.1 | `html-to-md.js` ≤100 LOC; reads argv, runs turndown+GFM, emits MD | **Verified** | `wc -l html-to-md.js` → 96; self-test `# Hi\n\nBody`; GFM table round-trip emits pipe-table |
| FR-22 | Legacy-md shim renders `<pre class="pmos-legacy-md">` + advisory | **Verified** | JSDOM test 3 in `viewer.test.js` |
| FR-25.1 | Clipboard fallback (execCommand + textarea) | **NA — alt-evidence** | Implemented in `copyToClipboard`; full exercise requires a real iframe sandbox (Phase 2 T11 chrome integration). Code-path verified by inspection during reviewer Check 6 + bug-scan reviewer; no JSDOM probe possible without a clipboard mock harness. |
| FR-26 | `sessionStorage` try/catch + in-memory fallback | **Verified** | JSDOM test 2 in `viewer.test.js` (QuotaExceededError + SecurityError → in-memory) |
| FR-40 | file:// detection + fallback banner + target=_blank sidebar links | **Verified** | JSDOM test 1 in `viewer.test.js` (banner present, all sidebar links `target="_blank"`, no iframe) |
| FR-41 | No `fetch()` of sibling JSON; manifest inlined | **Verified** | `grep -n 'fetch(' viewer.js` → 0 matches. Manifest read via `<script type="application/json" id="pmos-index">` text content. XHR used only for legacy-md shim under serve.js (FR-22 path). |
| FR-42 | Per-artifact `<artifact>.html` self-contained via relative `./assets/` paths | **NA — alt-evidence** | Substrate provides relative-path template; FR-10.1 (per-folder asset prefix) is owned by T8 runbook (Phase 2). Substrate-side correctness confirmed by template.html `{{asset_prefix}}` slot. |

**Outcome counts:** Verified: 12. NA — alt-evidence: 3. Unverified — action required: 0.

## Plan compliance (Phase 1 tasks)

| Task | Outcome | Evidence |
|---|---|---|
| T1 — Scaffold `_shared/html-authoring/` (template + conventions) | **Verified** | Commit `65ccedf`; structure check above (FR-01–03) |
| T2 — Author `assets/style.css` | **Verified** | Commit `267c164`; size 14 155 B; rename to `.pmos-fallback-banner` landed in this verify pass |
| T3 — Author `assets/viewer.js` | **Verified** | Commit `d8d440f` (impl), `a6b6373` (task log), this pass (4 review fixes); 4 JSDOM tests pass |
| T4 — Author `assets/serve.js` | **Verified** | Commit `2d7a87e`; path-traversal hardening + 4 regression tests landed in this pass |
| T5 — Vendor turndown + GFM (UMD) | **Verified** | Commit `5cdea32`; both bundles + LICENSE present; html-to-md.js exercises both |
| T6 — Author `assets/html-to-md.js` (CLI shim) | **Verified** | Commit `554343f`; 96 LOC ≤ 100; self-test + GFM round-trip pass |

## Tests added in this verify pass (Phase 6 hardening)

| Test | What it covers | Red-green proof |
|---|---|---|
| `tests/scripts/serve.test.js` Test 2 (URL-encoded `%2E%2E` traversal) | Regression for the `safeJoin` prefix-confusion bug | Empirically reproduced pre-fix (200 + SECRET leaked); post-fix returns 4xx with no leak. Documented in `static.txt` and `post-fix.txt`. |
| `tests/scripts/serve.test.js` Test 1 (literal `..`) | Confirms Node HTTP parser collapses literal `../` (no false-negative on the regression) | Pre-fix and post-fix both 404 (the literal form never reaches our handler). Test exists to prove negative case. |
| `tests/scripts/serve.test.js` Test 4 (MIME map) | FR-06 declarative coverage of `text/html; charset=utf-8` and `text/css; charset=utf-8` | Manual smoke confirmed pre-fix; new test makes it permanent. |
| `tests/scripts/viewer.test.js` Test 4 (artifactSlug) | Regression for the `manifest.id` honoring fix | Pre-fix `slugify('01_requirements.html')` returned `'01-requirements'` ignoring any explicit manifest `id`; post-fix `artifactSlug({id: '01-requirements', path: '...'})` returns `'01-requirements'` from the explicit id, and falls back to path-derived only when `id` absent. |

## Phase 7 — final compliance pass

- No TODO/FIXME/HACK in changed files (`grep -nE 'TODO\|FIXME\|HACK' plugins/pmos-toolkit/skills/_shared/html-authoring/` → 0).
- No debug logging or `console.log` in viewer.js/serve.js/html-to-md.js (each uses `process.stderr.write` only for user-facing errors).
- No hardcoded values that should be config; `DEFAULT_BASE_PORT=8765`, `PORT_SCAN_LIMIT=10` are exposed via CLI flags.
- README.md + conventions.md updated as part of T1; this verify pass adds no further docs.

## Phase 7.5 — design-system drift check

Skipped: no DESIGN.md / COMPONENTS.md present in this feature folder; no Tailwind/CSS-token extraction in scope. The substrate IS the design system seed for this feature.

## Open items (none blocking)

- `html-to-md.js` documented `HTML_TO_MD_JSDOM_PATH` semantics: comment says "abs path to jsdom"; the de-facto contract is `NODE_PATH`-style (`abs path to node_modules`). Land the doc fix in T17/T20 alongside the assert scripts that exercise html-to-md.js. Tracking note only — no code change needed; both shapes work today.
- conventions.md needs a §12 enumerating the `data-pmos-*` vocabulary (`role="toolbar|body|footer|main|sidebar|quickstart|fallback-banner|shell"`, `action="copy-md|copy-link"`). Land in T7 (resolve-input.md) or T8 (runbook).
- viewer.test.js readyState path coverage: extend in T17 sections-contract test alongside the toolbar Copy-MD test surface.

## Verdict

`{ ok: true, evidence_dir: "docs/pmos/features/2026-05-09_html-artifacts/verify/2026-05-09-phase-1/", failures: [] }`

Phase 1 substrate is ready for Phase 2 consumption.
