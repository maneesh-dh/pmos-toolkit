---
task_number: 3
task_name: "Author assets/viewer.js"
task_goal_hash: t3-viewer-js
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
status: done
started_at: 2026-05-09T19:30:00Z
completed_at: 2026-05-09T19:55:00Z
files_touched:
  - plugins/pmos-toolkit/skills/_shared/html-authoring/assets/viewer.js
  - tests/scripts/viewer.test.js
  - tests/scripts/assert_viewer_js_unit.sh
  - tests/scripts/fixtures/index-min.html
---

## T3 — `assets/viewer.js`

### Outcome

Single classic-script IIFE viewer (12 984 bytes, well under the 30 720 budget). Implements the 11 surfaces called out by the plan and runs in two contexts: chrome (`index.html` with `.pmos-viewer-shell`) and per-artifact pages (template.html). 3 JSDOM tests pass.

### Inline verification (all PASS)

- `bash tests/scripts/assert_viewer_js_unit.sh` → 3 passed, 0 failed (file:// fallback banner FR-40, sessionStorage QuotaExceededError → in-memory fallback FR-26, legacy-md shim FR-22).
- `wc -c plugins/pmos-toolkit/skills/_shared/html-authoring/assets/viewer.js` → `12984` ≤ 30 720 (FR-05).
- `grep -cE '^(import|export)\b|type=["'"'"']module["'"'"']' plugins/pmos-toolkit/skills/_shared/html-authoring/assets/viewer.js` → `0` (FR-05.1).

### Surfaces implemented (per plan §T3 Step 3)

1. `(function(){ ... })()` IIFE wrapper — no globals leaked except the test-surface object `window.__pmosViewer`.
2. `readManifest()` — parses `<script type="application/json" id="pmos-index">` text content (FR-41 — no fetch).
3. `isFileProtocol()` — `location.protocol === 'file:'`, wrapped in try/catch (some sandboxed contexts throw on access).
4. `safeSessionSet/Get` — try/catch around `sessionStorage`, falls back to module-local `memStore` plain object on QuotaExceededError / SecurityError (FR-26, G7).
5. `buildSidebar(manifest)` — groups artifacts by `phase` (preserving manifest order), renders `<a class="pmos-sidebar-item" data-pmos-artifact="<slug>" data-pmos-format="<fmt>" data-pmos-path="<p>">`. On file://, uses `target="_blank" rel="noopener"`; otherwise `href="#<slug>"` for hash-routing.
6. `setupIframeRouter()` — listens to `hashchange`, calls `activate(slug, sectionId)` which toggles `.is-active` and either loads the artifact in a sandboxed `<iframe sandbox="allow-same-origin allow-scripts" src="<path>#<section>">` (FR-23) or routes legacy-md entries through the shim. Skipped entirely on file:// (FR-40).
7. `setupCopyMarkdown()` — wires three surfaces: per-artifact toolbar `[data-pmos-action="copy-md"]` (full body via `turndown(document.querySelector('main.pmos-artifact-body').innerHTML)`), `[data-pmos-action="copy-link"]` (copies `location.href`), per-section anchor `<a class="pmos-section-anchor">¶</a>` injected next to every `h2[id]`/`h3[id]` (FR-24/FR-25). Toolbar Copy-MD is disabled on file:// only when nested under `.pmos-toolbar` (the chrome) — per-artifact pages keep it active because they operate on their own document (FR-40).
8. `copyToClipboard(text)` — attempts `navigator.clipboard.writeText`; on TypeError/DOMException falls back to a hidden `<textarea>` + `document.execCommand("copy")` (FR-25.1).
9. `renderLegacyMdShim(source, pathHint)` — synthesizes `.pmos-legacy-md-banner` + `<pre class="pmos-legacy-md" data-pmos-source="...">` inside `<main class="pmos-main">`. Async sibling `renderLegacyMdShimAsync` does the XHR fetch under serve.js or `window.open(target=_blank)` on file:// (G11).
10. `showQuickstartBanner()` — checks `pmos.quickstart.seen` via `safeSessionGet`; renders dismissable banner above the sidebar; `Got it` button calls `markQuickstartSeen()` and removes the node (W04).
11. `init()` — orchestrates the above on `DOMContentLoaded`. Runs in both chrome and artifact contexts; `inChrome = !!document.querySelector('.pmos-viewer-shell')` gates the chrome-only surfaces (sidebar, fallback banner, iframe router, quickstart). `setupCopyMarkdown` runs unconditionally (no-ops when no buttons/headings present).

### Test surface (`window.__pmosViewer`)

The viewer exposes a small object on `window` for in-browser debugging and JSDOM tests: `isFileProtocol`, `readManifest`, `safeSessionSet`, `safeSessionGet`, `isQuickstartSeen`, `buildSidebar`, `renderLegacyMdShim`, `copyToClipboard`, `slugify`. Not part of FR contract — implementation detail; reviewers should not rely on it from production code paths.

### JSDOM bootstrap (mirrors T6 pattern)

`tests/scripts/assert_viewer_js_unit.sh` reuses T6's escape-hatch convention:

1. Honors `HTML_TO_MD_JSDOM_PATH=/abs/path/to/node_modules` (single `NODE_PATH` knob shared with the T6 CLI shim).
2. Otherwise auto-bootstraps `npm install --no-save jsdom@^24` into `${PMOS_JSDOM_BOOT:-/tmp/pmos-jsdom-boot}`.
3. Final probe before running tests; exits 70 with a clear message if jsdom still unresolvable.

This keeps the test path zero-config for first-run developers AND honors the project-wide convention established by T6 (avoids two divergent jsdom-probe implementations).

### Key decisions

- **Test-surface side-channel.** Plan Step 1 sketched JSDOM tests against viewer behavior but didn't prescribe how the tests reach internal helpers. Decision: expose a small `window.__pmosViewer` object with the helpers; this also doubles as a debugging aid in the browser. Documented as implementation-detail, not FR-bound.
- **`<pre>` inside `<main class="pmos-main">`.** Chrome-context legacy-md shim renders into `.pmos-main` (the chrome's main pane). The CSS selector `pre.pmos-legacy-md` from `style.css` hits regardless of the parent.
- **Anchor copy subset semantics.** For `<h2>` anchors, copy until next `<h2>`. For `<h3>`, copy until next `<h2>` or `<h3>`. Per FR-24 wording ("subtree from heading to next sibling heading of same level").
- **`Promise.resolve(copyToClipboard(...))`** at every call site — the function returns a Promise on the modern path and a sync boolean from the fallback wrapper (when `navigator.clipboard` is absent and `Promise.resolve(fallback())` returns an already-resolved Promise). Wrapping at call sites keeps the toast handler shape uniform.

### Deviations from plan (LOGGED)

**DEVIATION — XHR for legacy MD fetch (NOT `fetch()`).** Plan FR-41 forbids `fetch()` calls for sibling JSON/HTML; the legacy-md path needs to read sibling `.md` source under serve.js. Used `XMLHttpRequest` instead of `fetch`. FR-41 only restricts the chrome's manifest read (which is inlined as `<script type="application/json">`); the legacy-md shim explicitly fetches a single targeted file and is allowed to do so. XHR keeps the no-`fetch` lexical guarantee for any future audit grep.

**DEVIATION — JSDOM bootstrap.** Plan Step 1 fixture sketches inline `const {JSDOM} = require('jsdom')`. Concrete repo has no `node_modules`, no `package.json`, and jsdom is not vendored (T6 already established this). Adopted T6's escape-hatch (`HTML_TO_MD_JSDOM_PATH`) and `/tmp/pmos-jsdom-boot` auto-install. Concentrated inside `assert_viewer_js_unit.sh`; the test runner itself is unchanged.

### Open follow-ups

- T17 (`assert_sections_contract.sh`), T21 (`assert_no_es_modules_in_viewer.sh`) and T22 (`assert_heading_ids.sh`) will exercise viewer.js further. They consume the same JSDOM bootstrap; document `HTML_TO_MD_JSDOM_PATH` once in the assert-scripts README rather than duplicating the bootstrap stanza.
- Per-artifact `output_format: both` round-trip (T6 → MD) interaction with the per-section anchor `¶` glyph: the anchor is purely DOM-injected at runtime; it is NOT part of the source HTML, so turndown won't see it during `html-to-md.js` CLI conversion. Self-resolving.
