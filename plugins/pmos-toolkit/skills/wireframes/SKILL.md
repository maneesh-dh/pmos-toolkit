---
name: wireframes
description: Generate static HTML wireframes (single-file, mid-fi, Tailwind) for a user-facing feature — covers all screens, components, states, and target devices. Optional bridge between /requirements and /spec in the requirements -> spec -> plan pipeline (run before /spec when the feature is user-facing). Auto-triggers /requirements if no req doc exists. Optionally extracts a "house style" from the host repo's frontend (Tailwind tokens, component library, layout patterns) so wireframes match the existing app, and accepts screenshots (`--screenshots`) of existing flows as IA anchors for "extend this flow" requests. Self-evaluates each wireframe against UX heuristics with a reviewer subagent and runs up to 2 self-refinement loops. Use when the user says "create wireframes", "mock up the UI", "wireframe this feature", "design the screens", "show me the UI states", "extend this existing flow", or has a requirements doc ready and wants visuals before the spec.
user-invocable: true
argument-hint: "<path-to-requirements-doc or feature description> [--devices=desktop-web,mobile-web,...] [--feature <slug>] [--screenshots <path>]"
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

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:
- **No `AskUserQuestion`:** State your assumption (default device = desktop-web; default scope = all components from the req doc), document it in the output's README, and proceed. The user reviews after completion.
- **No subagents:** Generate wireframes sequentially in the main agent; run the reviewer critique inline rather than dispatching a separate reviewer agent.
- **No background processes:** Skip the local server and print the absolute `file://` path to `index.html` instead.
- **No Playwright MCP:** Note browser-based verification as a manual step for the user.

## Track Progress

This skill has multiple phases. Create one task per phase using your agent's task-tracking tool (e.g., `TodoWrite` in Claude Code, equivalent in other agents). Mark each task in-progress when you start it and completed as soon as it finishes — do not batch completions.

---

## Phase 0: Load Workstream Context & Learnings

Before any other work, follow the context loading instructions in `product-context/context-loading.md` (relative to the skills directory). This determines `{docs_path}` and loads workstream context if available — design tokens, brand voice, and prior wireframe conventions live here. Also read `~/.pmos/learnings.md` if it exists. Note any entries under `## /wireframes` and factor them into your approach for this session.

**Resolve feature folder.** Follow `../_shared/feature-folder.md` with `skill_name=wireframes`, `feature_arg=<--feature value or empty>`, and `feature_hint=<topic from user input>`. Use the returned folder path as `{feature_folder}`. Wireframes are commonly produced before /spec, so this skill may create the folder.

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

## Phase 2.5: Host Style Extraction (optional)

> Decimal phase number is intentional — Phase 3 onward keeps existing numbering so external references (other skills, prior conversations) still resolve. Skip this phase entirely if it doesn't apply; the rest of the skill is unaffected.

This phase tries to make wireframes look like they belong in the user's existing product. **Skip silently** when there's no host frontend (backend-only repo, ad-hoc directory). When applicable, it produces an override CSS file that re-skins the wireframe vocabulary using tokens extracted from the repo.

Follow `reference/style-extraction.md` for the full procedure. Summary:

1. **Detect** whether to run. Triggers when `cwd` is in a git repo AND a frontend signal is present (React/Vue/Svelte/Next/Nuxt deps, `tailwind.config.*`, `:root { --* }` CSS, or a substantial `<style>` block in `index.html`). If none match, write `{feature_folder}/wireframes/assets/house-style.json` with `{"source": null}` and skip the rest of this phase.
2. **Choose a candidate frontend.** Single candidate → use it. Multiple candidates → ask via `AskUserQuestion` (single-select, candidates + "None — use default style"). Platform fallback: pick the candidate with the most component files; announce.
3. **Extract** tokens (colors, radius, fontFamily) and component-library hints from `tailwind.config.*`, top-level CSS files, `package.json`, and 2–3 representative component/page files. Read budget cap: ~20 files / ~30 KB.
4. **Write artifacts:**
   - `{feature_folder}/wireframes/assets/house-style.json` — structured summary (always, even if empty).
   - `{feature_folder}/wireframes/assets/house-style.css` — variable overrides for `wireframe.css` (only when extraction yielded usable tokens).
5. **Confirm with the user** via `AskUserQuestion`:
   - **Question:** "Apply this extracted house style to wireframes?"
   - **Options:** **Use as extracted** / **Edit before applying** / **Discard, use default style**
   - "Discard" → delete `house-style.css`; keep the JSON with `"applied": false` for audit.
6. **Screenshot fallback:** if no host frontend was detected but Phase 1 step 3.5 ingested screenshots, attempt token inference from the screenshot descriptions (best effort; leave empty if not confident).

**Subagents:** if available, dispatch one subagent for the extractor with read-only access to the repo. Otherwise run inline.

**Gate:** the user must confirm or discard the extracted style before Phase 3 begins. This is a fast confirmation, not a deep review.

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
- Workstream tech-stack hints if loaded (brand color, type stack)
- **If `assets/house-style.json` exists with `source != null` AND the user chose "Use as extracted":** include the JSON verbatim. Instruct the subagent to (a) link `./assets/house-style.css` after `./assets/wireframe.css` in every generated file, and (b) match component shapes to the `patterns` hints (e.g., button radius, card style, nav layout). The override CSS handles colors and tokens — the subagent only needs to honor the shape patterns.
- **If this component has at least one anchored screenshot** (per `source-screens.md`): include only that screenshot's description block (not the whole file) plus the absolute path to the original image. Include the IA-preservation instruction from `reference/screenshot-ingestion.md` ("match layout/IA, may improve states/a11y/copy, must NOT silently reorganize IA"). Components without anchored screenshots receive no screenshot context.
- Strict instruction: produce ONLY the HTML file(s), no commentary

**If subagents are unavailable**: generate sequentially in the main agent.

### File Requirements (every wireframe MUST satisfy)

- One `.html` file per `(component × device)` pair
- Links the shared `./assets/wireframe.css` (copied in step 3a) — do NOT inline the rules from that stylesheet
- If `./assets/house-style.css` exists and was applied in Phase 2.5, link it **immediately after** `wireframe.css` so its `:root` overrides take effect
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

For each generated wireframe file, run up to 2 refinement loops. Stop early when the reviewer reports zero issues at severity ≥ medium.

### Loop Structure

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

---

## Phase 5: Index & Serve

### 5a. Generate `index.html`

Create `{feature_folder}/wireframes/index.html` with:

- Header: feature name, generation date, link back to req doc
- **Device tabs** at the top — one tab per device targeted; clicking filters the card grid
- **Card grid** — one card per `(component × device)` pair showing:
  - Component name + device chip
  - State count badge ("4 states")
  - 200×140 px iframe preview of the wireframe (scaled), or a static thumbnail block if iframes prove flaky
  - Click → opens the wireframe in a new tab
- Search box that filters cards by component name
- Footer: total file count, file path of the folder

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

If the req doc has > 5 journeys, use `AskUserQuestion` (multiSelect) to let the user pick the top 5; recommend the most stakeholder-visible ones (signup, first-value, primary daily flow, share/invite, recovery).

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

**Skip if no workstream was loaded in Phase 0.** Otherwise, follow the enrichment instructions in `product-context/context-loading.md` Step 4. For this skill, the signals to look for are:

- Recurring component patterns (top nav, modals) → workstream `## Design System / UI Patterns`
- Brand/typography decisions made during generation → workstream `## Tech Stack`
- Device support decisions → workstream `## Constraints & Scars`

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
