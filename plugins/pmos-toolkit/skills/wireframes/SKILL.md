---
name: wireframes
description: Generate static HTML wireframes (single-file, mid-fi, Tailwind) for a user-facing feature — covers all screens, components, states, and target devices. Optional bridge between /requirements and /spec in the requirements -> spec -> plan pipeline (run before /spec when the feature is user-facing). Auto-triggers /requirements if no req doc exists. Optionally extracts a "house style" from the host repo's frontend (Tailwind tokens, component library, layout patterns) so wireframes match the existing app, and accepts screenshots (`--screenshots`) of existing flows as IA anchors for "extend this flow" requests. Self-evaluates each wireframe against UX heuristics with a reviewer subagent and runs up to 2 self-refinement loops. Use when the user says "create wireframes", "mock up the UI", "wireframe this feature", "design the screens", "show me the UI states", "extend this existing flow", or has a requirements doc ready and wants visuals before the spec.
user-invocable: true
argument-hint: "<path-to-requirements-doc or feature description> [--devices=desktop-web,mobile-web,...] [--feature <slug>] [--screenshots <path>] [--bootstrap-design-only]"
---

# Wireframe Generator

Produce static HTML wireframes that visualize every screen, component, and state needed to fulfill a feature's user journeys. Output is mid-fidelity (Tailwind via CDN, neutral palette, real typography, no real images) — looks polished enough to review with stakeholders but clearly not final design. This is an OPTIONAL stage that sits between requirements and spec for user-facing features:

```
/requirements  →  [/wireframes]  →  /spec  →  [/simulate-spec]  →  /plan  →  /execute  →  /verify
                  (this skill, optional)
```

Use this when the feature has meaningful UI surface and the team benefits from seeing the flow before writing technical design. Skip for backend-only or API-only features.

**Design vocabulary** is shared across every wireframe in a feature folder via `assets/wireframe.css` (theme tokens, state-switcher, annotations layer, device frames, and `mock-*` primitives — vocabulary borrowed from `superpowers:brainstorming/visual-companion`; CSS-variable theme discipline borrowed from `claude-plugins-official:frontend-design`). The CSS is copied into each output folder at the start of generation so wireframes remain portable and consistent.

**Announce at start:** "Using the wireframes skill to generate HTML wireframes for this feature."

## `--bootstrap-design-only` mode

Invoked as `/wireframes --bootstrap-design-only` (typically by `/prototype` Phase 1.5 when DESIGN.md is missing but wireframes already exist). In this mode the skill produces ONLY DESIGN.md and COMPONENTS.md — no wireframe HTML, no review loops, no PSYCH/MSF, no Phase 7 polish, no Phase 9–10 enrichment. The user's existing wireframes are not touched.

**Phases that run in this mode:** Phase 0 (workstream context), Phase 2.5 (DESIGN.md, including 2.5c review gate — DO NOT skip the gate), Phase 2.6a (COMPONENTS.md load/create — including 2.6a accept/edit/skip gate). All other phases are skipped.

**COMPONENTS.md scope in bootstrap mode (mandatory):** enumerate ONLY components that exist in the host frontend (`<app_dir>/src/components/` or equivalent). Do NOT propose feature-specific or speculative new components — those belong to `/prototype`'s output (Phase 4c flags new variants in the components.js footer; `/verify` promotes them later). A bootstrap-mode COMPONENTS.md that names components not present in the host frontend is a contract violation.

**Announce at start in this mode:** "Bootstrap-design-only: skipping wireframe regen. Producing DESIGN.md + COMPONENTS.md from the host frontend."

**Exit:** announce path to the two files and return; do NOT trigger downstream phases or commit anything beyond the two files.

For all other invocations, proceed through every phase below as usual.

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:
- **No `AskUserQuestion`:** State your assumption (default device = desktop-web; default scope = all components from the req doc), document it in the output's README, and proceed. The user reviews after completion.
- **No subagents:** Generate wireframes sequentially in the main agent; run the reviewer critique inline rather than dispatching a separate reviewer agent.
- **No background processes:** Skip the local server and print the absolute `file://` path to `index.html` instead.
- **No Playwright MCP:** Note browser-based verification as a manual step for the user.

## Track Progress

This skill has multiple phases. Create one task per phase using your agent's task-tracking tool (e.g., `TodoWrite` in Claude Code, equivalent in other agents). Mark each task in-progress when you start it and completed as soon as it finishes — do not batch completions.

---

## Rigor & Corner-Cut Protocol

This skill is permissive — several phases have a "cheap option" (skip Phase 2.5, fewer Phase 4 loops, smaller PSYCH walkthrough). Permissiveness is fine; **silent downgrades are not**. The protocol below makes rigor visible.

### Rigor tiers

Pick the tier that matches the work. The tier governs Phase 4 (review loops) and the default density of Phase 2 / Phase 6 prompts.

- **High-rigor (default).** One reviewer subagent per file in parallel; full 2-loop protocol; full Phase 2.5 extraction; full Phase 6 walkthrough.
- **Medium-rigor (recommended for ≤ 6 files OR a focused enhancement).** ONE cross-file reviewer subagent (single message, multi-file critique); apply fixes; no second loop. Phase 2.5 still runs in full. Phase 6 still mandatory for Tier 2/3 but may collapse to a single subagent.
- **Low-rigor (personal-tool, single-user, time-bound only).** Inline grep + read-aloud spot-check against the rubric headings PLUS one mandatory cross-file reviewer subagent (200-word brief: aria coverage on icon-only buttons, focus-visible styles, contrast against dark/light surfaces, high-variance findings across files). The cross-file pass is non-negotiable — it's cheap (~30s) and catches what grep misses.

The user can override the chosen tier at any phase boundary. Default is high-rigor; recommend medium for ≤ 6 files; recommend low only when the user has signaled time-pressure or personal-tool context.

### Announcement rule (non-negotiable)

Whenever you choose the lighter option for a phase, **announce it before doing it** with this format:

> "Choosing [lighter option] for [phase] because [rationale]. Trade-off: [what we lose]. Override?"

The user gets one beat to redirect; if they don't, proceed. Phases that have cheap options and therefore require an announcement when downgraded:

