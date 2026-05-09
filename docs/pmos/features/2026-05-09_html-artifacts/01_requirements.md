# HTML-native artifact generation across pmos-toolkit pipeline skills — Requirements

**Date:** 2026-05-09
**Last updated:** 2026-05-09
**Status:** Draft
**Tier:** 3 — Feature

---

## Problem

Every pmos-toolkit pipeline skill that writes into a feature folder (`/requirements`, `/spec`, `/plan`, `/msf-req`, `/msf-wf`, `/simulate-spec`, `/grill`, `/artifact`, `/verify`, `/design-crit`) writes its primary artifact as **plain markdown**. **Markdown is the wrong primary format for these documents.**

(Global, non-feature-folder skills `/changelog` and `/session-log` are explicitly **not in scope this iteration** — see Non-Goals.)

Three concrete pains:

1. **Markdown can't express what the artifact wants to say.** Architecture diagrams are reduced to ASCII. Decision trees collapse to nested bullets. State transition matrices flatten into tables that lose direction. Screenshots and visual mockups can't be embedded inline; they require separate image files referenced by URL. Cross-references between sections degrade to "(see §3.2)" text rather than working anchors.
2. **Pipeline output is invisible without effort.** A user finishes `/feature-sdlc` with a feature folder containing 8+ markdown files (`01_requirements.md`, `02_spec.md`, `03_plan.md`, `msf-findings.md`, `simulate-spec/*.md`, `grills/*.md`, `wireframes/*.html`, `verify/*.md`). They have no unified way to navigate them. Wireframes are HTML; everything else is markdown — they can't be browsed in a single view. Sharing requires zipping the folder or pasting individual markdown bodies.
3. **Reviewer subagents parse markdown by heading regex** — fragile, breaks when authors use a different `##` level, can't disambiguate sections with the same heading text in different parts of the doc.

### Who experiences this?

Three distinct roles, all on the same person but with different needs at different moments:

- **Skill author / pipeline operator** (the user invoking `/requirements`, `/spec`, etc.) — generates the artifact and wants the format to support what they're trying to express.
- **Stakeholder / reader** (the user, a teammate, or an LLM reviewing later) — opens the feature folder and wants to navigate, read, and share the work.
- **Reviewer subagent** (LLMs invoked inside `/grill`, `/verify`, `/msf-req`, `/msf-wf`, `/simulate-spec`) — parses the artifact to extract sections for evaluation.

### Why now?

Two converging triggers. **Trigger 1:** the user attempted to take a `/spec` output to a stakeholder for review and found the markdown unshareable — no diagrams render inline, no nav, no embedded mockups. **Trigger 2:** `/wireframes` and `/prototype` already prove the HTML-output pattern works inside the pipeline (HTML files + `serve.js` + `index.html` viewer), and the asymmetry — wireframes are HTML, surrounding context isn't — is now actively hurting the experience. The infra precedent exists; the gap is no longer justifiable.

---

## Goals & Non-Goals

> Goals are observable user outcomes. Acceptance Criteria (engineering contracts) belong in `/spec`.

### Goals

- **A finished feature folder is shareable as a self-contained, navigable artifact set** — the user (or a teammate, or an LLM) can open the folder via `node serve.js` (or zip-and-share) and read every artifact in a single sidebar-navigated view without prior setup — measured by: a recipient with no pmos-toolkit installed can navigate a finished feature folder end-to-end in under a minute from cold.
- **Skills generate HTML directly,** authoring semantic structure, inline SVG diagrams, embedded images, structured tables, and anchored cross-references — not by post-converting markdown — measured by: zero "md→html converter" code paths in the affected skills.
- **Every feature folder ships with a unified, navigable viewer** (`index.html`) that shows all artifacts including nested wireframes/prototype/grill outputs in one place — measured by: opening `index.html` reveals every artifact in the folder via a sidebar TOC.
- **Markdown remains available for clipboard/export** but only as a **derived** format from the HTML source — measured by: a "Copy Markdown" button per doc in the viewer that produces clean, structured markdown on demand.
- **Reviewer subagents read HTML semantically** (the LLM is the parser; receive HTML wholesale, no DOM extraction or regex) — measured by: zero `^##` regex extractors AND zero `jsdom`/DOM-querying code paths in reviewer prompts post-migration.
- **Output format is configurable** via `.pmos/settings.yaml :: output_format` ∈ `{html, both}` (default `html`) and per-invocation `--format` flag.

