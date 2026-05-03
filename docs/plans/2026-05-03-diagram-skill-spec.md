# `/diagram` Skill — Spec

**Status:** Revised post-grill (21 decisions locked)
**Date:** 2026-05-03
**Author:** Maneesh + Claude
**Save location:** `~/Desktop/Projects/agent-skills/skills/diagram/SKILL.md` (delivered via `pmos-toolkit:diagram`)

---

## 1. Goals

Produce a single SVG file that visually communicates a concept — architecture, flow, hierarchy, dependency, sequence, state, mental model, etc. — with a consistent house style and a measurable, mostly-binary quality bar.

**The skill must:**

1. Accept free-form input ("draw how X works") with optional path to a markdown source document.
2. Brainstorm **2–3 structurally distinct framings** of the same content, **reasoned from first principles each time** (no hardcoded list — agent invents framings appropriate to the content), and present them via `AskUserQuestion` for user selection before drawing. A `--approach <free-text>` flag bypasses the brainstorm for automation.
3. Emit exactly one `.svg` file plus a `<slug>.diagram.json` sidecar that records the design decisions and node geometry.
4. Self-evaluate against a hybrid rubric (deterministic code metrics with hard-fails + a 7-item binary vision rubric on rendered raster) and iterate up to N refinement loops per rigor tier (default high = up to 2), exiting early on clean pass.
5. Apply a single shared `style.md` for tokens, typography, layout, components (arrowheads, edge labels, legend), accessibility, canvas sizes, and anti-patterns — used both as generation guidance and as the eval contract.

## 2. Non-goals

- **No per-diagram-type templates.** The skill does not ship "flowchart.svg", "architecture.svg" exemplars to clone. The agent re-derives layout each time.
- **No pipeline integration.** Standalone utility. Does not load workstream context, does not gate `/spec` or `/plan`.
- **No interactive SVG.** Static — no JavaScript, no animations.
- **No DSL conversion.** SVG is authored directly. We do not produce Mermaid/PlantUML/Graphviz and convert.
- **No raster output.** The PNG render is a private intermediate for vision review only.
- **No code-directory parsing for `--source`** in v1 (markdown / plain text only).
- **No category icons / badge library** in v1.

## 3. User-facing surface

```
/diagram <free-form description>
         [--source <path>]
         [--out <path>]
         [--approach <free-text framing>]
         [--rigor high|medium|low]
         [--clear-cache]
         [--selftest]
```

- **`<free-form description>`** (required, positional): "show how the requirements pipeline feeds into spec and plan with optional enhancers".
- **`--source <path>`** (optional): markdown / plain-text file. Agent reads it and uses it as ground truth for entities/relationships. **v1 does not accept code directories.**
- **`--out <path>`** (optional): output path. Default: `{docs_path}/diagrams/<slug>.svg` where `{docs_path}` is resolved as: read `.pmos/settings.yaml`; if present use its `docs_path` value (default `.pmos`); else fall back to `docs/pmos/`. `<slug>` is a 5–6 word kebab-case derived from the description. The `diagrams/` subdirectory is created on demand. Sidecar `<slug>.diagram.json` lives next to the SVG.
- **`--approach <free-text>`** (optional): bypasses Phase 2 brainstorm. Agent uses the supplied framing directly. Intended for scripts and parent skills.
- **`--rigor`** (optional): `high` (default) / `medium` / `low`. Controls the loop budget (see §6).
- **`--clear-cache`** (optional, no value): wipes `~/.pmos/diagram-cache/` and exits without drawing.
- **`--selftest`** (optional, no value): runs the eval against the bundled golden + defect fixtures and exits with diff vs snapshot.

**Final stdout** on success: absolute path to the SVG plus a one-line eval summary, e.g.:
```
./diagrams/requirements-to-plan-flow.svg
Eval: PASS — code 0.92, vision 6/6 items pass (item 7 advisory: balance OK), canvas 1280x800, 8 nodes
```

On terminal failure (see §6 Phase 6.5): write a `<slug>.svg` with a leading XML comment warning, OR delete it, depending on user choice.

## 4. File layout

