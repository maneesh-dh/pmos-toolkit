# Update brief: /complete-dev

**Source:** /update-skills triage at `docs/pmos/features/2026-05-08_update-skills-complete-dev-merge/00_triage.md`
**Triage findings approved for this skill:** 2
**Tier (user-confirmed):** Tier 2

## Approved findings (verbatim from triage)

### Finding 1 — [friction] Phase 3 should default to rebase-onto-main + FF instead of merge (FF / --no-ff)
- **Evidence:** User: "should we make git rebase as the default during merge to main?"
- **Proposed fix:** Make rebase the default option in Phase 3, with a safety guard for branches that have been pushed/shared (where rebasing would rewrite SHAs others may have pulled). When the guard trips, fall back to `--no-ff` merge.
- **Classification:** UX-friction
- **Scope hint:** medium

### Finding 2 — [friction/bug] Parallel worktrees produce version-bump collisions
- **Evidence:** User: "if there are multiple worktrees in parallel, there are bound to be version conflicts. Is there a way to minimize git conflicts due to incorrect version bump assumptions in different worktrees?"
- **Proposed fix:** Defer the version bump (Phase 9) until *after* the rebase/merge onto main has happened, so the bump baseline is read from main's `plugin.json`, not from the feature branch's potentially-stale view. Add a pre-flight collision check that compares the local `plugin.json` version against `origin/main`'s version (after `git fetch`), and surfaces a clear "stale base — please rebase before bumping" message when they differ in a way that would collide. Include detection of the case where a feature branch *already* committed a version bump speculatively (a stale bump that needs to be discarded and redone from main's HEAD).
- **Classification:** bug (causes real conflicts in observed parallel-worktree workflow)
- **Scope hint:** medium

## Current SKILL.md excerpts (sections to change)

### Excerpt for Finding 1 — `plugins/pmos-toolkit/skills/complete-dev/SKILL.md`, "## Phase 3 — Merge feature → main"

> If on a feature branch:
>
> ```
> question: "Land branch <name> into main how?"
> options:
>   - Merge into main (fast-forward if possible, else --no-ff merge commit) (Recommended)
>   - Rebase onto main, then fast-forward
>   - Stay on feature branch and push only this branch
>   - Cancel
> ```
>
> If merge chosen:
> 1. Verify uncommitted state is clean (or surface to commit them first; ask user)
> 2. `cd <root-main-path>` if currently in a worktree
> 3. `git checkout main`
> 4. `git pull origin main` (sync first)
> 5. `git merge <feature-branch>` (fast-forward where possible; `--no-ff` if explicitly chosen)
> 6. **Conflicts → STOP and ask user. Do NOT auto-resolve.**

### Excerpt for Finding 2 — `plugins/pmos-toolkit/skills/complete-dev/SKILL.md`, "## Phase 9 — Version bump"

> If skill content changed (Phase 0 detected new/modified files under `plugins/pmos-toolkit/skills/` or `plugins/pmos-toolkit/agents/`), bump is **mandatory** — pre-push hook enforces.
>
> **Paired-manifest special case**: if BOTH `plugins/pmos-toolkit/.claude-plugin/plugin.json` AND `plugins/pmos-toolkit/.codex-plugin/plugin.json` exist, treat as ONE logical version that bumps together. Pre-flight: read both; if versions differ, ask which to use as baseline (the pre-push hook rejects mismatch).
>
> For other monorepo cases: detect via multiple `package.json` files; only offer bumps for paths that actually changed (`git diff --name-only main..HEAD` mapped to package roots).
>
> ```
> question: "Current version is X.Y.Z. What kind of bump?"
> options:
>   - Patch (X.Y.Z+1) — bug fix, content tweak, doc-only
>   - Minor (X.Y+1.0) — new skill, additive feature (Recommended for new skills)
>   - Major (X+1.0.0) — breaking change to skill API or removed skill
>   - Skip version bump (only if no plugin content changed)
> ```
>
> Apply via `Edit`. Validate JSON parses: `python3 -c "import json; json.load(open('<path>'))"`.

### Supporting excerpt — Phase 14 dry-run summary (touchpoint for the new pre-flight check output)

> ```
> === /complete-dev summary ===
> Branch:           main
> Local commits:    <N> ahead of origin/main
> ...
> Plugin version:   <X.Y.Z> (manifests in-sync: <YES|NO>)
> ```

### Supporting excerpt — Anti-patterns (these become wrong / need updating after F1)

> 7. **Auto-rolling-back the merge on push failure** — destructive; user almost always wants to fix-and-retry.
> 9. **Skipping version bump because "nothing changed"** when skill files actually changed — Phase 0 must accurately detect changes; pre-push hook will reject otherwise.

(Anti-pattern list will need a new entry about *not* rebasing branches that have been pushed/shared.)

## Proposed direction (one paragraph)

Rework Phase 3 so the default option is `Rebase onto main, then fast-forward` — but only if a guard passes: (a) feature branch has no upstream, OR (b) upstream exists and the local SHA matches the remote (i.e. nobody else has pulled it past where we are). When the guard fails, the recommended option flips back to `--no-ff` merge with a one-line explanation ("branch is shared — rebase would rewrite SHAs others may have"). Phase 9 is reordered so that the version-bump baseline is read AFTER Phase 3's merge/rebase has put us on the latest main HEAD; before bumping, do a `git fetch origin main` + compare the staged-bump-target against `origin/main`'s `plugin.json` version, and abort with a concrete "rebase first" message if a parallel worktree shipped a bump while we were working. Add a pre-flight check at Phase 0 (cheap) that compares feature-branch's `plugin.json` against `origin/main` and warns if the feature branch has already speculatively bumped on a now-stale base — pointing the user at the recovery recipe (revert the speculative bump, rebase, re-bump from new baseline).

## Out-of-scope for this run

- Changing the pre-push hook itself (the hook already rejects mismatched manifests; Phase 9's new check is meant to catch the problem earlier and friendlier, not replace the hook).
- Touching the merge-vs-rebase choice for non-pmos-toolkit repos (the guard is general but the default-flip should only ship after proving out on this repo's workflow).
- Auto-resolving rebase conflicts (same rule as merge conflicts: STOP and ask user).

## Constraints

- Skill must remain backwards-compatible with `argument-hint`: `[--skip-changelog] [--skip-deploy] [--no-tag] [optional commit-message hint]` (no new flags required for this change; if a `--force-merge` escape hatch is added it must be additive).
- All AskUserQuestion prompts must follow the Findings Presentation Protocol (one question per decision, ≤4 batched, sequential follow-ups for "Modify"-style answers).
- Reference paths (`learnings/learnings-capture.md`, `_shared/*`) resolve as siblings under `plugins/pmos-toolkit/skills/`.
- Version bump at next /push: **patch** (no new phases or files, just behavior changes within existing phases).