### Non-Goals

- **NOT migrating `/changelog` and `/session-log` to HTML in this iteration** — because they write **global** docs (`docs/changelog.md`, `docs/session-log.md`) outside any feature folder, and dragging them in expands scope to "design a repo-wide HTML docs viewer", which is its own decision. We address feature-folder asymmetry first; revisit global docs as a follow-up.
- **NOT migrating existing artifacts** in old `{docs_path}/features/*` folders — because retroactive conversion is high risk for low value; old folders stay markdown-native.
- **NOT supporting `output_format: markdown`-only** (HTML always written) — because the user explicitly rejected "markdown source of truth"; allowing markdown-only would re-introduce that path.
- **NOT building a hosted viewer / web service** — because the viewer is local-only via `serve.js`; we ship a static folder, not a deployment.
- **NOT supporting heavy HTML frameworks** (React, Vue, build steps) — because the viewer must run from a static folder with zero install; React-via-CDN (already used by `/prototype`) is acceptable, build pipelines are not.
- **NOT adopting an existing static-site generator** (mdbook, MkDocs, Sphinx, Eleventy, docsify, etc.) — see D11 below.
- **NOT making `/diagram` a pure programmatic API** in this iteration if it requires deep refactor — because the diagram-embed contract should work with `/diagram` as it stands; if it can't, the skill body inlines SVG directly via prompt as the fallback.
- **NOT redesigning the artifact contents** — sections, content, and tone stay the same; only the rendering format changes.

---

## User Experience Analysis

### Motivation

**Job to be done:**
- *Skill author:* "I want this design decision matrix / state diagram / flow chart to actually look like a decision matrix / state diagram / flow chart in the document, not a wall of nested bullets."
- *Stakeholder reader:* "I want to open this feature folder and immediately see the whole story — requirements, spec, wireframes, journey, plan — without piecing together a dozen files."
- *Reviewer subagent:* "I want to extract section X by a stable anchor without guessing whether the author wrote `##` or `###`."

**Importance / Urgency:** High for skill author (already painful — the work product the user is trying to ship feels under-served by the format). Medium for stakeholder reader (nice-to-have until you try to share, then critical). High for reviewer subagent (silent quality bug — heading-regex misses cause reviewer findings to be wrong, which the user discovers only when reviewing the review).

**Alternatives the user could take:**

- *Hand-write HTML for each artifact* — defeats the point of the pipeline.
- *Convert markdown to HTML post-hoc with a tool like pandoc* — the user explicitly rejected this; the limitation is that markdown can't express the intent in the first place, so converting from markdown loses fidelity regardless of the converter.
- *Live with markdown forever* — leaves all three pains unaddressed.

### Friction Points

