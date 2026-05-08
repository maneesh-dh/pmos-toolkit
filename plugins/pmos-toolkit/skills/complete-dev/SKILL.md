---
name: complete-dev
description: End-of-development orchestrator that follows /verify — merges feature work into main, captures learnings into CLAUDE.md/AGENTS.md, regenerates the changelog, bumps versions, deploys per repo norms, tags the release, and pushes to all configured remotes. Supersedes the legacy /push skill. Terminal stage of the requirements -> spec -> plan -> execute -> verify -> complete-dev pipeline. Use when the user says "complete the dev cycle", "ship this work", "merge and deploy", "wrap up this branch", "finish development", "ready to push and deploy", "push to remotes", "push and ship", or "push the release".
user-invocable: true
argument-hint: "[--skip-changelog] [--skip-deploy] [--no-tag] [optional commit-message hint]"
---

# /complete-dev — end-of-development orchestrator

Runs the full end-of-dev ceremony after `/verify`: merge → worktree cleanup → deploy detection → learnings capture → README + /changelog → version bump → commit → tag → push.

**Announce at start:** "Running /complete-dev: end-of-dev ceremony — merge, deploy, learnings, commit, tag, push. Approval gates at every destructive step."

## Pipeline position

```
/requirements → [/msf-req, /creativity] → /spec → /plan → /execute → /verify → /complete-dev (this skill)
                  optional enhancers
```

Standalone-ish: invokes `/changelog` (Phase 8) and optionally `/verify` (Phase 1).

## Track Progress

This skill has 19 phases. Create one task per phase using your agent's task-tracking tool (e.g., `TaskCreate` in Claude Code, equivalent elsewhere). Mark each task in-progress when you start it and completed as soon as it finishes — do not batch completions.

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:

- **No `AskUserQuestion`:** state your assumption, document it in the final report, proceed. Never silently skip a phase. Specifically: default deploy method to "skip deploy" if undetermined; default merge style to fast-forward if possible; default version bump to patch.
- **No subagents:** Phase 6 learnings scan and Phase 8 /changelog run inline (sequential). No dispatch needed.
- **No Playwright / MCP:** N/A — this skill has no browser-based steps.
- **No `TaskCreate` / `TodoWrite`:** print phase headers as text progress markers.
- **/changelog unavailable:** skip Phase 8 with a warning; suggest manual changelog edit. Same path as `--skip-changelog`.
- **/verify unavailable:** Phase 1's "Run /verify now" option becomes "Run verify manually then resume" with a pause.

## Load Learnings

Read `~/.pmos/learnings.md` if it exists. Note any entries under `## /complete-dev` and factor them into your approach for this session. If the file doesn't exist, skip silently.

## Arguments

`$ARGUMENTS` may contain:

- `--skip-changelog` — bypass Phase 8 (still runs Phase 5 detection so dry-run summary documents what was skipped)
- `--skip-deploy` — bypass Phase 15's deploy invocation only (push and tag still happen)
- `--no-tag` — bypass Phase 13 tagging (push still happens)
- Free-form text — used as the commit-message hint draft in Phase 11

---

## Phase 0 — Sanity & state

Run in parallel:
- `git status --porcelain` (uncommitted state)
- `git branch --show-current` (current branch)
- `git remote -v` (which remotes are configured)
- `git worktree list` (am I in a worktree?)
- `git log --oneline -5`
- `git status -sb` (ahead/behind tracking)

Print a one-line state summary: `Branch: <name>; Worktree: <yes|no>; Uncommitted: <N>; Remotes: <list>; Ahead of origin: <N>`.

## Phase 1 — /verify gate

ALWAYS ask via `AskUserQuestion` (no auto-detection — branch state changes via amend/rebase make commit-pattern detection unreliable):

```
question: "Has /verify been run for this branch's current state?"
options:
  - Already ran, continue (Recommended)
  - Run /verify now — invoke /pmos-toolkit:verify, then resume
  - Skip — I accept the risk for this push
  - Cancel /complete-dev
```

If "Run /verify now" → invoke `/pmos-toolkit:verify` inline. If verify fails, abort /complete-dev.

## Phase 2 — Worktree + branch detection

Determine:
- Is the current cwd a worktree? (`git rev-parse --git-common-dir` differs from `git rev-parse --git-dir` when in a worktree)
- What's the feature branch? (current branch unless on main)
- Where's the root main checkout? (`git worktree list` first entry, or the dir whose `.git` is a directory not a file)

