---
name: complete-dev
description: End-of-development orchestrator that follows /verify — merges feature work into main, captures learnings into CLAUDE.md/AGENTS.md, regenerates the changelog, bumps versions, deploys per repo norms, tags the release, and pushes to all configured remotes. Supersedes the legacy /push skill. Terminal stage of the requirements -> spec -> plan -> execute -> verify -> complete-dev pipeline. Use when the user says "complete the dev cycle", "ship this work", "merge and deploy", "wrap up this branch", "finish development", "ready to push and deploy", "push to remotes", "push and ship", or "push the release".
user-invocable: true
argument-hint: "[--skip-changelog] [--skip-deploy] [--no-tag] [optional commit-message hint] [--non-interactive | --interactive]"
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

- **No interactive prompt tool:** state your assumption, document it in the final report, proceed. Never silently skip a phase. Specifically: default deploy method to "skip deploy" if undetermined; default merge style to fast-forward if possible; default version bump to patch.
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

<!-- non-interactive-block:start -->
1. **Mode resolution.** Compute `(mode, source)` with precedence: `cli_flag > parent_marker > settings.default_mode > builtin-default ("interactive")` (FR-01).
   - `cli_flag` is `--non-interactive` or `--interactive` parsed from this skill's argument string. Last flag wins on conflict (FR-01.1).
   - `parent_marker` is set if the original prompt's first line matches `^\[mode: (interactive|non-interactive)\]$` (FR-06.1).
   - `settings.default_mode` is `.pmos/settings.yaml :: default_mode` if present and one of `interactive`/`non-interactive`. Unknown values → warn on stderr `settings: invalid default_mode value '<v>'; ignoring` and fall through (FR-01.3).
   - If `.pmos/settings.yaml` is malformed (not parseable as YAML, or missing `version`): print to stderr `settings.yaml malformed; fix and re-run` and exit 64 (FR-01.5).
   - On Phase 0 entry, always print to stderr exactly: `mode: <mode> (source: <source>)` (FR-01.2).

2. **Per-checkpoint classifier.** Before issuing any `AskUserQuestion` call, classify it (FR-02):
   - Use the awk extractor below to find the line of this call's `question:` key in the live SKILL.md (FR-02.6).
   - The defer-only tag, if present, is the literal previous non-empty line: `<!-- defer-only: <reason> -->` where `<reason>` ∈ {`destructive`, `free-form`, `ambiguous`} (FR-02.5).
   - Decision (in order): tag adjacent → DEFER; multiSelect with 0 Recommended → DEFER; 0 options OR no option label ends in `(Recommended)` → DEFER; else AUTO-PICK the (Recommended) option (FR-02.2).

3. **Buffer + flush.** Maintain an append-only OQ buffer in conversation memory. On each AUTO-PICK or DEFER classification, append one entry per the schema in spec §11.2. At end-of-skill (or in a caught error before exit), flush (FR-03):
   - Primary artifact is single Markdown → append `## Open Questions (Non-Interactive Run)` section with one fenced YAML block per entry; update prose frontmatter (`**Mode:**`, `**Run Outcome:**`, `**Open Questions:** N` where N counts deferred only — see FR-03.4) (FR-03.1).
   - Skill produces multiple artifacts → write a single `_open_questions.md` aggregator at the artifact directory root; primary artifact's frontmatter `**Open Questions:** N — see _open_questions.md` (FR-03.5).
   - Primary artifact is non-MD (SVG, etc.) → write sidecar `<artifact>.open-questions.md` (FR-03.2).
   - No persistent artifact (chat-only) → emit buffer to stderr at end-of-run as a single block prefixed `--- OPEN QUESTIONS ---` (FR-03.3).
   - Mid-skill error → flush partial buffer under heading `## Open Questions (Non-Interactive Run — partial; skill errored)`; set `**Run Outcome:** error`; exit 1 (E13).

4. **Subagent dispatch.** When dispatching a child skill via Task tool or inline invocation, prepend the literal first line: `[mode: <current-mode>]\n` to the child's prompt (FR-06).

5. **Awk extractor.** The classifier and `tools/audit-recommended.sh` MUST both use the function below. Loaded at script init time; sourcing differs per consumer.

