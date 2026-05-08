# Spec: /complete-dev

Tier: 3
Generated: 2026-05-08
Status: implemented

> **Grill applied 2026-05-08** — see `grills/2026-05-08_02_spec.md`. Changes baked in: always-ask /verify (no detection), two-release bootstrap (keep /push for v1), enumerate-all deploy signals, paired-manifest special case, no auto-rollback on push fail, diff-scoped learnings, tag-conflict pre-check, push-flavored trigger phrases.

## 1. One-line description

End-of-development orchestrator that follows /verify — merges feature work into main, captures learnings into CLAUDE.md/AGENTS.md, regenerates the changelog, bumps versions, deploys per repo norms, tags the release, and pushes to all configured remotes. Supersedes the legacy /push skill. Use when the user says "complete the dev cycle", "ship this work", "merge and deploy", "wrap up this branch", "finish development", "ready to push and deploy", "push to remotes", "push and ship", or "push the release".

## 2. Argument hint

`[--skip-changelog] [--skip-deploy] [--no-tag] [optional commit-message hint]`

## 3. Source / inputs

What the skill consumes:

- **Repo state** — current branch, working tree status, worktree list (`git worktree list`), remotes (`git remote -v`), commit log
- **/verify state** — Phase 1 ALWAYS asks the user (no auto-detection); commit-message scanning was rejected during grill as too unreliable (amends, rebases, post-verify commits). Options: Run /verify now / Already ran, continue / Skip / Cancel.
- **Repo deployment hints** — probe and enumerate ALL detected signals; do not pick one silently:
  1. `CLAUDE.md` / `AGENTS.md` for an explicit "Deploy:" or "Release:" section
  2. `package.json` `scripts.deploy` / `scripts.release` / `scripts.publish`
  3. `Makefile` targets named `deploy`, `release`, `publish`
  4. `.github/workflows/` (note: CI-driven deploy → no local action needed)
  5. Plugin manifest at `plugins/pmos-toolkit/.claude-plugin/plugin.json` (this repo: deploy = push to 3 remotes)
