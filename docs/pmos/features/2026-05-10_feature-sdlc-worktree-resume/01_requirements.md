# /feature-sdlc worktree + resume rework — Requirements

**Date:** 2026-05-10
**Last updated:** 2026-05-10
**Status:** Approved
**Tier:** 3 — Feature

## Problem

`/feature-sdlc` (v2.34.0) creates a git worktree via raw `git worktree add`, but the Claude Code session stays rooted in the directory it was launched from. The harness's session root — what `cwd` resolves to after `/compact`, `/resume`, or a fresh session — is the launch directory, not whatever directory a Bash `cd` last visited. `git worktree add` is invisible to the harness. **Subagents and many tool calls resolve relative paths against the session root, not the current Bash `cwd`, so worktree-local work silently drifts back to main.** State written to `<worktree>/.pmos/feature-sdlc/state.yaml` becomes unreachable on `--resume` because the resumed session is rooted in main with no pointer to the worktree.

This blocks two things:
- Running 2–3 features in parallel without ambiguity or per-resume disambiguation flags.
- Compaction-driven session restarts (which are unavoidable for context hygiene on long-running pipelines).

A third defect was discovered empirically while initializing this very pipeline: **`.pmos/feature-sdlc/state.yaml` is currently tracked in git**, so every new worktree inherits the previously-shipped feature's state. The per-worktree-state model is structurally broken until that file is gitignored and removed from tracking.

### Who experiences this?

- The repo owner running pmos-toolkit pipelines on their own machine.
- Specifically affects anyone trying to run `/feature-sdlc` end-to-end, since `/compact` is unavoidable for any non-trivial pipeline (Tier 3 routinely exceeds context budgets).

### Why now?

- Two recent shipped features (`pipeline-consolidation`, `update-skills-complete-dev-merge`) hit the resume friction directly. Prior pipelines bandaged with `--worktree <path>` flags or by manually `cd`-ing before `--resume`.
- `EnterWorktree` and `ExitWorktree` shipped as harness-native primitives, which makes a clean fix possible without symlink hacks.
- The `pipeline-consolidation` work surfaced the gitignore defect when a fresh worktree inherited stale state.

## Goals & Non-Goals

> Goals are observable user outcomes; engineering acceptance criteria belong in `/spec`.

### Goals

- **G1.** `/feature-sdlc --resume` (no flags) works after `/compact` or in a brand-new session — measured by: relaunching `claude` from inside a worktree and running `/feature-sdlc --resume` lands on the correct phase with no manual disambiguation, in 100% of cases tested.
- **G2.** 2–3 concurrent features can be in flight without collision, ambiguity, or per-resume disambiguation — measured by: each feature runs in its own worktree + terminal session; switching tabs is the only context switch; no global mutable state reads/writes that could collide.
- **G3.** Subagents dispatched inside a `/feature-sdlc` run reliably operate in the correct worktree — measured by: spike-style empirical confirmation (subagent `pwd`/`git rev-parse --show-toplevel` matches worktree path) plus all child skills (`/requirements`, `/spec`, etc.) writing artifacts to the right `feature_folder` without the orchestrator passing `cd <abs>` prefixes.
- **G4.** Stale worktree state from previously-shipped features no longer leaks into new pipelines — measured by: `.pmos/feature-sdlc/` is gitignored; `git ls-files .pmos/feature-sdlc/` is empty after this feature ships.
- **G5.** On successful merge, `/complete-dev` removes the feature worktree + branch, leaving the repo in the same shape it was before the feature started — measured by: `git worktree list` shows no entry for the feature; `git branch --list feat/<slug>` is empty.

### Non-Goals (explicit scope cuts)