```
skills/diagram/
├── SKILL.md                       # main instructions (target < 500 lines)
├── style.md                       # tokens, typography, layout, components, a11y, canvases, anti-patterns
├── eval/
│   ├── rubric.md                  # binary 7-item vision rubric + reviewer prompt template
│   └── code-metrics.md            # exact xml.etree-based metric implementations
├── reference/
│   ├── svg-primer.md              # SVG gotchas: viewBox, transform composition, text length, markers, namespaces
│   ├── render-to-raster.md        # Playwright MCP / rsvg-convert / cairosvg invocations + detection
│   └── sidecar-schema.md          # <slug>.diagram.json schema (schemaVersion: 1)
├── examples/
│   └── style-atoms/               # tiny SVGs: one node, one connector w/ arrowhead, one legend chip,
│                                  # color-swatch sheet, type-specimen sheet. NOT full diagrams.
└── tests/
    ├── golden/                    # ~5 SVGs that should pass
    │   ├── *.svg
    │   └── *.expected.json        # snapshotted code-metric output for regression diffing
    ├── defects/                   # ~10 SVGs each carrying ONE intentional violation
    │   └── *.svg                  # filename encodes the expected failing metric
    └── run.py                     # invoked by `--selftest`
```

**Why `examples/style-atoms/` is not "templates":** they are isolated visual primitives — one node in canonical style, one connector with arrowhead, one legend chip, one color-swatch sheet, one type specimen. The agent never sees a full composition to copy. Style is calibrated; structure is re-derived.

## 5. style.md — single source of truth

Concrete, opinionated, narrow. Every section below is enforced either by code metrics, the binary vision rubric, or both.

### 5.1 Design tokens (HARD-LOCKED)

- **Palette** — 6 semantic roles. Hex values fixed. **One** accent. Pinned to satisfy WCAG AA contrast for every pairing the skill is permitted to combine (see §5.8).
  - `surface`, `surface-muted`, `ink`, `ink-muted`, `accent`, `warn`
- **Typography** — single sans-serif stack: `Inter, ui-sans-serif, system-ui`.
  - Sizes: `12 / 14 / 16 / 20` only. **Never** below 12.
  - Weights: `400 / 600` only.
- **Stroke weights**: `1 / 1.5 / 2` only.
- **Corner radii**: `0 / 4 / 8` only.
- **Spacing scale**: `4 / 8 / 16 / 24 / 32` (4-px grid).

### 5.2 Layout (FLEXIBLE APPLICATION within locked tokens)

- Snap every coordinate to the 4-px grid.
- Reading direction matches content: top-down for hierarchy, left-right for flow. Pick once per diagram, don't mix.
- Whitespace ≥ 24px between distinct groups, ≥ 16px between sibling nodes.
- Connector style is a **judgment call by content type**: orthogonal right-angle for flows / architectures / sequences; curves acceptable for mind maps, dependency graphs, networks. Pick one style per diagram, don't mix.

### 5.3 Color usage (FLEXIBLE within locked tokens)

Color is a category signal, not decoration. Number of colors used = number of categories the content actually has, drawn from the 6-token palette. There is no "monochrome by default" rule — agent uses 1 to 4 colors as the content needs. Whenever ≥ 2 categorical colors are used, a legend block (see §5.6) is mandatory.

### 5.4 Arrowheads (TOKEN)

One style only:
- Filled solid triangle, 8px wide × 6px tall.
- Color matches the connector stroke.
- One marker definition reused across all connectors in the diagram.

### 5.5 Edge labels (TOKEN)

When a connector needs a label ("creates", "1..*", "depends on"):
- 12px ink-muted text on a `surface-muted` pill background.
- 4px horizontal padding, 2px vertical padding, 4px corner radius.
- Centered on the connector midpoint; rotates with the line only if the angle is ≤ 30° from horizontal, else stays horizontal and the connector routes around it.

### 5.6 Legend block (TOKEN)

Required whenever ≥ 2 categorical colors are used:
- Anchored top-right of the canvas, inside content padding.
- 16×16 color swatch + 8px gap + 12px label per row.
- 4px row gap.
- `surface` background, 1px `ink-muted` border, 4px corner radius, 8px internal padding.

### 5.7 Canonical canvases (TOKEN)

Three canvases. Width is always 1280. Agent chooses one based on content shape and announces the choice with a one-line rationale.

| Aspect | Dimensions | Use for |
|---|---|---|
| 16:10 | 1280 × 800 | General flows, architectures, sequences (default) |
| 1:1 | 1280 × 1280 | Hierarchies, concept maps, radial layouts |
| 4:5 | 1280 × 1600 | Tall trees, deep dependency stacks |

### 5.8 Accessibility — contrast (HARD-LOCKED)

