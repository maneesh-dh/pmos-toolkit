# /requirements Refactor + Pipeline-Setup Overhaul — Requirements

**Date:** 2026-05-08
**Last updated:** 2026-05-08
**Status:** Draft
**Tier:** 2 — Enhancement

## Problem

The `/requirements` skill has accumulated ~36 surfaced defects (vague tier-detection, redundant review-loop minimums, contradictory brainstorm guidance, missing T1/T2 sections, silent overwrites, undocumented edge cases). Compounding the skill-level issues, the shared pipeline-setup contract (`product-context/context-loading.md` + `_shared/feature-folder.md`) is convoluted (7 sub-flows for "where does my doc go") and structurally skip-prone — both files open with `<MUST READ END-TO-END>` directives that are themselves a tell that authors know agents skip them.

### Who & Why now

PMs and solo developers invoking `/requirements` as the entry point to the pmos-toolkit pipeline. Defects surfaced in a `/grill` session on 2026-05-08; same grill discovered the pipeline-setup convolution. Both bodies of work touch the Phase 0 region of `/requirements`, so coordinated fix avoids editing the same lines twice.

## Goals & Non-Goals

### Goals
- Apply all grill-report dispositions to `/requirements/SKILL.md` — measured by grill-disposition checklist (~36 items) all reflected in committed file.
- Reduce first-run friction from 3 sequential prompts to 1 consolidated prompt — measured by a fresh-repo dry run hitting exactly one `AskUserQuestion` call before brainstorming begins.
- Make pipeline-setup contract deterministic-on-read (no skip risk) — measured by lint script enforcing zero drift between canonical block and per-skill copies.
- Replace dual-shared-file resolver (context-loading.md + feature-folder.md) with single `_shared/pipeline-setup.md` — measured by both files removed (or shimmed) at end of work.
- Migrate existing repos silently with logged diff — measured by test fixtures (b)-(c) producing expected `.pmos/settings.yaml` without manual intervention.

### Non-Goals
- NOT refactoring `/spec` or `/plan` skill bodies — because each deserves its own grill before refactor; bundling makes review unmanageable.
- NOT changing `/msf` / `/creativity` skill semantics — because those are enhancers, not pipeline stages; only their references to renamed files get updated.
- NOT introducing hooks or validator subagents for resolver enforcement — because explicit MUST-language in the inline block is sufficient and avoids per-repo install friction.
- NOT auto-deleting any user files during migration — because `git mv` only is safer; users can revert via git if migration was wrong.

## Solution Direction

Two coordinated bodies of work in one PR:

1. **Pipeline-setup contract overhaul.** Single `_shared/pipeline-setup.md` (Sections 0/A/B/C/D) replaces `context-loading.md` + `feature-folder.md`. `.pmos/settings.yaml` becomes the sole source of repo-local state (replaces pointer file + autodetect chain). A 10-line canonical Phase 0 block lives in Section 0 and is pasted verbatim into each pipeline SKILL.md, with MUST-language for edge-case `Read`s. A lint script enforces zero drift between copies.

2. **`/requirements` rewrite per grill.** Apply all ~36 dispositions: tier-detection signals, decomposition trigger tightening, mode-specific phase routing, 6-gate exit replacing min-2 loops, Phase 5/6 merge, template additions (T1 Decision/OQ/Investigated, T2 Why-Now/measured-by, all-tier Status lifecycle), Goals-vs-AC boundary, conditional wireframe-link rule, drift detection for downstream artifacts, commit-before-overwrite safety, learnings audit line.

The two are coordinated because both modify the same Phase 0 region; doing them together avoids two passes.

## User Journeys

### Primary Journey — Fresh repo, first invocation

1. User runs `/requirements "I want to add bulk-edit to the agent dashboard"` in a repo with no `.pmos/`.
2. Skill detects first-run; emits **single consolidated** `AskUserQuestion` covering: docs_path (default `docs/pmos`), workstream (list `~/.pmos/workstreams/*.md` or skip), feature slug (derived from input → `bulk-edit-dashboard`, edit-to-override).
3. User accepts defaults; skill writes `.pmos/settings.yaml`, creates `docs/pmos/features/2026-05-08_bulk-edit-dashboard/`.
4. Tier detection fires (signals: 1 surface, no new persona, no new data model → Tier 2).
5. Brainstorm proceeds; review loops use 6-gate exit; doc commits as `01_requirements.md`.

### Alternate Journey — Legacy repo (auto-migrate)

1. User runs `/requirements ...` in a repo with existing `docs/specs/`, `docs/plans/`, and `.pmos/current-feature` pointer.
2. Skill detects legacy state; runs silent migration: writes `.pmos/settings.yaml` constructed from existing layout (`docs_path: docs/`, `current_feature: <pointer-value>`); deletes pointer file via `git rm`; logs diff to user.
3. Pipeline proceeds normally as if fresh; subsequent invocations skip migration.

