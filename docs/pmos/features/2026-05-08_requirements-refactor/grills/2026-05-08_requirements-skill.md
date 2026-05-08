# Grill Report — `skills/requirements/SKILL.md` (pmos-toolkit 2.17.0)

**Date:** 2026-05-08
**Depth:** deep
**Questions asked:** 27 (21 grill + 6 pipeline-setup design)
**Target:** `/Users/maneeshdhabria/.claude-personal/plugins/cache/pmos-toolkit/pmos-toolkit/2.17.0/skills/requirements/SKILL.md`

---

## Part 1 — Grill dispositions on `/requirements` skill

### Tier detection & flow

- **Tier auto-detection** → add explicit signals (surface count, new data model, new persona, reversibility); agent picks highest-tier signal fired.
- **Decomposition trigger** → fire only when all 3 hold: different user roles, independently shippable, non-overlapping ACs. Otherwise treat as single Tier 3.
- **Task list ordering** → confirm/override tier *before* task creation, not after.
- **Tier 2 vs Tier 3 task list collision** → Tier 3 gains explicit additional tasks (UX Analysis, Success Metrics, Alternate/Error journey mapping).

### Templates

- **Tier 1 missing sections** → add optional Decision + Open Questions.
- **Tier 1 research tracking** → add lightweight `Investigated` list (file paths + issue links).
- **Tier 2 metrics** → goals require `— measured by [signal]` suffix.
- **Tier 2 "Why now?"** → require as explicit subsection.
- **Tier 2 UX lens** → stay lean; handoff message points to `/msf` for depth.
- **Goals vs AC boundary** → add explicit guideline. Tier 1 keeps AC because it bypasses spec.
- **Status field** → lifecycle: Draft → In Review → Approved. Add "Last updated" line that refreshes on each commit.
- **Open Questions columns** → default 2-col (`#`, `Question`). Expand to Owner / Needed By only when stakeholder/deadline signals fire.

### Process

- **Acid test reader** → dual test: designer can evaluate options + spec author has no unresolved why/what.
- **Diagrams "ZERO impl detail" line** → user-observable only (screens/journeys/states), not internal architecture.
- **Min 2 review loops** → drop. Replaced by 6-gate exit (both lenses run + lens findings logged + dispositions captured + explicit user confirm + decision-coverage + zero open clarifications).
- **Phase 5/6 confirmation overlap** → merge Phase 6 polish checks into final Phase 5 loop. One confirmation gate.
- **Brainstorm contradiction** → batch related questions only; one topic per `AskUserQuestion` call.
- **Question lists** → become coverage checklists, not scripts. Ask only where gaps exist.
- **Brainstorm stop condition** → tier-based: T1 stops at Problem+Cause+Fix; T2 at Problem+Goals+Direction+1 journey; T3 when all mandatory sections have a non-placeholder answer or Open Question entry.
- **Ambiguity gate** → replace "two engineers interpret differently" with concrete heuristics (no "etc.", quantified claims, no orphan should/might or pronouns).
- **Decision count "3+ for Tier 3"** → drop; require coverage instead (every research/brainstorm choice → Decision row OR Open Question).

### Research

- **Subagent return schema** → fixed structure (summary bullets ≤5, sources table, flagged gaps).
- **Industry research bias** → drop named defaults (Linear/Stripe/Notion); pick from workstream/repo domain or ask user.
- **Update-path stale research** → read prior Sources table; refresh only delta-relevant areas.

### Pipeline & file ops

- **Phase 4 silent overwrite** → commit any dirty `01_requirements.md` before overwriting.
- **Pipeline drift** → Phase 1 checks for downstream `02_spec.md` / `03_plan.md`; warn before write.
- **Backlog bridge edges** → guard + idempotent: only call `/backlog set` when doc-written + commit-succeeded; re-runs log overwrite history.
- **Wireframes link rule** → conditional ("if wireframes exist, link them; else describe at behavior level only").
- **Commit message** → conditional add/update verb based on whether file existed at Phase 1 entry.
- **Tier 3 enhancer handoff** → handoff message lists `/creativity` and `/msf` as optional steps before `/spec`.
- **Phase 7 enrichment** → skip for Tier 1.

### First-run UX

