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
- **Reviewer subagents parse HTML by stable structural anchors** (`data-section` attributes), not by heading regex — measured by: zero `^##` regex extractors in reviewer prompts post-migration.
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
| "Reviewer subagents miss findings because they can't find a section" — heading regex breaks silently when author uses a different level | Markdown's structural anchors are heuristic, not contractual | `data-section="<slug>"` attributes are part of the authoring contract; reviewer prompts query by attribute, not by heading text |
| "I write a doc, then re-run the skill, and now my pretty HTML is gone" — overwrite without snapshot | All affected skills today snapshot-commit before rewrite for the markdown case (per `/requirements` Phase 4 pre-write safety) | Same snapshot-commit guard applies to HTML; the safety doesn't depend on file format |
| "/diagram doesn't compose into another skill cleanly" — diagrams need to land mid-document, but `/diagram` is currently a user-invokable standalone | `/diagram` was designed for direct user invocation, not as a callable from another skill's prompt | Open question (D2 below) — resolve in `/grill`. Fallback path: skills inline SVG directly in the prompt when `/diagram` proves uncallable. |

### Satisfaction Signals

- The user opens `index.html` for a finished feature folder, sees every artifact in one TOC, and shares the folder via screenshot or `serve.js` URL without needing to assemble anything.
- The user reads a `/spec` output and the architecture diagram is **actually a diagram**, not ASCII boxes.
- A reviewer subagent's findings cite section anchors (`data-section="error-handling"`) that the user can click and jump to.
- The user doesn't think about format at all — `output_format: html` is the default, the doc is HTML, the viewer just works.

---

## Solution Direction

Five components, sequenced so reviewer migration ships in lockstep with artifact format:

### 1. Shared HTML authoring contract — `plugins/pmos-toolkit/skills/_shared/html-authoring/`

A new shared directory containing:

- **Base HTML template** — head, link to shared CSS, optional script tag for the viewer's JS hooks.
- **Structural-attribute convention** — every major content block carries `data-section="<slug>"`. Slugs are stable (defined per skill in a shared taxonomy file) and referenced by both the index sidebar generator and reviewer subagents.
- **Diagram convention** — when a skill identifies a diagram-worthy moment, it inlines an SVG inside `<figure data-section="diagram-<slug>">`. The SVG source is one of: (a) returned from a `/diagram` call (preferred, if callable; see D2); (b) authored inline by the skill prompt (fallback).
- **Image / asset handling** — skills write image and SVG sidecars to `{feature_folder}/assets/`; HTML references them with relative paths. Inline SVG is allowed (and preferred for small diagrams); large or reused assets go to `assets/`.
- **Shared CSS** (`html-authoring/style.css`) — clean readable defaults, print-friendly, dark/light, no JS frameworks.

User-observable behavior: skill prompts get **shorter and more directive** ("write content for `<section data-section="problem">`") rather than longer (no markdown-styling rules to enforce).

### 2. Per-skill rewrites

Each affected skill's "write the document" phase changes from "write markdown to `01_requirements.md`" to "write HTML to `01_requirements.html`, optionally also write derived `01_requirements.md` if `output_format: both`". The HTML is authored against the shared contract.

All affected outputs are **feature-folder primaries** (`01_requirements`, `02_spec`, `03_plan`, `msf-findings`, `simulate-spec/*`, `grills/*`, `verify/*`) — straightforward; write `.html` instead of `.md`. Global docs (`/changelog`, `/session-log`) are out of scope this iteration (see Non-Goals).

### 3. Index viewer — `{feature_folder}/index.html`

Zero-deps static page generated at write time (each skill regenerates after writing its artifact, or the index generator is invoked explicitly).

Layout (high-level user-observable behavior — visual design comes from `/wireframes`, not this doc):

- **Sidebar** — TOC across every artifact in the folder, including nested folders (`wireframes/`, `prototype/`, `grills/`, `simulate-spec/`, `verify/`). Group by phase. Each entry expands to show the artifact's own `data-section` anchors as second-level nav.
- **Main pane** — the currently-selected artifact rendered inline (HTML inserted directly, not via `<iframe>`) so anchored navigation works seamlessly.
- **Per-doc toolbar** — at the top of each rendered artifact: "Copy Markdown" button (runs html→md at click time). Possibly also "Open in new tab" and "Copy section link".
- **Frame chrome** — minimal; the artifact's own content dominates.

### 4. Local server — `{feature_folder}/serve.js`

Reuse the pattern from `/wireframes`: zero-dep Node.js `http.createServer`, serves the folder, prints URL, optionally opens default browser. Invoke via `node serve.js` from the feature folder.

### 5. Reviewer subagent migration

Reviewer subagents in `/grill`, `/verify`, `/msf-req`, `/msf-wf`, `/simulate-spec` switch their input-parsing logic:

- **Before:** read the markdown file, regex on `^##` to extract sections.
- **After:** read the HTML file, query DOM by `data-section="<slug>"` to extract sections.