| Friction Point | Cause | Mitigation |
|---|---|---|
| "I don't know how to author HTML inside a skill prompt" — skill author worries about whether the LLM can generate good HTML | Skills' authoring instructions are markdown-shaped today; rewriting them is the bulk of the work | Shared `_shared/html-authoring/` contract with a base template, structural-attribute conventions, and a per-skill section taxonomy — so skill prompts say "fill in the `<section data-section="problem">` block" rather than "design HTML from scratch" |
| "I can't see the artifacts because nothing renders my HTML" — reader opens `01_requirements.html` directly in the file system and sees raw markup or unstyled output | Browsers render HTML but local CSS/JS may be blocked under `file://`; nested artifacts need the parent's CSS | Index viewer + `node serve.js` (zero-deps `http.createServer`) — already the pattern from `/wireframes` and `/prototype`. Print the URL clearly at end of every artifact-write phase. |
| "I want the markdown for clipboard / chatops / pastebin" — reader has HTML but downstream tooling expects markdown | HTML is the source of truth post-migration | "Copy Markdown" button in the viewer, runs html→md client-side at click time. Always-fresh, no sidecar files to keep in sync. |
| "Reviewer subagents miss findings because they can't find a section" — heading regex breaks silently when author uses a different level | Markdown's structural anchors are heuristic, not contractual | Reviewers read HTML wholesale and rely on the LLM to find sections semantically (the same way LLMs already read MD). HTML's natural semantics (`<section>`, `<h2>`, etc.) are richer than markdown's heading hierarchy, so semantic extraction is more robust, not less. |
| "I write a doc, then re-run the skill, and now my pretty HTML is gone" — overwrite without snapshot | All affected skills today snapshot-commit before rewrite for the markdown case (per `/requirements` Phase 4 pre-write safety) | Same snapshot-commit guard applies to HTML; the safety doesn't depend on file format |
| "/diagram doesn't compose into another skill cleanly" — diagrams need to land mid-document, but `/diagram` is currently a user-invokable standalone | `/diagram` was designed for direct user invocation, not as a callable from another skill's prompt | Open question (D2 below) — resolve in `/grill`. Fallback path: skills inline SVG directly in the prompt when `/diagram` proves uncallable. |

### Satisfaction Signals

- The user opens `index.html` for a finished feature folder, sees every artifact in one TOC, and shares the folder via screenshot or `serve.js` URL without needing to assemble anything.
- The user reads a `/spec` output and the architecture diagram is **actually a diagram**, not ASCII boxes.
- A reviewer subagent's findings cite section names that match what the artifact author wrote, and link to in-doc anchors (`#error-handling`) the user can click to jump to.
- The user doesn't think about format at all — `output_format: html` is the default, the doc is HTML, the viewer just works.

---

## Solution Direction

Six components, sequenced so reviewer migration ships in lockstep with artifact format:

### 1. Shared HTML authoring contract — `plugins/pmos-toolkit/skills/_shared/html-authoring/`

A new shared directory containing:

- **Base HTML template** — head, link to a sibling `./assets/style.css`, optional script tag for `./assets/viewer.js` (Copy-Markdown, sidebar TOC builder).
- **Semantic structure convention** — skills author standard semantic HTML (`<section>`, `<h2>`, `<table>`, `<figure>`, `<dl>`, etc.) using auto-generated `id` attributes on headings (`<h2 id="problem">`). No special attribute discipline — just clean semantic markup the way an LLM naturally produces it. The viewer's TOC builder walks `h1`/`h2`/`h3` for sidebar entries; in-doc cross-references use standard `#id` anchors.
- **Diagram convention** — when a skill identifies a diagram-worthy moment, it spawns `/diagram` as a blocking Task subagent (per D2), receives the SVG, and inlines it inside `<figure>` with a `<figcaption>`. No special attributes required.
- **Asset distribution (per Q5 grill resolution)** — skills copy `style.css`, `serve.js`, and any required JS (e.g., turndown for Copy-Markdown) into `{feature_folder}/assets/` at write time. Each feature folder is fully self-contained — the goal is "zip-and-share" with no setup on the recipient's side. Trade-off: stylesheet updates don't propagate to existing folders (acceptable per D5: forward-only).
- **Image handling** — image sidecars (screenshots, photos) go to `{feature_folder}/assets/`; HTML references via relative paths. Inline SVG is preferred for small diagrams; large/reused diagrams go to `assets/diagrams/`.

User-observable behavior: skill prompts get **shorter and more directive** ("write a `<section>` for the problem statement") rather than longer (no markdown-styling rules to enforce, no special attribute taxonomy to memorize).

### 2. Per-skill rewrites

Each affected skill's "write the document" phase changes from "write markdown to `01_requirements.md`" to "write HTML to `01_requirements.html`, optionally also write derived `01_requirements.md` if `output_format: both`". The HTML is authored against the shared contract.

All affected outputs are **feature-folder primaries** (`01_requirements`, `02_spec`, `03_plan`, `msf-findings`, `simulate-spec/*`, `grills/*`, `verify/*`) — straightforward; write `.html` instead of `.md`. Global docs (`/changelog`, `/session-log`) are out of scope this iteration (see Non-Goals).