If on `main` already: skip to Phase 5 (no merge needed; treat as direct-to-main flow).

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

## Phase 4 — Worktree cleanup

If Phase 2 detected a worktree and Phase 3 merged successfully:

```
question: "Worktree at <path> can be removed (changes merged to main locally). Remove now?"
options:
  - Remove worktree (Recommended)
  - Keep worktree (I want to inspect it before push)
  - Cancel
```

If "Remove": `git worktree remove <path>`. **Note**: this happens BEFORE push by design. If push fails later (Phase 15), the worktree is already gone — recovery uses the rollback recipes in `reference/rollback-recipes.md`, not the worktree.

Cwd is now the root main checkout; print confirmation.

## Phase 5 — Detect deployment norms

Probe and **enumerate ALL detected signals** (do not pick silently):

1. `CLAUDE.md` / `AGENTS.md` for explicit "Deploy:" or "Release:" sections
2. `package.json` `scripts.deploy` / `scripts.release` / `scripts.publish`
3. `Makefile` targets named `deploy`, `release`, `publish`
4. `.github/workflows/` files that trigger on `push` to `main` (CI auto-deploy)
5. Plugin manifest at `plugins/pmos-toolkit/.claude-plugin/plugin.json` (this repo: deploy = push to remotes)

See `reference/deploy-norms.md` for the full detection rubric.

Present detected signals + a recommendation. Example:

```
Detected deploy signals:
  (1) package.json scripts.deploy: "vercel deploy --prod"
  (2) .github/workflows/deploy.yml on push to main (CI auto-deploy)

Recommendation: skip explicit deploy — CI handles it on push.

question: "Which deploy path?"
options:
  - Skip explicit deploy (CI handles it) (Recommended)
  - Run npm run deploy locally
  - Run both (risk of double-deploy)
  - Skip deploy entirely (--skip-deploy effect)
```

If `--skip-deploy` flag: still show this menu but pre-pick the skip option in the dry-run summary.

## Phase 6 — Capture learnings

Scan `git diff main..HEAD` (or `git diff origin/main..HEAD` post-merge) plus the last N feature-branch commit messages. **Do NOT scan conversation transcript.** See `reference/learnings-scan.md` for the heuristics.

Generate up to 8 candidate learnings. Group by target file (CLAUDE.md, AGENTS.md, ~/.pmos/learnings.md). Present via the **Findings Presentation Protocol**:

For each candidate, ask via `AskUserQuestion` (batched ≤4 per call):

```
question: "<one-sentence finding> — propose adding to <file>: '<text>'"
options:
  - Add as proposed (Recommended)
  - Edit text — I'll dictate the replacement
  - Skip this entry
  - Defer to manual edit later
```

Apply approved entries inline. Stage the edited files for the Phase 11 commit.

**Platform fallback** (no AskUserQuestion): print numbered findings table with disposition column; user replies with disposition list; never auto-write.

## Phase 7 — README freshness check

Detect skill inventory drift (per /push Phase 1.5 logic):

- Skill directories on disk: `/bin/ls plugins/pmos-toolkit/skills/ | grep -vE "^(_shared|\.shared|\.system)$"`
- Skill rows in README: `/usr/bin/grep -oE '/pmos-toolkit:[a-z-]+' README.md | sort -u`

If diff exists, ask:

```
question: "README is out of sync — <new-skills> missing, <removed-skills> still listed. Update?"
options:
  - Update README now (Recommended)
  - Skip — I'll update README in a follow-up
  - Cancel
```

If "Update": read each new skill's `SKILL.md` `description:` and add a categorized row (Pipeline / Enhancers / Artifacts & docs / Tracking & context / Utilities — ask if unclear). Remove rows for deleted skills. Show diff before staging.

## Phase 8 — Run /changelog (unless --skip-changelog)

If `--skip-changelog`: skip with a one-line warning.

Otherwise: invoke `/pmos-toolkit:changelog` inline. /changelog writes to `{docs_path}/changelog.md` (resolved via `.pmos/settings.yaml`).

After /changelog completes, surface the diff to the user:

```
question: "Changelog drafted. Use this entry?"
options:
  - Looks good (Recommended)
  - Let me edit before commit
  - Re-run /changelog
  - Skip changelog this run
```

## Phase 9 — Version bump

