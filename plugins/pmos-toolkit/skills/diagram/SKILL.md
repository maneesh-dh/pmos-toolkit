---
name: diagram
description: Generate a single SVG vector diagram from a free-form description (with optional source markdown) — architecture, flow, hierarchy, dependency, sequence, state, mental-model, etc. Brainstorms 2–3 structural framings from first principles, asks the user to pick, then drafts and self-evaluates against a hybrid rubric (deterministic SVG metrics with hard-fails + a 7-item binary vision rubric on a rendered raster) with up to 2 refinement loops. Applies a configurable theme (default `technical`; switch with `--theme editorial`) so every output is consistent. Standalone utility — does not load workstream context. Use when the user says "draw a diagram", "create an architecture diagram", "show how X flows", "make an SVG of this concept", "diagram this", or wants a vector visual of any system/flow/structure.
user-invocable: true
argument-hint: "<free-form description> [--source <path>] [--out <path>] [--approach <free-text>] [--theme technical|editorial] [--rigor high|medium|low] [--clear-cache] [--selftest]"
---

# `/diagram` — SVG Diagram Generator

**Announce at start:** "Using the diagram skill to generate an SVG from your description."

Produce one `.svg` file plus a `<slug>.diagram.json` sidecar that records the design decisions. Skill enforces a configurable theme (`themes/<theme>/theme.yaml` + `style.md`) and a hybrid eval (`eval/code-metrics.md` + `eval/rubric.md`). The skill is **standalone** — it does not load workstream context, does not gate any pipeline stage. Invoke any time you need a diagram.

---

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:

- **No `AskUserQuestion`:** state your assumption, document it in the sidecar, and proceed.
  - Phase 1 collision: default to `suffix` (write `<slug>-2.svg`).
  - Phase 1 same-concept: default to `redraw`.
  - Phase 2 brainstorm: pick the first framing you'd recommend; record alternatives in the sidecar's `alternativesConsidered`.
  - Phase 6 refinement findings: present as a numbered findings table with disposition column; do NOT silently self-fix.
  - Phase 6.5 terminal failure: default to `ship-with-warning`, prepend an XML comment to the SVG.
- **No subagents:** for Phase 5 vision review, run the reviewer call inline rather than dispatching a `general-purpose` subagent.
- **No Playwright MCP:** use `rsvg-convert` or `cairosvg` per `reference/render-to-raster.md`; refuse to run if none are available.

---

## Track Progress

This skill has multiple phases. Create one task per phase using your agent's task-tracking tool (e.g., `TodoWrite` in Claude Code, equivalent in other agents). Mark each task in-progress when you start it and completed as soon as it finishes — do not batch completions.

---

## Load Learnings

Read `~/.pmos/learnings.md` if it exists. Note any entries under `## /diagram` and factor them into your approach for this session.

---

## Phase 0 — Setup, args, hard-gate renderer detection

1. **Parse args.**
   - Positional: free-form description (required, unless `--clear-cache` or `--selftest` is the only arg).
   - Flags: `--source <path>`, `--out <path>`, `--approach <text>`, `--theme <name>` (default `technical`), `--rigor high|medium|low` (default `high`), `--clear-cache`, `--selftest`.
   - Derive `<slug>` = first 5–6 content words of the description, kebab-cased.
   - **Resolve `{docs_path}`**: read `.pmos/settings.yaml` in the current repo; if present, use its `docs_path` value (default in that file is `.pmos`). If `.pmos/settings.yaml` does not exist, fall back to `docs/pmos/` (create on demand).
   - Default `--out` = `{docs_path}/diagrams/<slug>.svg`. Create the `diagrams/` subdirectory if it doesn't exist.
   - The sidecar lives next to the SVG: `{docs_path}/diagrams/<slug>.diagram.json`.

2. **Special-mode shortcuts** (handle and exit):
   - `--clear-cache` → wipe `~/.pmos/diagram-cache/` (and only that directory). Print count of files removed. Exit.
   - `--selftest` → run `python3 skills/diagram/tests/run.py`. Exit with the runner's exit code.