### 3. Index viewer — `{feature_folder}/index.html`

Zero-deps static page generated at write time (each skill regenerates after writing its artifact, or the index generator is invoked explicitly).

Layout (high-level user-observable behavior — visual design comes from `/wireframes`, not this doc):

- **Sidebar** — TOC across every artifact in the folder, including nested folders (`wireframes/`, `prototype/`, `grills/`, `simulate-spec/`, `verify/`). Group by phase. Each entry expands to show the artifact's `<h2>`/`<h3>` headings as second-level nav (auto-generated by walking the loaded HTML's heading tree).
- **Main pane** — the currently-selected artifact rendered inline (HTML inserted directly, not via `<iframe>`) so anchored navigation works seamlessly.
- **Per-doc toolbar** — at the top of each rendered artifact: "Copy Markdown" button (runs html→md at click time). Possibly also "Open in new tab" and "Copy section link".
- **Frame chrome** — minimal; the artifact's own content dominates.

### 4. Local server — `{feature_folder}/serve.js`

Reuse the pattern from `/wireframes`: zero-dep Node.js `http.createServer`, serves the folder, prints URL, optionally opens default browser. Invoke via `node serve.js` from the feature folder.

### 5. Reviewer subagent migration

Reviewer subagents in `/grill`, `/verify`, `/msf-req`, `/msf-wf`, `/simulate-spec` switch their input file extension and prompt expectations:

- **Before:** read `*.md`. Reviewer prompts speak in terms of markdown structure (`## Decisions`, `### Open Questions`, etc.).
- **After:** read `*.html`. Reviewer prompts speak in terms of HTML semantic structure (`<section>` for "Decisions", `<h2>` named "Open Questions", etc.). The LLM is the parser — no jsdom, no regex, no DOM queries. Same approach the existing markdown reviewers already use; just the input format changes.

Migration ships in the same release as artifact format — no intermediate state. Smoke verification: during `/verify` of this pipeline, each of the 5 reviewers runs at least once on real HTML output from this very feature folder; reviewer findings are spot-checked to confirm sections were actually identified, not silent no-findings.

### 6. Cross-skill artifact resolution (per Q2 grill resolution)

Downstream skills (`/spec` reads `01_requirements`, `/plan` reads `02_spec`, `/verify` reads all priors, etc.) currently resolve upstream artifacts via hardcoded paths or via `_shared/resolve-input.md`. Post-migration, two formats exist on disk: new pipelines write `.html`, old folders contain `.md` (per D5 forward-only).

`_shared/resolve-input.md` is extended with format-aware resolution: given a logical artifact name (e.g., `01_requirements`), it tries `.html` first, falls back to `.md`, errors if neither exists. Every "read upstream artifact" path in every downstream skill routes through it. Resolves the mixed-format-folders concern across feature-folder boundaries (one folder MD, another HTML, both still readable).

### Settings + flag

```yaml
# .pmos/settings.yaml
output_format: html   # one of: html, both. Default: html when unset.
```

```
/<skill> --format html|both       # per-invocation override
```

Behavior:

- `html` — write `.html` only.
- `both` — write `.html` (primary) AND derived `.md` (sidecar at write time, regenerated whenever the `.html` is rewritten).

Note: `markdown`-only is **not a supported value**. Existing markdown artifacts are not touched (per Non-Goals).

---

## User Journeys

### Primary journey — Skill author runs the pipeline (Tier-3 feature, fresh folder)

