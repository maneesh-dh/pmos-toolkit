# Plan: DESIGN.md / COMPONENTS.md integration into `/prototype`

**Date:** 2026-05-02
**Owner:** Maneesh
**Skill:** `pmos-toolkit:prototype`
**Target version:** pmos-toolkit v2.8.0
**Builds on:** `2026-05-02-design-md-integration-plan.md` (`/wireframes` + `/verify` integration, shipped in v2.7.0)

---

## Goal

Make `/prototype` consume the same canonical design artifacts that `/wireframes` and `/verify` now use:
- **DESIGN.md** — visual identity tokens + `x-interaction` + `x-content`.
- **COMPONENTS.md** — component-library inventory.
- **`design-overlay.css`** — generated CSS variable overlay.
- **`design-tokens.js`** *(new for `/prototype`)* — JS-shaped tokens for JSX imports.

Replace the existing ad-hoc `house-style.json`-driven `styles.css` derivation with the DESIGN.md pipeline. Enforce `x-interaction` patterns literally in generated prototype code (modal style, destructive-action confirmation, focus traps, shortcuts).

**No new skill.** All changes are inside `/prototype`. Reuses the DESIGN.md infrastructure shipped in v2.7.0 — no duplicate logic.

---

## Decisions (captured via AskUserQuestion, 2026-05-02)

1. **JS tokens artifact:** generate `design-tokens.js` so JSX can `import` token values for chart configs, inline styles, conditional logic. New artifact next to the CSS overlay.
2. **CSS overlay source:** reuse `{feature_folder}/wireframes/assets/design-overlay.css` if present (avoids drift within a feature), regenerate from DESIGN.md otherwise.
3. **`x-interaction` enforcement:** **mandatory.** Generators must implement patterns literally (destructive confirmation pattern, modal style, focus trap, keyboard shortcuts). Reviewer subagent in Phase 6 enforces.
4. **DESIGN.md / COMPONENTS.md bootstrap:** **require `/wireframes` first.** `/prototype` does NOT bootstrap on its own — if no DESIGN.md is resolvable, abort with: *"Run `/wireframes` first to bootstrap DESIGN.md."* Keeps bootstrap responsibility in a single skill; avoids parallel "first-run extraction" code paths.

---

## Why these are the right choices

- **JS tokens:** prototype JSX needs JS-readable values for chart palettes, conditional rendering, sizing in inline styles. CSS variables alone force every consumer through `getComputedStyle()` — clunky and slow.
- **Reuse overlay:** within one feature folder, wireframes and prototype should look identical. Reusing the wireframe's overlay enforces this at the file level. Regeneration is the fallback for prototype-only sessions.
- **Mandatory x-interaction:** prototypes are *interaction demos* by design. If the spec says "destructive actions use type-to-confirm" but the prototype shows a one-click delete, stakeholders see the wrong pattern, then implementation gets built to match the prototype, not the spec. The whole point of `x-interaction` is that prototypes implement it.
- **Require `/wireframes` first:** bootstrap is a 5-minute interactive flow the first time it runs (greenfield elicitation, accept/edit/discard gate, possibly migration of legacy workstream patterns). Cramming it into `/prototype` would either duplicate the prompts or make `/prototype` feel like `/wireframes`. The natural pipeline order is `/requirements → /wireframes → /prototype → /spec`; making `/prototype` depend on `/wireframes` reinforces that.

---

## Existing `/prototype` structure (for reference)

Phases that need touching:
- **Phase 0** — Load workstream (already reads workstream; needs to also read the DESIGN.md pointers).
- **Phase 1** — Locate inputs (currently reads `wireframes/assets/house-style.json`; needs to switch to DESIGN.md).
- **Phase 4 — "Generate Shared Runtime + Components + Styles"**:
  - 4a copies `prototype.css` (unchanged).
  - 4b generates `runtime.js` (no DESIGN.md changes needed).
  - 4c generates `components.js` — **needs DESIGN.md / COMPONENTS.md / x-interaction in the prompt.**
  - 4d generates `styles.css` from `house-style.json` — **rewrite to use design-overlay.css + design-tokens.js.**