<!-- awk-extractor:start -->
```awk
# Find AskUserQuestion call sites and their adjacent defer-only tags.
# Input: a SKILL.md file (stdin or argv).
# Output (TSV): <line_no>\t<has_recommended:0|1>\t<defer_only_reason or "-">
# A "call site" is a line referencing `AskUserQuestion` in the SKILL's own prose
# (backtick mentions, prose instructions, multi-line invocation hints).
# `(Recommended)` is detected on the call site line OR any subsequent non-blank
# line (the option-list block) until a blank line, defer-only tag, or another
# AskUserQuestion call closes the pending call. Lines inside the inlined
# `<!-- non-interactive-block:... -->` region are canonical contract text and
# never count as call sites.
function emit_pending() {
  if (pending_call > 0) {
    out_tag = (pending_call_tag != "") ? pending_call_tag : "-";
    printf "%d\t%d\t%s\n", pending_call, pending_has_recc, out_tag;
    pending_call = 0;
    pending_has_recc = 0;
    pending_call_tag = "";
  }
}
/^<!-- non-interactive-block:start -->$/ { in_inlined=1; next }
/^<!-- non-interactive-block:end -->$/   { in_inlined=0; next }
in_inlined { next }
/^[[:space:]]*<!--[[:space:]]*defer-only:[[:space:]]*([a-z-]+)[[:space:]]*-->/ {
  emit_pending();
  match($0, /defer-only:[[:space:]]*[a-z-]+/);
  pending_tag = substr($0, RSTART + 12, RLENGTH - 12);
  sub(/^[[:space:]]+/, "", pending_tag);
  pending_line = NR;
  next;
}
/^[[:space:]]*$/ {
  emit_pending();
  pending_tag = "";
  next;
}
/AskUserQuestion/ {
  emit_pending();
  pending_call = NR;
  pending_has_recc = ($0 ~ /\(Recommended\)/) ? 1 : 0;
  pending_call_tag = (pending_tag != "" && NR == pending_line + 1) ? pending_tag : "";
  pending_tag = "";
  next;
}
{
  if (pending_call > 0 && $0 ~ /\(Recommended\)/) {
    pending_has_recc = 1;
  }
}
END { emit_pending() }
```
<!-- awk-extractor:end -->

6. **Refusal check.** If this SKILL.md contains a `<!-- non-interactive: refused; ... -->` marker (regex: `<!--[[:space:]]*non-interactive:[[:space:]]*refused`), and `mode` resolved to `non-interactive`: emit refusal per Section A and exit 64 (FR-07).

