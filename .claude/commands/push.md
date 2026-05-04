---
description: Pre-flight check, version bump, merge feature branch, commit, push to all 3 remotes
argument-hint: "[optional commit message hint]"
---

# /push — agent-skills repo push workflow

You are running the agent-skills repo push workflow. Follow these phases in order. **Stop and ask the user via `AskUserQuestion` at each gate.** Do not auto-decide on version bumps, branch deletions, or commit messages.

**Announce at start:** "Running /push: pre-flight checks, then version + commit + push to all 3 remotes."

## Track progress

This command has 10 phases. Create one `TodoWrite` task per phase. Mark each `in_progress` when you start it and `completed` when it finishes.

## Phase 0 — Sanity & state

Run in parallel:
- `git status --porcelain` (uncommitted state)
- `git branch --show-current` (current branch)
- `git remote -v` (must show exactly: `origin`, `github`, `github-work`; if not, abort and ask user)
- `git log --oneline -5`
- `git status -sb` (ahead/behind tracking)

Print a one-line state summary: `Branch: <name>; Uncommitted: <N>; Ahead of origin: <N>`.

## Phase 1 — Detect new skill content

Check if any new skill directories were added or if existing skill content changed:

```bash
git status --porcelain | grep -E "^(\?\?|A|M).*plugins/pmos-toolkit/skills/" || true
git status --porcelain | grep -E "^(\?\?|A|M).*skills/" || true
```

**Two failure modes to catch:**

### 1a. Skill placed in wrong directory

If new files exist under root `skills/<name>/` (NOT inside `plugins/pmos-toolkit/skills/`), this is the wrong location — the plugin manifest at `plugins/pmos-toolkit/.claude-plugin/plugin.json` loads from `plugins/pmos-toolkit/skills/`.

Surface via `AskUserQuestion`:

```
question: "New skill files found at root skills/<name>/. The plugin loads from plugins/pmos-toolkit/skills/. Move them?"
options:
  - Move to plugins/pmos-toolkit/skills/<name>/ via git mv (Recommended)
  - Leave as-is — this skill is intentionally not shipped via the plugin
  - Cancel /push
```

If "Move" → run `git mv skills/<name> plugins/pmos-toolkit/skills/<name>` and re-run Phase 1.

### 1b. New skill but plugin.json unchanged

Check: did `plugins/pmos-toolkit/skills/` gain a new directory in this batch of changes? If yes, ensure version will be bumped (Phase 2).

## Phase 1.5 — README freshness check

If Phase 1 detected new or removed skills under `plugins/pmos-toolkit/skills/`, the README's Skills section is stale.

Compare:
- Skill directories on disk: `/bin/ls plugins/pmos-toolkit/skills/ | grep -vE "^(_shared|\.shared|\.system)$"`
- Skill rows in README: `/usr/bin/grep -oE '/pmos-toolkit:[a-z-]+' README.md | sort -u`

For any difference (new skill missing from README OR removed skill still listed):

Surface via `AskUserQuestion`:

```
question: "README is out of sync — <new-skills> missing, <removed-skills> still listed. Update?"
options:
  - Update README now (Recommended)
  - Skip — I'll update README in a follow-up
  - Cancel /push
```

