# /diagram — Themes + Infographic Mode

**Date:** 2026-05-06
**Skill:** `plugins/pmos-toolkit/skills/diagram/`
**Status:** Design — pending implementation plan

---

## 1. Problem

The `/diagram` skill ships a single hard-locked house style: white surface, single accent (`#2563EB`), single connector aesthetic per diagram (orthogonal XOR curved), sans-serif throughout. The user surfaced a reference aesthetic that breaks several of those rules deliberately and looks markedly better for editorial/blog-post contexts:

- Cream surface with a dashed outer container framing the whole scene.
- Mono-uppercase eyebrow labels above each major group.
- Two co-equal accents (deep blue + red-orange) carrying distinct semantic roles.
- Solid-black "computation" blocks for terminal/model nodes.
- Pastel category chips (peach + lilac) for stacked fragment lists.
- Mixed connector aesthetics in one diagram, keyed to semantic role (curved black fan-ins, straight red emphasis edge, dashed blue return-loop).
- Optional editorial wrapper around the diagram: eyebrow → headline → lede paragraph → FIG-numbered diagram → bottom legend → 4-column annotated captions → footer kicker.

The current skill cannot produce this look without breaking its own contract. We need themability and an optional infographic wrapper, without disturbing the parts of the skill that work (Phase 2 brainstorming, layout reasoning, eval loop, sidecar discipline).

## 2. Goals & Non-Goals

**Goals.**
- Add named, swappable visual themes. v1 ships two: `technical` (current style, default) and `editorial` (the new cream/dashed/two-accent style).
- Themes own visuals only. Layout still comes from Phase 2's brainstormed framing on the actual content. A radial mind map under the editorial theme stays a radial mind map — it just gets cream surface, dashed boundary, and mono eyebrows.
- Add an optional infographic mode that wraps the diagram in editorial scaffolding (eyebrow, H1, lede, FIG label, legend, 4-column captions, footer) and emits a single self-contained SVG.
- Preserve full backward compatibility: with no flags, the skill behaves identically to today.

**Non-goals (v1).**
- User-authored themes outside the repo (would need a `~/.pmos/diagram-themes/` discovery path).
- HTML or PDF infographic output.
- Infographic mode under the `technical` theme.
- More than one infographic layout per theme.
- Animated, interactive, or multi-page diagrams.

## 3. User Surface

Two new flags:

- `--theme <name>` — selects which theme to apply. Default `technical`. v1 valid values: `technical`, `editorial`.
- `--mode diagram|infographic` — default `diagram` (current behavior). `infographic` only valid when the active theme declares `infographic.supported: true`. Otherwise: clear error in Phase 0, exit non-zero.

No other flag changes. No breaking changes to existing flags.

## 4. Architecture

Three new concepts; no existing layout logic disturbed.

1. **Themes** — named bundles of visual tokens at `skills/diagram/themes/<name>/`. Each theme has `theme.yaml` (machine-readable tokens + rubric overrides), `style.md` (human-readable spec, like the current top-level one), and optional `atoms/` (theme-specific style atoms). The current top-level `style.md` moves to `skills/diagram/themes/technical/style.md`.

2. **`--theme <name>` flag** — selects which theme to apply. Default `technical` (preserves all current behavior). The skill loads `themes/<name>/theme.yaml` in Phase 0 alongside global structural rules.

3. **`--mode diagram|infographic` flag** — when `infographic`, after the diagram is finalized in Phase 6, a new **Phase 6.6 — Editorial wrapper** runs: skill auto-generates eyebrow + H1 + lede paragraph + 4 caption columns + footer kicker from the description and the diagram's entity list, then composes a single SVG that embeds the diagram inside an editorial scaffold.

**Hard separation kept:**
- **Layout** = Phase 2 framings (unchanged).
- **Theme** = visuals only. Themes never dictate node positions or reading direction.
- **Mode** = whether to emit a bare diagram or wrap it in editorial chrome.

**Globally locked rules (not overridable by any theme):** WCAG AA contrast, ≥12px text, ≤30 primary nodes, 4-px grid snap, no decorative shadows/gradients, `<title>` first child for a11y, max 1280px width. `foreignObject` is permitted only inside the infographic wrapper region for rich text wrapping when font-metric line-breaking is unavailable; never for decoration in the diagram interior.

