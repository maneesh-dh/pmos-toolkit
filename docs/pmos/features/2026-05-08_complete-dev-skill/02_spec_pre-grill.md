# Spec: /complete-dev

Tier: 3
Generated: 2026-05-08
Status: draft

## 1. One-line description

End-of-development orchestrator that follows /verify — merges feature work into main, captures learnings into CLAUDE.md/AGENTS.md, regenerates the changelog, bumps versions, deploys per repo norms, tags the release, and pushes to all configured remotes. Replaces the legacy /push skill with a fuller ceremony. Use when the user says "complete the dev cycle", "ship this work", "merge and deploy", "wrap up this branch", "finish development", or "ready to push and deploy".

## 2. Argument hint

`[--skip-changelog] [--skip-deploy] [--no-tag] [optional commit-message hint]`

## 3. Source / inputs

What the skill consumes:

- **Repo state** — current branch, working tree status, worktree list (`git worktree list`), remotes (`git remote -v`), commit log
- **Last commit message** — to detect whether /verify ran (look for `verify` in subject or `Verified-By:` trailer)
- **Repo deployment hints** — read in priority order:
  1. `CLAUDE.md` / `AGENTS.md` for an explicit "Deploy:" or "Release:" section
  2. `package.json` `scripts.deploy` / `scripts.release` / `scripts.publish`
  3. `Makefile` targets named `deploy`, `release`, `publish`
  4. `.github/workflows/` (note: CI-driven deploy → no local action needed)
  5. Plugin manifest at `plugins/pmos-toolkit/.claude-plugin/plugin.json` (this repo: deploy = push to 3 remotes)
- **Session transcript + git diff** — scan for surprises/corrections to propose CLAUDE.md/AGENTS.md learnings
- **Slash arguments** — `--skip-changelog`, `--skip-deploy`, `--no-tag`, free-form commit-message hint

If no input flags: use repo-detected defaults; never silently skip a phase.

## 4. Output

What the skill produces:

- **Git state changes**: feature branch merged into main; worktree removed (after local merge); main pushed to all configured remotes; release tag pushed (unless `--no-tag`)
- **File edits**: version bumps in plugin.json (and `.codex-plugin/plugin.json` if present); README.md updates if skill inventory changed; CLAUDE.md / AGENTS.md learning entries; CHANGELOG.md entries via /changelog
- **In-conversation deliverables**: pre-flight summary, deploy-norm detection summary, learnings-proposal review, dry-run push summary, final success report
- **Side effects**: cwd switches to root main checkout after worktree cleanup; release tag created locally and pushed
- **Happy path**: "Merged <branch>, bumped to vX.Y.Z, deployed via <method>, pushed to <remotes>, tagged vX.Y.Z. Worktree removed. Now in <main-path>."

## 5. Phases

| # | Phase | Purpose | Gate |
|---|-------|---------|------|
| 0 | Load learnings + sanity check | Read ~/.pmos/learnings.md `## /complete-dev`; print initial state summary | none |
| 1 | /verify gate | Detect whether /verify ran this session (last commit message); if not, AskUserQuestion: run /verify / skip / cancel | AskUserQuestion |
| 2 | Worktree + branch detection | Identify if running in a worktree; identify feature branch; identify root main checkout path | none |
| 3 | Merge feature → main | Switch to main checkout, pull origin, merge feature branch (ff or --no-ff per user choice); halt on conflict | AskUserQuestion |
| 4 | Worktree cleanup | After successful local merge, remove worktree via `git worktree remove`; switch cwd to root main path | AskUserQuestion (keep/remove) |
| 5 | Detect deployment norms | Probe CLAUDE.md → package.json → Makefile → CI configs → plugin manifest; present detected method + confidence to user | AskUserQuestion |
| 6 | Capture learnings → CLAUDE.md/AGENTS.md | Scan transcript + diff for surprises; propose entries via Findings Protocol; user approves each before write | AskUserQuestion (per finding) |
| 7 | README freshness check | Detect new/removed skills under plugins/pmos-toolkit/skills/ (or analogous); update README rows | AskUserQuestion |
| 8 | Run /changelog (unless --skip-changelog) | Invoke /changelog skill; show user the proposed CHANGELOG entries; user approves before commit | AskUserQuestion |
| 9 | Version bump (mandatory if skill content changed) | Read manifest(s); detect monorepo (multiple package.json); only bump packages with changes; ask patch/minor/major per package | AskUserQuestion |
| 10 | JSON schema validation | For any plugin schema files that changed, validate JSON parses; validate paired YAML examples against schemas | none (abort on failure) |
| 11 | Stage + commit | Stage specific files (never `git add -A`); draft commit message using `$ARGUMENTS` hint + last 3 commits as style reference; user approves message | AskUserQuestion |
| 12 | Stale branch cleanup | List merged branches and `[gone]` branches; user multi-selects which to delete with `-d` | AskUserQuestion (multi-select) |
| 13 | Tag release (unless --no-tag) | Create annotated tag `v<version>` on main HEAD | AskUserQuestion |
| 14 | Dry-run summary | One-screen pre-push summary: branch, version, deploy method, remotes, tag | AskUserQuestion (push / origin-only / cancel) |
| 15 | Deploy + push (unless --skip-deploy) | Sequential: deploy method first if non-trivial; then push origin → other remotes; abort chain on origin failure; offer to roll back local merge | AskUserQuestion (rollback only on failure) |
| 16 | Push tag | Push the tag to remotes that accepted main | none (after Phase 15) |
| 17 | Final verification | `git status -sb`, `git log --oneline -3`; verify cwd is root main; report success summary or partial-failure remediation | none |
| 18 | Capture Learnings (terminal) | Reflect on /complete-dev itself; propose updates to ~/.pmos/learnings.md | terminal |

