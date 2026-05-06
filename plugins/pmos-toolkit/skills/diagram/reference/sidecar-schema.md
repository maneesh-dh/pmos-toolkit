# Sidecar Schema — `<slug>.diagram.json`

Written next to every successful SVG in Phase 7. Read in Phase 1 to power the extend-vs-redraw flow.

## Current schema (v2)

```json
{
  "schemaVersion": 2,
  "concept": "string — short paraphrase of the input description (≤ 240 chars)",
  "theme": "technical | editorial",
  "mode": "diagram | infographic",
  "approach": "string — chosen framing description as presented in Phase 2",
  "alternativesConsidered": [
    "string — framing 2 short description",
    "string — framing 3 short description"
  ],
  "canvas": {
    "aspect": "16:10 | 1:1 | 4:5",
    "width": 1280,
    "height": 800
  },
  "entities": [
    { "id": "kebab-id", "label": "Display Label", "category": "category-name-or-null" }
  ],
  "relationships": [
    {
      "from": "kebab-id",
      "to": "kebab-id",
      "label": "optional",
      "kind": "directed | bidirectional",
      "role": "contribution | emphasis | feedback | dependency | reference",
      "_svgId": "optional — SVG element id for role-style-consistency check"
    }
  ],
  "positions": {
    "kebab-id": { "x": 0, "y": 0, "w": 0, "h": 0 }
  },
  "colorAssignments": {
    "category-name": "ink | ink-muted | accent | warn | <theme accent name>"
  },
  "evalSummary": {
    "codeScore": 0.92,
    "codeHardFails": [],
    "softMetrics": {
      "edge_crossings": 1.0,
      "grid_snap": 0.97,
      "node_count": 1.0,
      "angular_resolution": 0.81
    },
    "visionItems": {
      "primary-emphasis": "pass",
      "clear-entry": "pass",
      "legibility": "pass",
      "legend-coverage": "pass",
      "arrowhead-consistency": "pass",
      "style-atom-match": "pass",
      "visual-balance": "pass"
    },
    "loopsRun": 1,
    "shippedWithWarning": false,
    "userOverrides": []
  },
  "createdAt": "2026-05-03T12:00:00Z",
  "createdBy": "pmos-toolkit:diagram@v2"
}
```

### Infographic-mode additions

When `mode: "infographic"`, the sidecar additionally carries the wrapper state needed for the Extend flow and post-hoc audit:

```json
{
  "mode": "infographic",
  "wrapperLayout": "editorial-v1",
  "wrappedText": {
    "eyebrow": "HARNESS ENGINEERING · SYSTEMS VIEW",
    "headline": "...",
    "lede": "..." ,
    "figLabel": "FIG. 1 — ...",
    "captions": [
      {"title": "...", "body": "...", "anchorColor": "#1E3A8A", "anchorElementId": "e1"}
    ],
    "footer": "..."
  },
  "captionAnchorMode": "color | ordinal",
  "captionAnchorRemaps": [
    {"from": "#FF00FF", "to": "ink", "reason": "color absent from diagram"}
  ],
  "captionCountClamp": {"from": 7, "to": 5, "reason": "drop-weakest"},
  "wrapperRubricResults": {
    "wrapper-typography-hierarchy": "pass",
    "wrapper-text-fit": "pass",
    "wrapper-figure-proportion": "pass",
    "wrapper-edge-padding": "pass"
  }
}
```

These fields are absent (not `null`) when `mode: "diagram"`.

## Field semantics

- **`schemaVersion`** — integer. v2 introduced `theme`, `mode`, `relationships[].role`, `relationships[]._svgId`, and stable rubric-ID keys for `visionItems`. v1 sidecars are not read (see Versioning policy).
- **`theme`** — name of the active theme (matches `themes/<theme>/theme.yaml`'s `name` field). Used by extend-mode to ensure the patch reuses the same theme tokens.
- **`mode`** — `diagram` (vector-only) or `infographic` (diagram wrapped with copy/captions/ordinal markers per `theme.infographic.layout`).
- **`concept`** — used by Phase 1 to detect "same concept" re-runs. Fuzzy comparison (case-insensitive, punctuation-stripped substring + Jaccard).
- **`approach`** — verbatim from Phase 2 (or `--approach`). Surfaced in stdout for audit.
- **`alternativesConsidered`** — populated when Phase 2 brainstorming runs; empty when `--approach` is used.
- **`relationships[].role`** — optional in `technical` (or any theme with `connectors.mixingPermitted: false`), required in editorial-style themes. Drives `theme.connectors.byRole[role]` lookup at draw time.
- **`relationships[]._svgId`** — plan-level binding field. Underscore prefix signals it is NOT a semantic property of the relationship; it exists so the `role-style-consistency` rubric add-item can map sidecar role tags to SVG element IDs without re-clustering strokes.
- **`positions`** — post-transform absolute bboxes. Used by extend-mode to keep geometry stable when only colors/labels change.
- **`colorAssignments`** — category→token mapping. Token names should be valid within the active theme's palette.
- **`evalSummary.visionItems`** — keyed by stable rubric IDs (see `eval/rubric.md`). v1's numeric keys (`"1".."7"`) are not supported.
- **`userOverrides`** — strings recording any user override during the run.

## Versioning policy

- **Read same version (v2)** → use directly.
- **Read older version (v1)** → **treat as absent**. The Phase 1 collision logic falls through to the missing-sidecar path (overwrite/suffix prompt or fresh-draw). v1 is not migrated; rationale is in the design doc D5.
- **Read newer version (>2)** → refuse with: `"this sidecar was written by a newer /diagram (schemaVersion <N>). Upgrade the skill or use a different --out path."`

## Migration table

| From | To | Action |
|---|---|---|
| (none) | 1 | Initial — no migration needed |
| 1 | 2 | **Not supported.** v1 sidecars are ignored on read; rewrite via a fresh `/diagram` run if needed. |