If "Update":
1. Read each new skill's `SKILL.md` to extract its `description:` field
2. Add a row to the appropriate section of the Skills table (Pipeline / Enhancers / Artifacts & docs / Tracking & context / Utilities — categorize based on the skill's purpose; ask the user if unclear)
3. Remove rows for any deleted skills
4. Update the pipeline-flow diagram if a pipeline skill was added/removed
5. Show the user the diff before staging:

```
question: "README updated. Proceed with this diff?"
options:
  - Looks good (Recommended)
  - Let me edit it manually
  - Cancel /push
```

Stage the updated README so it lands in the same commit as the skill change.

## Phase 2 — Version bump decision

Read both manifests:
- `plugins/pmos-toolkit/.claude-plugin/plugin.json`
- `plugins/pmos-toolkit/.codex-plugin/plugin.json`

**Pre-flight: versions MUST match between the two files.** If they don't, surface via AskUserQuestion which to use as the baseline; the pre-push hook will reject otherwise.

If skill content changed (Phase 1 detected new/modified files under `plugins/pmos-toolkit/skills/` or `plugins/pmos-toolkit/agents/`), version bump is **mandatory** — the pre-push hook enforces this.

Surface via `AskUserQuestion` with current version shown:

```
question: "Current version is X.Y.Z. What kind of bump?"
options:
  - Patch (X.Y.Z+1) — bug fix, content tweak, relocation, doc-only (Recommended for fixes)
  - Minor (X.Y+1.0) — new skill, new flag, additive feature (Recommended for new skills)
  - Major (X+1.0.0) — breaking change to skill API or removed skill
  - Skip version bump (only if no plugin content changed)
```

Apply the chosen bump to BOTH plugin.json files using the `Edit` tool. Validate both JSON files parse afterward via `python3 -c "import json; json.load(open('<path>'))"`.

## Phase 3 — JSON schema validation

For any `.json` schema files in `plugins/pmos-toolkit/skills/*/schemas/`:

```bash
python3 -c "import json; json.load(open('<schema-path>'))"
```

For any example YAML files paired with a schema:

```bash
python3 -c "import json, yaml, jsonschema; jsonschema.validate(yaml.safe_load(open('<example>')), json.load(open('<schema>')))"
```

(Install `jsonschema` and `pyyaml` via pip if missing.) Abort and surface errors if anything fails.

## Phase 4 — Branch reconciliation

Check current branch:

```bash
current=$(git branch --show-current)
```

**If on `main`:** skip to Phase 5.

**If on a feature branch:**

Surface via `AskUserQuestion`:

```
question: "On branch <name>. How should we land it?"
options:
  - Merge into main (fast-forward if possible, else --no-ff merge commit) (Recommended)
  - Rebase onto main, then merge fast-forward
  - Stay on feature branch and push only this branch
  - Cancel /push
```

If merge chosen:
1. Verify uncommitted state is clean (or commit them first via Phase 5; ask user)
2. `git checkout main`
3. `git pull origin main` (sync with remote first)
4. `git merge <feature-branch>` (fast-forward where possible)
5. Resolve conflicts → STOP and ask user; do NOT auto-resolve

## Phase 5 — Commit

If uncommitted changes exist:

1. Run `git diff --staged` and `git diff` to understand what's being committed
2. Run `git log --oneline -3` to match commit message style (this repo uses `feat(scope): summary — pmos-toolkit X.Y.Z` format with co-author trailer)
3. Draft a commit message. Use the user's hint from `$ARGUMENTS` if provided.
4. **Surface the draft via `AskUserQuestion` BEFORE committing:**

```
question: "Draft commit message: '<first line>'. Use it?"
options:
  - Commit with this message (Recommended)
  - Edit the message
  - Cancel /push
```

5. If "Edit" → ask for the replacement message via a follow-up open prompt.
6. Stage relevant files (prefer specific paths; never `git add -A` blindly — could pick up secrets). Then commit using HEREDOC:

```bash
git commit -m "$(cat <<'EOF'
<message>

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

7. Verify the commit landed: `git log --oneline -1`

## Phase 6 — Stale branch cleanup

Find merged feature branches:

```bash
git branch --merged main | grep -vE "^\*|^\s*main$" || true
```

If any exist, surface via `AskUserQuestion` (one question, multi-select):

```
question: "Merged branches found. Which to delete?"
multiSelect: true
options:
  - <branch-1> (last commit: <date>)
  - <branch-2> (last commit: <date>)
  - ...
  - Skip cleanup
```

Delete only branches the user selected: `git branch -d <name>` (NEVER `-D` here — `-d` refuses unmerged branches as a safety net).

Also offer to clean `[gone]` branches (deleted on remote but still local):

```bash
git fetch --all --prune
git branch -vv | grep ': gone]' | awk '{print $1}'
```

Same select-and-confirm flow. For these, `git branch -d` is safe because they're tracking gone remotes.

## Phase 7 — Dry-run summary

Print a one-screen summary BEFORE pushing:

```
=== /push summary ===
Branch:           main
Local commits:    <N> ahead of origin/main
Last commit:      <hash> <message>
Plugin version:   <X.Y.Z> (claude=Y, codex=Y, in-sync=YES)
Pushing to:       origin → github → github-work
=====================
```

Surface via `AskUserQuestion`:

```
question: "Push <N> commits to all 3 remotes?"
options:
  - Push (Recommended)
  - Push to origin only (skip github, github-work)
  - Cancel
```

## Phase 8 — Push to remotes (sequential, abort on failure)

Push in this order. Origin first because that's where the pre-push hook runs (run it once, not 3x):

```bash
git push origin main 2>&1
```

If origin fails (hook rejection, conflict, auth) → STOP. Do not attempt github / github-work. Show the error to the user. Most likely causes:
- Pre-push hook rejected because plugin.json versions disagree → go fix Phase 2
- Non-fast-forward → user needs to pull first
- Auth failure → user needs to fix credentials

If origin succeeds:

```bash
git push github main 2>&1
git push github-work main 2>&1
```

Each runs sequentially; report each result. If github or github-work fails, report it but don't roll back origin (origin is the source of truth).

## Phase 9 — Final verification

Run in parallel:
- `git status -sb` — confirm working tree clean and `main` is in sync
- `git log --oneline -3` — show the committed history

Print a one-line success summary:

```
Pushed <hash> to origin, github, github-work. Working tree clean.
```

If any push failed in Phase 8, list the failed remote(s) and suggest manual retry: `git push <remote> main`.

---

## Anti-patterns

- ❌ Auto-bumping version without asking (patch vs minor is a judgment call)
- ❌ `git add -A` blindly (might pick up secrets, .env, .bak files)
- ❌ `git push --force` to any remote (never, even if user asks; warn and require explicit override)
- ❌ Skipping the pre-flight summary in Phase 7 (user must see what's about to happen)
- ❌ Auto-deleting branches with `-D` (only `-d`, which refuses unmerged branches)
- ❌ Pushing to all 3 remotes in parallel (sequence with origin first; abort on origin failure)
- ❌ Committing without user-approved message (the draft must be approved or edited)
- ❌ Auto-resolving merge conflicts (always stop and ask)
- ❌ Skipping JSON schema validation when schemas changed
- ❌ Forgetting to bump BOTH `.claude-plugin` and `.codex-plugin` versions to match
- ❌ Pushing a new skill without updating README's Skills table (Phase 1.5 catches this)

## Arguments

`$ARGUMENTS` — optional commit-message hint. Pass to Phase 5 as the starting draft.
