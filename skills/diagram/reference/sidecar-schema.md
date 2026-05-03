# Sidecar Schema — `<slug>.diagram.json`

Written next to every successful SVG in Phase 7. Read in Phase 1 to power the extend-vs-redraw flow.

## Current schema (v1)

```json
{
  "schemaVersion": 1,
  "concept": "string — short paraphrase of the input description (≤ 240 chars)",
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
    { "from": "kebab-id", "to": "kebab-id", "label": "optional", "kind": "directed | bidirectional" }
  ],
  "positions": {
    "kebab-id": { "x": 0, "y": 0, "w": 0, "h": 0 }
  },
  "colorAssignments": {
    "category-name": "ink | ink-muted | accent | warn"
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
      "1": "pass", "2": "pass", "3": "pass",
      "4": "pass", "5": "pass", "6": "pass", "7": "pass"
    },
    "loopsRun": 1,
    "shippedWithWarning": false,
    "userOverrides": []
  },
  "createdAt": "2026-05-03T12:00:00Z",
  "createdBy": "pmos-toolkit:diagram@v1"
}
```

## Field semantics

- **`concept`** — used by Phase 1 to detect "same concept" re-runs. Comparison is fuzzy (case-insensitive, punctuation-stripped substring + Jaccard on tokens). When in doubt, prompt via collision AskUserQuestion.
- **`approach`** — verbatim from Phase 2 (or `--approach` flag). Surfaced in stdout for audit.
- **`alternativesConsidered`** — populated in Phase 2 when brainstorming runs; empty array when `--approach` is used.
- **`positions`** — post-transform absolute bboxes. Used by extend-mode to keep geometry stable when only colors/labels change.
- **`colorAssignments`** — explicit category→token mapping. Lets extend-mode preserve semantic color choices.
- **`userOverrides`** — strings recording any user override during the run, e.g. `"proceeded with 23 nodes despite split-prompt"`.

## Versioning policy

- **Read with same version** → use directly.
- **Read older version** → fields missing from older schema default sensibly (`alternativesConsidered: []`, `userOverrides: []`, etc.). Log one-line note `read sidecar v<N>; some fields defaulted`.
- **Read newer version** → refuse with: `"this sidecar was written by a newer /diagram (schemaVersion <N>). Upgrade the skill or use a different --out path."`

## Migration table

| From | To | Action |
|---|---|---|
| (none) | 1 | Initial — no migration needed |

When a v2 ships, add the row and document defaults for missing-on-old-read fields.
