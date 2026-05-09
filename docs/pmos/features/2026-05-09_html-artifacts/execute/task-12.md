---
task_number: 12
task_name: "Chrome-strip helper algorithm"
task_goal_hash: t12-chrome-strip
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
status: done
started_at: 2026-05-09T23:55:00Z
completed_at: 2026-05-10T00:05:00Z
files_touched:
  - plugins/pmos-toolkit/skills/_shared/html-authoring/chrome-strip.md
  - plugins/pmos-toolkit/skills/_shared/html-authoring/assets/chrome-strip.js
  - tests/scripts/assert_chrome_strip.sh
  - tests/fixtures/chrome-strip/1.html
  - tests/fixtures/chrome-strip/2.html
  - tests/fixtures/chrome-strip/3.html
  - tests/fixtures/chrome-strip/4.html
  - tests/fixtures/chrome-strip/5.html
---

## T12 — chrome-strip helper

**Outcome:** done. Algorithm doc + reference JS implementation + 5-fixture
self-test, all green. R2 mitigated (balanced-tag tracker correctly handles the
nested-literal-`<main>` case in `<pre><code>`).

### TDD cycle

1. Wrote 5 fixtures at `tests/fixtures/chrome-strip/{1..5}.html` covering the
   edge cases enumerated in plan T12 step 1.
2. Wrote `tests/scripts/assert_chrome_strip.sh` (43 lines) — runs each fixture
   through the helper, asserts presence/absence of marker substrings.
3. Ran assert script → **FAIL** as expected: `Cannot find module …chrome-strip.js`.
4. Authored `chrome-strip.md` (≈55 lines): purpose + 4-step algorithm + 5-row
   edge-case table + reference implementation pointer + self-test pointer.
5. Authored `chrome-strip.js` (≈55 LOC, well under the 80 LOC budget). Three
   pure functions: `extractFirstH1` (regex), `extractFirstMain` (balanced-tag
   tracker over `/<main\b/gi` opens vs `/<\/main\s*>/gi` closes), `stripChrome`
   (defensive `<link>` / `<script>` / `<style>` removal).
6. Ran assert script → **PASS** (5/5). Output: `OK: 5 chrome-strip fixtures passed`.

### F3 evidence (R2 mitigation)

The literal `<main>fake</main>` inside `<pre><code>` does not truncate the
extraction. Stripped output for F3:

```
<h1>F3 Title</h1>
<main class="pmos-artifact-body">
    <p>before</p>
    <pre><code><main>fake</main></code></pre>
    <p>after-marker-3</p>
  </main>
```

`after-marker-3` is between the inner `</main>` and the outer `</main>` — its
presence proves the tracker walked past the inner close (depth 1 → 0 only at
the outer close).

### Decisions / deviations

- **Step 5 — implementation choice.** Plan offered "small node helper OR inline
  into each skill prompt". Chose the shared helper (`assets/chrome-strip.js`)
  to reduce drift across the 5 reviewer-dispatching skills (consistent with
  how `html-to-md.js` is shared across all skills emitting MD sidecars).
- **Defensive chrome-strip in step 3.** The substrate template never embeds
  `<link>` / `<script>` / `<style>` inside `<main>`, but a hand-edited
  artifact theoretically could. The defensive regex removes them after the
  balanced extraction; cost is negligible.
- **No `<header>` / `<footer>` strip from captured slice.** Step 3 of the
  plan listed `<header class="pmos-artifact-toolbar">` / `<footer
  class="pmos-artifact-footer">` as strip targets, but those elements live
  outside the extracted `<main>` slice (siblings of `<main>` in the substrate
  template). The captured `<h1>` is the inner `<h1>` element only — its parent
  `<header>` is not transitively included. Documented in chrome-strip.md
  edge-case row 5.
- **Exit codes.** 64 on missing argv (per existing /viewer + /serve
  conventions); 1 on missing `<main>` (real failure); 0 on success.

### Spec compliance

| FR | Requirement | Satisfied by |
|---|---|---|
| FR-50 | Canonical chrome-strip algorithm | chrome-strip.md §Algorithm steps 1-4 |
| FR-50 | R2 mitigation (balanced tracker) | chrome-strip.js `extractFirstMain` + F3 self-test |

FR-51 (consumer prompt template), FR-52 (post-dispatch validation), FR-72
(hard-fail policy) land in T13 (5 reviewer-prompt updates).

### Inline verification

```
$ bash tests/scripts/assert_chrome_strip.sh
OK: 5 chrome-strip fixtures passed
```

LOC budget: chrome-strip.js = 55 LOC (≤80 target). chrome-strip.md = 53 lines
(≤40 target was approximate; over by 13 because the edge-case table earned its
keep — it documents R2 explicitly).

### Forward-dependencies

- **T13:** 5 skills will inline `node ${CLAUDE_PLUGIN_ROOT}/skills/_shared/html-authoring/assets/chrome-strip.js <artifact>.html > /tmp/<artifact>-stripped.html` before subagent dispatch.
- **T26 (Final Verification):** reviewer-smoke run consumes the stripped output to validate FR-51 + FR-52 end-to-end.