Phase count: 19. Tier 3 confirmed.

## 6. Tier classification rationale

- **Phase count**: 19 phases (Tier 3 threshold ≥ 5)
- **Replaces an existing critical skill** (/push) — high blast radius
- **Multi-source behavior**: worktree state, repo type, deploy norms, learnings transcript
- **Pipeline integration**: follows /verify, invokes /changelog
- **External integrations**: git worktree, repo deploy commands (npm/vercel/etc.), tagging
- **Has a Findings Presentation Protocol** (learnings approval loop)
- User confirmed Tier 3 explicitly in Phase 2 of /create-skill.

## 7. Asset inventory

| File | Purpose | Format | Invoked by |
|------|---------|--------|------------|
| (none) | All logic inline in SKILL.md or referenced from `reference/` | — | — |

No standalone scripts needed; all phases are git/jq/python3 invocations from Bash.

## 8. Reference inventory

| File | Purpose | Loaded by phase |
|------|---------|-----------------|
| deploy-norms.md | Detection rubric: priority order + signals for npm/vercel/make/gh-actions/plugin-push; example for each repo type | Phase 5 |
| learnings-scan.md | Heuristics for what counts as a "surprise" worth capturing in CLAUDE.md/AGENTS.md (corrections, non-obvious decisions, repeated mistakes); excludes ephemeral state | Phase 6 |
| commit-style.md | Repo-specific commit-message conventions (read last 3 commits + this guide) — fallback templates per detected repo type | Phase 11 |
| rollback-recipes.md | Step-by-step recovery for: push rejected, deploy failed mid-way, tag conflict, merge needs undo | Phase 15 (on failure) |

## 9. Pipeline / workstream integration

- **Pipeline position**: terminal stage. Diagram:

```
/requirements → [/msf-req, /creativity] → /spec → /plan → /execute → /verify → /complete-dev (this skill)
                  optional enhancers
```

Note: `/changelog` is invoked *by* /complete-dev as a sub-step (Phase 8), not as a peer pipeline stage.

- **Workstream awareness**: Phase 0 does NOT load workstream context. /complete-dev operates on git state and repo files; workstream context is not relevant for shipping mechanics. Therefore: NO Workstream Enrichment phase.
- **Cross-skill dependencies**: invokes /changelog inline (Phase 8); detects /verify run state (Phase 1); replaces /push entirely (deletion in Phase 7 of /create-skill).

## 10. Findings Presentation Protocol applicability

Two phases use the Findings Presentation Protocol:

**Phase 6 (Learnings capture)**:
- Group proposed entries by file (CLAUDE.md, AGENTS.md, ~/.pmos/learnings.md)
- One AskUserQuestion per proposed entry, batched ≤4 per call
- Disposition options: **Add as proposed** / **Edit text** / **Skip this entry** / **Defer to manual edit later**
- Cap: max 8 proposals per session (avoid noise)
- Platform fallback: numbered findings table; user replies with disposition list

**Phase 15 (Deploy+push failure handling)**:
- One AskUserQuestion per failed remote/step
- Disposition options: **Retry** / **Skip this remote** / **Roll back local merge** / **Cancel and let me fix manually**
- No batching — failures are blocking and need linear handling
- Platform fallback: print failure + suggested commands; await user instruction

## 11. Platform fallbacks

- **AskUserQuestion** → State the assumption (e.g., "proceeding with detected deploy method <X>"), document it in the final report, proceed. Never silently skip a phase.
- **Subagents** → Phase 6 learnings scan runs inline (sequential transcript review). Phase 8 /changelog runs inline (not dispatched).
- **Playwright / MCP** → N/A — this skill has no browser-based verification.
- **TaskCreate / TodoWrite** → Use whichever the host agent provides; if neither, print phase progress as text headers.
- **/changelog unavailable** → Skip Phase 8 with a warning; suggest manual CHANGELOG edit. `--skip-changelog` is the same path.
- **/verify never ran detector** → If last-commit pattern detection is unreliable, fall back to "always ask" (the chosen design).

