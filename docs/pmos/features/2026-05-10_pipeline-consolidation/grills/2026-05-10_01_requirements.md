# Grill Report — 01_requirements.md (pipeline-consolidation)

**Date:** 2026-05-10
**Target:** `docs/pmos/features/2026-05-10_pipeline-consolidation/01_requirements.md`
**Depth:** standard
**Questions asked:** 7
**Outcome:** all branches resolved; 7 dispositions feeding Loop-2 of /requirements (or directly into /spec)

## Summary of artifact

8-workstream Tier-3 feature folding `/msf-req`, `/msf-wf`, `/simulate-spec` into their parents (Tier 3 default-on, Tier 1/2 soft); fix `msf-findings.md` slug clash; remove redundant `/feature-sdlc` gates; standardize `--non-interactive` OQ contract via byte-identical inlining; fold `/retro` as final soft gate; add multi-session retro (`--last/--days/--since/--project all`, subagent-per-transcript). 14 decisions (D1–D14), 7 OQs, 1 prior review loop terminal.

## Resolved (7 dispositions)

| # | Branch | Question | Disposition | Doc impact |
|---|---|---|---|---|
| 1 | D2 / D11 / D13 mandatoriness semantics | What does "Tier 3 mandatory" actually mean given advisory-on-failure (D11) and `--skip-folded-msf` (D13)? | **Run-by-default + advisory-on-failure.** Rename D2 from "mandatory" to "default-on at Tier 3". `/verify` edge-case row softened to "warn at Tier 3, advisory at Tier 1/2". Escape flag stays. | Reword D2; soften /verify edge-case row in §Edge Cases table. |
| 2 | W3 / D13 asymmetry | Why does `/msf-req` get an escape (`--skip-folded-msf`) but `/simulate-spec` does not? | **Add `--skip-folded-sim-spec` for symmetry.** New decision **D15**. Mirrors D13; logged to `state.yaml.phases.spec.notes` when running under /feature-sdlc. | Add D15 to Design Decisions; update W3 Solution Direction; mention in Edge Cases. |
| 3 | D14 auto-apply atomicity + undo | What's the contract if auto-apply crashes mid-batch, or the user disagrees post-hoc? | **Per-finding git commits with last-good rollback.** New decision **D16**. Each auto-applied finding becomes its own commit (`msf-req: auto-apply finding F<n> (confidence <pct>)`); crash leaves last-good HEAD intact; undo via `git revert <sha>`. | Add D16 to Design Decisions; W1+W2+W3 Solution Direction sub-bullets gain "per-finding commit cadence". |
| 4 | D14 in `--non-interactive` | What's Recommended for sub-80-confidence findings when no human is at the keyboard? | **Recommended=Defer.** Inline `AskUserQuestion` call sites get Recommended=Defer; classifier AUTO-PICKs Defer; FR-03 emits to OQ artifact. Never silently mutate the doc in NI mode. | Update D14 wording; add explicit non-interactive sub-bullet under W1/W2/W3. |
| 5 | D11 silent-failure observability | If folded MSF crashes at Tier 3, how does the user find out? | **Phase-11 distinct "Folded-phase failures" subsection.** New decision **D17**. /feature-sdlc Phase 11 surfaces folded-phase crashes as a structured row above the OQ index; mirrored to chat; `state.yaml.phases.<parent>.folded_phase_failures[]` carries the record. | Add D17 to Design Decisions; W5 Solution Direction sub-bullet for the new state.yaml field; metric "Folded-phase failures surfaced in final summary" added to §Success Metrics. |
| 6 | /retro subagent count cap | `--last 50` or `--project all` on a 30-project corpus could spawn 150 subagents. What's the ceiling? | **Hard cap N=20 / 5 in-flight.** New decision **D18**. Above 20 candidate transcripts, Phase 1 surfaces an `AskUserQuestion` (scan all / most-recent-20 / cancel). Concurrency 5 in-flight. | Add D18 to Design Decisions; W8 Solution Direction sub-bullet for cap + concurrency. |
| 7 | D10 aggregation hash collisions | First-100-chars hash will collapse genuinely-different findings sharing boilerplate lead-ins. | **Boilerplate-strip + nested raw-finding sub-list.** Updates D10. Strip skill-name prefixes (`The /<skill> skill`, `The skill`) before first-100 hash; emit constituent raw findings as nested sub-list beneath each aggregated row. | Update D10 wording; W8 Solution Direction sub-bullet on boilerplate-strip preprocessing. |

## Open / Deferred — none

All 7 grilled branches closed cleanly with explicit dispositions. The 7 OQs already in `01_requirements.md` remain valid and are the right shape for `/spec` to resolve.

## Gaps surfaced (need /spec attention, not new grill questions)

- **G-A — state.yaml schema delta.** Disp 5 introduces `state.yaml.phases.<parent>.folded_phase_failures[]`. Schema bump in `reference/state-schema.md` required; resume-detection (Phase 0.b) needs to re-print the failure subsection on `--resume`.
- **G-B — NI-mode behavior of the new D18 confirmation prompt.** The "Found 47 transcripts — scan all / most-recent-20 / cancel" prompt needs Recommended=most-recent-20 for AUTO-PICK in `--non-interactive` `/retro --last N` runs; `lint-non-interactive-inline.sh` should pass.
- **G-C — /execute commit-cadence interaction with D16.** Per-finding commits land on the feature branch during `/requirements` and `/spec`. `/execute`'s commit-cadence assumption (one TDD task = one commit) needs to gracefully handle a branch that already carries N folded-MSF auto-apply commits. Likely a no-op, but pin in `02_spec.md`.
- **G-D — Phase-11 final-summary template.** `reference/pipeline-status-template.md` (or wherever the Phase-11 chat output is templated) needs a "Folded-phase failures" section above the OQ index. Pin the exact format in `/spec`.

## Recommended next step

1. **Update `01_requirements.md`** with the 7 new/updated decisions (D2 reworded, D10 updated, D14 updated, D15/D16/D17/D18 added) plus a Loop-2 Review-Log row. Optionally collapse this into the single requirements-doc commit at end-of-grill.
2. **Run `/spec`** next — its workload now includes the 7 prior OQs *plus* spec'ing G-A through G-D from this grill, plus producing the W6 audit list (target skill set for the canonical-block rollout).
