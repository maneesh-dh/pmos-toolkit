---
name: prototype
description: Generate a high-fidelity, single-HTML-per-device interactive prototype (React via CDN + JSX, simulated API calls, domain-real LLM-generated mock data) that stitches all wireframe screens into walkable user journeys. Optional bridge between /wireframes and /spec in the requirements -> spec -> plan pipeline. Tier 1 skip; Tier 2 optional; Tier 3 mandatory. Inherits from wireframes (visual reference, IA, copy) and produces forms, CRUD, navigation, loading/error states without any backend or build step. Self-evaluates with a reviewer subagent (≤2 loops per device file) and runs an interactive friction pass measuring clicks/keystrokes/decisions per journey. Use when the user says "create a prototype", "make this clickable", "high-fi mockup", "stakeholder demo", "interactive prototype", "prototype this feature", or has wireframes ready and wants stakeholders to experience the flow before /spec.
user-invocable: true
argument-hint: "<path-to-requirements-doc or feature description> [--devices=desktop-web,mobile-web,...] [--feature <slug>]"
---

# Prototype Generator

Produce a single-HTML-per-device interactive prototype that stitches wireframe screens into walkable user journeys with simulated API calls, mock data, and full client-side interactivity. Output is high-fidelity (real brand colors, typography, no annotation chrome) but unmistakably NOT the real product (no backend, in-memory only, mock data). This is an OPTIONAL stage that sits between wireframes and spec for user-facing features:

```
/requirements  →  /wireframes  →  [/prototype]  →  /spec  →  [/simulate-spec]  →  /plan  →  /execute  →  /verify
                                  (this skill, optional)
```

Use this when stakeholders need to experience the flow end-to-end before committing to implementation. Skip for backend-only or API-only features.

**Single-HTML-per-device** is the scope fence: the prototype is a stakeholder-confidence and design-validation artifact, not the implementation. No build step, no npm packages, no backend — the user can email the folder to a stakeholder and it works.

