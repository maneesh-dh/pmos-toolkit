# /complete-dev — rebase-default + parallel-worktree version-bump fix — Implementation Plan

**Date:** 2026-05-08
**Spec:** `docs/pmos/features/2026-05-08_update-skills-complete-dev-merge/02_spec.md`
**Requirements:** `docs/pmos/features/2026-05-08_update-skills-complete-dev-merge/01_requirements.md`

---

## Overview

Modify the `/complete-dev` SKILL.md in two phases: Phase 3 gets a rebase-by-default flow with a shared-branch safety guard, Phase 9 gets a `git fetch origin main` + 3-way version pre-flight that detects parallel-worktree collisions before commit. Add a new `reference/version-bump-recovery.md` for stale-bump recovery. Patch-version-bump both paired manifests.

**Done when:** SKILL.md Phase 3 recommends rebase-onto-main+FF (with guard fallback to merge), Phase 9 fetches origin/main and runs the 3-way stale-bump pre-flight, the new `reference/version-bump-recovery.md` exists, the SHA-equality-test caveat is in the anti-pattern list, both `plugin.json` files bumped to 2.27.1, all grep-based static checks pass, and the SKILL.md frontmatter still parses as YAML.

**Execution order:**

```
T1 (new reference file) ──┐
T2 (Phase 3 edits)        ├──→ T5 (version bump) ──→ T6 (final verification)
T3 (Phase 9 edits)        │
T4 (anti-pattern entry) ──┘
```

T1–T4 are largely independent edits to non-overlapping spans; can run sequentially in any order. T5 depends on T1–T4 (only bump after content changes are in). T6 depends on T5.

---

## Decision Log

> Architecture decisions inherited from `02_spec.md` (D1–D9). Implementation-specific decisions below.

| # | Decision | Options Considered | Rationale |
|---|----------|--------------------|-----------|
| P1 | No `pytest`-style red/green TDD for SKILL.md prose; verify via grep-based static checks + a SKILL-frontmatter YAML parse + manual scenario recipe. | (a) Force pytest-style TDD on prose changes (round-peg-square-hole). (b) Static grep + frontmatter parse (chosen). (c) Author a custom shell test harness for SKILL.md content. | (a) is ceremonial. (c) is over-engineering for a 2-FR change. (b) is the convention used elsewhere in this repo when modifying SKILL.md (per recent commits 613a057, a9a8d9e). |
| P2 | Reference file written in T1 (before SKILL.md edits) so SKILL.md can link to it without dangling reference. | (a) Reference file last. (b) Reference file first (chosen). | Forward references are fine in markdown but checking the link at T2 commit time prevents a window where the SKILL.md cites a missing file. |
| P3 | Replace spec §13.3's `tools/lint-pipeline-setup-inline.sh` reference with a `git diff` check on the inline-block markers (script doesn't exist in this repo). | (a) Author the lint script (out of scope). (b) Use `git diff` against HEAD to confirm Phase 0 block untouched (chosen). | Phase 2 code study revealed the script doesn't exist. The pre-existing convention is to manually confirm inline-block stability — `git diff plugins/pmos-toolkit/skills/complete-dev/SKILL.md \| grep -A2 'pipeline-setup-block'` is sufficient. |
| P4 | Phase 9's pre-flight runs synchronously before the bump prompt (does not background). | (a) Background fetch + show prompt; race. (b) Sync (chosen). | NFR-01 caps wall-clock at 3s + 10s hard kill; user-perceived latency is acceptable. Backgrounding adds race-condition complexity for negligible gain. |
| P5 | Anti-pattern numbering: append as #14 (after current #13). | (a) Insert in topical order. (b) Append (chosen). | Append preserves existing numbering used by other docs/comments referencing specific anti-pattern numbers. |
| P6 | Patch bump only; no new flag, no behaviour the user must opt into. | (a) Minor (new reference file is additive). (b) Patch (chosen). | Per spec D9 + repo convention: behaviour-within-existing-phases changes are patch even when adding a reference file, since no skill API surface changed. |
| P7 | T5 bumps versions but does NOT commit yet — final commit happens in T6 after verification. | (a) Bump+commit per task. (b) Bump in T5, single ceremony commit in T6 after verify (chosen). | The repo's `/complete-dev` will run on this branch; it expects a single coherent commit at the end of feature work. Pre-bumping during /execute would create an awkward intermediate state. |