3. **Renderer detection (HARD GATE).** In order:
   1. Playwright MCP — check whether `mcp__plugin_playwright_playwright__browser_navigate` is callable in this session.
   2. `rsvg-convert` — `command -v rsvg-convert >/dev/null 2>&1`.
   3. `cairosvg` — `python3 -c "import cairosvg" 2>/dev/null`.

   If none → REFUSE TO RUN. Print:
   ```
   /diagram requires an SVG renderer for vision review. Install one of:
     • Playwright MCP (preferred): add the playwright plugin to your Claude Code session
     • rsvg-convert (macOS):       brew install librsvg
     • rsvg-convert (Linux):       apt-get install librsvg2-bin
     • cairosvg (any platform):    pip install cairosvg
   ```
   Exit non-zero. Vision review is non-negotiable; without it half the eval is missing.

4. **Resolve `--theme`** (default `technical`). Load `themes/<theme>/theme.yaml` and validate it against `themes/_schema.json`. If the file is missing or schema validation fails, print the error and exit 2. The active theme governs palette, typography, stroke choices, connector dispatch, arrowhead style, and rubric overrides.

5. **Read `themes/<theme>/style.md`** end-to-end. You will be quoting its tokens throughout.

---

## Phase 1 — Comprehension + existing-output handling

1. **Read `--source` if provided.** Extract entities, relationships, and any explicit hierarchy or order. If the doc is long, surface your extracted entity list to the user (via `AskUserQuestion` "is this the right entity set?" with options Confirm / Refine / Add missing) before brainstorming. Prose-fallback: print the extracted list and proceed assuming it is correct unless contradicted in the next message.