- **NOT** introducing symlinks from main repo to worktree state — because: symlinks cannot resolve N parallel worktrees, and the user explicitly rejected this approach.
- **NOT** adding a `--worktree <path>` flag on `--resume` — because: the user explicitly rejected per-resume disambiguation friction; the canonical path is `cd <worktree> && claude --resume`.
- **NOT** building cross-repo discovery (e.g., a global `~/.pmos/feature-sdlc/index.yaml`) — because: the user accepted per-repo-only `git worktree list` discovery; cross-repo adds concurrency, GC, and lifecycle complexity for a feature most users won't hit.
- **NOT** migrating already-running pipelines started under the old model in flight — because: those pipelines have committed state.yaml in their branches; safest to let them finish under old rules. Pre-rework state files are detected and refused at runtime, not silently retro-fitted.
- **NOT** auto-stashing or auto-discarding uncommitted worktree edits during `/complete-dev` cleanup — because: stashes are easy to lose; refusing on a dirty tree is the safe default and matches existing `/complete-dev` pre-flight semantics.
- **NOT** ensuring `EnterWorktree`'s `cwd` shift survives `/compact` — because: the user accepted the "relaunch in worktree" friction as a one-time effort, which makes cross-session durability moot. The resumed session is launched FROM the worktree, so `cwd` is correct from t=0.

## User Experience Analysis

### Motivation

- **Job to be done:** Ship a single feature end-to-end through the pmos-toolkit pipeline, with `/compact` checkpoints between heavy phases (`/wireframes`, `/execute`, `/verify`), without losing the pipeline's place mid-run, and without the worktree drifting silently back to main.
- **Importance / Urgency:** Blocking — the current model fails on every Tier-3 pipeline because `/compact` is unavoidable past a certain context size. Workarounds (manual `cd`, `--worktree` flag, single-feature-at-a-time discipline) all add friction or prevent parallel work.
- **Alternatives:** (a) Skip `/compact` and tolerate degraded performance until completion (impractical for Tier 3). (b) Manually `cd` to worktree before each `--resume` (works but easy to forget; silently drifts when forgotten). (c) Run the pipeline without worktrees via `--no-worktree` (loses isolation; multi-feature parallel becomes impossible).

### Friction Points

| Friction Point | Cause | Mitigation |
|---|---|---|
| "I `/compact`-ed and now `--resume` can't find my pipeline" | Resumed session rooted in main; state.yaml is in worktree | One-session-per-worktree model; resume always reads `./.pmos/feature-sdlc/state.yaml` from session-root cwd |
| "I'm running 3 features and don't know which session is for which" | No per-session identity beyond shell history | Each session is started from its worktree; `pwd` + branch name in shell prompt make identity obvious |
| "I started this feature yesterday, came back today, and don't remember which worktrees are still in flight" | No discovery surface across sessions | New `/feature-sdlc list` subcommand: tabulates `git worktree list` × per-worktree `state.yaml` |
| "My new feature inherited the last feature's state.yaml" | `.pmos/feature-sdlc/state.yaml` is tracked in git | Add `.pmos/feature-sdlc/` to `.gitignore`; `git rm --cached` the existing file |
| "`/feature-sdlc` told me to relaunch and I'm not sure exactly what to type" | Handoff instructions vague | Print the exact two-line copy-paste: `cd <abs-worktree-path>` then `claude --resume` |

### Satisfaction Signals

- After running `/feature-sdlc <new feature seed>`, the user is unambiguously in the worktree (either via `EnterWorktree` taking effect, or via clear handoff instructions they copy-paste once).
- After `/compact` + `claude --resume`, `/feature-sdlc --resume` reads the correct state file with no flags or manual cd.
- `/feature-sdlc list` shows 3 in-flight features without ambiguity; the user knows which terminal tab corresponds to which.
- After `/complete-dev` on a merged feature, the worktree disappears and the user is left in main without manual cleanup.

## Solution Direction

The chosen design is **Model C — try-then-handoff**, with state living per-worktree and discovery scoped per-repo. The four pieces:

1. **Worktree creation + entry.** `/feature-sdlc` (no `--no-worktree`) creates the worktree via `git worktree add -b feat/<slug> <abs-path>`, writes initial `state.yaml` inside, then attempts `EnterWorktree(path=<abs>)`.
   - Success → continues in the same session.
   - Any error → prints the exact two-line handoff (`cd <worktree>` + `claude --resume`) and exits 0.
   - Either path leaves the worktree + state.yaml ready for resume.
