# Add /plan and /verify to /create-skill pipeline — Requirements

**Date:** 2026-05-08
**Last updated:** 2026-05-08
**Status:** Draft
**Tier:** 3 — Feature (modifies a pipeline orchestrator)

## Problem

The `/pmos-toolkit:create-skill` orchestrator skips two pipeline stages that every other multi-skill flow in the toolkit relies on: there is no `/plan` step (the pipeline jumps from spec/grill straight to implement) and no `/verify` step (Phase 7 is an inline pre-save checklist, not the multi-agent `/verify` gate). As a result, skill creations at Tier 2 and Tier 3 land without an execution plan or post-implementation verification — making `/create-skill` the only skill-orchestrator in the toolkit that doesn't dogfood its own pipeline.

### Who experiences this?

**Skill authors** running `/pmos-toolkit:create-skill` to scaffold a new skill at Tier 2+. They get a spec (and optionally a grill pass at Tier 3), then jump straight to writing SKILL.md without an execution plan — and ship without `/verify` validation. Compare to `/update-skills`, which already invokes both stages in Phase 8.

### Why now?

User feedback explicitly called out the gap during a recent triage. The asymmetry between `/create-skill` (no plan/verify) and `/update-skills` (plan + verify) is a coherence problem — both are orchestrators that produce skill code, and authors expect them to run the same pipeline.

## Goals & Non-Goals

### Goals

- Every Tier 2+ run of `/create-skill` invokes `/pmos-toolkit:plan` after spec (and after grill at Tier 3) — measured by: SKILL.md contains a numbered Phase that calls `/plan`, gated to Tier 2+.
- Every run of `/create-skill` (all tiers) invokes `/pmos-toolkit:verify` after implementation — measured by: SKILL.md contains a numbered Phase that calls `/verify`, marked non-skippable.
- The pre-save inline checklist (current Phase 7) is removed entirely — `/verify` covers it for all tiers — measured by: Phase 7 deleted from SKILL.md, content folded into a `/verify` checklist hint or the spec template if needed.
- Anti-patterns section explicitly forbids skipping `/plan` (Tier 2+) or `/verify` (any tier) — measured by: two new bullets in Anti-Patterns.

### Non-Goals

- NOT modifying `/update-skills` — it already invokes `/plan` (Tier 2+) and `/verify` (non-skippable) in Phase 8. F3 was reviewed and skipped.
- NOT changing the existing tier table's tier-detection signals (Tier 1/2/3 triggers stay as-is) — only the "workflow" column reflects the new phases.
- NOT extending `/plan` or `/verify` themselves — we treat them as black-box pipeline skills.
- NOT changing Phase 1 (intent), Phase 2 (auto-tier), Phase 3 (interview), Phase 4 (spec), or Phase 5 (grill).

## User Experience Analysis

### Motivation

- **Job to be done:** Create a new skill at Tier 2+ that has been planned (broken into TDD tasks), implemented against the plan, and verified before declaring complete.
- **Importance/Urgency:** Medium — current flow ships skills, but they bypass the validation gates the rest of the pipeline relies on. Risk surfaces post-merge as missing edge cases or regression.
- **Alternatives:** Author manually invokes `/plan` and `/verify` after `/create-skill` finishes. This works but is forgotten in practice and has no enforcement.

### Friction Points

| Friction Point | Cause | Mitigation |
|---|---|---|
| Author forgets to run `/plan` after spec is approved. | No phase exists in `/create-skill` to invoke it. | New Phase 5.5 invokes `/plan` automatically (Tier 2+). |
| Author ships a skill without `/verify` running. | Phase 7's inline checklist is human-readable but doesn't run lint/tests/multi-agent review. | New Phase 7.5 invokes `/verify`, mandatory all tiers. |
| Tier 1 author runs full `/verify` for a trivial one-shot skill, slowing the cycle. | If `/verify` were Tier 2+ only, Tier 1 would be unprotected. | `/verify` is mandatory all tiers per user decision. The inline checklist is removed entirely — `/verify` is the single source of truth for verification at every tier. |

### Satisfaction Signals

