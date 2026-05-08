# /requirements Refactor + Pipeline-Setup Overhaul — Implementation Plan

**Date:** 2026-05-08
**Last updated:** 2026-05-08
**Status:** Draft
**Upstream:** `01_requirements.md` (this folder)

## Goal

Apply all `/grill`-surfaced dispositions to `skills/requirements/SKILL.md` AND restructure the pipeline-setup contract (settings.yaml, merged shared file, inline-block pattern) in one coordinated PR. Done together because both edit the same Phase 0 region of `/requirements` and downstream pipeline skills.

## In scope (this PR)

- `skills/requirements/SKILL.md` — full rewrite per grill (~36 dispositions)
- `skills/_shared/pipeline-setup.md` — NEW (consolidates `context-loading.md` + `feature-folder.md`)
- `.pmos/settings.yaml` schema + silent auto-migration logic (lives inside the new shared file)
- Lint script for inline-block drift detection
- Tier 1/2/3 templates inside `/requirements`
- Backlog bridge contract update for `/requirements`
- **Propagation** of new Phase 0 inline block to `/spec`, `/plan`, `/execute`, `/verify`, `/wireframes`, `/prototype`
- **Deletion** of `context-loading.md` and `feature-folder.md` (after propagation, with non-pipeline consumer audit)
- **Cross-skill reference audit** of `/backlog`, `/msf`, `/creativity`, `/product-context`

## Out of scope (deferred)

- Full grill-style refactors of `/spec` and `/plan` skill bodies — each deserves its own `/grill` session.
- Semantic changes to `/msf`, `/creativity`, or `/backlog` beyond reference path updates.
- Any new skill creation.

---

## Phase A — Foundation

A1 must finish before B1 (which quotes Section 0 verbatim).

### A1. Author `skills/_shared/pipeline-setup.md`

Five sections:

- **Section 0 — Canonical inline Phase 0 block** (~10 lines). Wrapped in HTML-comment markers `<!-- pipeline-setup-block:start -->` and `<!-- pipeline-setup-block:end -->` so the lint script (Phase C) can scope its diff. Uses MUST-language for edge-case `Read`s. One-line failure-mode warning: "Skipping the Read on edge cases is the most common cause of folder-naming defects."
- **Section A — First-run setup.** Single consolidated `AskUserQuestion` (3 questions batched: docs_path, workstream, feature slug). Slug-derivation rule: extract concrete feature noun from input; if MVP-shaped/broad input with no concrete noun, suggest `mvp-v1` (kebab-case, versioned) with edit-to-override.
- **Section B — Feature-folder rules.** Slug spec (kebab-case, ≤40 chars, no double hyphens, no leading/trailing hyphens), mandatory date prefix `{YYYY-MM-DD}_{slug}`, collision handling, edge cases.
- **Section C — Workstream enrichment.** Lifted from current `context-loading.md` Step 4 (`/requirements` signals: User Segments, Value Proposition, Key Metrics).
- **Section D — Migration recipe.** Silent auto-migration on first read. Detects: legacy `docs/{requirements,specs,plans,features}/` layout, `.pmos/current-feature` pointer file. Constructs `settings.yaml` from existing state. `git mv`-only — never destructive. Logs every move before doing it. Aborts with surfaced error if any non-`git mv`-able conflict.

### A2. `.pmos/settings.yaml` schema

```yaml
version: 1
docs_path: docs/pmos             # or docs/ on legacy-detected repos
workstream: <slug-or-null>       # null if user skipped
current_feature: <YYYY-MM-DD_slug-or-null>   # null on fresh init
```

Documented inside Section A of `pipeline-setup.md`. Schema versioning enables future migrations.

### A3. Test fixtures under `tests/fixtures/pipeline-setup/`

- (a) **fresh** — no `.pmos/`, no `docs/`
- (b) **pointer-only** — has `.pmos/current-feature` but no settings.yaml
- (c) **legacy-layout** — has `docs/specs/`, `docs/plans/`, no `.pmos/`
- (d) **fully-migrated** — has `.pmos/settings.yaml` with all fields populated
- (e) **mid-pipeline** — has `01_requirements.md`, `02_spec.md`, `03_plan.md` in feature folder