2. **Per-worktree state, no global index.** State lives only at `<worktree>/.pmos/feature-sdlc/state.yaml`. `.pmos/feature-sdlc/` is gitignored; the existing committed file is removed from tracking. Resume reads `./.pmos/feature-sdlc/state.yaml` from session-root cwd. No flags, no picker.
3. **Pre-flight drift check.** At every `/feature-sdlc` entry, compare `realpath(pwd)` to `realpath(state.worktree_path)`. On mismatch, hard-error: `relaunch claude from <worktree>` (do not silently do the wrong thing).
4. **Discovery + cleanup.** New `/feature-sdlc list` subcommand iterates `git worktree list` for the current repo, reads each worktree's `state.yaml` if present, and prints a table to chat. `/complete-dev` learns to run `git worktree remove <worktree>` on successful merge (refuses on dirty tree per its existing pre-flight; surfaces the raw error and stops).

### Approaches considered

| Approach | Why not |
|---|---|
| Single session, EnterWorktree per-phase shift | Requires EnterWorktree's effect to be safely re-entrant and survive `/compact`. Cross-session durability is unverified; rebuilding around it would be fragile. |
| Bootstrap-and-handoff only (skip the EnterWorktree attempt) | Most robust but adds unnecessary friction when EnterWorktree would have worked. Try-then-handoff costs ~one tool call to discover it works. |
| Symlink from main to worktree | Cannot resolve N parallel worktrees. User explicitly rejected. |
| Global index file at `~/.pmos/feature-sdlc/index.yaml` | Adds concurrency (3 sessions writing simultaneously), GC, and lifecycle complexity. `git worktree list` already provides per-repo discovery for free. |
| Migrate in-flight pre-rework pipelines | Pre-rework state files have wrong assumptions baked in (committed location, no `realpath` drift check). Safer to detect + refuse than silently retro-fit. |

## User Journeys

### Primary Journey (single feature, EnterWorktree succeeds)

1. User in main repo session: `/feature-sdlc Fix race condition in foo`.
2. Skill derives slug `fix-race-condition-foo`, confirms via `AskUserQuestion`.
3. Skill creates worktree at `~/code/myrepo-fix-race-condition-foo/` on branch `feat/fix-race-condition-foo`.
4. Skill writes `<worktree>/.pmos/feature-sdlc/state.yaml`.
5. Skill calls `EnterWorktree(path=<worktree>)`. Returns success.
6. Pipeline continues in same session, now rooted in worktree. User sees: `Entered worktree at <path> on branch feat/fix-race-condition-foo. Continuing pipeline.`
7. `/requirements`, `/grill`, `/spec`, `/plan` run; subagents inherit the worktree cwd.
8. Before `/execute` (heavy phase), skill surfaces compact checkpoint. User picks Pause.
9. State written. Skill prints: `Pipeline paused. To resume: claude --resume in this session, or open a new session: cd <worktree> && claude --resume`. Exits clean.
10. User runs `/compact` then `/feature-sdlc --resume` — reads `./.pmos/feature-sdlc/state.yaml`, lands on `/execute`.
11. Pipeline completes through `/verify`, `/complete-dev`.
12. `/complete-dev` merges to main, runs `git worktree remove <worktree>`, deletes the branch. User is back in main with the worktree gone.

### Alternate Journey (EnterWorktree fails — handoff path)

After step 5, `EnterWorktree` returns an error (e.g., "Must not already be in a worktree" because the user already started `claude` from a worktree). Skill prints:

```
Worktree created at <abs-worktree-path>.
State initialized at <worktree>/.pmos/feature-sdlc/state.yaml.

To continue the pipeline, run these two commands in a new terminal:

    cd <abs-worktree-path>
    claude --resume

Then call /feature-sdlc --resume in the new session.
```

Exits 0. User opens new terminal, follows the instructions. From step 7 onwards identical to primary journey.

### Alternate Journey (parallel features)