- **Phase 5** — Per-device HTML files — **needs to link the new artifacts** in the correct cascade order.
- **Phase 6** — Refinement loop — **reviewer subagent gets DESIGN.md anti-patterns + x-interaction contract** to enforce.
- **Phase 9** — Workstream enrichment — **narrowed to four navigation pointers** (already managed by `/wireframes`; `/prototype` just consumes).

---

## Implementation phases

### Phase A — Author `design-md-to-tokens-js.md`

**File:** `plugins/pmos-toolkit/skills/prototype/reference/design-md-to-tokens-js.md` (new)

Mirror of `wireframes/reference/design-md-to-css.md`, but for JS.

Contents:
- Inputs: merged DESIGN.md object (after `x-extends` cascade).
- Output path: `{feature_folder}/prototype/assets/design-tokens.js`.
- Output shape:
  ```js
  // Generated from DESIGN.md (apps/web/DESIGN.md @ 4af3e83). Do not edit by hand.
  window.__designTokens = Object.freeze({
    name: "AcmeCRM",
    colors: { primary: "#2563EB", ... },
    typography: { body: { fontFamily: "Inter, ...", fontSize: "14px", ... }, ... },
    rounded: { sm: "4px", md: "8px", ... },
    spacing: { xs: "4px", sm: "8px", ... },
    components: { "button-primary": { ... } },
    interaction: { modals: { style: "centered", ... }, destructiveActions: { ... }, ... },
    informationArchitecture: { layouts: { ... }, breakpoints: { ... } },
    content: { voice: "...", buttonVerbs: { ... }, formats: { ... } },
    componentsExtended: { table: { ... }, form: { ... }, dataViz: { palette: [...] } },
  });
  ```
- Reference resolution: same `{path.to.token}` resolver as the CSS generator; values resolve before emit.
- `x-source` is **omitted** (provenance is on DESIGN.md itself; not useful at runtime).
- `Object.freeze()` for immutability — prevents accidental in-prototype mutation.
- Idempotent — always overwritten; never patched.

**Acceptance:** given the worked example in `design-md-spec.md`, the generator produces a parseable JS file whose values match the YAML.

### Phase B — Author `design-artifact-resolver.md`

**File:** `plugins/pmos-toolkit/skills/prototype/reference/design-artifact-resolver.md` (new, ~one page)

Thin doc describing the prototype-specific resolver behavior — composes existing `/wireframes` resolver doc with the prototype-specific rules.

Contents:
1. Call `wireframes/reference/design-md-resolver.md` end-to-end. If `design_md_path: null` → abort: *"DESIGN.md not found. Run `/wireframes` first to bootstrap."*
2. **CSS overlay resolution:**
   - If `{feature_folder}/wireframes/assets/design-overlay.css` exists, **copy** to `{feature_folder}/prototype/assets/design-overlay.css`. Done.
   - Else regenerate via `wireframes/reference/design-md-to-css.md` directly into the prototype folder.
3. **JS tokens generation:**
   - Always regenerate via `prototype/reference/design-md-to-tokens-js.md` (cheap; consistency over reuse).
   - Output to `{feature_folder}/prototype/assets/design-tokens.js`.
4. **COMPONENTS.md:**
   - If file exists at `<dirname design_md_path>/COMPONENTS.md`, load. Else proceed with empty inventory and warn.
   - Do NOT extract from `/prototype` — the drift check in `/verify` handles that.
5. Composition context (layout anchor, decision context) — same as `/wireframes` Phase 2.6, reuse `wireframes/reference/design-md-resolver.md` Step 5 plus the assembly logic from `/wireframes` SKILL.md Phase 2.6c.

**Acceptance:** given a feature folder with prior wireframes, resolver produces `design-overlay.css` + `design-tokens.js` in prototype assets; given no wireframes but DESIGN.md exists, regenerates both.

### Phase C — Wire `/prototype/SKILL.md`

**File:** `plugins/pmos-toolkit/skills/prototype/SKILL.md` (edit)

#### C.1. New Phase 1.5 — "Resolve DESIGN.md & Composition Context"

Insert immediately after Phase 1 (Locate Inputs), before Phase 2 (Tier Gate).

