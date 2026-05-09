---
task_number: 2
task_name: "Author assets/style.css"
task_goal_hash: t2-style-css
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
status: done
started_at: 2026-05-09T18:55:00Z
completed_at: 2026-05-09T18:58:00Z
files_touched:
  - plugins/pmos-toolkit/skills/_shared/html-authoring/assets/style.css
---

## T2 — Author `assets/style.css`

### Outcome

Hand-authored vanilla CSS, 531 lines, **14,175 bytes** (well under the 30,720-byte budget — 46% headroom for future additions). Adapts wireframe palette using `--pmos-*` design tokens; vanilla CSS only — no Tailwind, no `@import`, no external runtime fetches.

### Sections (12 per plan)

1. `:root` design tokens — colors (light + dark via `prefers-color-scheme`), typography scale (xs..2xl), spacing scale (1..6), radii, shadows, mono+sans font stacks, sidebar width.
2. Reset + base — `*, *::before, *::after { box-sizing }`, html/body baseline, `a` color + focus-visible, `img/svg` max-width.
3. Typography — `h1..h6` (h2 has top-border separator + section anchor positioning), `p`, `pre/code` (mono, surface-2 bg), `blockquote` (left-accent rule).
4. Tables — `<table>`/`<th>`/`<td>` with thead surface-2 fill, even-row striping, caption italics.
5. Lists + DL — `ul/ol` indent, `dl/dt/dd` decision-log shape (dt bold, dd indented muted).
6. Figures — `<figure>` carded with surface bg + border + radius; SVG centered; `<figcaption>` muted italic centered.
7. Viewer chrome — `.pmos-viewer-shell` grid (280px sidebar + 1fr main), sticky toolbar, scroll-locked sidebar with group headers + active-state highlighting; iframe-fill `.pmos-main`.
8. Per-artifact body — `.pmos-artifact-toolbar` sticky with title + actions, `.pmos-btn` styling, max-width 880px content column, `.pmos-section-anchor` (left-edge, opacity 0 → 1 on `h2/h3:hover`), `:target` highlight flash animation (FR-90), `.pmos-toast` (Copy confirmation).
9. Quickstart banner — `.pmos-quickstart-banner` accent-bg pill (FR-26 W04).
10. file:// fallback banner — warning-tinted (light/dark variants).
11. Legacy MD shim — `.pmos-legacy-md` mono pre-wrap (FR-22) + warning banner.
12. Focus ring + a11y — `:focus-visible` everywhere, skip link, `prefers-reduced-motion`, print stylesheet (hides chrome, expands main).

### Inline verification (all PASS)

- `wc -c style.css` → 14175 (≤30720) ✓
- `grep -c "^@import" style.css` → 0 ✓
- `grep -c "tailwind" style.css` → 0 ✓

### Key decisions

- **Dark mode via `prefers-color-scheme`** — no toggle in chrome; respects OS setting. Cheap addition, no extra LOC inside chrome.
- **Section anchor as left-edge button** (offset `-28px`) rather than right-edge — matches the wireframe's hover-anchor pattern and avoids colliding with `<table>` content that runs to the right.
- **`:target` flash via `background-size` animation** — pure CSS, GPU-accelerated, no JS. Fades in 1.4s.
- **Print stylesheet included** — hides toolbar/sidebar/anchors so artifacts print cleanly. ~10 lines of CSS for a UX win.
- **Did NOT add Tailwind-style utility classes** despite wireframe leaning on them — the spec is explicit (FR-04 vanilla CSS, no Tailwind). Element selectors + the small set of `.pmos-*` component classes do everything the chrome needs.

### Deviations from plan

None.

### Open follow-ups

- T3 (viewer.js) will hook the `data-pmos-action="copy-md"` and `data-pmos-action="copy-link"` buttons, plus inject `.pmos-section-anchor` into rendered headings.
- T11 (index.html generator) consumes `.pmos-viewer-shell` / `.pmos-toolbar` / `.pmos-sidebar` / `.pmos-main` shell classes.