1. User runs `/feature-sdlc <brief>`. Settings has `output_format: html` (default).
2. `/requirements` runs. At write step, it composes semantic HTML against the shared authoring contract (problem, goals, journeys, decisions as `<section>` blocks with auto-generated heading anchors). Saves `{feature_folder}/01_requirements.html`. Copies `assets/style.css` + `serve.js` into the folder. Regenerates `index.html`.
3. Pipeline announces: `Wrote 01_requirements.html. Run \`node serve.js\` from {feature_folder} to view.`
4. User runs `node serve.js`. Browser opens to `http://localhost:<port>/index.html`. Sidebar shows `01 Requirements` with sub-anchors. Main pane shows the rendered HTML.
5. User clicks "Copy Markdown" — clipboard receives clean structured markdown.
6. Pipeline continues. `/spec` runs, writes `02_spec.html` with inline SVG architecture diagram (from `/diagram` or inlined directly), regenerates `index.html`. Sidebar now shows `02 Spec` too.
7. After `/wireframes`, sidebar shows nested `wireframes/` group with each screen file. Clicking a screen renders it inline in the main pane (existing HTML, no conversion).
8. After `/verify`, the verify reports appear in sidebar as `verify/` group. Each report's reviewer-subagent findings cite section headings (e.g., "in §Decisions of 02_spec") and may link to in-doc `#decisions` anchors.

### Alternate journey — User wants markdown alongside HTML

1. User opts into both formats: `/<skill> --format both` OR sets `output_format: both` in settings.
2. Skill writes `01_requirements.html` (primary) AND `01_requirements.md` (derived sidecar) at the same time. `.md` is regenerated on every `.html` rewrite — never edit `.md` directly.
3. User pastes the `.md` into Slack or wherever; it round-trips cleanly because the html→md derivation is structural.

### Alternate journey — User opens index.html via `file://` (no server)

1. User opens `{feature_folder}/index.html` directly in their browser without running `serve.js`.
2. Index loads with sidebar populated. Some browsers restrict iframe + JS-fetch from `file://` — the index detects this and falls back to a simpler "links to each artifact in new tab" mode rather than inline rendering.
3. A banner at the top reads: `Running from file:// — for the embedded viewer, run \`node serve.js\`.`
4. (Mirror of the existing `/wireframes` "Node missing" pattern.)

### Alternate journey — Reviewer subagent reads an artifact

1. `/grill` runs against `01_requirements.html`.
2. Reviewer subagent receives the HTML wholesale (the same way it currently receives markdown wholesale) and is asked to evaluate the "Decisions" section per its rubric.
3. Subagent reads the HTML semantically (LLM as parser), finds `<section>` containing the heading "Design Decisions", evaluates per the rubric, and emits findings citing section names.
4. Migration ships in lockstep — no run can produce HTML artifacts that reviewers haven't been updated to handle. The reviewer-prompt change is small: swap "expect markdown" → "expect HTML"; the LLM does the rest.

### Error journey — `/diagram` subagent stalls or errors

1. `/spec` reaches a diagram-worthy section. Spawns `/diagram` as a blocking Task subagent.
2. Subagent stalls past a timeout (per `~/.pmos/learnings.md` `## /msf-wf` entry, subagents do stall) OR returns an error.
3. **Fallback path:** skill prompt inlines an SVG directly using its own context. Less polished than `/diagram`'s reviewer-loop output, but viable.
4. The `<figure>` records the source as a `<figcaption>` note (e.g., "Diagram authored inline due to /diagram subagent timeout").
5. Specific timeout, retry, and stall-fallback policy: resolve in `/spec`.

### Error journey — User has `output_format: markdown` in their settings.yaml from before this feature shipped