### Alternate Journey — Mid-pipeline re-invocation

1. User re-runs `/requirements` after `/spec` and `/plan` already exist in the feature folder.
2. Skill detects downstream artifacts; warns: "Updating requirements will desync 02_spec.md and 03_plan.md — continue / cancel / run /verify after?"
3. User picks "continue"; skill commits dirty `01_requirements.md` first (snapshot), then proceeds with update path: reads prior Research Sources, refreshes only delta-relevant areas.

### Error Journeys

- **Slug collision detected** → skill `Read`s `pipeline-setup.md` Section B and prompts user (use existing / pick different slug).
- **Migration fails on a non-`git mv`-able file** → skill aborts migration, surfaces error, leaves repo unchanged. User receives explicit message.
- **Inline block diverges from canonical (lint detects)** → CI fails; PR cannot merge until copies are reconciled.

## Design Decisions

| # | Decision | Options Considered | Rationale |
|---|---|---|---|
| D1 | Settings file at `.pmos/settings.yaml` carries all repo-local state including `current_feature` | (a) separate state.yaml file, (b) keep pointer file, (c) runtime-only via folder mtime | One file = one read = single source of truth; atomic updates; eliminates pointer-file class of staleness bugs. |
| D2 | Silent auto-migration on first read with logged diff | (a) one-time prompt, (b) manual recipe only, (c) dual-read for one release | Zero-friction; logged diff means user can audit; `git mv`-only ensures reversibility. |
| D3 | Inline Phase 0 block (~10 lines) per pipeline SKILL.md, canonical in `_shared/pipeline-setup.md` Section 0; lint enforces no drift | (a) build-time include macro, (b) live with drift, (c) reference-only with no inline | Inline removes "I'll just infer from the reference" failure mode; lint catches drift at CI; no runtime indirection. |
| D4 | First-run prompt is single `AskUserQuestion` covering docs_path + workstream + slug | (a) defer slug to feature-creation step, (b) two sequential prompts, (c) skip workstream | One prompt = lowest friction; user sees full setup at once; slug derivation defaults to extracted noun or `mvp-v1` for MVP-shaped input. |
| D5 | Read-Trigger uses MUST-language + failure-mode warning, no hooks or validator subagents | (a) setup-validator subagent, (b) PreToolUse hook on Write/Edit, (c) trust language as-is | Sharper prose is the cheapest enforcement that doesn't require per-repo install; hooks/subagents are heavier and less portable. |
| D6 | 6-gate exit replaces min-2-loops in Phase 5; both lenses + explicit user confirm carry the weight | (a) keep min-2 as soft default, (b) tier-based, (c) drop min entirely with no replacement | Loop count is a proxy; explicit gates are the real forcing function. Avoids churn on clean drafts. |
| D7 | Decomposition fires only when 3-of-3 signals hold (different roles + independently shippable + non-overlapping ACs); else single Tier 3 | (a) 2-of-3, (b) never decompose, (c) always ask user | Pipeline assumes one doc per feature — splitting is correct only when the work truly is independent. |
| D8 | Old shared files deleted in same PR (after Phase E migrates all 7 pipeline skills); audit non-pipeline consumers first | (a) deprecation shims for one release cycle, (b) delete only one of the two | Clean state, smaller lint/test surface; audit ensures no surprise breakage. |
| D9 | `/spec` and `/plan` grill-style refactors stay deferred to separate sessions | (a) fold in /spec, (b) fold in both | Each has its own decision tree; bundling makes review unmanageable. |

## Open Questions

All resolved 2026-05-08:

| # | Question | Resolution |
|---|---|---|
| 1 | Does any non-pipeline skill import the old shared files? | No — user confirmed. Phase F deletes without shim. |
| 2 | Lint-script block-boundary mechanism? | HTML-comment markers (`<!-- pipeline-setup-block:start --> ... <!-- pipeline-setup-block:end -->`). Wraps canonical block in Phase A1 Section 0; lint diffs only the marked region. |

## Research Sources

| Source | Type | Key Takeaway |
|---|---|---|
| `/grill` session 2026-05-08 (chat transcript) | This-session | 36 dispositions resolved across tier detection, templates, review loops, research, file ops |
| `skills/requirements/SKILL.md` (v2.17.0, ~482 lines) | Existing code | Current contract; Phase numbering; template structure |
| `skills/product-context/context-loading.md` | Existing code | Step 1 docs_path resolution; Step 3 first-run fallback prompt |
| `skills/_shared/feature-folder.md` | Existing code | Slug rules, date-prefix mandate, collision handling, pointer file semantics |
| `skills/backlog/pipeline-bridge.md` (referenced) | Existing code | /requirements end-state contract for backlog set call |