### A — Verification

Manual walkthrough on each fixture; confirm migration logs match expected diff and no destructive ops fire. Document expected outcomes in `tests/fixtures/pipeline-setup/EXPECTED.md`.

---

## Phase B — `/requirements` rewrite

Each B-step is one logical edit. Sequenced to avoid same-region conflicts. Apply sequentially within `skills/requirements/SKILL.md`.

### B1. Phase 0 — REPLACE entirely

Delete current Phase 0 references to `context-loading.md` and `feature-folder.md`. Paste canonical block from `pipeline-setup.md` Section 0 verbatim, between the lint markers.

### B2. Phase 1 — Intake & Tier

- Add explicit tier-detection signals: surface count, new vs. existing data model, new persona, reversibility. Agent picks the highest-tier signal that fires.
- Move tier confirm/override BEFORE task creation.
- Tighten decomposition trigger to 3-of-3 (different user roles + independently shippable + non-overlapping ACs); else treat as single Tier 3.
- Add mode-specific phase routing for the 4 input modes:
  - Raw thoughts → full flow (current default)
  - Existing doc update → skip Phase 2 research; only run Phase 3 on the delta
  - Multiple text inputs → add Phase 1.5 synthesis step before Phase 2
  - Spec/brief → skip Phase 3 brainstorm; run gap-analysis lens in Phase 5
- Add downstream-drift warning: check for `02_spec.md` / `03_plan.md` before any write. If present, warn user: "Updating requirements will desync spec/plan — continue / cancel / run /verify after?"
- Tier 3 task list gains: UX Analysis, Success Metrics definition, Alternate/Error journey mapping (as separate tracked tasks).

### B3. Phase 2 — Research

- Renumber `1a` / `1b` → `2a` / `2b`.
- Drop named-competitor defaults (Linear/Stripe/Notion/etc.); replace with: "Pick 2–4 competitors from the user's actual domain — derive from workstream context, repo description, or ask user."
- Add subagent return-schema spec: each subagent returns (1) bullet summary ≤5 bullets, (2) cited sources table (path/URL + 1-line takeaway), (3) flagged gaps. Parent merges by section without re-summarization.
- Add update-path stale-research handling: parse prior Research Sources table; for each row, check if its takeaway still holds; only research net-new areas tied to the user's delta.

### B4. Phase 3 — Brainstorming

- Resolve "one-at-a-time vs batch-4" contradiction → "One question per topic. Use `AskUserQuestion`'s multi-question form (up to 4) ONLY when questions are genuinely related and the user can answer all in one pass without context switching."
- Reframe scripted question lists as **coverage checklists** — areas the doc must cover, not questions to ask. Agent checks if user input + research already answered each area; only asks where gaps exist.
- Add tier-based stop conditions:
  - T1: stop when Problem + Root Cause + Fix Direction are pinned.
  - T2: stop when Problem + Goals + Solution Direction + 1 user journey are pinned.
  - T3: stop when all mandatory sections have a non-placeholder answer or an Open Question entry.

### B5. Phase 4 — Write

- Add commit-before-overwrite safety check: before write, run `git status` on `01_requirements.md`. If dirty, run `git add 01_requirements.md && git commit -m "snapshot: pre-/requirements-rewrite"`. Then overwrite.
- Conditional commit-message verb: `update` if file existed at Phase 1 entry, else `add`.

### B6. Phase 5 — Review (LARGEST EDIT)

- Replace `min 2 loops` with **6-gate exit**:
  1. Loop ran both lenses in the same pass (structural + product-critique).
  2. Loop produced findings, OR explicitly logged "no findings under lens X" per lens.
  3. Findings (if any) all dispositioned via `AskUserQuestion` (Fix / Modify / Skip / Defer).
  4. User explicitly confirmed "no further concerns" — single yes/no, not inferred from silence.
  5. Decision table populated (≥3 for T3, ≥1 for T2, optional for T1).
  6. Zero open clarifications addressed to the user.