- After running `/create-skill` at Tier 2+, the author sees a saved plan doc in the feature folder before any code is written.
- After implementation, `/verify` produces a green report or surfaces actionable findings — same UX as `/update-skills` and the standalone `/verify` flow.
- The skill's tier table workflow column matches the actual phases run, no surprises.

## Solution Direction

Insert two new phases into `/create-skill`:

```
Current:                              Proposed:
Phase 4 spec (T2+)                    Phase 4 spec (T2+)
Phase 5 grill (T3)                    Phase 5 grill (T3)
                                      Phase 6 plan (T2+)             <-- NEW
Phase 6 implement                     Phase 7 implement (renumbered)
Phase 7 pre-save checklist            Phase 8 verify (all tiers)     <-- NEW (replaces checklist)
Phase 8 capture learnings             Phase 9 capture learnings (renumbered)
```

Spec status flow becomes: `draft → grilled (T3) → planned (T2+) → approved → implemented → verified`.

Tier table (current SKILL.md L44-L48) "Workflow" column updates:

| Tier | Old workflow | New workflow |
|---|---|---|
| 1 | Skip Phases 4-5. Implement directly. | Skip Phases 4, 5, 6 (plan). Implement (Phase 7) → /verify (Phase 8). |
| 2 | Run Phase 4. Skip Phase 5. | Run Phase 4 (spec), 6 (plan), 7 (implement), 8 (/verify). Skip Phase 5 grill. |
| 3 | Run Phases 4 + 5. | Run Phases 4, 5, 6, 7, 8. Full pipeline. |

The current inline pre-save checklist is **deleted**. `/verify` covers location/wiring/content checks for all tiers. Any release-prereq items (README row, version bump) that `/verify` doesn't already cover get folded into the `/verify` invocation context as a checklist hint passed via the seed brief — no parallel inline checklist remains.

## User Journeys

### Primary Journey — Tier 2 enhancement skill creation

1. Author runs `/pmos-toolkit:create-skill make a skill that critiques markdown links`.
2. Phase 1 captures intent → Phase 2 auto-tiers as Tier 2 → Phase 3 interview.
3. Phase 4 writes spec; user approves.
4. **NEW Phase 6:** `/create-skill` invokes `/pmos-toolkit:plan` with the spec path; spec status moves `approved → planned`. User approves the plan doc.
5. Phase 7 implements SKILL.md against the plan.
6. **NEW Phase 8:** `/create-skill` invokes `/pmos-toolkit:verify`; lint/tests/review surface findings; user dispositions; status moves to `verified`.
7. Phase 9 captures learnings. Done.

### Primary Journey — Tier 3 feature skill creation

1. Same as Tier 2 through Phase 4 spec.
2. Phase 5 runs `/grill`; status `draft → grilled`.
3. **NEW Phase 6:** `/plan` runs against the grilled spec.
4. Phase 7 implement → Phase 8 `/verify` → Phase 9 learnings.

### Primary Journey — Tier 1 quick skill creation

1. Author runs `/create-skill add a one-shot diff summarizer`.
2. Tier 1 → skip Phases 4 (spec), 5 (grill), 6 (plan).
3. Phase 7 implement directly from interview.
4. **NEW Phase 8:** `/verify` runs (mandatory). User dispositions any findings.
5. Phase 9 learnings.

### Error Journeys

- **`/plan` fails or user cancels** — `/create-skill` halts; offer Continue (skip plan, log warning) / Retry / Abort. Default Retry. Same pattern as `/update-skills` Phase 8.
- **`/verify` surfaces blocker findings** — author dispositions in `/verify`'s Findings Presentation Protocol; if blocker is unresolved, `/create-skill` does NOT mark spec status `verified`; status stays `implemented` and the skill is flagged as not-ready in Phase 8 output.

### Empty States & Edge Cases

| Scenario | Condition | Expected Behavior |
|---|---|---|
| User invokes `/create-skill` with `--tier 1` for a skill that interview signals as Tier 2 | Tier override | Honor `--tier 1` per current Phase 2 contract; skip Phases 4/5/5.5; still run Phase 6.5 `/verify`. |
| `/plan` skill is unavailable (older toolkit) | Missing dependency | Phase 6 surfaces a one-paragraph warning in spec §14 and offers Continue / Abort, mirroring how Phase 5 handles missing `/grill`. |
| `/verify` skill is unavailable | Missing dependency | Phase 8 surfaces a hard error: skill creation cannot complete without verification. User must install/upgrade `/verify` or explicitly accept-as-risk via a one-time override. |
| Author re-runs `/create-skill` with same skill name | Resume / re-author | Out of scope — current `/create-skill` already handles slug bumping; no new behavior required. |

