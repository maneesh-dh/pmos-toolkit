# Plan — /wireframes style extraction & screenshot input

**Spec:** `docs/specs/2026-04-30-wireframes-style-and-screenshot-input-design.md`
**Target:** `plugins/pmos-toolkit/skills/wireframes/SKILL.md` (+ small reference files)

## Files touched

1. `plugins/pmos-toolkit/skills/wireframes/SKILL.md` — the bulk of the work; description, argument-hint, Phase 1 additions, new Phase 2.5, Phase 3 generator briefing tweaks, anti-patterns.
2. `plugins/pmos-toolkit/skills/wireframes/reference/style-extraction.md` — **new** — extractor procedure (what to read, how to score confidence, output schema, fallback rules).
3. `plugins/pmos-toolkit/skills/wireframes/reference/screenshot-ingestion.md` — **new** — ingestion procedure (vision prompt, output format for `source-screens.md`, journey-anchoring rules).
4. `plugins/pmos-toolkit/skills/wireframes/assets/wireframe.css` — **inspect only**; confirm CSS variables are named consistently so `house-style.css` can override them. Edit only if a needed variable doesn't exist yet.

No new dependencies. No code (skill is markdown).

## Tasks

### Task 1 — Inspect `wireframe.css` for override surface

Read `assets/wireframe.css`. Confirm CSS variables exist for: primary color, background, foreground, muted, border, destructive, radius, font-sans, font-mono. If any are missing or hard-coded, add them as `:root` custom properties with current values as defaults so a small `house-style.css` override file can re-skin the wireframes.

**Verify:** grep `--` declarations in the file; cover the six color tokens + radius + font-family.

### Task 2 — Write `reference/style-extraction.md`

New file. Sections:
- "When this runs" (Phase 2.5 trigger conditions, copied from spec)
- "Detection algorithm" (frontend candidate enumeration heuristic)
- "Reading the source" (which files to read in priority order; sample read budget cap: ~20 files / ~30KB total to keep subagent context tight)
- "Output schema" (the `house-style.json` shape from spec)
- "Generating `house-style.css`" (mapping from JSON tokens to CSS variable overrides; concrete example)
- "Confidence rules" (when to write empty source, when to flag for user review)
- "Screenshot fallback" (when no host frontend, infer from screenshots)

**Verify:** file exists, all sections present, JSON example parses, CSS example is syntactically valid.

### Task 3 — Write `reference/screenshot-ingestion.md`

New file. Sections:
- "Inputs" (`--screenshots` flag + inline attached images)
- "Vision-extraction prompt" (the exact prompt template the model uses to describe a screenshot — structure, components, state, device)
- "`source-screens.md` format" (one section per image, fenced)
- "Journey anchoring protocol" (the AskUserQuestion flow + platform fallback)
- "Generator briefing" (what to pass to Phase 3 subagents for an anchored component)

**Verify:** file exists, vision prompt is concrete enough to be used as-is, output format example present.

### Task 4 — Edit `SKILL.md`: metadata

- Update `description` to mention style extraction and `--screenshots`.
- Update `argument-hint` to add `[--screenshots <path>]`.

**Verify:** frontmatter still parses, `argument-hint` line shows the new flag.

### Task 5 — Edit `SKILL.md`: Phase 1 (screenshot ingestion)

Add a step "1.5 Ingest screenshots (if provided)" after the existing Step 3 (read req doc) and before Step 4 (confirm understanding):
- Detect `--screenshots` flag values + any attached images.
- For each: copy to `{feature_folder}/wireframes/assets/source-screens/`, run vision extraction per `reference/screenshot-ingestion.md`, append to `source-screens.md`.
- Defer journey-anchoring to the journey-confirmation step (Step 4) — when summarizing journeys, propose anchor mappings.

Also extend Step 4 (confirm understanding) to include the proposed screenshot-to-step mappings in the AskUserQuestion batch (or in the platform-fallback summary).

**Verify:** Phase 1 reads cleanly end-to-end; new step doesn't break the existing gate.

### Task 6 — Edit `SKILL.md`: insert Phase 2.5 (style extraction)

Insert new section between current Phase 2 and Phase 3, titled "Phase 2.5: Host Style Extraction (optional)". Body follows the spec's Design §1: trigger detection, candidate selection, extractor invocation referencing `reference/style-extraction.md`, user-confirmation prompt, outputs to `assets/house-style.json` and `assets/house-style.css`.

Renumber subsequent phases? **No** — Phase 2.5 keeps the existing phase numbers stable so external references don't break. Document this decimal numbering at the top of the new section.

**Verify:** existing Phase 3, 4, … headers untouched; new phase has its own gate ("user confirms the extracted style or chooses to discard").

### Task 7 — Edit `SKILL.md`: Phase 3 generator briefing

In Phase 3.b "Generation Protocol" subagent input list, add two bullets:
- "If `assets/house-style.json` exists with non-null source: include it verbatim and instruct the generator to link `./assets/house-style.css` after `./assets/wireframe.css` and match the `patterns` shape hints."
- "If this component is anchored to a source screenshot (per `source-screens.md`): include only that screenshot's description block. Instruct the generator to preserve IA but improve states, a11y, and copy."

In "File Requirements" add: "If `house-style.css` exists, link it after `wireframe.css`."

**Verify:** subagent input list still reads as a coherent brief; no contradictions with existing instructions.

### Task 8 — Edit `SKILL.md`: anti-patterns

Append three bullets to the Anti-Patterns block:
- "Do NOT blend tokens from multiple host frontends — pick one (user-selected)."
- "Do NOT use screenshots as the sole journey source — they augment the req doc, not replace it."
- "Do NOT redesign IA away from an anchored screenshot without explicit user direction."

**Verify:** new bullets are at the end of the existing list, formatting matches.

### Task 9 — End-to-end review

Re-read SKILL.md top-to-bottom. Confirm:
- New flag appears in argument-hint and Phase 1.
- Phase 2.5 reads as a coherent optional stage.
- Phase 3 references the new artifacts without ambiguity.
- Anti-patterns updated.
- No phase number was accidentally changed.
- No reference to a file or section that doesn't exist.

**Verify:** manual reading; grep for stale phase numbers; check the two new reference files are linked.

## Out of scope

- Writing automated tests (skill is markdown; verification is manual per spec).
- Adding token extraction to other skills (e.g. `/spec`).
- Refactoring `wireframe.css` beyond ensuring the override surface exists.
- Changing how `index.html` is themed (it already links `wireframe.css` and inherits any override).

## Verification (final)

After all tasks:
1. `grep -n "house-style" plugins/pmos-toolkit/skills/wireframes/SKILL.md` returns ≥4 hits across Phase 2.5, Phase 3, anti-patterns.
2. `grep -n "screenshots" plugins/pmos-toolkit/skills/wireframes/SKILL.md` returns ≥3 hits across argument-hint, Phase 1, anti-patterns.
3. Both new reference files exist and pass a quick read-aloud test for clarity.
4. `wireframe.css` has the eight CSS variables the override depends on.
5. SKILL.md frontmatter parses (no broken YAML).