- Replace ambiguity gate ("two engineers interpret differently") with concrete heuristics: no "etc." / "and more"; every quantitative claim has a number; every "should" / "might" either becomes "must" or moves to Open Questions; no orphan pronouns.
- Replace `3+ decisions for Tier 3` with coverage rule: every non-trivial design choice from research/brainstorm must appear as a Decision row OR an Open Question.
- **Merge Phase 6 final-review checks INTO Phase 5's final loop** (conciseness, missing journeys, coherence, new-person test). Delete Phase 6 as a separate phase.

### B7. Phase numbering shift

Former Phase 7 → 6, former Phase 8 → 7. Update every internal reference in the file.

### B8. New Phase 6 — Workstream enrichment

- Add guard: "Skip if Tier 1." Otherwise unchanged.

### B9. New Phase 7 — Learnings

- Replace "reflection happens" with: agent must emit a 1-line output — either `Learning: <new entry>` written to `~/.pmos/learnings.md` OR `No new learnings this session because <specific reason tied to this session>`. Empty reflection counts as unfinished.

### B10. Templates

- **T1:** add optional Decision + Open Questions sections (marked "omit if empty"). Add lightweight `### Investigated` block — file paths + issue/PR links touched during root-cause analysis.
- **T2:** add `### Why now?` subsection. Goals require `— measured by [signal]` suffix on each bullet. Add handoff pointer at end: "For UX friction analysis, run `/msf`."
- **T3:** add Goals-vs-AC boundary callout under the Goals section.
- **All tiers:** Status lifecycle field — Draft → In Review → Approved (advances at Phase 5 entry and Phase 5 user-confirm). Add `**Last updated:** YYYY-MM-DD` line that refreshes on every commit.

### B11. Document Guidelines

- Add Goals-vs-AC boundary rule: "Goals are observable user outcomes ('users find the right issue 80% of the time'). Acceptance Criteria are engineering contracts ('search returns results in <300ms') — those belong in `/spec`. Tier 1 carries both because it bypasses `/spec`."
- Conditional wireframe-link rule: "If wireframes exist for this feature folder, link them and avoid prose visual description. If not, describe screens at a behavior level only — do not invent visual detail."
- Diagrams rule: "Allowed if they describe what the user sees/does (screens, journeys, state transitions). Banned if they describe internal architecture (services, queues, DBs) — those belong in `/spec`."

### B12. Open Questions table

- Default to 2-col (`#`, `Question`).
- Expand to 4-col (`#`, `Question`, `Owner`, `Needed By`) ONLY if: user mentioned a teammate/stakeholder during brainstorm, OR `~/.pmos/people/` directory is non-empty, OR user mentioned a deadline.

### B13. Backlog bridge

- Update Phase 7 (or wherever the backlog set call lives) to:
  - Only call `/backlog set {id} source={doc_path}` if (a) doc was actually written this run AND (b) commit succeeded.
  - On re-run with same `--backlog id`, log overwrite event to backlog item history (e.g., append a `- 2026-05-08: requirements doc rewritten by user` line).
  - Skip silently if doc missing.

### B14. Tier 3 handoff message

- Final message becomes: "Requirements committed. Optional next: `/creativity` (alternative angles), `/msf` (UX friction analysis). When ready: `/spec`."
- Tier 1 / Tier 2 handoff: keep the simple "→ /spec" form.

### B — Verification

Run `/requirements` on each test fixture (a)–(e) from A3. Confirm:

- (a) First-run consolidated prompt fires correctly; settings.yaml created with sensible defaults.
- (b) Pointer file absorbed into settings.yaml; pointer deleted via `git rm`; user sees migration log.
- (c) Legacy `docs/` layout detected; `docs_path: docs/` written to settings.yaml; no file moves.
- (d) Skill proceeds normally; no migration noise.
- (e) Drift warning appears before any write; user can choose continue/cancel.

