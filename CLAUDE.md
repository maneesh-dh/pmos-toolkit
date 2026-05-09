# agent-skills — repo invariants

Project-level rules that aren't obvious from the directory structure. Skills and tools loaded from this repo trust these invariants; violating them produces silent failures (skills don't load, releases get stuck).

## Canonical skill path (pmos-toolkit)

The `pmos-toolkit` plugin manifest loads skills from exactly one directory:

```
plugins/pmos-toolkit/skills/<skill-name>/SKILL.md
```

Anywhere else (root `skills/`, under another plugin, in a feature folder, in `docs/`) is invisible to the loader. A skill saved at the wrong path will not register and will not error — it just silently doesn't exist as a slash command.

When creating, moving, copying, or renaming a pmos-toolkit skill:
- Target path must be `plugins/pmos-toolkit/skills/<skill-name>/SKILL.md`.
- `<skill-name>` is lowercase-hyphenated (e.g., `create-skill`, `verify`, not `CreateSkill`).
- After any move, run `ls plugins/pmos-toolkit/skills/` to confirm the new directory is present and named correctly.

`/create-skill` Phase 7 enforces this at write-time. Manual edits do not get that check — this rule is the backstop.

## Plugin manifest version sync

Both manifests must carry the same version on every release:

```
plugins/pmos-toolkit/.claude-plugin/plugin.json
plugins/pmos-toolkit/.codex-plugin/plugin.json
```

The pre-push hook enforces sync. When bumping versions for a release, edit both files in the same commit.

## Release entry point

`/complete-dev` is the canonical release skill. It supersedes the legacy `/push`. Skills, docs, and references in this repo should point at `/complete-dev`, not `/push`.
