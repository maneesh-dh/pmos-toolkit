# Plan: DESIGN.md integration into `/wireframes`

**Date:** 2026-05-02
**Owner:** Maneesh
**Skill:** `pmos-toolkit:wireframes`
**Related:** `2026-04-30-wireframes-style-and-screenshot-input-plan.md` (replaces in-folder `house-style.json/css` artifacts with a repo-resident `DESIGN.md`)

---

## Goal

Make `DESIGN.md` (Google Labs' open-sourced spec, Apache 2.0) the durable, repo-resident source of truth for visual identity, generated and consumed by `/wireframes`. Save once per app, reuse across every wireframe run. Extend the spec with namespaced `x-*` fields for things `/wireframes` and `/prototype` need that the base spec does not cover.

**No new skill.** The existing `/wireframes` skill creates `DESIGN.md` on first run and consumes it on every subsequent run.

## Sufficiency: what DESIGN.md is and isn't

DESIGN.md is necessary but not sufficient on its own. It is a **visual identity contract** — tokens + prose. It is deliberately not code, not layout-complete, and not behaviorally executable. Wireframes that *fit* the existing app need three artifacts working together:

1. **`DESIGN.md`** (this plan's main subject) — tokens + visual rationale. One per app. Lives in the app repo.
2. **`COMPONENTS.md`** (new sidecar, see Phase B' below) — component-library inventory: names, props, variants, usage. Too verbose for DESIGN.md proper; lives next to it.
3. **Workstream decision log** (existing, via `/product-context`) — `## Constraints & Scars`, `## Design System / UI Patterns`. Cross-feature memory.

The generator subagent in Phase 3 receives all three, not just DESIGN.md.

## Workstream contract

The workstream (managed by `/product-context`) stores **only navigation state and pointers** — not visual content. Visual content is canonical in DESIGN.md / COMPONENTS.md; duplicating it into the workstream creates drift.

New `## Wireframes & Design System` section in the workstream doc, with exactly four fields:

| Field | Purpose | Example |
|---|---|---|
| `target_app` | Monorepo app selection. Set once on first `/wireframes` run, reused silently. | `{ path: "apps/web", confirmed_at: "2026-05-02" }` |
| `design_md_path` | Resolved path to the active DESIGN.md. | `apps/web/DESIGN.md` |
| `components_md_path` | Resolved path to COMPONENTS.md. | `apps/web/COMPONENTS.md` |
| `last_extraction_sha` | Commit at most recent extraction or `/verify` sync. Drift-check uses this to skip already-reconciled commits. | `4af3e83…` |

**What does NOT go in the workstream:**
- Brand color, typography, spacing → DESIGN.md (canonical).
- Component lists, variants, props → COMPONENTS.md (canonical).
- Recurring UI patterns → DESIGN.md `## Do's and Don'ts` / `x-components-extended`.

**What stays in the workstream's existing sections:**
- `## Constraints & Scars` — human-judgment decision log (e.g. "full-page modals failed on mobile"). Cannot be inferred from code; doesn't belong in DESIGN.md `x-*` fields. Phase 2.6 reads it; nothing in this plan writes to it.

**Migration on first run:** when `/wireframes` bootstraps DESIGN.md and the workstream's existing `## Design System / UI Patterns` section is non-empty, copy the patterns into DESIGN.md (with user confirmation), then replace the workstream section's body with a one-line pointer (`→ See DESIGN.md at <path>`).

## Layered architecture (rendering)

`wireframe.css` is **not** replaced by DESIGN.md. They are different layers:

| Layer | Purpose | Lives where | Per-run |
|---|---|---|---|
| **DESIGN.md** | Brand contract — tokens + rationale. Portable across tools. | App repo (root or `packages/ui/`). One per app. | Read |
| **`design-overlay.css`** | Generated `:root { --* }` derived from DESIGN.md. The bridge from spec to runtime. | `{feature_folder}/wireframes/assets/` | Regenerated |
| **`wireframe.css`** | Wireframe vocabulary — state-switcher tabs, annotation layer, device frames, `mock-*` primitives. App-agnostic; consumes the variables. | Skill `assets/`, copied into output folder. | Copied |
| **Tailwind CDN** | Layout/spacing utilities at markup level. | No file. | — |

Cascade order in every wireframe HTML:
1. `wireframe.css` — variable *names* + wireframe chrome
2. `design-overlay.css` — variable *values* from DESIGN.md (overrides)
3. Tailwind via CDN — utilities
4. Per-file `<style>` — one-off corrections

Killing `wireframe.css` would mean re-inventing the wireframe vocabulary every run. It stays.

---

## Decisions (captured via AskUserQuestion, 2026-05-02)

1. **Monorepo app resolution:** Ask first time, persist in workstream context. Re-ask only on feature-scope change.
2. **Inheritance:** Support `x-extends` so app-level `DESIGN.md` can inherit from a shared base (e.g. `packages/ui/DESIGN.md`).
3. **Greenfield repos (no frontend to extract from):** Interactively elicit basics (3–4 quick questions: brand color, font preference, density, accent) and synthesize a minimal `DESIGN.md`.
4. **Staleness:** When tracked Tailwind/CSS files have changed since `x-source.sha`, warn + ask to re-extract / use as-is / abort.

---

## File schema

### Base (compliant with Google Labs DESIGN.md alpha spec)

YAML front matter — required: `name`, `colors`. Optional: `version`, `description`, `typography`, `rounded`, `spacing`, `components`.

Markdown body in canonical section order: `## Overview`, `## Colors`, `## Typography`, `## Layout`, `## Elevation & Depth`, `## Shapes`, `## Components`, `## Do's and Don'ts`.

### `x-*` extensions (ours; ignored by other tools)

- `x-source` — provenance: extracted-from file paths, `sha` (commit at extraction), `extracted_at` (ISO date), `extractor_version`.
- `x-extends` — relative path to a parent `DESIGN.md`; tokens cascade (parent + child override).
- `x-interaction` — modal/drawer/toast behavior, destructive-action confirmation rules, default empty/loading/error state patterns, focus management, keyboard shortcuts.
- `x-information-architecture` — nav model, breakpoints + per-breakpoint behavior, page-header anatomy, breadcrumb rules, **`layouts`** (named page-template patterns: `two-pane-detail`, `left-rail-dashboard`, `single-column-form`, with skeletons).
- `x-content` — voice/tone, button verb conventions, error-message tone, empty-state copy patterns, date/number/currency formats.
- `x-components-extended` — tables (density, sort, sticky header), forms (label position, validation timing, required indicator), data-viz palette + rules.
- `## Anti-patterns` (prose) — repo-specific don'ts with the *why*.

---

## Placement rules

Resolution order when `/wireframes` runs (per chosen app):

1. `<app-dir>/DESIGN.md`
2. Nearest `packages/ui/DESIGN.md` or `packages/design-system/DESIGN.md` (shared base)
3. Repo-root `DESIGN.md` (single-app fallback)

**App selection in monorepos:** detect frontend apps (multiple `package.json` with React/Vue/Svelte deps OR multiple `tailwind.config.*`). If >1, AskUserQuestion on first run; persist choice in `/product-context` workstream state under a new key `wireframes.target_app`. Re-ask only when feature topic doesn't match the persisted app.

**First-run write location:**
- Single app → `<app-dir>/DESIGN.md` (or repo root if app is at root).
- Monorepo with shared `tailwind.config` / `packages/ui` → ask: shared (`packages/ui/DESIGN.md`) vs app-specific (`apps/<name>/DESIGN.md`).
- Greenfield → prompt for basics, write to chosen app dir or repo root.

---

## Implementation phases

### Phase A — Author the spec doc

**File:** `plugins/pmos-toolkit/skills/wireframes/reference/design-md-spec.md` (new)

Contents:
- Base DESIGN.md schema (link to `github.com/google-labs-code/design.md` as upstream, freeze our supported fields against the alpha snapshot).
- Full `x-*` extension schemas with examples.
- Token reference syntax (`{colors.primary}`).
- `x-extends` cascade semantics: child overrides parent at the leaf (deep-merge, not replace).
- Validation rules: required fields, hex format, WCAG AA contrast check expectation.
- Worked example: a real DESIGN.md for a fictional app showing every section + every `x-*` block.

**Acceptance:** doc reads end-to-end coherently; an LLM given only this doc + a Tailwind config can produce a valid DESIGN.md.

### Phase B' — Author the COMPONENTS.md spec + extractor

**File:** `plugins/pmos-toolkit/skills/wireframes/reference/components-md-spec.md` (new)

Companion to DESIGN.md. Captures the existing component-library inventory at richer fidelity than `x-components-extended` allows.

Schema (markdown, no front matter — this is prose-first):

```markdown
# COMPONENTS.md

Source: <paths walked> · Commit: <sha> · Generated: <date>

## <ComponentName>

**Path:** `src/components/Button.tsx`
**Variants:** primary, secondary, ghost, destructive
**Sizes:** sm, md, lg
**Props (key):** `variant`, `size`, `loading`, `leftIcon`, `rightIcon`, `disabled`
**Used in:** Dashboard, Settings, Onboarding (top 5 call-sites)
**Notes:** Loading state shows spinner replacing left icon; disabled is opacity-50 + pointer-events-none.

[...repeat per component...]
```

Extractor procedure:
1. Walk component directories (heuristics: `src/components/`, `packages/ui/src/`, `app/components/`).
2. For each top-level `.tsx`/`.vue`/`.svelte` file: parse exported component name, props (TS interface or PropTypes), enumerate variant strings from union types or `cva`/`tv` calls.
3. For top 10 components by import frequency, sample 3 call-sites each from the codebase to populate "Used in".
4. Emit `COMPONENTS.md` next to `DESIGN.md` (same directory).
5. Mirror a token-level summary into DESIGN.md `x-components-extended` (component names + variants only, no prose).

**Acceptance:** running the extractor on a sample React+TS app produces a readable COMPONENTS.md with at least the top 10 components and accurate variant lists.

### Phase B — Author the resolver doc

**File:** `plugins/pmos-toolkit/skills/wireframes/reference/design-md-resolver.md` (new)

Contents:
- App-detection algorithm (frontend signals, candidate enumeration).
- Resolution walk (app → shared → root).
- `x-extends` resolution: locate parent, deep-merge, detect cycles.
- Staleness check: read `x-source.sha` + `x-source.extracted_from`, run `git log -1 --format=%H -- <files>` against current HEAD, compare.
- Workstream persistence: read/write `wireframes.target_app` via `/product-context`.

**Acceptance:** procedure can be followed mechanically; covers single-app, monorepo-shared, monorepo-distinct, greenfield.

### Phase C — Author the extractor doc

**File:** `plugins/pmos-toolkit/skills/wireframes/reference/design-md-extractor.md` (replaces parts of existing `style-extraction.md`)

Contents:
- Inputs: app-dir path, optional shared-base path.
- Token extraction (colors, typography, spacing, radius) from `tailwind.config.*`, CSS custom properties, top-level styles. Read budget ~20 files / 30 KB.
- Component-token extraction: identify primitives (button, input, card) by usage frequency; emit per-variant entries.
- `x-source` population: list of extracted-from paths, current commit SHA, ISO timestamp.
- Greenfield branch: 4-question elicitation (brand color, font family preference, density tight/normal/spacious, accent color), synthesize minimal DESIGN.md with `x-source.source: "interactive-elicitation"`.
- Output: write `DESIGN.md` to resolved location; print path to user.

Keep `style-extraction.md` but mark it superseded; have it point to the new doc.

**Acceptance:** running the extractor against this repo (greenfield — no frontend) produces a valid elicited DESIGN.md; running it against a Tailwind-using sample app produces a valid extracted one with populated `x-source`.

### Phase D — Wire `/wireframes` SKILL.md

**File:** `plugins/pmos-toolkit/skills/wireframes/SKILL.md` (edit)

Changes to **Phase 2.5 (Host Style Extraction)**:

1. Rename to **"Phase 2.5: Resolve DESIGN.md"**.
2. Replace existing logic with:
   - Step 1: Resolve target app per `reference/design-md-resolver.md` (consult workstream `wireframes.target_app`; AskUserQuestion if ambiguous and no persisted choice).
   - Step 2: Walk resolution order. If a `DESIGN.md` is found at any level, load it (with `x-extends` resolution), check staleness, AskUserQuestion if stale (re-extract / use as-is / abort).
   - Step 3: If no `DESIGN.md` found, run extractor (`reference/design-md-extractor.md`); ask shared-vs-app-specific where applicable; write file; commit boundary belongs to Phase 8.
   - Step 4: Confirm with user: "Use this DESIGN.md / Edit before applying / Discard for this run". "Discard" leaves the file in place but proceeds with default style for this run only.
   - Step 5: Drop the legacy `house-style.json` + `house-style.css` artifacts. Wireframe templates read tokens directly from the resolved DESIGN.md (or via a small generated CSS variable file derived from it — see Phase E).

**New Phase 2.6 — Resolve Composition Context** (runs immediately after 2.5):

1. Load `COMPONENTS.md` from the same dir as the resolved `DESIGN.md`. If missing AND a host frontend exists, run the COMPONENTS.md extractor (Phase B'); write the file; offer same accept/edit/discard gate as DESIGN.md.
2. **Layout anchor selection:** if the app has detectable page templates, AskUserQuestion: "Which existing page is closest to what we're wireframing?" Options: top 3 detected templates + "None — start fresh". The chosen template becomes the layout anchor passed to generators.
3. **Decision-log assembly:** pull `## Constraints & Scars` and `## Design System / UI Patterns` from the workstream (if loaded in Phase 0), plus `## Anti-patterns` and `## Do's and Don'ts` from the resolved DESIGN.md. Concatenate into a single "decision context" block.

Output of Phase 2.6 is three in-memory blobs: `components_inventory`, `layout_anchor`, `decision_context`. All three feed Phase 3.

Changes to **Phase 3 (Generate Wireframes)**:
- Subagent prompt receives: the merged DESIGN.md (after `x-extends`) verbatim, the `design-overlay.css` reference, the Phase 2.6 `components_inventory` (so the subagent prefers existing components over inventing new ones), the `layout_anchor` (so chrome/IA matches), and the `decision_context` (so anti-patterns are honored).
- Wireframe HTML links the overlay CSS the same way `house-style.css` was linked previously, **after** `wireframe.css`.
- Generator instruction: "When wireframing a button/input/card/modal/etc., use the variant names from `components_inventory` rather than inventing new ones. If the inventory has no matching component, flag it for review in the file footer."

Changes to **Phase 9 (Workstream Enrichment)**:
- Write/update only the four fields defined in the Workstream contract section: `target_app`, `design_md_path`, `components_md_path`, `last_extraction_sha`.
- **Stop** writing brand color, typography, or recurring component patterns into `## Tech Stack` / `## Design System / UI Patterns` — those facts are canonical in DESIGN.md/COMPONENTS.md now.
- On first run only: run the `## Design System / UI Patterns` migration described in the Workstream contract section (copy patterns into DESIGN.md with user confirmation, then replace the workstream section body with a pointer).
- `## Constraints & Scars` is read-only from this skill — do not auto-write.

### Phase E — DESIGN.md → CSS overlay generator

**File:** `plugins/pmos-toolkit/skills/wireframes/reference/design-md-to-css.md` (new, small)

Procedure to derive a `:root { --* }` overlay from a merged DESIGN.md (post-`x-extends`). Output written to `{feature_folder}/wireframes/assets/design-overlay.css`. Linked after `wireframe.css`.

This is the bridge between the spec file (portable, tool-agnostic) and the wireframe rendering (CSS-variable-driven).

**Acceptance:** given a known DESIGN.md, the generator produces a CSS file whose variables match the wireframe.css token names.

### Phase F — Migration & docs

1. Update `assets/wireframe.css` if any token names need to align with DESIGN.md conventions.
2. Update `reference/style-extraction.md` to be a thin pointer at the new docs (don't delete — other plans link to it).
3. Update CHANGELOG / version bump for `pmos-toolkit` (minor — additive feature, no breaking change for users without a DESIGN.md).
4. Update `MEMORY.md` index with a one-liner if a memory is warranted (likely yes — this is a notable spec adoption).

### Phase H — `/verify` integration: continuous updation

**Files:** `plugins/pmos-toolkit/skills/verify/SKILL.md` (edit), `plugins/pmos-toolkit/skills/verify/reference/design-drift-check.md` (new)

Without continuous updation, DESIGN.md and COMPONENTS.md rot the moment someone ships a new component or token. `/verify` is the right host because it already runs post-implementation when the diff is fresh and the user is in "checking my work" mode.

**New `/verify` phase: "Design-system drift check"** — runs late, after lint/test/spec compliance, before final summary. Advisory, never blocking.

Procedure (in `reference/design-drift-check.md`):

1. **Skip-fast guard:** if the diff touches no frontend files (no `*.tsx`/`*.vue`/`*.svelte`/`*.css`/`tailwind.config.*` changes), skip entire phase silently. Same skip if no `DESIGN.md` resolvable (one-line note: "No DESIGN.md found — run /wireframes to bootstrap").
2. **Locate** nearest `DESIGN.md` + `COMPONENTS.md` using the same resolver as `/wireframes` Phase 2.5/2.6.
3. **Detect drift** by diffing branch changes against the files:
   - **Token drift** — new/changed entries in `tailwind.config.*`, `:root { --* }`, top-level theme files vs. DESIGN.md `colors`/`typography`/`spacing`/`rounded`.
   - **Component drift** — new component files in component dirs, or new `variant`/`size` literals in existing component union types / `cva`/`tv` calls vs. COMPONENTS.md.
   - **Layout drift** — new top-level route/page introducing a new chrome shape vs. `x-information-architecture.layouts`.
4. **Categorize** each drift item: **Additive** / **Modified** / **Removed**.
5. **Surface via `AskUserQuestion`** (max 4 per call, batched): per item — **Apply to DESIGN.md/COMPONENTS.md** / **Modify** / **Skip (don't track)** / **Defer**.
6. **High-volume escape hatch:** if drift count > 20, collapse to a single summary question: "Large drift detected (N items). Re-run /wireframes Phase 2.5 + 2.6 extractors instead? [y/N]" — avoids prompt fatigue on refactor PRs.
7. **Apply approved changes** via `Edit`, bump `x-source.sha` + `x-source.extracted_at` to current commit/timestamp, stage edits in `/verify`'s commit boundary.
8. **Report in `/verify` summary:** "DESIGN.md/COMPONENTS.md: N additions, M modifications" or "Design-system files in sync".

**Boundaries (what this phase does NOT do):**
- Does not generate or regenerate wireframes (that's `/wireframes`).
- Does not regenerate `design-overlay.css` (next `/wireframes` run does that).
- Does not modify workstream `## Constraints & Scars` — needs human judgment; flag for user instead, no auto-edit.
- Does not block `/verify` from passing — drift is advisory.
- Does not auto-create DESIGN.md/COMPONENTS.md if missing — that is `/wireframes`' job alone.

**Edge cases:**
- Greenfield-elicited DESIGN.md (no `x-source` paths) → skip token drift, run component/layout drift only.
- User marked DESIGN.md as discarded (`x-source.applied: false`) → skip entire phase silently.
- Component dir not yet in COMPONENTS.md (first commit of a new monorepo app) → propose creating COMPONENTS.md with one prompt rather than per-component prompts.

**Opt-out:** `/verify --skip-design-drift` flag for users who don't want the prompts.

**Acceptance:** modify a Tailwind color in this repo's test fixture, run `/verify` → drift surfaces → approve → DESIGN.md updates with new `x-source.sha`. Modify a component variant → drift surfaces → approve → COMPONENTS.md updates.

### Phase G — Verification

- Run `/wireframes` in this repo (no frontend → greenfield path): confirm 4-question elicitation, file written to repo root, subsequent run skips extraction.
- Run against a real Tailwind app (pick one from local projects): confirm extraction populates `x-source.sha`, staleness warning fires after a deliberate Tailwind edit, re-extract works.
- Run against a synthetic monorepo (two apps + `packages/ui`): confirm app selection question, `x-extends` resolution, persistence to workstream.
- Spot-check a generated wireframe: confirm it visually reflects the DESIGN.md tokens, uses component variant names from `COMPONENTS.md`, and honors the chosen layout anchor.
- Confirm cascade order in a generated HTML file: `wireframe.css` → `design-overlay.css` → Tailwind CDN → per-file `<style>`.

---

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| Google's alpha spec changes shape | Pin our base-field allowlist in `design-md-spec.md`; review quarterly. |
| Hand-edited DESIGN.md drifts from repo reality | Staleness check on `x-source.sha`; `/verify` could grow a "DESIGN.md freshness" check later (out of scope here). |
| `x-extends` cycles or missing parents | Resolver detects cycles, errors loudly; missing parent → fall back to child-only with announcement. |
| Greenfield 4-question elicitation produces a bland baseline | Acceptable for v1; user is expected to hand-edit the file later. Document this in the file's `## Overview`. |
| Existing `house-style.json` artifacts in old feature folders | Leave in place; new runs ignore them. Don't auto-migrate. |
| Token-name mismatch between DESIGN.md and `wireframe.css` | Phase E generator is the single mapping point; update it, not the schema. |

---

## Out of scope (deferred)

- `/prototype` consuming DESIGN.md (likely Phase II — same resolver, different render target).
- An LLM-based "extraction quality" reviewer subagent.
- Importing existing design-token tools' output (Style Dictionary, Tokens Studio) — manual hand-off for now.
- Auto-publishing DESIGN.md changes back to upstream design-system packages.

---

## Open questions to resolve during implementation

1. Do we need a `version` discipline on our `x-*` extensions (e.g. `x-version: 1`) so future changes don't silently break old files? Lean yes — cheap insurance.
2. Should the elicited greenfield DESIGN.md include a TODO checklist in `## Overview` reminding the user to fill in voice/tone, anti-patterns? Lean yes.
3. When `x-extends` is used, should staleness check the parent's `x-source.sha` too? Lean yes — child is only as fresh as its parent.

These are small enough to decide inline during Phase A/B authoring; flagging here so they don't get lost.