```markdown
## Phase 1.5: Resolve DESIGN.md & Composition Context

Follow `reference/design-artifact-resolver.md`:

1. Resolve DESIGN.md via `wireframes/reference/design-md-resolver.md`. **If no DESIGN.md is found, abort with:** "DESIGN.md not found. Run `/wireframes` first to bootstrap the design-system file, then re-run `/prototype`." Do not auto-bootstrap; that's `/wireframes`' responsibility.
2. Resolve `design-overlay.css` (reuse from wireframes folder if present, else regenerate).
3. Generate `design-tokens.js` via `reference/design-md-to-tokens-js.md`.
4. Load COMPONENTS.md (empty inventory + warning if missing).
5. Pick layout anchor from `x-information-architecture.layouts` (single AskUserQuestion if multiple). Skip if none declared.
6. Assemble decision context (workstream `## Constraints & Scars` + DESIGN.md `## Anti-patterns` + `## Do's and Don'ts`).

Output: in-memory `merged_design_md`, `components_inventory`, `layout_anchor`, `decision_context`. Pass to Phases 4–6.
```

#### C.2. Phase 1 (Locate Inputs) — drop legacy `house-style.json` reference

Replace the line `wireframes/assets/house-style.json if present (drives Phase 4d high-fi style)` with: `wireframes/assets/design-overlay.css if present (reused as the prototype's overlay; otherwise regenerated from DESIGN.md in Phase 1.5)`.

#### C.3. Phase 4c (Generate components.js) — expanded subagent prompt

The components.js generator receives, in addition to existing inputs:
- The merged DESIGN.md verbatim.
- COMPONENTS.md content.
- `x-interaction` block with the instruction:
  > "**Mandatory: implement `x-interaction` literally.** Specifically:
  > - `modals.style` controls the Modal component's positioning class.
  > - `modals.dismiss` controls which dismiss handlers Modal wires up (backdrop click, esc key, explicit-button only).
  > - `destructiveActions.confirmation: type-to-confirm` means the destructive Button variant opens a confirm modal that requires typing the resource name to enable the confirm button. `double-click` means the first click arms a 3-second countdown ring on the button.
  > - `focus.trapInModals: true` means Modal traps focus within itself when open.
  > - `focus.visibleStyle` becomes the `:focus-visible` class string applied to Button, Input, etc.
  > - `shortcuts` becomes a global keydown handler in the runtime; advertise the shortcuts in a `?` modal."
- `x-content.buttonVerbs` with the instruction: "Use these exact verbs in default Button labels. Don't invent 'Submit' or 'Add' — use 'Save' and 'Create'."
- COMPONENTS.md inventory with the instruction: "When emitting an atom (Button, Input, Card, Modal, etc.), use variant names from COMPONENTS.md. If the inventory has no matching variant, emit the atom anyway but flag it in the file footer."

#### C.4. Phase 4d (Generate styles.css) — REWRITE

Drop the entire `house-style.json`-based derivation. New 4d:

```markdown
### 4d. Apply design overlay + tokens

The CSS overlay (`design-overlay.css`) and JS tokens (`design-tokens.js`) were already produced in Phase 1.5. This phase:

1. Confirm both files exist at `{feature_folder}/prototype/assets/`.
2. Generate a thin `styles.css` (≤ 30 lines) for prototype-only utility classes that aren't in `prototype.css` and don't belong in DESIGN.md (e.g. mock-data shimmer animations, scroll-snap overrides). Most prototypes will not need any custom styles here.
3. Validate per existing rules (balanced braces, no external URLs, no @import).

`reference/styles-derivation.md` is marked superseded; cite the new docs.
```

#### C.5. Phase 5 (Per-Device HTML Files) — link cascade

Update the `<link>` and `<script>` order in the device HTML template:

```html
<link rel="stylesheet" href="./assets/prototype.css">
<link rel="stylesheet" href="./assets/design-overlay.css">  <!-- NEW -->
<link rel="stylesheet" href="./assets/styles.css">
<script src="https://cdn.tailwindcss.com"></script>
<script src="./assets/design-tokens.js"></script>           <!-- NEW: must load before runtime + components -->
<script src="./assets/runtime.js"></script>
<script src="./assets/components.js"></script>
```

`design-tokens.js` must load before `components.js` so `window.__designTokens` is defined when components evaluate.

#### C.6. Phase 6 (Refinement Loop) — x-interaction contract enforcement

Reviewer subagent prompt gets two new sections:

1. **DESIGN.md anti-patterns + Do's and Don'ts** — verbatim. Score the file against each.
2. **`x-interaction` contract** — checklist:
   - Modal style matches `modals.style`?
   - Modal dismiss matches `modals.dismiss` exactly (no extra dismiss paths)?
   - Destructive actions match `destructiveActions.confirmation` literally?
   - Focus trap implemented in Modal?
   - `focus.visibleStyle` applied to interactive elements?
   - Declared shortcuts wired up and advertised?
   - Default empty/loading/error states match `defaultStates`?

Findings at severity ≥ medium feed the refinement loop.

#### C.7. Phase 7 (Interactive Friction Pass) — `x-content` voice check

Add one bullet to the friction pass: "Confirm copy honors `x-content.voice` and `x-content.buttonVerbs`. Mismatched verbs ('Submit' vs 'Save') are a finding."

#### C.8. Phase 9 (Workstream Enrichment) — narrow to pointers

Replace existing enrichment with the same pattern `/wireframes` v2.7.0 uses:
- Workstream stores only the four navigation fields (`target_app`, `design_md_path`, `components_md_path`, `last_extraction_sha`).
- These are already managed by `/wireframes` and `/verify`. `/prototype` reads them; never writes.
- Do NOT write brand color, typography, or component patterns into the workstream.

#### C.9. Anti-patterns (DO NOT) — additions

- Do NOT bootstrap DESIGN.md from `/prototype` — abort and tell user to run `/wireframes` first.
- Do NOT regenerate `design-overlay.css` if a fresh one exists in the wireframes folder — copy it instead (avoids feature-internal drift).
- Do NOT treat `x-interaction` as advisory — it's a contract. Modal style, destructive confirmation, focus management must match literally.
- Do NOT write design-system content into the workstream — those facts live in DESIGN.md/COMPONENTS.md (canonical).
- Do NOT keep the legacy `house-style.json` codepath alive — Phase 4d is rewritten; legacy reference doc is superseded.

### Phase D — Mark legacy `styles-derivation.md` superseded

**File:** `plugins/pmos-toolkit/skills/prototype/reference/styles-derivation.md` (edit)

Add a header banner like the one we added to `wireframes/reference/style-extraction.md`:

```markdown
> **Superseded as of pmos-toolkit v2.8.0.** Phase 4d of `/prototype` no longer follows this document. Style is now driven by:
>
> - `design-artifact-resolver.md` — resolves DESIGN.md, copies/regenerates `design-overlay.css`, generates `design-tokens.js`.
> - `design-md-to-tokens-js.md` — produces the JS tokens artifact.
> - `wireframes/reference/design-md-spec.md` — DESIGN.md schema.
> - `wireframes/reference/design-md-to-css.md` — CSS overlay generator (reused).
>
> This file is retained as a historical reference for plans that link to it. New work follows the docs above.
```

### Phase E — `/verify` drift check coverage

The `/verify` Phase 7.5 drift check (shipped in v2.7.0) already covers DESIGN.md and COMPONENTS.md. **No new drift logic for `design-tokens.js`** — it's always regenerated by `/prototype`, so it can't drift from DESIGN.md. Document this explicitly in `prototype/reference/design-artifact-resolver.md` ("design-tokens.js is fully derived; never drift-checked").

### Phase F — Migration & docs

1. Bump `pmos-toolkit/.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` to `2.8.0`.
2. Update `MEMORY.md` index with a one-liner pointing at a new `project_design_md_prototype.md` memory.
3. Confirm no other skill references `house-style.json` (run `grep -r house-style plugins/` and clean up any stragglers in docs).

### Phase G — Verification

- **Inherited DESIGN.md path** — run `/prototype` after `/wireframes` in a sample feature folder. Confirm:
  - `design-overlay.css` is **copied** from wireframes (same file content, same mtime+1).
  - `design-tokens.js` is **generated** with values matching DESIGN.md.
  - HTML cascade order is `prototype.css → design-overlay.css → styles.css`, scripts `design-tokens.js → runtime.js → components.js`.
  - Modal in components.js uses `x-interaction.modals.style`.
  - Destructive Button shows the configured confirmation pattern.
- **Standalone `/prototype` (no wireframes)** — same feature folder, no wireframes. Confirm:
  - `design-overlay.css` is **regenerated** from DESIGN.md (not copied).
  - Same downstream behavior.
- **No DESIGN.md** — fresh repo, `/prototype` must abort with the documented message and exit cleanly.
- **Reviewer enforcement** — intentionally generate a Modal that uses `drawer-right` when DESIGN.md says `centered`. Confirm Phase 6 reviewer flags it as ≥ medium severity and the loop fixes it.
- **Workstream check** — confirm `/prototype` reads `## Wireframes & Design System` pointers but does not write to `## Tech Stack` or `## Design System / UI Patterns`.

---

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| Reused `design-overlay.css` is stale because `/wireframes` ran weeks ago and DESIGN.md changed | The freshness check happens in `/wireframes` resolver. If DESIGN.md is fresher than the overlay, the resolver should flag — add a check in `design-artifact-resolver.md` Step 2: if `mtime(DESIGN.md) > mtime(wireframes overlay)`, regenerate instead of copy. |
| `x-interaction` enforcement adds friction when patterns are aspirational (not yet built in the real app) | Reviewer findings are still surfaceable as "Skip" / "Defer" via the existing Phase 6 Findings Presentation Protocol. User stays in control. |
| `design-tokens.js` JSON-encoding choice (Object.freeze vs plain) | `Object.freeze()` is one extra line, prevents footgun, no runtime cost worth caring about. Keep it. |
| Users running `/prototype` standalone get an abort — pipeline-feel breaks | Acceptable. The abort message names the next action ("Run `/wireframes` first"). One redirection beats permanent code duplication. |
| Existing prototypes generated under v2.7.0- will have stale `styles.css` shape | Acceptable. Old prototypes are output artifacts; users regenerate when they re-run `/prototype`. No migration of generated files needed. |

---

## Out of scope (deferred)

- Drift check for `design-tokens.js` — not needed (always regenerated).
- A standalone `/prototype --bootstrap-design` flag that triggers the elicitation flow — adds duplication for marginal benefit.
- Per-device DESIGN.md variants (e.g. native iOS tokens distinct from web) — DESIGN.md base spec doesn't model device-specific tokens portably yet. Wait for upstream.
- Dark-mode prototype tokens — same constraint as the v2.7.0 plan.

---

## Open questions to resolve during implementation

1. **`design-tokens.js` should be wrapped in IIFE for strict isolation, or is `window.__designTokens` enough?** Lean: plain `window.__designTokens = Object.freeze({...})`. Prototypes are not security-sensitive and the globals already include `window.__protoComponents`.
2. **Should the layout anchor selection happen in `/prototype` Phase 1.5 (re-asking) or inherit from a wireframes session if one exists?** Lean: inherit if a `wireframes/.layout-anchor` marker file exists (cheap to write from `/wireframes`); re-ask otherwise. Add the marker write to `/wireframes` Phase 2.6 as a small forward-compatible change.
3. **Reviewer prompt budget** — Phase 6 reviewer subagent now receives DESIGN.md + COMPONENTS.md + `x-interaction` contract + the existing eval rubric + pattern files. Token budget may push 8K. If this becomes a problem, split into a per-component reviewer (one subagent per atom) instead of one cross-file pass.

These are small enough to decide inline during Phase A/B/C authoring.

---

## Estimated scope

- **New docs:** 2 (~2 short pages each).
- **Modified docs:** `prototype/SKILL.md` (one new phase, four phase rewrites), `prototype/reference/styles-derivation.md` (banner only), 2 plugin manifests, MEMORY.md.
- **Net SKILL.md delta:** ~150 lines added, ~40 removed.
- **Risk class:** additive feature on a stable infrastructure (DESIGN.md pipeline shipped in v2.7.0 and used in `/wireframes` and `/verify` already). No upstream cascade.