**Announce at start:** "Using the prototype skill to generate an interactive prototype for this feature."

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:
- **No `AskUserQuestion`:** State your assumption (default devices = wireframes' device list; default scope = all wireframe screens; mock data = use as generated; layout anchor = first declared in DESIGN.md or none if none exist), document it in the output's `index.html`, and proceed. For Phase 1.5 staleness prompts, default to "Use as-is" and note the staleness in the index footer.
- **No subagents:** Generate sequentially in the main agent; run review and friction passes inline.
- **No background processes:** Skip the local server and print the absolute `file://` path to `index.html`.
- **No Playwright MCP:** Note browser-based verification as a manual step for the user.

## Track Progress

This skill has 14 phases (Phase 1.5 was added in v2.8.0 for DESIGN.md resolution). Create one task per phase using your agent's task-tracking tool (e.g., `TodoWrite` in Claude Code, equivalent in other agents). Mark each task in-progress when you start it and completed as soon as it finishes — do not batch completions.

---

## Phase 0: Load Workstream Context & Learnings

Before any other work, follow the context loading instructions in `product-context/context-loading.md` (relative to the skills directory). This determines `{docs_path}` and loads workstream context if available — brand voice, design tokens, domain hints, and prior prototype conventions live here. Also read `~/.pmos/learnings.md` if it exists. Note any entries under `## /prototype` and factor them into your approach for this session.

**Resolve feature folder.** Follow `../_shared/feature-folder.md` with `skill_name=prototype`, `feature_arg=<--feature value or empty>`, and `feature_hint=<topic from user input>`. Use the returned folder path as `{feature_folder}`. Prototype is produced AFTER /wireframes, so the folder typically already exists.

---

## Phase 1: Locate Inputs

1. **Find the requirements doc.** Follow `../.shared/resolve-input.md` with `phase=requirements`, `label="requirements doc"`. Accept either a path or inline feature description.
2. **No requirements doc found?** Stop and trigger `/wireframes` (which will trigger `/requirements` if needed):
   - Tell the user: "Prototype needs requirements + wireframes. Running `/wireframes` first."
   - Hand off to `/pmos-toolkit:wireframes` with the user's original ask.
   - Resume `/prototype` once both docs exist.
3. **Find the wireframes folder.** Default location: `{feature_folder}/wireframes/`. Check for `index.html` and at least one `NN_*.html` file.
4. **No wireframes found?** Trigger `/pmos-toolkit:wireframes` (announce, hand off, resume).
5. **Read inputs end-to-end:**
   - Req doc: extract user journeys, business rules, entity model, tier tag
   - Wireframes: read `index.html` for the inventory matrix; read each `NN_*.html` for layout, copy, visible fields, state list
   - `wireframes/assets/design-overlay.css` if present (reused as the prototype's CSS overlay in Phase 1.5; otherwise regenerated from DESIGN.md)
6. **Confirm understanding.** Summarize the journeys to be made interactive and the device list. Ask via `AskUserQuestion` (≤4 batched). Platform fallback: numbered list + free-text confirmation.

**Gate:** Do not proceed until the user confirms.

---

## Phase 1.5: Resolve DESIGN.md & Composition Context

> Decimal phase number is intentional — Phase 2 onward keeps existing numbering so external references (other skills, prior conversations) still resolve.

`/prototype` consumes the same canonical design artifacts as `/wireframes` and `/verify`: DESIGN.md (visual identity + `x-interaction` + `x-content`), COMPONENTS.md (component-library inventory), `design-overlay.css` (CSS variable overlay), and a new `design-tokens.js` (JS-shaped tokens for JSX imports).

Detailed procedure: `reference/design-artifact-resolver.md`. Summary:

1. **Resolve DESIGN.md** via `wireframes/reference/design-md-resolver.md` (target app → file walk → `x-extends` cascade → staleness check). **If no DESIGN.md is found, abort with:** "DESIGN.md not found. Run `/wireframes` first to bootstrap the design-system file, then re-run `/prototype`." Do NOT auto-bootstrap; that's `/wireframes`' responsibility.
2. **Resolve `design-overlay.css`:**
   - If `{feature_folder}/wireframes/assets/design-overlay.css` exists AND is at least as fresh as DESIGN.md → copy to `{feature_folder}/prototype/assets/design-overlay.css`.
   - Otherwise → regenerate from DESIGN.md via `wireframes/reference/design-md-to-css.md` directly into the prototype folder.
3. **Generate `design-tokens.js`** via `reference/design-md-to-tokens-js.md` → `{feature_folder}/prototype/assets/design-tokens.js`. Always regenerated; cheap; never reused.
4. **Load COMPONENTS.md** from the same dir as DESIGN.md (warn if absent — `/verify` populates it on the next implementation pass).
5. **Pick layout anchor** from `x-information-architecture.layouts`:
   - Inherit from `{feature_folder}/wireframes/.layout-anchor` marker file if present and still valid (announce: "Inheriting layout anchor `<name>` from /wireframes").
   - Else AskUserQuestion (single-select). Persist choice to `{feature_folder}/prototype/.layout-anchor`.
6. **Assemble decision context** by concatenating workstream `## Constraints & Scars` + DESIGN.md `## Anti-patterns` + `## Do's and Don'ts`.

Output: in-memory `merged_design_md`, `components_inventory`, `layout_anchor`, `decision_context` — passed to Phases 4–6. On disk: `design-overlay.css` and `design-tokens.js` in `{feature_folder}/prototype/assets/`.

**Subagents:** if available, dispatch one read-only subagent for DESIGN.md resolution + token generation. Otherwise inline.

**Gate:** none for fresh DESIGN.md; user must respond to the staleness AskUserQuestion if the file is stale.

---

## Phase 2: Tier Gate & Scope Confirmation

### 2a. Tier detection

Read tier from req doc. If absent, ask via `AskUserQuestion`:

- **Question:** "What tier is this feature?"
- **Options:** Tier 1 (bug fix / minor enhancement) / Tier 2 (enhancement / UX overhaul, **Recommended**) / Tier 3 (new feature / major redesign)

**Tier gating:**

- **Tier 1:** Stop. Tell the user: "Tier 1 features rarely need a prototype. Recommend running `/spec` directly. Re-run with `--force` to override." Exit cleanly.
- **Tier 2:** Ask via `AskUserQuestion`:
  - **Question:** "Tier 2 detected. Run /prototype now? Adds ~1 hr; produces interactive prototype for stakeholder review."
  - **Options:** **Run now (Recommended)** / **Skip — proceed to /spec**
  - Platform fallback: state assumption "Skipping /prototype for Tier 2 unless you ask for it" and exit.
- **Tier 3:** Announce: "Tier 3 detected — /prototype is mandatory. Proceeding."

### 2b. Scope confirmation

Print the screen × device matrix:

```
| # | Screen | Slug | Devices | Source wireframe |
|---|--------|------|---------|------------------|
```

Confirm via `AskUserQuestion` (batch ≤4):

1. Device list (multiSelect; default = wireframes' devices)
2. Interactivity baseline (multiSelect; default = all four — navigation, forms, CRUD, loading/error/empty)

Platform fallback: print defaults, announce assumptions, proceed.

**Gate:** User confirms scope before Phase 3.

---

## Phase 3: Generate Mock Data

Use `reference/mock-data-prompt.md` as the prompt template.

1. **Extract visible-field summary** from wireframes. Grep across `wireframes/*.html` for `<th>`, `<label>`, `<dt>` text and any `data-field` attributes. Build `{screen, fieldsShown: [...], approxRowCount: N}`.
2. **Dispatch ONE subagent** (or run inline if subagents unavailable) with:
   - The mock-data prompt template (verbatim)
   - Full requirements doc text
   - Visible-field summary
   - Workstream domain hint if Phase 0 loaded one
   - Output folder: `{feature_folder}/prototype/assets/`
3. **Validate output** before user review:
   - Each `<entity>.json` is valid non-empty JSON
   - No Lorem ipsum (`grep -i 'lorem\|ipsum'`)
   - No `"User N"` / `"Item N"` patterns (`grep -E '"(User|Item|Test) [0-9]+"'`)
   - Spot-check 1–2 foreign-key relationships resolve
4. **User review gate** via `AskUserQuestion`:
   - **Question:** "Approve mock data? {entities + counts + 3 sample records each}"
   - **Options:** **Use as generated (Recommended)** / **Edit before continuing** / **Regenerate**
   - "Edit": print absolute paths to JSON files, wait for user, then re-confirm.
   - "Regenerate": prompt user for adjustments, re-run subagent **once**. No second regen.
5. Platform fallback: print summary, announce "using as generated", proceed.

---

## Phase 4: Generate Shared Runtime + Components + Styles

### 4a. Copy base stylesheet

Copy `assets/prototype.css` from this skill into the output folder so device files can link `./assets/prototype.css`:

```bash
mkdir -p "{feature_folder}/prototype/assets"
cp "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude-personal/plugins/cache/pmos-toolkit/pmos-toolkit/*/}skills/prototype/assets/prototype.css" \
   "{feature_folder}/prototype/assets/prototype.css"
```

If the copy fails, `Read` the skill's `assets/prototype.css` and `Write` it to the destination.

### 4b. Generate runtime.js (subagent)

Dispatch a subagent (or run inline) with `reference/runtime-template.md` as the spec. Output: `{feature_folder}/prototype/assets/runtime.js`. Must implement: hash router, mock-API client (200–800ms latency), in-memory store with pub/sub, mock-data loader (fetch + inline-script fallback), error injection via query param, `useRoute` and `useStore` hooks.

### 4c. Generate components.js (subagent)

Dispatch a subagent (or run inline) with `reference/components-template.md` as the spec. Output: `{feature_folder}/prototype/assets/components.js`. Must export the atoms listed in the template (Button, Input, Modal, Toast, Card, Table, EmptyState, Spinner, Badge, Avatar) on `window.__protoComponents`.

In addition to the existing inputs, the subagent receives **four blocks from Phase 1.5**:

1. **The merged DESIGN.md verbatim** with the instruction: "Tokens are read at runtime via `window.__designTokens`; structural decisions (component variants, voice) read here."
2. **COMPONENTS.md content** (from `components_inventory`) with the instruction: "When emitting an atom, use variant names from COMPONENTS.md. If a needed variant doesn't exist in the inventory, emit the atom anyway but flag in the file footer comment under `/* New variants: <list> */` so reviewer can confirm."
3. **`x-interaction` block (mandatory contract)** with the instruction:
   > "Implement `x-interaction` literally. Specifically:
   > - `modals.style` (centered / drawer-right / drawer-bottom / fullscreen) controls Modal positioning. Hard-code the matching class string.
   > - `modals.dismiss` (backdrop-click / explicit-button / esc-key) controls which dismiss handlers Modal wires up. Wire ONLY the listed dismiss paths — no extras.
   > - `destructiveActions.confirmation`: `always` → simple confirm modal; `double-click` → first click arms a 3-second visual countdown ring on the button; `type-to-confirm` → confirm modal with a text input that must match the resource name to enable the confirm button.
   > - `focus.trapInModals: true` → Modal traps Tab/Shift-Tab within itself when open.
   > - `focus.visibleStyle` → applied as the `:focus-visible` class on Button, Input, Select, etc.
   > - `defaultStates.empty` (illustrated / minimal / none) → EmptyState atom default variant.
   > - `defaultStates.loading` (skeleton / spinner / progress) → default Loading variant in components like Table.
   > - `defaultStates.error` (inline-banner / full-page / toast) → default error rendering in components.
   > - `shortcuts` → wire as global keydown handlers in runtime.js (cross-reference Phase 4b); advertise in a `?` keyboard-shortcut modal.
   > Pull values from `window.__designTokens.interaction.*` at runtime; do not duplicate the values inline."
4. **`x-content.buttonVerbs` and `x-content.formats`** with the instruction: "Use these exact verbs in default Button labels — 'Save', 'Create', 'Delete'. Don't invent 'Submit' or 'Add'. Date and currency formats come from `window.__designTokens.content.formats`."
5. **`decision_context`** with the instruction: "Honor every anti-pattern listed. If a component must violate one, flag in the file footer with rationale."

### 4d. Apply design overlay + emit thin styles.css

**Tokens are already produced in Phase 1.5.** `design-overlay.css` (CSS variables from DESIGN.md) and `design-tokens.js` (JS-shaped tokens) live at `{feature_folder}/prototype/assets/`. This phase:

1. **Confirm both files exist.** If either is missing, return to Phase 1.5 and regenerate.
2. **Emit a thin `styles.css`** (≤ 30 lines typical) containing ONLY prototype-only utility classes that aren't in `prototype.css` and don't belong in DESIGN.md:
   - Mock-data shimmer animations
   - Scroll-snap overrides for prototype-only carousels
   - File-protocol fallbacks
   - Anything device-specific that the overlay doesn't address
   Most prototypes will not need any custom styles here — emit a one-line comment file in that case.
3. Do NOT duplicate tokens from `design-overlay.css` here. The overlay is canonical for tokens.

`reference/styles-derivation.md` is **superseded** as of v2.8.0 — the legacy `house-style.json` codepath is gone. See the banner at the top of that file.

**Subagent dispatch:** 4b, 4c are independent — fire 2 parallel subagents in one message when available. 4d runs inline (it's small) after 1.5 confirms the overlay and tokens are present.

**Validation after 4d:**
- `design-overlay.css` exists and is non-empty (or contains only a header comment if DESIGN.md had no tokens)
- `design-tokens.js` exists and parses (`grep -q "window.__designTokens" design-tokens.js`)
- `styles.css` (if non-empty): balanced braces, no `url(http*)` external URLs, no `@import` statements

---

## Phase 5: Generate Per-Device HTML Files

For each device in the confirmed list, generate `{feature_folder}/prototype/index.<device>.html`.

### 5a. Extract visible-field summary per screen

For each wireframe screen, extract `<th>`, `<label>`, `<dt>`, button text, and CTA text. Save as `{feature_folder}/prototype/.screens-summary.json` for the generator subagents to consume.

### 5b. Dispatch device generators (parallel where possible)

One subagent per device. Each receives:
- `reference/device-html-template.md` (structure + skeleton)
- `.screens-summary.json` (what each screen must contain)
- Full text of `wireframes/<NN>_*.html` files for that device (visual reference)
- Req doc journey list (screens to wire up + transitions)
- Mock-data filenames AND the JSON contents (for inline-script fallbacks — subagent inlines the JSON verbatim)

Strict rules (from `reference/device-html-template.md`):
- **CSS load order** (cascade-critical): `prototype.css` → `design-overlay.css` → `styles.css`. The overlay must come AFTER `prototype.css` so its `:root` overrides take effect, and BEFORE `styles.css` so prototype-only utility classes can use the overlaid variables.
- **JS load order** (dependency-critical): `design-tokens.js` → `runtime.js` → `components.js`. Tokens must load first so `window.__designTokens` is defined when runtime and components evaluate.
- One screen component per wireframe screen, named `<PascalCaseSlug>Screen`, registered on `window.__screens`
- Inline `<script type="application/json" id="mock-<entity>">` for every entity
- Implement navigation across all screens via `useRoute` / `navigate`
- Wire forms, CRUD, loading/error/empty via `mockApi` and `store`
- No external network calls — everything routes through `mockApi`
- Use atoms from `window.__protoComponents` — no raw `<button>` / `<input>` in screens

### 5c. Per-device verification

After each device file is written:

```bash
# 1. Required script + style tags present (in correct order)
grep -c 'react@18\|babel/standalone\|design-tokens.js\|runtime.js\|components.js\|design-overlay.css' "{feature_folder}/prototype/index.<device>.html"
# Expected: ≥6

# 2. All entities have inline-data fallback
# (compare meta mock-entities content to <script id=mock-*> count)

# 3. Forbidden patterns
grep -E 'Lorem ipsum|User [0-9]+|Item [0-9]+|TODO|FIXME|console\.error|console\.log' \
  "{feature_folder}/prototype/index.<device>.html" \
  && echo "FORBIDDEN PATTERN" || echo "OK"

# 4. Screen count matches wireframe inventory
# (count `Screen` function definitions vs wireframe screen count)
```

If any check fails, send a follow-up to the device's generator subagent with the specific failure.

---

## Phase 6: Refinement Loop (Reviewer Subagent + ≤2 Loops Per File)

For each per-device HTML file, run up to 2 refinement loops. Stop early when zero high/medium findings remain.

### Loop Structure

**Step 1 — Dispatch reviewer subagent (parallel where possible):**
- One reviewer per device file
- Prompt: load `reference/eval-rubric.md` AND the following from Phase 1.5:
  - DESIGN.md `## Anti-patterns` and `## Do's and Don'ts` (verbatim) — score the file against each.
  - The `x-interaction` block — score against the **mandatory contract checklist** below.
  - COMPONENTS.md content — flag use of variants not in the inventory.
- Score the file against all six rubric groups (I, J, M, A, V, R) PLUS the contract checks. Return JSON findings array; tag each finding with `source: "rubric:<id>" | "design-md:antipattern:<n>" | "x-interaction:<key>" | "components-md:<name>"`.

**`x-interaction` contract checklist** (severity ≥ medium when violated):
- Modal positioning class matches `interaction.modals.style`?
- Modal dismiss handlers match `interaction.modals.dismiss` exactly (no extra paths)?
- Destructive Button confirmation matches `interaction.destructiveActions.confirmation` literally (simple-confirm / double-click countdown / type-to-confirm)?
- Modal traps focus when `interaction.focus.trapInModals: true`?
- `interaction.focus.visibleStyle` applied to Button, Input, Select, etc.?
- Declared `interaction.shortcuts` wired up in runtime AND advertised in a `?` modal?
- Default empty/loading/error states match `interaction.defaultStates`?
- Button labels honor `content.buttonVerbs` (Save/Create/Delete, not Submit/Add)?

**Step 2 — Apply fixes:**
- High/medium → apply via `Edit` (or have a generator subagent re-emit the affected section)
- Low → log in HTML comment block at top of file as `<!-- Known minor issues: ... -->`
- Track changes in a `<!-- Review Log -->` HTML comment block at top

**Step 3 — Loop continuation:**
- Remaining high/medium → run loop 2
- Otherwise exit
- Hard cap: 2 loops per file

**Platform fallback:** run reviewer pass inline.

---

## Phase 7: Interactive Friction Pass

Use `reference/friction-thresholds.md`. Pull journey list from req doc (cap 5). If req doc has >5 journeys, ask via `AskUserQuestion` (multiSelect) — recommend the most stakeholder-visible ones (signup, first-value, primary daily flow, share/invite, recovery).

For each journey:
1. Trace screens through the prototype (subagent reads device HTML, walks the route table from `runtime.js`)
2. Count clicks, keystrokes, decisions, screen transitions, modal interruptions per step
3. Apply thresholds; flag exceedances with severity
4. **Copy check:** confirm button labels and confirmation copy honor `merged_design_md.x-content.voice` and `x-content.buttonVerbs`. Mismatched verbs ("Submit" where DESIGN.md says "Save") are findings at severity medium.

**Subagents:** one per journey, parallel where available.

**Output:** `{feature_folder}/prototype/interactive-friction.md` per the format in `reference/friction-thresholds.md`.

**Anti-pattern:** do NOT re-run PSYCH or MSF — those are `/wireframes` responsibilities. The friction pass measures *operational cost*, not motivation/satisfaction.

---

## Phase 8: Findings Presentation Protocol

Aggregate Phase 6 unresolved + Phase 7 flags. Group by target (prototype / wireframe / req doc).

`AskUserQuestion`, ≤4 per batch:
- **question:** one-sentence finding + which file(s) + proposed fix
- **options:** **Apply to prototype** / **Update wireframe** / **Update req doc** / **Defer to spec**

Apply dispositions:
- **Prototype edits** via `Edit`. Inline spot-check post-edit against `reference/eval-rubric.md` (no Phase 6 re-loop).
- **Wireframe edits** via `Edit` to the wireframe file directly.
- **Req-doc edits** append a `## Prototype Findings` subsection with the change.

Log every applied change in `{feature_folder}/prototype/prototype-findings.md`.

**Cap total findings surfaced at 12.** Highest severity first (high → medium → low). The rest go to `prototype-findings.md` under "Unsurfaced findings".

**Platform fallback:** numbered findings table with disposition column; do NOT silently self-fix.

**Anti-pattern:** A wall of prose ending in "Let me know what you'd like to fix." Always structure the ask.

---

## Phase 9: Generate Landing Index + Serve

### 9a. Generate `index.html`

Create `{feature_folder}/prototype/index.html`:
- Header: feature name, generation date, link back to req doc + wireframes folder
- Device tabs/cards: one per device file with device name, screen count, mock-data summary, "Open prototype" button (links to `index.<device>.html`)
- Friction-pass summary: counts of high/medium/low flags per journey
- Findings summary: counts by disposition from Phase 8
- Footer: file count, prototype folder path
- Loads `assets/prototype.css` only (no React — pure static landing page; must work offline as `file://`)

### 9b. Serve

Detect Node:

```bash
command -v node && command -v npx
```

- **Node available:** start a static server in the background:
  ```bash
  cd {feature_folder}/prototype && npx --yes http-server -p 0 -c-1 --silent
  ```
  Capture printed port and report `http://localhost:<port>/index.html`.
- **Node missing:** print absolute `file://` path. Note: the inline-data fallback in Phase 5 makes `file://` work even when fetch is blocked.

Always print BOTH a served URL (if any) AND the file path so the user has a fallback.

---

## Phase 10: Spec Handoff

Append to requirements doc:

```markdown
## Prototype

Generated: {YYYY-MM-DD}
Folder: `{relative_path_to_prototype}`
Index: `{relative_path}/index.html`
Devices: {device-list}
Mock data: {N} entities, ~{record_count} records total
Findings: `{relative_path}/prototype-findings.md`
Friction pass: `{relative_path}/interactive-friction.md`

| # | Screen | Devices | File |
|---|--------|---------|------|
| 01 | … | … | linked from `index.<device>.html` |
```

Commit:

```bash
git add {feature_folder}/prototype/ {requirements_doc_path}
git commit -m "docs: add prototype for <feature>"
```

Tell the user: "Prototype is ready. Open `{served_url_or_file_path}` to review. When you're ready, run `/pmos-toolkit:spec` — it picks up the prototype findings from the requirements doc automatically."

---

## Phase 11: Workstream Enrichment

**Skip if no workstream was loaded in Phase 0.**

The four-field navigation contract under `## Wireframes & Design System` (`target_app`, `design_md_path`, `components_md_path`, `last_extraction_sha`) is **managed by `/wireframes` and `/verify` only**. `/prototype` reads these fields in Phase 1.5 but never writes them.

The only field `/prototype` may write to the workstream is `target_app.path` if it's missing entirely — that's a one-time bootstrap, never a re-write.

**Do NOT write** brand colors, typography, modal style, latency tuning, or recurring interaction patterns into `## Tech Stack` / `## Design System / UI Patterns`. Those facts are canonical in DESIGN.md (`x-interaction`, `x-content`, etc.). Duplicating creates drift.

**`## Constraints & Scars`** is read-only from this skill. If a prototype run surfaces a genuinely new and reusable constraint (e.g. "this device family always needs portrait-only support" — cross-feature, not one-off), surface it as a Phase 8 finding with disposition "Update workstream scars" and let the user explicitly approve. Never auto-write.

**`## Domain Notes`** can still receive mock-data realism heuristics that proved reusable (e.g. "ZIP codes for this domain need leading-zero handling"). This is not design-system content; it's domain knowledge. Keep this enrichment.

This phase is mandatory whenever Phase 0 loaded a workstream — do not skip it just because the core deliverable is complete.

---

## Phase 12: Capture Learnings

**This skill is not complete until the learnings-capture process has run.** Read and follow `learnings/learnings-capture.md` (relative to the skills directory) now. Reflect on whether this session surfaced anything worth capturing — surprising mock-data realism issues, latency calibration that worked, friction thresholds that need adjustment, a runtime pattern that broke in a specific browser, a `file://` portability gotcha, an atom that turned out to be reusable across features. Proposing zero learnings is a valid outcome for a smooth session; the gate is that the reflection happens.

---

## Anti-Patterns (DO NOT)

- Do NOT generate prototype without confirmed wireframes — auto-trigger `/wireframes` if missing
- Do NOT regenerate mock data per device file — generate once in Phase 3, share across all
- Do NOT silently fix high-severity findings — always surface via Findings Presentation Protocol
- Do NOT exceed 2 refinement loops per device file — diminishing returns
- Do NOT prototype non-user-facing features (backend-only, cron jobs, internal APIs) — recommend skipping
- Do NOT introduce build steps, npm packages, bundlers, or any backend
- Do NOT inline `runtime.js` or `components.js` into device files — share via `assets/`
- Do NOT use Lorem ipsum or generic mock data ("User 1", "Item A") — must be domain-real
- Do NOT cherry-pick screens — full coverage is the contract; if user wants partial, run `/wireframes` with narrower scope first
- Do NOT re-run PSYCH or MSF — those are `/wireframes` responsibilities; this skill runs the lighter friction pass
- Do NOT skip Phase 12 (capture learnings) — terminal gate
- Do NOT generate prototypes that fail on `file://` — always emit inline-data fallback alongside JSON files
- Do NOT exceed 5 journeys in the friction pass — diminishing returns and reviewer fatigue
- Do NOT auto-edit upstream wireframes or req doc without explicit user disposition in Phase 8
- Do NOT skip Phase 2 tier gate — Tier 1 features must be turned away politely with a `/spec` recommendation
- Do NOT add a separate AskUserQuestion gate around per-finding fixes if Phase 8 already handled them
- Do NOT use `@import url(...)` for fonts or any external resources — breaks `file://` portability
- Do NOT use `console.log` / `console.error` / `console.warn` in generated screen code — debug logs are findings, not features
- Do NOT bootstrap DESIGN.md from `/prototype` — Phase 1.5 aborts cleanly when missing and tells the user to run `/wireframes` first. Bootstrap responsibility lives in `/wireframes` exclusively
- Do NOT regenerate `design-overlay.css` if a fresh one exists in the wireframes folder — copy it instead. Within a feature, wireframes and prototype must use the same overlay (avoids visual drift between the two artifacts)
- Do NOT treat `x-interaction` as advisory — Phase 4c subagent and Phase 6 reviewer enforce it as a contract. Modal style, dismiss paths, destructive confirmation, focus trap, shortcuts must match literally
- Do NOT write design-system content (colors, typography, modal style, interaction patterns) into the workstream — those live in DESIGN.md / COMPONENTS.md (canonical). Phase 11 only writes `target_app.path` if missing
- Do NOT keep the legacy `house-style.json` codepath alive — Phase 4d is rewritten to consume `design-overlay.css` + `design-tokens.js`. The legacy `reference/styles-derivation.md` is superseded
- Do NOT load `design-tokens.js` after `runtime.js` or `components.js` — tokens must be on `window.__designTokens` before runtime/components evaluate, or atoms get `undefined` lookups