---

## Code Study Notes

- **`plugins/pmos-toolkit/skills/complete-dev/SKILL.md`** (531 lines) — Phase 3 lives at lines 90–108, Phase 9 at lines 214–232, anti-pattern list at lines 429–443. The inline Phase 0 block is in `_shared/pipeline-setup.md`, not this file (so this change does NOT touch the inline-block-lint surface).
- **Reference-file convention** — existing files in `complete-dev/reference/` (commit-style.md, deploy-norms.md, learnings-scan.md, rollback-recipes.md) are 65–82 lines each. The new `version-bump-recovery.md` will be ≤30 lines per spec FR-16 — a tighter, recipe-only file.
- **Pre-push hook** — `.githooks/pre-push` enforces `local_v != remote_v` at push time. The pre-flight check we're adding mirrors this logic earlier in the flow; no hook changes required.
- **Paired manifests** — `plugins/pmos-toolkit/.claude-plugin/plugin.json` and `plugins/pmos-toolkit/.codex-plugin/plugin.json` both at `2.27.0`. Bump must apply to both atomically.
- **`AskUserQuestion` style** — existing Phase 9 prompt format ("question:" / "options:" with `(Recommended)` annotation) is the pattern to extend; new FR-11 prompt follows the same convention.

---

## Prerequisites

- On a feature branch (or in a worktree) — this work will eventually ship via `/complete-dev` itself.
- `git status` clean before T1 (or only the pipeline docs `00_triage.md`, `01_requirements.md`, `02_spec.md`, `03_plan.md` modified).
- No `git rebase` or `git merge` in flight.

---

## File Map

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `plugins/pmos-toolkit/skills/complete-dev/reference/version-bump-recovery.md` | ≤30 lines: stale-bump recovery recipe (3-step `git checkout` + re-bump), failure modes, manual fallback. |
| Modify | `plugins/pmos-toolkit/skills/complete-dev/SKILL.md` (Phase 3, ~lines 90–108) | Reorder AskUserQuestion options (rebase first, Recommended); insert shared-branch guard pseudocode block before the prompt; expand merge step list with the explicit rebase-then-FF command sequence (FR-04). |
| Modify | `plugins/pmos-toolkit/skills/complete-dev/SKILL.md` (Phase 9, ~lines 214–232) | Insert new pre-flight steps (fetch / read main_v / read branch_point_v / read local_v / decision-table verdict) before the existing bump-prompt; add stale-bump `AskUserQuestion` (FR-11); add pointer to new reference file (FR-17); add fetch-failure fallback paragraph (FR-06). |
| Modify | `plugins/pmos-toolkit/skills/complete-dev/SKILL.md` (Anti-pattern list, ~line 443) | Append entry #14: SHA-equality-test caveat (FR-15). |
| Modify | `plugins/pmos-toolkit/.claude-plugin/plugin.json` | Bump `version` 2.27.0 → 2.27.1. |
| Modify | `plugins/pmos-toolkit/.codex-plugin/plugin.json` | Bump `version` 2.27.0 → 2.27.1 (paired-manifest invariant). |

No test files to modify — verification is static-grep + frontmatter-parse + manual behavioural recipes (per P1).

---

## Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| Phase 3 / Phase 9 line numbers shift if SKILL.md is edited concurrently | Low | T2 and T3 use anchored Edit `old_string` matches (full unique blocks), not line numbers. |
| Adding lots of bash/git pseudocode to SKILL.md drifts it past readability budget | Medium | Keep new content under ~50 lines per phase; push procedural detail into the new reference file. |
| Anti-pattern entry duplicates an existing entry | Low | Phase 2 read of anti-pattern list confirms no overlap. |
| Phase 9 pre-flight bash gets out-of-sync with `.githooks/pre-push` (which uses `sed`-based version parsing, not `jq`) | Medium | The pre-flight uses `jq` for SKILL.md prose readability; the hook's `sed` approach stays. Both extract the same field; if `jq` not installed users are unlikely to be running /complete-dev anyway, but T6 verification will spot it. |
| Patch bump rejected by user as wrong tier | Low | P6 rationale documented; if minor preferred, edit T5 commands. |