2. **Existing-output check.** If `<out>.svg` already exists:
   - Look for sibling `<out>.diagram.json` sidecar; load via `read_sidecar()` (see `tests/run.py`). It returns `None` when the file is missing OR has a pre-v2 `schemaVersion` (v1 sidecars are intentionally ignored). It raises `ValueError` for any version newer than the current schema (refuse).
   - If `read_sidecar()` returned `None`, treat the sidecar as absent and skip directly to the **Different concept** branch below.
   - **Same concept** (sidecar `concept` field substantially matches current input — case-insensitive substring or ≥0.6 Jaccard on tokens):
     - `AskUserQuestion`: "Existing diagram is for the same concept. Extend with the new instruction, or redraw from scratch?"
       Options: **Extend** / **Redraw** / **Cancel**.
     - On **Extend**: read the existing SVG. Treat sidecar `positions` and `colorAssignments` as fixed. Apply the new instruction as a minimal patch (e.g., recolor a single node, add a single connector, relabel a node). Skip Phase 2 (no new brainstorm). Proceed to Phase 4 with the patched SVG.
     - On **Redraw**: discard the existing SVG (don't delete yet — overwrite at Phase 7). Use the sidecar's `approach` as a starting hint to Phase 2 but allow new framings.
     - On **Cancel**: exit 0.
   - **Different concept** (or sidecar absent / unreadable):
     - `AskUserQuestion`: "Output path collision. Overwrite, write to `<slug>-2.svg`, or cancel?"
       Options: **Overwrite** / **Suffix** / **Cancel**.

3. **Entity model.** From either `--source` or the description, build an internal list:
   ```
   entities = [{id, label, category}]
   relationships = [{from, to, label?, kind: directed|bidirectional, role?: contribution|emphasis|feedback|dependency|reference}]
   ```
   When the active theme has `connectors.mixingPermitted: true`, Phase 3 MUST assign a `role` to every relationship (default to `default` only when no other role fits). When `mixingPermitted: false`, `role` is optional and ignored at draw time. This becomes the sidecar's `entities` / `relationships` arrays in Phase 7.

---

## Phase 2 — Approach selection

If `--approach <text>` was passed: skip the brainstorm, use the supplied framing, announce it. Sidecar `alternativesConsidered` is `[]`.

Otherwise, **brainstorm 2–3 structurally distinct framings from first principles** for THIS specific content. Do not pick from a hardcoded list. Examples of the kind of dimensions you might vary (this is illustrative, not a menu):

- Hierarchy direction (top-down vs left-right vs radial).
- What's primary (the actor vs the artifact vs the trigger event).
- Granularity (groups-and-flows vs every-individual-node).
- Synchronous vs asynchronous edges (sequence vs dataflow).
- Nesting (containers around groups vs flat).

For each framing, write one paragraph: what it emphasizes, what it de-emphasizes, who it's best for. Then issue `AskUserQuestion`:

```
question: "Three ways to frame this diagram. Which lens?"
header: "Framing"
options:
  - { label: "<framing 1 short name>", description: "<one-line trade-off>" }
  - { label: "<framing 2 short name>", description: "<one-line trade-off>" }
  - { label: "<framing 3 short name>", description: "<one-line trade-off>" }
```

Prose-fallback: print the three framings as a numbered list, default to #1 if no response.

Record the chosen framing and the rejected ones in sidecar `approach` and `alternativesConsidered`.

---

## Phase 3 — Draft

1. **Choose canvas.** Pick from the active theme's `style.md` §5.7 by content shape:
   - 16:10 (1280×800) — flows, architectures, sequences (default).
   - 1:1 (1280×1280) — hierarchies, concept maps, radial.
   - 4:5 (1280×1600) — tall trees, deep stacks.
   Announce: "Canvas: 16:10 because the content is a 4-stage left-right pipeline."

2. **Place nodes.** Snap every coordinate to multiples of 4. Maintain ≥ 24px between distinct groups, ≥ 16px between siblings. Pad ≥ 32px from canvas edges.

3. **Author SVG by hand.** Use the scaffold in `reference/svg-primer.md`:
   - `xmlns`, `viewBox`, root `font-family`.
   - `<title>` as first child (a11y).
   - `<defs>` with single `<marker id="arrow">` reused everywhere.
   - `<style>` with the class palette from svg-primer.md.
   - Content elements.
   - Legend block (top-right) only if ≥ 2 categorical colors used.

4. **Apply the active theme's tokens strictly.**
   - Palette: only colors declared in the theme's `palette` block (`ink`, `inkMuted`, `warn`, `surface`, `surfaceMuted`, every `accents[].hex`, every `categoryChips[].hex`).
   - Typography: sizes and weights from `theme.typography.body` (and `display` / `mono` / `eyebrow` when defined). For the default `technical` theme that's 12 / 14 / 16 / 20 at weights 400 / 600.
   - Stroke: weights from `theme.nodeChrome.primaryStroke` and the theme's stated defaults (technical: 1 / 1.5 / 2).
   - Radii: from `theme.nodeChrome.primaryRadius` / chip radii (technical: 0 / 4 / 8).
   - Spacing: 4-px grid is global (4 / 8 / 16 / 24 / 32) — not theme-specific.

5. **Connector style.** Inspect `theme.connectors`:
   - If `mixingPermitted: false`, use a single style for the whole diagram — orthogonal for flows/architectures/sequences, curves for mind maps/networks/dependency graphs. Pick once and stick with it.
   - If `mixingPermitted: true`, assign every relationship a `role` (one of `contribution | emphasis | feedback | dependency | reference`; default to `default` when unsure) and look up `theme.connectors.byRole[role]` to get `{shape, stroke, dashed}`. All edges sharing a role MUST use the same lookup result — mixing within a role is forbidden.

6. **Color usage.** 1–4 colors as content needs. Use ONLY colors declared in the active theme's `palette` block. When the theme defines `palette.accents[].pinnedRole`, that mapping is fixed across every diagram drawn under the theme; never reassign a pinned-role accent per diagram. If ≥ 2 categorical colors are used → legend is mandatory.

7. **Write the SVG to a temp path** first (`<out>.svg.tmp`). Don't overwrite the real file until Phase 7.

---

## Phase 4 — Code-metric self-review

Run:

```bash
python3 -c "
import sys, json
sys.path.insert(0, 'skills/diagram/tests')
import run
print(json.dumps(run.evaluate('<out>.svg.tmp'), indent=2))
"
```

(Adjust path to wherever the skill repo lives.)

**Decision tree:**

- `hard_fails == []` AND `code_score >= 0.8` → proceed to Phase 5.
- Any `hard_fails` OR `code_score < 0.8` →
  - If node-count diagnostic is in [21, 30]: issue node-count split prompt now (`AskUserQuestion`: "This diagram has N nodes. Split into 2 diagrams or proceed?" — Split / Proceed-anyway / Cancel). Record any override in sidecar `userOverrides`.
  - Otherwise: enter Phase 6 with these findings as targets. Skip Phase 5 for now (vision review is wasted on a code-failing draft).

---

## Phase 5 — Vision review (binary rubric)

1. **Render** `<out>.svg.tmp` → `~/.pmos/diagram-cache/<slug>-<sha1>.png` per `reference/render-to-raster.md`. If the cache file already exists for this SVG content, reuse.

2. **Dispatch reviewer.**
   - `high`-rigor: dispatch a `general-purpose` subagent with the prompt template from `eval/rubric.md`. Pass the PNG and the source SVG.
   - `medium` / `low`-rigor: run the reviewer prompt inline.

3. **Reviewer returns** the JSON shape from `eval/rubric.md`:
   ```json
   {
     "items": { "1": {"verdict": "...", "evidence": "..."}, ... "7": ... },
     "blocker_count": <count of items 1-6 failing>,
     "top_priorities": [...]
   }
   ```

4. **Decision:**
   - `blocker_count == 0` → combined gate satisfied → proceed to Phase 7.
   - `blocker_count > 0` → enter Phase 6.

---

## Phase 6 — Refinement loop

**Loop budget by rigor tier** (from spec §6):

| Rigor | Up to N loops | Behavior |
|---|---|---|
| `high` (default) | 2 | Full protocol with subagent reviewer |
| `medium` | 1 | Inline reviewer |
| `low` | 0 | **Skip Phase 6 entirely** — proceed to Phase 7 with whatever fails exist; ship-with-warning |

For each refinement loop iteration:

1. **Aggregate findings** from Phase 4 hard_fails + Phase 5 reviewer items 1–6 fails.

2. **Findings Presentation Protocol** (mandatory):
   - Group by category. Max 4 questions per `AskUserQuestion` call. Issue multiple sequential calls for more findings.
   - Each question = one blocker. Options: **Apply fix as proposed** / **Modify fix** / **Skip** / **Defer to user notes**.
   - Open-ended findings ("rethink categorization") asked as a follow-up after the structured batch.
   - Prose-fallback: numbered findings table with disposition column; do NOT silently self-fix.

3. **Apply user-approved fixes** to `<out>.svg.tmp`. Each fix is a minimal SVG edit (don't redraw from scratch).

4. **Re-run Phase 4 + Phase 5.**

5. **Exit early on clean pass:** if `hard_fails == []` AND `code_score >= 0.8` AND `blocker_count == 0`, break the loop.

6. **Loop exhausted with fails remaining** → enter Phase 6.5 (high/medium only) or proceed to Phase 7 with warning (low rigor).

---

## Phase 6.5 — Terminal failure handler (high / medium rigor only)

Loops are exhausted and gating fails remain.

`AskUserQuestion`:

```
question: "After N refinement loops, the diagram still has gating fails. What now?"
header: "Terminal"
options:
  - Ship with warning: write the SVG with a leading XML comment listing remaining fails.
  - Try alternative framing: restart from Phase 3 using one of the brainstormed alternatives.
  - Abandon: delete the temp SVG, exit non-zero.
```

Prose-fallback: ship-with-warning by default.

If user picks **alt framing** → restart at Phase 2 with the next brainstormed approach pre-selected; loop budget is fresh. If even the alternative fails its terminal handler, default to ship-with-warning.

---

## Phase 7 — Finalize: SVG + sidecar

1. **Move** `<out>.svg.tmp` → `<out>.svg`. If shipped-with-warning, prepend an XML comment immediately after the `<?xml` declaration:
   ```xml
   <!-- DIAGRAM QUALITY WARNING: <comma-separated remaining fails> -->
   ```

2. **Write `<out>.diagram.json`** sidecar via `write_sidecar()` per `reference/sidecar-schema.md`:
   - `schemaVersion: 2`
   - `theme` — the active theme name (from `--theme`, default `technical`).
   - `mode` — `"diagram"` for vanilla draws; `"infographic"` when invoked with `--mode infographic`.
   - `concept`, `approach`, `alternativesConsidered`, `canvas`, `entities`, `positions`, `colorAssignments`, `evalSummary`, `createdAt` (ISO 8601 UTC), `createdBy: "pmos-toolkit:diagram@v2"`.
   - `relationships[]` includes `role` for every relationship that was assigned one in Phase 3 (mandatory under themes with `connectors.mixingPermitted: true`; optional otherwise).
   - `evalSummary.visionItems` uses stable rubric IDs (e.g. `"primary-emphasis": "pass"`) — see `eval/rubric.md`.

3. **Print final stdout** (one line of path + one line of eval summary):
   ```
   <absolute-path>/<slug>.svg
   Eval: PASS — code <score>, vision <N>/6 items pass (item 7 advisory: <pass|fail>), canvas <aspect>, <node-count> nodes
   ```
   Or, on shipped-with-warning:
   ```
   <absolute-path>/<slug>.svg
   Eval: WARNING — <comma-separated remaining fails>; <other summary>
   ```

---

## Phase 8 — Capture Learnings

**This skill is not complete until the learnings-capture process has run.** Read and follow `learnings/learnings-capture.md` (relative to the skills directory, i.e. `skills/diagram/learnings/learnings-capture.md` if present, else `~/.claude-personal/.../skills/learnings/learnings-capture.md` or the equivalent path in your environment).

Reflect on this session — surprising rendering behaviors, repeated user corrections, eval-rubric drift, framings that worked unusually well or badly, refinement-loop budget calibration. Proposing zero learnings is a valid outcome for a smooth session; the gate is that the reflection happens.

If a generic `learnings-capture.md` is not found, append entries directly to `~/.pmos/learnings.md` under a `## /diagram` section, one bullet per insight, with date and 1-line context.

---

## Anti-patterns (DO NOT)

- Do NOT use `AskUserQuestion` to ask "should I proceed?" — only to gather decisions or surface findings. Each question must have a clear default fallback for non-AskUserQuestion environments.
- Do NOT skip the renderer hard-gate. If no renderer is available, refuse to run; never silently downgrade to "code-only eval".
- Do NOT brainstorm from a hardcoded list of diagram types ("flowchart vs hierarchy vs swimlane"). Always reason from the specific content's structure.
- Do NOT copy the structure of any file in `themes/technical/atoms/` (or any theme's `atoms/` directory) — those are visual primitives, not templates. Re-derive layout each time.
- Do NOT regenerate the entire SVG when the user requests a tweak via the extend flow. Apply minimal patches preserving sidecar `positions`.
- Do NOT use colors outside the active theme's declared palette. The contrast metric will hard-fail any out-of-token combination, regardless of theme.
- Do NOT reassign pinned-role accents per diagram. When a theme defines `palette.accents[].pinnedRole` (e.g. editorial pins `feedback` to `#1E3A8A`), that mapping is permanent across every diagram drawn under the theme.
- Do NOT mix connector styles within a single role even when the theme permits mixed connectors. Each role uses one consistent style across the diagram.
- Do NOT use font sizes below 12px — even for "subtle annotations". Move the content to the legend or remove it.
- Do NOT write SVGs that include `<image>`, `<foreignObject>`, `<animate>`, `filter`, drop shadows, or gradients (themes' anti-patterns sections).
- Do NOT exceed 30 primary nodes. At 21–30 you MUST prompt for a split before proceeding.
- Do NOT mix orthogonal and curved connectors in one diagram. Pick one style and stick with it.
- Do NOT silently dump prose findings in Phase 6. Always use the Findings Presentation Protocol with structured options.
- Do NOT delete `~/.pmos/diagram-cache/` files outside of the explicit `--clear-cache` flag.

---

## File map

```
skills/diagram/
├── SKILL.md                       # this file (orchestrator)
├── eval/
│   ├── rubric.md                  # 7-item binary vision rubric + reviewer prompt template
│   └── code-metrics.md            # xml.etree-based metric specifications (impl in tests/run.py)
├── reference/
│   ├── svg-primer.md              # SVG authoring scaffold + gotchas
│   ├── render-to-raster.md        # detection + invocation for Playwright MCP / rsvg / cairosvg
│   └── sidecar-schema.md          # <slug>.diagram.json schema (schemaVersion: 1) + versioning policy
├── themes/                        # theme directories — each ships theme.yaml + style.md + atoms/
│   ├── _schema.json               # JSON Schema for theme.yaml (positive-list; rejects layout keys)
│   └── technical/                 #   default theme (was top-level style.md + examples/style-atoms/)
│       ├── theme.yaml
│       ├── style.md
│       └── atoms/                 # 8 visual primitives — NOT templates
└── tests/
    ├── golden/                    # 5 passing fixtures + .expected.json snapshots
    ├── defects/                   # 10 fixtures, one violation each
    └── run.py                     # eval impl + selftest runner (invoked by --selftest)
```