1. Settings has `output_format: markdown` (a value introduced by some pre-release branch or copy-paste mishap).
2. New skill version reads settings, sees unsupported value, **errors clearly**: `output_format: 'markdown' is not supported. Use 'html' (default) or 'both'.` (Don't silently coerce.)
3. User updates settings, re-runs.

### Error journey — Existing markdown artifacts in current feature folder when HTML run starts

1. User re-runs `/requirements` in a folder that already has `01_requirements.md` (from a pre-HTML run).
2. Skill detects the existing `.md`, runs the pre-write snapshot-commit (existing safety), then writes `01_requirements.html` going forward. The old `.md` stays — it becomes a stale sidecar.
3. Index viewer detects orphan `.md` (no matching `.html`) and surfaces a one-line note in the sidebar: `01_requirements.md (legacy markdown)` — clickable, no Copy-Markdown toolbar (since it's already markdown).
4. (Decision D5 covers this in detail.)

### Empty states & edge cases

| Scenario | Condition | Expected Behavior |
|---|---|---|
| Empty feature folder | `index.html` is generated when first artifact is written | Until then, no `index.html` |
| `serve.js` missing or Node not installed | User runs the skill but doesn't have Node | Skill prints `file://` URL fallback; `serve.js` is bundled but optional |
| Browser blocks JS under `file://` | User opens `index.html` directly | Fallback mode: links open each artifact in a new tab |
| Skill is run before HTML infra ships (this run) | This very requirements doc | Written in markdown — bootstrap. Future runs of the same pipeline write HTML. |
| Existing `.html` and `.md` for the same artifact (post-migration partial state) | Mixed-state folder mid-migration | `.html` is canonical; `.md` shown as legacy entry |
| `--format` flag and settings disagree | Flag wins | Documented; non-controversial |
| `/changelog`, `/session-log` (global docs) | Out of scope this iteration | Stay markdown; revisit as follow-up |

---

## Design Decisions

| # | Decision | Options Considered | Rationale |
|---|---|---|---|
| **D1** | HTML is the **native, primary** authoring target. Markdown is a derived export. | (a) Markdown source-of-truth, convert to HTML for viewing. (b) HTML source-of-truth, convert to markdown on demand. (c) Dual sources (author both). | (b). User explicitly rejected (a): markdown can't express the intent. (c) violates SSOT and creates drift. |
| **D2** | Diagrams: skill spawns **`/diagram` as a blocking Task subagent** per diagram-worthy moment, using its full reviewer loop. Inline-SVG-by-prompt is the fallback when the subagent stalls or errors. | (a) Always inline SVG (cheaper, lower quality). (b) Always spawn `/diagram` subagent (this option). (c) Mermaid client-side (adds JS dep, breaks zero-deps). (d) Refactor `/diagram` to add a render-only mode (scope creep). | (b). Resolved in `/grill` Q1: user accepted the wall-clock cost (30s–2min per diagram) for `/diagram`'s reviewer-refined SVG quality. Stall fallback handles the known subagent-stall risk per `~/.pmos/learnings.md` `## /msf-wf`. Specific timeout/retry policy resolves in `/spec`. |
| **D3** | Reviewer subagents read HTML semantically — **the LLM is the parser**. No `jsdom`, regex, or DOM queries. Reviewer prompts swap "expect markdown" for "expect HTML"; everything else stays the same. | (a) `jsdom`. (b) Regex on attribute. (c) `node-html-parser`. (d) Pass HTML wholesale to LLM (this option). | (d). Resolved in `/grill` (post-Q3/Q6 reframe): the markdown reviewers already pass MD wholesale to the LLM and find sections semantically. HTML is more structured than MD, not less, so semantic extraction is more robust, not less. The data-section attribute taxonomy that earlier grill answers proposed was solving a problem that doesn't exist if we just trust the LLM. |
| **D4** | Markdown export: **client-side conversion at click time**, not pre-rendered sidecar (unless `output_format: both`). | (a) Pre-render `.md` always (sidecar). (b) Bundle a JS converter (e.g., turndown), run in browser at click. (c) Server endpoint that converts on demand. | (b) by default. (a) only when `output_format: both` (explicit opt-in). (c) overkill for a static folder. |
| **D5** | Existing markdown artifacts stay; HTML coexists. Index viewer surfaces orphan `.md` as "legacy" entries. | (a) Migrate existing `.md` to `.html` retroactively. (b) Strict no-touch (this option). (c) Hide legacy entries from index. | (b). Migration is high risk for low value (per Non-Goals). Surfacing them as legacy entries beats hiding (transparency over clean look). |
| **D6** | Index regeneration: each skill calls the index generator after writing its artifact. | (a) Each skill regenerates after write. (b) Standalone `/index` command, user invokes. (c) Generated by `serve.js` at request time. | (a) for write-time freshness. (c) considered for simplicity, but means index is always 1-step out of date until server runs — surprise-prone. (b) extra step, easy to forget. |
| **D7** | Global docs (`/changelog`, `/session-log`) are **excluded from this iteration**. | (a) Migrate, separate `docs/index.html`. (b) Migrate, fold into one global viewer per repo. (c) Skip this iteration; only feature-folder skills migrate. | (c). Migrating them is meaningful scope expansion — pulls in "design a repo-wide HTML docs viewer" as its own concern. Address feature-folder asymmetry first; revisit global docs as a follow-up once the feature-folder pattern is proven. |
| **D8** | Settings field name: `output_format` with values `{html, both}`. Default `html` when unset. | (a) `output_format`, `{html, both}`. (b) `output_format`, `{html, markdown, both}`. (c) `artifact_format`. | (a). (b) re-introduces the markdown-only path the user explicitly rejected. (c) creates a synonym to existing `format` patterns; `output_format` is precise to "what the skill outputs". |
| **D9** | html→md tech choice deferred to `/spec`. (Reviewer parser tech resolved in D3.) | (a) turndown.js bundled client-side (D4 default). (b) Pre-rendered `.md` sidecar at write time. (c) Server-side endpoint. | Resolve in `/spec`. Whatever JS is bundled gets copied to `assets/` per Q5. |
| **D10** | The `_shared/html-authoring/` directory is a **new top-level shared component**, not a per-skill addition. | (a) Each skill owns its own template. (b) Centralized `_shared/html-authoring/`. | (b). Same reason `_shared/pipeline-setup.md` exists — uniform contract beats per-skill drift. |
| **D11** | **NOT adopting an existing static-site generator** (mdbook, MkDocs, Sphinx, Eleventy, docsify, Hugo, Zola, etc.). Build the viewer ourselves as zero-deps static HTML + tiny JS, in the `/wireframes`+`/prototype` style. | (a) Adopt mdbook/MkDocs (markdown-source SSGs). (b) Adopt Eleventy/docsify (more flexible). (c) Build our own (this option). | (c). All major SSGs assume markdown source-of-truth — directly conflicts with D1 (HTML-native). Most require a build step (we ruled out: zero install). They bring opinionated theming, plugin systems, and config files that we'd have to fight to keep minimal. The viewer's footprint is small (sidebar + main pane + Copy-Markdown) and the existing `/wireframes`+`/prototype` pattern proves zero-deps static-HTML viewer-style works inside this pipeline. Adopting an SSG would be more code on net, not less. |

---

## Success Metrics

| Metric | Baseline (today) | Target | Measurement |
|---|---|---|---|
| Affected skills emitting HTML primary | 0 of 10 | 10 of 10 | Grep affected SKILL.md for "write `.html`"; count post-/verify |
| Reviewer subagents reading HTML and emitting non-empty findings on real artifacts | 0 of 5 | 5 of 5 | During `/verify` smoke run on this very feature folder, each reviewer must produce at least one section-aware finding (catches silent no-findings) |
| Time from "skill writes artifact" to "user can navigate it in browser" | Manual (open `.md` in IDE / paste-render) | < 30s (run `node serve.js`, click) | User flow timing during `/verify` |
| Diagrams rendered as SVG (not ASCII) in `/spec` and `/plan` | 0% | ≥ 80% of diagram-worthy moments | Count `<figure>` blocks containing `<svg>` per spec/plan vs. ASCII boxes pre-migration |
| Cross-skill artifact resolution success rate | n/a | 100% across mixed-format folders | `_shared/resolve-input.md` test fixtures: folder-with-only-md, folder-with-only-html, folder-with-both, folder-with-neither (error). All four cases resolve correctly. |
| Round-trip "Copy Markdown → paste → re-render HTML" structural fidelity | n/a (no current path) | Sections, headings, lists, tables preserved | Manual round-trip test on each artifact type during `/verify` |
| Existing-folder regressions | n/a | Zero | All pre-existing `01_requirements.md` files in `docs/pmos/features/*` still render and navigate post-merge |

---

## Research Sources

| Source | Type | Key Takeaway |
|---|---|---|
| `plugins/pmos-toolkit/skills/wireframes/SKILL.md` (lines 398–540) | Existing code | HTML-output pattern is proven: writes `wireframes/{NN}_*.html` + `index.html` + `assets/` + `serve.js` + `file://` fallback. Direct precedent. |
| `plugins/pmos-toolkit/skills/prototype/SKILL.md` (lines 363–394) | Existing code | Per-device `index.<device>.html`; React-via-CDN allowed; runtime smoke under `file://` is degraded. Confirms "no build pipeline" constraint is workable. |
| `plugins/pmos-toolkit/skills/_shared/` | Existing code | Has `pipeline-setup.md`, `interactive-prompts.md`, `non-interactive.md`, `msf-heuristics.md`, etc. Net-new directory `html-authoring/` is consistent with this layout. |
| `plugins/pmos-toolkit/skills/diagram/SKILL.md` | Existing code | `/diagram` is currently designed as user-invokable; inline-SVG-authoring referenced only as part of its own Phase 5 reviewer. Programmatic callability is the Open Question (OQ1). |
| `plugins/pmos-toolkit/skills/{requirements,spec,plan,msf-req,msf-wf,simulate-spec,grill,artifact,verify,design-crit}/SKILL.md` (the 10 in-scope skills) plus `{changelog,session-log}` (out-of-scope confirmation) | Existing code | Confirmed all 12 use `_shared/pipeline-setup.md` for path resolution. In-scope output-path surface: feature-folder primaries (`01_*`, `02_*`, `03_*`), per-skill subfolders (`verify/`, `simulate-spec/`, `grills/`, `msf-findings.md`). Out-of-scope (this iteration): `/changelog` writes `docs/changelog.md`, `/session-log` writes `docs/session-log.md` — both global, not under a feature folder. |
| `plugins/pmos-toolkit/skills/_shared/non-interactive.md` (inlined non-interactive block) | Existing code | Schema already accommodates non-MD primary artifacts: "Primary artifact is non-MD (SVG, etc.) → write sidecar `<artifact>.open-questions.md`". HTML fits cleanly into existing OQ infra; no contract change needed there. |
| `~/.pmos/learnings.md` `## /requirements` (none under that header) | Learning archive | No prior `/requirements` lessons specific to this work. |

---

## Open Questions

| # | Question |
|---|---|
| ~~OQ1~~ | ~~`/diagram` programmatic callability~~ — **resolved in `/grill` Q1:** spawn `/diagram` as blocking Task subagent. |
| ~~OQ2~~ | ~~Reviewer parser tech~~ — **resolved in `/grill` (post-rollback):** the LLM is the parser. No DOM/regex/parser library. Reviewers receive HTML wholesale and find sections semantically. |
| OQ3 | html→md derivation tech: turndown.js bundled client-side vs. pre-rendered `.md` sidecar always vs. server endpoint. Bundle size, freshness, and zero-deps stance pull in different directions. **Resolve in `/spec`.** |
| OQ4 | Index viewer's nested-folder rendering: should `wireframes/` and `prototype/` (already-HTML, with their own `index.html`) embed inline in the parent index or link out? **Resolve in `/wireframes` (Phase 4.c gate of this run) — concrete UI question.** |
| OQ5 | Should the "Copy Markdown" button copy the full doc, or the section under cursor? Or both (toolbar + per-section)? **Resolve in `/wireframes`.** |
| OQ6 | This requirements doc is itself written in markdown (bootstrap). When should we re-author it as HTML — at the end of the implementation, or leave as the historical artifact written in the old format? **Resolve in `/complete-dev`.** |
| OQ7 | What happens to `/feature-sdlc`'s own `00_pipeline.md` and `00_open_questions_index.md`? They're orchestrator artifacts, not skill-pipeline artifacts. In scope or not? **Resolve in `/spec`.** |
| OQ8 | `/diagram` subagent timeout, retry, and stall-fallback policy (per D2 stall path). What's the wall-clock budget per `/spec` run, and when does the skill give up and fall back to inline SVG? **Resolve in `/spec`.** |

---

**For UX friction analysis on this requirements doc, run `/msf-req` after commit.**
