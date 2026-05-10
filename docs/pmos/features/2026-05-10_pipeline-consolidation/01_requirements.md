# Pipeline Consolidation — Requirements

**Date:** 2026-05-10
**Last updated:** 2026-05-10
**Status:** Approved
**Tier:** 3 — Feature

## Problem

The pmos-toolkit pipeline has accumulated three pseudo-stages (`/msf-req`, `/msf-wf`, `/simulate-spec`) that are gated separately by `/feature-sdlc` even though each one only makes sense as a phase **inside** its parent (`/requirements`, `/wireframes`, `/spec`). The result is friction in three places:

- Pipeline authors duplicate decisions ("Tier 3 means run msf-req — but only if I remember to pick Run at the gate"). Tier-aware mandatoriness is not enforced; the user sees a Recommended-default and can silently skip something the tier explicitly requires.
- The two MSF skills both write to `msf-findings.md`, so a Tier-3 run that legitimately needs both produces a slug clash and one overwrites the other (or one renames-out-of-the-way and the linkage breaks).
- `--non-interactive` mode behaves inconsistently across pipeline skills: `/feature-sdlc` has a fully-specified canonical contract (the inlined `<!-- non-interactive-block:start -->` region, FR-01..FR-08, awk extractor, OQ schema), but most child skills either don't support the flag or implement open-questions emission ad-hoc, so a non-interactive pipeline run emits divergent OQ artifacts the orchestrator cannot reliably aggregate.

Separately, `/retro` only operates on the current session, so the user cannot answer questions like "how is `/spec` performing across the last 5 runs" or "what's recurring across the last two weeks of pipeline work" — which is exactly the lens that surfaces structural skill problems vs. one-off friction.

### Who experiences this?

- **Skill author / maintainer** running the pipeline end-to-end via `/feature-sdlc` to ship features and to dogfood the toolkit. They feel the gate-fatigue, the slug-clash recovery, and the inconsistent `--non-interactive` behavior whenever they automate or batch.
- **Toolkit owner** (same person, different hat) who wants empirical signal on which skills are mis-firing. They run `/retro` after sessions but cannot aggregate across sessions, so structural patterns hide behind single-session noise.

### Why now?

The html-artifacts feature (just shipped at v2.33.0) migrated all 10 pipeline skills to HTML-primary feature-folder artifacts via `_shared/html-authoring/`. Every pipeline SKILL.md was edited recently, the substrate is consolidated under `_shared/`, and the manifest version-sync invariants are well-tested. This is the cleanest moment to fold the three sub-skills into their parents — the substrate exists, the dispatch sites are recently audited, and the `_shared/non-interactive.md` canonical doc is in place but not yet uniformly inlined. Waiting risks divergence.

## Goals & Non-Goals

### Goals

Eight workstreams, each with an observable outcome:

- **G1 (W1 fold msf-req).** A Tier-3 `/requirements` run mandatorily executes the MSF-req friction analysis as an internal phase before handoff; a Tier-1 run skips it by default but can opt in. Observable: every Tier-3 `01_requirements.md` from this feature forward carries an MSF block (or links to a sidecar) without the user toggling a separate gate.
- **G2 (W2 fold msf-wf).** Same shape for `/wireframes` — Tier-3 mandatorily runs MSF-wf per wireframe; Tier-1 skips by default. Observable: every Tier-3 wireframes run produces both wireframe HTML and MSF-wf findings, in a single invocation.
- **G3 (W3 fold simulate-spec).** Tier-3 `/spec` mandatorily runs the simulate-spec scenario trace before declaring "Ready for Plan". Observable: every Tier-3 `02_spec.md` carries patches/decisions sourced from a simulate-spec trace as part of the same skill run.
- **G4 (W4 fix slug clash).** `/msf-req` and `/msf-wf` write to skill-distinct artifact slugs so a single feature folder can hold both without overwrite. Observable: `ls <feature_folder>` after a Tier-3 run shows distinctly-named artifacts (e.g. `msf-req-findings.md` and `msf-wf-findings/`) — measured by zero filename collisions in test fixtures.
- **G5 (W5 update /feature-sdlc).** The orchestrator pipeline removes the now-redundant Phase 4.a (msf-req gate) and Phase 6 (simulate-spec gate); the msf-wf reference under Phase 4.c becomes internal to `/wireframes`; `/retro` is added as the final optional Phase 13. Observable: `/feature-sdlc` Tier-3 dry-run prompts the user at exactly 4 soft gates (creativity, wireframes, prototype, retro) — measured against the current 7.
- **G6 (W6 standardize OQ format).** Every pipeline skill that supports `--non-interactive` inlines the canonical block from `_shared/non-interactive.md` byte-identical, and `tools/lint-non-interactive-inline.sh` passes for every such skill. Observable: greenfield CI-style lint run reports zero divergence — measured by the lint script exiting 0 across the pipeline-skill set.
- **G7 (W7 fold /retro into pipeline).** `/feature-sdlc` ends with an explicit `/retro` gate (Skip recommended, Run / Defer available). Observable: every `/feature-sdlc` run emits a final-phase decision row in `00_pipeline.html` reflecting the user's retro choice.
- **G8 (W8 multi-session retro).** `/retro` accepts `--last N`, `--days N`, `--since YYYY-MM-DD`, `--project current|all`, `--skill <name>`. In multi-session mode it dispatches one subagent per transcript file and aggregates findings into recurring-pattern + unique-but-notable buckets. Observable: a user running `/retro --last 5 --skill spec` gets a frequency-weighted findings report covering 5 sessions without the parent agent reading transcripts directly.

