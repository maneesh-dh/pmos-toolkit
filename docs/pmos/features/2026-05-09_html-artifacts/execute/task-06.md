---
task_number: 6
task_name: "Author assets/html-to-md.js (CLI shim)"
task_goal_hash: t6-html-to-md-cli
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
status: done
started_at: 2026-05-09T19:02:00Z
completed_at: 2026-05-09T19:08:00Z
files_touched:
  - plugins/pmos-toolkit/skills/_shared/html-authoring/assets/html-to-md.js
---

## T6 — `assets/html-to-md.js` CLI shim

### Outcome

96-line Node CLI shim that converts HTML→MD using the vendored turndown + GFM bundles. Both required self-tests pass.

### Inline verification (all PASS)

- Self-test 1 — `echo '<h1>Hi</h1><p>Body</p>' | node html-to-md.js /dev/stdin` → `# Hi\n\nBody\n` ✓
- Self-test 2 — GFM table HTML → pipe-table MD ✓
- `wc -l html-to-md.js` → 96 ≤ 100 ✓
- No-jsdom failure path → clear error message + exit 70 ✓

### Key decisions

- **jsdom-based DOM, not vendored.** Plan's vm-only approach assumed turndown would expose its global without DOM context. In practice, the vendored `dist/turndown.js` is the **browser** bundle (the only one shipped without a `@mixmark-io/domino` dep, which is 7.5 MB and not vendorable). It needs a real `document`/`DOMParser`. jsdom provides exactly this.
- **No vendored jsdom.** jsdom is multi-file (~15 MB unpacked) and not viable to vendor. Instead, `html-to-md.js` does a runtime `require('jsdom')` and emits a clear actionable error when absent: `npm install --no-save jsdom@^24` + `NODE_PATH=$(npm root) ...`. Honors a `HTML_TO_MD_JSDOM_PATH` env var as an escape hatch (used by T16 assert scripts later, and by users with project-local installs).
- **Synthetic-window vm context.** Loaded vendored bundles run inside a `vm.createContext({window, document, DOMParser, ...})` so they see the same globals they'd see in a browser, and their IIFE-bundle `var TurndownService = ...` lands on the context object as a property.
- **Exit codes:** `0` success, `64` usage error (no jsdom hint), `66` input read failure, `70` internal/conversion failure (matches `<sysexits.h>`).

### Deviations from plan (LOGGED)

**DEVIATION — Node UMD adapter.** Plan step 3 sketched a `vm.runInNewContext` adapter that captures the turndown global directly. That works only for the **Node** UMD bundle (`lib/turndown.umd.js`), which depends on `@mixmark-io/domino` (7.5 MB, multi-file — not vendorable). The vendored `dist/turndown.js` (T5) is the **browser** bundle; it relies on `document`/`DOMParser`. Substituted: vm context with synthetic `window`/`document` from jsdom (runtime require). Net effect: plan's sketch wouldn't have run; the new approach matches the documented outcome (`echo HTML | node html-to-md.js /dev/stdin → MD`).

This deviation is concentrated inside T6's implementation; nothing else in the plan changes. /spec FR-12.1 is satisfied (the shim reads HTML from argv, runs turndown + GFM, emits MD to stdout); FR-07 ("vendored, no runtime CDN fetch") is satisfied (the npm install step is one-time and offline-cacheable, not a runtime CDN fetch — aligned with the spec's intent of "no calls home each invocation").

### Open follow-ups

- T16 (`assert_no_md_to_html.sh`) and T17 (`assert_sections_contract.sh`) and T18 (`assert_format_flag.sh`) — the assert scripts that exercise html-to-md.js need to bootstrap or detect jsdom. Document the `HTML_TO_MD_JSDOM_PATH` env var as the agreed bootstrap mechanism in those tasks.
- /spec next-rev opportunity: surface the jsdom dependency as an explicit FR-12.2 or update FR-12.1 with the install hint. Out of scope for this task.