## Design Decisions

| # | Decision | Options Considered | Rationale |
|---|---|---|---|
| D1 | `/plan` runs at Tier 2+. | (a) Tier 2+; (b) Tier 3 only; (c) all tiers. | Match `/update-skills` Phase 8 contract. T1 is one-shot and skips spec, so it has nothing for `/plan` to consume. |
| D2 | `/plan` runs **after** `/grill`. | (a) After grill; (b) before grill. | Plan should consume the grill-hardened spec, not a draft that may flip in grill. Mirrors `/update-skills` order. |
| D3 | `/verify` is mandatory at all tiers. | (a) Optional T1; (b) mandatory all tiers; (c) skip T1. | User explicitly chose mandatory all tiers. T1 still benefits from lint/test pass even without spec/plan. |
| D4 | Pre-save inline checklist (current Phase 7) is **deleted** entirely. | (a) Drop entirely; (b) keep as T1 fallback; (c) keep at all tiers. | Since `/verify` is mandatory at all tiers (D3), the inline checklist is fully redundant. Single source of truth for verification = `/verify`. |
| D5 | Spec status flow extended to include `planned` and `verified`. | (a) Reuse `approved`; (b) add granular states. | Granular states make resume mode and skip checks unambiguous, matching how spec/grill statuses already work. |
| D6 | Out of scope: `/update-skills` changes (F3). | (a) Apply F3; (b) skip — already-handled. | `/update-skills` Phase 8 already invokes both. User confirmed Skip in triage Phase 6. |

## Success Metrics

| Metric | Baseline | Target | Measurement |
|---|---|---|---|
| % of Tier 2+ `/create-skill` runs that produce a `03_plan.md`-equivalent artifact | 0% | 100% | Audit the next 5 `/create-skill` Tier 2+ sessions; check for plan doc in the feature/spec folder. |
| % of `/create-skill` runs (all tiers) that produce a `/verify` artifact | 0% | 100% | Audit next 5 `/create-skill` sessions; check for verify report. |
| Author-reported "shipped a skill without verifying" incidents | unknown (anecdotal) | 0 in 90 days post-ship | Post-ship retro / `/retro` paste-back review. |

## Research Sources

| Source | Type | Key Takeaway |
|---|---|---|
| `plugins/pmos-toolkit/skills/create-skill/SKILL.md` | Existing code | Current pipeline: intent → tier → interview → spec → grill → implement → checklist → learnings. No /plan, no /verify. |
| `plugins/pmos-toolkit/skills/update-skills/SKILL.md` Phase 8 | Existing code | Reference pattern: requirements → spec → [grill] → plan → execute → verify, with verify non-skippable per skill. This is the pattern to copy. |
| `~/.pmos/learnings.md` `/create-skill` entries | Internal learnings | Path resolution should delegate to `_shared/pipeline-setup.md`; tier-3 grill on orchestrator skills has high yield. Both apply here. |
| Triage doc `00_triage.md` (this folder) | Source of feedback | F1, F2 approved; F3 skipped. Tier 3 confirmed by user. |

## Open Questions

| # | Question |
|---|---|
| 1 | Should the new Phase 6.5 `/verify` use the `--for-skill` mode if `/verify` exposes one, or the generic mode? (Defer to spec phase — `/verify` SKILL.md will dictate.) |
| 2 | Does `/plan` accept a spec path as input the same way `/update-skills` passes it, or does it need a wrapper? (Defer to spec phase — verify by reading `/plan` SKILL.md.) |
| 3 | Should Phase 8 `/create-skill` report a final pipeline-status table (mirroring `/update-skills` Phase 8) so the author sees which stages ran? Recommended yes; confirm in spec. |

---

**For UX friction analysis, run `/msf-req` after this doc is committed.** (Optional — skill is internal-tooling-only, low end-user-friction risk.)
