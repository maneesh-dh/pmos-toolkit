# /verify: phase-scoped gate, bubbles doc, outcome template (V1+V2+V3) — Requirements

**Date:** 2026-05-08
**Last updated:** 2026-05-08
**Status:** Draft
**Tier:** 2 — Enhancement (collapsed: requirements + spec + plan inline)

## Problem

Three friction points in `/verify` surfaced from the retro:

1. **V1 (friction):** `--scope phase` runs require `TodoWrite`-per-FR-ID under the Phase 4 Entry Gate, even though the per-task logs at `{feature_folder}/execute/task-NN.md` already carry evidence-typed FR coverage tables. The `TodoWrite` mandate duplicates structural enforcement that already exists.
2. **V2 (friction):** Synthesizing a `KeyboardEvent` in Playwright without `bubbles: true` causes document-level listeners to silently miss the event, producing false-negative FR verifications. This isn't documented anywhere in Phase 4 sub-step 3d evidence guidance.
3. **V3 (nit):** The three-state outcome model (`Verified` / `NA — alt-evidence` / `Unverified — action required`) is described in prose at Phase 5 (lines 443–446) and the table headers reference it, but there is no copy-pasteable template that makes the outcome column structural rather than free-form. Reviewers tend to slip into `Pass` / `Fail` / `✓` instead.

### Who experiences this?

Maintainers running `/verify` either standalone or via `/execute` Phase 2.5 phase boundaries — particularly anyone running phase-scoped verification on a multi-phase plan.

## Goals & Non-Goals

### Goals
- V1: phase-scoped runs use the `review.md` markdown table as Phase 4 Entry Gate enforcement; standalone runs continue to require `TodoWrite`. Measured by: phase-scoped invocation block lists this as the third change, AND Phase 4 Entry Gate prose has a phase-scoped exception callout.
- V2: any agent reading Phase 4 sub-step 3d guidance sees the bubbles:true requirement immediately. Measured by: the evidence-allowlist row for 3d names the requirement with the exact phrase "`bubbles: true`".
- V3: any agent writing a Phase 5 4b compliance table sees a copy-pasteable template. Measured by: the section contains a fenced markdown block with the three valid `Outcome` values explicitly written out.

### Non-Goals
- NOT redesigning the entry-gate concept itself — because the structural-enforcement principle is sound; only the per-FR-ID `TodoWrite` artifact is the friction.
- NOT introducing a new outcome state — because the existing 3-state model already covers reality; this is a discoverability fix.
- NOT adding test fixtures for skill-prose changes — because the skill is evaluated by execution-time agents reading the file; the gate is contract-text inspection.

## Solution Direction

In `verify/SKILL.md`:
1. Extend the "Invocation Mode: Phase-Scoped" block from "two changes" to "three changes" — third is the entry-gate exception (V1).
2. Add a callout in the "Phase 4 Entry Gate" section that points to the phase-scoped exception (V1, redundant for discoverability).
3. Append the bubbles:true sentence to the 3d row of the evidence-type allowlist (V2).
4. Append a copy-pasteable markdown template + an explicit allowed-values list under Phase 5 sub-section 4b (V3).

No new phases, no new reference files, no changes to argument-hint.

## Acceptance Criteria

- [ ] AC1 (V1) — Phase-scoped invocation block lists three changes; the third explicitly says the markdown table in `review.md` is the structural enforcement and reserves `TodoWrite`-as-gate for standalone runs.
- [ ] AC2 (V1) — Phase 4 Entry Gate section contains a callout pointing to the phase-scoped exception; the callout names the per-task log as the source of duplicated coverage.
- [ ] AC3 (V2) — Phase 4 sub-step 3d row in the evidence-type allowlist contains the exact phrase "`bubbles: true`" with surrounding text explaining why (document-level listeners + false-negative risk).
- [ ] AC4 (V3) — Phase 5 sub-section 4b contains a copy-pasteable markdown table template inside a fenced ` ```markdown ` block with example rows for each of `Verified`, `NA — alt-evidence`, `Unverified — action required`.
- [ ] AC5 (V3) — Phase 5 sub-section 4b explicitly enumerates the three allowed `Outcome` values and lists invalid alternatives (`Pass`, `Fail`, `Complete`, `Partial`, `✓`, `❌`) as not valid.
- [ ] AC6 — `argument-hint` and phase numbering unchanged; standalone (non-`--scope phase`) Entry-Gate behavior unchanged for runs that lack `--scope phase`.

## Open Questions

_(none)_
