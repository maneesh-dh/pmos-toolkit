# /prototype Skill Implementation Plan

> **For agentic workers:** Implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking. Each task is self-contained — file paths and content are explicit.

**Goal:** Build the `/prototype` skill in pmos-toolkit per design spec at `docs/superpowers/specs/2026-04-30-prototype-skill-design.md`.

**Architecture:** Skill = SKILL.md (process orchestration) + `reference/*.md` (rubrics, templates, prompts) + `assets/*.css` (base styles). The skill itself produces no runtime code at author time — its outputs are runtime artifacts (HTML/JS/JSON) emitted at invocation time, scaffolded from the reference templates.

**Tech Stack:** Markdown (SKILL.md, references), CSS (high-fi base palette). No build step. Plugin delivery via `pmos-toolkit` (already configured to auto-discover skills via `"skills": "./skills/"` in `plugin.json`).

**Reference implementation:** `plugins/pmos-toolkit/skills/wireframes/` is the closest analog — same skill family, same conventions, same shape (SKILL.md + reference/ + assets/). Mirror its style.

**Verification model:** Skills are prompt-engineering artifacts, not executables. Per-task "tests" are file-existence checks, frontmatter validation, line-count caps, and cross-reference integrity (every `reference/foo.md` link must resolve). End-to-end smoke test is deferred — flagged in Task 16.

---

## File Structure

```
plugins/pmos-toolkit/skills/prototype/
  SKILL.md                              # main entrypoint, ≤500 lines target
  assets/
    prototype.css                       # high-fi base palette + tokens (runtime artifact, copied to outputs)
  reference/
    eval-rubric.md                      # Phase 6 reviewer rubric
    friction-thresholds.md              # Phase 7 thresholds
    runtime-template.md                 # runtime.js scaffold (router, mock-API, store)
    components-template.md              # components.js scaffold (atoms)
    device-html-template.md             # per-device HTML scaffold
    mock-data-prompt.md                 # LLM prompt for Phase 3 mock data generation
    styles-derivation.md                # rules to derive high-fi styles.css from house-style.json
  learnings/
    learnings-capture.md                # symlink/copy of shared learnings-capture (or reference shared)
```

---

## Task 1: Scaffold directory + plugin version bump + SKILL.md frontmatter

**Files:**
- Create: `plugins/pmos-toolkit/skills/prototype/` (directory)
- Create: `plugins/pmos-toolkit/skills/prototype/SKILL.md` (frontmatter + announce only)
- Modify: `plugins/pmos-toolkit/.claude-plugin/plugin.json` (or wherever the manifest is — verify path)

- [ ] **Step 1: Verify plugin.json location**

```bash
find /Users/maneeshdhabria/Desktop/Projects/agent-skills/plugins/pmos-toolkit -maxdepth 3 -name "plugin.json"
```
Expected: prints path. Use it for step 4.

- [ ] **Step 2: Create directories**

```bash
mkdir -p /Users/maneeshdhabria/Desktop/Projects/agent-skills/plugins/pmos-toolkit/skills/prototype/{reference,assets}
```

- [ ] **Step 3: Write SKILL.md frontmatter + first line**

Content:
```markdown
---
name: prototype
description: Generate a high-fidelity, single-HTML-per-device interactive prototype (React via CDN + JSX, simulated API calls, domain-real LLM-generated mock data) that stitches all wireframe screens into walkable user journeys. Optional bridge between /wireframes and /spec in the requirements -> spec -> plan pipeline. Tier 1 skip; Tier 2 optional; Tier 3 mandatory. Inherits from wireframes (visual reference, IA, copy) and produces forms, CRUD, navigation, loading/error states without any backend or build step. Self-evaluates with a reviewer subagent (≤2 loops per device file) and runs an interactive friction pass measuring clicks/keystrokes/decisions per journey. Use when the user says "create a prototype", "make this clickable", "high-fi mockup", "stakeholder demo", "interactive prototype", "prototype this feature", or has wireframes ready and wants stakeholders to experience the flow before /spec.
user-invocable: true
argument-hint: "<path-to-requirements-doc or feature description> [--devices=desktop-web,mobile-web,...] [--feature <slug>]"
---

# Prototype Generator

Produce a single-HTML-per-device interactive prototype that stitches wireframe screens into walkable user journeys with simulated API calls, mock data, and full client-side interactivity. Output is high-fidelity (real brand colors, typography, no annotation chrome) but unmistakably NOT the real product (no backend, in-memory only, mock data).

```
/requirements  →  /wireframes  →  [/prototype]  →  /spec  →  [/simulate-spec]  →  /plan  →  /execute  →  /verify
                                  (this skill, optional)
```

**Announce at start:** "Using the prototype skill to generate an interactive prototype for this feature."
```

- [ ] **Step 4: Bump plugin version to 2.2.0**

Read current `plugin.json`, change `"version": "2.1.0"` → `"version": "2.2.0"`, append a keyword `"prototype"`.

- [ ] **Step 5: Verify**