---

## Rollback

This plan does not introduce migrations, deploys, or data mutations. Rollback is `git revert <commit>` on the eventual ceremony commit. No special recipe needed.

---

## Tasks

### T1: Create `reference/version-bump-recovery.md`

**Goal:** Author the stale-bump recovery recipe as a standalone reference file before SKILL.md links to it.
**Spec refs:** FR-12, FR-16, FR-17

**Files:**
- Create: `plugins/pmos-toolkit/skills/complete-dev/reference/version-bump-recovery.md`

**Steps:**

- [ ] Step 1: Write the file with the recipe content. Target ≤30 lines.

  Content to write (the implementor pastes this verbatim — no judgment needed):

  ```markdown
  # Version-bump recovery — stale speculative bump

  Triggered by `/complete-dev` Phase 9 when the pre-flight detects a stale
  speculative bump on the feature branch (local plugin.json bumped past the
  branch point, AND main shipped its own bump in the meantime).

  ## Recipe

  1. **Restore both paired manifests** to main's HEAD version:

     ```bash
     git checkout origin/main -- \
       plugins/pmos-toolkit/.claude-plugin/plugin.json \
       plugins/pmos-toolkit/.codex-plugin/plugin.json
     ```

  2. **Re-run the bump prompt** (Phase 9 step 6) — baseline now reads
     correctly as `main_v`. Pick the bump kind appropriate for your changes
     (Patch / Minor / Major) on top of the new baseline.

  3. **Validate JSON** parses for both files (Phase 9 already does this):

     ```bash
     python3 -c "import json; json.load(open('plugins/pmos-toolkit/.claude-plugin/plugin.json'))"
     python3 -c "import json; json.load(open('plugins/pmos-toolkit/.codex-plugin/plugin.json'))"
     ```

  Phase 11 commits the corrected bump alongside the rest of the ceremony.

  ## Failure modes

  - **`git checkout origin/main -- <file>` fails** ("pathspec did not match any files")
    → `origin/main` doesn't have the manifest at that path. Verify
    `git ls-tree origin/main plugins/pmos-toolkit/.claude-plugin/plugin.json`;
    fall back to manual edit.
  - **User declines recovery** (picks "Keep going anyway") → proceed; pre-push
    hook will reject the duplicate version. Recovery becomes a manual edit
    after the rejection.

  ## Manual fallback

  Edit both `plugin.json` files by hand to a version strictly greater than
  the version on `origin/main`. Both files MUST carry the same version (the
  pre-push hook rejects mismatch).
  ```

- [ ] Step 2: Verify the file is created and ≤40 lines.

  Run: `/usr/bin/wc -l plugins/pmos-toolkit/skills/complete-dev/reference/version-bump-recovery.md`
  Expected: a number ≤ 40 (allow a small buffer over the 30 target).

- [ ] Step 3: Stage (do NOT commit yet — single coherent commit at T6 per P7).

  Run: `git add plugins/pmos-toolkit/skills/complete-dev/reference/version-bump-recovery.md`
  Expected: no error; file appears in `git status` as `new file:`.

**Inline verification:**
- `test -f plugins/pmos-toolkit/skills/complete-dev/reference/version-bump-recovery.md` — exit 0.
- `/usr/bin/grep -c '^## ' plugins/pmos-toolkit/skills/complete-dev/reference/version-bump-recovery.md` — outputs `3` (Recipe / Failure modes / Manual fallback).
- `/usr/bin/grep -q 'git checkout origin/main' plugins/pmos-toolkit/skills/complete-dev/reference/version-bump-recovery.md` — exit 0.

---

### T2: Modify Phase 3 — default flip + shared-branch guard

**Goal:** Reorder Phase 3's AskUserQuestion options (rebase first, Recommended) and prepend a shared-branch guard pseudocode block; expand the rebase command sequence per FR-04.
**Spec refs:** FR-01, FR-02, FR-03, FR-04, FR-05

**Files:**
- Modify: `plugins/pmos-toolkit/skills/complete-dev/SKILL.md` (Phase 3 region)

**Steps:**

- [ ] Step 1: Open the file and locate the Phase 3 region by searching for `## Phase 3 — Merge feature → main`.

