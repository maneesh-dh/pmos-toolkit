# Feature-Folder Artifact Layout Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move pmos-toolkit pipeline artifacts from skill-centric folders (`docs/requirements/`, `docs/specs/`, `docs/plans/`) to feature-centric folders (`docs/{YYYY-MM-DD}_{slug}/`) with a shared discovery protocol and a `--feature` override.

**Architecture:** Introduce `_shared/feature-folder.md` (resolve-or-create protocol called by every pipeline skill at startup). Update `.shared/resolve-input.md` to read from the current feature folder first, with legacy folders as fallback. Each pipeline skill calls the protocol, writes to a fixed numbered path (`01_requirements.md`, `02_spec.md`, `03_plan.md`) or its owned subfolder (`wireframes/`, `simulate-spec/`, `execute/`, `verify/`). Forced cutover at v1.9.0; existing artifacts not migrated but readable via legacy fallback.

**Tech Stack:** Markdown skill instructions (no code). Verification = grep/diff inspection plus a real end-to-end smoke run.

**Spec reference:** `docs/specs/2026-04-30-feature-folder-artifact-layout-design.md`

---

## File Structure

**New files:**
- `plugins/pmos-toolkit/skills/_shared/feature-folder.md` — resolution-and-create protocol
- `.gitignore` entry for `.pmos/current-feature` (added to repo root `.gitignore`)

**Modified files:**
- `plugins/pmos-toolkit/skills/.shared/resolve-input.md` — feature-folder-first reads, legacy fallback
- `plugins/pmos-toolkit/skills/requirements/SKILL.md`
- `plugins/pmos-toolkit/skills/spec/SKILL.md`
- `plugins/pmos-toolkit/skills/plan/SKILL.md`
- `plugins/pmos-toolkit/skills/wireframes/SKILL.md`
- `plugins/pmos-toolkit/skills/simulate-spec/SKILL.md`
- `plugins/pmos-toolkit/skills/execute/SKILL.md`
- `plugins/pmos-toolkit/skills/verify/SKILL.md`
- `plugins/pmos-toolkit/skills/backlog/SKILL.md` (promote path only)
- `plugins/pmos-toolkit/.claude-plugin/plugin.json` — version bump to 1.9.0
- `plugins/pmos-toolkit/.codex-plugin/plugin.json` — version bump to 1.9.0
- pmos-toolkit changelog (location: existing convention in repo)

---

## Task 1: Create `_shared/feature-folder.md` resolution protocol

**Files:**
- Create: `plugins/pmos-toolkit/skills/_shared/feature-folder.md`

- [ ] **Step 1: Write the protocol document**

Content of `plugins/pmos-toolkit/skills/_shared/feature-folder.md`:

```markdown
# Resolve or Create Feature Folder

Shared procedure for pipeline skills that produce or consume feature-scoped artifacts. Every pipeline skill calls this **after product-context loading** and **before any artifact work**. Returns the absolute path to the feature folder, the slug, and whether the folder was newly created.

Callers pass:
- `skill_name` — e.g. `requirements`, `spec`, `plan`, `wireframes`
- `feature_arg` — value of `--feature <slug>` if the user provided it; otherwise empty
- `feature_hint` — a short feature-name string the skill has from user input (used to derive a default slug for new folders); may be empty

The folder lives at `{docs_path}/{YYYY-MM-DD}_{slug}/` where `{docs_path}` was resolved by `product-context/context-loading.md` and the date is the folder *creation* date.

## Step 1: Explicit `--feature` argument

If `feature_arg` is non-empty:
- Look for a folder matching `{docs_path}/*_{feature_arg}/` (any date prefix).
- **Exactly one match:** use it. Update `.pmos/current-feature` to that folder name. Echo: `Using feature folder: <path>`. Return.
- **Zero matches:** error. Echo: `No feature folder matching '{feature_arg}'. Available: <list of slugs from existing feature folders>`. Stop. Do **not** auto-create — explicit `--feature` is a precise lookup.
- **Multiple matches:** error. Echo: `Multiple feature folders match '{feature_arg}': <list>`. Stop.

## Step 2: Read pointer file

Read `.pmos/current-feature` if present. The file contains a single line: the folder name (e.g., `2026-04-30_verify-skill-teeth`).
- **Pointer present and folder exists:** use it. Echo: `Using feature folder: <path>`. Return.
- **Pointer present but folder missing (stale):** warn `Pointer references missing folder '<x>' — clearing.` Delete the pointer file. Continue to Step 3.
- **Pointer absent:** continue to Step 3.

## Step 3: Prompt the user

Use `AskUserQuestion`-style prompt (see `_shared/interactive-prompts.md`):

> What feature is this for?

Options, in order:
1. `Create new: <derived-slug>` — only if `feature_hint` is non-empty. Derive `<derived-slug>` per the **Slug Rules** section below.
2. Up to 5 most-recently-modified existing feature folders, one option each, labeled by folder name.
3. `Other...` — free-text input. The text is treated as either an existing slug to look up (per Step 1 logic) or a new slug to create.

## Step 4: Create new (when chosen)

If the user picks **Create new** or types a new slug under **Other...**:

1. Show the derived (or typed) slug. Prompt: `Slug: <derived-slug> [Enter to accept, edit to override]`. Accept the user's edited value if any.
2. Validate the final slug against **Slug Rules** below. On failure, show the rule that was violated and re-prompt.
3. **Collision check:** if `{docs_path}/*_{slug}/` already matches an existing folder (any date), abort the create. Show the existing folder and prompt:
   - `Use existing <folder-name>` — switch to that folder.
   - `Pick a different slug` — re-prompt for slug.
4. Create the directory `{docs_path}/{today}_{slug}/` where `{today}` is the current date `YYYY-MM-DD`.
5. Write `.pmos/current-feature` containing the folder name (single line, no trailing newline issues — use plain echo).
6. Echo: `Created feature folder: <path>`. Return.

## Step 5: Existing folder (when chosen)

If the user picks an existing folder:
1. Update `.pmos/current-feature` to that folder name.
2. Echo: `Using feature folder: <path>`. Return.

## Slug Rules

- Lowercase only.
- Kebab-case: alphanumeric (`a-z`, `0-9`) and hyphens only. No underscores, spaces, slashes.
- Max 40 characters.
- No leading or trailing hyphens.
- No double hyphens (collapse runs).

**Auto-derivation from a feature hint:**
1. Lowercase the hint.
2. Replace any run of non-alphanumeric characters with a single hyphen.
3. Strip leading/trailing hyphens.
4. Truncate at 40 characters; if the truncation lands mid-word, prefer truncating at the previous hyphen if that keeps the slug ≥20 chars.

## Pointer File

`.pmos/current-feature` is repo-local plain text, one line: the folder name only (no path, no quotes). Default `.gitignore`d. Cleared by manual edit, by Step 2 (stale), or by future `/feature done` command (out of scope for v1).
```

- [ ] **Step 2: Verify file shape**

Run: `wc -l plugins/pmos-toolkit/skills/_shared/feature-folder.md && head -5 plugins/pmos-toolkit/skills/_shared/feature-folder.md`
Expected: file exists, starts with `# Resolve or Create Feature Folder`.

- [ ] **Step 3: Commit**

```bash
git add plugins/pmos-toolkit/skills/_shared/feature-folder.md
git commit -m "feat(pmos-toolkit): add feature-folder resolution protocol"
```

---

## Task 2: Update `.shared/resolve-input.md` for feature-folder-first reads

**Files:**
- Modify: `plugins/pmos-toolkit/skills/.shared/resolve-input.md`

- [ ] **Step 1: Read the current file**

Read all 39 lines of `plugins/pmos-toolkit/skills/.shared/resolve-input.md` to confirm the current 3-step structure (explicit arg → conversation history → numbered picker over `{docs_path}/{phase}/`).

- [ ] **Step 2: Replace the document with the feature-folder-aware version**

Replace the entire file contents with:

```markdown
# Resolve Pipeline Input

Shared procedure for pipeline skills that consume a prior-phase document. Callers pass:
- `phase` — the canonical phase name: `requirements`, `spec`, or `plan`
- `label` — human-readable name for prompts (e.g., "requirements doc", "spec", "plan")

The phase maps to a numbered file in the current feature folder:

| phase          | feature-folder file       | legacy folder         |
|----------------|---------------------------|-----------------------|
| `requirements` | `01_requirements.md`      | `{docs_path}/requirements/` |
| `spec`         | `02_spec.md`              | `{docs_path}/specs/`        |
| `plan`         | `03_plan.md`              | `{docs_path}/plans/`        |

Try resolution steps in order. Stop at the first hit. Always echo the resolved path on a single line before proceeding — this is the user's only chance to catch a wrong pick.

## Step 1: Explicit argument

If the user passed an argument to the slash command:
- If it resolves to an existing file path, use it. Echo: `Using: <path>`
- Otherwise treat the argument as inline content. Echo: `Using inline <label> from argument`

Proceed. Skip remaining steps.

## Step 2: Current feature folder

If a current feature folder is set (per `_shared/feature-folder.md`), check for the numbered file for this `phase`:
- Found: echo `Using: <path>` and proceed.
- Not found: continue to Step 3.

## Step 3: Conversation history

Scan this session for any file written, edited, or read earlier that matches the feature-folder file or the legacy `{docs_path}/{phase}/` location. If one or more exist, pick the most recently touched. Echo: `Using from this session: <path>`

Proceed. Skip remaining steps. Do not prompt — the echo is the confirmation; the user can interrupt if wrong.

## Step 4: Legacy folder picker (fallback)

List files in legacy `{docs_path}/{phase_legacy}/` sorted by mtime (newest first), keeping up to 3. (`phase_legacy` per the table above: `requirements`, `specs`, `plans`.)

- **0 files:** Report `No {label} found in current feature folder or {docs_path}/{phase_legacy}/` and ask the user to provide a path or inline content. Do not proceed until provided.
- **1 file:** Skip the list. Echo: `Using legacy: <path>` and proceed.
- **2–3 files:** Present a numbered list:

  ```
  Recent {label}s in {docs_path}/{phase_legacy}/ (legacy):
    [1] <path>  (modified <mtime>)
    [2] <path>  (modified <mtime>)
    [3] <path>  (modified <mtime>)
  Pick one [default 1]:
  ```

  On confirmation (including empty input → 1), echo: `Using legacy: <path>` and proceed.
```

- [ ] **Step 3: Verify**

Run: `grep -c "Step" plugins/pmos-toolkit/skills/.shared/resolve-input.md`
Expected: `4` (Steps 1–4).

Run: `grep "01_requirements\|02_spec\|03_plan" plugins/pmos-toolkit/skills/.shared/resolve-input.md`
Expected: all three numbered files appear in the table.

- [ ] **Step 4: Commit**

```bash
git add plugins/pmos-toolkit/skills/.shared/resolve-input.md
git commit -m "feat(pmos-toolkit): resolve-input reads feature folder first, legacy fallback"
```

---

## Task 3: Update `/requirements` skill

**Files:**
- Modify: `plugins/pmos-toolkit/skills/requirements/SKILL.md`

- [ ] **Step 1: Read the file** (full contents) to locate the existing save instruction (`Save to {docs_path}/requirements/YYYY-MM-DD-<feature-name>.md`).

- [ ] **Step 2: Add a "Resolve feature folder" step right after product-context loading**

Insert (or replace the existing folder-creation guidance) with text along these lines, placed immediately after the existing context-loading paragraph:

```markdown
**Resolve feature folder.** Follow `../_shared/feature-folder.md` with `skill_name=requirements`, `feature_arg=<value of --feature flag if provided, else empty>`, and `feature_hint=<short user-supplied feature name from the conversation>`. Use the returned folder path as `{feature_folder}` for the rest of this run. The protocol creates the folder if needed.
```

- [ ] **Step 3: Replace the save instruction**

Find: `Save to {docs_path}/requirements/YYYY-MM-DD-<feature-name>.md. Create the directory if it doesn't exist.`

Replace with: `Save to {feature_folder}/01_requirements.md. Overwrite if it already exists (git provides version history).`

- [ ] **Step 4: Add `--feature <slug>` to the argument-hint frontmatter**

In the YAML frontmatter at the top of `SKILL.md`, update the `argument-hint` value to include `[--feature <slug>]`. Example: if it currently reads `argument-hint: "<feature description> [--backlog <id>]"`, change to `argument-hint: "<feature description> [--feature <slug>] [--backlog <id>]"`.

- [ ] **Step 5: Verify**

Run: `grep -E "feature-folder\.md|01_requirements\.md|--feature" plugins/pmos-toolkit/skills/requirements/SKILL.md`
Expected: at least three matches (protocol reference, save path, argument hint).

Run: `grep "docs/requirements/" plugins/pmos-toolkit/skills/requirements/SKILL.md`
Expected: no matches (legacy write path removed).

- [ ] **Step 6: Commit**

```bash
git add plugins/pmos-toolkit/skills/requirements/SKILL.md
git commit -m "feat(pmos-toolkit): /requirements writes to feature folder"
```

---

## Task 4: Update `/spec` skill

**Files:**
- Modify: `plugins/pmos-toolkit/skills/spec/SKILL.md`

- [ ] **Step 1: Read the file** to locate (a) the existing save instruction (`Save to {docs_path}/specs/...`), (b) the "Locate the requirements" step that calls `resolve-input.md`, (c) the "Check for existing spec" step.

- [ ] **Step 2: Add the resolve-feature-folder step**

After product-context loading and **before** the "Locate the requirements" step, add:

```markdown
**Resolve feature folder.** Follow `../_shared/feature-folder.md` with `skill_name=spec`, `feature_arg=<--feature value or empty>`, and `feature_hint=<topic from user input or the requirements arg>`. Use the returned folder path as `{feature_folder}`. The protocol creates the folder if needed (supporting users who enter the pipeline at /spec).
```

- [ ] **Step 3: Update the existing-spec check**

Find the step `Check for existing spec. Look in {docs_path}/specs/ for an existing file.`

Replace the path with `{feature_folder}/02_spec.md`. Keep the same "update vs fresh start" branching logic.

- [ ] **Step 4: Replace the save instruction**

Find: `Save to {docs_path}/specs/YYYY-MM-DD-<feature-name>-spec.md` (or whatever the current exact phrasing is — match the spec file's actual line).

Replace with: `Save to {feature_folder}/02_spec.md. Overwrite if it already exists.`

- [ ] **Step 5: Update argument-hint frontmatter** to include `[--feature <slug>]`.

- [ ] **Step 6: Verify**

Run: `grep -E "feature-folder\.md|02_spec\.md|--feature" plugins/pmos-toolkit/skills/spec/SKILL.md`
Expected: protocol reference, save path, argument hint all present.

Run: `grep "docs/specs/\|docs/specs}" plugins/pmos-toolkit/skills/spec/SKILL.md`
Expected: no matches in *write* contexts (legacy may still be referenced in resolve-input.md examples; for SKILL.md specifically, no write paths to legacy).

- [ ] **Step 7: Commit**

```bash
git add plugins/pmos-toolkit/skills/spec/SKILL.md
git commit -m "feat(pmos-toolkit): /spec writes to feature folder"
```

---

## Task 5: Update `/plan` skill

**Files:**
- Modify: `plugins/pmos-toolkit/skills/plan/SKILL.md`

- [ ] **Step 1: Read the file** to locate the save instruction (`Save to {docs_path}/plans/...`) and any existing-plan check.

- [ ] **Step 2: Add resolve-feature-folder step** (same shape as Task 4 Step 2):

```markdown
**Resolve feature folder.** Follow `../_shared/feature-folder.md` with `skill_name=plan`, `feature_arg=<--feature value or empty>`, and `feature_hint=<topic from user input or spec arg>`. Use the returned folder path as `{feature_folder}`. The protocol creates the folder if needed.
```

Place after product-context loading and before any input resolution.

- [ ] **Step 3: Replace the save instruction**

Find: `Save to {docs_path}/plans/YYYY-MM-DD-<feature-name>-implementation-plan.md` (match exact phrasing).

Replace with: `Save to {feature_folder}/03_plan.md. Overwrite if it already exists.`

- [ ] **Step 4: Update existing-plan check** if present — point to `{feature_folder}/03_plan.md` instead of legacy folder.

- [ ] **Step 5: Update argument-hint frontmatter** to include `[--feature <slug>]`.

- [ ] **Step 6: Verify**

Run: `grep -E "feature-folder\.md|03_plan\.md|--feature" plugins/pmos-toolkit/skills/plan/SKILL.md`
Expected: all three.

Run: `grep "docs/plans/" plugins/pmos-toolkit/skills/plan/SKILL.md`
Expected: no write-path matches.

- [ ] **Step 7: Commit**

```bash
git add plugins/pmos-toolkit/skills/plan/SKILL.md
git commit -m "feat(pmos-toolkit): /plan writes to feature folder"
```

---

## Task 6: Update `/wireframes` skill

**Files:**
- Modify: `plugins/pmos-toolkit/skills/wireframes/SKILL.md`

- [ ] **Step 1: Read the file** to find the current output-path instructions for HTML files and any assets.

- [ ] **Step 2: Add resolve-feature-folder step** (after product-context loading):

```markdown
**Resolve feature folder.** Follow `../_shared/feature-folder.md` with `skill_name=wireframes`, `feature_arg=<--feature value or empty>`, and `feature_hint=<topic from user input>`. Use the returned folder path as `{feature_folder}`. Wireframes are commonly produced before /spec, so this skill may create the folder.
```

- [ ] **Step 3: Replace output-path instructions**

Wireframe files now go to `{feature_folder}/wireframes/`. Inside that subfolder:
- HTML files: `{feature_folder}/wireframes/{NN}_{screen-slug}.html` where `NN` is a 2-digit zero-padded sequence number reflecting the intended viewing order. The first file is `01_…`, second is `02_…`, etc. The skill controls the numbering.
- Supporting assets (CSS, images): `{feature_folder}/wireframes/assets/`.

Update the SKILL.md text accordingly. Replace any prior `docs/wireframes/...` or similar paths.

- [ ] **Step 4: Update argument-hint frontmatter** to include `[--feature <slug>]`.

- [ ] **Step 5: Verify**

Run: `grep -E "feature-folder\.md|wireframes/|--feature" plugins/pmos-toolkit/skills/wireframes/SKILL.md`
Expected: protocol reference, subfolder write path, argument hint.

- [ ] **Step 6: Commit**

```bash
git add plugins/pmos-toolkit/skills/wireframes/SKILL.md
git commit -m "feat(pmos-toolkit): /wireframes writes to feature subfolder"
```

---

## Task 7: Update `/simulate-spec` skill

**Files:**
- Modify: `plugins/pmos-toolkit/skills/simulate-spec/SKILL.md`

- [ ] **Step 1: Read the file** to find current input/output handling.

- [ ] **Step 2: Add resolve-feature-folder step** (after product-context loading):

```markdown
**Resolve feature folder.** Follow `../_shared/feature-folder.md` with `skill_name=simulate-spec`, `feature_arg=<--feature value or empty>`, and `feature_hint=<spec slug or topic>`. Use the returned folder path as `{feature_folder}`. This skill consumes `02_spec.md` and writes traces under `{feature_folder}/simulate-spec/`.
```

- [ ] **Step 3: Update input resolution**

If the skill currently references `resolve-input.md` with phase=`spec`, that already returns `{feature_folder}/02_spec.md` first (per Task 2). No further change needed for input.

If the skill takes an explicit spec-path argument (per its `argument-hint`), that path overrides — keep that behavior.

- [ ] **Step 4: Replace output-path instructions**

Trace files: `{feature_folder}/simulate-spec/{YYYY-MM-DD}-trace.md`. Multiple runs append by date; if two run the same day, append `-2`, `-3`, etc.

- [ ] **Step 5: Update argument-hint frontmatter** to include `[--feature <slug>]` (in addition to whatever path argument it already accepts).

- [ ] **Step 6: Verify**

Run: `grep -E "feature-folder\.md|simulate-spec/|--feature" plugins/pmos-toolkit/skills/simulate-spec/SKILL.md`
Expected: all three.

- [ ] **Step 7: Commit**

```bash
git add plugins/pmos-toolkit/skills/simulate-spec/SKILL.md
git commit -m "feat(pmos-toolkit): /simulate-spec writes to feature subfolder"
```

---

## Task 8: Update `/execute` skill

**Files:**
- Modify: `plugins/pmos-toolkit/skills/execute/SKILL.md`

- [ ] **Step 1: Read the file** to find current plan-input and per-task-log handling.

- [ ] **Step 2: Add resolve-feature-folder step** (after product-context loading):

```markdown
**Resolve feature folder.** Follow `../_shared/feature-folder.md` with `skill_name=execute`, `feature_arg=<--feature value or empty>`, and `feature_hint=<topic if provided>`. Use the returned folder path as `{feature_folder}`. This skill consumes `03_plan.md` and writes per-task logs under `{feature_folder}/execute/`.
```

- [ ] **Step 3: Plan input** — already covered by `resolve-input.md` updates (Task 2). No further change.

- [ ] **Step 4: Replace per-task-log path**

Per-task logs: `{feature_folder}/execute/task-{NN}.md` where `NN` matches the task number from the plan. Overwrite if a re-run hits the same task.

- [ ] **Step 5: Update argument-hint frontmatter** to include `[--feature <slug>]`.

- [ ] **Step 6: Verify**

Run: `grep -E "feature-folder\.md|execute/|--feature" plugins/pmos-toolkit/skills/execute/SKILL.md`
Expected: all three.

- [ ] **Step 7: Commit**

```bash
git add plugins/pmos-toolkit/skills/execute/SKILL.md
git commit -m "feat(pmos-toolkit): /execute writes per-task logs to feature subfolder"
```

---

## Task 9: Update `/verify` skill

**Files:**
- Modify: `plugins/pmos-toolkit/skills/verify/SKILL.md`

- [ ] **Step 1: Read the file** to locate inputs (reads requirements, spec, plan, execution logs) and review-report output path.

- [ ] **Step 2: Add resolve-feature-folder step** (after product-context loading):

```markdown
**Resolve feature folder.** Follow `../_shared/feature-folder.md` with `skill_name=verify`, `feature_arg=<--feature value or empty>`, and `feature_hint=<topic if provided>`. Use the returned folder path as `{feature_folder}`. This skill reads all prior artifacts (`01_requirements.md`, `02_spec.md`, `03_plan.md`, `execute/`) and writes review reports under `{feature_folder}/verify/`.
```

- [ ] **Step 3: Update reads** — for each "read prior artifact" instruction in the skill (requirements, spec, plan, execution logs), point to the feature-folder paths first; legacy fallback is automatic via `resolve-input.md`.

- [ ] **Step 4: Replace review-report output path**

Review reports: `{feature_folder}/verify/{YYYY-MM-DD}-review.md`. Multiple runs same day → append `-2`, `-3`.

- [ ] **Step 5: Update argument-hint frontmatter** to include `[--feature <slug>]`.

- [ ] **Step 6: Verify**

Run: `grep -E "feature-folder\.md|verify/|--feature" plugins/pmos-toolkit/skills/verify/SKILL.md`
Expected: all three.

- [ ] **Step 7: Commit**

```bash
git add plugins/pmos-toolkit/skills/verify/SKILL.md
git commit -m "feat(pmos-toolkit): /verify writes reports to feature subfolder"
```

---

## Task 10: Update `/backlog promote` to seed feature folder

**Files:**
- Modify: `plugins/pmos-toolkit/skills/backlog/SKILL.md`

- [ ] **Step 1: Read the file** to locate the `promote` command's behavior — specifically where a backlog item is converted into a requirements doc.

- [ ] **Step 2: Update promote-path output**

When `/backlog promote <id>` runs:
1. Call `_shared/feature-folder.md` with `skill_name=backlog`, `feature_arg=<--feature value or empty>`, and `feature_hint=<title of the backlog item>`. Default to **Create new** with the derived slug.
2. Seed the new folder with `01_requirements.md` populated from the backlog item content (existing behavior, just routed to the new path).
3. Update `.pmos/current-feature` to the new folder (the protocol does this).

Replace the existing legacy-path write with `{feature_folder}/01_requirements.md`.

- [ ] **Step 3: Verify**

Run: `grep -E "feature-folder\.md|01_requirements\.md" plugins/pmos-toolkit/skills/backlog/SKILL.md`
Expected: both present in the promote section.

- [ ] **Step 4: Commit**

```bash
git add plugins/pmos-toolkit/skills/backlog/SKILL.md
git commit -m "feat(pmos-toolkit): /backlog promote creates feature folder"
```

---

## Task 11: Add `.gitignore` rule for the pointer file

**Files:**
- Modify: repo-root `.gitignore` (create if absent)

- [ ] **Step 1: Check current state**

Run: `cat .gitignore 2>/dev/null | grep -c "current-feature" || echo 0`
Expected: `0` (rule not yet present).

- [ ] **Step 2: Append the rule**

Append this block to `.gitignore`:

```
# pmos-toolkit per-repo session pointer
.pmos/current-feature
```

- [ ] **Step 3: Verify**

Run: `grep "current-feature" .gitignore`
Expected: line present.

- [ ] **Step 4: Commit**

```bash
git add .gitignore
git commit -m "chore: gitignore .pmos/current-feature pointer"
```

---

## Task 12: Bump pmos-toolkit version to 1.9.0

**Files:**
- Modify: `plugins/pmos-toolkit/.claude-plugin/plugin.json`
- Modify: `plugins/pmos-toolkit/.codex-plugin/plugin.json`

- [ ] **Step 1: Read both manifests** to confirm current version (expected `1.8.0`).

Run: `grep '"version"' plugins/pmos-toolkit/.claude-plugin/plugin.json plugins/pmos-toolkit/.codex-plugin/plugin.json`

- [ ] **Step 2: Update both files**

Change `"version": "1.8.0"` to `"version": "1.9.0"` in both files. Use `Edit` tool with `old_string="\"version\": \"1.8.0\""` and `new_string="\"version\": \"1.9.0\""` per file.

- [ ] **Step 3: Verify**

Run: `grep '"version"' plugins/pmos-toolkit/.claude-plugin/plugin.json plugins/pmos-toolkit/.codex-plugin/plugin.json`
Expected: both show `"version": "1.9.0"`.

- [ ] **Step 4: Commit**

```bash
git add plugins/pmos-toolkit/.claude-plugin/plugin.json plugins/pmos-toolkit/.codex-plugin/plugin.json
git commit -m "chore(pmos-toolkit): bump to v1.9.0 for feature-folder layout"
```

---

## Task 13: Add changelog entry

**Files:**
- Modify: existing pmos-toolkit changelog (locate it first)

- [ ] **Step 1: Locate the changelog**

Run: `find plugins/pmos-toolkit -maxdepth 3 -iname "changelog*" -o -iname "CHANGELOG*" | head -5`

If a changelog file exists, modify it. If not, follow the existing repo convention (check recent commits like `b2f7156`, `3d8c19d` for how previous bumps were documented; likely no separate changelog file — version-bump commits + the commit log are the changelog).

- [ ] **Step 2: Add an entry (if changelog file exists)**

Add a top entry under `## v1.9.0 — 2026-04-30` (or whatever today's date is at execution time) with bullet points:

```markdown
## v1.9.0 — YYYY-MM-DD

- **BREAKING (forced cutover):** Pipeline artifacts now save to feature-centric folders at `docs/{YYYY-MM-DD}_{slug}/` instead of skill-centric folders (`docs/requirements/`, `docs/specs/`, `docs/plans/`).
- New `_shared/feature-folder.md` resolution protocol: pointer file at `.pmos/current-feature`, `--feature <slug>` override on every pipeline skill, prompt fallback when no current feature is set.
- `/wireframes`, `/simulate-spec`, `/execute`, `/verify` now write into owned subfolders (`wireframes/`, `simulate-spec/`, `execute/`, `verify/`) within the current feature folder.
- `/backlog promote <id>` creates the feature folder and seeds `01_requirements.md`.
- Existing legacy artifacts under `docs/{requirements,specs,plans}/` are **not migrated** but remain readable as fallback inputs to the pipeline.
```

- [ ] **Step 3: Verify (if file exists)**

Run: `grep "v1.9.0\|feature-centric" <changelog-path>`
Expected: entry present.

- [ ] **Step 4: Commit**

```bash
git add <changelog-path>
git commit -m "docs(pmos-toolkit): changelog entry for v1.9.0 feature-folder layout"
```

If no changelog file exists, skip this task — the version-bump commit and individual feat commits document the change.

---

## Task 14: End-to-end smoke test

**Files:** none (interactive)

- [ ] **Step 1: Pick a throwaway test repo or scratch dir**

Use `/tmp/pmos-feature-folder-smoke` or a scratch git repo. Initialize with `git init` if needed. Make sure pmos-toolkit is loaded (this repo's plugin).

- [ ] **Step 2: Cold-start scenario (no pointer)**

In a fresh Claude Code session in the test repo:
1. Run `/pmos-toolkit:requirements add a button to the dashboard`.
2. Expected: skill prompts for slug confirmation with derived default like `add-a-button-to-the-dashboard`, then creates `docs/{today}_<slug>/01_requirements.md` and `.pmos/current-feature`.
3. Verify with `cat .pmos/current-feature` and `ls docs/`.

- [ ] **Step 3: Continuation scenario (pointer exists)**

In the same session (or a new one in the same repo):
1. Run `/pmos-toolkit:spec`.
2. Expected: skill reads `.pmos/current-feature`, finds the existing folder, reads `01_requirements.md` via `resolve-input.md` (Step 2 path: current feature folder), writes `02_spec.md` to the same folder. **No prompt** about which feature.
3. Verify `ls docs/{today}_<slug>/` shows both `01_requirements.md` and `02_spec.md`.

- [ ] **Step 4: `--feature` override scenario**

1. Run `/pmos-toolkit:plan --feature <existing-slug>`.
2. Expected: skill resolves the folder by slug regardless of pointer, writes `03_plan.md`.
3. Verify the plan is in the right folder.

- [ ] **Step 5: Mid-pipeline entry scenario**

1. Delete `.pmos/current-feature`.
2. Run `/pmos-toolkit:wireframes mockup the new dashboard`.
3. Expected: skill prompts (no current feature), offers "Create new: mockup-the-new-dashboard" and lists existing folders. User picks Create new. Skill creates `docs/{today}_mockup-the-new-dashboard/wireframes/01_<screen>.html`.
4. Verify folder structure.

- [ ] **Step 6: Legacy fallback scenario**

1. In a repo that has legacy `docs/specs/2026-01-15-old-feature-spec.md` but no current feature folder set.
2. Delete `.pmos/current-feature` if present.
3. Run `/pmos-toolkit:plan` (no args).
4. Expected: `resolve-input.md` finds the legacy spec via Step 4 (legacy folder picker), echoes `Using legacy: docs/specs/2026-01-15-old-feature-spec.md`. Then `feature-folder.md` is invoked separately for *output* path — prompts for new feature folder. `03_plan.md` lands in the new folder.
5. Verify the legacy spec was used as input but the new plan went to a feature folder.

- [ ] **Step 7: Slug collision scenario**

1. Try to create a new feature with a slug that matches an existing folder.
2. Expected: protocol blocks creation, offers "use existing" or "pick a different slug".

- [ ] **Step 8: Document any issues found**

If any step fails or feels wrong, capture in the verify report at `docs/<feature>/verify/<date>-review.md` (eating own dog food). Otherwise, proceed.

- [ ] **Step 9: No commit needed**

Smoke test artifacts are throwaway. If you used a scratch repo, leave it. If you used this repo, do not commit the smoke-test feature folders.

---

## Self-Review (run before handoff)

- [ ] **Spec coverage:** Each spec section maps to tasks?
  - Folder Layout → Tasks 3–10 (each skill writes to the right path)
  - Slug Rules → Task 1 (in protocol)
  - Discovery Protocol → Task 1
  - Pointer File → Task 1 (creation), Task 11 (gitignore)
  - Per-Skill Mapping → Tasks 3–10
  - Cross-Skill Reads → Task 2 (resolve-input.md)
  - Edge Cases → Task 1 (most), Task 14 (verified by smoke test)
  - Rollout → Task 12 (version bump), Task 13 (changelog)
  - Out of Scope → not implemented (correct)
- [ ] **Placeholder scan:** No "TBD" / "implement later". Each step has the actual content.
- [ ] **Type consistency:** `{feature_folder}` token used consistently across Tasks 3–10. Numbered file names (`01_requirements.md`, `02_spec.md`, `03_plan.md`) match the spec exactly. Subfolder names (`wireframes`, `simulate-spec`, `execute`, `verify`) match the spec exactly.
- [ ] **Sequencing:** Task 1 (protocol) and Task 2 (resolve-input) come before any skill update — skills reference these. Task 11 (gitignore) and Task 12 (version bump) can land anytime but are sensibly grouped near the end. Task 14 (smoke test) is last, depends on everything.