### Non-Goals (explicit scope cuts)

- **NOT retiring** the standalone `/msf-req`, `/msf-wf`, or `/simulate-spec` slash commands — because users still need ad-hoc invocation against legacy docs and external artifacts (e.g. running MSF on a wireframe file someone else produced). Backwards-compat is mandatory.
- **NOT cross-referencing** /retro findings against the current skill body (the "did the prose fix actually change behavior" loop the brief floats) — because the user explicitly scoped that out at the gate; revisit in a later feature.
- **NOT changing** the pipeline order beyond removing redundant gates — because the requirements → spec → plan → execute → verify → complete-dev sequence is load-bearing; only the soft optional gates between them are touched.
- **NOT re-authoring** the canonical non-interactive contract — because `_shared/non-interactive.md` is the source of truth from html-artifacts; this feature inlines it across more skills, it doesn't redesign it.
- **NOT introducing** a new artifact format or HTML substrate — because the html-artifacts substrate is fresh; folded phases reuse it.
- **NOT supporting** in-place skill-version migration of old MSF artifacts at `msf-findings.md` — because the existing artifacts are read-only deliverables; a one-time read-only fallback in `/verify` covers backwards-compat without write-side complexity.

## User Experience Analysis

### Motivation

- **Job to be done:**
  - *(Pipeline runs)* Ship a feature end-to-end through the toolkit with the Tier-appropriate level of rigor — without the user manually remembering which optional sub-skills are "actually mandatory at Tier 3".
  - *(Retro)* Diagnose recurring problems in the toolkit itself by aggregating signals across many sessions, not just the one that just happened.