- [ ] Step 2: Replace the existing Phase 3 body with the new content. Use `Edit` with the full Phase 3 block as `old_string` (anchored, unique) — do NOT rely on line numbers.

  **`old_string`** (current Phase 3, from spec §6 of plan):

  ```text
  ## Phase 3 — Merge feature → main

  If on a feature branch:

  ```
  question: "Land branch <name> into main how?"
  options:
    - Merge into main (fast-forward if possible, else --no-ff merge commit) (Recommended)
    - Rebase onto main, then fast-forward
    - Stay on feature branch and push only this branch
    - Cancel
  ```

  If merge chosen:
  1. Verify uncommitted state is clean (or surface to commit them first; ask user)
  2. `cd <root-main-path>` if currently in a worktree
  3. `git checkout main`
  4. `git pull origin main` (sync first)
  5. `git merge <feature-branch>` (fast-forward where possible; `--no-ff` if explicitly chosen)
  6. **Conflicts → STOP and ask user. Do NOT auto-resolve.**
  ```

  **`new_string`** (new Phase 3 — paste verbatim, including the four code fences):

  ```text
  ## Phase 3 — Merge feature → main

  If on a feature branch:

  **Step A — Shared-branch guard.** Before showing the prompt, determine whether rebasing is safe:

  ```bash
  upstream=$(git rev-parse --abbrev-ref --symbolic-full-name @{upstream} 2>/dev/null || true)
  if [ -z "$upstream" ]; then
    guard=PASS  # no upstream → rebase-safe
  else
    git fetch "${upstream%/*}" "${upstream#*/}" 2>/dev/null || true
    if [ "$(git rev-parse HEAD)" = "$(git rev-parse "$upstream")" ]; then
      guard=PASS
    else
      guard=FAIL  # remote tip diverged → rebase would rewrite SHAs others may have pulled
    fi
  fi
  ```

  **Step B — Show the prompt.** Annotation flips based on guard.

  - **Guard PASS** (default — solo branch or unpushed):

    ```
    question: "Land branch <name> into main how?"
    options:
      - Rebase onto main, then fast-forward (Recommended)
      - Merge into main (fast-forward if possible, else --no-ff merge commit)
      - Stay on feature branch and push only this branch
      - Cancel
    ```

  - **Guard FAIL** (branch shared, remote diverged):

    ```
    question: "Branch <name> has been pushed and remote tip differs from local — rebase would rewrite SHAs others may have. Land into main how?"
    options:
      - Merge into main (--no-ff if not fast-forward) (Recommended)
      - Rebase onto main, then fast-forward (WARNING: rewrites SHAs)
      - Stay on feature branch and push only this branch
      - Cancel
    ```

  **Step C — Execute the chosen option.**

  If **rebase** chosen, the explicit sequence:

  1. Verify uncommitted state is clean (or commit; ask user)
  2. `cd <root-main-path>` if currently in a worktree
  3. `git checkout main && git pull origin main`
  4. `git checkout <feature-branch>`
  5. `git rebase main` — **conflicts → STOP and ask user. Do NOT auto-resolve.**
  6. `git checkout main`
  7. `git merge --ff-only <feature-branch>` (guaranteed safe after step 5)

  If **merge** chosen, the existing sequence:

  1. Verify uncommitted state is clean
  2. `cd <root-main-path>` if currently in a worktree
  3. `git checkout main`
  4. `git pull origin main`
  5. `git merge <feature-branch>` (fast-forward where possible; `--no-ff` if explicitly chosen)
  6. **Conflicts → STOP and ask user. Do NOT auto-resolve.**
  ```

- [ ] Step 3: Verify Phase 3 changes landed.

  Run:
  ```bash
  /usr/bin/grep -n 'Rebase onto main, then fast-forward (Recommended)' plugins/pmos-toolkit/skills/complete-dev/SKILL.md
  /usr/bin/grep -n 'Shared-branch guard' plugins/pmos-toolkit/skills/complete-dev/SKILL.md
  /usr/bin/grep -n 'merge --ff-only <feature-branch>' plugins/pmos-toolkit/skills/complete-dev/SKILL.md
  ```
  Expected: each grep returns exactly one match in the Phase 3 region.