Decision D3 below: parser tech choice. Migration ships in the same release as artifact format — no intermediate state.

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
2. `/requirements` runs. At write step, it composes HTML against the shared authoring contract (problem, goals, journeys, decisions all under `data-section` blocks). Saves `{feature_folder}/01_requirements.html`. Regenerates `index.html`.
3. Pipeline announces: `Wrote 01_requirements.html. Run \`node serve.js\` from {feature_folder} to view.`
4. User runs `node serve.js`. Browser opens to `http://localhost:<port>/index.html`. Sidebar shows `01 Requirements` with sub-anchors. Main pane shows the rendered HTML.
5. User clicks "Copy Markdown" — clipboard receives clean structured markdown.
6. Pipeline continues. `/spec` runs, writes `02_spec.html` with inline SVG architecture diagram (from `/diagram` or inlined directly), regenerates `index.html`. Sidebar now shows `02 Spec` too.
7. After `/wireframes`, sidebar shows nested `wireframes/` group with each screen file. Clicking a screen renders it inline in the main pane (existing HTML, no conversion).
8. After `/verify`, the verify reports appear in sidebar as `verify/` group. Each report's reviewer-subagent findings cite `data-section` anchors that the user can click to jump to in the corresponding artifact.

### Alternate journey — User wants markdown alongside HTML

1. User opts into both formats: `/<skill> --format both` OR sets `output_format: both` in settings.
2. Skill writes `01_requirements.html` (primary) AND `01_requirements.md` (derived sidecar) at the same time. `.md` is regenerated on every `.html` rewrite — never edit `.md` directly.
3. User pastes the `.md` into Slack or wherever; it round-trips cleanly because the html→md derivation is structural.

### Alternate journey — User opens index.html via `file://` (no server)

1. User opens `{feature_folder}/index.html` directly in their browser without running `serve.js`.
2. Index loads with sidebar populated. Some browsers restrict iframe + JS-fetch from `file://` — the index detects this and falls back to a simpler "links to each artifact in new tab" mode rather than inline rendering.
3. A banner at the top reads: `Running from file:// — for the embedded viewer, run \`node serve.js\`.`
4. (Mirror of the existing `/wireframes` "Node missing" pattern.)

### Alternate journey — Reviewer subagent extracts a section