**Theme-overridable knobs:** palette (incl. # of accents), surface color, typography stack/weights/sizes, stroke weights, corner radii, connector aesthetic (orthogonal / curved / mixed-permitted), arrowhead style, container chrome (none / framed / dashed-boundary), eyebrow label treatment, category-chip styling, legend placement (top-right / bottom).

**Sidecar gains a `theme` field** recording which theme drew the SVG. Schema bumped to `schemaVersion: 2`. Tolerant-read in Phase 1 still accepts v1 sidecars — they are treated as `theme: "technical"`, `mode: "diagram"` on read. v2 is what is written going forward.

## 5. `theme.yaml` Schema

Validated against `themes/_schema.json` at load time.

```yaml
name: editorial
displayName: "Editorial / Cream"
extends: technical          # optional; inherit then override
surface:
  background: "#F4EFE6"
  containerChrome: dashed   # none | framed | dashed
  containerStrokeColor: "#9CA3AF"
  containerStrokeDasharray: "4 4"
palette:
  ink: "#0F172A"
  inkMuted: "#475569"
  accents:                  # ordered list; theme declares how many it permits
    - { token: accent-primary,  hex: "#1E3A8A", role: "memory/loop edges" }
    - { token: accent-emphasis, hex: "#D9421C", role: "fragment/inject path" }
  warn: "#B91C1C"
  categoryChips:
    - { token: chip-warm, hex: "#F5C9B8", textOn: ink }
    - { token: chip-cool, hex: "#DCE0F0", textOn: ink }
    - { token: chip-ink,  hex: "#0F172A", textOn: surface }
typography:
  display:    { stack: "Inter Tight, ui-sans-serif, system-ui, sans-serif", weight: 700, sizes: [28, 36, 44] }
  body:       { stack: "Inter, ui-sans-serif, system-ui, sans-serif",       weights: [400, 600], sizes: [12, 14, 16, 20] }
  eyebrow:    { stack: "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace", weight: 400, size: 12, transform: uppercase, letterSpacing: 0.08 }
connectors:
  styles: [orthogonal, curved]   # both permitted in same diagram
  defaultEmphasisColor: accent-emphasis
  defaultLoopColor: accent-primary
  loopMayBeDashed: true
arrowheads:
  style: filled-triangle
  sizes: { default: "8x6", emphasis: "10x7" }
chips:
  enabled: true
  cornerRadius: 4
  paddingX: 8
  paddingY: 4
nodeChrome:
  primaryStroke: 1.5
  primaryRadius: 6
  computationBlock:
    fill: chip-ink
    text: surface
    radius: 4
rubricOverrides:
  waive:
    - "single-accent"
    - "single-connector-style"
  add:
    - { id: "eyebrow-mono-uppercase-applied",   prompt: "Each major group has a monospace uppercase eyebrow label", evidenceHint: "look above container groups" }
    - { id: "container-chrome-matches-theme",   prompt: "Outer container uses the theme's dashed boundary", evidenceHint: "outermost rect should be dashed" }
infographic:
  supported: true
  layout: editorial-v1
```

The `technical` theme's `theme.yaml` codifies the current `style.md` tokens with `waive: []`, `add: []`, `infographic.supported: false`.

**Inheritance semantics for `extends:`.** If a theme declares `extends: <parent>`, the loader reads the parent's `theme.yaml` first and merges the child on top. Scalar keys are replaced. Lists are **replaced wholesale**, not concatenated (so a child that wants to add one accent must redeclare the full accent list). Nested objects merge key-by-key. v1 ships no theme that uses `extends:` (both `technical` and `editorial` are standalone); the field is reserved for future user-authored themes.

## 6. Editorial Theme — Defining Moves

These are the visual moves that distinguish the editorial theme. Each is enforced by `theme.yaml` tokens or theme-added rubric items.

1. **Cream surface** with a **dashed outer container** wrapping the entire diagram (rule: dashed rect inset 16px from canvas edge; stroke `#9CA3AF` 1px dasharray `4 4`).
2. **Mono-uppercase eyebrows** above each major group (e.g., `EXTERNAL CONTEXT (objects we populate)`, `HARNESS · system of blocks…`) — replaces decorative section titles.
3. **Two co-equal accents**: deep blue (`#1E3A8A`) for memory/loop semantics, red-orange (`#D9421C`) for retrieve/shape/inject. Author chooses which semantic role each accent carries at draft time; sidecar records the assignment.
4. **Solid-black "computation" blocks** (`chip-ink`) for terminal/model nodes — high-contrast endpoint marker.
5. **Pastel category chips** (peach + lilac) for stacked fragment-list rows inside containers — replaces plain bordered rectangles when content is a list of categorical items.
6. **Mixed connector aesthetic permitted, keyed by semantic role**: black curved beziers for fan-in convergence, straight red emphasis edge for the primary path, dashed blue return-loop for feedback. Each *role* uses a consistent style throughout one diagram; mixing within a single role is forbidden.
7. **Inline label-on-top + descriptor-below** node pattern (e.g., **System prompt** / *base + user-appended*) instead of single-line labels.

**Layout independence.** A radial mind map under the editorial theme would still have cream + dashed boundary + mono eyebrows + the two-accent system, but no left-fan-in or right-computation-block — those came from this specific content's pipeline shape, not from the theme.

## 7. Infographic Mode (Phase 6.6)

**When it runs.** After Phase 6 produces a clean diagram and before Phase 7 finalizes. Only if `--mode infographic` AND the active theme declares `infographic.supported: true` AND `infographic.layout` resolves to a layout file under `themes/<theme>/infographic/<layout>.md`. Otherwise the skill emits a clear error in Phase 0 and exits.

**Output.** A single SVG at `<out>.svg` whose viewBox is enlarged to host the editorial scaffold; the diagram is embedded as a nested `<g>` block at its native coordinates, translated to the figure region. No HTML, no separate files.

**Editorial-v1 layout grid** (defined in `themes/editorial/infographic/editorial-v1.md`):

```
canvas: 1280 wide, height computed (typically 1600–2000)
margins: 64 left/right, 56 top, 48 bottom
zones, top→bottom:
  ZONE_EYEBROW   (24h)   mono uppercase, ink-muted, letter-spaced
  ZONE_HEADLINE  (auto)  display 36–44, weight 700, ink, max 2 lines
  ZONE_LEDE      (auto)  body 16, weight 400, ink, max 5 lines, bold inline phrases permitted
  ZONE_FIG_LABEL (16h)   mono "FIG. 1 — <caption>"
  ZONE_DIAGRAM   (auto)  the Phase 6 diagram, scaled to fit width with 16px container inset
  ZONE_LEGEND    (32h)   horizontal swatch row, drawn from theme + actual colors used
  ZONE_CAPTIONS  (auto)  4 columns, each with 2px ink-muted left rule color-matched to a diagram element, body 13/400, max ~80 words/col
  ZONE_FOOTER    (16h)   mono uppercase footer kicker
```

Vertical rhythm uses the 8-px sub-grid (zones snap to multiples of 8); horizontal uses a 12-column grid for the captions block (3 cols per caption).

**Auto-generated text.** After Phase 6 closes, the skill assembles a generation prompt with the original description, `--source` markdown if provided, the entity model + relationships, the chosen Phase 2 framing, and the color-to-element assignments from the sidecar. It generates a JSON object:

```json
{
  "eyebrow": "HARNESS ENGINEERING · SYSTEMS VIEW",
  "headline": "Harness, Memory, Context Fragments, & The Bitter Lesson",
  "lede": "The context window is a **box we do computation on**. Everything outside it…",
  "figLabel": "FIG. 1 — MEMORY & CONTEXT FRAGMENTS IN THE HARNESS",
  "captions": [
    { "anchorColor": "ink",             "title": "Context window = computation box.", "body": "..." },
    { "anchorColor": "accent-primary",  "title": "Memory & Search.",                   "body": "..." },
    { "anchorColor": "accent-emphasis", "title": "Fragments guide computation.",       "body": "..." },
    { "anchorColor": "accent-primary",  "title": "Search: the bitter lesson.",         "body": "..." }
  ],
  "footer": "HARNESS ENGINEERING · DIAGRAM"
}
```

**User-review checkpoint** (the only added gate vs. pure-diagram mode). `AskUserQuestion`: "Generated infographic copy — accept, edit a field, or regenerate?"

- **Accept** → draw.
- **Edit** → present each field one at a time for inline edit (one `AskUserQuestion` per field with current text in the description; user picks Keep / Replace / Skip-this-field, "Other" lets them rewrite).
- **Regenerate** → re-prompt the model once with whatever feedback the user types.

Prose-fallback (no `AskUserQuestion`): print the JSON, accept by default, allow the user to reject in their next message.

**Caption-to-diagram color mapping rule.** Each caption's `anchorColor` MUST be a token actually used in the diagram. The wrapper draws each caption's left rule in that token's color, so the reader can visually pair each blurb to a path/node in the figure. If the model returns a caption with a color not present, the skill replaces it with `ink` and notes the remap in the sidecar.

**Lede inline-bold phrases.** The model returns markdown-bold (`**...**`) inline; the renderer parses runs and sets bold-weight `<tspan>`s within the `<text>` element. No other markdown features supported in v1.

**Text wrapping.** The skill computes wrap points from font metrics where available; if no font-metrics library is available, it uses a conservative 0.55em-per-char heuristic with ~5% slack. `foreignObject` is permitted as a fallback only inside the infographic wrapper text zones — never in the diagram interior.

**Re-running Phase 4/5 on the wrapped output.** Code-metrics runs on the full composite SVG (not just the diagram interior) to catch new violations the wrapper might introduce (off-grid text, contrast on the cream surface, etc.). Vision rubric does NOT re-run on the wrapped image — wrapper layout is deterministic and rubric items are diagram-focused.

**Sidecar additions for infographic mode:**
```
mode: "infographic"
wrapperLayout: "editorial-v1"
wrappedText: { eyebrow, headline, lede, figLabel, captions[], footer }
captionAnchorRemaps: [...]   # any forced replacements
```

## 8. Rubric Override Loader

`eval/rubric.md` becomes generic (theme-agnostic). The 7 items get stable IDs:

| ID | Item |
|---|---|
| `legibility` | All text ≥ 12px, no rotation > 30°, contrast ≥ AA |
| `hierarchy` | Visual weight matches conceptual importance |
| `whitespace` | Groups separated, no kissing edges |
| `single-accent` | Exactly one accent color used |
| `single-connector-style` | Orthogonal XOR curved, not mixed |
| `arrowhead-consistency` | One marker style throughout |
| `informational-fit` (advisory) | Diagram answers the question implied by the description |

In Phase 5, the reviewer prompt is templated with the active theme's `rubricOverrides.waive` list. Waived items are dropped from the rubric for that run; the reviewer sees only the items that apply. Waived items are recorded in the sidecar `evalSummary.waivedItems` so it is auditable why a diagram passed without a check the reader might expect.

`rubricOverrides.add` lets a theme inject extra binary checks. Each added item is one YAML row: `{ id, prompt, evidenceHint }`. The loader concatenates them into the reviewer prompt. Added items count toward `blocker_count`.

The `technical` theme declares `waive: []` and `add: []`, so its behavior is identical to today.

## 9. Selftest Changes (`tests/run.py`)

- New parameter: `theme` name. Defaults to `technical` to preserve current golden tests.
- `evaluate(svg_path, theme="technical")` reads `themes/<theme>/theme.yaml` and applies palette + typography + stroke validation against the theme's tokens, not a hardcoded list.
- New golden fixtures under `tests/golden/editorial/`:
  - `editorial-flow-fanin.svg` — the reference-style left-fan-in pipeline.
  - `editorial-radial-mindmap.svg` — radial layout with editorial chrome (proves theme ≠ layout).
  - `editorial-infographic-full.svg` — full wrapper with captions.
- New defects under `tests/defects/editorial/`:
  - `cream-but-mixed-connectors-within-one-role.svg` — mixed connectors used outside the role-consistent rule.
  - `infographic-caption-color-not-in-diagram.svg` — caption anchor color absent from figure.
  - `eyebrow-not-uppercase.svg` — fails the editorial-added rubric item.
- Existing golden tests run unchanged under the technical theme.

## 10. Migration Plan

1. Move `skills/diagram/style.md` → `skills/diagram/themes/technical/style.md` (verbatim, no content change).
2. Create `skills/diagram/themes/technical/theme.yaml` — codifies the current `style.md` tokens with `waive: []`, `add: []`, `infographic.supported: false`.
3. Replace `skills/diagram/style.md` with a thin pointer file (`# This file moved. See themes/<theme>/style.md`). Remove after one release cycle.
4. Move `examples/style-atoms/` → `themes/technical/atoms/`. Editorial gets its own `themes/editorial/atoms/` seeded from the reference's repeating motifs.
5. Sidecar schema bumped to `schemaVersion: 2`. Tolerant-read in Phase 1 still accepts v1 sidecars (treated as `theme: "technical"`, `mode: "diagram"` on read).
6. SKILL.md updated:
   - Phase 0 reads theme; rejects `--mode infographic` if theme doesn't support it.
   - Phase 3 cites theme tokens instead of hardcoded ones.
   - Phase 5 reviewer prompt is theme-aware.
   - Phase 6.6 added (editorial wrapper).
   - Anti-patterns section adjusted: "do not mix connectors" becomes "do not mix connectors unless the active theme permits role-keyed mixing; even then, mixing within a single role is forbidden".

## 11. File-Tree Diff

```
skills/diagram/
├── SKILL.md                               (edited: phases 0, 3, 5, 7 + new 6.6)
├── style.md                               (replaced with pointer; removed next release)
├── themes/                                (NEW)
│   ├── _schema.json                       (NEW — JSON Schema for theme.yaml)
│   ├── technical/
│   │   ├── theme.yaml                     (NEW — codifies current style.md)
│   │   ├── style.md                       (MOVED from top level)
│   │   └── atoms/                         (MOVED from examples/style-atoms/)
│   └── editorial/                         (NEW)
│       ├── theme.yaml                     (NEW)
│       ├── style.md                       (NEW)
│       ├── atoms/
│       │   ├── eyebrow-mono.svg
│       │   ├── dashed-container.svg
│       │   ├── pastel-chip-stack.svg
│       │   ├── computation-block.svg
│       │   └── return-loop-arrow.svg
│       └── infographic/
│           └── editorial-v1.md            (NEW — wrapper layout spec)
├── eval/
│   ├── rubric.md                          (edited: stable IDs, theme-aware loader)
│   └── code-metrics.md                    (edited: token tables sourced from theme.yaml)
├── reference/
│   ├── svg-primer.md                      (unchanged)
│   ├── render-to-raster.md                (unchanged)
│   └── sidecar-schema.md                  (edited: v2 schema, mode/theme/wrappedText/wrapperLayout)
├── examples/
│   └── style-atoms/                       (MOVED into themes/technical/atoms/)
└── tests/
    ├── golden/
    │   ├── (existing 5 fixtures unchanged, run as theme=technical)
    │   └── editorial/                     (NEW — 3 fixtures)
    ├── defects/
    │   ├── (existing 10 fixtures unchanged)
    │   └── editorial/                     (NEW — 3 fixtures)
    └── run.py                             (edited: theme param, theme.yaml-driven validation)
```

## 12. Backward Compatibility

- No flags: behaves exactly as today (technical theme, diagram mode).
- v1 sidecars: read transparently, written as v2.
- Existing golden tests: pass unchanged.
- Existing CLAUDE.md / docs references to `style.md`: pointer file keeps them resolvable for one release cycle.

## 13. Risks & Open Questions

- **Font availability across renderers.** `Inter Tight` and `JetBrains Mono` are not guaranteed on every host. Decision: use system-only font stacks; accept slight per-OS rendering differences. Vision review runs against rasterized output, so any catastrophic fallback (e.g., serif body) will be caught by the rubric.
- **Two-accent contrast pairings.** The editorial theme's `#1E3A8A` and `#D9421C` against `#F4EFE6` cream both pass AA; this should be verified by the contrast metric on every editorial diagram, not just trusted from the theme file.
- **Caption text quality variance.** Auto-generated captions can be bland or off-message. The user-review checkpoint mitigates this in v1; if it proves insufficient in practice, a future iteration can add a `--captions <path>` override.
- **Wrapper text wrapping accuracy without font metrics.** The 0.55em heuristic may overflow narrow columns for unusually wide glyph runs. The composite SVG re-runs Phase 4 metrics, which will catch overflow against zone bounds.

## 14. Out of Scope (v1)

- User-authored themes outside the repo.
- HTML or PDF infographic output.
- Infographic mode for the technical theme.
- More than one infographic layout per theme.
- Animated/interactive diagrams.
- `--captions <path>` user override for infographic copy.
