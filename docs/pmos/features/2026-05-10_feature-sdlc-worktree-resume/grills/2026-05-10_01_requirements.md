# Grill Report — 01_requirements.md

**Depth:** standard  •  **Questions asked:** 6  •  **Date:** 2026-05-10

## Resolved

| # | Branch | Question | Disposition |
|---|---|---|---|
| Q1 | D11 + D2 | Handoff exit semantics when EnterWorktree fails | Exit 0 + explicit `Status: handoff-required` chat line. Preserves /loop /schedule wrapper semantics. → D11 extended |
| Q2 | D2 extension | What happens to `--no-worktree` mode in the rework | Full bypass: no `git worktree add`, no `EnterWorktree`, no drift check; state at `./.pmos/feature-sdlc/state.yaml` in cwd. → D12 added |
| Q3 | D9 refinement | Cleanup edge with gitignored state.yaml + untracked files | Strict `git worktree remove` (no --force); refuse on any untracked or modified tracked file. Explicit `--force-cleanup` flag opts in. State.yaml excluded from dirty check. → D13 added |
| Q4 | (atomicity) | State.yaml write atomicity under retry/resume | temp+rename in same dir, no advisory lock. Reuses pipeline-consolidation FR-31. Per-worktree model already prevents cross-process writes. |
| Q5 | D10 extension | Repeat-slug worktree collision (orphan-dir case) | Unified pre-flight: branch + worktree path + `git worktree list` registration; merged Use-existing / Pick-new (-N suffix) / Abort dialog. → D14 added |
| Q6 | OQ #5 | Post-cleanup terminal cwd state in /complete-dev | Try `ExitWorktree(action=keep)` first; on no-op (resumed-from-worktree session), proceed with `git worktree remove` and print `cd <root-main-path>` fallback. → D15 added; OQ #5 closed |

## Open / Deferred

- **OQ #1** (staleness flagging in `/feature-sdlc list`) — UX polish; ship without and add if friction surfaces.
- **OQ #2** (legacy v1/v2 worktree handling in `/feature-sdlc list`) — defer to /spec; expected disposition: show with `(legacy v1/v2)` marker, don't crash.

## Closed implicitly (by other answers)

- **OQ #3** (running /feature-sdlc from already-in-worktree session): EnterWorktree errors per its contract → handoff path (D2/D11) fires naturally. No special detection logic.
- **OQ #4** (pre-flight drift check in child skills): EnterWorktree's effect is session-scoped and cwd is inherited by subagents (spike-confirmed). Only `/feature-sdlc` and `/feature-sdlc --resume` need explicit drift check.

## Gaps surfaced (folded into Decisions table)

- **G1** — D11 needs explicit `Status: handoff-required` chat line specification.
- **G2** — D2 needs `--no-worktree` subsection.
- **G3** — D9 needs `--force-cleanup` flag named + state.yaml-excluded-from-dirty rule.
- **G4** — D10 / Phase 0.a needs unified pre-flight expanded to cover orphan worktree dirs.
- **G5** — /complete-dev Phase 4 needs ExitWorktree-then-remove sequence with no-op fallback.

All five gaps now captured in the Decisions table as D11 (extended), D12, D13, D14, D15.

## Recommended next step

Advance to `/spec`. The grill produced refinements to existing decision rows, not new requirement areas. The doc went from 11 decisions to 15; OQs went from 5 (3 open, 2 closed by grill) effectively reducing genuine open scope.