- **`git diff main..HEAD` + last N feature-branch commit messages** — the durable record of what changed, scanned to propose CLAUDE.md/AGENTS.md learnings. Conversation transcript is explicitly OUT of scope (too noisy; includes detours that didn't ship). Cap: 8 proposals.
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
| 1 | /verify gate | ALWAYS AskUserQuestion (no auto-detection): Run /verify now / Already ran, continue / Skip / Cancel | AskUserQuestion |
| 2 | Worktree + branch detection | Identify if running in a worktree; identify feature branch; identify root main checkout path | none |
| 3 | Merge feature → main | Switch to main checkout, pull origin, merge feature branch (ff or --no-ff per user choice); halt on conflict | AskUserQuestion |
| 4 | Worktree cleanup | After successful local merge, remove worktree via `git worktree remove`; switch cwd to root main path | AskUserQuestion (keep/remove) |
| 5 | Detect deployment norms | Probe CLAUDE.md, package.json, Makefile, CI configs, plugin manifest. Enumerate ALL detected signals + emit a recommendation (e.g., "CI auto-deploys on push → recommend skipping local deploy"). User picks which (or none) to invoke. | AskUserQuestion |
| 6 | Capture learnings → CLAUDE.md/AGENTS.md | Scan `git diff main..HEAD` + last N feature-branch commits (NOT transcript); propose ≤8 entries via Findings Protocol; user approves each before write | AskUserQuestion (per finding) |
| 7 | README freshness check | Detect new/removed skills under plugins/pmos-toolkit/skills/ (or analogous); update README rows | AskUserQuestion |
| 8 | Run /changelog (unless --skip-changelog) | Invoke /changelog skill; show user the proposed CHANGELOG entries; user approves before commit | AskUserQuestion |
| 9 | Version bump (mandatory if skill content changed) | Read manifest(s). **Paired-manifest special case:** if both `plugins/pmos-toolkit/.claude-plugin/plugin.json` and `plugins/pmos-toolkit/.codex-plugin/plugin.json` exist, treat as ONE logical version that always bumps together (pre-push hook enforces equality). Otherwise: detect monorepo (multiple package.json), only bump packages with changes; ask patch/minor/major per package. | AskUserQuestion |
| 10 | JSON schema validation | For any plugin schema files that changed, validate JSON parses; validate paired YAML examples against schemas | none (abort on failure) |
| 11 | Stage + commit | Stage specific files (never `git add -A`); draft commit message using `$ARGUMENTS` hint + last 3 commits as style reference; user approves message | AskUserQuestion |
| 12 | Stale branch cleanup | List merged branches and `[gone]` branches; user multi-selects which to delete with `-d` | AskUserQuestion (multi-select) |
| 13 | Tag release (unless --no-tag) | Pre-check `git rev-parse v<version>`. If tag exists: AskUserQuestion (Skip tagging / Force-replace destructive / Cancel). Otherwise create annotated tag `v<version>` on main HEAD. | AskUserQuestion |
| 14 | Dry-run summary | One-screen pre-push summary: branch, version, deploy method, remotes, tag | AskUserQuestion (push / origin-only / cancel) |
| 15 | Deploy + push (unless --skip-deploy) | Sequential: deploy method first if user picked one in Phase 5; then push origin → other remotes; abort chain on origin failure. **NO auto-rollback.** On failure: delete local tag, show `Fix and retry push` as primary path. Full rollback to pre-merge SHA offered only as explicit destructive escape hatch with the SHA shown. | AskUserQuestion (only on failure) |
| 15.5 | Push retry cleanup | If user picks "Fix and retry": delete the local tag (so re-tag at new HEAD succeeds), pause for user to fix the underlying cause, then loop back to Phase 14. | none |
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

**Two-release transition** (decided in grill):

- **v1 release (this one)**: ship /complete-dev as **additive**. /push remains in place untouched. README adds /complete-dev row in **Utilities** section AND keeps /push row, marking /push as "deprecated — use /complete-dev for full end-of-dev workflow." Standalone-line update: add /complete-dev after /verify in the pipeline-flow's standalone list. Version bump: **minor** (X.Y+1.0). Changelog: "Added /complete-dev; /push deprecated, will be removed in next release."
- **v2 release (next one)**: remove /push entirely. Delete `plugins/pmos-toolkit/.claude/commands/push.md`. Remove /push row from README. Update plugin.json `commands` array if /push is registered there. Version bump: **minor** (additive feature being mature, not breaking removal — /complete-dev already covers the surface). Changelog: "Removed deprecated /push (use /complete-dev)."
- **Bootstrap chicken-and-egg**: the v1 release ships using legacy /push (or manual git). All subsequent releases use /complete-dev. The two-release gap means a /complete-dev defect discovered post-v1 doesn't strand the user — /push still works.

## 14. Open questions

All open questions resolved during grill (`grills/2026-05-08_02_spec.md`):

1. ~~Worktree timing~~ → **Resolved**: keep eager cleanup after local merge.
2. ~~/verify detection~~ → **Resolved**: skip detection, always ask.
3. ~~Monorepo detection~~ → **Resolved**: paired-manifest special case; auto-detect for true monorepos.
4. ~~Tag conflict~~ → **Resolved**: `git rev-parse` pre-check + AskUserQuestion.
5. ~~`--skip-deploy` semantics~~ → **Resolved**: skips Phase 15 deploy invocation only; Phase 5 detection still runs so the dry-run summary documents what was skipped.
6. ~~Learnings scope~~ → **Resolved**: diff + commit messages only; cap 8.
7. ~~Bootstrap~~ → **Resolved**: two-release transition (additive v1, removal v2).
8. ~~/changelog target~~ → **Resolved from code**: `{docs_path}/changelog.md` per `.pmos/settings.yaml`.
9. ~~Missing learnings file~~ → **Resolved**: Phase 0 reads `~/.pmos/learnings.md` if present, skips silently if not.
10. ~~AskUserQuestion 4-option limit~~ → **No issue identified**; Phase 14's three options are sufficient.

No remaining open questions. Ready for status: `approved`.