User runs `/feature-sdlc Build OAuth refresh` in tab 1; pipeline proceeds in worktree A. While `/execute` is running, user opens tab 2, `cd ~/code/myrepo`, `claude`, then `/feature-sdlc Add audit log` — pipeline creates worktree B and proceeds independently. Tab 1 and tab 2 share no state files; both have their own `state.yaml` inside their own worktree. User can `/feature-sdlc list` from any tab to see both in flight.

### Discovery Journey (`/feature-sdlc list`)

1. User comes back after a few days, doesn't remember which features are in flight or where their worktrees live. Runs `/feature-sdlc list` from anywhere in the repo (main checkout or any worktree).
2. Skill iterates `git worktree list` for the current repo, reads each worktree's `.pmos/feature-sdlc/state.yaml` if present.
3. Skill prints a Markdown table to chat:
   ```
   | Slug | Branch | Phase | Last updated | Worktree |
   |---|---|---|---|---|
   | oauth-refresh | feat/oauth-refresh | execute (paused) | 2026-05-08 14:32Z | ~/code/myrepo-oauth-refresh |
   | audit-log     | feat/audit-log    | spec             | 2026-05-09 10:11Z | ~/code/myrepo-audit-log |
   ```
4. User picks one to resume; copy-pastes the worktree path into `cd <path> && claude --resume`.
5. New session lands in the right worktree; `/feature-sdlc --resume` picks up where it paused.

### Error Journeys