Palette hex values must be chosen so every text/background pair the skill emits passes WCAG AA:
- ≥ 4.5:1 for body text (12, 14 px).
- ≥ 3:1 for ≥ 16 px text.

Enforced by a code metric (§7.1) — any text element whose color/enclosing-fill pairing falls below threshold is a hard fail.

### 5.9 Anti-patterns (explicit "don't")

- Drop shadows, gradients, 3-D bevels, skeuomorphic icons.
- Connectors crossing through unrelated nodes ("edge tunnels").
- Text smaller than 12 px or rotated more than 30°.
- Decorative emoji or clip-art.
- Mixed reading directions in one diagram.
- Mixed connector styles (orthogonal + curves) in one diagram.
- Rainbow palettes — colors outside the 6-token set.

## 6. Phase plan

```
Phase 0   Load learnings + parse args + detect renderer (HARD GATE)
Phase 1   Comprehension — read --source, extract entities/relationships
          + check for existing <slug>.svg + sidecar
Phase 2   Approach selection
          - if --approach passed: use directly
          - else: agent invents 2–3 framings from first principles,
                  AskUserQuestion to pick (prose-fallback if unavailable)
Phase 3   Draft — produce first SVG honoring style.md; choose canvas size
Phase 4   Self-review (deterministic metrics; hard-fail gates)
Phase 5   Self-review (vision reviewer subagent; binary rubric)
Phase 6   Refinement loop (up to N per rigor tier, exit early on clean pass)
          → Findings Presentation Protocol via AskUserQuestion at end of each loop
Phase 6.5 Terminal failure handler (high/medium rigor only;
          fires when loops exhausted with gating fails remaining)
          → AskUserQuestion: ship-with-warning / restart-with-alternative-framing / abandon
          (low-rigor skips this phase — see §6 rigor table for ship-with-warning behavior)
Phase 7   Write sidecar <slug>.diagram.json
Phase 8   Capture Learnings (mandatory, terminal-gate)
```

### Phase 0 hard gate — renderer detection

The skill **refuses to run** if none of the following is available:
1. Playwright MCP (preferred — `mcp__plugin_playwright_playwright__browser_navigate` + `_take_screenshot`).
2. `rsvg-convert` on PATH.
3. `cairosvg` (Python module).

Failure message includes a one-line install hint per platform. Vision review is non-negotiable; without it, half the eval is missing.

### Phase 1 — existing-output handling

If `<slug>.svg` already exists, the skill picks one of two flows by comparing the sidecar's `concept` field to the current input:

**Same concept (substantial match) → extend-vs-redraw flow.** AskUserQuestion: (a) **extend** — agent reads the existing SVG + sidecar, treats positions/color assignments as fixed, and applies the new instruction as a minimal patch (e.g. "make the auth box red" recolors only that node, leaving geometry untouched); (b) **redraw** — discard the existing SVG, regenerate from scratch using the sidecar's recorded approach as a starting hint.

**Different concept (or sidecar absent) → collision flow.** AskUserQuestion: (a) **overwrite**, (b) **write to `<slug>-2.svg`** (and a fresh sidecar), (c) **cancel** with a hint to pass `--out`.

Prose-fallback in non-AskUserQuestion environments: default to **redraw** (same-concept) or **suffix** (collision); announce the choice and proceed.

### Phase 2 — `--approach` bypass

If the flag is set, skip the brainstorm entirely. Agent still announces the framing it's using. Otherwise present 2–3 first-principles framings via `AskUserQuestion` (or numbered prose fallback in non-Claude-Code envs).

### Phase 6 — refinement-loop budget per rigor tier

| Rigor | Loop budget | Vision reviewer | Behavior |
|---|---|---|---|
| **high** (default) | up to 2 | dedicated subagent | full protocol; exit early on clean pass |
| **medium** | up to 1 | inline reviewer call | full protocol; exit early on clean pass |
| **low** | 0 | inline (run once for reporting) | draft + Phase 4 code metrics + Phase 5 vision review run once; results reported but **no refinement loop** triggered even on fail. Diagram ships with whatever fails it has, plus warning |

**Exit early** on any iteration where: code-metric score ≥ 0.8 with zero hard-fails AND vision rubric items 1–6 all pass.

Lighter-tier announcement (per `create-skill` Convention 2): "Choosing [tier] because [reason]. Trade-off: fewer refinement passes mean visual issues less likely to be caught. Override?"

## 7. Eval rubric — hybrid

### 7.1 Deterministic code metrics (Phase 4)

