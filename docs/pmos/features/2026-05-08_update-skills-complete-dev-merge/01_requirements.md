# /complete-dev — rebase-default + parallel-worktree version-bump fix — Requirements

**Date:** 2026-05-08
**Last updated:** 2026-05-08
**Status:** Approved
**Tier:** 2 — Enhancement

## Review Log

| Loop | Findings | Changes Made |
|------|----------|-------------|
| 1 | F-A: recovery recipe bash too implementation-y. F-B: OQ#1 caveat could be decided. F-C: speculative-bump journey missing abort-mid-ceremony trigger. | F-A skipped (user kept as-is). F-B applied (caveat moved to D4 rationale + slated for SKILL.md anti-pattern; OQ#1 removed). F-C applied (trigger noted on the alternate journey). User confirmed no further concerns. |

## Problem

Two friction points in `/complete-dev` produce avoidable rework when shipping pmos-toolkit work from this repo:

1. **Phase 3 defaults to a merge commit** (`Merge into main (fast-forward if possible, else --no-ff merge commit)` is `(Recommended)`), but the user's preferred history shape is **linear**. Every release ceremony today requires the user to manually pick option 2 (`Rebase onto main, then fast-forward`).
2. **Phase 9 reads the version-bump baseline from the feature branch**, with no awareness of what `origin/main` shipped while the user was working. When two worktrees branched off the same SHA both bump `2.27.0 → 2.28.0`, the second push trips `.githooks/pre-push` (which compares `local_v` against `remote_v` at the merge base and rejects equality). The user then has to edit both `plugin.json` files up to `2.29.0`, re-commit, and re-push — every collision costs 1–2 minutes plus lost context.

### Who experiences this?