- **Pre-flight drift detected:** User somehow ended up in a session whose `cwd` no longer matches `state.worktree_path` (e.g., they cd'd elsewhere mid-session). Skill aborts with: `pre-flight check failed: realpath(pwd) [<actual>] != realpath(state.worktree_path) [<expected>]. Relaunch claude from <expected> and try again.`
- **Pre-rework state file detected:** `--resume` reads a state.yaml whose `schema_version` is < 3 OR whose `worktree_path` doesn't match `realpath(pwd)`. Skill aborts with: `state file from old /feature-sdlc model. Either finish in the original session, or delete <state.yaml> to start over.`
- **`git worktree remove` refuses dirty tree (during `/complete-dev`):** Skill surfaces the raw `git` error and stops. User decides whether to commit, stash, or force-remove manually. No auto-stash.
- **`EnterWorktree` succeeds initially but `/compact` resume drops the cwd shift:** Detected by pre-flight drift check on next `/feature-sdlc --resume` call. User gets the relaunch instruction; copy-pastes; continues.

### Empty States & Edge Cases

| Scenario | Condition | Expected Behavior |
|---|---|---|
| `--resume` with no state.yaml in cwd | User ran in wrong directory | Hard-error: `--resume specified but no .pmos/feature-sdlc/state.yaml in <cwd>. cd to the right worktree.` Exit 64. |
| `/feature-sdlc list` in repo with zero in-flight features | No worktrees match `feat/*` pattern, OR no state.yaml in any worktree | Empty table with helpful note: "No in-flight features. Start one with /feature-sdlc <seed>." |
| `/feature-sdlc list` in non-git directory | `git worktree list` errors | Surface the git error, exit 64. |
| Worktree exists at expected path but no state.yaml | User ran `--no-worktree` previously, or state.yaml was deleted | List entry shows `(no state)`, no crash. |
| Handoff printed but user runs `/feature-sdlc <fresh seed>` instead of `--resume` in the new session | User forgot the resume step | Skill detects existing state.yaml in cwd, prompts: `Existing pipeline for <slug> in this worktree. Resume? / Start over? / Cancel.` |

## Design Decisions

| # | Decision | Options Considered | Rationale |
|---|---|---|---|
| D1 | Use `EnterWorktree(path=<abs>)` after `git worktree add`, not raw `cd` | (a) Raw `cd` only, (b) EnterWorktree only (no git worktree add), (c) git worktree add + EnterWorktree | Spike confirmed: EnterWorktree shifts the harness session root and propagates to subagents; raw cd does not. (b) doesn't work because we need `-b feat/<slug>` semantics. |
| D2 | Try-then-handoff (Model C), not bootstrap-only nor in-place-only | (a) Always handoff, (b) Always EnterWorktree, (c) Try EnterWorktree, fall to handoff on any error | (c) gets the best UX when it works; handoff is robust fallback. (a) is unnecessary friction; (b) is fragile. |
| D3 | State lives at `<worktree>/.pmos/feature-sdlc/state.yaml` (per-worktree only) | (a) Global index file, (b) Per-worktree only, (c) Per-worktree + global catalog | (b) eliminates concurrency (no two sessions write the same file); discovery via `git worktree list` is free. |
| D4 | `.pmos/feature-sdlc/` added to `.gitignore`; existing committed `state.yaml` removed via `git rm --cached` in this feature's branch | (a) Leave tracked + accept stale-inherit bug, (b) Move state out of repo (e.g., `~/.pmos/feature-sdlc/<slug>/`), (c) Gitignore + `git rm --cached` | (c) keeps state co-located with the worktree (intuitive `.pmos/` namespace) without polluting git. (b) breaks the per-worktree-discovery model. |
| D5 | Pre-flight drift check uses `realpath()` comparison (resolves symlinks/canonicalization) | (a) String equality, (b) `realpath()`, (c) `inode` comparison | macOS canonicalizes `/tmp` → `/private/tmp` on EnterWorktree, confirmed in spike. String equality would false-fire on every macOS run. |
| D6 | Schema bump v2 → v3, additive (drift detection at runtime) | (a) Hard-refuse all v2 state files, (b) Silent migration to v3, (c) Additive v3 + runtime drift detect | (c) doesn't break legitimate v2 mid-flight pipelines (which finish under old rules); also catches the real defect (location/path drift) at runtime where it's actionable. |
| D7 | `/feature-sdlc list` is a subcommand, chat output only | (a) Subcommand + chat, (b) `--list` flag, (c) Subcommand + generated file, (d) Defer | (a) is most discoverable + leaves no on-disk artifact to maintain. Reads `git worktree list` × per-worktree state.yaml live. |
| D8 | Per-repo discovery only; no cross-repo index | (a) Per-repo, (b) Cross-repo via `~/.pmos/feature-sdlc/index.yaml` | (a) keeps complexity bounded; cross-repo discovery is a niche need not on the user's path. |
| D9 | `/complete-dev` runs `git worktree remove <worktree>` on successful merge; refuses on dirty tree (raw error surfaced) | (a) Auto-stash + remove, (b) Prompt user with stash/discard/abort, (c) Refuse-on-dirty + surface error, (d) Don't auto-cleanup | (c) matches `/complete-dev`'s existing pre-flight discipline; auto-stashing is unsafe; interactive prompt at end-of-pipeline is unwelcome. |
| D10 | Worktree path convention: `<repo-parent>/<repo-name>-<slug>/` (sibling directory) | (a) Sibling, (b) `.git/worktrees/<slug>` (inside repo), (c) `~/code/worktrees/<slug>`, (d) Configurable | (a) matches existing `pipeline-consolidation` worktree convention; navigable in finders/IDEs without surprise. Sticking with prevailing pattern; revisit if multi-machine sync surfaces issues. |
| D11 | Handoff message is a literal copy-paste two-line block, not prose; original session exits 0 with explicit `Status: handoff-required` line | (a) Prose ("then run cd ... && claude"), (b) Literal command block + status line, (c) Exit non-zero (e.g. EX_TEMPFAIL 75) | (b) is unambiguous; users copy-paste without parsing. Exit 0 + status line preserves /loop and /schedule wrapper semantics (they only check exit code) while still signaling to a human reader that work continues in another session. |
| D12 | `--no-worktree` mode is full bypass: no `git worktree add`, no `EnterWorktree`, no drift check; state at `./.pmos/feature-sdlc/state.yaml` in cwd | (a) Deprecate --no-worktree, (b) Keep as full bypass, (c) Require --no-worktree on --resume too | (b) preserves the power-user escape (Tier-1 fixes in main, no worktree ceremony) without breaking the rework's invariants. Resume from same cwd works identically because state lives where you are. |
| D13 | `/complete-dev` cleanup uses strict `git worktree remove` (no --force); refuses on any untracked or modified tracked file. Explicit `--force-cleanup` flag opts in. State.yaml excluded from dirty check (expected gitignored). | (a) Refuse-on-tracked-modified-only, (b) Strict no-force + opt-in --force-cleanup, (c) Always require --cleanup at every release | (b) matches /complete-dev's existing pre-flight discipline; auto-cleaning untracked files risks losing forgotten user scratch. Opt-in --force-cleanup is the documented escape. |
| D14 | Phase 0.a unified pre-flight: check branch existence + worktree path existence + `git worktree list` registration; merged `Use existing / Pick new (-N suffix) / Abort` dialog | (a) Branch-only check (current SKILL.md edge-case d), (b) Auto-suffix silently, (c) Unified branch + path + registration check | (c) handles both clean reruns AND orphan worktree dirs (e.g., user manually rm-rf'd `.git/worktrees` entry). Auto-suffix would silently create duplicate parallel features when the user wanted to resume. |
| D15 | Post-cleanup cwd handling in `/complete-dev` Phase 4: try `ExitWorktree(action=keep)` first; on no-op (resumed-from-worktree session), proceed with `git worktree remove` and print `cd <root-main-path>` fallback instruction | (a) Always print cd fallback, (b) Try ExitWorktree-then-fallback, (c) Refuse cleanup in resumed sessions | (b) gets the in-place harness cwd shift in the original-session case (clean UX); falls back gracefully in the resumed case. ExitWorktree's contract ("only worktrees this session created") makes the split unavoidable. |

## Success Metrics

| Metric | Baseline | Target | Measurement |
|---|---|---|---|
| `/feature-sdlc --resume` success rate after `/compact` | ~0% (currently broken: state.yaml unreachable from main session) | 100% (when relaunched from worktree) | Manual: run a 3-phase pipeline, `/compact`, `claude --resume`, `/feature-sdlc --resume`; check it lands on the right phase. Repeat 3× across two features. |
| Concurrent in-flight features supported | 1 (parallel runs collide on shared `current_feature` and stale state) | ≥3 | Manual: open 3 terminal tabs, start 3 different features, run each through `/spec`. Confirm zero state collision; `/feature-sdlc list` shows all 3 with correct phases. |
| Stale state inheritance defects | 1 known (this feature's worktree inherited `pipeline-consolidation` state) | 0 | After ship: `git ls-files .pmos/feature-sdlc/` returns empty. New worktrees show no state.yaml until `/feature-sdlc` writes one. |
| Worktree leak after `/complete-dev` | 100% (worktrees never auto-removed) | 0% on clean trees; 100% surfaced (not silent) on dirty trees | After ship: run a feature through `/complete-dev`, confirm `git worktree list` no longer shows the feature's worktree. |
| Subagent cwd correctness | Unknown (no formal verification) | 100% | Spike-style test: dispatch a subagent inside an EnterWorktree session, verify `pwd` matches. Already done for this rework; preserve as a lint or doc-test in `_shared/`. |

## Research Sources

| Source | Type | Key Takeaway |
|---|---|---|
| `EnterWorktree` / `ExitWorktree` tool schemas (deferred-tool inspection) | Harness primitive | EnterWorktree(path=) cleanly enters externally-created worktrees; subagents inherit shifted cwd. ExitWorktree refuses to remove worktrees it didn't create — cleanup uses `git worktree remove`. |
| Pre-pipeline empirical spike (this session, 2026-05-10) | Live test | Subagent dispatched inside EnterWorktree session reported `pwd = /private/tmp/feature-sdlc-spike-wt`, confirming subagent cwd inheritance. macOS `/tmp` → `/private/tmp` canonicalization observed. |
| `plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md` (v2.34.0) | Existing code | Current skill uses raw `git worktree add`; resume logic assumes state.yaml at `./.pmos/feature-sdlc/state.yaml` but doesn't enforce that the session is rooted in the right worktree. |
| `plugins/pmos-toolkit/skills/feature-sdlc/reference/state-schema.md` | Existing code | Schema v2 just shipped (2026-05-10) in pipeline-consolidation. v3 will be additive. Pre-rework v2 files exist in user's main branch (committed). |
| `docs/pmos/features/2026-05-10_pipeline-consolidation/01_requirements.md` and downstream | Reference | Most recently shipped Tier-3 feature uses Markdown artifacts (despite html-artifacts shipping at v2.33.0); current pragma is .md primary. This feature follows the same convention. |
| `.gitignore` (current) and `git ls-files .pmos/` | Repo state | Confirmed `.pmos/feature-sdlc/state.yaml` is tracked. `.pmos/current-feature` is already gitignored (legacy session pointer). Convention exists for excluding ephemeral pipeline state. |

## Open Questions

| # | Question | Status |
|---|---|---|
| 1 | Should `/feature-sdlc list` flag worktrees whose `last_updated` is older than N days (stale work)? Currently spec'd to just list everything; staleness flagging is a UX polish that could ship later. | Open — defer to spec |
| 2 | Does `/feature-sdlc list` need to handle worktrees whose `state.yaml` schema is v1 or v2 (legacy pipelines mid-flight)? Probably yes — show them with a `(legacy v1/v2)` marker rather than crashing. Confirm in spec. | Open — defer to spec |
| 3 | If the user runs `/feature-sdlc` from a session that's already inside a worktree (via prior `EnterWorktree`), should the skill detect that and offer to run the pipeline against an existing in-flight feature in the same worktree, or only allow new-feature creation from a fresh session? | **Closed by /grill Q6** — EnterWorktree errors per its own contract on already-in-worktree; the handoff path (D2/D11) fires naturally. No special detection needed. |
| 4 | The pre-flight drift check fires at every `/feature-sdlc` entry. Is it also worth firing in `/spec`, `/plan`, `/execute`, etc.? | **Closed by /grill** — EnterWorktree's effect is session-scoped; children inherit cwd. Only `/feature-sdlc` (and `/feature-sdlc --resume`) need the explicit drift check. |
| 5 | When `/complete-dev` removes the worktree, the user's terminal session is rooted IN the worktree (which just got deleted). | **Closed by D15** — Phase 4 tries `ExitWorktree(action=keep)` first (clean shift in original-session case); on no-op (resumed-session case), prints `cd <root-main-path>` fallback. |

---

## Phase 5.5 — Folded MSF-req (Tier 3 default-on)

The Tier-3 UX Analysis section (Motivation / Friction Points / Satisfaction Signals) already applies the MSF lens inline. The folded MSF apply-loop ran against `01_requirements.md` and produced **no novel findings** beyond what the UX Analysis section captures: the central friction (post-handoff copy-paste of `cd <worktree> && claude --resume`) is already explicitly named, accepted by the user during pre-pipeline brainstorm as a one-time effort, and surfaced in D2 + D11 + Friction Points table row 5. No inline auto-apply commits were generated. `state.yaml.phases.requirements.folded_phase_failures` remains empty.

## Review Log

| Loop | Findings | Changes Made |
|---|---|---|
| 1 | F2: D6 vague on schema v3 additions. F3: /feature-sdlc list lacked a user journey. (Plus 3 nice-to-haves not raised per "don't manufacture friction" — F1 G3 measurement claim hedge, F5 friction-vs-correctness tension, F4 "why not branches alone" non-goal.) | F2 dispositioned **Skip — defer to /spec** (D6 stays high-level). F3 dispositioned **Fix as proposed** — Discovery Journey added under User Journeys. |
| 2 (/grill — standard depth, 6 questions) | Q1 handoff exit semantics, Q2 --no-worktree interaction, Q3 cleanup edge with gitignored state.yaml + untracked, Q4 state.yaml atomicity, Q5 repeat-slug worktree collision (orphan-dir case), Q6 post-cleanup terminal state (ExitWorktree split). | All 6 dispositioned **Fix as proposed**. Added D11 (extended), D12, D13, D14, D15 to Decisions table. OQ #5 closed by D15. OQ #3 + #4 closed implicitly (handoff fires on already-in-worktree; orchestrator's drift check covers child skills). |
