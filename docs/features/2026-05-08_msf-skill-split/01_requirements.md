# Requirements — /msf skill split & PSYCH relocation

**Tier:** 3 (feature-level — touches three skills + shared module + pipeline conventions)
**Date:** 2026-05-08
**Source:** `grills/2026-05-08_msf-skill-design.md`

## Problem

The current `/msf` skill in `pmos-toolkit` bundles two architecturally different jobs behind flag-driven branching (`--wireframes`, `--skip-psych`, `--default-scope`):

1. **Pre-/spec mode:** abstract MSF analysis on a requirements doc, with a write-back step that mutates `01_requirements.md`.
2. **Inline-from-/wireframes mode:** grounded MSF + PSYCH analysis on wireframe HTML files, with a write-back step that mutates the HTML.

The bundling produces three concrete problems:
- **Self-grading writes:** Phase 5 mutates source artifacts and Phase 6 self-checks the same edits — a diagnostic skill silently authoring inputs to /spec.
- **PSYCH duplication:** /wireframes Phase 6 already runs PSYCH; /msf re-runs it unless told to skip via `--skip-psych`. Two implementations, one concept.
- **Output volume vs. cap collision:** the persona × scenario × journey × 24-considerations matrix routinely exceeds the documented 300-line report cap.

## Goals

1. Replace `/msf` with two purpose-built skills: `/msf-req` (req-doc evaluation) and `/msf-wf` (wireframe evaluation).
2. Make both skills **recommendations-only by default**. Source-artifact writes are permitted *only* when invoked by a parent skill that owns the artifact (`/requirements`, `/wireframes`, `/prototype`).
3. Move PSYCH scoring into `/msf-wf` and remove it from `/wireframes`. /wireframes keeps its UX-rubric self-eval only.
4. Save findings to `NN_<slug>/msf-findings.md` inside the pipeline feature dir (or `~/.pmos/msf/` for ad-hoc invocations), matching `/grill`'s convention.
5. Adopt a two-tier output: full uncapped matrix in the saved findings doc, executive summary in chat (capped).

## Non-goals

- Calibrating PSYCH thresholds against empirical data (deferred — keep current heuristics, soften threshold language to "directional").
- Tier auto-gating (deferred — descriptions claim Tier 3 but skills won't enforce).
- Resolving the /msf-wf ↔ /wireframes regenerate-loop semantics (deferred to a follow-up grill on /msf-wf).

## User journeys

### J1 — Pre-/spec UX evaluation (standalone /msf-req)
1. User has `01_requirements.md` for a Tier 3 feature.
2. User runs `/msf-req <path>`.
3. Skill aligns on personas, journeys; runs MSF Pass A only.
4. Skill emits findings doc at `NN_<slug>/msf-findings.md` and an executive summary in chat.
5. User reads findings, manually folds them into a revised requirements doc or hands them to `/spec`.

### J2 — Post-wireframes UX evaluation (standalone /msf-wf)
1. User has a wireframes folder produced by `/wireframes`.
2. User runs `/msf-wf <wireframes-folder>`.
3. Skill reads every HTML file, runs MSF Pass A + PSYCH Pass B grounded in DOM elements.
4. Skill emits findings doc + executive summary.
5. User decides whether to manually re-run `/wireframes` to apply changes.

### J3 — Inline invocation from /wireframes
1. `/wireframes` finishes generating HTML in Phase 7.
2. /wireframes invokes `/msf-wf` with parent-write authority.
3. /msf-wf runs analysis, emits findings, AND directly edits HTML for accepted recommendations (parent-skill-authorized writes).
4. Control returns to /wireframes.

### J4 — Inline invocation from /requirements or /prototype
- Same as J3 but the parent skill owns the requirements doc or prototype HTML respectively.

## Acceptance criteria

1. `/msf` no longer exists as a skill; it is replaced by `/msf-req` and `/msf-wf` with disambiguated descriptions.
2. Shared MSF heuristics live in `_shared/msf-heuristics.md` (or equivalent), referenced by both skills.
3. PSYCH scoring instructions exist only in `/msf-wf`. /wireframes Phase 6 (currently PSYCH) is replaced with UX-rubric eval only; `psych-findings.md` is no longer produced by /wireframes.
4. Standalone runs of either skill never edit source artifacts. Test: invoke each skill on a sample doc/folder; confirm only the findings doc is written.
5. Parent-invoked runs (J3, J4) accept a `--parent-writes-authorized` (or equivalent) signal and only then perform source edits.
6. Findings doc lives at `NN_<slug>/msf-findings.md` when invoked inside a feature dir; falls back to `~/.pmos/msf/YYYY-MM-DD_<slug>.md` otherwise.
7. Chat output is bounded (≤200 lines); saved findings doc has no line cap.
8. The `--wireframes`, `--skip-psych`, and `--default-scope` flags are removed.
9. Release notes / CHANGELOG updated; pmos-toolkit minor version bumped.
10. Coupled-skill descriptions updated: /wireframes loses its PSYCH-related trigger phrases; /msf-req and /msf-wf trigger phrases are disjoint.

## Open questions deferred to /spec or later

- Exact handoff schema for `msf-findings.md` (columns, severity field) so /spec can mechanically consume it.
- Whether `/msf-req` and `/msf-wf` share any code/file beyond `_shared/msf-heuristics.md` (e.g., persona-alignment phase, executive-summary template).
- Migration: should the existing `/msf` skill stay as a deprecation shim that dispatches to /msf-req or /msf-wf based on argument shape? Or hard-remove?
- Versioning: is this a minor or major bump for pmos-toolkit?

## Constraints

- Must follow `pmos-toolkit` skill conventions: `learnings/learnings-capture.md`, platform-adaptation block, `_shared/resolve-input.md`, `_shared/interactive-prompts.md`.
- Must not break in-flight pipeline runs that reference `/msf` directly — provide migration path or shim.
