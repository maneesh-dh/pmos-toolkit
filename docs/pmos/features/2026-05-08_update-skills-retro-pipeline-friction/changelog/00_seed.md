# Update brief: /changelog

**Source:** /update-skills triage at `docs/pmos/features/2026-05-08_update-skills-retro-pipeline-friction/00_triage.md`
**Triage findings approved for this skill:** 1
**Tier (user-confirmed):** Tier 1

## Approved findings (verbatim from triage)

### Finding CL1 — [friction] Skill follows `.pmos/settings.yaml` `docs_path` literally despite project's CLAUDE.md observed-convention override
- **Evidence:** Phase 1 says "Use `{docs_path}/changelog.md`" without checking for a sibling under `docs/`. In a recent run, `.pmos/settings.yaml` had `docs_path: .pmos` but the project's CLAUDE.md said "follow the observed `docs/` convention and write alongside existing siblings"; user had to manually override and write to `docs/changelog.md` instead of `.pmos/changelog.md`.
- **Proposed fix (verbatim):** In Phase 1, after reading `docs_path` from settings, also check if `{repo_root}/docs/changelog.md` exists. If it does, prefer it (and emit a one-line note suggesting the user fix the `settings.yaml` mismatch). The pattern of "settings says X but observed convention is Y" is repo-specific and worth honoring.
- **Classification:** UX-friction
- **Scope hint:** small

## Current SKILL.md excerpt (section to change)

> from `plugins/pmos-toolkit/skills/changelog/SKILL.md`, "## Determine docs_path" (lines 11–13):
>
> ## Determine docs_path
>
> Check for `.pmos/settings.yaml` in the current repo. If found, read `docs_path` from it. If not found, follow `_shared/pipeline-setup.md` Section A to run first-run setup (which writes settings.yaml and detects legacy `docs/` layout). Use `{docs_path}/changelog.md` as the output path.

> from `plugins/pmos-toolkit/skills/changelog/SKILL.md`, "## Process" step 5 (line 120):
>
> 5. **Write** — Prepend the entry to `{docs_path}/changelog.md`. If the file doesn't exist, create it with a single H1 header `# Changelog` followed by the entry.

> from `plugins/pmos-toolkit/skills/changelog/SKILL.md`, "## Process" step 1 (line 102):
>
> 1. **Determine scope** — Run `git log` to find commits since the last changelog entry date (read the top entry in `{docs_path}/changelog.md` for the last date). If no changelog exists, use all commits on main.

## Proposed direction

Extend the "Determine docs_path" section so that after resolving `docs_path` from settings, the skill also probes `{repo_root}/docs/changelog.md`. Resolution becomes: (a) if a sibling `docs/changelog.md` exists AND `docs_path != docs/`, prefer the sibling AND emit a single advisory line to the user noting the settings/observed-convention mismatch (suggest they update `settings.yaml`); (b) otherwise use `{docs_path}/changelog.md` as today. Apply the resolved path consistently to both Process step 1 (scope read) and step 5 (write). Behavior must remain unchanged when `docs_path` is `docs/` or when no sibling `docs/changelog.md` exists. No new phases, no new reference files — the change is a single resolver tweak in the existing "Determine docs_path" section.

## Out-of-scope for this run

None — this is the only approved finding for /changelog. Do not redesign Process steps 2–4 or the "Rules" block.

## Constraints

- Skill must remain backwards-compatible with its current `argument-hint`/contract.
- Reference paths (`_shared/pipeline-setup.md`) resolve as siblings under `plugins/pmos-toolkit/skills/`.
- The advisory line must be at most one line and must not block (no AskUserQuestion).
- Version bump at next /push: patch.