- **Repo owner running `/complete-dev`** as the terminal stage of the pipeline (this repo's typical workflow). Single user, multiple parallel worktrees under `.worktrees/`.

### Why now?

- The repo has crossed into **routine multi-worktree usage** (recent merges 2.24.0 → 2.27.0 stacked across worktrees show this is no longer a corner case — 8b9ffe3's commit message literally calls out "re-bump 2.25.0 → 2.26.0 to stack above local main's /create-skill release").
- The pre-push hook **catches** the collision but only at push time, after the ceremony is mostly done — moving detection earlier saves a full re-tag + re-push cycle.
- Rebase preference has been validated (linear history makes `/changelog` cleaner — no merge commits to filter out).

## Goals & Non-Goals

### Goals

- **G1.** `/complete-dev` Phase 3 defaults to **rebase-onto-main + fast-forward**, with merge as a fallback only when rebasing would be unsafe — measured by: zero manual "pick option 2" interactions in the next 5 routine `/complete-dev` runs.
- **G2.** Parallel-worktree version-bump collisions are **detected before commit, not at push time** — measured by: when a stale-base bump is staged, the user sees a concrete "rebase first; main is at vX.Y.Z" message *during Phase 9*, not a pre-push hook rejection.
- **G3.** Recovery from a stale speculative bump (already-committed `plugin.json` change on a now-stale base) has a **named recipe** the user can follow — measured by: the failure mode produces a one-line pointer to the recipe, not improvised remediation.
- **G4.** Rebase safety guard prevents accidental SHA-rewrite of branches others may have based work on — measured by: when the feature branch has an upstream whose tip differs from local, rebase is downgraded to merge with a one-line explanation.

### Non-Goals

- NOT changing the **pre-push hook** (`.githooks/pre-push`) — it stays as the last line of defence; this work moves detection earlier and friendlier.
- NOT changing rebase-vs-merge defaults for **non-pmos-toolkit repos that adopt this skill** — the default flip is general (rebase preference is widespread for solo workflows), but the safety guard must be conservative enough to be safe in shared-branch repos out of the box.
- NOT auto-resolving rebase conflicts — same rule as merge conflicts today: STOP and ask user.
- NOT introducing a new version-bump strategy (changesets, semantic-release, etc.) — those are larger product decisions and out of scope for this enhancement. The goal is to minimise friction in the **current** Phase-9-bumps-the-version model.
- NOT changing `--skip-deploy` / `--no-tag` / `--skip-changelog` flag semantics.

## Solution Direction

Three coordinated changes inside `/complete-dev`:

### A. Phase 3 default flip (with safety guard)

Reorder Phase 3's `AskUserQuestion` options so **rebase-onto-main + FF is `(Recommended)`** and merge becomes option 2. Before presenting the prompt, run a cheap **shared-branch guard**:

```
guard passes (rebase is safe) when EITHER:
  (a) feature branch has no upstream (git rev-parse --abbrev-ref @{upstream} fails), OR
  (b) upstream exists AND local SHA equals remote SHA (after `git fetch <remote> <branch>`)
```

When the guard fails (upstream tip diverged from local — implies someone else may have pulled past where we are), the prompt's `(Recommended)` flips back to `--no-ff` merge with a one-line reason in the question text:

> "Branch `<name>` has been pushed and remote tip differs from local — rebase would rewrite SHAs others may have. Recommended: --no-ff merge."

Rebase still appears as a manual option (with a `(WARNING: rewrites SHAs)` suffix) for the user who knows nobody pulled it.

### B. Phase 9 baseline reorder + collision pre-flight

Phase 9 today reads `plugin.json` *from the working tree*. After the change, Phase 9 runs in two steps:

1. **Sync main reference.** `git fetch origin main` (or whatever the configured upstream of `main` is — re-use Phase 0's remote enumeration). Read `origin/main:plugins/pmos-toolkit/.claude-plugin/plugin.json` as `main_v`.
2. **Pre-flight collision check.** Compare `local_v` (working tree) against `main_v`:
   - **Identical** → no parallel bump happened; proceed normally; the bump applies on top of `main_v` → `main_v + 1`.
   - **`local_v > main_v`** → feature branch already bumped speculatively. Two cases:
     - The bump is **stale** if `main_v >= local_v_at_branch_point` (a parallel worktree shipped between branch creation and now). Surface the stale-bump warning (see G3).
     - The bump is **fresh** if `main_v == local_v_at_branch_point` (no parallel ship). Allow proceed.
   - **`local_v < main_v`** → impossible if Phase 3 actually rebased; surface as "did Phase 3 succeed? main is ahead of local on `plugin.json`" warning.

Because Phase 3 (after change A) defaults to rebase-onto-main, by the time Phase 9 runs the working tree's view of `plugin.json` is already main-aware in the common case — the pre-flight is a safety net for "user picked merge", "user skipped Phase 3 because already on main", and "speculative bump committed earlier on the feature branch".

### C. Stale-bump recovery recipe

When the pre-flight detects a stale speculative bump, it presents:

```
question: "Stale version bump detected: feature branch has plugin.json at vX.Y.Z, but main shipped vX.Y.W (W > the version you branched from). What now?"
options:
  - Revert the speculative bump and re-bump from main (Recommended) — auto-runs the recovery recipe
  - Keep going anyway (will likely fail pre-push hook)
  - Cancel — let me investigate manually
```

Recovery recipe (referenced from a new `reference/version-bump-recovery.md`):

1. Restore both `plugin.json` files to their state at `origin/main` (`git checkout origin/main -- plugins/pmos-toolkit/.claude-plugin/plugin.json plugins/pmos-toolkit/.codex-plugin/plugin.json`).
2. Re-run Phase 9's bump prompt (which now reads `main_v` as baseline).
3. Apply, validate JSON, restage. Phase 11 will commit the corrected bump.

## User Journeys

### Primary Journey — solo branch, no collision (the common case)

1. User: `/complete-dev` from feature branch `add-foo-skill`.
2. Phase 0 reports clean state, ahead of origin.
3. Phase 1 `/verify` gate → "Already ran".
4. Phase 3 runs the shared-branch guard: feature branch has no upstream → guard passes → recommends `Rebase onto main + FF`. User accepts default.
5. Rebase + FF succeed; cwd switches to root main checkout.
6. Phases 4–8 proceed unchanged.
7. Phase 9 runs the new pre-flight: `main_v == local_v == 2.27.0` → no collision → asks bump kind. User picks `Patch`.
8. Bump applied to both manifests as `2.27.1`.
9. Phases 11–17 commit, tag, push.

### Alternate Journey — parallel worktree, fresh bump on stale main

1. User opened worktree A at SHA where `main_v = 2.27.0`. Made changes; ran `/complete-dev`; shipped `2.28.0`.
2. User now in worktree B (also at SHA where `main_v = 2.27.0`); made unrelated changes; runs `/complete-dev`.
3. Phase 3 guard: branch B has no upstream → rebase. **Rebase onto main pulls in worktree A's `2.28.0` bump** — the rebase resolves the version conflict if A's bump was the only change to `plugin.json`, otherwise STOP-and-ask (existing rebase-conflict behaviour).
4. Phase 9 pre-flight: `main_v = 2.28.0`, `local_v = 2.28.0` (after rebase) → no collision → bump prompts. User picks `Patch` → `2.28.1`.

### Alternate Journey — speculative bump committed before rebase

> Also reachable when `/complete-dev` was aborted *after* Phase 11 commit but *before* successful push (Phase 15) — the bump commit lingers on the feature branch even though the ceremony didn't complete.

1. User in worktree B started `/complete-dev`, picked `Patch` bump → committed `2.28.0`. Push fails (pre-push hook detects worktree A already shipped `2.28.0`). User aborts mid-ceremony.
2. User re-runs `/complete-dev`. Phase 3 rebases → conflict in `plugin.json`. STOP and ask.
3. User aborts rebase (out of scope). Re-runs `/complete-dev` with intent to use the new recovery flow:
4. Phase 9 pre-flight: `main_v = 2.28.0`, `local_v = 2.28.0` (committed earlier on stale base). Stale-bump detected. User picks `Revert and re-bump from main`.
5. Recipe runs: checkout `origin/main -- plugin.json`s; bump prompt re-runs against `2.28.0` → `2.28.1` → 2.29.0` (user picks). Continues.

### Alternate Journey — branch is shared (rebase guard fires)

1. User pushed `feature-collab` to origin earlier for review. Coworker pulled it.
2. User: `/complete-dev`.
3. Phase 3 guard: upstream exists, `git fetch origin feature-collab`, local SHA == remote SHA → guard passes (in this scenario user hasn't been pulled past, so technically rebase-safe by guard's rule).

   **Edge case worth surfacing in Open Questions:** the guard checks "remote tip == local tip" which is a *necessary* but not *sufficient* test for "no one has based work on this". A stricter heuristic would require knowledge of who pulled the branch, which git doesn't provide. The guard is conservative enough for solo workflows but documented as a known limitation.

4. If remote tip differs (someone pushed a fixup), guard fails → recommend `--no-ff` merge with one-line reason.

### Error Journeys

- **Rebase conflict on plugin.json** (parallel-worktree case) → STOP, surface conflict, ask user (existing Phase 3 conflict-handling behaviour applies; no auto-resolution).
- **`git fetch` fails** in Phase 9 pre-flight (network / auth) → fall back to "skip pre-flight" with a one-line warning ("could not fetch origin/main; pre-push hook will catch any version collision"). Do not block the ceremony.
- **`origin/main:plugin.json` missing or unparseable** → fall back to skip-pre-flight; warn.

## Design Decisions

| # | Decision | Options Considered | Rationale |
|---|----------|--------------------|-----------|
| D1 | Default Phase 3 to rebase-onto-main + FF when guard passes; keep merge as fallback. | (a) Always default to rebase. (b) Always default to merge (today's behaviour). (c) Conditional default with shared-branch guard (chosen). | (a) is unsafe for shared branches; (b) is current friction. (c) flips the common-case ergonomics without sacrificing safety in shared-branch repos. |
| D2 | Pre-flight collision check lives in Phase 9, not Phase 0. | (a) Phase 0 (early). (b) Phase 9 (chosen). (c) Both. | Phase 0 runs before Phase 3's rebase; the post-rebase state is what matters for the bump. Running the check in Phase 9 means it sees the correct baseline. A cheap Phase 0 hint ("local plugin.json differs from origin/main") is a nice-to-have but not required for G2. |
| D3 | Stale-bump recovery is interactive, not automatic. | (a) Auto-revert speculative bump silently. (b) Show recipe + ask (chosen). (c) Just refuse to proceed. | (a) destroys user work without consent. (c) leaves the user stuck. (b) explains what happened, offers the fix, gets explicit consent. |
| D4 | Shared-branch guard uses `local SHA == remote SHA` test; document the necessary-but-not-sufficient caveat in `/complete-dev` SKILL.md anti-patterns rather than nagging at runtime. | (a) Check if branch has any upstream (too conservative — every pushed branch fails). (b) Check `local SHA == remote SHA` (chosen). (c) Track who-pulled-what (impossible in git). | (b) is the most permissive correct test — implies the user hasn't pushed anything new since the last sync, so coworkers are at most "at the same SHA we're about to rewrite", which is recoverable on their end. The "coworker pulled, then both pushed independently" case still slips through; documented as an anti-pattern entry rather than runtime warning to avoid notification fatigue (resolves former OQ#1). |
| D5 | Don't introduce a new flag (`--force-merge`, `--force-rebase`). | (a) Add escape-hatch flags. (b) Just rely on the AskUserQuestion options (chosen). | The interactive prompt already lets the user pick non-default options. Adding flags expands the surface area without unlocking new behaviour for routine use. |
| D6 | Pre-flight failure on network/auth issues skips, doesn't block. | (a) Skip with warning (chosen). (b) Block until fetch succeeds. | The pre-push hook is a hard gate later; the pre-flight is best-effort. Blocking on transient network issues would be more friction than the bug we're fixing. |

## Open Questions

| # | Question |
|---|----------|
| 1 | When Phase 3 rebases onto main and pulls in a parallel worktree's `plugin.json` bump cleanly (no conflict because feature branch never touched plugin.json), should Phase 9 still announce "I noticed the rebase brought in vX.Y.Z from another worktree" or stay silent? |
| 2 | Should the speculative-bump detection look beyond this commit's `plugin.json` change? E.g., catch the case where the user manually edited `plugin.json` outside the Phase 9 flow on a stale base. |

---

**Next step:** When ready, run `/spec` to create the detailed technical specification.