- **Phase 2 scope-triage** — items classified as "skip wireframe" or "comparison only"
- **Phase 2.5** — when skipped despite a host frontend being present
- **Phase 3.5 screenshot ingestion** — when skipped despite screenshots being attached
- **Phase 4 review loops** — when running medium- or low-rigor instead of full
- **Phase 6 PSYCH** — when fewer than the available journeys are walked, or single-subagent collapse is used

Silently downgrading rigor is a small integrity leak that compounds across phases.

---

## Phase 0: Pipeline Setup (inline — do not skip)

Use workstream context (loaded by step 3 below) — design tokens, brand voice, and prior wireframe conventions live here. Wireframes are commonly produced before /spec, so this skill may create the feature folder.

<!-- pipeline-setup-block:start -->
1. **Read `.pmos/settings.yaml`.**
   - If missing → you MUST invoke the `Read` tool on `_shared/pipeline-setup.md` Section A and run first-run setup before proceeding. (Skipping this Read is the most common cause of folder-naming defects.)
2. Set `{docs_path}` from `settings.docs_path`.
3. If `settings.workstream` is non-null → load `~/.pmos/workstreams/{workstream}.md` as context preamble; if frontmatter `type` is `charter` or `feature` and a `product` field exists, also load `~/.pmos/workstreams/{product}.md` read-only.
4. Resolve `{feature_folder}`:
   - If `--feature <slug>` was passed → glob `{docs_path}/features/*_<slug>/`. **Exactly 1 match required**; on 0 or 2+ → you MUST `Read` `_shared/pipeline-setup.md` Section B before acting.
   - Else if `settings.current_feature` is set AND `{docs_path}/features/{current_feature}/` exists → use it.
   - Else → ask user (offer: create new with derived slug, pick existing from folder list, or specify via Other...).
5. **Edge cases — you MUST `Read` `_shared/pipeline-setup.md` Section B before acting:** slug collision, slug validation failure, legacy date-less folder encountered, ambiguous `--feature` lookup, any folder creation.
6. Read `~/.pmos/learnings.md` if present; note entries under `## /<this-skill-name>` and factor them into approach (skill body wins on conflict; surface conflicts to user before applying).
<!-- pipeline-setup-block:end -->

---

## Phase 1: Locate Requirements

1. **Find the requirements doc.** Follow `../.shared/resolve-input.md` with `phase=requirements`, `label="requirements doc"`. Accept either a path or inline feature description.
2. **No requirements doc found?** Stop and trigger `/requirements` first:
   - Tell the user: "Wireframes need a requirements doc to anchor user journeys. Running `/requirements` first."
   - Hand off to `/pmos-toolkit:requirements` with the user's original ask.
   - Resume `/wireframes` once the req doc is written.
3. **Read the req doc end-to-end.** Extract:
   - User journeys (each step the user takes)
   - Functional requirements that imply UI
   - Non-goals (so you do NOT wireframe out-of-scope flows)
   - Any explicit UX constraints (brand, accessibility tier, device support already declared)
3.5. **Ingest screenshots, if provided.** If the user passed `--screenshots <path>` (one or more times) OR attached images inline, follow `reference/screenshot-ingestion.md`:
   - Copy each image to `{feature_folder}/wireframes/assets/source-screens/`
   - Run vision-extraction per the prompt template in that file
   - Append a section per screenshot to `{feature_folder}/wireframes/assets/source-screens.md`
   - Defer the journey-anchoring `AskUserQuestion` step to the journey-confirmation gate below (so the user reviews journeys and screenshot mappings together)
   - If no screenshots provided, skip this step entirely.
4. **Confirm understanding.** Summarize the journeys you'll wireframe AND (if step 3.5 ran) propose anchor mappings between each screenshot and a journey step. Ask the user to confirm both via `AskUserQuestion` (batch ≤ 4 per call, screenshots first then journey list, sequential calls if needed). Update `source-screens.md` "Anchored to" lines per the user's answers. Platform fallback: present journeys + proposed mappings as a numbered list and ask for confirmation in free text.

**Gate:** Do not proceed until the user confirms the journey list.

---

## Phase 2: Component & Device Breakdown

### 2a-pre. Scope Triage (do this first)

Read every item in the requirements doc. For each, classify into one of three treatments:

| Class | Symptom | Treatment |
|---|---|---|
| **Net-new IA / flow** | new screen, new tab, new modal, reshaped chrome | Full wireframe with state matrix |
| **Comparison / before-after** | restyle, remove stripes, change a single visual property | Single-screen "before / after" wireframe (1 file, 2 states) |
| **Trivially specifiable** | data fix, label change, link wiring, refactor | Skip wireframe — note in handoff that /spec proceeds directly |

Present the triage table via `AskUserQuestion` (one question per row OR a single multiSelect with labeled rows) so the user confirms classifications before any inventory work. Default recommendations should be visible. Per the Rigor & Corner-Cut Protocol, **announce every "skip wireframe" and "comparison only" classification with rationale** — these are scope-cuts, not silent omissions.

After triage, only the items classed "Net-new IA / flow" or "Comparison / before-after" enter the inventory below. Skipped items get listed in the Phase 8 spec handoff under "Skipped from wireframing — proceed directly to /spec".

### 2a. Component Inventory

From the journeys, derive the design surface. Group into:

- **Screens / pages** — full-viewport destinations (e.g., "Dashboard", "Settings", "Onboarding step 2")
- **Modals / overlays** — temporary surfaces (e.g., "Confirm delete", "Image picker")
- **Reusable components** — surfaces that appear in multiple screens (e.g., "Top nav", "Empty-state card", "Toast")
- **Layouts** — only if multiple screens share a non-trivial chrome that's worth wireframing once

Write the inventory as a numbered list. Each item gets a `slug` (lowercase, hyphenated) — this becomes the filename later.

**For each item, look up matching patterns** in `patterns/README.md`. A screen is typically a composition of patterns (e.g., a "Deals dashboard" = `layout/page-header` + `data-display/stats-dashboard` + `data-display/table` + `feedback/empty-state`). Tag the inventory row with `patterns: [<category>/<file>, ...]`. If no pattern matches a component → tag `patterns: novel` and flag it for explicit human review (the generator should still produce it, but the reviewer subagent should pay extra attention).

### 2b. State Coverage