7. **Pre-rollout BC.** If the `--non-interactive` argument is present BUT this SKILL.md does NOT contain the `<!-- non-interactive-block:start -->` marker (i.e., this skill hasn't been rolled out yet): emit `WARNING: --non-interactive not yet supported by /<skill>; falling back to interactive.` to stderr; continue in interactive mode (FR-08).

8. **End-of-skill summary.** Print to stderr at exit: `pmos-toolkit: /<skill> finished — outcome=<clean|deferred|error>, open_questions=<N>` (NFR-07).
<!-- non-interactive-block:end -->

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

<!-- defer-only: ambiguous -->
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

## Phase 4 — Worktree cleanup (FR-CD01–CD06)

If Phase 2 detected a worktree AND Phase 3 merged successfully:

Skip Phase 4 entirely (chat: `Phase 4 skipped: not in a worktree.`) when Phase 2 detected `--no-worktree` mode or a non-worktree session (FR-CD06).

Otherwise, run the existing user gate:

```
question: "Worktree at <path> can be removed (changes merged to main locally). Remove now?"
options:
  - Remove worktree (Recommended)
  - Keep worktree (I want to inspect it before push)
  - Cancel
```

On **Remove**:

1. **Compute dirty status excluding `.pmos/feature-sdlc/`** (FR-CD03). Query the worktree's tracked + untracked status, **excluding the entire `.pmos/feature-sdlc/` subtree** (state.yaml is gitignored but exists on disk and would otherwise count as untracked). Non-empty result set = dirty. The exact git invocation (porcelain flags, pathspec syntax, or two-step `git ls-files --others --exclude-standard` + `git diff --name-only`) is left to the implementor to pin against the installed git version; the contract is the exclusion + the boolean result.

2. **Dirty branch (FR-CD01 step 2 + FR-CD02):**
   - With `--force-cleanup` flag: `git worktree remove --force <path>`; proceed to step 4.
   - Without `--force-cleanup`: surface the raw git error and stop. The user decides whether to commit, stash, or rerun with `--force-cleanup`. No auto-stash.

3. **Clean branch (FR-CD01 steps 3–5):**
   - Call `ExitWorktree(action=keep)` (FR-CD04).
     - Success → cwd is restored to the launch session's root; proceed.
     - No-op (any non-success return — typically "Must not already be in a worktree" / "Must have entered the worktree this session") → print fallback (FR-CD05): `Worktree removed. After this session ends, run: cd <root-main-path>` where `<root-main-path>` is the first entry of `git worktree list` (canonical realpath per `_shared/canonical-path.md`); proceed.
   - Run `git worktree remove <path>` (no `--force`).
   - Run `git branch -D feat/<slug>`.

4. **Confirm.** `git worktree list` no longer contains the feature's worktree; `git branch --list "feat/<slug>"` is empty. Print confirmation to chat.

**Note:** Removal happens BEFORE push by design (preserves the existing Phase 4 ordering). If push fails later (Phase 15), the worktree is already gone — recovery uses the rollback recipes in `reference/rollback-recipes.md`, not the worktree.

## Phase 5 — Detect deployment norms

Probe and **enumerate ALL detected signals** (do not pick silently):

1. `CLAUDE.md` / `AGENTS.md` for explicit "Deploy:" or "Release:" sections
2. `package.json` `scripts.deploy` / `scripts.release` / `scripts.publish`
3. `Makefile` targets named `deploy`, `release`, `publish`
4. `.github/workflows/` files that trigger on `push` to `main` (CI auto-deploy)
5. Plugin manifest at `plugins/pmos-toolkit/.claude-plugin/plugin.json` (this repo: deploy = push to remotes)
6. `pyproject.toml` with `[project]` metadata at `./pyproject.toml` or `./backend/pyproject.toml` (PyPI publish via `uv publish`)

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

When signal #6 fires alone (no other deploy signals), present:

```
Detected deploy signals:
  (1) pyproject.toml at ./pyproject.toml — package "<name>" v<version>

Recommendation: build + publish to PyPI via `uv publish`.

question: "Which deploy path?"
options:
  - Build + publish to PyPI via `uv publish` (Recommended)
  - Skip deploy entirely (--skip-deploy effect)
```

If `--skip-deploy` flag: still show this menu but pre-pick the skip option in the dry-run summary.

## Phase 6 — Capture learnings

Scan `git diff main..HEAD` (or `git diff origin/main..HEAD` post-merge) plus the last N feature-branch commit messages. **Do NOT scan conversation transcript.** See `reference/learnings-scan.md` for the heuristics.

Generate up to 8 candidate learnings. Group by target file (CLAUDE.md, AGENTS.md, ~/.pmos/learnings.md). Present via the **Findings Presentation Protocol**:

<!-- defer-only: ambiguous -->
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

**Platform fallback** (no interactive prompt tool): print numbered findings table with disposition column; user replies with disposition list; never auto-write.

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

## Phase 7.5 — Release-notes recipes (new in v2.34.0 per T20/W7)

When generating the release notes section (consumed by /changelog in Phase 8 OR included directly in the merge commit body), include the following recipes for users navigating folded-phase commits and the v2.34.0 flag surface:

### Recipe 1 — Filter human-meaningful commits (skip auto-apply)

Folded MSF and simulate-spec phases write per-finding auto-apply commits (T6/T7/T8). To read the human-authored commit history without the auto-apply noise:

```bash
git log --invert-grep --grep='auto-apply' main..HEAD
```

This excludes commits like `requirements: auto-apply msf-req finding F3`, `wireframes: auto-apply msf-wf finding F7`, `spec: auto-apply simulate-spec patch P12`. Useful when scanning for behavior changes.

### Recipe 2 — Discover dependency graph from Depends-on bodies

Auto-apply commits include `Depends-on: F<M>` (or `P<M>`) in the commit body when finding F<N> requires F<M>. To enumerate the dependency graph:

```bash
git log --grep='Depends-on:' --pretty=format:'%h %s%n%b%n---' main..HEAD
```

Useful when reviewing whether folded findings landed in the right order, or when debugging why a re-apply on resume picked the wrong cursor.

### Recipe 3 — Anti-pattern: manual git rebase mid-pipeline

**DO NOT** `git rebase -i` during an in-progress /feature-sdlc run. The orchestrator's resume cursor uses `--since=<phase.started_at>` (T13/FR-57) plus per-finding commit greps to detect already-applied work. Rebasing rewrites timestamps and SHAs, which makes the apply-loop think nothing was applied — leading to duplicate auto-apply commits or skipped findings on resume.

Safe alternative: complete the pipeline (or pause via the compact checkpoint), then rebase in a fresh `/complete-dev` session before merging.

### Recipe 4 — `--help` quick reference for the v2.34.0 flag surface

11 new flags added across the pipeline in v2.34.0:

| Skill | New flags |
|-------|-----------|
| `/feature-sdlc` | `--minimal` (skip 4 soft gates: creativity, wireframes, prototype, retro) |
| `/requirements` | `--skip-folded-msf`, `--msf-auto-apply-threshold N` |
| `/wireframes` | `--skip-folded-msf-wf`, `--msf-auto-apply-threshold N` |
| `/spec` | `--skip-folded-sim-spec` |
| `/retro` | `--last N`, `--days N`, `--since YYYY-MM-DD`, `--project current\|all`, `--skill <name>`, `--scan-all` |

`--msf-auto-apply-threshold N` defaults to 80 (Tier 3) — sub-threshold findings surface via inline disposition (D14) with `Recommended=Defer`.

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
<!-- defer-only: ambiguous -->
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
14. **Trusting the shared-branch guard's `local==remote SHA` test as proof no one has based work on this branch.** It's necessary-but-not-sufficient — a coworker who pulled before our last fixup could have based work, and we'd never know. The pre-push hook is the only authoritative line of defence; use the merge fallback for any branch you've shared for review.