Computed via `python3 -c '...'` calls using `xml.etree.ElementTree`. Composes nested `<g transform="...">` to resolve absolute coordinates; resolves CSS classes for `font-size`/`fill`/`stroke` lookup. Metric scores ∈ [0,1]; weighted sum is the code subscore. **Hard-fails** override the score and force refinement (or terminal failure if loops are exhausted).

| Metric | How computed | Soft threshold | Hard-fail |
|---|---|---|---|
| **Edge crossings** | Pairwise segment-intersection on resolved polylines. Score = `1 − crossings / max_possible`. | ≥ 0.95 (≈ 0–1 crossings on ≤ 15 nodes) | — |
| **Node-node occlusion** | Bounding-box overlap of node shapes after transform composition. | — | overlap > 0 |
| **Edge-node occlusion ("tunnels")** | For each connector, count node bboxes the polyline crosses that aren't endpoints. | — | tunnels > 0 |
| **Min font size** | Min `font-size` resolved across all `<text>` (incl. CSS class). | — | < 12 px |
| **Palette adherence** | All `fill` / `stroke` ∈ §5.1 token set. | — | any non-token color |
| **Contrast (WCAG AA)** | For each `<text>`, compute relative-luminance ratio against enclosing fill. | — | < 4.5:1 (body) / < 3:1 (≥ 16 px) |
| **Grid snap** | All resolved x/y mod 4 == 0. | ≥ 0.95 | — |
| **Node count** | 1.0 if ≤ 12; 0.7 if 13–20 (announce "consider splitting"); 0.4 if 21–30 (MUST propose split via AskUserQuestion, user can override); — if > 30 | ≥ 0.4 | > 30 |
| **Angular resolution** (when ≥ 1 node has degree ≥ 3) | Min angle between incident connectors at any node, normalized by `360 / degree`. | ≥ 0.5 | — |

**Code subscore** = mean of the four soft-threshold metric scores (edge crossings, grid snap, node count, angular resolution — the last only when applicable). The five hard-fail-only metrics (occlusion, tunnels, font min, palette, contrast) are pure gates and do not contribute to the subscore. Pass: subscore ≥ 0.8 AND zero hard-fails.

**Side-effect — node-count split prompt.** When node count is in [21, 30], the metric scores 0.4 (does not fail) but Phase 4 MUST emit an AskUserQuestion proposing a split into two diagrams. User can override and proceed. This fires regardless of overall pass/fail, before any refinement loop.

References: `greadability.js` (rpgove); Dunne & Shneiderman, "Readability metric feedback for aiding node-link visualization designers" (IBM J. R&D, 2015); Purchase, "Validating Graph Drawing Aesthetics."

### 7.2 Vision reviewer — 7-item binary rubric (Phase 5)

Render the SVG via the renderer chosen in Phase 0 → PNG at the canonical canvas dimensions → dispatch reviewer (general-purpose subagent in `high`-rigor; inline call otherwise). Reviewer is given the PNG, the rubric below, and the rendered file's source SVG (for grounding citations).

For each item, reviewer outputs `pass | fail` PLUS a one-sentence justification grounded in concrete pixel/element evidence ("text 'auth-svc' at coords ~410,288 overlaps connector to 'gateway'"). No 0–5 scoring.

| # | Binary check | Gating? |
|---|---|---|
| 1 | Is there exactly one visually-emphasized "primary" node (size, weight, or position distinguishes it)? | yes |
| 2 | Does the diagram have a clear starting point — top-left node, or an explicitly labeled "start" / "input"? | yes |
| 3 | Is every text label fully legible at 50% raster scale (no clipping, no occlusion)? | yes |
| 4 | Does each color used appear in the legend with a clear meaning? (N/A and auto-pass if only one ink color) | yes |
| 5 | Are arrowheads consistently directional (no mix of bidirectional + directional without legend explanation)? | yes |
| 6 | Does the diagram match the reference style atoms (palette tokens, stroke weights, type scale)? | yes |
| 7 | Is the largest empty quadrant ≤ 35% of canvas area AND the densest 25% region ≤ 60% of nodes? (replaces "balance") | advisory |

**Vision pass:** all of items 1–6 pass. Item 7 reported but doesn't gate (intrinsically content-driven for trees and hubs).

### 7.3 Combined gate

A diagram **passes** when:
1. Code metrics: zero hard-fails AND code subscore ≥ 0.8.
2. Vision rubric: all gating items (1–6) pass.

