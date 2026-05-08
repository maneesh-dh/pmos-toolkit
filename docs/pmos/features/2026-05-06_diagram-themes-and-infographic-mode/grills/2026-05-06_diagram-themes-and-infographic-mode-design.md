# Grill Report — `2026-05-06-diagram-themes-and-infographic-mode-design.md`

**Depth:** deep • **Questions asked:** 9 (1 skipped as already-resolved)

## Resolved (re-affirmations of existing spec)

- **Single-SVG output for infographic** → kept; user accepts the hand-rolled wrapping complexity rather than introduce HTML.
- **Infographic ↔ theme coupling** → not actually a coupling; per-theme `infographic.supported` already leaves the door open for a future `technical-v1` layout. No change.

## Spec changes required (new gaps surfaced)

1. **Caption count: 3–5, auto-fit grid.** Replace the hardcoded "4 columns" in §7 with: 3 captions → 4-col each; 4 → 3-col each; 5 → tighter. Model picks count based on actual semantic clusters; no filler.

2. **Strict positive-list JSON Schema for `theme.yaml`.** `themes/_schema.json` enumerates exactly the allowed top-level keys (surface, palette, typography, connectors, arrowheads, chips, nodeChrome, rubricOverrides, infographic, name, displayName). Loader rejects unknown keys. No layout-related keys exist in the schema. Mechanically enforces "themes own visuals only".

3. **Connector `role` is now a first-class concept.** Extend the Phase 1 relationship schema to `{from, to, label?, kind: directed|bidirectional, role?: contribution|emphasis|feedback|dependency|reference}`. `theme.yaml` adds `connectors.byRole: { contribution: curved-black, emphasis: straight-red, feedback: dashed-blue-loop, default: straight-default }`. Phase 3 author assigns role per edge; sidecar records it; rubric checks one-style-per-role consistency.

4. **Caption-anchor fallback to ordinal markers.** When the diagram uses fewer than 3 distinct token colors, replace colored left rules with geometric markers (● ▲ ■ ◆) drawn next to both each caption and its referenced element in the diagram. Document in §7.

5. **Drop v1 sidecar support entirely.** Remove the v1→v2 tolerant-read fallback from §4 and §10. v1 sidecars are treated as absent (skill proceeds as if no sidecar exists). Migration plan §10 step 3 simplifies: just delete the top-level `style.md` outright (no pointer file).

6. **Drop `extends:` from v1 schema.** Both shipping themes are standalone. Remove the inheritance section added during self-review. Add a v2 future-direction note instead.

7. **Slim wrapper vision rubric.** Add a single-pass 4-item rubric run after Phase 6.6 composes the wrapper: (a) typographic hierarchy clear, (b) lede + captions readable / no overflow, (c) diagram-to-frame proportion balanced, (d) no element kissing canvas edges. Single pass, no refinement loop. Failures ship-with-warning via XML comment.

8. **Pin accent-to-role mapping in theme.yaml.** Editorial theme's `accents` list gains a `pinnedRole` field per entry: `accent-primary` always = feedback/loop, `accent-emphasis` always = primary path. Authors stop choosing per-diagram. Cross-document consistency.

9. **Renderer policy for infographic mode.** Keep the 3-renderer hard-gate. If the wrapper would use `foreignObject` (font-metrics unavailable) AND renderer is rsvg/cairosvg, skip foreignObject and fall back to the 0.55em heuristic; emit a console warning that wrapping accuracy is reduced. Output still ships.

10. **Extend-flow handling for infographic.** When user picks **Extend** in Phase 1 and the existing sidecar has `mode: infographic`, treat `wrappedText` as fixed (like `positions` and `colorAssignments`). Add a future flag `--regenerate-copy` to opt back into text regeneration.

## Open / Deferred

- **Pipeline of multiple infographic figures (`--accept-copy` flag to skip per-figure checkpoint).** Not surfaced via grill but worth flagging — easy follow-up.
- **Implementation detail: how the rubric loader templates added items** (`{ id, prompt, evidenceHint }`) into the reviewer prompt. Defer to implementation plan.
- **Implementation detail: how the rubric verifies one-style-per-role consistency** (parse SVG stroke patterns vs trust sidecar role tags). Defer to implementation plan.

## Recommended next step

Update the spec with items 1–10 above, then run `/pmos-toolkit:simulate-spec` to pressure-test the revised design against scenarios (extend flow with role changes, mono diagram + infographic, multi-figure document, foreignObject fallback path). Then `/pmos-toolkit:plan` to break into TDD tasks.