**Inline verification:**
- `python3 -c "import yaml; yaml.safe_load(open('plugins/pmos-toolkit/skills/complete-dev/SKILL.md').read().split('---',2)[1]); print('OK')"` — outputs `OK`.
- Three `grep` commands above all match.
- `git diff plugins/pmos-toolkit/skills/complete-dev/SKILL.md | grep -c '^+' | awk '$1 < 80'` — confirms added-line count is reasonable (<80 added lines for Phase 3).

---

### T3: Modify Phase 9 — fetch + 3-way pre-flight + recovery hookup

**Goal:** Insert pre-flight steps before the existing bump prompt; add the stale-bump AskUserQuestion (FR-11); link the new reference file.
**Spec refs:** FR-06, FR-07, FR-08, FR-09, FR-10, FR-11, FR-13, FR-14, FR-17, NFR-01, NFR-03

**Files:**
- Modify: `plugins/pmos-toolkit/skills/complete-dev/SKILL.md` (Phase 9 region)

**Steps:**

- [ ] Step 1: Locate the Phase 9 header (`## Phase 9 — Version bump`).

- [ ] Step 1a: Read the Phase 9 region of SKILL.md to capture the exact `old_string` text for the Edit. Use `Read` with `file_path=plugins/pmos-toolkit/skills/complete-dev/SKILL.md`, `offset=210`, `limit=30` (covers Phase 9 header + body in current 531-line file). The implementor builds the `old_string` from the lines returned — character-exact, including blank lines and code-fence markers.

- [ ] Step 2: Replace the body of Phase 9 with the new content. Use `Edit` with the full Phase 9 block as `old_string` (anchored — captured in Step 1a).

  **`old_string`** — current Phase 9 body, captured verbatim in Step 1a. Starts at `If skill content changed...` and ends at the `Apply via Edit. Validate JSON parses...` line of current SKILL.md.

  **`new_string`** — the new Phase 9 body:

  ```text
  If skill content changed (Phase 0 detected new/modified files under `plugins/pmos-toolkit/skills/` or `plugins/pmos-toolkit/agents/`), bump is **mandatory** — pre-push hook enforces.

  **Paired-manifest special case**: if BOTH `plugins/pmos-toolkit/.claude-plugin/plugin.json` AND `plugins/pmos-toolkit/.codex-plugin/plugin.json` exist, treat as ONE logical version that bumps together.

  **Step 1 — Pre-flight: sync main reference.**

  ```bash
  git fetch origin main 2>&1   # NFR-01: 10s hard timeout via `timeout 10 git fetch origin main` if available
  ```

  On non-zero exit, log `pre-flight skipped: could not fetch origin/main; pre-push hook will catch any version collision` and set `pre_flight_skipped=true`. Skip to Step 5.

  **Step 2 — Read main_v.**

  ```bash
  main_v=$(git show origin/main:plugins/pmos-toolkit/.claude-plugin/plugin.json | jq -r .version)
  ```

  On parse failure, treat as Step 1 failure (skip pre-flight, warn).

  **Step 3 — Read branch_point_v.**

  ```bash
  merge_base=$(git merge-base HEAD origin/main)
  branch_point_v=$(git show "$merge_base":plugins/pmos-toolkit/.claude-plugin/plugin.json | jq -r .version || echo "$main_v")
  ```

  If lookup fails, fall back to `branch_point_v=$main_v` (degraded 2-way mode; warn).

  **Step 4 — Read local_v + decide.**

  ```bash
  local_v=$(jq -r .version plugins/pmos-toolkit/.claude-plugin/plugin.json)
  ```

  Apply the decision table (semantic-version compare on each cell):

  | `local_v` vs `branch_point_v` | `main_v` vs `branch_point_v` | Verdict |
  |---|---|---|
  | equal (no local bump yet) | equal (no parallel ship) | **Clean**: bump baseline = `main_v` |
  | equal (no local bump yet) | greater (parallel ship happened) | **Clean-after-rebase**: bump baseline = `main_v` |
  | greater (local already bumped) | equal (no parallel ship) | **Fresh local bump**: proceed; baseline already advanced |
  | greater (local already bumped) | greater (parallel ship + local bump on stale base) | **Stale-bump**: trigger recovery prompt below |
  | less (impossible-ish) | any | **Anomaly**: warn user; ask whether Phase 3 succeeded; offer skip-or-cancel |

  **Step 4a — Stale-bump recovery prompt** (only on Stale-bump verdict):

  ```
  question: "Stale version bump detected: feature branch has plugin.json at v<local_v>, branched from v<branch_point_v>, but main shipped v<main_v> since. What now?"
  options:
    - Revert the speculative bump and re-bump from main (Recommended)
    - Keep going anyway (will likely fail pre-push hook)
    - Cancel — let me investigate manually
  ```

  If "Revert and re-bump", run the recipe in `reference/version-bump-recovery.md`, then continue at Step 5 with the restored manifests.

  **Step 5 — Bump prompt.**

  ```
  question: "Current version is <baseline_v>. What kind of bump?"
  options:
    - Patch (X.Y.Z+1) — bug fix, content tweak, doc-only
    - Minor (X.Y+1.0) — new skill, additive feature (Recommended for new skills)
    - Major (X+1.0.0) — breaking change to skill API or removed skill
    - Skip version bump (only if no plugin content changed)
  ```

  Where `<baseline_v>` is `main_v` (when pre-flight ran cleanly) or `local_v` with suffix `(pre-flight skipped — verify manually)` when `pre_flight_skipped=true`.

  Apply the bump to BOTH paired manifests (paired-manifest invariant). Validate JSON parses:

  ```bash
  python3 -c "import json; json.load(open('plugins/pmos-toolkit/.claude-plugin/plugin.json'))"
  python3 -c "import json; json.load(open('plugins/pmos-toolkit/.codex-plugin/plugin.json'))"
  ```

  **Stale-bump recovery:** see `reference/version-bump-recovery.md`.

  **For other monorepo cases**: detect via multiple `package.json` files; only offer bumps for paths that actually changed (`git diff --name-only main..HEAD` mapped to package roots).
  ```