For each component, enumerate the states it must show. Standard checklist:

- Default / loaded
- Empty (no data yet)
- Loading
- Error / failure
- Success / confirmation
- Edge cases the req doc explicitly calls out (over-limit, partial-permission, etc.)

A wireframe file MUST cover every state for its component — use a state-switcher tab pattern (see `reference/html-template.md`) so reviewers can flip between states in one file.

### 2c. Device Selection

Ask the user (`AskUserQuestion`, multiSelect=true) which devices to target:

- desktop-web
- mobile-web
- desktop-app (Electron-like, treat as desktop-web with frame chrome)
- android-app (native patterns: bottom nav, FAB, system bar)
- ios-app (native patterns: tab bar, sheet, large title)

Default offered: whatever the req doc declared. If silent, recommend `desktop-web` + `mobile-web` for any consumer-facing feature.

### 2d. Clarifying Questions

Use `AskUserQuestion` (max 4 per call) to resolve genuine ambiguities about scope, IA, or interaction model. Do NOT ask cosmetic questions — those are reviewer-loop concerns. If you have no genuine ambiguities, skip and announce why.

**Gate:** Do not proceed until the user confirms the component inventory, state matrix, and device list. Print the matrix as a table:

```
| # | Component | Slug | Type | States | Devices | Patterns |
|---|-----------|------|------|--------|---------|----------|
```

The `Patterns` column lists the `patterns/<category>/<file>` references for each component. This drives what the generator and reviewer subagents load in Phases 3 and 4 — keep it accurate.

---

## Phase 2.5: Resolve DESIGN.md

> Decimal phase number is intentional — Phase 3 onward keeps existing numbering so external references (other skills, prior conversations) still resolve.

DESIGN.md is the durable, repo-resident brand contract for the target app. This phase **finds** it, or **creates** it on first run, then merges it (resolving `x-extends`) into an in-memory object that the rest of the skill consumes. The legacy in-folder `house-style.json` / `house-style.css` artifacts are gone — DESIGN.md replaces them.

Detailed procedure lives in three reference docs:
- `reference/design-md-spec.md` — schema (base + `x-*` extensions).
- `reference/design-md-resolver.md` — the resolution walk + `x-extends` cascade + staleness check + workstream persistence.
- `reference/design-md-extractor.md` — auto-extraction from a host frontend; interactive elicitation for greenfield.

### 2.5a — Resolve target app

Follow `reference/design-md-resolver.md` Step 1 (workstream-first, then frontend detection, then AskUserQuestion if ambiguous). The chosen `app_dir` persists to the workstream `## Wireframes & Design System` section as `target_app.path`.

### 2.5b — Find or create DESIGN.md

Follow `reference/design-md-resolver.md` Step 2 (walk: `<app>/DESIGN.md` → `packages/ui/DESIGN.md` → `<repo-root>/DESIGN.md`).

- **Found** → load it. Resolve `x-extends` per resolver Step 3. Run staleness check per resolver Step 4.
  - **Fresh** → proceed to 2.5c.
  - **Stale** → AskUserQuestion: **Re-extract** / **Use as-is** / **Abort**. Re-extract runs `reference/design-md-extractor.md` Branch A and rewrites the file (preserving any hand-edited `## Anti-patterns` and `x-content.voice` — diff and confirm before overwrite).
- **Not found** → run `reference/design-md-extractor.md`:
  - **Frontend present** → Branch A (auto-extract).
  - **Greenfield** → Branch B (interactive elicitation, 4 questions).
  - **Monorepo with shared `packages/ui/`** → AskUserQuestion: write to **shared base** (`packages/ui/DESIGN.md`) or **app-specific** (`<app_dir>/DESIGN.md`, with `x-extends` to the shared base if one exists). Recommend shared.

### 2.5c — Confirm with user

After load/create, AskUserQuestion:
- **Question:** "Use this DESIGN.md for wireframes?"
- **Options:** **Use as-is** / **Edit before continuing** / **Discard for this run**
- "Edit" → print absolute path; wait for user signal; re-read.
- "Discard" → set `x-source.applied: false` in the file; proceed with `wireframe.css` defaults only (no overlay).

### 2.5d — Generate `design-overlay.css`

Once confirmed, follow `reference/design-md-to-css.md` to produce `{feature_folder}/wireframes/assets/design-overlay.css` from the merged DESIGN.md. This file is regenerated every run.

### 2.5e — Workstream persistence

Update the workstream `## Wireframes & Design System` section per resolver Step 5: `target_app`, `design_md_path`, `components_md_path`, `last_extraction_sha` (only set on extract/re-extract).

### 2.5f — Migration from legacy `## Design System / UI Patterns`

If this is the first DESIGN.md created for this workstream AND the workstream has a non-empty `## Design System / UI Patterns` section (legacy from older `/wireframes` runs):
1. Show the user the existing patterns and the proposed DESIGN.md additions (into `## Anti-patterns` / `## Do's and Don'ts`).
2. AskUserQuestion: **Migrate (recommended)** / **Skip migration**.
3. On migrate: append patterns to DESIGN.md, replace the workstream section's body with `→ See DESIGN.md at <path>`.

**Subagents:** if available, dispatch one read-only subagent for extraction. Otherwise inline.

**Gate:** the user must confirm DESIGN.md before Phase 2.6 begins.

---

## Phase 2.6: Resolve Composition Context

DESIGN.md captures visual identity. Phase 2.6 captures **structural composition**: existing components, layout templates, and the decision log. Without this, Phase 3 would generate wireframes that *look* like the app but don't *fit* it.

Output of this phase is three in-memory blobs passed to Phase 3:
- `components_inventory` — from COMPONENTS.md.
- `layout_anchor` — chosen named layout from `x-information-architecture.layouts`.
- `decision_context` — concatenated workstream scars + DESIGN.md anti-patterns.

### 2.6a — Load or create COMPONENTS.md

COMPONENTS.md lives in the same dir as DESIGN.md. Procedure per `reference/components-md-spec.md` ("Extractor procedure"):

