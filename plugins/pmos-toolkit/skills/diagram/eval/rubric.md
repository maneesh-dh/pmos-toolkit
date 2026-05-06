# Vision Rubric — 7-Item Binary Review

This is the rubric the vision-reviewer subagent (or inline reviewer call) applies to the rendered PNG of a `/diagram` output.

**No 0–5 scoring.** Each item is binary `pass | fail` plus a one-sentence justification grounded in concrete pixel/element evidence (coordinates, label text, or quadrant references).

---

## Reviewer prompt template

When `high`-rigor: dispatch a `general-purpose` subagent. When `medium`/`low`-rigor: run inline. Either way the prompt is:

```
You are reviewing a rendered diagram against a fixed rubric. You will be given:
- A PNG of the diagram (rendered at canonical canvas dimensions).
- The source SVG (for grounding citations to element ids/coords).
- The diagram's stated `concept` and chosen `approach`.

For each of the 7 rubric items below, return:
- "pass" or "fail"
- exactly one sentence of justification citing concrete evidence
  (pixel coordinates, label text, named element, or canvas quadrant).
  Examples:
    - "fail — node 'auth-svc' at (~410,288) is occluded by the connector to 'gateway'"
    - "pass — only 'requirements' node uses 8px corner radius and accent fill, others are 4px ink-muted"
    - "fail — top-left and bottom-right quadrants are empty (~38% canvas), nodes cluster center"

Items 1–6 are GATING. Item 7 is ADVISORY (reported but does not gate).

Output JSON only:
{
  "items": {
    "1": {"verdict": "pass|fail", "evidence": "..."},
    ...
    "7": {"verdict": "pass|fail", "evidence": "..."}
  },
  "blocker_count": <count of items 1-6 that failed>,
  "top_priorities": ["<id of most-important fix>", ...]  // up to 3, in order
}

Do NOT speculate beyond what you can see in the PNG/SVG. If an item is genuinely
ambiguous, lean toward "pass" but state the ambiguity in evidence.
```

---

## The 7 items

### 1. Primary node emphasis (gating)

> Is there exactly one visually-emphasized "primary" node, distinguished by size OR weight OR position OR color (`accent`)?

**Pass** if the diagram has a clear hero node — usually the input/start of a flow, the root of a hierarchy, or the question being answered.
**Fail** if every node looks equally important (no hero) OR multiple nodes claim primary status (competing heroes).

Edge case: monochrome diagrams of fully symmetric content (e.g. a 4-node round-trip) may have no primary by design — agent must declare this in the sidecar `approach` field, in which case auto-pass.

### 2. Clear starting point (gating)

> Does the diagram have a clear starting point — top-left node for left-right flows, top-center node for top-down hierarchies, an explicitly labeled "start" / "input" / "user", or the primary node from item 1 if it doubles as the entry?

**Pass** if a viewer could finger-trace where to begin reading.
**Fail** if entry is genuinely ambiguous.

Mind-map / radial diagrams pass automatically if the center node is the starting point.

### 3. Label legibility at 50% scale (gating)

> Is every text label fully legible at 50% raster scale (no clipping, no occlusion by other elements, no overlap with connectors)?

**Pass** if every word reads at half-size.
**Fail** if any label is clipped, hidden, or runs together with another label/connector.

The 12px-min font rule is enforced separately by the code metric; this item catches occlusion that code can't see.

### 4. Legend coverage (gating, N/A in monochrome)

> Does each color used in the diagram appear in the legend with a clear meaning? (Auto-pass if only `ink` + at most one of `accent`/`warn` is used.)

**Pass** if the legend explains every category color.
**Fail** if a color appears in the diagram but not the legend, OR the legend lists colors not actually used.

### 5. Arrowhead consistency (gating)

> Are arrowheads consistently directional? (No mix of bidirectional + directional connectors without a legend explanation. No connectors lacking arrowheads where direction is implied.)

**Pass** if all connectors use the same arrowhead style and direction is obvious.
**Fail** if some connectors are arrowed and others aren't (without legend), or some are double-headed and others single-headed inconsistently.

### 6. Style atoms match (gating)

> Does the diagram match the active theme's reference style atoms in `themes/<theme>/atoms/` — palette tokens, stroke weights, type scale, corner radii, edge label pill style, legend block style?

**Pass** if a side-by-side with the style atoms shows the same visual vocabulary.
**Fail** if shapes have wrong corner radii, stroke weights deviate, type sizes are off-scale, or legend formatting differs from the reference.

### 7. Visual balance (advisory only)

> Is the largest empty quadrant ≤ 35% of canvas area AND the densest 25% region ≤ 60% of nodes?

Mentally split the canvas into a 2×2 grid. Estimate empty-area percentage of the largest empty quadrant. Estimate node density of the densest quartile.

**Pass** if both thresholds hold.
**Fail** report only — does NOT gate.

This item is advisory because some content shapes (deep trees, hub-and-spoke) are intrinsically asymmetric. Failing it is a signal, not a blocker.

---

## Pass condition

The vision rubric **passes** when items 1–6 all `pass` (item 7 may pass or fail).

If any of items 1–6 `fail`:
- The reviewer's `top_priorities[]` list seeds the Phase 6 Findings Presentation Protocol.
- SKILL.md groups failures by category, presents up to 4 per `AskUserQuestion` call with options Apply / Modify / Skip / Defer.
- Loop continues until pass OR loop budget exhausted (then Phase 6.5 terminal handler).

---

## Anti-flake guidance for the reviewer

- **Always cite concrete evidence.** "Looks unbalanced" is not acceptable; "top-right quadrant is empty (~40%) while bottom-left has 6 of 8 nodes" is.
- **Do not invent failures.** If you can't find concrete evidence, the item passes.
- **Do not score politeness.** Items don't have shades; they pass or they don't.
- **When two items would catch the same issue,** report fails on each independently. The deduplication happens later in the Findings Protocol.