- **First-run resolver flow** → consolidate workstream + slug + docs_path into a single prompt. Add explicit `feature_hint` derivation rule (extract most concrete noun phrase; inline prompt if unclear). `{docs_path}` documented as the parent of `{feature_folder}`.
- **Stale 1a/1b numbering in Phase 2** → renumber to 2a/2b.
- **Learnings consumption** → define entry schema; skill body wins on conflict; conflicts surfaced to user.
- **Phase 8 reflection audit** → require explicit `Learning: X` or `No new learnings because Y` line.

---

## Part 2 — Pipeline-setup design decisions

After the grill surfaced the convoluted/skip-prone shared resolver (`context-loading.md` + `feature-folder.md`), six follow-up design decisions resolved the new contract:

| # | Decision | Rationale |
|---|---|---|
| 1 | Silent auto-migrate on first read with logged diff | Zero-friction; logged diff means user can audit; `git mv`-only ensures reversibility. |
| 2 | `current_feature` lives in `.pmos/settings.yaml` (not separate state file or runtime mtime) | One file = one read = single source of truth; atomic updates; eliminates pointer-file class of staleness bugs. |
| 3 | Inline block defers slug rules / collision / migration / first-run to `pipeline-setup.md` with mandatory `Read` | Happy path is 100% inline; edges force a Read so agents can't infer their way around the contract. |
| 4 | First-run prompt is one consolidated `AskUserQuestion` covering docs_path + workstream + slug; MVP-shaped input suggests `mvp-v1` | One prompt = lowest friction; user sees full setup at once. |
| 5 | Read-Trigger uses MUST-language + failure-mode warning, no hooks or validator subagents | Sharper prose is the cheapest enforcement that doesn't require per-repo install. |
| 6 | Canonical block in `_shared/pipeline-setup.md` Section 0; verbatim copy in each SKILL.md; lint script enforces no drift | Removes "I'll just infer from the reference" failure mode; lint catches drift at CI; no runtime indirection. |

---

## Part 3 — Out-of-scope folding decisions

After the plan was drafted, four follow-up decisions on what to fold in vs. defer:

| # | Decision | Rationale |
|---|---|---|
| 7 | **Fold in** propagation of new Phase 0 block to `/spec`, `/plan`, `/execute`, `/verify`, `/wireframes`, `/prototype` (Phase E) | Avoids drift window; mechanical paste, not full grill refactor; ~1.5h. |
| 8 | **Fold in** deletion of `context-loading.md` and `feature-folder.md` (Phase F) once Phase E completes | Clean state; smaller lint/test surface; audit non-pipeline consumers first. |
| 9 | **Fold in** cross-skill reference audit of `/backlog`, `/msf`, `/creativity`, `/product-context` (Phase D additions) | Light-effort grep + path updates; keeps references consistent. |
| 10 | **Defer** full grill-style refactors of `/spec` and `/plan` | Each deserves its own grill session; bundling makes review unmanageable. |

---

## Open / Deferred

- None at grill close. Two implementation-time open questions surfaced in `01_requirements.md`:
  - OQ-1: Are there non-pipeline consumers of the old shared files? (Gates Phase F.) — Resolved: no, per user.
  - OQ-2: Lint-script block-boundary mechanism — HTML-comment markers vs. heading-match vs. magic-string. (Gates Phase C.)

---

## Gaps surfaced (cross-cutting)

- The skill's first-run handling is correct in shared resolvers but invisible at `requirements/SKILL.md` level. Future skills delegating to the same resolvers inherit the same multi-prompt friction unless a shared "consolidated first-run" pattern is built — which Phase A1 Section A now does.
- Several "exit gate" criteria across phases (Phase 5, Phase 6, Phase 8) repeat the user-confirmation motif. Worth a future `_shared/exit-gate.md` if `/spec` and `/plan` end up with similar gates.
- The skill is `user-invocable: true` mid-pipeline, so drift-warning logic (resolved here) needs propagation to `/spec`, `/plan`, `/execute` when their grills run — flag in those future sessions.

---

## Recommended next step

1. Implement per `03_plan.md` Phases A → F.
2. After implementation lands, run separate `/grill` sessions on `/spec` and `/plan`. Apply the pipeline-drift detection pattern from this grill to those skills as well.
3. No `/simulate-spec` follow-up needed for this work — the artifact is a skill file, not a spec. Real-repo invocation on test fixtures is the verification.