If skill content changed (Phase 0 detected new/modified files under `plugins/pmos-toolkit/skills/` or `plugins/pmos-toolkit/agents/`), bump is **mandatory** — pre-push hook enforces.

**Paired-manifest special case**: if BOTH `plugins/pmos-toolkit/.claude-plugin/plugin.json` AND `plugins/pmos-toolkit/.codex-plugin/plugin.json` exist, treat as ONE logical version that bumps together. Pre-flight: read both; if versions differ, ask which to use as baseline (the pre-push hook rejects mismatch).

For other monorepo cases: detect via multiple `package.json` files; only offer bumps for paths that actually changed (`git diff --name-only main..HEAD` mapped to package roots).

```
question: "Current version is X.Y.Z. What kind of bump?"
options:
  - Patch (X.Y.Z+1) — bug fix, content tweak, doc-only
  - Minor (X.Y+1.0) — new skill, additive feature (Recommended for new skills)
  - Major (X+1.0.0) — breaking change to skill API or removed skill
  - Skip version bump (only if no plugin content changed)
```

Apply via `Edit`. Validate JSON parses: `python3 -c "import json; json.load(open('<path>'))"`.

## Phase 10 — JSON schema validation

For any `.json` schema files in `plugins/pmos-toolkit/skills/*/schemas/` that changed:

```bash
python3 -c "import json; json.load(open('<schema-path>'))"
```

For paired YAML examples:

```bash
python3 -c "import json, yaml, jsonschema; jsonschema.validate(yaml.safe_load(open('<example>')), json.load(open('<schema>')))"
```

Abort and surface errors if anything fails.

## Phase 11 — Stage + commit

If uncommitted changes exist (and there will be — version bump, README, changelog, learnings):

1. Run `git diff --staged` and `git diff` to see what's being committed.
2. Run `git log --oneline -3` to match repo commit-message style. See `reference/commit-style.md` for fallback templates.
3. Draft the commit message using the user's `$ARGUMENTS` hint if provided.
4. **Surface the draft via AskUserQuestion BEFORE committing:**

```
question: "Draft commit message: '<first line>'. Use it?"
options:
  - Commit with this message (Recommended)
  - Edit the message
  - Cancel
```

5. Stage SPECIFIC files (never `git add -A` — could pick up secrets, .env, .bak). Then commit using HEREDOC:

```bash
git commit -m "$(cat <<'EOF'
<message>

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

6. Verify: `git log --oneline -1`.

## Phase 12 — Stale branch cleanup

```bash
git branch --merged main | grep -vE "^\*|^\s*main$" || true
git fetch --all --prune
git branch -vv | grep ': gone]' | awk '{print $1}'
```

If branches found, ask via multi-select:

```
question: "Cleanup eligible branches?"
multiSelect: true
options:
  - <merged-branch-1> (last commit: <date>)
  - <gone-branch-1> (remote deleted)
  - ...
  - Skip cleanup
```

Delete only selected branches with `git branch -d` (NEVER `-D`).

## Phase 13 — Tag release (unless --no-tag)

If `--no-tag`: skip.

Otherwise pre-check tag existence:

```bash
git rev-parse v<version> 2>/dev/null
```

If tag exists at expected version:

```
question: "Tag v<version> already exists at <existing-sha>. What to do?"
options:
  - Skip tagging (Recommended if version unchanged)
  - Force-replace tag (DESTRUCTIVE — rewrites tag pointer)
  - Cancel
```

Otherwise create annotated tag:

```bash
git tag -a v<version> -m "Release v<version>"
```

## Phase 14 — Dry-run summary

Print a one-screen summary BEFORE pushing:

```
=== /complete-dev summary ===
Branch:           main
Local commits:    <N> ahead of origin/main
Last commit:      <hash> <message>
Plugin version:   <X.Y.Z> (manifests in-sync: <YES|NO>)
Tag:              v<X.Y.Z> (new | force-replaced | skipped)
Deploy method:    <chosen Phase 5 path | skipped>
Pushing to:       <remote-list>
=============================
```

```
question: "Push to <N> remotes?"
options:
  - Push to all configured remotes (Recommended)
  - Push to origin only
  - Cancel
