# Feature-Folder Artifact Layout — Design

**Date:** 2026-04-30
**Status:** Approved (brainstorm complete; writing-plans next)
**Scope:** pmos-toolkit skills that produce or consume pipeline artifacts

## Problem

Today, pmos-toolkit skills save their outputs to skill-centric canonical folders:

- `docs/requirements/YYYY-MM-DD-<feature>.md`
- `docs/specs/YYYY-MM-DD-<feature>-spec.md`
- `docs/plans/YYYY-MM-DD-<feature>-implementation-plan.md`

Artifacts for a single feature scatter across three top-level folders, making it hard to see "everything related to this initiative" at a glance. Newer skills like `/wireframes` produce collections of files that don't fit cleanly into the per-skill-folder pattern. As more pipeline skills ship (`/simulate-spec`, `/execute`, `/verify`), the scatter problem compounds.

## Solution Overview

Move to a feature-centric layout: every initiative gets one folder under `docs/`, named `{YYYY-MM-DD}_{feature-slug}`. All artifacts for that feature — single-file core pipeline outputs and multi-file collections — live inside it.

A shared resolution protocol (`_shared/feature-folder.md`) replaces ad-hoc path logic in each skill. The protocol is callable by any pipeline skill, so the user can enter the pipeline at any stage (`/requirements`, `/spec`, `/plan`, `/wireframes`, etc.) and have artifacts land in the right place.

## Folder Layout

```
docs/
  2026-04-30_verify-skill-teeth/
    01_requirements.md
    02_spec.md
    03_plan.md
    wireframes/
      01_landing.html
      02_dashboard.html
      assets/
    simulate-spec/
      2026-05-01-trace.md
    execute/
      task-01.md
    verify/
      2026-05-02-review.md
```

**Rules:**

1. Feature folders live at `docs/{YYYY-MM-DD}_{slug}/`. The date is the folder *creation* date — it does not change as work progresses.
2. **Numbered single-files** at the root for the core pipeline:
   - `01_requirements.md` — `/requirements`
   - `02_spec.md` — `/spec`
   - `03_plan.md` — `/plan`
3. Pipeline-order numbering is fixed. Gaps are allowed (e.g., no `01_` if the user started at `/spec`).
4. **Unnumbered subfolders** for everything else. Each subfolder is owned by exactly one skill, which controls its internal structure:
   - `wireframes/` — `/wireframes`
   - `simulate-spec/` — `/simulate-spec`
   - `execute/` — `/execute`
   - `verify/` — `/verify`
5. Re-runs of a numbered skill **overwrite** the existing file. Git is the version history.
6. Subfolder skills append (each run produces a new dated file inside the subfolder).

## Slug Rules

Slugs are durable — they appear in every artifact path. Rules:

- Lowercase
- Kebab-case (alphanumeric + hyphens only)
- Max 40 characters
- Auto-derivation: lowercase the feature name, replace non-alphanumeric runs with `-`, strip leading/trailing `-`, truncate at 40

Slug creation always presents the derived default to the user via `AskUserQuestion`-style prompt; Enter accepts, edit overrides. Consistent prompt regardless of how clean the auto-derivation is.

## Discovery Protocol — `_shared/feature-folder.md`

Every pipeline skill calls this protocol after product-context loading and before any artifact work.

**Inputs:**
- Skill name (e.g., `spec`)
- Optional `--feature <slug>` flag value
- Optional feature-name hint (e.g., user input the skill received)

**Outputs:**
- Absolute path to the feature folder (created if needed)
- The feature slug
- Whether the folder was newly created or pre-existing

**Resolution algorithm:**

```
1. If --feature <slug> was passed:
     - Look for docs/*_<slug>/ (any date prefix).
     - Found: use it. Update .pmos/current-feature. Return.
     - Not found: error with available slugs. Do NOT auto-create.

2. Read .pmos/current-feature:
     - Present and folder exists: use it. Return.
     - Present but stale: warn, clear pointer, fall to step 3.
     - Absent: fall to step 3.

3. Prompt the user (AskUserQuestion):
     "What feature is this for?"
     - "Create new: <derived-slug>"  (only if skill provided a hint)
     - up to 5 most-recently-modified existing feature folders
     - "Other..." (free-text)

4. If "create new":
     - Show derived slug; allow edit (Enter accepts).
     - Validate: kebab-case, ≤40 chars, no collision.
     - Create docs/{today}_{slug}/.
     - Write .pmos/current-feature.
     - Return.

5. If existing folder selected:
     - Update .pmos/current-feature.
     - Return.
```

## Pointer File — `.pmos/current-feature`

