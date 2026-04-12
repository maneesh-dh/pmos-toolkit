# Git Hooks

Repo-local git hooks. Opt in once per clone:

```bash
git config core.hooksPath .githooks
```

## pre-push

Blocks pushes that modify plugin content without a version bump.

**Why it exists.** Claude Code and Codex load installed plugins from a version-keyed cache (`~/.claude-personal/plugins/cache/<plugin>/<plugin>/<version>/`). When a plugin's `version` stays the same, the cache is not refreshed — edits to skill files silently do nothing on any machine that already has the old version cached. `/reload-plugins` and new sessions do not invalidate the cache.

**What it enforces.** For each plugin whose `skills/` or `agents/` changed in the range being pushed:

1. `plugins/<name>/.claude-plugin/plugin.json` `version` must differ from the remote tip's value.
2. `plugins/<name>/.codex-plugin/plugin.json` `version` must match the Claude manifest at the local tip (the two must stay in lockstep).

**Semver guidance** (enforced by discipline, not by the hook):

- **Patch** (`1.0.0 → 1.0.1`) — typo fixes, reworded instructions, clarifications.
- **Minor** (`1.0.1 → 1.1.0`) — new phases, new skill files, backward-compatible additions.
- **Major** (`1.x → 2.0`) — breaking changes to skill behavior or required inputs.

**If the hook fires.** Bump both `plugin.json` files to the same new version, amend or add a commit, and push again.

**Bypass.** `git push --no-verify` — but only do this for hook-maintenance commits (e.g., editing the hook itself). Anything else defeats the purpose.
