# /complete-dev — rebase-default + parallel-worktree version-bump fix — Spec

**Date:** 2026-05-08
**Status:** Ready for Plan
**Requirements:** `docs/pmos/features/2026-05-08_update-skills-complete-dev-merge/01_requirements.md`
**Tier:** 2 — Enhancement
**Target:** `plugins/pmos-toolkit/skills/complete-dev/SKILL.md` (+ new `plugins/pmos-toolkit/skills/complete-dev/reference/version-bump-recovery.md`)

---

## 1. Problem Statement

`/complete-dev` Phase 3 defaults to a merge commit when the user prefers linear history (rebase). Phase 9 reads the version-bump baseline from the feature branch with no awareness of `origin/main`, causing parallel-worktree bumps to collide at the pre-push hook (catch-up cost: re-edit both `plugin.json`s, re-commit, re-push). Primary success metric: zero manual "pick option 2" interactions and zero post-bump pre-push rejections across 5 routine `/complete-dev` runs.

---

## 2. Goals

| # | Goal | Success Metric |
|---|------|---------------|
| G1 | Phase 3 defaults to rebase + FF when safe. | Zero "pick option 2" interactions in 5 routine runs. |
| G2 | Version-bump collisions detected before commit. | Pre-flight surfaces stale-bump *during Phase 9*, not at push-time. |
| G3 | Stale-bump recovery has a named recipe. | Failure mode produces a one-line pointer to `reference/version-bump-recovery.md`. |
| G4 | Rebase safety guard prevents accidental SHA-rewrite. | When upstream tip ≠ local tip, recommended option flips to `--no-ff` merge. |

---

## 3. Non-Goals

- NOT changing `.githooks/pre-push` — it stays as last-line defence.
- NOT changing rebase-vs-merge defaults for non-pmos-toolkit repos that adopt `/complete-dev` — same skill ships everywhere; the guard is conservative enough.
- NOT auto-resolving rebase conflicts — STOP and ask, same as merge conflicts today.
- NOT introducing a different version-bump strategy (changesets, semantic-release).
- NOT changing `--skip-deploy` / `--no-tag` / `--skip-changelog` semantics.
- NOT generalizing trunk-branch or remote names — `origin/main` is hardcoded throughout, preserved from current SKILL.md. Repos with `master`/`develop`/non-`origin` remotes are already incompatible with the existing `/complete-dev` and remain so after this change.

---

## 4. Decision Log

| # | Decision | Options Considered | Rationale |
|---|----------|--------------------|-----------|
| D1 | Default Phase 3 to rebase-onto-main + FF when guard passes; merge as fallback. | (a) Always rebase. (b) Always merge (current). (c) Conditional default (chosen). | (a) unsafe for shared branches; (b) is current friction. (c) flips common-case ergonomics without sacrificing safety. |
| D2 | Pre-flight collision check lives in Phase 9, not Phase 0. | (a) Phase 0. (b) Phase 9 (chosen). | The post-rebase state is what matters; Phase 9 sees the correct baseline. |
| D3 | Stale-bump recovery is interactive, not automatic. | (a) Auto-revert silently. (b) Show recipe + ask (chosen). | Don't destroy user work without consent; explain → fix → consent. |
| D4 | Shared-branch guard uses `local SHA == remote SHA` test; document caveat as anti-pattern, not runtime nag. | (a) Any-upstream test (too conservative). (b) SHA equality (chosen). (c) Track who-pulled-what (impossible). | Most permissive correct test; the "coworker pulled, both pushed independently" gap is the pre-push hook's problem. |
| D5 | No new flags (`--force-merge`/`--force-rebase`). | (a) Add escape-hatch flags. (b) Rely on AskUserQuestion options (chosen). | Interactive prompt already gives non-default options; don't expand surface area. |
| D6 | Pre-flight failure on network/auth issues skips with warning, doesn't block. | (a) Skip + warn (chosen). (b) Block until fetch succeeds. | Pre-push hook is the hard gate; pre-flight is best-effort. |
| D7 | Pre-flight uses `git fetch origin main` (not lazy / not `ls-remote`). | (a) Always fetch (chosen). (b) Cached fetch with mtime check. (c) `git ls-remote` + `git show`. | Simplest mental model; 1–3s overhead is negligible compared to a missed-collision re-push cycle. User confirmed in Architect-role interview. |
| D8 | Stale-detect uses three-way compare (local / main / branch-point). | (a) local-vs-main only. (b) Three-way (chosen). | Three-way correctly distinguishes "bump on stale base" from "bump that legitimately matches main because rebase already pulled it in". |
| D9 | Recovery recipe lives in a new `reference/version-bump-recovery.md`, not inline in SKILL.md. | (a) Inline. (b) Separate reference file (chosen). | Reference file convention matches existing complete-dev/reference/ layout (rollback-recipes.md, deploy-norms.md, etc.); keeps SKILL.md scannable. |

