<!-- pmos:update-skills-triage v=1 -->
# /update-skills triage — /diagram handoff contract (v0.14.0)

**Source:** `/Users/maneeshdhabria/Desktop/Projects/pmos/pmos-content/.claude/skills/rewrite/specs/v0.14.0-diagram-handoff-contract.md` (forward-looking spec from /rewrite v0.14.0 author; not a /retro paste).
**Filter:** `--skill /diagram` (implicit from invocation arg).
**Out-of-scope skills:** none — single-skill update.

## Context note

The `feature/non-interactive-mode` branch was merged into main between session start and Phase 1 of this skill (user confirmed). Re-triage was done against post-merge main (HEAD `b506eae`, pmos-toolkit 2.28.0). Commit `f1df98d feat(T22): non-interactive rollout for /diagram` ships the `--non-interactive` flag via the toolkit-wide OQ-buffer protocol, which materially satisfies spec §1.

## Findings (parsed)

| id | severity | skill | finding | proposed-fix |
|----|----------|-------|---------|--------------|
| F1 | blocker | /diagram | Add `--non-interactive` flag bypassing 5 AskUserQuestion calls; record assumptions in sidecar | Spec §1 — auto-pick Recommended option in 5 named phases |
| F2 | blocker | /diagram | Add `--on-failure {drop\|ship-with-warning\|exit-nonzero}` flag gating Phase 6.5 disposition; default `exit-nonzero` when `--non-interactive` set | Spec §2 — exit 3 on drop, exit 4 on exit-nonzero, exit 0 on ship-with-warning |
| F3 | nit | /diagram | `--out` already supported per spec | No action |
| F4 | nit | /diagram | `--source` already supported per spec | No action |
| F5 | nit | /diagram | `--theme` already supported per spec | No action |
| F6 | nit | /diagram | Idempotent re-run on resume already supported | No action |

## Critique

| id | already-handled? | classification | recommendation | scope |
|----|------------------|----------------|----------------|-------|
| F1 | YES (T22 / OQ-buffer) | UX-friction | **Skip** — existing impl satisfies intent; auto-picks Recommended, defers tagged ones, sidecar already records `concept`/`alternativesConsidered`/`assumptions`. /rewrite v0.14.0 should consume the OQ-buffer sidecar fields instead of asking /diagram to re-implement spec §1 verbatim. | small |
| F2 | NO | new-capability | **Apply** — net-new flag, gates Phase 6.5 disposition + exit codes, ~30–60 lines SKILL.md + tests | small |
| F3–F6 | YES | nit | **Skip** — spec author confirms no action needed | trivial |

## Disposition log

User approved via `AskUserQuestion` Phase 6 batch:
- F1: **Skip** (already-handled)
- F2: **Apply as recommended**
- F3–F6: **Skip** (no action needed per spec)
- Tier: **Tier 1** (small flag, no new phases, no new reference files)

No findings deferred to backlog.

## Approved changes by skill

### /diagram
- **F2 — `--on-failure` flag**
  - Add `--on-failure {drop|ship-with-warning|exit-nonzero}` to `argument-hint`.
  - Phase 0: parse the flag. Default value depends on mode:
    - non-interactive mode → default `exit-nonzero`
    - interactive mode → flag is ignored (Phase 6.5 AskUserQuestion path remains the source of truth).
  - Phase 6.5: when `mode == non-interactive`, **bypass** the AskUserQuestion and dispatch on `--on-failure`:
    - `drop`: do not write SVG, do not write sidecar, exit 3, print one-line reason to stderr.
    - `ship-with-warning`: existing prose-fallback path (write SVG with leading `<!-- WARNING: ... -->` comment), exit 0.
    - `exit-nonzero`: do not write SVG, exit 4, print one-line reason to stderr.
  - Document the exit-code contract in SKILL.md prose so /rewrite (and other callers) can rely on it.
  - Add a regression test per disposition value (3 tests) verifying exit codes + file presence.

## Per-skill tier

| skill | tier | rationale |
|-------|------|-----------|
| /diagram | Tier 1 | Single flag, no new phase, no reference-file additions. Bug-fix-shaped scope. /spec and /grill skipped. |

## Pipeline status

| skill | phase | status | artifact path | timestamp |
|-------|-------|--------|---------------|-----------|
| /diagram | requirements | completed | docs/pmos/features/2026-05-08_update-skills-diagram-on-failure/01_requirements.md | 2026-05-08 |
| /diagram | plan | completed | docs/pmos/features/2026-05-08_update-skills-diagram-on-failure/03_plan.md | 2026-05-08 |
| /diagram | execute | completed | docs/pmos/features/2026-05-08_update-skills-diagram-on-failure/execute/task-{01..05}.md | 2026-05-08 |
| /diagram | verify | in-progress | — | — |
