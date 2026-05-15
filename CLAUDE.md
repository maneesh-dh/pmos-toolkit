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

`/feature-sdlc skill` enforces this — its skill-eval rubric's `a-name-matches-dir` check fails when the frontmatter `name` doesn't match the directory. Manual edits do not get that check — this rule is the backstop.

## Skill-authoring conventions

How to author or revise a pmos-toolkit skill:

- **Canonical path** — new skills go at `plugins/pmos-toolkit/skills/<skill-name>/SKILL.md` and nowhere else (see "## Canonical skill path (pmos-toolkit)" above — the loader reads only that directory; a skill anywhere else silently doesn't register). `<skill-name>` is lowercase-hyphenated.
- **After any move / copy / rename** of a pmos skill, run `ls plugins/pmos-toolkit/skills/` to confirm the directory is present and correctly named.
- **The SDLC for skills** — author a new skill, or apply feedback to existing skill(s), via `/feature-sdlc skill <description>` / `/feature-sdlc skill --from-feedback <…>` (or the `/skill-sdlc` alias). That pipeline runs requirements → spec → plan → execute → skill-eval → verify and scores the result against a binary rubric before merge. (`/create-skill` and `/update-skills` were retired in 2.38.0 — see `archive/skills/README.md`.)
- **The authoring guide** — for the generic SKILLS-standard guidance (frontmatter; description & triggering; structure & progressive disclosure; body & content; scripts & tooling), see `plugins/pmos-toolkit/skills/feature-sdlc/reference/skill-patterns.md`. That is the single source of truth — used by `/feature-sdlc skill`'s requirements / spec / execute / verify stages and mirrored 1:1 by `plugins/pmos-toolkit/skills/feature-sdlc/reference/skill-eval.md` (the binary eval rubric).
- **See also** — "## Plugin manifest version sync" and "## Release entry point" below for the pmos-specific release rules a skill change must satisfy.

## Plugin manifest version sync

Both manifests must carry the same version on every release:

```
plugins/pmos-toolkit/.claude-plugin/plugin.json
plugins/pmos-toolkit/.codex-plugin/plugin.json
```

The pre-push hook enforces sync. When bumping versions for a release, edit both files in the same commit.

## Release entry point

`/complete-dev` is the canonical release skill. It supersedes the legacy `/push`. Skills, docs, and references in this repo should point at `/complete-dev`, not `/push`.

## Bash portability

Repo-wide invariants for any shell script in this repo (most live under `plugins/pmos-toolkit/skills/*/scripts/` and `tests/integration/`):

- **`BASH_SOURCE[0]` is not always populated.** When a script is sourced from a non-canonical path (e.g., via a symlink or under `bash -c "source …"`), `BASH_SOURCE[0]` can be empty or a relative segment that fails `cd "$(dirname …)"`. Always implement a fallback: prefer `${BASH_SOURCE[0]:-$0}`, then fall back to walking up from `$PWD` until a sentinel file is found, then exit with a clear error if neither resolves. Pattern in `plugins/pmos-toolkit/skills/readme/scripts/_reviewer_validate.sh` (2026-05-15).
