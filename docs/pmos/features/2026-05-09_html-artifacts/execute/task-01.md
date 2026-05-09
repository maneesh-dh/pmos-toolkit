---
task_number: 1
task_name: "Scaffold _shared/html-authoring/ + template + conventions"
task_goal_hash: t1-scaffold-html-authoring-substrate
plan_path: "docs/pmos/features/2026-05-09_html-artifacts/03_plan.md"
branch: "feat/html-artifacts"
worktree_path: null
status: done
started_at: 2026-05-09T18:50:00Z
completed_at: 2026-05-09T18:55:00Z
files_touched:
  - plugins/pmos-toolkit/skills/_shared/html-authoring/README.md
  - plugins/pmos-toolkit/skills/_shared/html-authoring/template.html
  - plugins/pmos-toolkit/skills/_shared/html-authoring/conventions.md
  - plugins/pmos-toolkit/skills/_shared/html-authoring/assets/.gitkeep
---

## T1 — Scaffold `_shared/html-authoring/` + template + conventions

### Outcome

Substrate created. The new directory `plugins/pmos-toolkit/skills/_shared/html-authoring/` now holds:

- `README.md` (~64 lines): authoring contract — what the dir is, what skills MUST do at write time, FR-03.1 enforcement summary, pointers.
- `template.html` (24 lines): scaffold with `{{title}}`, `{{asset_prefix}}`, `{{plugin_version}}`, `{{content}}`, `{{source_path}}` slots. Classic `<script defer>` (FR-02 — no modules). `<header>`/`<main>`/`<footer>` body skeleton with toolbar role attributes the viewer.js will hook into.
- `conventions.md` (~120 lines): 11 sections covering section structure, heading hierarchy, FR-03.1 heading-id rule + canonical id-derivation algorithm with collision dedupe, `<figure>`/`<dl>`/`<table>`/`<pre>` patterns, forbidden patterns, sections.json companion contract, cross-doc anchor rule.
- `assets/` directory exists (T2-T6 will populate it).

### Inline verification (all PASS)

- `test -f .../README.md` → 0 ✓
- `test -f .../template.html` → 0 ✓
- `test -f .../conventions.md` → 0 ✓
- `grep -q 'every \`<h2>\` and \`<h3>\` carries' conventions.md` → PASS (FR-03.1 phrase present)
- `grep -cE 'type="module"|^import |^export ' template.html` → 0 (FR-02 no-modules)

### Key decisions

- **Toolbar role attributes** (`data-pmos-role="toolbar"`, etc.) emitted in template.html so `viewer.js` (T3) can hook into them without coupling to class names. Class names remain stable but the data attributes survive any future class rename.
- **Per-section "Copy section link" button** added to toolbar alongside "Copy Markdown" (FR-25 — copies `index.html#<artifact>/<section>`). Surfacing it at the top toolbar matches the spec's two-surface pattern.
- **Empty `assets/` not committed bare** — added `.gitkeep` placeholder so the directory tracks even before T2-T6 populate it (avoids a confusing intermediate commit where the substrate dir lacks the assets/ subdir).
- **Conventions §3 algorithm** spells out the id-derivation rule explicitly (lowercase → non-alnum→`-` → trim → dedupe `-2`/`-3`) so every skill author + every reviewer subagent can compute the same id deterministically. Cross-doc anchors (FR §11) depend on this determinism.

### Deviations from plan

None.

### Open follow-ups

- T2-T6 will populate `assets/` (style.css, viewer.js, serve.js, turndown vendoring, html-to-md.js).
- T11 will author the index.html + _index.json generator that consumes this substrate.
