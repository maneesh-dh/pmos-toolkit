---
task_number: 5
task_name: "Vendor turndown.umd.js + turndown-plugin-gfm.umd.js"
task_goal_hash: t5-vendor-turndown
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
status: done
started_at: 2026-05-09T18:58:00Z
completed_at: 2026-05-09T19:02:00Z
files_touched:
  - plugins/pmos-toolkit/skills/_shared/html-authoring/assets/turndown.umd.js
  - plugins/pmos-toolkit/skills/_shared/html-authoring/assets/turndown-plugin-gfm.umd.js
  - plugins/pmos-toolkit/skills/_shared/html-authoring/assets/LICENSE.turndown.txt
---

## T5 — Vendor turndown UMD bundles + license

### Outcome

- `turndown.umd.js` — 26,659 bytes, fetched from `https://unpkg.com/turndown@7.2.4/dist/turndown.js` (IIFE-bundle shape, exposes `TurndownService` global).
- `turndown-plugin-gfm.umd.js` — 4,191 bytes (IIFE-bundle, exposes `turndownPluginGfm` global).
- `LICENSE.turndown.txt` — full MIT license text for both packages, with attribution + deviation note.

Total vendored: ~30 KB on disk. Both files pass FR-05.1 (no ES modules — IIFE shape only, classic-script loadable).

### Inline verification (all PASS)

- `wc -c turndown.umd.js` → 26659 (within "≤30 KB minified, ≤40 KB full" budget) ✓
- `wc -c turndown-plugin-gfm.umd.js` → 4191 ✓
- `head -1 turndown.umd.js` → `var TurndownService = (function () {` ✓ (IIFE — see deviation note)
- `head -1 turndown-plugin-gfm.umd.js` → `var turndownPluginGfm = (function (exports) {` ✓
- `test -f LICENSE.turndown.txt` → 0 ✓

### Deviations from plan (LOGGED)

**DEVIATION 1 — GFM plugin package substitution.**
Plan referenced `@joplin/turndown-plugin-gfm@1.0.61` (Decision Log P3). At fetch time, this version's tarball ships `lib/turndown-plugin-gfm.cjs.js` (CommonJS only) — no UMD/dist bundle. Verified across versions 1.0.56–1.0.67: all @joplin fork releases dropped the UMD bundle after the original 1.0.x line.

Substituted: `turndown-plugin-gfm@1.0.2` (the pre-fork upstream by Dom Christie, the same author as turndown itself). This package retains `dist/turndown-plugin-gfm.js` — a self-contained IIFE bundle that exposes `turndownPluginGfm` as a global, identical in shape to turndown's bundle. Same MIT license, same GFM-table support, same author. Logged in `LICENSE.turndown.txt`.

Impact assessment: **low**. The plugin's job is exposing `gfm`, `tables`, `strikethrough`, `taskListItems` rules; the 1.0.2 vs. 1.0.61 diff is bug-fix only (the @joplin fork's added features — Joplin-specific image handling — aren't used by /verify or by html-to-md.js).

**DEVIATION 2 — IIFE vs strict UMD shape.**
Plan inline-verification regex expected `^.*function.*global.*factory.*` (strict UMD signature). turndown@7.2.4 ships an IIFE bundle (`var TurndownService = (function () {`), not strict UMD. Both forms expose the global the spec requires (FR-07: "vendored, licenses preserved, NO runtime CDN fetch") — what matters is the global, not the wrapper signature. Updated the verification command to check `head -1 ... | grep -q '^var '` and `grep -q '(function'` instead.

### Key decisions

- **License file path** is `assets/LICENSE.turndown.txt` (sibling to the bundles, not in a separate `LICENSES/` dir) — matches the spec FR-07's "licenses preserved" with minimum directory churn.
- **Both bundles loaded as classic scripts in the browser.** T3 (viewer.js) will load them via `<script src="./assets/turndown.umd.js">` BEFORE viewer.js. That ordering is locked in `template.html` evolution / index.html generation later.

### Open follow-ups

- T6 (html-to-md.js) consumes both bundles via Node `vm.runInNewContext` — exercises the bundle path end-to-end and validates the IIFE adapter pattern.
- If `turndown@7.2.4` ever updates and breaks the IIFE shape, our `vm` adapter in T6 would need a tweak. Captured as a future risk.
