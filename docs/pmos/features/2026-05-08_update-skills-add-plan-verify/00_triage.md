<!-- pmos:update-skills-triage v=1 -->
# Triage — add /plan and /verify to skill-creation pipeline

**Source:** inline feedback via slash arg
**Raw input:** "In both /create-skill and /update-skills there is no plan and verify step in the pipeline. We should add that"
**Affected skills:** `/pmos-toolkit:create-skill`, `/pmos-toolkit:update-skills`

## Out-of-scope skill mentions

None.

## Findings

| # | Skill | Severity | Finding | Evidence | Proposed fix (from feedback) |
|---|---|---|---|---|---|
| F1 | create-skill | friction (inferred) | Pipeline has no `/plan` step — goes directly from spec (Phase 4/5) to implement (Phase 6). | SKILL.md L70-128: Phase 4 spec → Phase 5 grill (Tier 3) → Phase 6 implement, no /plan invocation. | Insert /plan invocation between spec and implement (Tier 2+). |
| F2 | create-skill | friction (inferred) | Pipeline has no `/verify` step — Phase 7 is a pre-save checklist, not the multi-agent /verify gate. | SKILL.md L131-133: Phase 7 "Pre-save checklist" walks the inline checklist; never invokes /verify. | Add a /verify invocation after implement, before learnings capture. |
| F3 | update-skills | friction (inferred) | User asserts /update-skills has no plan+verify steps. | SKILL.md Phase 8 already lists: requirements → spec → [grill] → **plan (Tier 2+)** → execute → **verify (non-skippable)**. | **already-handled** — verify with user before applying. |

## Critique

| # | Already handled? | Classification | Recommendation | Scope |
|---|---|---|---|---|
| F1 | No — /create-skill skips /plan entirely. | UX-friction / new-capability | **Apply** — add Phase 5.5 `/plan` invocation (Tier 2+), gated like the existing spec phase (status: planned → approved). | medium |
| F2 | No — Phase 7 is an inline checklist, not the /verify skill. | UX-friction / new-capability | **Apply** — add Phase 7.5 `/verify` invocation after Phase 6 implement, non-skippable for Tier 2+, optional for Tier 1. | medium |
| F3 | **Yes** — /update-skills Phase 8 already invokes /plan (Tier 2+) and /verify (non-skippable). | n/a | **Skip** — recommend confirming with user that this was a mis-read; no change needed. | n/a |

## Disposition log

- F1: **Apply as recommended** (add /plan invocation Phase 5.5 in /create-skill, Tier 2+).
- F2: **Apply as recommended** (add /verify invocation after Phase 6 in /create-skill, non-skippable Tier 2+, optional Tier 1).
- F3: **Skip — already handled** (/update-skills Phase 8 already invokes /plan and /verify).

## Approved changes by skill

### /create-skill
- F1: Insert a new phase between Phase 5 (grill) and Phase 6 (implement) that invokes `/pmos-toolkit:plan`, gated for Tier 2+. Spec status flow becomes `draft → grilled (T3) → planned → approved`. Tier 1 skips.
- F2: After Phase 6 implement, before Phase 7 pre-save checklist (or merge them), invoke `/pmos-toolkit:verify`. Non-skippable for Tier 2+; optional for Tier 1.

### /update-skills
- (no changes)

## Per-skill tier table

| skill | scope | recommended tier | rationale |
|---|---|---|---|
| /create-skill | adds 2 phases that invoke pipeline skills (/plan, /verify); changes pipeline integration | **Tier 3** | Pipeline integration + modifying multi-phase orchestrator → grill recommended. |
| /update-skills | none | n/a | F3 skipped. |

## Pipeline status

| skill | phase | status | artifact path | timestamp |
|---|---|---|---|---|
| /create-skill | requirements | completed | docs/pmos/features/2026-05-08_update-skills-add-plan-verify/01_requirements.md | 2026-05-08 |
| /create-skill | spec | completed | docs/pmos/features/2026-05-08_update-skills-add-plan-verify/02_spec.md | 2026-05-08 |
| /create-skill | grill | completed | inline grill report (3 questions, 2 spec edits) | 2026-05-08 |
| /create-skill | plan | completed | docs/pmos/features/2026-05-08_update-skills-add-plan-verify/03_plan.md | 2026-05-08 |
| /create-skill | execute | completed | git HEAD (5 files, +56/-54) | 2026-05-08 |
| /create-skill | verify | in-progress | (pending) | 2026-05-08 |