```bash
test -f plugins/pmos-toolkit/skills/prototype/SKILL.md && echo OK
head -3 plugins/pmos-toolkit/skills/prototype/SKILL.md
grep '"version"' plugins/pmos-toolkit/.claude-plugin/plugin.json
```
Expected: OK; `name: prototype`; `"version": "2.2.0"`.

- [ ] **Step 6: Commit**

```bash
git add plugins/pmos-toolkit/skills/prototype/SKILL.md plugins/pmos-toolkit/.claude-plugin/plugin.json
git commit -m "feat(prototype): scaffold skill directory + frontmatter (pmos-toolkit v2.2.0)"
```

---

## Task 2: reference/eval-rubric.md

**Files:**
- Create: `plugins/pmos-toolkit/skills/prototype/reference/eval-rubric.md`

- [ ] **Step 1: Write rubric**

The rubric must score interactivity completeness, journey coverage, mock-data realism, accessibility, visual consistency, runtime errors. Same JSON output shape as `wireframes/reference/eval-rubric.md`. Heuristics groups:

- **I — Interactivity** (I1: navigation works end-to-end; I2: forms validate + submit; I3: CRUD persists in-session; I4: loading/error/empty states triggered by latency layer; I5: no console errors on first paint or any nav step)
- **J — Journey coverage** (J1: every wireframe screen reachable; J2: every required journey from req doc completable; J3: dead-ends explicitly handled with a back/cancel affordance)
- **M — Mock data** (M1: domain-real, not generic; M2: enough volume for the screen pattern — list views ≥20 records; M3: relationships consistent across entities; M4: no Lorem ipsum)
- **A — Accessibility** (A1: semantic HTML; A2: focus-visible; A3: aria-label on icon-only buttons; A4: contrast ≥4.5:1; A5: keyboard nav works for primary CTAs)
- **V — Visual consistency** (V1: high-fi palette applied; V2: typography stack matches house-style; V3: components.js atoms used consistently; V4: no wireframe-style annotations)
- **R — Runtime** (R1: file:// portability — no fetch failures via inline-data fallback; R2: no Babel compile errors; R3: simulated latency within 200–800ms)

Severity: high blocks task; medium friction; low cosmetic. Output is JSON array per file.

- [ ] **Step 2: Verify line count + structure**

```bash
wc -l plugins/pmos-toolkit/skills/prototype/reference/eval-rubric.md
grep -E '^### [A-Z] —' plugins/pmos-toolkit/skills/prototype/reference/eval-rubric.md
```
Expected: ≤150 lines; six section headers (I, J, M, A, V, R).

- [ ] **Step 3: Commit**

```bash
git add plugins/pmos-toolkit/skills/prototype/reference/eval-rubric.md
git commit -m "feat(prototype): add reviewer eval rubric"
```

---

## Task 3: reference/friction-thresholds.md

**Files:**
- Create: `plugins/pmos-toolkit/skills/prototype/reference/friction-thresholds.md`

- [ ] **Step 1: Write thresholds**

Define the interactive friction pass (Phase 7). Per-journey measurements: clicks, keystrokes, decisions (each branch the user must consciously pick), screen transitions, modal interruptions. Thresholds (flag at):
- First-value journey (signup → first meaningful action): >12 clicks OR >3 form steps OR >2 modal interruptions
- Daily-flow journey (returning user primary task): >6 clicks OR >1 form step
- Recovery journey (error → resolved): >8 clicks OR any unrecoverable dead-end
- Universal: any single screen with >5 decisions, any flow >60s estimated

Output JSON shape per journey: `{journey, steps:[{screen, clicks, keystrokes, decisions, latencyMs}], totals, flags:[{threshold, severity}]}`.

- [ ] **Step 2: Verify + commit**

```bash
wc -l plugins/pmos-toolkit/skills/prototype/reference/friction-thresholds.md
git add plugins/pmos-toolkit/skills/prototype/reference/friction-thresholds.md
git commit -m "feat(prototype): add interactive friction thresholds"
```

---

## Task 4: reference/runtime-template.md

**Files:**
- Create: `plugins/pmos-toolkit/skills/prototype/reference/runtime-template.md`

- [ ] **Step 1: Write the runtime template**

Documents what `assets/runtime.js` must contain when emitted by Phase 4. Sections:

1. **Hash router** — `window.location.hash` based; `useRoute()` hook; `navigate(path)`; route table built from screen registry
2. **Mock-API client** — `mockApi.get/post/put/delete(path, body)`; resolves promises after random 200–800ms; reads/writes the in-memory store; deterministic failure rules (e.g., `path === '/api/orders/fail-demo'` always 500)
3. **In-memory store** — single object keyed by entity (`store.users`, `store.products`, …); seeded from `mock-data` loader on init; mutations via `store.update(entity, id, patch)` etc.
4. **Mock-data loader with fallback** — try `fetch('./assets/<entity>.json')`; on failure, parse `<script type="application/json" id="mock-<entity>">` from DOM
5. **Latency simulator** — `simulateLatency(min=200, max=800)` returns a Promise; used by mockApi
6. **Error injection** — `?inject-errors=path1,path2` query param to deterministically fail listed routes (for stakeholder demo of error states)

Include a verbatim ~150-line skeleton so the generator subagent has something concrete to fill in.

- [ ] **Step 2: Verify + commit**

```bash
wc -l plugins/pmos-toolkit/skills/prototype/reference/runtime-template.md
git add plugins/pmos-toolkit/skills/prototype/reference/runtime-template.md
git commit -m "feat(prototype): add runtime.js template (router, mock-API, store)"
```

---

## Task 5: reference/components-template.md

**Files:**
- Create: `plugins/pmos-toolkit/skills/prototype/reference/components-template.md`

- [ ] **Step 1: Write the components template**

Lists the shared atoms `assets/components.js` must export. Each atom: name, props, behavior, JSX skeleton.

- `Button({variant, onClick, children, disabled, loading})` — primary/secondary/destructive/ghost
- `Input({label, value, onChange, error, type})` — with inline validation slot
- `Modal({open, onClose, title, children, footer})`
- `Toast({type, message, onDismiss})` — success/error/info
- `Card({header, footer, children})`
- `Table({columns, rows, onRowClick, emptyState})` — with built-in loading skeleton
- `EmptyState({icon, title, description, cta})`
- `Spinner({size})`
- `Badge({tone, children})` — success/warning/danger/neutral
- `Avatar({name, src, size})` — initials fallback

All components consume CSS classes from `prototype.css` (Task 9). Components render with Babel-compiled JSX inside `<script type="text/babel">`.

- [ ] **Step 2: Verify + commit**

```bash
wc -l plugins/pmos-toolkit/skills/prototype/reference/components-template.md
git add plugins/pmos-toolkit/skills/prototype/reference/components-template.md
git commit -m "feat(prototype): add shared components.js template (atoms)"
```

---

## Task 6: reference/device-html-template.md

**Files:**
- Create: `plugins/pmos-toolkit/skills/prototype/reference/device-html-template.md`

- [ ] **Step 1: Write the device HTML template**

Documents the structure of every `index.<device>.html` file:

```html
<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{Feature} — {Device} Prototype</title>
  <link rel="stylesheet" href="./assets/prototype.css">
  <link rel="stylesheet" href="./assets/styles.css">
  <script src="https://unpkg.com/react@18/umd/react.development.js"></script>
  <script src="https://unpkg.com/react-dom@18/umd/react-dom.development.js"></script>
  <script src="https://unpkg.com/@babel/standalone/babel.min.js"></script>
  <script src="./assets/runtime.js"></script>
  <script src="./assets/components.js"></script>
</head>
<body class="device-{device}">
  <div id="root"></div>
  <!-- inline-data fallback for file:// portability -->
  <script type="application/json" id="mock-users">[…]</script>
  <script type="application/json" id="mock-products">[…]</script>
  <script type="text/babel" data-presets="react">
    /* screen components: one per wireframe screen */
  </script>
  <script type="text/babel" data-presets="react">
    /* app shell: device frame + router outlet + global modals */
  </script>
</body>
</html>
```

Device frame requirements:
- desktop-web: 1280×800, no chrome
- mobile-web: 375×812, rounded corners, status bar, home indicator
- ios-app: tab bar pattern, large title, sheet presentation
- android-app: bottom nav, FAB, system bar
- desktop-app: window chrome with traffic-light buttons

Include a ~80-line skeleton.

- [ ] **Step 2: Verify + commit**

```bash
wc -l plugins/pmos-toolkit/skills/prototype/reference/device-html-template.md
git add plugins/pmos-toolkit/skills/prototype/reference/device-html-template.md
git commit -m "feat(prototype): add per-device HTML template"
```

---

## Task 7: reference/mock-data-prompt.md

**Files:**
- Create: `plugins/pmos-toolkit/skills/prototype/reference/mock-data-prompt.md`

- [ ] **Step 1: Write the LLM prompt template**

Template for the mock-data subagent. Inputs:
- Requirements doc (entity model, business rules)
- Wireframes (visible fields per screen — extract via grep on table headers, form labels)
- Domain hint from workstream context if available

Output contract:
- One JSON file per entity in `assets/<entity>.json`
- One `assets/mock-data.json` index summarizing entities + counts
- 20–200 records per entity (skill picks based on visible volume)
- Domain-real names: real-looking person names, plausible company names, realistic prices/dates/copy
- Cross-entity referential integrity (orders.userId references users.id)
- Some records exhibit edge cases (empty fields where the schema allows, max-length values, special characters)

Include the verbatim prompt the subagent receives.

- [ ] **Step 2: Verify + commit**

```bash
wc -l plugins/pmos-toolkit/skills/prototype/reference/mock-data-prompt.md
git add plugins/pmos-toolkit/skills/prototype/reference/mock-data-prompt.md
git commit -m "feat(prototype): add mock-data generation prompt template"
```

---

## Task 8: reference/styles-derivation.md

**Files:**
- Create: `plugins/pmos-toolkit/skills/prototype/reference/styles-derivation.md`

- [ ] **Step 1: Write the derivation rules**

How Phase 4 produces `assets/styles.css` from `wireframes/assets/house-style.json`:

1. Read `house-style.json` — primary color, neutrals, radius, fontFamily, component-library hint
2. If `source: null` (no host frontend detected during wireframes phase) → use a sensible default high-fi palette (defined in `prototype.css`; styles.css is empty/minimal)
3. Otherwise generate `:root { --primary: …; --primary-hover: …; --surface: …; --text: …; --radius-sm: …; --radius-md: …; --font-sans: …; }` and component-shape rules (button border-radius, card style, nav layout)
4. **No annotation chrome** (delete any `.annotation`, `.state-tab`, `.wireframe-frame` rules)
5. Add hover/active/focus states for buttons, inputs, links — wireframes don't have these but high-fi must

Include the CSS skeleton that the styles-extractor subagent fills in.

- [ ] **Step 2: Verify + commit**

```bash
wc -l plugins/pmos-toolkit/skills/prototype/reference/styles-derivation.md
git add plugins/pmos-toolkit/skills/prototype/reference/styles-derivation.md
git commit -m "feat(prototype): add high-fi styles derivation rules"
```

---

## Task 9: assets/prototype.css

**Files:**
- Create: `plugins/pmos-toolkit/skills/prototype/assets/prototype.css`

- [ ] **Step 1: Write the base CSS**

The default high-fi base. Copied to every output's `assets/` folder. Structure:

- `:root` tokens (default palette: indigo primary, slate neutrals, system font stack, 6/12/16/24px radii)
- Reset / box-sizing
- Typography scale (h1-h6 with sensible weight/size ramp)
- Layout primitives (`.stack`, `.row`, `.grid`)
- Component classes consumed by `components.js` atoms (`.btn`, `.btn--primary`, `.input`, `.modal`, `.toast`, `.card`, `.table`, `.spinner`, `.badge`, `.avatar`)
- Hover/focus/active states (focus-visible outlines)
- Device-frame chrome rules keyed off `body.device-mobile-web`, `body.device-ios-app`, etc.
- Loading skeleton shimmer animation
- Toast slide-in animation

Target ~250 lines. This is the only runtime-shipping file in the skill itself; everything else is generated.

- [ ] **Step 2: Verify**

```bash
wc -l plugins/pmos-toolkit/skills/prototype/assets/prototype.css
grep -c "^\." plugins/pmos-toolkit/skills/prototype/assets/prototype.css   # class count, expect ≥20
```

- [ ] **Step 3: Commit**

```bash
git add plugins/pmos-toolkit/skills/prototype/assets/prototype.css
git commit -m "feat(prototype): add high-fi base stylesheet"
```

---

## Task 10: SKILL.md — Platform Adaptation, Track Progress, Phase 0, Phase 1

**Files:**
- Modify: `plugins/pmos-toolkit/skills/prototype/SKILL.md` (append)

- [ ] **Step 1: Append sections**

Append in order:

```markdown
## Platform Adaptation

These instructions use Claude Code tool names. In other environments:
- **No `AskUserQuestion`:** State your assumption (default devices = wireframes' device list; default scope = all wireframe screens), document it in the output's index.html, and proceed.
- **No subagents:** Generate sequentially in the main agent; run review and friction passes inline.
- **No background processes:** Skip the local server and print the absolute `file://` path to `index.html`.
- **No Playwright MCP:** Note browser-based verification as a manual step for the user.

## Track Progress

This skill has 13 phases. Create one task per phase using your agent's task-tracking tool. Mark each task in-progress when you start it and completed as soon as it finishes — do not batch completions.

---

## Phase 0: Load Workstream Context & Learnings

Before any other work, follow the context loading instructions in `product-context/context-loading.md` (relative to the skills directory). This determines `{docs_path}` and loads workstream context. Brand voice, design tokens, and prior prototype conventions live here. Also read `~/.pmos/learnings.md` if it exists. Note any entries under `## /prototype` and factor them into your approach for this session.

**Resolve feature folder.** Follow `../_shared/feature-folder.md` with `skill_name=prototype`, `feature_arg=<--feature value or empty>`, and `feature_hint=<topic from user input>`. Use the returned folder path as `{feature_folder}`. Prototype is produced AFTER /wireframes, so the folder typically already exists.

---

## Phase 1: Locate Inputs

1. **Find the requirements doc.** Follow `../.shared/resolve-input.md` with `phase=requirements`, `label="requirements doc"`. Accept either a path or inline feature description.
2. **No requirements doc found?** Stop and trigger `/requirements` first via `/wireframes` chain:
   - Tell the user: "Prototype needs requirements + wireframes. Running `/wireframes` first (which will trigger `/requirements` if needed)."
   - Hand off to `/pmos-toolkit:wireframes` with the user's original ask.
   - Resume `/prototype` once both docs exist.
3. **Find the wireframes folder.** Default location: `{feature_folder}/wireframes/`. Check for `index.html` and at least one `NN_*.html` file.
4. **No wireframes found?** Trigger `/wireframes` (announce, hand off, resume).
5. **Read inputs end-to-end:**
   - Req doc: extract user journeys, business rules, entity model, tier tag
   - Wireframes: read `index.html` for the inventory matrix; read each `NN_*.html` for layout, copy, visible fields, state list
   - `wireframes/assets/house-style.json` if present (drives Phase 4 high-fi styles)
6. **Confirm understanding.** Summarize the journeys to be made interactive and the device list. Ask via `AskUserQuestion` (≤4 batched). Platform fallback: numbered list + free-text confirmation.

**Gate:** Do not proceed until the user confirms.
```

- [ ] **Step 2: Verify + commit**

```bash
wc -l plugins/pmos-toolkit/skills/prototype/SKILL.md
git add plugins/pmos-toolkit/skills/prototype/SKILL.md
git commit -m "feat(prototype): SKILL.md platform adaptation + Phases 0-1"
```

---

## Task 11: SKILL.md — Phase 2, Phase 3

**Files:**
- Modify: `plugins/pmos-toolkit/skills/prototype/SKILL.md` (append)

- [ ] **Step 1: Append Phase 2 (Tier Gate & Scope)**

```markdown
---

## Phase 2: Tier Gate & Scope Confirmation

### 2a. Tier detection

Read tier from req doc. If absent, ask via `AskUserQuestion`:
- **Question:** "What tier is this feature?"
- **Options:** Tier 1 (bug fix) / Tier 2 (enhancement, **Recommended**) / Tier 3 (new feature)

**Tier gating:**
- **Tier 1:** Stop. Tell the user: "Tier 1 features rarely need a prototype. Recommend running `/spec` directly. Re-run with `--force` to override." Exit.
- **Tier 2:** Ask via `AskUserQuestion`: "Tier 2 detected. Run /prototype now? Adds ~1 hr; produces interactive prototype for stakeholder review." Options: **Run now (Recommended)** / **Skip — proceed to /spec**.
- **Tier 3:** Announce: "Tier 3 detected — /prototype is mandatory. Proceeding."

### 2b. Scope confirmation

Print:
```
| # | Screen | Slug | Devices | Source wireframe |
|---|--------|------|---------|-----------------|
```

Confirm via `AskUserQuestion`:
1. Device list (multiSelect; default = wireframes' devices)
2. Interactivity baseline (multiSelect; default = all four — navigation, forms, CRUD, loading/error)

Platform fallback: print defaults, announce assumptions, proceed.

**Gate:** User confirms scope before Phase 3.

---

## Phase 3: Generate Mock Data

Use `reference/mock-data-prompt.md` as the prompt template. Dispatch ONE subagent (or run inline) to generate:

1. `{feature_folder}/prototype/assets/<entity>.json` — one file per entity identified in the req doc
2. `{feature_folder}/prototype/assets/mock-data.json` — index: `{entities: [{name, count, file}], generatedAt, seed}`

Inputs to subagent:
- Req doc text (full)
- Wireframes' visible-field summary (extracted: table column headers, form labels, detail-view labels — grep across `wireframes/*.html`)
- Workstream domain hint if Phase 0 loaded it

Output rules:
- 20–200 records per entity (subagent picks based on largest visible volume in wireframes)
- Domain-real names; no Lorem ipsum, no "User 1"
- Referential integrity (foreign keys reference real ids)
- Some edge-case records (long names, empty optional fields, max values)

**User review gate:** present a summary table (entities + counts + 3 sample records each) via `AskUserQuestion`:
- **Question:** "Approve mock data?"
- **Options:** Use as generated / Edit before continuing / Regenerate

If "Edit": print absolute paths to JSON files, wait for user to edit, then re-confirm.
If "Regenerate": prompt user for adjustments, re-run subagent once. No second regen.

Platform fallback: print summary, announce assumption "using as generated", proceed.
```

- [ ] **Step 2: Verify + commit**

```bash
wc -l plugins/pmos-toolkit/skills/prototype/SKILL.md
git add plugins/pmos-toolkit/skills/prototype/SKILL.md
git commit -m "feat(prototype): SKILL.md Phases 2-3 (tier gate, mock data)"
```

---

## Task 12: SKILL.md — Phase 4 (Runtime+Components+Styles), Phase 5 (Per-Device Generation)

**Files:**
- Modify: `plugins/pmos-toolkit/skills/prototype/SKILL.md` (append)

- [ ] **Step 1: Append**

```markdown
---

## Phase 4: Generate Shared Runtime + Components + Styles

### 4a. Copy base stylesheet

Copy `assets/prototype.css` from this skill into the output folder:

```bash
mkdir -p "{feature_folder}/prototype/assets"
cp "${CLAUDE_PLUGIN_ROOT:-$HOME/.claude-personal/plugins/cache/pmos-toolkit/pmos-toolkit/*/}skills/prototype/assets/prototype.css" \
   "{feature_folder}/prototype/assets/prototype.css"
```

If copy fails, `Read` the skill's `assets/prototype.css` and `Write` to destination.

### 4b. Generate runtime.js

Dispatch a subagent (or run inline) with `reference/runtime-template.md` as the spec. Output: `{feature_folder}/prototype/assets/runtime.js`. Must implement: hash router, mock-API client (200–800ms latency), in-memory store, mock-data loader (fetch + inline-script fallback), error injection via query param.

### 4c. Generate components.js

Dispatch a subagent (or run inline) with `reference/components-template.md` as the spec. Output: `{feature_folder}/prototype/assets/components.js`. Must export the atoms listed in the template, all consuming `prototype.css` classes.

### 4d. Generate styles.css (high-fi skin)

Read `{feature_folder}/wireframes/assets/house-style.json`. Apply `reference/styles-derivation.md` rules. Output: `{feature_folder}/prototype/assets/styles.css`. If house-style is empty, write a minimal styles.css that just imports nothing (prototype.css defaults take over).

**Subagent dispatch:** 4b, 4c, 4d are independent — fire 3 parallel subagents in one message when available.

---

## Phase 5: Generate Per-Device HTML Files

For each device in the confirmed list, generate `{feature_folder}/prototype/index.<device>.html`.

### 5a. Extract visible-field summary per screen

For each wireframe screen, extract:
- All table column headers (`<th>` text)
- All form labels (`<label>` text)
- All detail-view key labels
- All button text (CTAs)

Save as a structured JSON `{feature_folder}/prototype/.screens-summary.json` for the generator to consume.

### 5b. Dispatch device generators (parallel where possible)

One subagent per device. Each subagent receives:
- `reference/device-html-template.md` (structure)
- `.screens-summary.json` (what each screen must contain)
- Full text of `wireframes/<NN>_*.html` files for its device (visual reference)
- The req doc journey list (screens to wire up + transitions)
- Mock-data filenames (for inline-script fallbacks — subagent inlines the JSON)
- Strict rules:
  - Load `prototype.css`, `styles.css`, `runtime.js`, `components.js` in that order
  - One screen component per wireframe screen (named `{ScreenSlug}Screen`)
  - Inline `<script type="application/json" id="mock-<entity>">` for every entity (read JSON files, embed verbatim)
  - Implement navigation across all screens
  - Wire up forms, CRUD actions, loading/error/empty via the runtime layer
  - No external network calls — everything resolves to mock-API

### 5c. Per-device verification

After each device file is written:
1. Open it with a quick read; confirm it has React mount, all script tags present, every screen function defined
2. Count screens vs wireframe inventory — must match
3. Static-grep for forbidden patterns (`Lorem ipsum`, `User 1`, `console.error`, `TODO`)
```

- [ ] **Step 2: Verify + commit**

```bash
wc -l plugins/pmos-toolkit/skills/prototype/SKILL.md
git add plugins/pmos-toolkit/skills/prototype/SKILL.md
git commit -m "feat(prototype): SKILL.md Phases 4-5 (runtime+styles, device generation)"
```

---

## Task 13: SKILL.md — Phase 6 (Refinement), Phase 7 (Friction), Phase 8 (Findings Protocol)

**Files:**
- Modify: `plugins/pmos-toolkit/skills/prototype/SKILL.md` (append)

- [ ] **Step 1: Append**

```markdown
---

## Phase 6: Refinement Loop (Reviewer Subagent + ≤2 Loops Per File)

For each per-device HTML file, run up to 2 refinement loops. Stop early when zero high/medium findings remain.

### Loop Structure

**Step 1 — Dispatch reviewer subagent (parallel):**
- One reviewer per device file
- Prompt: load `reference/eval-rubric.md`. Score the file against all six heuristic groups (I, J, M, A, V, R). Return JSON findings array.

**Step 2 — Apply fixes:**
- High/medium → apply via `Edit` (or have a generator subagent re-emit the affected section)
- Low → log in HTML comment block at top of file as "Known minor issues"
- Track changes in a `Review Log` HTML comment

**Step 3 — Loop continuation:**
- Remaining high/medium → run loop 2
- Otherwise exit
- Hard cap: 2 loops per file

**Platform fallback:** run reviewer pass inline.

---

## Phase 7: Interactive Friction Pass

Use `reference/friction-thresholds.md`. Pull journey list from req doc (cap 5).

For each journey:
1. Trace screens through the prototype (subagent reads device HTML, walks the route table from `runtime.js`)
2. Count clicks, keystrokes, decisions, screen transitions, modal interruptions per step
3. Apply thresholds; flag exceedances with severity

**Subagents:** one per journey, parallel.

**Output:** `{feature_folder}/prototype/interactive-friction.md` — per-journey table + flagged items + cumulative metrics.

**Anti-pattern:** do NOT re-run PSYCH or MSF — those are `/wireframes` responsibilities.

---

## Phase 8: Findings Presentation Protocol

Aggregate Phase 6 unresolved + Phase 7 flags. Group by target (prototype / wireframe / req doc).

`AskUserQuestion`, ≤4 per batch:
- **question:** one-sentence finding + which file(s) + proposed fix
- **options:** **Apply to prototype** / **Update wireframe** / **Update req doc** / **Defer to spec**

Apply dispositions:
- Prototype edits via `Edit`. Inline spot-check post-edit (no Phase 6 re-loop).
- Wireframe edits via `Edit` to the wireframe file.
- Req doc edits append a `## Prototype Findings` subsection with the change.

Log every applied change in `{feature_folder}/prototype/prototype-findings.md`.

**Cap total findings surfaced at 12.** Highest severity first. Rest go to `prototype-findings.md` under "Unsurfaced findings".

**Platform fallback:** numbered findings table with disposition column; do NOT silently self-fix.

**Anti-pattern:** A wall of prose ending in "Let me know what you'd like to fix." Always structure the ask.
```

- [ ] **Step 2: Verify + commit**

```bash
wc -l plugins/pmos-toolkit/skills/prototype/SKILL.md
git add plugins/pmos-toolkit/skills/prototype/SKILL.md
git commit -m "feat(prototype): SKILL.md Phases 6-8 (refinement, friction, findings)"
```

---

## Task 14: SKILL.md — Phase 9 (Index+Serve), Phase 10 (Spec Handoff), Phases 11-12 (Enrichment+Learnings)

**Files:**
- Modify: `plugins/pmos-toolkit/skills/prototype/SKILL.md` (append)

- [ ] **Step 1: Append**

```markdown
---

## Phase 9: Generate Landing Index + Serve

### 9a. Generate index.html

Create `{feature_folder}/prototype/index.html`:
- Header: feature name, generation date, link back to req doc + wireframes
- Device tabs/cards: one per device file with device name, screen count, mock-data summary, "Open prototype" button
- Footer: file count, friction-pass summary, findings count
- Loads `assets/prototype.css` only (no React — pure HTML landing)

### 9b. Serve

Detect Node:

```bash
command -v node && command -v npx
```

- **Node available:** start `npx --yes http-server -p 0 -c-1 --silent` in `{feature_folder}/prototype/`. Capture port. Report `http://localhost:<port>/index.html`.
- **Node missing:** print absolute `file://` path. Note that inline-data fallback handles Chrome/Safari fetch restrictions.

Always print BOTH a served URL (if any) AND the file path.

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
| 01 | … | … | linked from index.<device>.html |
```

Commit:

```bash
git add {feature_folder}/prototype/ {requirements_doc_path}
git commit -m "docs: add prototype for <feature>"
```

Tell the user: "Prototype is ready. Open `{served_url_or_file_path}` to review. When you're ready, run `/pmos-toolkit:spec` — it picks up the prototype findings from the requirements doc automatically."

---

## Phase 11: Workstream Enrichment

**Skip if no workstream was loaded in Phase 0.** Otherwise, follow the enrichment instructions in `product-context/context-loading.md` Step 4. Signals for this skill:

- Brand color overrides applied during Phase 4 → workstream `## Tech Stack`
- Recurring interaction patterns (modal dismissal, form layout) → workstream `## Design System / UI Patterns`
- Device-specific decisions → workstream `## Constraints & Scars`

Mandatory whenever Phase 0 loaded a workstream.

---

## Phase 12: Capture Learnings

**This skill is not complete until the learnings-capture process has run.** Read and follow `learnings/learnings-capture.md` (relative to the skills directory, or the shared file at `../_shared/` if linked) now. Reflect on whether this session surfaced anything worth capturing — surprising mock-data realism issues, latency calibration that worked, friction thresholds that need adjustment, a runtime pattern that broke in a specific browser. Proposing zero learnings is a valid outcome.
```

- [ ] **Step 2: Set up learnings reference**

The learnings-capture file is shared. Create a reference:

```bash
mkdir -p plugins/pmos-toolkit/skills/prototype/learnings
# Copy the same approach wireframes uses; either symlink or copy
cp plugins/pmos-toolkit/skills/wireframes/learnings/* plugins/pmos-toolkit/skills/prototype/learnings/ 2>/dev/null || \
  echo "wireframes/learnings empty; will use shared path"
```

If wireframes uses a different path, mirror that. Verify after:

```bash
ls plugins/pmos-toolkit/skills/prototype/learnings/ 2>/dev/null
```

- [ ] **Step 3: Verify + commit**

```bash
wc -l plugins/pmos-toolkit/skills/prototype/SKILL.md
git add plugins/pmos-toolkit/skills/prototype/
git commit -m "feat(prototype): SKILL.md Phases 9-12 (index, handoff, enrichment, learnings)"
```

---

## Task 15: SKILL.md — Anti-Patterns + final polish

**Files:**
- Modify: `plugins/pmos-toolkit/skills/prototype/SKILL.md` (append)

- [ ] **Step 1: Append Anti-Patterns**

```markdown
---

## Anti-Patterns (DO NOT)

- Do NOT generate prototype without confirmed wireframes — auto-trigger `/wireframes` if missing
- Do NOT regenerate mock data per device file — generate once in Phase 3, share across all
- Do NOT silently fix high-severity findings — always surface via Findings Presentation Protocol
- Do NOT exceed 2 refinement loops per device file
- Do NOT prototype non-user-facing features (backend-only, cron jobs, internal APIs)
- Do NOT introduce build steps, npm packages, bundlers, or any backend
- Do NOT inline `runtime.js` or `components.js` into device files — share via `assets/`
- Do NOT use Lorem ipsum or generic mock data — must be domain-real
- Do NOT cherry-pick screens — full coverage is the contract
- Do NOT re-run PSYCH or MSF — `/wireframes` owns those; this skill runs the lighter friction pass
- Do NOT skip Phase 12 (capture learnings) — terminal gate
- Do NOT generate prototypes that fail on `file://` — always emit inline-data fallback alongside JSON files
- Do NOT exceed 5 journeys in the friction pass — diminishing returns
- Do NOT auto-edit upstream wireframes or req doc without explicit user disposition
- Do NOT skip Phase 2 tier gate — Tier 1 features must be turned away politely
- Do NOT add a separate AskUserQuestion gate around per-finding fixes if Phase 8 already handled them
```

- [ ] **Step 2: Verify totals**

```bash
wc -l plugins/pmos-toolkit/skills/prototype/SKILL.md
```
Expected: ≤500 lines. If over, extract verbose sections to `reference/`.

- [ ] **Step 3: Cross-reference integrity check**

```bash
# every reference/ file mentioned in SKILL.md must exist
grep -oE 'reference/[a-z-]+\.md' plugins/pmos-toolkit/skills/prototype/SKILL.md | sort -u | while read f; do
  test -f "plugins/pmos-toolkit/skills/prototype/$f" || echo "MISSING: $f"
done
```
Expected: empty output.

- [ ] **Step 4: Convention compliance audit (manual checklist)**

Verify all `/create-skill` conventions:
- [x] Saved to plugins/pmos-toolkit/skills/prototype/SKILL.md
- [x] Platform Adaptation present
- [x] Description has trigger phrases
- [x] No hard dependency on AskUserQuestion (fallbacks documented)
- [x] No hard dependency on MCP tools
- [x] Pipeline diagram included
- [x] Findings Presentation Protocol present
- [x] Phase 0 reads learnings + workstream
- [x] Capture Learnings is a numbered phase with terminal-gate language
- [x] Workstream Enrichment is a numbered phase
- [x] Track Progress instruction (≥3 phases)
- [x] Anti-Patterns section
- [x] ≤500 lines

- [ ] **Step 5: Commit**

```bash
git add plugins/pmos-toolkit/skills/prototype/SKILL.md
git commit -m "feat(prototype): SKILL.md anti-patterns + final polish"
```

---

## Task 16: Smoke test recommendation + final commit

**Files:** none (recommendation note for user)

- [ ] **Step 1: Write a SMOKE-TEST.md note for the user**

Since end-to-end smoke testing requires invoking the skill against a real feature folder with wireframes, document the test recipe instead of running it autonomously:

Create `plugins/pmos-toolkit/skills/prototype/SMOKE-TEST.md`:

```markdown
# /prototype Smoke Test Recipe

After installing the skill (restart Claude Code or `/reload-plugins`), run:

1. Pick a feature folder that already has `/wireframes` output (look under `docs/features/`)
2. Run `/pmos-toolkit:prototype <path-to-req-doc>` for that feature
3. Verify the skill:
   - Loads workstream + learnings without error (Phase 0)
   - Detects existing wireframes (Phase 1)
   - Honors tier gating (Phase 2)
   - Generates `assets/<entity>.json` with domain-real data (Phase 3)
   - Generates `runtime.js`, `components.js`, `styles.css` in parallel (Phase 4)
   - Produces one `index.<device>.html` per device (Phase 5) that opens cleanly in a browser
   - Reviewer subagent runs ≤2 loops per file (Phase 6)
   - Friction pass produces `interactive-friction.md` (Phase 7)
   - Findings surface via AskUserQuestion (Phase 8)
   - Landing index serves; both URL + file path printed (Phase 9)
   - Req doc gets `## Prototype` section appended (Phase 10)
   - Workstream enriched if loaded (Phase 11)
   - Learnings captured (Phase 12)

If any phase fails, capture findings in `~/.pmos/learnings.md` under `## /prototype` and iterate.
```

- [ ] **Step 2: Final repo-wide commit + summary**

```bash
git add plugins/pmos-toolkit/skills/prototype/SMOKE-TEST.md
git commit -m "docs(prototype): smoke test recipe"
git log --oneline -10
```

---

## Self-Review

After all tasks complete, verify:

1. **Spec coverage:** every phase in the design spec maps to a SKILL.md section. Open spec, walk phases 0–12, point to SKILL.md heading for each.
2. **Placeholder scan:** `grep -rn "TBD\|TODO\|FIXME\|XXX" plugins/pmos-toolkit/skills/prototype/` should return nothing in checked-in files.
3. **Cross-reference integrity:** every `reference/<name>.md` linked from SKILL.md exists; every `assets/<name>.<ext>` linked from reference/ exists in the skill's `assets/` (the runtime artifacts referenced by templates exist as templates).
4. **Line count:** `wc -l plugins/pmos-toolkit/skills/prototype/SKILL.md` ≤ 500.
5. **Naming consistency:** "prototype-findings.md", "interactive-friction.md", `assets/runtime.js`, `assets/components.js`, `assets/styles.css`, `assets/prototype.css` — same names everywhere they appear.

Fix any issues inline before declaring done.