- Plain text, single line: the folder name (e.g., `2026-04-30_verify-skill-teeth`).
- Repo-local. Each repo has its own pointer.
- Default `.gitignore`d (session state, not project state). Documented as such; flippable later if team usage demands shared pointers.
- Cleared by manual edit/delete or by a future `/feature done` command (not scoped in v1).

## Per-Skill Mapping

| Skill | Output path | Folder-creation role |
|---|---|---|
| `/requirements` | `<feature>/01_requirements.md` | Common entry point; usually creates folder |
| `/spec` | `<feature>/02_spec.md` | Can create folder if entering pipeline mid-stream |
| `/plan` | `<feature>/03_plan.md` | Can create folder if entering pipeline mid-stream |
| `/wireframes` | `<feature>/wireframes/NN_<screen>.html` | Can create folder; controls subfolder contents |
| `/simulate-spec` | `<feature>/simulate-spec/<date>-trace.md` | Reads `02_spec.md`; subfolder skill |
| `/execute` | `<feature>/execute/task-NN.md` | Reads `03_plan.md`; per-task logs |
| `/verify` | `<feature>/verify/<date>-review.md` | Reads all prior artifacts in folder |
| `/backlog promote <id>` | Creates folder, seeds `01_requirements.md` | Calls protocol with create-new path |
| `/changelog`, `/session-log`, `/learnings`, `/mac-health`, `/mytasks`, `/people` | unchanged | Not feature-scoped |

## Cross-Skill Reads (`pipeline-input-resolution.md` updates)

Skills that read prior artifacts (e.g., `/spec` reading the requirements doc) follow this resolution order:

1. **Primary:** look in the current feature folder for the expected numbered file (`01_requirements.md` for `/spec`, `02_spec.md` for `/plan`, etc.).
2. **Fallback:** search legacy `docs/{requirements,specs,plans}/` for the most recent matching file. This preserves the "build a spec from a legacy requirements doc" workflow.

**Boundary rule:**
- *Reads:* feature folder first, legacy folders as fallback.
- *Writes:* always feature folder. Never write to legacy folders.

## Edge Cases

1. **`--feature <slug>` not found** → error with available slugs; do not auto-create.
2. **Pointer set, but `/requirements` invoked for a new feature** → prompt: continue existing or create new.
3. **Slug collision** (user-chosen slug matches existing folder) → block creation; offer to use existing or pick a different slug. Never silently duplicate.
4. **Stale pointer** (folder deleted manually) → warn, clear pointer, fall through to prompt.
5. **Cross-repo same-feature** → each repo has its own pointer; no cross-repo coupling.
6. **Mid-run failure** → folder and pointer persist; next run resumes; partial artifacts overwrite on re-run.
7. **No feature hint, no pointer** → prompt path without "create new" option (or with a generic placeholder); user must pick existing or type a slug.
8. **Date drift** → folder date is creation date, never updated. Provides stable history.
9. **`/verify` run with missing prior artifacts** → primary lookup fails; legacy fallback runs; error if nothing found.
10. **Rename a feature mid-flight** → manual `mv` + edit pointer. No skill-level rename in v1.

## Rollout

**Forced cutover on a version bump.** pmos-toolkit ships a minor version (likely v1.9.0) where every pipeline skill uses the new layout. Existing artifacts in `docs/{requirements,specs,plans}/` are not migrated — they remain as historical inputs and are reachable via the legacy-fallback read path. After the upgrade, all *new* artifacts go into feature folders.

Documented in the changelog. No opt-in flag.

## Out of Scope (v1)

- Migration of existing `docs/{requirements,specs,plans}/` artifacts.
- A `/feature done` or `/feature rename` command.
- Cross-repo feature coordination.
- Committed (vs. gitignored) pointer file.

## Files Affected

**New:**
- `plugins/pmos-toolkit/skills/_shared/feature-folder.md` — resolution protocol

**Modified:**
- `plugins/pmos-toolkit/skills/requirements/SKILL.md` — call protocol, write to numbered path
- `plugins/pmos-toolkit/skills/spec/SKILL.md` — same
- `plugins/pmos-toolkit/skills/plan/SKILL.md` — same
- `plugins/pmos-toolkit/skills/wireframes/SKILL.md` — call protocol, write to subfolder
- `plugins/pmos-toolkit/skills/simulate-spec/SKILL.md` — same
- `plugins/pmos-toolkit/skills/execute/SKILL.md` — same
- `plugins/pmos-toolkit/skills/verify/SKILL.md` — same
- `plugins/pmos-toolkit/skills/backlog/SKILL.md` — promote path creates feature folder
- `plugins/pmos-toolkit/skills/_shared/pipeline-input-resolution.md` (or equivalent) — feature-folder-first, legacy fallback
- `plugins/pmos-toolkit/.codex-plugin` and `plugin.json` — version bump
- pmos-toolkit changelog