**Roles considered, no questions:**

```text
Silent roles considered:
- DBA — no schema or persistent storage changes; this is git plumbing only.
- Principal Designer — no UI changes; AskUserQuestion prompts inherit the existing /complete-dev style.
- Product Director — user journeys already validated in 01_requirements.md §"User Journeys"; no new persona.
- Senior Analyst — FR coverage validated against requirements G1–G4 in §6 below; no gaps.
```

DevOps role surfaced via D6 (graceful degradation on fetch failure) — embedded in Architect-role thread rather than separate.

---

## 5. User Journeys

(See `01_requirements.md` §"User Journeys" — primary, two parallel-worktree alternates, shared-branch alternate, error journeys. Spec inherits without restating.)

---

## 6. Functional Requirements

### 6.1 Phase 3 — default flip + shared-branch guard

| ID | Requirement |
|----|-------------|
| FR-01 | Phase 3's `AskUserQuestion` reorders options so `Rebase onto main, then fast-forward` is option 1 with `(Recommended)`; `Merge into main (fast-forward if possible, else --no-ff merge commit)` is option 2; `Stay on feature branch and push only this branch` and `Cancel` remain. |
| FR-02 | Before showing the prompt, run the **shared-branch guard**:<br>1. `upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null \|\| true)`<br>2. If `upstream` is empty → guard PASSES (rebase-safe; no upstream to break).<br>3. Else: `git fetch ${upstream%/*} ${upstream#*/}` (single-ref fetch). Compare `git rev-parse HEAD` against `git rev-parse $upstream`.<br>4. If equal → guard PASSES. If different → guard FAILS. |
| FR-03 | When guard FAILS, the prompt's `(Recommended)` annotation moves to the merge option, and the question text gains a one-line prefix: "Branch `<name>` has been pushed and remote tip differs from local — rebase would rewrite SHAs others may have. Recommended: --no-ff merge." Rebase still appears as a manual option but with `(WARNING: rewrites SHAs)` suffixed to its label. |
| FR-04 | When user picks rebase, execute the explicit sequence:<br>`git checkout main && git pull origin main && git checkout <feature> && git rebase main && git checkout main && git merge --ff-only <feature>`<br>Conflicts during the `git rebase main` step → STOP and ask user (no auto-resolve). The final `merge --ff-only` is guaranteed safe since the feature branch was just rebased onto current main. |
| FR-05 | When user picks merge: execute the existing merge sequence unchanged (FR-01's option 2). |

### 6.2 Phase 9 — baseline reorder + collision pre-flight

| ID | Requirement |
|----|-------------|
| FR-06 | Phase 9 step 1 (NEW): `git fetch origin main 2>&1`. On non-zero exit, log a one-line warning ("could not fetch origin/main; pre-push hook will catch any collision"), set `pre_flight_skipped=true`, jump to FR-10. |
| FR-07 | Phase 9 step 2 (NEW): read `main_v = git show origin/main:plugins/pmos-toolkit/.claude-plugin/plugin.json \| jq -r .version`. On parse failure, same fallback as FR-06. |
| FR-08 | Phase 9 step 3 (NEW): read `branch_point_v` by finding `merge_base = git merge-base HEAD origin/main` and running `git show $merge_base:plugins/pmos-toolkit/.claude-plugin/plugin.json \| jq -r .version`. On parse failure, treat `branch_point_v` as `main_v` (degraded mode; warn). |
| FR-09 | Phase 9 step 4 (NEW): read `local_v` from working-tree `plugins/pmos-toolkit/.claude-plugin/plugin.json`. |
| FR-10 | Phase 9 step 5 (NEW) — **stale-bump pre-flight decision table**:<br><br>\| `local_v` vs `branch_point_v` \| `main_v` vs `branch_point_v` \| Verdict \|<br>\|---\|---\|---\|<br>\| equal (no local bump yet) \| equal (no parallel ship) \| **Clean**: bump baseline = `main_v` \|<br>\| equal (no local bump yet) \| greater (parallel ship happened) \| **Clean-after-rebase**: bump baseline = `main_v` (Phase 3 rebase already pulled the parallel ship in) \|<br>\| greater (local already bumped) \| equal (no parallel ship) \| **Fresh local bump**: proceed; baseline already advanced \|<br>\| greater (local already bumped) \| greater (parallel ship + local bump on stale base) \| **Stale-bump**: trigger FR-11 recovery flow \|<br>\| less (impossible-ish) \| any \| **Anomaly**: warn user; ask whether Phase 3 succeeded; offer skip-or-cancel \| |
| FR-11 | On **Stale-bump** verdict, show a dedicated `AskUserQuestion`:<br>`question`: "Stale version bump detected: feature branch has plugin.json at v`<local_v>`, branched from v`<branch_point_v>`, but main shipped v`<main_v>` since. What now?"<br>`options`:<br>1. `Revert the speculative bump and re-bump from main (Recommended)` — invokes recovery recipe (FR-12).<br>2. `Keep going anyway` — proceeds to FR-13 unchanged (will likely fail pre-push hook).<br>3. `Cancel — let me investigate manually` — abort `/complete-dev`. |
| FR-12 | Recovery recipe (sourced from `reference/version-bump-recovery.md`):<br>1. `git checkout origin/main -- plugins/pmos-toolkit/.claude-plugin/plugin.json plugins/pmos-toolkit/.codex-plugin/plugin.json`<br>2. Re-run FR-13 bump prompt with baseline now = `main_v`.<br>3. Apply, validate JSON, re-stage. Phase 11 commits the corrected bump. |
| FR-13 | After pre-flight (or on `pre_flight_skipped=true`), Phase 9's bump prompt remains structurally unchanged (Patch / Minor / Major / Skip), but the "Current version is X.Y.Z" header line uses the resolved bump-baseline (`main_v` if pre-flight ran cleanly; otherwise `local_v` with a warning suffix "pre-flight skipped — verify manually"). |
| FR-14 | The paired-manifest invariant from current Phase 9 is preserved: bumps apply to BOTH `.claude-plugin/plugin.json` AND `.codex-plugin/plugin.json` to identical versions. |

### 6.3 Anti-pattern + reference-file additions

| ID | Requirement |
|----|-------------|
| FR-15 | `/complete-dev` SKILL.md anti-pattern list grows by 1 entry: "**Trusting the shared-branch guard's `local==remote SHA` test as proof no one has based work on this branch.** It's necessary-but-not-sufficient — a coworker who pulled before our last fixup could have based work, and we'd never know. The pre-push hook is the only authoritative line of defence; use the merge fallback for any branch you've shared for review." |
| FR-16 | New file: `plugins/pmos-toolkit/skills/complete-dev/reference/version-bump-recovery.md` (≤30 lines) — contains the recovery recipe (FR-12 steps), failure modes, manual fallback. |
| FR-17 | `/complete-dev` SKILL.md Phase 9 includes a one-line pointer: "Stale-bump recovery: see `reference/version-bump-recovery.md`." |

---

## 7. Non-Functional Requirements

| ID | Category | Requirement |
|----|----------|-------------|
| NFR-01 | Latency | Phase 9 pre-flight adds ≤3s wall-clock for a healthy `git fetch origin main`. Hard cap: if fetch exceeds 10s, kill it and skip pre-flight (FR-06 path). |
| NFR-02 | Compatibility | All existing `/complete-dev` flags (`--skip-changelog`, `--skip-deploy`, `--no-tag`, free-form commit hint) continue to work unchanged. |
| NFR-03 | Failure mode | Network/auth failures during pre-flight degrade gracefully (warn + skip), never block ceremony. |
| NFR-04 | Reversibility | The recovery recipe (FR-12) is fully reversible (it only `git checkout`s tracked files; no destructive history rewrite). |

---

## 8. API Changes

N/A — this is a SKILL-prose modification; no programmatic API.

---

## 9. Database Design

N/A — no persistent storage.

---

## 10. Frontend Design

N/A — interactive prompts inherit the existing `AskUserQuestion` style; no new UI surface.

---

## 11. Edge Cases

| # | Scenario | Condition | Expected Behavior |
|---|----------|-----------|-------------------|
| E1 | Feature branch has no upstream | `git rev-parse @{upstream}` fails | Guard PASSES (FR-02 step 2); rebase recommended. |
| E2 | Feature branch shared, remote tip == local tip | upstream exists, SHAs match | Guard PASSES; rebase recommended. |
| E3 | Feature branch shared, remote tip != local tip | upstream exists, SHAs differ | Guard FAILS; merge recommended with one-line reason (FR-03). |
| E4 | `git fetch` fails (network/auth) | non-zero exit | Skip pre-flight, warn, proceed (FR-06). |
| E5 | `origin/main:plugin.json` missing/unparseable | `git show` or `jq` fails | Skip pre-flight, warn, proceed. |
| E6 | Rebase conflict in `plugin.json` | Phase 3 rebase | STOP, ask user (existing Phase 3 conflict-handling). |
| E7 | Branch-point lookup fails | `git merge-base HEAD origin/main` returns empty | Treat `branch_point_v = main_v` (degraded mode); warn; pre-flight runs in 2-way mode (less precise but still catches obvious collisions). |
| E8 | User picks "Keep going anyway" on stale-bump | FR-11 option 2 | Proceed to FR-13 unchanged; pre-push hook is expected to reject — no auto-prevention. |
| E9 | `/complete-dev` aborted post-Phase-11-commit, pre-push | Speculative bump committed on stale base | On re-run, Phase 3 rebase will conflict on `plugin.json` (E6) → after user resolves or aborts rebase, Phase 9 pre-flight detects stale-bump and offers recovery (FR-11). |
| E10 | Worktree with no `origin` remote (rare) | `git remote get-url origin` fails | Skip pre-flight (treat as E4); ceremony proceeds. |

---

## 12. Configuration & Feature Flags

None. The change is unconditional behaviour; the rebase guard provides the only branching logic.

---

## 13. Testing & Verification Strategy

### 13.1 Static checks (run by `/verify` after `/execute`)

| Check | Command | Expected |
|-------|---------|----------|
| Inline Phase 0 block unchanged | `bash tools/lint-pipeline-setup-inline.sh` | exit 0 |
| Anti-pattern count grew by 1 | `grep -c '^[0-9]\+\.' plugins/pmos-toolkit/skills/complete-dev/SKILL.md \| <compare to baseline+1>` | matches |
| New reference file exists | `test -f plugins/pmos-toolkit/skills/complete-dev/reference/version-bump-recovery.md` | exit 0 |
| SKILL.md still parses as valid YAML frontmatter | `python3 -c "import yaml; yaml.safe_load(open('plugins/pmos-toolkit/skills/complete-dev/SKILL.md').read().split('---')[1])"` | no exception |

### 13.2 Behavioural verification (manual; documented as a recipe in 03_plan.md)

| Scenario | Steps | Expected |
|----------|-------|----------|
| Solo branch, clean rebase | Make trivial change on feature branch (no upstream); run `/complete-dev`; observe Phase 3 prompt. | `Rebase onto main + FF` carries `(Recommended)`. |
| Shared branch, divergent remote | Push feature branch; coworker pushes a fixup; run `/complete-dev`. | Guard FAILS; merge recommended; one-line reason in question text. |
| Parallel-worktree collision | Worktree A bumps 2.27.0→2.28.0 and pushes; Worktree B (still at branch from 2.27.0) runs `/complete-dev`; Phase 3 rebase pulls 2.28.0 into B. | Phase 9 pre-flight reports `Clean-after-rebase`; user prompted to pick bump kind from `2.28.0` baseline. |
| Speculative-bump recovery | Worktree B speculatively committed 2.28.0 before Worktree A pushed 2.28.0; user re-runs `/complete-dev`; Phase 3 rebase conflicts in plugin.json; user aborts rebase. Re-run with intent to recover. | Phase 9 pre-flight detects stale-bump; offers recovery; recovery recipe restores plugin.json from origin/main and re-prompts bump. |

### 13.3 Verification commands (exact, for plan/execute)

```bash
# Lint (CI-runnable)
bash tools/lint-pipeline-setup-inline.sh

# Reference file presence
test -f plugins/pmos-toolkit/skills/complete-dev/reference/version-bump-recovery.md

# SKILL.md frontmatter still valid
python3 -c "import yaml,sys; yaml.safe_load(open('plugins/pmos-toolkit/skills/complete-dev/SKILL.md').read().split('---',2)[1]); print('OK')"

# Phase 3 default-flip presence (rough but adequate)
grep -A2 'Rebase onto main' plugins/pmos-toolkit/skills/complete-dev/SKILL.md | head -5

# Phase 9 fetch step presence
grep -n 'git fetch origin main' plugins/pmos-toolkit/skills/complete-dev/SKILL.md

# Anti-pattern about SHA-equality test caveat
grep -n 'necessary-but-not-sufficient' plugins/pmos-toolkit/skills/complete-dev/SKILL.md
```

### 13.4 Out of scope for automated tests

- Simulating two-worktree race conditions in CI (would require shellcraft + ephemeral remote). Behavioural verification is manual per §13.2.
- The "5 routine runs without manual intervention" success metric (G1) is observed over real use, not asserted in CI.

---

## 14. Rollout Strategy

- **Single PR** changes both SKILL.md and adds the reference file. No staged rollout.
- **Version bump:** patch (D9 — additive behaviour within existing phases; no contract changes). Both `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` bump together (paired-manifest invariant).
- **Rollback:** revert the commit. SKILL.md changes are pure prose/behaviour; no migrations to reverse, no state to clean up.
- **First user of new behaviour:** the very next `/complete-dev` ceremony in this repo (likely the one shipping this change). The author will exercise both Phase 3 and Phase 9 paths on real state.

---

## 15. Research Sources

| Source | Type | Key Takeaway |
|--------|------|-------------|
| `plugins/pmos-toolkit/skills/complete-dev/SKILL.md` | Existing skill | Current Phase 3 + Phase 9 logic; structures the diff. |
| `.githooks/pre-push` | Existing hook | `local_v == remote_v` rejection rule confirms the collision mode being addressed. |
| Recent commits 8b9ffe3 ("re-bump 2.25.0 → 2.26.0 to stack above local main's /create-skill release") | Git history | Real-world evidence the collision happens routinely; not a theoretical concern. |
| `plugins/pmos-toolkit/skills/_shared/pipeline-setup.md` | Shared infra | Inline block lint script (`tools/lint-pipeline-setup-inline.sh`) — Phase 0 block is untouched here so this lint stays green. |

---

## Review Log

| Loop | Findings | Changes Made |
|------|----------|-------------|
| 1 | F-1 [Should-fix] hardcoded `origin/main` not called out. F-2 [Nit] FR-04 sequence implicit. No structural findings. | F-1 applied: added non-goal entry. F-2 applied: FR-04 expanded with explicit command sequence. User confirmed no further concerns; promoting to Ready for Plan. |