1. `/grill` runs against `01_requirements.html`.
2. Reviewer subagent receives the HTML (per D3 parser tech) and is asked to extract the "Decisions" section.
3. Subagent queries `[data-section="decisions"]` (stable anchor), gets the structured content, evaluates per its rubric, and emits findings citing the same anchor. No heading regex involved.
4. (Migration ships in lockstep — no run can produce HTML artifacts that reviewers can't parse.)

### Error journey — `/diagram` invocation fails or is uncallable from a child skill

1. `/spec` reaches a diagram-worthy section. Tries to invoke `/diagram` programmatically. Call returns "uncallable" or errors.
2. **Fallback path** (per Non-Goals + D2): skill prompt inlines an SVG directly. Less polished than `/diagram`'s reviewer-loop output, but viable.
3. Document records this in its own "diagrams" section: `<figure data-section="diagram-arch" data-source="inline">` (vs `data-source="diagram-skill"`).
4. Open Question OQ1: revisit `/diagram` callability in a follow-up.

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
| **D2** | Diagrams: skill **invokes `/diagram`** when callable; falls back to **inline SVG** authored directly when not. | (a) Always inline SVG. (b) Always call `/diagram`. (c) Mermaid blocks rendered client-side. (d) Mix: `/diagram` preferred, inline fallback. | (d). User-confirmed (in `/feature-sdlc` setup): "Skills call `/diagram` internally and embed the result." Fallback handles the (likely) case that programmatic invocation isn't supported today; resolved in `/grill`. |
| **D3** | Reviewer subagents parse HTML by `data-section` attribute. Tech choice deferred to `/grill`/`/spec`. | (a) `jsdom` (real DOM, heavier). (b) Regex on `data-section="…"` (lightweight). (c) `node-html-parser` (middle ground). (d) Pass HTML wholesale to LLM and let it parse. | Defer to `/grill`. (b) is the simplest; (a) is sturdiest; (d) is current-state and what we're trying to leave behind for stability. |
| **D4** | Markdown export: **client-side conversion at click time**, not pre-rendered sidecar (unless `output_format: both`). | (a) Pre-render `.md` always (sidecar). (b) Bundle a JS converter (e.g., turndown), run in browser at click. (c) Server endpoint that converts on demand. | (b) by default. (a) only when `output_format: both` (explicit opt-in). (c) overkill for a static folder. |
| **D5** | Existing markdown artifacts stay; HTML coexists. Index viewer surfaces orphan `.md` as "legacy" entries. | (a) Migrate existing `.md` to `.html` retroactively. (b) Strict no-touch (this option). (c) Hide legacy entries from index. | (b). Migration is high risk for low value (per Non-Goals). Surfacing them as legacy entries beats hiding (transparency over clean look). |
| **D6** | Index regeneration: each skill calls the index generator after writing its artifact. | (a) Each skill regenerates after write. (b) Standalone `/index` command, user invokes. (c) Generated by `serve.js` at request time. | (a) for write-time freshness. (c) considered for simplicity, but means index is always 1-step out of date until server runs — surprise-prone. (b) extra step, easy to forget. |
| **D7** | Global docs (`/changelog`, `/session-log`) are **excluded from this iteration**. | (a) Migrate, separate `docs/index.html`. (b) Migrate, fold into one global viewer per repo. (c) Skip this iteration; only feature-folder skills migrate. | (c). Migrating them is meaningful scope expansion — pulls in "design a repo-wide HTML docs viewer" as its own concern. Address feature-folder asymmetry first; revisit global docs as a follow-up once the feature-folder pattern is proven. |
| **D8** | Settings field name: `output_format` with values `{html, both}`. Default `html` when unset. | (a) `output_format`, `{html, both}`. (b) `output_format`, `{html, markdown, both}`. (c) `artifact_format`. | (a). (b) re-introduces the markdown-only path the user explicitly rejected. (c) creates a synonym to existing `format` patterns; `output_format` is precise to "what the skill outputs". |
| **D9** | Reviewer parser tech and html→md tech choice deferred to `/spec`/`/grill`. | n/a | Tech choices belong in `/spec`. Surfaced here so they're not surprises later. |
| **D10** | The `_shared/html-authoring/` directory is a **new top-level shared component**, not a per-skill addition. | (a) Each skill owns its own template. (b) Centralized `_shared/html-authoring/`. | (b). Same reason `_shared/pipeline-setup.md` exists — uniform contract beats per-skill drift. |
| **D11** | **NOT adopting an existing static-site generator** (mdbook, MkDocs, Sphinx, Eleventy, docsify, Hugo, Zola, etc.). Build the viewer ourselves as zero-deps static HTML + tiny JS, in the `/wireframes`+`/prototype` style. | (a) Adopt mdbook/MkDocs (markdown-source SSGs). (b) Adopt Eleventy/docsify (more flexible). (c) Build our own (this option). | (c). All major SSGs assume markdown source-of-truth — directly conflicts with D1 (HTML-native). Most require a build step (we ruled out: zero install). They bring opinionated theming, plugin systems, and config files that we'd have to fight to keep minimal. The viewer's footprint is small (sidebar + main pane + Copy-Markdown) and the existing `/wireframes`+`/prototype` pattern proves zero-deps static-HTML viewer-style works inside this pipeline. Adopting an SSG would be more code on net, not less. |

---

## Success Metrics

| Metric | Baseline (today) | Target | Measurement |
|---|---|---|---|
| Affected skills emitting HTML primary | 0 of 10 | 10 of 10 | Grep affected SKILL.md for "write `.html`"; count post-/verify |
| Reviewer subagents querying by `data-section` | 0 of 5 | 5 of 5 | Grep reviewer prompts for `data-section`; zero `^##` regex post-migration |
| Time from "skill writes artifact" to "user can navigate it in browser" | Manual (open `.md` in IDE / paste-render) | < 30s (run `node serve.js`, click) | User flow timing during `/verify` |
| Diagrams rendered as SVG (not ASCII) in `/spec` and `/plan` | 0% | ≥ 80% of diagram-worthy moments | Count `<figure data-section="diagram-*">` per spec/plan vs. ASCII boxes pre-migration |
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
| OQ1 | Is `/diagram` callable programmatically from another skill's prompt — i.e., can `/spec` invoke `/diagram` mid-document and inline the returned SVG? If not, what's the cleanest contract to make it callable, and does that go in this iteration or get fallback'd via inline-SVG (per D2)? **Resolve in `/grill`.** |
| OQ2 | Reviewer parser tech: jsdom vs. regex on `data-section` vs. `node-html-parser` vs. pass-HTML-to-LLM. Performance, correctness, and reviewer-prompt churn each implicate different choices. **Resolve in `/spec`.** |
| OQ3 | html→md derivation tech: turndown.js bundled client-side vs. pre-rendered `.md` sidecar always vs. server endpoint. Bundle size, freshness, and zero-deps stance pull in different directions. **Resolve in `/spec`.** |
| OQ4 | Index viewer's nested-folder rendering: should `wireframes/` and `prototype/` (already-HTML, with their own `index.html`) embed inline in the parent index or link out? **Resolve in `/wireframes` (Phase 4.c gate of this run) — concrete UI question.** |
| OQ5 | Should the "Copy Markdown" button copy the full doc, or the section under cursor? Or both (toolbar + per-section)? **Resolve in `/wireframes`.** |
| OQ6 | This requirements doc is itself written in markdown (bootstrap). When should we re-author it as HTML — at the end of the implementation, or leave as the historical artifact written in the old format? **Resolve in `/complete-dev`.** |
| OQ7 | What happens to `/feature-sdlc`'s own `00_pipeline.md` and `00_open_questions_index.md`? They're orchestrator artifacts, not skill-pipeline artifacts. In scope or not? **Resolve in `/spec`.** |

---

**For UX friction analysis on this requirements doc, run `/msf-req` after commit.**