## 12. Anti-patterns

1. **Auto-deciding the deploy method** without user confirmation — repo norms can be ambiguous (e.g., `package.json` has `deploy` script but actual deploy is via CI). Always surface the detection + confidence and ask.
2. **`git add -A` blindly** — could include `.env`, `.bak`, secrets. Stage specific paths only.
3. **Auto-resolving merge conflicts** in Phase 3. Always halt and ask.
4. **Removing the worktree before push** when the user expected it gone only after deploy succeeds — gate is "after local merge" per spec, but this MUST be clearly communicated in Phase 4.
5. **Pushing to all remotes in parallel** — sequence with origin first; abort chain on origin failure (pre-push hook runs once, not N times).
6. **Tagging before push** — tag is local until pushed; if push fails the tag is still local. Phase 13 → Phase 15 → Phase 16 ordering matters.
7. **Auto-rolling-back the merge on push failure without asking** — destructive; user might prefer to fix the push reason and retry.
8. **Skipping version bump because "nothing changed"** when skill files actually changed — Phase 1 must accurately detect changes; "no changes detected" must be verifiable, not asserted.
9. **Capturing learnings the user didn't actually want** — propose, never auto-write. Each entry needs explicit approval.
10. **Forgetting to bump BOTH `.claude-plugin` and `.codex-plugin` versions to match** — pre-push hook rejects mismatch. Treat as one logical version.
11. **Treating `--skip-deploy` as `--skip-everything-deploy-related`** — push still happens, tag still happens. Only the deploy-method invocation is skipped.

## 13. Release prerequisites

- **README section**: replace the existing `/pmos-toolkit:push` row in the **Utilities** section with a `/pmos-toolkit:complete-dev` row. Add a deprecation note at the top of the row group: "Replaces /push." Update any pipeline diagram showing /push to show /complete-dev.
- **Standalone-line update**: yes — /complete-dev is invoked at the end of the pipeline, mention it after /verify in the standalone-list line.
- **Version bump type at next /push**: **minor** (X.Y+1.0) — replaces an existing skill (technically breaking for muscle memory but additive in capability). Note the breaking change in the changelog.
- **One-time bootstrap**:
  - Delete `plugins/pmos-toolkit/.claude/commands/push.md` (the legacy command file) — handled by user during the next /complete-dev run that ships this skill.
  - Update plugin.json `commands` array if /push is registered there.
  - Update CHANGELOG.md to call out: "BREAKING: /push removed; use /complete-dev for the full end-of-dev workflow."
- **Bootstrap concern**: The skill that ships /complete-dev cannot use /complete-dev to ship itself (chicken-and-egg). The first-time release uses the legacy /push (or manual git commands).

## 14. Open questions

These will be put through `/grill` in Phase 5:

1. **Worktree cleanup before push**: design choice is "remove after local merge." If push then fails, the worktree is gone but the merge is still local on main. Is the rollback recipe (Phase 15 failure handling) sufficient, or should we flip to "remove only after push succeeds"?
2. **`/verify` re-run vs. trust marker**: trust the last-commit pattern, or re-run /verify always? User chose "block with AskUserQuestion: run/skip/cancel" — covers it, but what's the correct default option?
3. **Monorepo detection**: how do we know "only these packages changed"? `git diff --name-only main..HEAD` is straightforward, but mapping paths to packages requires per-repo configuration. Should we punt to a manual-prompt for monorepo cases in v1?
4. **Tag conflict on existing version**: if user picks a version that already has a tag (e.g., didn't actually bump), what's the recovery path?
5. **`--skip-deploy` semantics**: does it skip Phase 5 (detect deploy norms) entirely, or just Phase 15's deploy invocation while still using detected info for the dry-run summary?
6. **Learnings-scan scope**: how far back in the session? Last N turns? Whole session? When the session is hours long, scanning everything is noisy.
7. **Bootstrap chicken-and-egg**: the first time this skill ships, /push is what ships it. Should we keep a thin /push redirect for one release as a transition aid, then remove?
8. **CHANGELOG location ambiguity**: this repo doesn't currently have a CHANGELOG.md; /changelog skill writes where? Need to confirm /changelog's actual output target before assuming Phase 8 produces a CHANGELOG.md edit.
9. **Phase 0 learnings file detection**: ~/.pmos/learnings.md is checked, but what if it doesn't exist? Skip silently or scaffold?
10. **AskUserQuestion limit (4 options)**: Phase 14's dry-run summary has push / origin-only / cancel = 3 options. Are there cases where we want a 4th like "push and skip tag-push"?