- **Found and fresh** (commit SHA matches DESIGN.md's `x-source.sha` ± any `/verify` updates) → load.
- **Found but stale** → offer re-extract via AskUserQuestion: **Re-extract** / **Use as-is**.
- **Missing AND host frontend exists** → run the extractor; write to `<dirname design_md_path>/COMPONENTS.md`; AskUserQuestion accept/edit/skip gate (same shape as 2.5c).
- **Missing AND greenfield** → write a stub COMPONENTS.md (header + `_No components yet._`). Don't block.

### 2.6b — Pick a layout anchor

If DESIGN.md `x-information-architecture.layouts` has entries:
- AskUserQuestion (single-select): "Which existing layout does this feature follow?"
- Options: each named layout + "None — start fresh"
- Cap at 4; if more, recommend the 3 most common (by call-site count if available, else alphabetical).

The chosen layout name + skeleton (from `x-information-architecture.layouts.<name>.skeleton`) is the `layout_anchor` passed to Phase 3.

**Persist the chosen layout name** to `{feature_folder}/wireframes/.layout-anchor` (single-line text file). This lets `/prototype` Phase 1.5 inherit the anchor without re-asking.

If no layouts are declared, skip — generators infer from DESIGN.md `## Layout` prose.

### 2.6c — Assemble decision context

Build a single text block by concatenating, in this order:
1. Workstream `## Constraints & Scars` (if loaded in Phase 0).
2. DESIGN.md `## Anti-patterns` (if present).
3. DESIGN.md `## Do's and Don'ts`.
4. Workstream `## Design System / UI Patterns` (only if migration in 2.5f was skipped).

This is read-only — Phase 2.6 never writes to the workstream's `## Constraints & Scars` (that needs human judgment).

**Gate:** none — Phase 2.6 is data assembly. Proceed to Phase 3.

---

## Phase 3: Generate Wireframes (Parallel Subagents)

For each `(component × device)` pair in the matrix, generate one HTML file at:

```
{feature_folder}/wireframes/{NN}_{screen-slug}.html
```

Where `NN` is a 2-digit zero-padded sequence number reflecting intended viewing order. The skill controls numbering — start at `01` and increment per screen, following the inventory order. Use a `{screen-slug}` that combines the component slug and device (e.g., `01_dashboard_desktop-web.html`). Supporting assets (CSS, images, thumbnails) live in `{feature_folder}/wireframes/assets/`.

### 3a. Copy shared stylesheet (do this BEFORE any wireframe is generated)

Copy `assets/wireframe.css` from this skill into the output folder so every wireframe can link `./assets/wireframe.css` (relative). Resolve the skill path from `${CLAUDE_PLUGIN_ROOT}` when available; otherwise fall back to the cached plugin path:

```bash
mkdir -p "{feature_folder}/wireframes/assets"
cp "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude-personal/plugins/cache/pmos-toolkit/pmos-toolkit/*/}skills/wireframes/assets/wireframe.css" \
   "{feature_folder}/wireframes/assets/wireframe.css"
```

If the copy fails (path not resolvable), `Read` the skill's `assets/wireframe.css` and `Write` it to the destination. Do NOT inline the contents into individual wireframe files.

### 3b. Generation Protocol

**If subagents are available** (Claude Code): dispatch `general-purpose` subagents in parallel — one per component (NOT per file; a single subagent generates all device variants for its component to keep them visually consistent). Send up to ~5 subagents in a single message. Each subagent receives:
- The component's inventory entry, states, and assigned devices
- Relevant excerpts from the req doc (journeys this component participates in)
- The full HTML template from `reference/html-template.md`
- **Only the pattern files tagged on this component's inventory row** (typically 1–3 files from `patterns/`). Do NOT pass the whole patterns library — it's too large and dilutes attention. The patterns are authoritative: each pattern's "best practices", "common mistakes", and "skeleton" must be respected
- Workstream tech-stack hints if loaded (brand color, type stack — note: most of this now lives in DESIGN.md)
- **The merged DESIGN.md (after `x-extends`) verbatim** as YAML, plus the instruction: "Link `./assets/design-overlay.css` immediately after `./assets/wireframe.css` in every generated file. The overlay handles tokens; honor `## Components` prose for shape patterns and `x-interaction` for behavior."
- **The Phase 2.6 `components_inventory` (COMPONENTS.md content)** with the instruction: "When wireframing a button/input/card/modal/etc., prefer the variant names listed in COMPONENTS.md over inventing new ones. If no matching component exists in the inventory, mock the new component AND flag it in the file footer under 'New components proposed: <list>' so the reviewer can confirm."
- **The Phase 2.6 `layout_anchor`** (named layout + skeleton) with the instruction: "Use this layout shell as the chrome for screen-level wireframes. Modals and overlays are exempt." If `layout_anchor` is "None — start fresh", omit this block.
- **The Phase 2.6 `decision_context`** (workstream scars + DESIGN.md anti-patterns) with the instruction: "Honor every anti-pattern listed. If a wireframe needs to violate one, flag it in the file footer with rationale."
- **If this component has at least one anchored screenshot** (per `source-screens.md`): include only that screenshot's description block (not the whole file) plus the absolute path to the original image. Include the IA-preservation instruction from `reference/screenshot-ingestion.md` ("match layout/IA, may improve states/a11y/copy, must NOT silently reorganize IA"). Components without anchored screenshots receive no screenshot context.
- Strict instruction: produce ONLY the HTML file(s), no commentary

**If subagents are unavailable**: generate sequentially in the main agent.

### File Requirements (every wireframe MUST satisfy)

- One `.html` file per `(component × device)` pair
- Links the shared `./assets/wireframe.css` (copied in step 3a) — do NOT inline the rules from that stylesheet
- Links `./assets/design-overlay.css` **immediately after** `wireframe.css` so DESIGN.md's `:root` overrides take effect (skip the link only if the user chose "Discard for this run" in Phase 2.5c)
- Tailwind via CDN: `<script src="https://cdn.tailwindcss.com"></script>` (used alongside the shared CSS for layout/spacing utilities)
- State-switcher tabs at the top so reviewers flip between states without reload
- Annotations layer (toggleable) explaining non-obvious interactions
- Realistic placeholder copy (not "Lorem ipsum") drawn from the req doc's domain
- Device frame:
  - desktop-web → 1280×800 viewport hint, no chrome
  - mobile-web → 375×812 frame with rounded corners
  - android-app → status bar + bottom nav chrome
  - ios-app → status bar + home indicator + tab bar chrome
  - desktop-app → window chrome with traffic-light buttons
- Accessibility baseline: semantic HTML, focus-visible styles, aria labels on icon-only buttons, contrast ≥ 4.5:1 for text
- Touch targets ≥ 44×44px on mobile/native variants
- A bottom footer with: component name, device, file index, generation date

The full template lives in `reference/html-template.md` — do not deviate from its structure unless the component genuinely needs it.

---

## Phase 4: Self-Refinement (Reviewer Subagent + Loops)

### 4a. Loop-rigor decision (do this before dispatching anything)

Pick the rigor tier per the **Rigor & Corner-Cut Protocol** at the top of this skill:

- **High-rigor (default):** one reviewer subagent per file in parallel; up to 2 refinement loops per file.
- **Medium-rigor:** ONE reviewer subagent across all files (single message, multi-file critique); apply fixes; no second loop. Recommend for ≤ 6 files or a focused enhancement.
- **Low-rigor:** inline grep + spot-check PLUS one mandatory cross-file reviewer subagent (200-word brief: aria-label coverage on icon-only buttons, focus-visible styles, color contrast against dark/light surfaces, high-variance findings across files). The cross-file pass is **non-negotiable** even in low-rigor — grep alone misses contrast, focus-visible rendering, and "wireframe 01 didn't actually change relative to current state" type findings.

**Announce the chosen tier with rationale before proceeding.** Format: "Choosing [tier] for Phase 4 because [reason]. Trade-off: [what we lose]. Override?"

The remainder of this phase describes the high-rigor protocol. Medium- and low-rigor variants follow the same loop structure but with the subagent fan-out reduced as described above.

### 4b. Loop Structure (high-rigor)

For each generated wireframe file, run up to 2 refinement loops. Stop early when the reviewer reports zero issues at severity ≥ medium.

**Step 1 — Dispatch reviewer subagent (parallel where possible):**
- One reviewer subagent per wireframe file
- Prompt: load `reference/eval-rubric.md` AND the pattern files tagged on this component's inventory row (the same files the generator received). Score the file against BOTH the rubric heuristics and the pattern's "best practices" / "common mistakes". Return findings as JSON: `[{source: "rubric:<id>" | "pattern:<file>:<rule>", severity: high|medium|low, finding, suggested_fix}]`. Cross-referencing both sources catches issues that pure heuristics miss (e.g., "destructive action in middle of dropdown menu" is a `dropdown-menu.md` rule, not a generic heuristic).

**Step 2 — Apply fixes:**
- For findings at severity `high` or `medium`: apply the suggested fix via `Edit` (or have a generator subagent re-emit the fixed section)
- For severity `low`: log in the wireframe footer as "Known minor issues" and skip
- Track every change in a `Review Log` HTML comment block at the top of the file

**Step 3 — Decide loop continuation:**
- If high/medium findings remain → run loop 2
- If only low findings or none → exit
- Hard cap: 2 loops per file regardless

**Platform fallback (no subagents):** run the reviewer pass inline — read the file, mentally apply the rubric, log findings, fix.

### Findings Presentation Protocol (cross-file rollup)

After all per-file refinement is done, present a cross-file rollup of any unresolved high/medium findings to the user via `AskUserQuestion`:

1. **Group findings by heuristic category** (max 4 per batch — respects the `AskUserQuestion` 4-question limit).
2. **One question per finding**:
   - `question`: one-sentence finding + which file(s) it affects + proposed fix
   - `options`: **Fix as proposed** / **Modify** / **Skip** / **Defer**
3. **Batch up to 4 questions per call**; sequential calls for more.
4. **Open-ended findings** (free-form fixes): ask inline as a follow-up.
5. **Platform fallback** (no `AskUserQuestion`): present findings as a numbered table with disposition column; do NOT silently self-fix.

**Anti-pattern:** A wall of prose ending in "Let me know what you'd like to fix." Always structure the ask.

**Edge cases of structured asks:** when a user reply slips outside the offered options (free-form text, a non-recommended pick that may break an invariant, or leftover findings that don't share a category), follow `../_shared/structured-ask-edge-cases.md`.

---

## Phase 5: Index & Serve

### 5a. Generate `index.html`

Create `{feature_folder}/wireframes/index.html` with:

- Header: feature name, generation date, link back to req doc
- **Device tabs** at the top — one tab per device targeted; clicking filters the card grid. **When only one device is targeted, omit the device-tabs row entirely** (a single-tab control is visual noise). Document the omission in the index footer ("All wireframes target desktop-web — device filter omitted") so the user knows it was intentional, not forgotten.
- **Card grid** — one card per `(component × device)` pair showing:
  - Component name + device chip
  - State count badge ("4 states")
  - 200×140 px iframe preview of the wireframe (scaled), or a static thumbnail block if iframes prove flaky
  - Click → opens the wireframe in a new tab
- Search box that filters cards by component name
- Footer: total file count, file path of the folder

**The index does NOT include:** state-switcher tabs or annotations toggles. Those live inside each wireframe file (per `reference/html-template.md`). The index is purely a navigation surface — a card grid + filter, nothing else. If a reviewer wants to flip states or toggle annotations, they open the wireframe in a new tab.

Use the same Tailwind CDN approach AND link the shared `./assets/wireframe.css` so the index inherits the same theme tokens, typography, and chrome styles as the wireframe files. The index must work offline as a `file://` URL.

### 5b. Serve

Detect Node:

```bash
command -v node && command -v npx
```

- **Node available**: start a static server in the background:
  ```bash
  cd {feature_folder}/wireframes && npx --yes http-server -p 0 -c-1 --silent
  ```
  Capture the printed port and report `http://localhost:<port>/index.html` to the user.
- **Node missing**: print the absolute `file://` path to `index.html` and tell the user to open it in Chrome. Note that some browsers restrict iframe loading from `file://` — the cards may need to be opened in new tabs instead.

Always print BOTH the served URL (if any) AND the file path so the user has a fallback.

---

## Phase 6: PSYCH Walkthrough

After per-wireframe refinement (Phase 4) and the index (Phase 5), run a **journey-level** PSYCH pass to catch flow-level drops in user drive that component-level review can't see. Phase 4 asks "is this wireframe well-built?"; Phase 6 asks "does the user's drive to continue survive this flow?" Both are needed.

### 6a. Tier detection

Read the tier tag from the requirements doc (carried forward from `/requirements`). If absent, ask via `AskUserQuestion`:

- **Question**: "What tier is this feature?"
- **Options**: **Tier 1: Bug fix / minor enhancement** / **Tier 2: Enhancement / UX overhaul (Recommended for most user-facing work)** / **Tier 3: New feature / new system**
- One-line rule shown in option descriptions: "Tier 1 = isolated bug fix or small change; Tier 2 = improving existing surface; Tier 3 = new capability or major redesign."

**Tier gating for Phase 6:**
- **Tier 1**: skip Phase 6 entirely → jump to Phase 8 (Spec Handoff). Tier 1 wireframes are usually 1–2 screens; PSYCH is overkill.
- **Tier 2 / Tier 3**: PSYCH is **mandatory**. Continue.

### 6b. Select journeys

Pull the user-journey list from the requirements doc. **Cap at 5 journeys per session** — more than 5 produces shallow output and review fatigue.

**Always confirm the journey list with the user via `AskUserQuestion` (multiSelect, max 5 selections)** — even when the req doc has ≤ 5 explicit journeys, and even when you derived the list yourself. Many req docs contain *implicit* journeys (overflow-menu paths, recovery flows, error-state walks) that aren't numbered as such; the confirmation step is the only place those surface.

- Recommended option: "the 3–5 journeys you derived, in priority order" (signup, first-value, primary daily flow, share/invite, recovery are the canonical stakeholder-visible set).
- Always include "Other (specify)" so the user can name a journey you missed.
- **Bias toward including any journey that walks through a wireframe with a verified bug or a known-broken state** — those are exactly the journeys most worth pressure-testing.

Platform fallback: present the list as a numbered list and ask for confirmation in free text.

For each selected journey:
- Identify the wireframes that participate (by component slug from the inventory matrix)
- Note the order: step 1 → step 2 → ... → completion
- Default the **entry-context starting score to Medium (40)** silently per /msf's PSYCH rubric. Document the assumption at the top of `psych-findings.md`. The user can override later by editing the doc and re-running.

### 6c. PSYCH scoring rubric (matches /msf format for artifact compatibility)

This rubric is the same shape as `/msf` Pass B so artifacts are interchangeable.

**Starting score per journey**: Medium-intent = 40 (default; see 6b for context).

**Score every notable element on each screen** at +1 to +10 (positives) or -1 to -10 (negatives). Skip neutral / expected elements — do NOT pad scores by inventing positives just to balance the sheet. Collapse like-kind elements into one row (e.g., "5 nav links — minor, -5 total") rather than enumerating identical items.

**+Psych drivers (canonical palette):**
- Positive emotions: attractive visuals, social proof, credibility signals
- Motivational boosts: urgency, progress indicators, value previews, completion cues
- Rewards: immediate value delivery, clear outcomes, "aha" moments

**-Psych drivers (canonical palette):**
- Physical effort: form fields, data entry, clicks, scrolling, waiting
- Decisions to make: choices, configurations, ambiguous options, unfamiliar terminology
- Questions to figure out: unclear UI, unknown costs, jargon, missing feedback

**Thresholds (matches /msf):**
- Cumulative score `< 20` → **danger zone** (high severity)
- Cumulative score `< 0` → **bounce risk** (critical severity)
- Single-screen Δ drop `> 20` → **flagged regardless of cumulative** (something on this screen pushes the user off a cliff even if the running total is healthy)

### 6d. Walkthrough protocol

For each journey:

1. **Trace the steps in order**. Print the trace before scoring so the user can see the path being evaluated:
   ```
   Journey: New user creates first project   (start: 40, Medium-intent)
     Step 1 → 03_signup-form_desktop-web.html
     Step 2 → 05_email-verify_desktop-web.html
     Step 3 → 09_workspace-empty_desktop-web.html
     Step 4 → 11_create-project-modal_desktop-web.html
     Step 5 → 12_project-detail_desktop-web.html
   ```
2. **Walk each screen left-to-right, top-to-bottom**, scoring every notable element. Sum element scores → screen Δ. Update running total: `cumulative = previous + Δ`.
3. **If subagents are available**: dispatch one subagent per journey in parallel. Each subagent receives the journey's wireframe files (read from disk), the journey description from the req doc, the canonical driver palette above, and the threshold rules. Returns:
   - Per-element rows (for the audit table)
   - Per-screen rollup (for the stakeholder table)
   - List of flagged screens (those crossing thresholds)
4. **If subagents unavailable**: walk sequentially in the main agent.

### 6e. Output: dual-table `psych-findings.md`

Save to `{feature_folder}/wireframes/psych-findings.md`. Format details — header, per-journey block, dual tables (element + screen rollup), driver palette, severity assignment, sparkline, applied-changes log, unsurfaced-findings log — are specified in `reference/psych-output-format.md`. Follow that format exactly so artifacts are interchangeable with `/msf` Pass B output.

### 6f. Findings Presentation Protocol

Surface findings via `AskUserQuestion`. Group by target:

1. **Wireframe-target findings**: each question states finding + proposed wireframe edit. Options: **Apply edit** / **Modify** / **Skip** / **Defer to spec stage**.
2. **Req-doc-target findings** (journey gap, wrong ordering, missing step): options: **Update req doc** / **Modify** / **Skip** / **Defer to spec stage**.
3. **Batch ≤ 4 per call**; sequential calls for more. **Cap total findings surfaced at 12** — prioritize highest severity (bounce risk → danger → single-screen-Δ-drop). Rest log to `psych-findings.md` under "Unsurfaced findings" for later review.

**Platform fallback (no `AskUserQuestion`):** present a numbered table grouped by target with disposition column. Do NOT silently self-fix.

**Anti-pattern:** A wall of prose ending in "Let me know what you'd like to fix." Always structure the ask.

**Edge cases of structured asks:** when a user reply slips outside the offered options (free-form text, a non-recommended pick that may break an invariant, or leftover findings that don't share a category), follow `../_shared/structured-ask-edge-cases.md`.

### 6g. Apply dispositions

- **Wireframe edits**: apply via `Edit` to the affected file. **Inline spot-check** the edited file against `reference/eval-rubric.md` heuristics — confirm no regression. Do NOT trigger another Phase 4 review-loop pass.
- **Req-doc edits**: apply to the requirements doc directly. Propagates to `/spec` and to /msf if Phase 7 runs.
- Log every applied change in `psych-findings.md` under "Applied changes" with: journey, screen, finding, fix, status.

### 6h. Exit criteria

- All bounce-risk and danger findings have explicit dispositions
- `psych-findings.md` written and committed alongside the wireframes folder
- User confirms ready to proceed to Phase 7

**Hard caps:** max 5 journeys per session, max 12 findings surfaced via AskUserQuestion, max 1 application pass (no re-walking — defer follow-ups to next session).

---

## Phase 7: MSF Analysis (inline /msf invocation)

PSYCH (Phase 6) measures the running drive curve. MSF asks the persona-conditional question PSYCH can't: "for THIS persona in THIS scenario, where does motivation/friction/satisfaction land?" A PSYCH dip might be fatal for the new-user persona but irrelevant for the power-user persona — only MSF distinguishes those.

### 7a. Tier gating

- **Tier 1**: skip Phase 7 → jump to Phase 8.
- **Tier 2**: optional. Gate via `AskUserQuestion`:
  - **Question**: "Run MSF analysis now? It layers persona-conditional motivation/friction/satisfaction analysis on top of PSYCH and applies edits inline (with per-finding approval). Optional for Tier 2. Takes ~10 min."
  - **Options**: **Run MSF now (Recommended for user-facing surface)** / **Skip — proceed to spec handoff**
  - Platform fallback: state assumption "Skipping MSF for Tier 2 unless you ask for it" and proceed.
- **Tier 3**: mandatory. Announce: "Tier 3 detected — MSF analysis is mandatory. Running /msf inline now."

### 7b. Inline /msf invocation

Invoke `/msf` as a sub-procedure rather than handing off. Skills stay independent at the SKILL level (`/msf` remains its own skill with its own command), but at runtime /wireframes delegates to /msf's procedure to avoid duplicating logic.

**Steps:**

1. **Announce the boundary**: "Entering /pmos-toolkit:msf for MSF analysis. Returning to /wireframes Phase 8 when /msf completes."
2. **Read** `../msf/SKILL.md` (relative to the skills directory).
3. **Construct arguments**:
   - `<requirements-doc>`: the path resolved in /wireframes Phase 1
   - `--wireframes {feature_folder}/wireframes`: the folder created in Phase 3
   - `--skip-psych`: Phase 6 already produced `psych-findings.md`; /msf Pass B references it, doesn't re-score
   - `--default-scope=both`: pre-recommends "update both req doc and wireframes" in /msf Phase 5 (user can still override)
4. **Execute /msf's phases inline** with these arguments:
   - /msf "Locate Requirements" → already resolved, pass through
   - /msf "Locate Wireframes" → resolves the `--wireframes` folder, reads `.html` files and `psych-findings.md`
   - /msf Phase 1 (Personas) → /msf's standard AskUserQuestion-driven persona alignment
   - /msf Phase 2 (Journeys) → confirm journeys (likely the same set as /wireframes Phase 6, but /msf may add scenarios per persona)
   - /msf Phase 3 (Analyze) → Pass A only (`--skip-psych` skips Pass B). Wireframes are first-class input — analysis cites specific screens / steps / elements.
   - /msf Phase 4 (Prioritize) → Must / Should / Nice-to-have grouping with per-recommendation user approval
   - /msf Phase 5 (Apply changes) → edits both req doc AND wireframes inline (user approves per recommendation; `--default-scope=both` is the default answer)
   - /msf Phase 6 (Consistency Pass) → cross-check applied changes against revised requirements
   - /msf "Save Analysis" → writes `docs/msf/YYYY-MM-DD-<feature>-msf-analysis.md` (canonical) AND `{feature_folder}/wireframes/msf-findings.md` (copy with header pointing to canonical)
   - /msf Phase 7 (Capture Learnings) → /msf logs its own learnings; /wireframes Phase 10 logs its separately
5. **Announce completion**: "Exited /pmos-toolkit:msf. Resuming /wireframes Phase 8 (Spec Handoff)."

**Note:** /msf's edits to wireframes follow the same approval flow /msf uses standalone (its Phase 4 prioritization + Phase 5 scope check). /wireframes does NOT add a separate approval gate — that would double-prompt the user.

### 7c. Post-/msf verification

After /msf returns:

1. **Spot-check edited wireframes** against `reference/eval-rubric.md` (same as Phase 6 post-edit check). Do NOT trigger Phase 4 review-loops.
2. Confirm both artifacts exist:
   - `docs/msf/YYYY-MM-DD-<feature>-msf-analysis.md`
   - `{feature_folder}/wireframes/msf-findings.md` (copy)
3. Confirm any wireframes /msf modified now reference the same `./wireframe.css` (they should — Edit doesn't touch the link).

### 7d. Exit criteria

- /msf completed all its phases (1–7)
- All high-severity MSF findings have explicit dispositions (handled inside /msf)
- Both `psych-findings.md` and `msf-findings.md` exist in the wireframes folder
- Edited wireframes pass eval-rubric.md spot-check
- User confirms ready for spec handoff

---

## Phase 8: Spec Handoff

Append a `## Wireframes` section to the requirements doc:

```markdown
## Wireframes

Generated: {YYYY-MM-DD}
Folder: `{relative_path_to_folder}`
Index: `{relative_path}/index.html`
PSYCH walkthrough: `{relative_path}/psych-findings.md` (if Phase 6 ran)
MSF analysis: `{relative_path}/msf-findings.md` (if Phase 7 ran; canonical at `docs/msf/...md`)

| # | Component | Devices | States | File |
|---|-----------|---------|--------|------|
| 01 | … | … | … | `01_…_desktop-web.html` |
```

Commit:

```bash
git add {feature_folder}/wireframes/ {requirements_doc_path}
# If Phase 7 ran, also stage the canonical /msf doc:
git add docs/msf/*-msf-analysis.md 2>/dev/null || true
git commit -m "docs: add wireframes for <feature>"
```

Tell the user: "Wireframes are ready. Open `{served_url_or_file_path}` to review. When you're satisfied, run `/pmos-toolkit:spec` — it will pick up the wireframes, PSYCH findings, and (if it ran) MSF findings from the requirements doc automatically."

---

## Phase 9: Workstream Enrichment

**Skip if no workstream was loaded in Phase 0.** Otherwise, this phase writes only the **navigation pointers** for the Wireframes & Design System contract — visual content lives canonically in `DESIGN.md` and `COMPONENTS.md`, not the workstream.

Update (or create) the workstream's `## Wireframes & Design System` section with these four fields exactly:

```yaml
target_app:
  path: <app_dir>
  confirmed_at: <YYYY-MM-DD>
design_md_path: <relative path>
components_md_path: <relative path>
last_extraction_sha: <SHA at extraction; only set/update on extract>
```

**Do NOT write** brand color, typography, or recurring component patterns into `## Tech Stack` / `## Design System / UI Patterns` — those facts are canonical in DESIGN.md/COMPONENTS.md. Duplicating them creates drift.

**Device support decisions** still go to workstream `## Constraints & Scars` if they're new and reusable across features (e.g. "no iOS app — never wireframe ios-app"). One-off device choices stay local to the feature folder.

`## Constraints & Scars` is otherwise read-only from this skill — Phase 2.6 reads it; nothing here writes to it automatically. (Migration of an existing `## Design System / UI Patterns` section is handled in Phase 2.5f, not here.)

This phase is mandatory whenever Phase 0 loaded a workstream — do not skip it just because the core deliverable is complete.

---

## Phase 10: Capture Learnings

**This skill is not complete until the learnings-capture process has run.** Read and follow `learnings/learnings-capture.md` (relative to the skills directory) now. Reflect on whether this session surfaced anything worth capturing — surprising behaviors, repeated corrections, non-obvious decisions (e.g., a heuristic that fired repeatedly, a Tailwind pattern that broke on iOS Safari, a device the user always wants but never declares upfront, a PSYCH driver pattern that recurred across journeys, an MSF persona-conditional finding that PSYCH alone missed). Proposing zero learnings is a valid outcome for a smooth session; the gate is that the reflection happens, not that an entry is written.

---

## Anti-Patterns (DO NOT)

- Do NOT generate wireframes without a confirmed user-journey list — you'll miss flows or invent ones
- Do NOT use `Lorem ipsum` — it makes reviewers debate the layout instead of the content
- Do NOT use real photographs or finished iconography — wireframes are not visual design
- Do NOT skip the state matrix — a wireframe that shows only the happy path hides the hard work
- Do NOT split a single component across multiple files per state — use the state-switcher tab pattern
- Do NOT exceed 2 refinement loops per file — diminishing returns; defer to user review
- Do NOT silently self-fix high-severity findings without the cross-file rollup question
- Do NOT skip `index.html` even for a single-component feature — it documents the artifact set
- Do NOT generate wireframes for non-user-facing features (cron jobs, internal APIs) — recommend skipping the skill
- Do NOT commit half-finished wireframes — finish all phases before the git commit in Phase 8
- Do NOT run PSYCH (Phase 6) on more than 5 journeys in one session — past 5, output gets shallow and reviewer fatigue sets in
- Do NOT run PSYCH per-wireframe (it's flow-level; per-wireframe is what Phase 4 does)
- Do NOT trigger a second Phase 4 review-loop pass to verify PSYCH or MSF edits — just spot-check the edits against `eval-rubric.md` inline
- Do NOT skip Phase 6 on Tier 2 or Tier 3 — PSYCH is mandatory for both (Tier 1 only is exempt)
- Do NOT skip Phase 7 on Tier 3 — MSF is mandatory; Tier 2 is gated, Tier 1 is exempt
- Do NOT pad PSYCH scores by inventing positive elements to balance negatives — score only what's notable, leave the column empty if the screen is genuinely neutral
- Do NOT enumerate identical elements separately (5 nav links each at -1) — collapse to one row ("Nav links (5), -5 total")
- Do NOT default the entry-context to High (60) or Low (25) silently — Medium (40) is the unbiased default unless the req doc declares otherwise
- Do NOT add a separate /wireframes approval gate around /msf's edits in Phase 7 — /msf already has its own per-recommendation approval flow (its Phase 4 + Phase 5); double-prompting confuses the user
- Do NOT auto-invoke /msf in Phase 7 without announcing the boundary — print "Entering /msf" and "Exiting /msf" so the user can follow the flow
- Do NOT blend tokens from multiple host frontends in Phase 2.5 — pick one (user-selected) so wireframes have a coherent visual language
- Do NOT use screenshots as the sole journey source — they augment the requirements doc, they don't replace it; trigger /requirements first if no req doc exists
- Do NOT redesign IA away from an anchored screenshot without explicit user direction — generators may improve states, a11y, and copy, but moving primary actions or restructuring sections needs the user to ask for it
- Do NOT silently downgrade rigor at any phase — the Rigor & Corner-Cut Protocol mandates announcement-with-rationale before choosing a lighter option (skipping subagents, fewer review loops, smaller PSYCH walkthrough). Silent downgrades compound across phases and erode user trust in the artifact
- Do NOT skip Phase 2.5 (Resolve DESIGN.md) — even if you "know" the tokens. DESIGN.md is the durable artifact other tools (Stitch, Cursor, /verify) consume; not having it is technical debt. Cost is ~1 minute when the file exists; ~5 minutes on first creation
- Do NOT write brand colors, typography, or component patterns into the workstream — those live in DESIGN.md / COMPONENTS.md. The workstream stores only the four navigation fields (`target_app`, `design_md_path`, `components_md_path`, `last_extraction_sha`)
- Do NOT bypass COMPONENTS.md by inventing button/input/card/modal variants — Phase 3 generators must prefer existing variants and flag novel ones explicitly in the file footer
- Do NOT modify the workstream `## Constraints & Scars` from this skill — Phase 2.6 reads it; only humans (or `/verify` with explicit confirmation) write to it
- Do NOT keep the legacy `house-style.json` / `house-style.css` artifacts alive in new feature folders — Phase 2.5 produces `design-overlay.css` from DESIGN.md instead. Old folders' artifacts are left in place but not consulted