Manual checklist: open committed `01_requirements.md` against grill-disposition list (~36 items); each must be reflected.

---

## Phase C — Lint script

### C1. Author `tools/lint-pipeline-setup-inline.sh`

- Scans `skills/{requirements,spec,plan,execute,verify,wireframes,prototype}/SKILL.md`.
- Extracts content between `<!-- pipeline-setup-block:start -->` and `<!-- pipeline-setup-block:end -->` markers.
- Diffs against canonical block in `_shared/pipeline-setup.md` Section 0.
- Exit non-zero on drift; prints diverging file + first-line-of-divergence.
- Emit zero-output success on no-drift.

### C2. Wire into CI

- Add to existing `/verify` skill or pre-commit hook (whichever the repo uses today).
- Block PRs on drift.

### C — Verification

- Intentionally break drift on a copy in `/spec/SKILL.md`; confirm lint fails with clear file+line message.
- Reset; confirm passes.

---

## Phase D — Documentation + cross-skill reference audit

### D1. Update `skills/backlog/pipeline-bridge.md`

- Reflect new `/requirements` end-state contract: guard with doc-written + commit-succeeded.
- Document overwrite-history append behavior.

### D2. CHANGELOG entry

```
## Unreleased
### BREAKING
- /requirements Phase 0 contract changed. Existing repos auto-migrate
  on first read; see _shared/pipeline-setup.md Section D for layout details.
- context-loading.md and feature-folder.md removed; consolidated into
  _shared/pipeline-setup.md.
### Added
- 6 pipeline skills now use a unified Phase 0 inline block.
- Lint script enforces inline-block drift across pipeline skills.
- /requirements gains tier-1 Decision/OQ/Investigated optionals,
  tier-2 Why-Now and measured-by, all-tier Status lifecycle.
```

### D3. Cross-skill reference audit

Run a single grep:

```bash
grep -rn "context-loading.md\|feature-folder.md\|.pmos/current-feature" skills/
```

Update every match in `/backlog`, `/msf`, `/creativity`, `/product-context`, and any other consumer to point at `_shared/pipeline-setup.md` (with section anchor where relevant). No semantic skill changes — just consistent reference paths.

### D4. Deprecation pointers

Add a 1-line note at top of `context-loading.md` and `feature-folder.md`:

```
> **Deprecated as of 2026-05-08.** This file's contents have moved to
> `_shared/pipeline-setup.md` (Sections A–D). This stub is kept for one
> release cycle; will be removed in Phase F of the requirements-refactor.
```