- **Importance / urgency:** High but not blocking. Pipeline runs work today; the friction is gate-fatigue and the slug-clash bug. Multi-session retro is a capability gap, not a regression. Importance comes from compound effect — the user runs the pipeline daily, so each saved gate removes O(daily) friction.
- **Alternatives the user considered:**
  - Memorize which gates are "actually mandatory" per tier (current state — fragile).
  - Always pick Run at every gate (over-runs at Tier 1, wasted time).
  - Use `--non-interactive` and let it Recommended-default (works for the gates, but breaks because OQ emission is non-uniform across child skills).
  - For retro: run `/retro` per-session and visually diff outputs (doesn't scale past 2 sessions).

### Friction Points

| Friction Point | Cause | Mitigation |
|---|---|---|
| User unsure if Tier-3 needs MSF-req at every run | Recommended-default at the gate is "Run" but skipping is silent; tier-mandatoriness is convention not enforcement | Move MSF-req inside `/requirements`; Tier-3 makes it mandatory phase, not a gate the user can mis-skip |
| Slug clash overwrites msf-findings.md when both MSF skills run | Both skills write to the same artifact slug | Distinct skill-name slugs (`msf-req-findings.md`, `msf-wf-findings/`); `/verify` reads both old + new locations during transition |
| `--non-interactive` produces divergent OQ artifacts | Each child skill emits OQ ad-hoc; only `/feature-sdlc` has the canonical block | Inline the canonical block in every pipeline skill; lint enforces byte-identity |
| `/retro` only sees this session | Single-jsonl scope; volume + context budget makes parent-direct multi-read infeasible | Subagent-per-transcript dispatch; parent only sees structured findings |
| Recurring pattern hidden behind single-session noise | No frequency weighting | Aggregate by `(skill, finding-hash)`; report frequency × severity |
| Skill version drift between old transcripts and current skill body | A 30-day-old finding may target prose the author already fixed | Tag every aggregated finding with `seen across <session-dates>` so the author can disregard pre-revision findings |

### Satisfaction Signals

- A Tier-3 `/feature-sdlc` run prompts the user at 4 gates instead of 7 (creativity / wireframes / prototype / retro), and those that remain are genuinely-optional.
- `/retro --last 5` produces a single report ranked by frequency, with the highest-recurrence findings at the top.
- Running `/feature-sdlc --non-interactive` against a fixture produces uniform `## Open Questions (Non-Interactive Run)` sections in every child artifact, with byte-identical contract text.
- `/verify` of an existing feature folder containing `msf-findings.md` (legacy slug) does not error — it reads both legacy and new slugs during the transition window.

## Solution Direction

The pipeline becomes:

```
/feature-sdlc
  └─> /requirements
        ├─ Phase 2 research
        ├─ Phase 3 brainstorm
        ├─ Phase 4 write
        ├─ Phase 5 review loops
        ├─ Phase 5.5 [folded] /msf-req      # Tier 3 mandatory; Tier 1/2 optional
        └─ Phase 7 capture-learnings
  └─> [/grill]                               # unchanged soft gate
  └─> [/creativity]                          # unchanged soft gate
  └─> [/wireframes]                          # unchanged soft gate (frontend heuristic)
        ├─ Phase 1..N existing wireframes phases
        └─ Phase N+1 [folded] /msf-wf        # Tier 3 mandatory; Tier 1/2 optional
  └─> [/prototype]                           # unchanged soft gate
  └─> /spec
        ├─ Phase 1..N existing spec phases
        ├─ Phase N+1 [folded] /simulate-spec # Tier 3 mandatory; Tier 1/2 optional
        └─ Phase final review/handoff
  └─> /plan                                  # unchanged
  └─> /execute                               # unchanged
  └─> /verify                                # unchanged (reads both old + new MSF slugs)
  └─> /complete-dev                          # unchanged
  └─> [/retro]                               # NEW final soft gate (Skip recommended)
```

### Per-workstream direction

**W1 — Fold /msf-req into /requirements.**
- After `/requirements` Phase 5 (review loops) completes and the doc is committed, dispatch a folded Phase 5.5 that runs the MSF-req logic inline against the just-written `01_requirements.md`.
- Tier gate: Tier 3 → mandatory (no user prompt; runs every time). Tier 2 → soft `AskUserQuestion` with Recommended=Run. Tier 1 → soft with Recommended=Skip.
- **`--skip-folded-msf` escape hatch:** the user can pass `--skip-folded-msf` to `/requirements` to bypass even the Tier-3 mandatory case (e.g., purely-backend feature with no UX surface). Always logged to `state.yaml.phases.requirements.notes` when running under `/feature-sdlc`.
- **Findings handling:** mirrors the /msf-wf-folded-into-/wireframes precedent from html-artifacts — high-confidence findings (e.g. confidence ≥80) are auto-applied to the doc with a Review-Log row noting the auto-apply; remaining findings are surfaced inline via `AskUserQuestion` for Fix/Modify/Skip/Defer disposition just like a review-loop. Folded MSF is NOT a silent advisory pass.
- **Atomicity (D16):** each auto-apply lands as its own git commit on the feature branch (`requirements: auto-apply msf-req finding F<n> (confidence <pct>)`); crash leaves last-good HEAD intact. Undo via `git revert <sha>`.
- **Non-interactive disposition (D14 refinement):** inline `AskUserQuestion` for sub-threshold findings carries Recommended=Defer; classifier AUTO-PICKs Defer in `--non-interactive`; FR-03 emits to OQ artifact so the doc is never silently mutated under NI mode.
- Standalone `/msf-req` slash command stays invokable; the folded path and the standalone path both call into shared logic in `_shared/msf-heuristics.md` (already exists).
- Output goes to a slug-distinct artifact (see W4).

**W2 — Fold /msf-wf into /wireframes.**
- Same shape; folded as a phase after wireframes are generated. Per-wireframe iteration retained (the existing standalone `/msf-wf` iterates per wireframe).
- Tier gate: same matrix as W1. Same `--skip-folded-msf` escape (renamed to `--skip-folded-msf-wf` if both flags are needed at `/wireframes`; final naming pinned in `/spec`).
- Findings handling: same auto-apply-high-confidence + inline-disposition model as W1. This already exists in /msf-wf's standalone path per the html-artifacts run; folded path reuses it.
- Atomicity (D16) + non-interactive disposition (D14 refinement) apply identically to W1.
- Standalone `/msf-wf` retained. Shared logic via `_shared/msf-heuristics.md`.

**W3 — Fold /simulate-spec into /spec.**
- Folded as a phase between `/spec`'s existing review loops and the "Ready for Plan" handoff. Patches surfaced by simulate-spec are applied to the spec doc inline (matching the standalone behavior).
- Tier gate: Tier 3 default-on; Tier 2 soft with Recommended=Run; Tier 1 soft with Recommended=Skip. (Wording aligned with D2 Loop-2 rewording.)
- **`--skip-folded-sim-spec` escape hatch (D15):** mirrors D13; the user can pass `--skip-folded-sim-spec` to `/spec` to bypass even the Tier-3 default-on case (e.g., infra refactor with no scenario surface). Logged to `state.yaml.phases.spec.notes` when running under `/feature-sdlc`.
- Atomicity (D16) applies: each simulate-spec patch landing on `02_spec.md` is its own commit (`spec: auto-apply simulate-spec patch P<n>`), so crash mid-batch is recoverable.
- Standalone `/simulate-spec` retained for cases where the user wants to pressure-test a spec produced outside the pipeline.

**W4 — Slug clash fix.**
- Naming convention: `<skill-name-slug>-findings.<ext>`. So `msf-req-findings.md` (single-doc) and `msf-wf-findings/` (per-wireframe directory). Generalizes to future MSF-* skills.
- Backwards-compat: `/verify` and downstream readers fall back to the legacy `msf-findings.md` path if no new-slug artifact is found, with a soft warning logged. New writes always use the new slug.
- One-pass migration script is not required — the legacy slug is read-only fallback; pre-existing artifacts in past feature folders stay where they are.

**W5 — Update /feature-sdlc.**
- Remove Phase 4.a (msf-req gate) and Phase 6 (simulate-spec gate) from the orchestrator's phase list.
- Phase 4.c (wireframes gate) stays; the msf-wf reference inside it is dropped because msf-wf is now internal to `/wireframes`.
- Add Phase 13 (retro gate) — soft, Recommended=Skip. The OQ-index emission in Phase 11 already covers the artifact contract.
- `state.yaml.phases[]` schema gains a `retro` entry; Phase 0.b resume-detection is unchanged otherwise.
- **Folded-phase failure surfacing (D17):** `state.yaml.phases.<parent>.folded_phase_failures[]` carries structured records `{folded_skill, error_excerpt, ts}`; `/feature-sdlc` Phase 11 emits a "Folded-phase failures" subsection above the OQ index when any are recorded; mirrored to chat at end-of-run; re-printed on `--resume`.
- Anti-pattern #4 in `/feature-sdlc` ("Auto-running optional stages without the gate") is updated to remove the now-folded skills from the list and add `/retro`.

**W6 — Standardize --non-interactive across pipeline.**
- Source of truth: `_shared/non-interactive.md` (canonical text) + the inlined block in `/feature-sdlc/SKILL.md` (the audited byte-identical region between `<!-- non-interactive-block:start -->` and `<!-- non-interactive-block:end -->`).
- Rollout target set: every pipeline skill that **currently supports** `--non-interactive`. The exact list is produced by `/spec` via an audit pass (grep each pipeline SKILL.md for the `<!-- non-interactive-block:start -->` marker AND for `--non-interactive` argument parsing). Skills that don't currently parse the flag are out of scope for this feature; adding new flag-handling is a follow-up.
- Each target SKILL.md gets the canonical block inlined. `tools/lint-non-interactive-inline.sh` enforces byte-identity in CI; new failures block the pre-push hook.
- Open-questions emission per skill follows FR-03 in the canonical block (single-MD primary → append section; multi-artifact → `_open_questions.md` aggregator; non-MD primary → sidecar; chat-only → stderr block). Skills that produce HTML-primary artifacts use the sidecar path with HTML-aware naming (`<artifact>.open-questions.md` for HTML, MD-side companion).

**W7 — Fold /retro into /feature-sdlc.**
- New Phase 13 in `/feature-sdlc/SKILL.md`, soft, with `AskUserQuestion`:
  ```
  question: "Run /retro to capture session learnings before exiting?"
  options:
    - Skip (Recommended)
    - Run /retro
    - Defer
  ```
- On Run: dispatch `/retro` with `[mode: <current-mode>]` prefix; capture artifact path into `state.yaml.phases.retro.artifact_path`.
- On Defer: log to `open_questions_log[]` and surface in the final Phase 11 summary.
- Standalone `/retro` retained.

**W8 — /retro multi-session enhancement.**
- New flags: `--last N`, `--days N`, `--since YYYY-MM-DD`, `--project current|all`, `--skill <name>`. Mutually-exclusive selectors are validated; default remains current session.
- Phase 1 (existing) extends to enumerate candidate transcripts when a multi-session selector is present. The user sees `(date, size, skill-invocation-count, project-slug)` rows and confirms scope before scan begins.
- **Subagent count cap (D18):** if candidate-transcript count > 20, Phase 1 surfaces `AskUserQuestion` (scan all / scan most-recent-20 / cancel). In `--non-interactive`, Recommended=most-recent-20 → AUTO-PICK. Concurrency 5 in-flight regardless of total.
- Phase 2 dispatches one subagent per transcript jsonl, batched 5 in-flight. Each subagent extracts only `(skill-invocation, ±N surrounding turns)` slices, returns a structured findings list per the existing /retro output schema. Parent aggregates without re-reading transcripts.
- Aggregation: `(skill, severity, first-100-chars-of-finding)` hash for fuzzy dedup, **with boilerplate prefix-stripping** (`The /<skill> skill`, `The skill`, etc.) before hashing to avoid collapsing genuinely-different findings sharing lead-ins; `(skill, finding-hash)` for count + sessions-seen-in. **Constituent raw findings are emitted as a nested sub-list under each aggregated row** so the reader can sanity-check the merge (D10 refinement).
- Phase 5 (output) emits two tiers in this order: (a) **Recurring patterns** — findings appearing in ≥2 sessions, sorted by `frequency × severity`; (b) **Unique-but-notable** — single-session findings still worth keeping.
- Each aggregated finding carries `seen across <session-dates>` so the author can spot pre-revision findings.
- Cross-project (`--project all`) iterates `~/.claude-personal/projects/*/`.

## User Journeys

### Primary Journey — Tier-3 feature run via /feature-sdlc

1. User invokes `/feature-sdlc <idea>` and confirms slug + Tier 3.
2. Orchestrator creates worktree + branch + state.yaml; dispatches `/requirements`.
3. `/requirements` runs Phases 0..4 unchanged; in Phase 5 the user iterates review loops; **Phase 5.5 (folded MSF-req) runs automatically — no gate** because Tier 3 is mandatory; emits `msf-req-findings.md`.
4. Orchestrator dispatches `/grill`, `/creativity` (gates as today), then `/wireframes` (frontend-heuristic gate).
5. If wireframes runs, **MSF-wf is folded as an internal phase — no separate gate**; emits `msf-wf-findings/<wireframe-id>.md` per wireframe.
6. Optional `/prototype` gate.
7. `/spec` runs Phases 1..N; **simulate-spec is folded as an internal phase — no separate gate**; patches applied inline; spec marked Ready for Plan.
8. `/plan` → `/execute` → `/verify` → `/complete-dev` unchanged.
9. **Phase 13 prompts:** "Run /retro?" — user picks Skip (Recommended) or Run.
10. Orchestrator emits `00_pipeline.html` final-state and exits.

### Alternate Journey — Tier-1 bug fix via /feature-sdlc

- Same flow but: MSF-req gate appears as soft `AskUserQuestion` Recommended=Skip; MSF-wf and simulate-spec gates likewise; `/retro` gate likewise. The user can opt in case-by-case.

### Alternate Journey — Standalone ad-hoc /msf-req on a legacy doc

- User invokes `/msf-req docs/old-feature/01_requirements.md` directly (not via pipeline).
- Skill runs in standalone mode, writes `msf-req-findings.md` next to the input doc (same slug rule applies).

### Alternate Journey — Multi-session /retro

1. User invokes `/retro --last 5 --skill spec`.
2. Phase 1 enumerates the 5 most recent jsonls; surfaces `(date, size, /spec-invocations, project-slug)`; user confirms.
3. Phase 2 dispatches 5 subagents (one per jsonl) in parallel; each returns structured findings.
4. Parent aggregates; emits two-tier report (recurring patterns first, unique-but-notable second).
5. User reads report; chooses to convert specific findings to skill-feedback paste-back blocks via the existing /retro paste-back protocol.

### Error Journeys

- **`/retro --last 5` requested but only 2 jsonls exist:** soft warning ("only 2 sessions found"), proceed with what's available.
- **Subagent fails on a transcript jsonl:** mark as scanned-failed in the report, continue with remaining transcripts; final report notes the partial coverage.
- **Slug-clash legacy artifact at `msf-findings.md` exists in a feature folder being re-run:** new write goes to `msf-req-findings.md` or `msf-wf-findings/`; legacy file is preserved on disk; `/verify` reads the new slug primarily and falls back to legacy with a soft warning.
- **`--non-interactive` run encounters a defer-only checkpoint in a child skill:** child writes the open-question to its skill-specific OQ artifact (per FR-03); orchestrator aggregates into `00_open_questions_index.html`; pipeline does NOT block.

### Empty States & Edge Cases

| Scenario | Condition | Expected Behavior |
|---|---|---|
| No msf-req-findings.md at /verify time on a Tier-3 feature | folded MSF-req failed silently OR was skipped at Tier-1/2 OR `--skip-folded-msf` was passed | `/verify` checks tier from `02_spec.md` frontmatter and reads `state.yaml.phases.requirements.folded_phase_failures[]` + `notes`; **at Tier 3 → warn loudly but advisory** (matches D2 "default-on" + D11 advisory-on-failure); at Tier 1/2 → advisory only. Blocking only if `state.yaml` shows neither a documented skip nor a recorded failure for the missing artifact |
| --last 0 or --days 0 | edge value | error with usage hint, exit 64 |
| --since with future date | invalid | error with usage hint, exit 64 |
| --project all on machine with 1 project | trivial case | works, single subagent, equivalent to --project current |
| Pipeline skill with --non-interactive flag but pre-rollout (canonical block missing) | post-rollout BC | already covered by FR-08 in the canonical block; falls back to interactive with stderr warning |
| /retro folded gate with no jsonl available (fresh project) | first-ever session | gate appears; if user picks Run, /retro emits "no transcripts found yet" and exits cleanly |

## Design Decisions

| # | Decision | Options Considered | Rationale |
|---|---|---|---|
| D1 | Keep standalone /msf-req, /msf-wf, /simulate-spec slash commands AND fold as phases | (a) Fully retire the standalones (b) Retire only /simulate-spec (c) Keep all three standalones + fold | (c) — backwards-compat for ad-hoc invocation against legacy docs is required; the marginal cost of keeping the standalones is one shared-logic doc each, which the html-artifacts feature already established as a pattern (`_shared/`); user explicitly chose this at the orchestrator gate |
| D2 | MSF folding triggers per Tier — Tier 3 **default-on** (no gate, but `--skip-folded-msf` and advisory-on-failure both apply per D11/D13), Tier 1/2 soft gate | (a) Always-mandatory at all tiers (b) Always-soft-gated at all tiers (c) Tier-keyed default-on with explicit escape | (c) — Tier 1 (bug fix) does not warrant MSF rigor; Tier 3 (feature) does; Tier 2 should be opt-in with Recommended=Run. Eliminates the gate-fatigue at Tier 3 while preserving lightweight Tier 1. **Reworded "mandatory" → "default-on" (Loop-2):** the word "mandatory" implied a contract D11 + D13 explicitly weaken (advisory-on-failure + opt-out flag); "default-on" describes what the pipeline actually does without overpromising |
| D3 | Slug naming: `<skill-name-slug>-findings.<ext>` | (a) `msf-findings-<skill>.<ext>` (b) Subdirectory `msf-findings/<skill>.<ext>` (c) `<skill-name-slug>-findings.<ext>` | (c) — generalizes to future MSF-* and any other slug-prone skill; reads naturally; sortable; collision-free |
| D4 | Backwards-compat: read-only fallback to legacy `msf-findings.md` in /verify; new writes always use new slug | (a) Migration script (b) Read-only fallback (c) Hard cutover | (b) — past feature folders are deliverables, not live state; a one-line read-fallback in /verify covers the transition cost without write-side complexity or risk |
| D5 | --non-interactive canonical source: keep `/feature-sdlc`'s inlined block as the audited reference; lint enforces inlining byte-identity | (a) Move canonical to `_shared/non-interactive.md` only and have skills reference it (b) Inline byte-identical via lint (c) Macro-substitute at build time | (b) — matches html-artifacts precedent (Pipeline-Setup block, Awk extractor) where lint enforces inlined identity. No build step required; SKILL.md remains directly readable; tools/audit-recommended.sh already greps for the inlined region |
| D6 | /retro folded as final Phase 13 (after /complete-dev), Recommended=Skip | (a) Recommended=Run (b) No gate, mandatory (c) Soft gate, Recommended=Skip | (c) — /retro is reflective work; making it mandatory adds friction for routine runs. Skip-recommended encourages opt-in only when the run actually felt rough. User explicitly aligned at gate |
| D7 | /retro multi-session: subagent-per-transcript dispatch (one per jsonl) | (a) Parent reads all jsonls directly (b) Single subagent reads all (c) One subagent per jsonl, parallel | (c) — context budget makes (a) infeasible past 2-3 sessions; (b) loses the per-session parallelism; (c) scales linearly with sessions and lets each subagent stream-extract only the slice it needs. User explicitly aligned at gate |
| D8 | Cross-project retro via --project all iterates `~/.claude-personal/projects/*/` | (a) Per-project only (b) Cross-project flag (c) Always cross-project | (b) — explicit opt-in matches user intent ("how is /spec performing across all my projects?") without surprising single-project users with cross-project noise. User explicitly aligned at gate |
| D9 | NOT cross-referencing /retro findings against current skill body | (a) Include cross-ref (b) Exclude | (b) — user explicitly scoped out at the orchestrator gate; the cross-ref is high-signal but high-complexity; deferred to a future feature once multi-session aggregation is proven |
| D10 | Aggregation hash: `(skill, severity, first-100-chars-of-finding-with-boilerplate-stripped)` for dedup; `(skill, finding-hash)` for count; **constituent raw findings emitted as a nested sub-list beneath each aggregated row** | (a) Exact-string match (b) Levenshtein fuzzy match (c) Truncated-prefix hash | (c) — exact-string under-clusters; full fuzzy match is complex and needs tuning; truncated-prefix is good-enough per the brief. **Loop-2 refinement:** strip boilerplate prefixes (`The /<skill> skill`, `The skill`, etc.) BEFORE the first-100 hash to avoid collapsing genuinely-different findings that share lead-ins; emit constituents as a nested sub-list under each aggregated row so the reader can sanity-check the merge instead of having merges happen invisibly upstream of human review |
| D11 | Folded-phase failure semantics — soft (logs, doesn't block) at all tiers OR fail-stop at Tier 3? | (a) Always advisory (b) Always blocking (c) Tier-keyed | (a) — folded phases are quality gates not invariant gates; if MSF-req crashes, the requirements doc itself is still valid; downstream `/spec` can proceed. Tier 3 just gets a louder warning in the OQ index. Pipeline halts only on hard-phase failure (`/requirements` itself, `/spec` itself, etc.) |
| D12 | Where the "tier" lives that drives folded-phase decisions inside child skills | (a) Re-derive from doc frontmatter at every entry (b) Read from `state.yaml` (c) Pass via prompt | (a) — child skills must remain invokable standalone; reading their own input doc's tier line is the single authoritative source. Orchestrator-derived tier is informational only; child skills enforce their own. **Parsing rule (pinned for /spec):** regex `^\*\*Tier:\*\* ([0-9]+)` against the doc's first 20 lines (matches the existing `**Tier:** 3 — Feature` header convention used by /requirements/spec/plan templates) |
| D13 | `--skip-folded-msf` escape hatch for purely-backend Tier 3 features | (a) No escape — Tier 3 always runs MSF (b) Non-Goal carve-out only (c) Explicit `--skip-folded-msf` flag | (c) — purely-backend Tier 3 features (e.g., infra refactors) get no signal from a UX-friction skill; forcing the run is noise. Flag is opt-out, not opt-in; logged to `state.yaml.phases.<parent>.notes` when running under `/feature-sdlc` so the choice is auditable |
| D14 | Folded MSF findings handling: auto-apply high-confidence + inline disposition for the rest; **`--non-interactive` Recommended=Defer for sub-threshold findings** | (a) Advisory-only (write findings, don't block) (b) Auto-apply all (c) Auto-apply high-confidence + inline disposition for rest | (c) — matches /msf-wf-folded-into-/wireframes precedent from html-artifacts (where /msf-wf delegated and applied 3 of 6 findings inline). Auto-apply threshold defaults to confidence ≥80 (pinned in /spec). Remaining findings get the same Fix/Modify/Skip/Defer disposition as review-loop findings. **Loop-2 refinement:** under `--non-interactive`, the inline `AskUserQuestion` for sub-threshold findings carries Recommended=Defer; classifier AUTO-PICKs Defer; FR-03 emits the deferred entry to the OQ artifact so non-interactive runs never silently mutate the doc |
| D15 | `--skip-folded-sim-spec` escape hatch on `/spec`, mirroring D13 | (a) No escape (asymmetric) (b) Carve-out via Non-Goal (c) Explicit `--skip-folded-sim-spec` flag | (c) — purely-backend Tier 3 features (e.g., infra refactors) get no signal from a scenario-trace skill any more than they do from a UX-friction skill. Asymmetric escape (only on MSF) was indefensible. Flag mirrors D13 shape; logged to `state.yaml.phases.spec.notes` when running under `/feature-sdlc`. Added in Loop 2 |
| D16 | Auto-apply atomicity: per-finding git commits with last-good rollback | (a) Single end-of-phase atomic commit (b) Per-finding commits + last-good rollback (c) No commits during folded phase (manual commit by user) | (b) — per-finding granularity makes `git revert <sha>` a clean undo path; matches html-artifacts /msf-wf precedent (each finding-application observable in `git log`). Crash mid-batch leaves last-good HEAD intact; next applied finding starts from there. Commit message convention: `<parent>: auto-apply <folded-skill> finding F<n> (confidence <pct>)`. Added in Loop 2 |
| D17 | Folded-phase failure surfacing: distinct Phase-11 subsection + chat surface; `state.yaml.phases.<parent>.folded_phase_failures[]` structured record | (a) Folded into ordinary OQ entries (b) Distinct Phase-11 subsection + chat (c) Tier-keyed verbosity | (b) — without a dedicated surface, advisory-on-failure (D11) means a Tier-3 MSF crash gets buried inside the OQ index and the user might not notice until /verify. Phase 11 emits a "Folded-phase failures" subsection above the OQ index, mirrored to chat; structured record in state.yaml lets `--resume` re-print it. Added in Loop 2 |
| D18 | Multi-session retro subagent count: hard cap N=20 with confirmation prompt above; concurrency 5 in-flight | (a) Soft cap N=10 with auto-truncate (b) No cap, batched waves (c) Hard cap N=20 + confirmation above | (c) — `--last 50` and `--project all` on a multi-project corpus could otherwise spawn 100+ subagents; predictable resource ceiling matters. Above 20 candidates, /retro Phase 1 surfaces an `AskUserQuestion` (scan all / scan most-recent-20 / cancel). 5 in-flight matches typical harness concurrency; honors user's selector when explicitly opted in. Added in Loop 2 |

## Success Metrics

| Metric | Baseline (today) | Target (after ship) | Measurement |
|---|---|---|---|
| Soft gates presented in a Tier-3 `/feature-sdlc` run | 7 (msf-req, creativity, wireframes, msf-wf-as-part-of-wf, prototype, simulate-spec, retro-isn't-yet-folded) | 4 (creativity, wireframes, prototype, retro) | Count `AskUserQuestion` calls in a fixture run |
| Slug clashes per Tier-3 run that triggers both MSF skills | 1 (deterministic — overwrite or rename collision) | 0 | Run T3 fixture; assert distinct artifact paths |
| Pipeline-skill SKILL.md files with inlined canonical non-interactive block | 1 (only /feature-sdlc) | All target skills (estimated 12-14) | `lint-non-interactive-inline.sh` exit 0 across set |
| /retro multi-session capability | None (single-session only) | --last/--days/--since + --project all + per-skill filter | Run `/retro --last 5` against a fixture with 5+ jsonls; assert aggregated report |
| /verify backwards-compat read of legacy msf-findings.md slug | Untested | Pass | Fixture with legacy artifact path; /verify exit 0 with advisory |
| Feature-folder OQ artifact uniformity in --non-interactive run | Divergent (per-skill ad-hoc) | Uniform (FR-03 contract) | Run `/feature-sdlc --non-interactive` against fixture; diff OQ artifact structure across child skills |
| Folded-phase failures surfaced in /feature-sdlc Phase-11 final summary | Not surfaced (buried in OQ index) | Distinct subsection above OQ index, mirrored to chat | Inject a fixture folded-phase crash; assert Phase-11 chat output contains the "Folded-phase failures" subsection and `state.yaml.phases.<parent>.folded_phase_failures[]` is populated |

## Research Sources

| Source | Type | Key Takeaway |
|---|---|---|
| `plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md` | Existing code | Canonical `<!-- non-interactive-block:start -->` region is byte-audited via `tools/audit-recommended.sh`; lint precedent for byte-identity exists |
| `plugins/pmos-toolkit/skills/_shared/non-interactive.md` | Existing code | Canonical contract source; FR-01..FR-08; awk extractor; this is the doc to inline |
| `plugins/pmos-toolkit/skills/_shared/msf-heuristics.md` | Existing code | Shared MSF logic substrate already exists — both standalone and folded paths can call into it |
| `plugins/pmos-toolkit/tools/lint-non-interactive-inline.sh` | Existing code | Lint already exists for inlined non-interactive block; extend to cover the wider rollout set |
| `plugins/pmos-toolkit/tools/audit-recommended.sh` | Existing code | Greps for the inlined region; uses awk extractor; classifies AskUserQuestion calls |
| `plugins/pmos-toolkit/skills/msf-req/SKILL.md` and `msf-wf/SKILL.md` | Existing code | Both currently write to `msf-findings.md` slug — confirms the clash |
| `plugins/pmos-toolkit/skills/retro/SKILL.md` | Existing code | Single-session structure; Phase 1 = enumerate, Phase 2 = scan, Phase 5 = emit. Multi-session enhancement extends Phase 1 + Phase 2 |
| `~/.claude-personal/projects/<slug>/*.jsonl` | Filesystem convention | Per-project, sortable by mtime, append-only, self-contained per session — confirms multi-session scan tractability |
| html-artifacts feature (just shipped at v2.33.0) | Recent commit history | Established the precedent for `_shared/` substrate + lint-enforced inlining; FR-50/50.1/52 chrome-strip pattern is a structurally-similar fold |
| `plugins/pmos-toolkit/skills/spec/SKILL.md` | Existing code | Has a "Ready for Plan" handoff that's the natural insertion point for folded simulate-spec phase |
| `CLAUDE.md` | Project invariants | Canonical skill path is `plugins/pmos-toolkit/skills/<name>/SKILL.md`; manifest version-sync is enforced by pre-push hook; minor bump required for this feature |

## Open Questions

| # | Question |
|---|---|
| 1 | Folded simulate-spec at Tier 3: how many scenarios is the right floor? Standalone /simulate-spec runs ~28 scenarios for a Tier-3 spec (per html-artifacts evidence). Folded version should match or be tunable — confirm in `/spec`. |
| 2 | OQ aggregator filename when a child skill produces multiple artifacts: spec says `_open_questions.md`. Should the orchestrator's aggregation in `00_open_questions_index.html` (Phase 11) read these MD aggregators directly, or require a sidecar HTML version? Default: read MD aggregators; orchestrator's index is HTML and renders MD via the html-authoring substrate. Confirm in `/spec`. |
| 3 | /retro multi-session subagent failure: if 1 of 5 subagents errors, do we ship a partial report (with "1 session unscanned" notice) or block? Default: partial-report-with-notice. Confirm in `/spec`. |
| 4 | Cross-project retro permissions: `~/.claude-personal/projects/*/` may contain projects the user has since archived/abandoned. Should `--project all` filter by recent-mtime threshold (e.g. last 90 days) by default? Default: no filter; explicit --since for that. Confirm in `/spec`. |
| 5 | Tier-keyed mandatoriness inside folded phases: a Tier-2 `/requirements` run with the user picking Skip at the soft MSF-req gate — does that selection get logged anywhere observable, or is it ephemeral? Default: log to `state.yaml.phases.requirements.notes` if running under `/feature-sdlc`; ephemeral if standalone. Confirm in `/spec`. |
| 6 | D14 auto-apply confidence threshold: defaults to ≥80 by analogy with html-artifacts /msf-wf precedent. Should this be tunable per tier (e.g. ≥90 at Tier 1, ≥80 at Tier 3)? Confirm in `/spec`. |
| 7 | `--skip-folded-msf` flag naming: single flag covering both /requirements (msf-req) and /wireframes (msf-wf), or split into `--skip-folded-msf-req` / `--skip-folded-msf-wf`? Default: split. Confirm in `/spec`. |

## Review Log

| Loop | Findings | Changes Made |
|---|---|---|
| 1 | F1 [D12 tier-parsing rule ambiguous]; F2 [folded-MSF findings disposition unspecified]; F3 [no escape for backend Tier 3]; F4 [W6 rollout list speculative] | F1 fix-as-proposed → D12 carries explicit regex parsing rule. F2 modified per user → D14 added (auto-apply high-confidence + inline disposition); W1 + W2 Solution Direction sub-bullets updated. F3 fix-as-proposed → D13 added (`--skip-folded-msf` flag); W1 sub-bullet added. F4 fix-as-proposed → W6 reframed (target set produced by /spec audit pass, not asserted here). OQ-1 retired (resolved by D14); 2 new OQs added (D14 threshold tunability; flag naming). |
| 2 (grill) | G1 ["mandatory" wording overpromises given D11+D13]; G2 [W3/D13 escape-hatch asymmetry]; G3 [D14 auto-apply atomicity + undo unspecified]; G4 [D14 in `--non-interactive` underspecified]; G5 [D11 silent-failure observability gap]; G6 [/retro subagent count uncapped]; G7 [D10 boilerplate-lead-in collisions] | G1 → reword D2 "mandatory" → "default-on at Tier 3"; soften /verify edge-case row to warn-not-block. G2 → add D15 (`--skip-folded-sim-spec`); W3 sub-bullet added. G3 → add D16 (per-finding commits + last-good rollback); W1/W2/W3 sub-bullets added. G4 → update D14 with NI Recommended=Defer; W1/W2 sub-bullets added. G5 → add D17 (Phase-11 subsection + `state.yaml.phases.<parent>.folded_phase_failures[]`); W5 sub-bullet added; success metric row added. G6 → add D18 (hard cap N=20, 5 in-flight); W8 sub-bullet added. G7 → update D10 (boilerplate-strip + nested raw-finding sub-list); W8 sub-bullet updated. Grill-surfaced gaps G-A through G-D deferred to /spec (state-schema bump, NI-mode behavior of D18 confirmation prompt, /execute commit-cadence interaction with D16, Phase-11 template). Grill report: `grills/2026-05-10_01_requirements.md`. |
