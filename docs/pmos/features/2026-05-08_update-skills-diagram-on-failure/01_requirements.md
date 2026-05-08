# /diagram `--on-failure` flag — Requirements

**Date:** 2026-05-08
**Last updated:** 2026-05-08
**Status:** Draft
**Tier:** 1 — Bug Fix (small new flag, no new phase, no schema change)
**Mode:** non-interactive
**Run Outcome:** clean
**Open Questions:** 0

## Problem

When `/diagram` runs in `--non-interactive` mode (added in T22) and Phase 6.5 fires (refinement loops exhausted with gating fails remaining), behavior is **non-deterministic**. The existing `AskUserQuestion` is tagged `<!-- defer-only: ambiguous -->`, so non-interactive runs defer the disposition into the OQ buffer and silently fall through. Callers (notably the upcoming `/rewrite` v0.14.0 which dispatches `/diagram` per template/worked-example) cannot rely on a documented exit-code contract: there is no way to say "if rendering fails, abort the slot vs. ship a marked-up SVG vs. let me decide."

This blocks `/rewrite` v0.14.0 from completing its spec-only-handoff swap.

### Who experiences this?

`/rewrite` (and any other future caller) invoking `/diagram --non-interactive` against a topic where Phase 6 cannot drive `code_score >= 0.8` and `blocker_count == 0` within the rigor-tier loop budget. Interactive `/diagram` users are unaffected — they continue to pick from the existing `Ship-with-warning / Try-alt / Abandon` `AskUserQuestion`.

### Reproduction / Root Cause

- **Reproduce:** invoke `/diagram "<intentionally hard description>" --non-interactive --rigor high` against a description that the rubric will reject (e.g., 30+ entities, ambiguous relationships). Loop exhaustion fires Phase 6.5; OQ-buffer protocol defers the AUQ; behavior past that point is unspecified.
- **Root cause:** Phase 6.5 disposition lives entirely in an `AskUserQuestion` with no programmatic alternative. Non-interactive mode was bolted on top of every skill's existing AUQ surface via the OQ-buffer protocol, but `defer-only: ambiguous` tags are explicit "human must decide" checkpoints — they have no auto-pick fallback by design. Phase 6.5 is one of those checkpoints.

### Investigated

- `plugins/pmos-toolkit/skills/diagram/SKILL.md:347-365` — Phase 6.5 source.
- `plugins/pmos-toolkit/skills/diagram/SKILL.md:80-163` — non-interactive-block (OQ-buffer protocol).
- Spec: `/Users/maneeshdhabria/Desktop/Projects/pmos/pmos-content/.claude/skills/rewrite/specs/v0.14.0-diagram-handoff-contract.md` §2.
- Triage: `00_triage.md` (this folder) — F2 approved, F1 (`--non-interactive`) skipped as already-handled by T22.

## Fix Direction

Add a `--on-failure {drop|ship-with-warning|exit-nonzero}` flag that becomes the **deterministic source of truth** for Phase 6.5 disposition when `mode == non-interactive`. Interactive mode is unaffected.

Behavior contract (verbatim from spec §2):

| Value | Behavior on Phase 6.5 firing |
|---|---|
| `drop` | Do NOT write SVG. Do NOT write sidecar. Exit 3. Print one-line reason to stderr listing remaining gating fails. |
| `ship-with-warning` | Write SVG with leading `<!-- WARNING: <fails> -->` comment + sidecar. Exit 0. (This is the existing prose-fallback behavior, now selectable.) |
| `exit-nonzero` | Do NOT write SVG. Do NOT write sidecar. Exit 4. Print one-line reason to stderr. |

**Default when `mode == non-interactive` and `--on-failure` is absent:** `exit-nonzero` (caller-decides). Per spec — the safest default for an automated caller is "don't write a half-baked artifact, let the orchestrator decide what to do with the failure."

**Interactive mode:** flag is parsed but advisory only. The existing `Ship-with-warning / Try-alt / Abandon` `AskUserQuestion` remains the source of truth. (Treating the flag as a pre-selection in interactive mode is out-of-scope for this iteration.)