If either side fails → enter refinement loop (Phase 6). If loops exhaust with fails remaining → terminal failure (Phase 6.5).

### 7.4 Findings Presentation Protocol (Phase 6, MANDATORY per `create-skill` Convention 2)

After each loop, present findings via `AskUserQuestion`:

- Group by category (max 4 per batch — issue multiple sequential calls if more findings).
- One question per blocker. Blockers = (a) any code hard-fail, (b) any soft-threshold code metric below its threshold that is dragging subscore below 0.8, (c) any vision item 1–6 fail.
- Options: **Apply fix as proposed** / **Modify fix** / **Skip** / **Defer to user notes**.
- Open-ended findings (e.g., "rethink categorization") asked as a follow-up after the structured batch — never shoehorned into options.
- **Prose-fallback** for non-Claude-Code envs: numbered findings table with disposition column; do NOT silently self-fix.

## 8. Render-to-raster

Detection runs in Phase 0 (hard gate). Three-tier pick (preferred → fallback) documented in `reference/render-to-raster.md`:

1. **Playwright MCP** (preferred): `mcp__plugin_playwright_playwright__browser_navigate` to `file://<svg>` then `browser_take_screenshot` at the canonical canvas size. Pixel-perfect, no install.
2. **`rsvg-convert`** (binary on PATH): `rsvg-convert -w 1280 in.svg -o out.png`.
3. **`cairosvg`** (Python module): `python3 -m cairosvg in.svg -o out.png -W 1280`.

If none detected → Phase 0 refuses to run.

PNG is written to `~/.pmos/diagram-cache/<slug>-<sha1-of-svg-bytes>.png`. Cache persists across runs (so re-runs reuse). Cleared explicitly via `--clear-cache`. The cache is per-user, never inside any repo.

## 9. Sidecar — `<slug>.diagram.json`

Written next to the SVG in Phase 7. Schema documented in `reference/sidecar-schema.md`. Read in Phase 1 to enable extend-vs-redraw and informed re-runs.

```json
{
  "schemaVersion": 1,
  "concept": "<short paraphrase of the input description>",
  "approach": "<chosen framing description>",
  "alternativesConsidered": ["<framing-2>", "<framing-3>"],
  "canvas": { "aspect": "16:10", "width": 1280, "height": 800 },
  "entities": [{ "id": "...", "label": "...", "category": "..." }],
  "relationships": [{ "from": "...", "to": "...", "label": "...", "kind": "..." }],
  "positions": { "<id>": { "x": 0, "y": 0, "w": 0, "h": 0 } },
  "colorAssignments": { "<category>": "<token-name>" },
  "evalSummary": {
    "codeScore": 0.92,
    "codeHardFails": [],
    "visionItems": { "1": "pass", "2": "pass", "3": "pass", "4": "pass", "5": "pass", "6": "pass", "7": "pass" },
    "loopsRun": 1,
    "shippedWithWarning": false
  },
  "createdAt": "2026-05-03T12:00:00Z",
  "createdBy": "pmos-toolkit:diagram@v1"
}
```

**Versioning policy** (tolerant read):
- If `schemaVersion == current` → use directly.
- If older → fields missing from the older schema default sensibly; log a one-line note ("read sidecar v0; some fields defaulted").
- If newer → refuse with: "this sidecar was written by a newer /diagram. Upgrade the skill or use a different `--out` path."

## 10. Test corpus & `--selftest`

Ships under `skills/diagram/tests/`. `--selftest` runs the eval against every fixture and prints a diff vs snapshot. Used as a regression gate when the eval evolves.

### 10.1 Golden fixtures (~5 SVGs)

Hand-authored to pass all checks. Each has a sibling `<name>.expected.json`:

```json
{
  "codeScore": 0.94,
  "codeHardFails": [],
  "visionAssertion": "all items 1-6 pass"
}
```

`--selftest` asserts:
- Code metrics match `<name>.expected.json` exactly (within ±0.001 for floats).
- Vision review (when run; honored only when an LLM is available) returns 0 fails on items 1–6. Vision is asserted as binary, never snapshot-matched (stochastic).

### 10.2 Defect fixtures (~10 SVGs)

Each carries one intentional violation. Filename encodes the violation, e.g.:
- `node-overlap.svg`
- `edge-tunnel.svg`
- `font-too-small.svg`
- `low-contrast.svg`
- `palette-violation.svg`
- `off-grid.svg`
- `over-30-nodes.svg`
- `mixed-reading-direction.svg`
- `crossing-storm.svg`
- `arrowhead-inconsistent.svg`