(Phase F may delete these; the pointer covers the brief window where Phase E has propagated but Phase F hasn't run yet, AND any external consumer that lands during the PR review.)

### D — Verification

- Grep confirms zero remaining references to old filenames in semantic positions (links allowed in deprecation notes).
- CHANGELOG renders cleanly in the project's existing format.

---

## Phase E — Propagate inline block to other pipeline skills

Mechanical paste; not a full grill-style refactor.

### E1. For each of `/spec`, `/plan`, `/execute`, `/verify`, `/wireframes`, `/prototype`:

1. Locate current Phase 0 (or equivalent setup section) in the SKILL.md.
2. Replace its content with the canonical Phase 0 block from `_shared/pipeline-setup.md` Section 0, wrapped in lint markers.
3. Delete any references to `context-loading.md` and `feature-folder.md`.
4. Run lint script (Phase C) — confirm it passes.
5. Commit each skill separately for clean review: `chore(pipeline): unify Phase 0 setup in /<skill>`.

### E — Verification

- Lint script passes against the full `skills/` tree.
- Sanity test: invoke `/spec` on test fixture (d); confirm it reads settings.yaml and proceeds without prompting (since current_feature is set).

---

## Phase F — Delete old shared files

### F1. Audit non-pipeline consumers (verification grep)

User confirmed (2026-05-08) no non-pipeline consumers exist. F1 is a defensive verification only:

```bash
grep -rn "context-loading.md\|feature-folder.md" --include="*.md"
```

Expected result: only matches inside `pipeline-setup.md` itself and the deprecation stubs (Phase D4). Any unexpected match → pause F2 and update that consumer first.

### F2. Delete

```bash
git rm skills/product-context/context-loading.md
git rm skills/_shared/feature-folder.md
git commit -m "chore(pipeline): remove deprecated shared files (consolidated into pipeline-setup.md)"
```

### F — Verification

- Lint script (Phase C) still passes.
- Test fixtures (a)–(e) still produce expected outcomes.
- Final sanity test: 1 fresh-repo `/requirements` run + 1 legacy-repo `/requirements` run, both end-to-end without manual intervention.

---

## Execution order

A1 → A2 → A3 → B1 → (B2 ... B14 in any order; group by section for clean commits) → C1 → C2 → D1 → D2 → D3 → D4 → E1 (×6, one per skill) → F1 → F2

A1 must finish before B1 (B1 quotes Section 0 verbatim).
Phase E requires both A1 (canonical block exists) and C1 (lint script available).
Phase F requires E1 complete for all 6 skills.

---

## Risks & mitigations

| Risk | Mitigation |
|---|---|
| Silent migration corrupts a repo's docs layout | Dry-run mode in migration; log every move BEFORE doing it; `git mv` only, never `rm`; verify with test fixture (c) before any real-repo run. |
| Grill dispositions conflict at edit time (B6 + B7 both touch Phase 5/6 region) | B6 sequenced as a single edit (merge happens atomically); B7 only renumbers references after B6 lands. |
| Lint script too strict, breaks normal edits | Diff only the marked block region (between HTML-comment markers), not the whole file. |
| Phase E mechanical paste mistakes | Run lint after every paste (one paste = one commit = one lint run). Catches drift immediately. |
| Phase F breaks an external/non-pipeline consumer | F1 grep audit; if any non-pipeline reference exists, leave deprecation shim in place and skip F2 for that file. |
| Other pipeline skills (`/spec`, `/plan`) have undocumented dependencies on `feature-folder.md` Step 4 collision-handling that's now in Section B | Phase E review checklist includes "verify each skill's edge-case behavior still works after paste"; if a skill needed something not in Section B, surface it as a follow-up issue, not a blocker. |
| `/spec` and `/plan` (deferred) reveal new defects when they hit the new Phase 0 contract | Acceptable — those defects are independent of this PR. File them as backlog items for the deferred grill sessions. |

---

## Estimated effort

| Phase | Hours |
|---|---|
| A — Foundation | ~2.0 |
| B — `/requirements` rewrite | ~3.5 |
| C — Lint script | ~1.0 |
| D — Documentation + audit | ~0.5 |
| E — Propagation (×6) | ~1.5 |
| F — Delete + final sanity | ~0.5 |
| **Total** | **~9.0** |

---

## Final verification checklist

- [ ] All ~36 grill dispositions reflected in `skills/requirements/SKILL.md` (cross-check against grill report)
- [ ] `_shared/pipeline-setup.md` exists with Sections 0/A/B/C/D
- [ ] Inline Phase 0 block in `/requirements` matches Section 0 verbatim (lint passes)
- [ ] Inline Phase 0 block in `/spec`, `/plan`, `/execute`, `/verify`, `/wireframes`, `/prototype` matches verbatim (lint passes)
- [ ] Test fixtures (a)–(e) all produce expected outcomes
- [ ] Migration is reversible (git mv only)
- [ ] CHANGELOG documents the contract change
- [ ] `context-loading.md` and `feature-folder.md` deleted (or shimmed if non-pipeline consumer found)
- [ ] Cross-skill references updated in `/backlog`, `/msf`, `/creativity`, `/product-context`
- [ ] Sanity test: 1 fresh-repo run + 1 legacy-repo run + 1 mid-pipeline run completes without manual intervention
- [ ] Lint script blocks PRs on drift (verified by intentional break)