- [ ] Step 3: Verify Phase 9 changes landed.

  Run:
  ```bash
  /usr/bin/grep -n 'git fetch origin main' plugins/pmos-toolkit/skills/complete-dev/SKILL.md
  /usr/bin/grep -n 'Stale-bump' plugins/pmos-toolkit/skills/complete-dev/SKILL.md
  /usr/bin/grep -n 'reference/version-bump-recovery.md' plugins/pmos-toolkit/skills/complete-dev/SKILL.md
  /usr/bin/grep -n 'Clean-after-rebase' plugins/pmos-toolkit/skills/complete-dev/SKILL.md
  ```
  Expected: each grep returns ≥1 match in the Phase 9 region.

**Inline verification:**
- `python3 -c "import yaml; yaml.safe_load(open('plugins/pmos-toolkit/skills/complete-dev/SKILL.md').read().split('---',2)[1]); print('OK')"` — outputs `OK`.
- All four `grep` commands above match.

---

### T4: Append anti-pattern entry — SHA-equality test caveat

**Goal:** Add the necessary-but-not-sufficient caveat (FR-15) as a new anti-pattern entry at the end of the existing list.
**Spec refs:** FR-15

**Files:**
- Modify: `plugins/pmos-toolkit/skills/complete-dev/SKILL.md` (Anti-patterns section, end of file)

**Steps:**