The fix also documents the full exit-code contract in SKILL.md prose so callers can rely on it without reading source.

## Acceptance Criteria

- [ ] `argument-hint` lists `--on-failure {drop|ship-with-warning|exit-nonzero}`.
- [ ] Phase 0 `Parse args` step parses `--on-failure` into a variable; rejects unknown values with a clear error and exit 64.
- [ ] When `mode == non-interactive` and Phase 6.5 fires:
  - [ ] `--on-failure drop` → no SVG written, no sidecar written, exit 3, one-line reason on stderr.
  - [ ] `--on-failure ship-with-warning` → SVG written with leading `<!-- WARNING: <fails> -->` comment, sidecar written, exit 0.
  - [ ] `--on-failure exit-nonzero` → no SVG written, no sidecar written, exit 4, one-line reason on stderr.
  - [ ] `--on-failure` absent → behaves as `exit-nonzero`.
- [ ] When `mode == interactive`, Phase 6.5 behavior is unchanged (`AskUserQuestion` remains; flag is parsed but ignored).
- [ ] SKILL.md documents the exit-code contract (e.g., a small table in or near Phase 6.5).
- [ ] Phase 6.5's `<!-- defer-only: ambiguous -->` tag is removed (it no longer applies because non-interactive now has explicit handling) OR replaced with an explanatory comment that the AUQ only runs in interactive mode.
- [ ] Three regression tests under `plugins/pmos-toolkit/skills/diagram/tests/` exercise each `--on-failure` value end-to-end against a forced-failure fixture, asserting exit code + presence/absence of `<out>.svg` and sidecar.
- [ ] No changes to sidecar `schemaVersion`.
- [ ] No changes to Phase 0 hard-gate, Phase 1 existing-output, Phase 2 framing pick, Phase 6 refinement, or Phase 6.6 wrapper logic.

## Decisions

| # | Decision | Options Considered | Rationale |
|---|----------|--------------------|-----------|
| D1 | Default to `exit-nonzero` (not `ship-with-warning`) when `--non-interactive` is set and `--on-failure` is absent | (a) `ship-with-warning` (matches current prose-fallback behavior), (b) `exit-nonzero` (caller-decides), (c) `drop` (silently abandon) | Per spec §2. An automated caller is better served by an explicit failure exit than a half-baked artifact masquerading as success. `/rewrite` will configure `--on-failure exit-nonzero` explicitly per its handoff contract; making it the default protects unconfigured callers from the worst footgun. |
| D2 | Flag is advisory only in interactive mode (existing AUQ wins) | (a) Treat as pre-selection (skip AUQ if flag set), (b) Advisory only, (c) Reject combination | Avoids two ways to do the same thing in interactive mode and keeps the change narrow. The interactive `Try-alt framing` option has no non-interactive analog, so the surfaces aren't symmetric anyway. Pre-selection is a defensible future enhancement; out-of-scope here. |
| D3 | Remove the `<!-- defer-only: ambiguous -->` tag from Phase 6.5's AUQ | (a) Keep tag (OQ-buffer logs a reference even though the AUQ won't fire in non-interactive), (b) Remove tag, (c) Replace with `<!-- non-interactive: handled-via on-failure-flag -->` explanatory comment | Phase 6.5's AUQ is now interactive-only; defer-only tags exist to mark checkpoints with no programmatic fallback. With `--on-failure` providing the fallback, the tag is misleading. Use option (c) for clarity — explanatory comment over silent removal. |
| D4 | `drop` and `exit-nonzero` both skip sidecar write | (a) Write a stub failure-sidecar in both cases, (b) Skip sidecar in both, (c) Write only in `drop` | Spec doesn't require a sidecar on terminal failure. `/rewrite`'s exit-3-handling logs to its own `diagram-failures.md`; a stub sidecar adds nothing. Keep the contract minimal — file presence is the signal. |

## Open Questions

(none)

---

**Next step:** `/plan` to break this into TDD tasks. /spec is skipped (Tier 1).
