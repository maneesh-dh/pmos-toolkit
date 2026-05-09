# MSF + PSYCH Findings — html-artifacts wireframes

Entry context: Medium (40, default). Override by editing this line and re-running.

**Date:** 2026-05-09
**Mode:** /msf-wf --apply-edits (parent: /wireframes Phase 6)
**Wireframes folder:** `docs/pmos/features/2026-05-09_html-artifacts/wireframes/`
**Tier:** 3 — Feature
**Personas evaluated:** Skill author / pipeline operator; Stakeholder / reader; Reviewer subagent (collapsed onto one human per single-user-tool pattern from `## /msf-wf` learnings)
**Scenarios:** (a) operator running pipeline fresh, (b) stakeholder cold-open from Slack zip, (c) future-self revisiting older mixed-state folder
**Journeys analyzed:** 4 of 4 (J1 default-pipeline-run / W01, J2 file://-fallback-cold-open / W02, J3 mixed-state-folder / W03, J4 recipient-quickstart-first-open / W04)

> Consolidates the prior `/msf-req` pass (preserved at `msf-findings.md.bak`) which surfaced 11 recommendations (3 Must / 5 Should / 3 Nice) on the requirements doc. This pass adds wireframe-grounded findings that the text-only analysis couldn't see — affordance ambiguity, cold-open momentum, mode-switch friction.

---

## Threshold legend

- Cumulative `< 20` → **Watch**
- Cumulative `< 0` → **Bounce risk**
- Single-screen Δ drop `> 20` → **Cliff**

---

## Section A — MSF Analysis (grounded)

### Persona × Scenario matrix

The persona collapses onto one human; scenarios remain the productive axis.

#### Scenario (a) — Operator running pipeline fresh (entry: Medium 40, J1 / W01)

**Motivation**
- *Job to be done:* Open the feature folder mid-pipeline and confirm `02_spec.html` rendered with its diagram. Wireframe W01 artifact-loaded state delivers exactly this — sidebar with anchors, inline SVG figure, working `#problem`/`#goals` anchors. ✓
- *Importance:* High (already-painful per req doc Trigger 1).
- *Alternatives:* Open `.md` in IDE preview (status-quo). W01 beats it on diagram fidelity and sidebar completeness.

**Friction**
- *Will the user understand this product?* Yes — chrome layout (sidebar + main pane + toolbar) is conventional. No new mental model required.
- *Decision complexity:* Low. The sidebar is the navigation; clicking is the only decision.
- *What else is going on?* The `Search ⌘K` button in W01 default state is a non-functional stub (no input, no behavior wired). For an operator scanning the chrome, an unlabeled placeholder is mild affordance ambiguity. → **W4** (drop or spec).
- *How inconsistent with expectations?* The Copy Markdown toolbar mirrors GitHub/Notion patterns; recognizable.

**Satisfaction**
- *Fulfilled the promised job?* Yes — the inline SVG renders, the copy-toast confirms exactly what was copied (size + section count). High felt-smart signal.

#### Scenario (b) — Stakeholder cold-open from Slack zip (entry: Low-intent 25, J2 / W02 + J4 / W04)

**Motivation**
- *Job to be done:* Read the feature artifact set well enough to leave review comments. Recipient is reactive (responding to a Slack drop), not proactive. Low-intent.
- *Importance:* Medium — until a deadline forces it.
- *Alternatives:* Ask the author to paste markdown into Slack. The wireframes must beat that for the cold-open.

**Friction**
- *Will the user understand this product?* W04's 3-step quickstart card is the make-or-break here. The card layout works (numbered steps, code chips, plain-language labels). But **W02's `↗` icon in sidebar items is opaque** to a non-developer recipient — they won't parse it as "external link." → **W1** (add visible hint).
- *Cost of a wrong decision:* Closing the tab assuming "the doc is broken" because the file:// fallback rendered blank or unstyled. W02 banner mitigates this — but only if the recipient actually reads it.
- *How inconsistent with expectations?* The recipient expects "open in browser → read." The fallback to "open each artifact in a new tab" is a divergence from expectation. The banner's expectation-setting (the "What works / Degraded" table) is the right move; W2 strengthens this.
- *What do they stand to lose?* Time + trust in the author.

**Satisfaction**
- *Fulfilled the promised job?* Yes if Node-installed path taken; partial via fallback. W04's quickstart is the critical hand-hold; without it, satisfaction collapses.
- *Reassuring?* W04 dismissed-state shows a `? Quickstart` button to re-summon — good reversibility.

#### Scenario (c) — Future-self revisiting older mixed-state folder (entry: Medium 40, J3 / W03)

**Motivation**
- *Job to be done:* Look up a decision from 6 weeks ago in a folder that pre-dates the HTML migration. Goal-directed, returning user.
- *Alternatives:* `git log --grep`. The viewer must beat it on context.

**Friction**
- *Cost of a wrong decision:* Confusing the legacy `.md` for a corrupted artifact. W03's italic + `legacy .md` chip handles this visually; the mixed-state callout makes it explicit. ✓
- *How inconsistent with expectations?* The pre-formatted `<pre>` rendering of the legacy markdown source feels visually different from the rendered HTML siblings. May read as "broken" even though intentional. → **W2** (clarifying prefix).
- *What else is going on?* Future-self has accumulated context; less ambiguity tolerance than fresh operator. Callout helps.

**Satisfaction**
- *Fulfilled the promised job?* Yes — content readable; Copy-affordance correctly absent ("No Copy Markdown — already markdown" disclosure prevents broken-affordance frustration). +Felt-smart.

---

## Section B — PSYCH Scoring

### Driver palette

Standard palette per `reference/psych-output-format.md`. Vocabulary kept consistent for cross-feature reading.

### Journey J1 — Default pipeline run (W01) — start: Medium 40

Sparkline: 40→48→63→68   ▁▃▆▇   (no danger; trending up)

#### Element table

| Screen | Element | ±Psych | Running | Notes |
|--------|---------|--------|---------|-------|
| W01 default | Grouped sidebar TOC populated | +5 | 45 | Completion cue: "every artifact in one place" |
| W01 default | "Pick an artifact" welcome with hint | +2 | 47 | Clear next action |
| W01 default | "Run `node serve.js`" tip | +2 | 49 | Handles common confusion proactively |
| W01 default | `Search ⌘K` non-functional stub | -1 | 48 | Question: what does this do? |
| W01 artifact-loaded | Sidebar drill-down anchors | +3 | 51 | Progress orientation |
| W01 artifact-loaded | Copy Markdown / Open / Section link toolbar | +3 | 54 | Power-user affordances |
| W01 artifact-loaded | Inline SVG figure | +5 | 59 | "Aha" — actual diagram, not ASCII |
| W01 artifact-loaded | Per-section hover Copy reveal | +4 | 63 | Felt-smart progressive disclosure |
| W01 copy-toast | Toast: "4.2 KB · 7 sections preserved" | +5 | 68 | Specific feedback signals competence |

#### Screen rollup

| Step | Screen | Previous | Δ | Cumulative | Severity | Top 2 Drivers |
|------|--------|----------|---|------------|----------|----------------|
| 1 | W01 default | 40 | +8 | 48 | OK | +5 (sidebar completeness), +2 (proactive Node hint) |
| 2 | W01 artifact-loaded | 48 | +15 | 63 | OK | +5 (inline SVG), +4 (per-section copy reveal) |
| 3 | W01 copy-toast | 63 | +5 | 68 | OK | +5 (specific toast feedback) |

### Journey J2 — file://-fallback cold-open (W02) — start: **Low-intent 25** (recipient just clicked a zip)

Sparkline: 25→33→31→28→29   ▃▆▅▂▃   (trending into Watch, recovers slightly)

#### Element table

| Screen | Element | ±Psych | Running | Notes |
|--------|---------|--------|---------|-------|
| W02 banner | Banner: badge + plain-language explanation | +3 | 28 | Expectation-setting reduces unknown costs |
| W02 banner | "What works / Degraded" capability table | +5 | 33 | Credibility signal: explicit about limits |
| W02 banner | Sidebar `↗` icons (4 items) | -2 | 31 | Question: what does the arrow mean? |
| W02 banner | "Run `node serve.js`" code chip | -3 | 28 | Question: do I have Node? Where is "this folder"? |
| W02 banner | Banner Dismiss + "Show banner again" | +1 | 29 | Reversibility |
| W02 links | "Show banner again" CTA | +0 | — | Neutral; not scored |

#### Screen rollup

| Step | Screen | Previous | Δ | Cumulative | Severity | Top 2 Drivers |
|------|--------|----------|---|------------|----------|----------------|
| 1 | W02 banner | 25 | +4 | 29 | **Watch** | +5 (capability table), -3 (Node CLI assumption) |
| 2 | W02 links | 29 | +0 | 29 | **Watch** | (banner dismissed; user navigates by clicking) |

W02 hovers at 29 — Watch territory but not bounce-risk. Two −Psych elements (`↗` opacity, Node CLI assumption) are addressable; see W1 + W5.

### Journey J3 — Mixed-state folder revisit (W03) — start: Medium 40

Sparkline: 40→43→43   ▁▃▃   (flat-positive)

#### Element table

| Screen | Element | ±Psych | Running | Notes |
|--------|---------|--------|---------|-------|
| W03 mixed-sidebar | Italic + `legacy .md` chip on legacy items | +3 | 43 | Credibility signal: explicit mixed-state |
| W03 mixed-sidebar | Mixed-state callout on active doc | +2 | 45 | Explains the mixed state in context |
| W03 mixed-sidebar | Group "Verify" with new HTML mixed in | +0 | — | Neutral |
| W03 legacy-open | Pre-rendered `<pre>` markdown source | -2 | 43 | Question: is this the rendered output or the source? |
| W03 legacy-open | "No Copy Markdown — already markdown" disclosure | +2 | 45 | Prevents broken-affordance frustration |

#### Screen rollup

| Step | Screen | Previous | Δ | Cumulative | Severity | Top 2 Drivers |
|------|--------|----------|---|------------|----------|----------------|
| 1 | W03 mixed-sidebar | 40 | +5 | 45 | OK | +3 (legacy chip clarity), +2 (callout) |
| 2 | W03 legacy-open | 45 | +0 | 45 | OK | +2 (disclosure), -2 (pre-rendered markdown reads as broken) |

### Journey J4 — Recipient quickstart first-open (W04) — start: **Low-intent 25**

Sparkline: 25→33→33   ▁▆▆   (positive arc; recipient gets oriented)

#### Element table

| Screen | Element | ±Psych | Running | Notes |
|--------|---------|--------|---------|-------|
| W04 first-open | 3-step quickstart card layout | +5 | 30 | Progressive disclosure tailored to cold-open |
| W04 first-open | Code chips (`node serve.js`, `index.html`) | +3 | 33 | Copy-pasteable; concrete |
| W04 first-open | Generated-by line + version | +0 | — | Neutral metadata |
| W04 first-open | "Got it" + "Don't show again" | +2 | 35 | Dismissibility, two-tier affordance |
| W04 first-open | "localStorage" hint in dismissed state | -1 | 34 | Jargon for non-engineer recipient |
| W04 dismissed | `? Quickstart` re-summon button | +1 | 35 | Reversibility |

#### Screen rollup

| Step | Screen | Previous | Δ | Cumulative | Severity | Top 2 Drivers |
|------|--------|----------|---|------------|----------|----------------|
| 1 | W04 first-open | 25 | +9 | 34 | OK | +5 (3-step card layout), +3 (concrete code chips) |
| 2 | W04 dismissed | 34 | +1 | 35 | OK | +1 (re-summon reversibility) |

W04 IS the recipient cold-open — it does the hard motivation work (lifting Low-intent 25 → 34) that everything else relies on.

---

## Section C — Recommendations

| ID | Severity | Recommendation | Affected | Effort |
|----|----------|----------------|----------|--------|
| W1 | **Should** | Replace bare `↗` icons in W02 sidebar with explicit hover `title="opens in new tab"` AND a visible secondary text hint at the top of the sidebar (e.g., "Click any artifact to open it in a new tab") so the recipient knows the affordance pattern before they click. | `02_index-file-fallback_desktop-web.html` | Low |
| W2 | **Should** | Add a prefix line inside the W03 `legacy-open` state's `<pre>` block — e.g., "Artifact predates the HTML migration; rendered as the original markdown source" — so the future-self reader knows the visual difference is intentional, not a render bug. | `03_index-mixed-state_desktop-web.html` | Low |
| W4 | Should | Disambiguate W01's `Search ⌘K` button: either drop it (out of scope for v1 viewer) or add a `wf-anno data-note` explaining it's a placeholder for future artifact-text search and surface as an Open Question for `/spec` to resolve. | `01_index-default_desktop-web.html` | Low |
| W5 | Nice | W02 banner: add a "Don't have Node?" tooltip / inline link on the `node serve.js` code chip pointing the recipient to W04's step 2 ("No Node? Open `index.html` directly"). Bridges the two journeys instead of treating them as independent. | `02_index-file-fallback_desktop-web.html` | Low |
| W6 | Nice | Show sidebar group counts (e.g., "Phase artifacts (4)", "Wireframes (4)") in all 4 wireframes so the recipient gets folder-shape orientation upfront — a small but cheap credibility signal. | All 4 files | Low |

**Deferred to /spec** (not applied here):
- **W3** — W04's first-open detection currently uses a localStorage flag (per the wf-anno note). LocalStorage is per-origin; cross-share via different paths/origins won't carry the seen-flag. Should be specced explicitly: hash-of-folder-path keyed flag, or accept the per-origin scoping as acceptable.

**Cross-cutting note (no recommendation, just a flag):** /msf-req's R3 (HTML structural validation in `/verify` smoke) becomes more important after these wireframes — the affordance patterns assume the LLM-authored HTML reliably produces the same `<button>`/`<aside>`/`<section>` structure. Worth restating in `/spec`.

---

## Section D — Applied changes

| Journey | Screen | Finding | Fix | Status |
|---------|--------|---------|-----|--------|
| J2 file://-fallback cold-open | W02 | W1 — bare `↗` opacity for non-developer recipient | Added `title="Opens in a new tab"` to all sidebar items and an above-sidebar hint line: "All artifacts open in new tabs (file:// limitation)." `aria-hidden="true"` on decorative arrows. | Applied |
| J3 mixed-state revisit | W03 | W2 — `<pre>` rendered markdown reads as broken | Added prefix line above `<pre>`: "Artifact predates the HTML migration; rendered as the original markdown source. Re-run the relevant skill to upgrade…" Removed the redundant bottom hint. | Applied |
| J1 default pipeline run | W01 | W4 — `Search ⌘K` non-functional stub | Added `wf-anno data-note` to the button explaining it's a placeholder for /spec; updated `aria-label` to mark "(placeholder for /spec)". Surfaces as an annotated review point. | Applied |
| J2 file://-fallback cold-open | W02 | W5 — bridge link from `node serve.js` chip to W04 step 2 | — | Skipped (Nice-tier; cross-doc affordance pattern needs /spec attention) |
| All journeys | W01–W04 | W6 — sidebar group counts for folder-shape orientation | — | Skipped (Nice-tier; multiplicative cost across 4 files) |

### Deferred / open

- **W3** (W04 first-open detection: localStorage scoping vs. folder-hash) — deferred to `/spec`. LocalStorage is per-origin; cross-share via different paths/origins won't carry the seen-flag. Spec must decide between hash-of-folder-path keying or accepting per-origin scoping as acceptable.

---

## Run summary

- **Findings raised:** 6 (W1–W6) + 1 deferred (W3)
- **Applied:** 3 (W1, W2, W4) — all Should-tier
- **Skipped:** 2 (W5, W6) — both Nice-tier per user disposition
- **Deferred to /spec:** 1 (W3)
- **Cumulative PSYCH outcome:** No bounce-risk, no cliff. W02 trended through Watch (29) but recovered post-banner; W04 lifts cold-open recipient from 25 → 35 doing the critical motivation work for the whole feature.