- [ ] Step 1: Locate the last existing anti-pattern (#13: "Scanning the conversation transcript for learnings").

- [ ] Step 1a: Read the anti-pattern list region of SKILL.md to capture the exact text of entry #13 as the Edit anchor. Use `Read` with `file_path=plugins/pmos-toolkit/skills/complete-dev/SKILL.md`, `offset=429`, `limit=20` (covers the entire anti-pattern list in the current 531-line file). Capture entry #13's full text verbatim for the `old_string` of Step 2.

- [ ] Step 2: Use `Edit` with `old_string` matching anti-pattern #13's full text (from Step 1a) and `new_string` containing both #13 (unchanged) and the new #14:

  ```text
  14. **Trusting the shared-branch guard's `local==remote SHA` test as proof no one has based work on this branch.** It's necessary-but-not-sufficient — a coworker who pulled before our last fixup could have based work, and we'd never know. The pre-push hook is the only authoritative line of defence; use the merge fallback for any branch you've shared for review.
  ```

- [ ] Step 3: Verify the new entry exists and is numbered #14.

  Run:
  ```bash
  /usr/bin/grep -nE '^14\. \*\*Trusting the shared-branch guard' plugins/pmos-toolkit/skills/complete-dev/SKILL.md
  ```
  Expected: exactly one match.

**Inline verification:**
- `/usr/bin/grep -c '^[0-9]\+\. \*\*' plugins/pmos-toolkit/skills/complete-dev/SKILL.md` — outputs `14` (one more than current `13`).
- `/usr/bin/grep -q 'necessary-but-not-sufficient' plugins/pmos-toolkit/skills/complete-dev/SKILL.md` — exit 0.

---

### T5: Bump paired manifest versions 2.27.0 → 2.27.1

**Goal:** Patch-bump both `plugin.json` files atomically.
**Spec refs:** FR-14 (paired invariant), §14 Rollout Strategy

**Files:**
- Modify: `plugins/pmos-toolkit/.claude-plugin/plugin.json`
- Modify: `plugins/pmos-toolkit/.codex-plugin/plugin.json`

**Steps:**

- [ ] Step 1: Edit `.claude-plugin/plugin.json`:

  Use `Edit` with `old_string='"version": "2.27.0"'` and `new_string='"version": "2.27.1"'`.

- [ ] Step 2: Edit `.codex-plugin/plugin.json`:

  Use `Edit` with `old_string='"version": "2.27.0"'` and `new_string='"version": "2.27.1"'`.

- [ ] Step 3: Validate JSON parses for both files.

  Run:
  ```bash
  python3 -c "import json; json.load(open('plugins/pmos-toolkit/.claude-plugin/plugin.json'))"
  python3 -c "import json; json.load(open('plugins/pmos-toolkit/.codex-plugin/plugin.json'))"
  ```
  Expected: no output (no exception).

- [ ] Step 4: Confirm versions match across paired manifests.

  Run:
  ```bash
  /usr/bin/grep '"version"' plugins/pmos-toolkit/.claude-plugin/plugin.json plugins/pmos-toolkit/.codex-plugin/plugin.json
  ```
  Expected output:
  ```
  plugins/pmos-toolkit/.claude-plugin/plugin.json:  "version": "2.27.1",
  plugins/pmos-toolkit/.codex-plugin/plugin.json:  "version": "2.27.1",
  ```

**Inline verification:**
- Both files parse as JSON (Step 3).
- Both versions match `2.27.1` (Step 4).

---

### T6: Final Verification

**Goal:** Confirm the entire change is coherent — all static checks pass, frontmatter valid, behavioural recipes documented, then commit the ceremony.

- [ ] **Frontmatter parse:**
  ```bash
  python3 -c "import yaml; yaml.safe_load(open('plugins/pmos-toolkit/skills/complete-dev/SKILL.md').read().split('---',2)[1]); print('OK')"
  ```
  Expected: `OK`.
- [ ] **JSON parse (both manifests):**
  ```bash
  python3 -c "import json; json.load(open('plugins/pmos-toolkit/.claude-plugin/plugin.json'))"
  python3 -c "import json; json.load(open('plugins/pmos-toolkit/.codex-plugin/plugin.json'))"
  ```
  Expected: no errors.
- [ ] **Phase 3 default-flip evidence:**
  ```bash
  /usr/bin/grep -n 'Rebase onto main, then fast-forward (Recommended)' plugins/pmos-toolkit/skills/complete-dev/SKILL.md
  /usr/bin/grep -n 'Shared-branch guard' plugins/pmos-toolkit/skills/complete-dev/SKILL.md
  ```
  Expected: 1 match each.
- [ ] **Phase 9 pre-flight evidence:**
  ```bash
  /usr/bin/grep -n 'git fetch origin main' plugins/pmos-toolkit/skills/complete-dev/SKILL.md
  /usr/bin/grep -n 'Clean-after-rebase' plugins/pmos-toolkit/skills/complete-dev/SKILL.md
  /usr/bin/grep -n 'Stale-bump' plugins/pmos-toolkit/skills/complete-dev/SKILL.md
  ```
  Expected: 1 match each.
- [ ] **Anti-pattern entry #14:**
  ```bash
  /usr/bin/grep -nE '^14\. \*\*Trusting the shared-branch guard' plugins/pmos-toolkit/skills/complete-dev/SKILL.md
  /usr/bin/grep -c '^[0-9]\+\. \*\*' plugins/pmos-toolkit/skills/complete-dev/SKILL.md
  ```
  Expected: 1 match for the named entry; total count `14`.
- [ ] **Reference file present + sized correctly:**
  ```bash
  test -f plugins/pmos-toolkit/skills/complete-dev/reference/version-bump-recovery.md
  /usr/bin/wc -l plugins/pmos-toolkit/skills/complete-dev/reference/version-bump-recovery.md
  ```
  Expected: file exists; line count ≤ 40.
- [ ] **Phase 0 inline block untouched** (P3 — replaces the missing lint script):
  ```bash
  git diff plugins/pmos-toolkit/skills/complete-dev/SKILL.md | /usr/bin/grep -E 'pipeline-setup-block:(start|end)' || echo "Phase 0 inline-block markers untouched"
  ```
  Expected: `Phase 0 inline-block markers untouched` (the markers themselves never appear in this skill's SKILL.md, so this is a defensive check; if it ever does match, abort and inspect).
- [ ] **Versions paired:**
  ```bash
  /usr/bin/grep '"version"' plugins/pmos-toolkit/.claude-plugin/plugin.json plugins/pmos-toolkit/.codex-plugin/plugin.json
  ```
  Expected: both lines show `"version": "2.27.1",`.
- [ ] **Behavioural verification recipes** (manual; do NOT block /execute completion — these get exercised when the user actually runs `/complete-dev` against this branch):
  - Solo branch, clean rebase: confirm Phase 3 prompt has rebase as `(Recommended)`.
  - Shared branch, divergent remote: simulate by pushing branch + local fixup, confirm guard FAILS and merge becomes `(Recommended)`.
  - Parallel-worktree collision: requires two worktrees; confirm Phase 9 pre-flight reports `Clean-after-rebase` after rebase pulls in the parallel ship.
  - Speculative-bump recovery: requires speculative commit + parallel ship; confirm stale-bump prompt fires and recovery recipe restores manifests.

  These are documented expectations for /verify and the user's first ceremony, not /execute gates.
- [ ] **Stage and commit ceremony:**
  ```bash
  git add \
    plugins/pmos-toolkit/skills/complete-dev/SKILL.md \
    plugins/pmos-toolkit/skills/complete-dev/reference/version-bump-recovery.md \
    plugins/pmos-toolkit/.claude-plugin/plugin.json \
    plugins/pmos-toolkit/.codex-plugin/plugin.json
  git commit -m "$(cat <<'EOF'
feat(complete-dev): rebase-by-default + parallel-worktree version-bump pre-flight (2.27.1)

Phase 3 now defaults to rebase-onto-main+FF when the shared-branch guard passes
(no upstream OR local SHA == remote SHA); falls back to --no-ff merge when the
guard fails. Phase 9 fetches origin/main and runs a 3-way (local / main /
branch-point) version pre-flight that detects parallel-worktree collisions
before commit, with an interactive recovery flow sourced from the new
reference/version-bump-recovery.md. Anti-pattern #14 documents the SHA-equality
test's necessary-but-not-sufficient nature.

Patch bump (paired manifests 2.27.0 → 2.27.1).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
  ```
  Expected: clean commit; `git log -1 --oneline` shows the new commit.

**Cleanup:**
- N/A — no temp files, no containers, no feature flags introduced.

---

## Review Log

| Loop | Findings | Changes Made |
|------|----------|-------------|
| 1 | F-1 [Should-fix] T3's "copy verbatim from current SKILL.md" relied on implicit Read; F-2 [Nit] decision log already exceeds 3-entry minimum (no action). | F-1 applied: T3 gained Step 1a with explicit `Read` parameters (offset=210, limit=30). |
| 2 | F-3 [Should-fix] T4 has the same Read-first issue as T3 (anti-pattern #13 anchor not captured). No design-critique concerns. | F-3 applied: T4 gained Step 1a with explicit `Read` parameters (offset=429, limit=20). User confirmed no further gaps. |