`--selftest` asserts each defect produces the **expected specific failing metric**, not just "some failure". This catches the eval false-positive class where an unrelated check happens to flag.

### 10.3 Runner

`tests/run.py` loads each fixture, runs the metrics, diffs against the snapshot, and exits non-zero on any mismatch. Output is a compact pass/fail table. Reused by both manual `--selftest` invocation and any CI hook the user adds.

## 11. Convention checklist (from `create-skill`)

- [x] Save location: `skills/diagram/` (NOT `plugins/`)
- [x] Platform Adaptation section in SKILL.md (no AskUserQuestion → state assumption + proceed; no subagent → run vision review inline; no Playwright MCP → use `rsvg-convert`/`cairosvg`)
- [x] Description with natural triggers: "draw a diagram", "create an architecture diagram", "show how X flows", "diagram this", "make an SVG of this concept"
- [x] No hard plugin dependency — fully self-contained
- [x] No hard `AskUserQuestion` dependency — assumption fallback documented per phase
- [x] No hard MCP dependency on Playwright (rsvg/cairosvg fallback)
- [x] No pipeline diagram — standalone utility
- [x] Findings Presentation Protocol present (§7.4)
- [x] Anti-patterns section in style.md §5.9
- [x] Learnings load at startup (Phase 0)
- [x] Capture Learnings is a numbered terminal-gated phase (Phase 8)
- [x] No Workstream Enrichment phase (no Phase-0 workstream load — standalone)
- [x] Progress tracking instruction included (≥ 3 phases)
- [x] Target < 500 lines for SKILL.md (rubric, code-metrics, render details, sidecar schema all extracted to `eval/` and `reference/`)

## 12. Acceptance criteria for v1

- Generates a valid `.svg` that opens in any browser without errors.
- On 5 hand-tested inputs, the **combined gate** passes within at most 2 refinement loops on at least 4 of 5.
- All 10 defect fixtures correctly produce their **specific expected failing metric** (not just any failure).
- All 5 golden fixtures pass with code-metric snapshots within ±0.001 of `<name>.expected.json`.
- Side-by-side review of 3 different `/diagram` outputs shows visual consistency (palette, type, line weights, arrowheads, legend treatment match).
- Findings Presentation Protocol surfaces structured choices, not prose dumps.
- Renderer detection refuses to run when none of {Playwright MCP, rsvg-convert, cairosvg} is available, with a clear install hint.
- Sidecar JSON written for every successful run; tolerant read works against a synthetic v0 stub.
- `--approach` flag bypasses Phase 2 brainstorm; `--clear-cache` wipes only `~/.pmos/diagram-cache/`; `--selftest` exits non-zero on any fixture mismatch.

## 13. Residual risks

1. **Layout drift across full regenerations.** Mitigated for tweaks via the sidecar + extend-vs-redraw flow (§9, Phase 1). A user who deletes the sidecar and re-runs will still get a fresh layout. Acceptable.
2. **Vision reviewer flake on borderline items.** Item 7 is advisory specifically because it's content-driven; items 1–6 are tightly worded enough to be stable. If we still see flake, tighten the reviewer prompt template in `eval/rubric.md`; do not move to scoring.
3. **`--source` markdown extraction may pick up irrelevant entities** when the source doc is long. Mitigation: agent surfaces its extracted entity list to the user (via `AskUserQuestion` in the brainstorm step or prose-fallback) before drawing.
4. **Renderer install friction** for users who lack all three options. Documented up-front in SKILL.md and the install hint covers macOS/Linux/Python paths.
5. **Sidecar `concept` matching is fuzzy** (Phase 1). When in doubt the skill asks via collision AskUserQuestion rather than guessing.

## 14. Implementation order

1. `style.md` (single source of truth — drives every other file).
2. `tests/golden/` + `tests/defects/` + `tests/run.py` + `expected.json` snapshots (so the eval is testable from day 1).
3. `eval/code-metrics.md` (xml.etree-based metric impls; runs against tests/).
4. `eval/rubric.md` (vision reviewer prompt template + binary rubric).
5. `reference/render-to-raster.md` + `reference/svg-primer.md` + `reference/sidecar-schema.md`.
6. `examples/style-atoms/` (hand-authored).
7. `SKILL.md` (orchestrates the above; target < 500 lines; all phase logic).

Once `style.md` and the test corpus exist, the rest can be built incrementally with `--selftest` as the regression gate.