```

## Phase 15 — Deploy + push

**Step 1 — Deploy** (skipped if `--skip-deploy` or user picked skip in Phase 5):
Run the chosen deploy command. If it fails, abort BEFORE push and surface the error. Do not retry automatically.

**Step 2 — Push**, sequentially. Origin first (pre-push hook runs once):

```bash
git push origin main 2>&1
```

If origin fails → STOP. Do not push to other remotes. Surface the error.

**On push failure: NO auto-rollback.** Present recovery options:

```
question: "Push to origin failed: <error summary>. What now?"
options:
  - Fix and retry — I'll address the cause, you re-push
  - Skip this remote, push others
  - Cancel — leave local main as-is
  - DESTRUCTIVE: full rollback to pre-merge SHA <sha> (loses ceremony commits)
```

If "Fix and retry" → proceed to Phase 15.5.

If origin succeeds, continue with other configured remotes:

```bash
git push <other-remote> main 2>&1
```

Each runs sequentially; report each result. Failures on non-origin remotes don't roll back origin.

See `reference/rollback-recipes.md` for the destructive rollback procedure.

## Phase 15.5 — Push retry cleanup

If user picked "Fix and retry" in Phase 15:

1. Delete local tag (so re-tag at the new HEAD can succeed if the retry includes new commits): `git tag -d v<version>`
2. Pause and tell the user: "Tag deleted. Address the push failure (auth, hook, conflict), then tell me to resume."
3. On resume, loop back to Phase 13 (re-create tag) → Phase 14 (re-summary) → Phase 15 (re-push).

## Phase 16 — Push tag

After Phase 15 push success, push the tag to remotes that accepted main:

```bash
git push <remote> v<version>
```

Skip if `--no-tag` was used.

## Phase 17 — Final verification

Run in parallel:
- `git status -sb` — confirm clean working tree, main in sync
- `git log --oneline -3` — show committed history
- `pwd` — confirm cwd is root main checkout (not a deleted worktree)

Print success summary:

```
✓ Merged <branch>, bumped to vX.Y.Z, deployed via <method | skipped>,
  pushed to <remotes>, tagged vX.Y.Z. Worktree removed. Now in <main-path>.
```

If anything failed in Phase 15-16, list the failed remote(s) + suggested manual retry: `git push <remote> main && git push <remote> v<version>`.

## Phase 18 — Capture Learnings

**This skill is not complete until the learnings-capture process has run.** Read and follow `learnings/learnings-capture.md` (relative to the skills directory, i.e. `plugins/pmos-toolkit/skills/learnings/learnings-capture.md`) now.

Reflect on whether this session surfaced anything worth capturing under `## /complete-dev` — surprising behaviors, repeated corrections, deploy-norm misdetections, push failures with non-obvious causes. Proposing zero learnings is a valid outcome.

---

## Anti-patterns

1. **Auto-deciding the deploy method** without enumerating signals — repo norms can be ambiguous (npm `deploy` script + CI auto-deploy = double-deploy risk). Always show ALL detected signals + recommend; user picks.
2. **`git add -A` blindly** — could include `.env`, `.bak`, secrets. Stage specific paths only.
3. **Auto-resolving merge conflicts** in Phase 3. Always halt and ask.
4. **Removing the worktree before merge succeeds** — Phase 4 gate is "after successful local merge", not "after Phase 3 starts". The order matters.
5. **Pushing to all remotes in parallel** — sequence with origin first; abort chain on origin failure (pre-push hook runs once, not N times).
6. **Tagging before push** — tag is local until pushed; if push fails the tag is still local. Phase 13 → Phase 15 → Phase 16 ordering is load-bearing.
7. **Auto-rolling-back the merge on push failure** — destructive; user almost always wants to fix-and-retry. Rollback is the explicit escape hatch, never the default.
8. **Forgetting to delete the local tag on push retry (Phase 15.5)** — re-tag at a new HEAD will fail if the old tag still points at the old HEAD.
9. **Skipping version bump because "nothing changed"** when skill files actually changed — Phase 0 must accurately detect changes; pre-push hook will reject otherwise.
10. **Capturing learnings the user didn't actually want** — Phase 6 proposes, never auto-writes. Each entry needs explicit approval.
11. **Forgetting to bump BOTH `.claude-plugin` and `.codex-plugin` versions to match** — pre-push hook rejects mismatch. Treat paired manifests as one logical version.
12. **Treating `--skip-deploy` as `--skip-everything-deploy-related`** — push, tag, dry-run summary all still happen. Only the deploy-method invocation is skipped.
13. **Scanning the conversation transcript for learnings** — too noisy. Phase 6 is scoped to `git diff main..HEAD` + commit messages only.
