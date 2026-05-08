---
name: artifact
description: Generate, refine, and update structured PM/eng artifacts (PRD, Experiment Design Doc, Engineering Design Doc, Discovery Doc) from existing context plus targeted gap-filling questions. Each artifact passes through a reviewer-subagent + auto-apply loop (max 2 iters) governed by per-section eval criteria. Ships with 4 built-in templates and 4 writing-style presets (Concise, Tabular, Narrative, Executive); users can author their own at ~/.pmos/artifacts/. Use when the user says "draft a PRD", "create an experiment design", "write a design doc", "generate a discovery doc", "/artifact", or names an artifact type to produce.
user-invocable: true
argument-hint: "[ | <type> [--tier lite|full] [--preset <slug>] | create <type> [...] | refine <path> | update <path> | template add|list|remove [<slug>] | preset add|list|remove [<slug>]]"
---

# /artifact

Generate, refine, and update structured PM/eng artifacts (PRD, Experiment Design Doc, Engineering Design Doc, Discovery Doc) with section-level eval criteria, a reviewer-subagent refinement loop (max 2 iterations), and writing-style presets. Templates ship in this skill; user-defined templates and presets live at `~/.pmos/artifacts/` and survive plugin upgrades.

**Announce at start:** "Using /artifact to {create|refine|update} a {type}."

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:
- **No `AskUserQuestion`:** State your assumption inline, document it in the artifact's frontmatter as `assumed: <field>`, proceed. User reviews after.
- **No subagents:** Run the refinement reviewer inline as the same agent. Same eval.md; same output format.
- **Task tracking:** Use whatever task tool exists (TaskCreate / update_plan / verbal phase announcements).

## Phase 0 — Load Context

1. Follow `../_shared/pipeline-setup.md` Section 0 (canonical inline block) to read `.pmos/settings.yaml`, resolve `{docs_path}`, and load workstream context. If settings.yaml is missing, run first-run setup per Section A.
2. Read `~/.pmos/learnings.md` if it exists. Note entries under `## /artifact` and factor them into this session.
3. Ensure `~/.pmos/artifacts/` exists. If not, create the empty tree:
   ```
   ~/.pmos/artifacts/
     templates/
     presets/
   ```
4. Determine the subcommand and route to the appropriate phase. Default subcommand is `create`.

## Phase 1 — Subcommand Routing

| Argument shape | Route to |
|---|---|
| `(empty)` | Phase 2.0 — type picker |
| `<type>` (one word matching a template slug) | Phase 2 — Create flow with `<type>` |
| `create <type> [flags]` | Phase 2 — Create flow |
| `refine <path>` | Refine flow |
| `update <path>` | Update flow |
| `template add` | Template Add flow |
| `template list` | Template List flow |
| `template remove <slug>` | Template Remove flow |
| `preset add` | Preset Add flow |
| `preset list` | Preset List flow |
| `preset remove <slug>` | Preset Remove flow |

If `<type>` doesn't match any template slug (built-in or user), list available templates and offer fuzzy match before erroring.

Recognized flags on `create`:
- `--tier lite|full` — bypass tier auto-detection
- `--preset <slug>` — bypass default preset selection

## Phase 2 — Create Flow

The same 7-step flow applies to every artifact type — built-in or user-defined.

### 2.0 — Type picker (only when invoked with no `<type>` argument)

Use `AskUserQuestion` to ask which type to create. Build options dynamically by listing all templates from:
- `templates/` in this skill dir (built-in)
- `~/.pmos/artifacts/templates/` (user)

Show source label `[built-in]` / `[user]` next to each. After selection, set `<type>` and proceed to 2.1.

### 2.1 — Resolve & validate template

1. Look up `<type>` in built-in templates first; if not found, in `~/.pmos/artifacts/templates/`. (Built-in always wins on slug — user templates use unique slugs by construction.)
2. Read `template.md` frontmatter and `eval.md`.
3. **Validate:**
   - Both files exist.
   - Frontmatter parses; required fields present: `name`, `slug`, `description`, `tiers`, `default_preset`, `files_to_read`.
   - Every section ID referenced in `eval.md` (e.g., `## §2`) exists in `template.md`.
   - If validation fails: stop, surface the specific error, do not proceed.

### 2.2 — Tier detection

If `template.md` frontmatter `tiers: [lite, full]`:
1. If `--tier <value>` flag was given, use it.
2. Otherwise auto-suggest based on signals:
   - Requirements doc richness: word count of `01_requirements*.md` if present (>1500 → suggest Full; <500 → suggest Lite).
   - User input length and tone (>200 chars with strategic terms like "OKR", "rollout", "stakeholders" → Full).
   - Default to Full when ambiguous.
3. Confirm with user via `AskUserQuestion` (preview shows the section list per tier).

If `tiers: [single]`, skip this step.

### 2.3 — Resolve feature folder

Follow `../_shared/pipeline-setup.md` Section B (feature-folder rules) with:
- `skill_name=artifact`
- `feature_arg=<value of --feature flag if any>`
- `feature_hint=<short feature name from user input or current type>`

Returned path becomes `{feature_folder}` for the rest of this run.

### 2.4 — Auto-consume upstream artifacts

For each entry in `template.md` frontmatter `files_to_read`:
- If `pattern:`, expand `{feature_folder}` and glob; read every match.
- If `source: product-context`, use the workstream content already loaded in Phase 0.
- If `source: user-args`, treat any file paths in the user's invocation as attached.

Concatenate all read content into a `gathered_context` block, tagged by source label.

### 2.5 — Gap interview

1. Filter `eval.md` items where `kind: precondition` AND the item's `tier:` includes the selected tier (or includes `single`).
2. For each precondition item, do a semantic check: does anything in `gathered_context` satisfy the item's `check`?
   - Use LLM judgment, not regex. Be generous — if the evidence is plausibly present, mark it satisfied.
3. For UNSATISFIED items only, queue the item's `gap_question`.
4. Batch queued questions ≤4 per `AskUserQuestion` call. Use multiple sequential calls if >4.
5. Append answers to `gathered_context` tagged `gap_answer:<criterion_id>`.

### 2.6 — Preset selection

1. If `--preset <slug>` flag, use it.
2. Otherwise read `template.md` frontmatter `default_preset`.
3. Confirm with the user via `AskUserQuestion` showing the 4 built-in presets + any user presets, with `default_preset` marked `(default)`.

Load the chosen preset's rendering rules and voice notes for use in 2.7.

### 2.7 — Generate draft

Generate the artifact section-by-section using:
- `template.md` section ordering and per-section guidance comments
- The selected preset's rendering rules (per section type)
- `gathered_context` (auto-read + gap answers)

Write the draft to `{feature_folder}/{slug}.md` (e.g., `prd.md`, `experiment-design.md`). Include a frontmatter block in the artifact:

```yaml
---
type: prd
tier: full
preset: narrative
generated_at: 2026-05-02
template_version: pmos-toolkit@2.10.0
sources:
  - 01_requirements_v3.md
  - workstream:product-x
---
```

Then proceed to Phase 3.

## Phase 3 — Self-Refinement Loop (max 2 iterations)

Mirrors `/wireframes` Phase 4 pattern.

### Loop iteration

1. **Dispatch reviewer subagent.**
   - Subagent type: `general-purpose`.
   - Inputs: `reviewer-prompt.md` (system instructions), the full `eval.md` for this template, and the current draft.
   - Background: false (this is a foreground call; we need findings before proceeding).
   - Subagent returns JSON of the shape defined in `reviewer-prompt.md`.

2. **Parse findings.** Each finding has `section`, `criterion_id`, `severity`, `finding`, `suggested_fix`.

3. **Auto-apply** all `high` and `medium` findings via `Edit` against the draft file. Apply the `suggested_fix` literally — the reviewer prompt requires fixes specific enough to apply directly.
4. **Log** all `low` findings to a `_residuals` accumulator (in-memory).

### Loop continuation

- If any `high` findings remained AFTER applying loop-1 (i.e., the auto-fix didn't fully resolve them — should be rare; reviewer should regenerate the section), run loop 2.
- Hard cap: **2 loops total.** No third loop, ever.

### Residual presentation

After loop 2 (or loop 1 if no high remain):

- Surface any `high` still remaining + all `medium` from loop 2 + any `low` deemed worth raising via the **Findings Presentation Protocol**:
  - Batch ≤4 findings per `AskUserQuestion` call.
  - Per finding, options: **Apply as proposed** / **Modify** / **Skip** / **Defer**.
  - Apply user-confirmed fixes via `Edit`. "Defer" appends the finding to a `## Deferred Improvements` section at the end of the artifact.

### Anti-patterns (do NOT)

- Run a 3rd loop "just in case." Diminishing returns are real; surface to user instead.
- Silently fix `low` findings without user input — log them, surface only on request or at handoff.
- Invoke the reviewer with a different prompt than `reviewer-prompt.md`. The prompt enforces the JSON contract.

## Phase 4 — Save & Confirm

1. The artifact file at `{feature_folder}/{slug}.md` already exists from Phase 2.7 and was edited in Phase 3.
2. Show the user a one-paragraph summary:
   - Artifact type + tier
   - Preset used
   - Sections written
   - Refinement-loop iterations (1 or 2) and counts: `N high resolved, M medium resolved, K low logged`
   - Residuals deferred (count + names)
3. Offer to `git add` + commit. Do NOT auto-commit. Suggested commit message:
   ```
   docs({type}): add {tier} {type} for {feature-slug}
   ```

## Phase 5 — Workstream Enrichment

If a workstream was loaded in Phase 0:

1. Scan the gathered context + the final draft for signals worth persisting to the workstream:
   - New user segments named
   - Metrics with baselines / targets
   - Strategic decisions / OKR links
   - Stakeholders / teams not previously listed
2. Surface each candidate addition via `AskUserQuestion` (Apply / Modify / Skip), batched ≤4 per call.
3. Apply approved additions to `~/.pmos/workstreams/{workstream}.md`.

If no workstream is active, skip this phase.

## Phase 6 — Capture Learnings

Read `../learnings/learnings-capture.md` (relative to this skill dir) and follow it. This phase is a **terminal gate** — the skill is not complete until learnings have been processed.

## Refine Flow (`/artifact refine <path>`)

Re-run the eval-loop judge on an existing artifact. **Internal QA only — does NOT accept new external feedback.**

1. Read the artifact at `<path>`. Parse its frontmatter to determine `type`. If frontmatter is missing or `type` cannot be inferred, ask the user via `AskUserQuestion`.
2. Resolve the template (same 2.1 logic) and load `eval.md`.
3. Ask the user: "Overwrite `<path>` or write to `<path>.refined.md`?" via `AskUserQuestion`. Default = `.refined.md` (safer).
4. Run Phase 3 refinement loop against the artifact (or its `.refined.md` copy).
5. Run Phase 4 save & confirm — point at the chosen output path.
6. Skip Phase 5 (no new workstream signals from a re-run).
7. Run Phase 6 learnings capture (terminal gate).

## Update Flow (`/artifact update <path>`)

Apply stakeholder feedback to an existing artifact. **Distinct from refine — this is a stakeholder loop, not internal QA.**

### Phase U.1 — Accept feedback input

Ask the user via `AskUserQuestion`:
- **Paste comments** — user pastes block of feedback inline.
- **File path** — user provides path to a feedback file (Notion export, email dump, .md notes).
- **Dictate** — user describes feedback conversationally; agent transcribes.

### Phase U.2 — Parse into structured items

Extract each feedback item into the shape:

```json
{
  "section": "§2 Problem & Customer",
  "type": "edit | expand | trim | question | accept | reject",
  "content": "verbatim feedback or summary"
}
```

For ambiguous items (no clear section, or unclear intent), batch clarifying questions via `AskUserQuestion` (≤4 per call).

For un-mappable items (don't fit any section), append them to a `## General Feedback` section in the artifact and continue.

### Phase U.3 — Apply via Findings Presentation Protocol

Per parsed item, batch ≤4 per `AskUserQuestion`. Options: **Apply as proposed** / **Modify** / **Skip** / **Defer**. Apply approvals via `Edit`. "Defer" appends to `## Deferred Improvements`.

### Phase U.4 — Append Comment Resolution Log

At the bottom of the artifact, append (or extend) a `## Comment Resolution Log` section with one row per resolved item:

```markdown
| Date | Reviewer | Section | Feedback | Resolution |
|---|---|---|---|---|
| 2026-05-02 | (paste) | §2 | Add competitor benchmark | Applied |
| 2026-05-02 | sarah@ | §5 | Tighten guardrails | Modified |
```

### Phase U.5 — Optional re-run of refinement loop

Ask: "Run the eval loop on the updated artifact?" via `AskUserQuestion`. If yes, run Phase 3.

### Phase U.6 — Save, then Phase 6 learnings capture (terminal gate)

Same as Phase 4 + Phase 6 from the create flow.

## Template Management

### `/artifact template add` — research-grounded authoring

`--quick` flag drops to scaffold-only mode (skip phases T.2 and T.3, jump to T.4 with empty proposed sections).

#### T.1 — Intake

Ask via `AskUserQuestion` (one batch ≤4):
- Template **name** + **slug** (slug must not collide with built-in templates: `prd`, `experiment-design`, `eng-design`, `discovery`. Validate at capture time and reject collisions before continuing.)
- **Purpose / when used** (1-2 sentences)
- **Audience**
- **Examples** — links or pasted reference docs (optional)
- **Inspirations / frameworks** to ground in (optional)

#### T.2 — Research subagent (skip if `--quick` or user opts out via AskUserQuestion)

Dispatch a `general-purpose` subagent. Foreground call. Prompt:

```
Research best practices for the artifact class "<name>" (purpose: <purpose>; inspirations: <list>).

Survey canonical sources via WebSearch and WebFetch. Cite each source.

Return a proposal:
- Sections (8-15) with one-line purpose each
- Per-section eval items with kind (precondition|judgment), check, severity (high|medium|low), and gap_question for preconditions
- Frontmatter files_to_read suggestions
- A recommended default_preset (concise|tabular|narrative|executive)
- Cited source links

Do NOT write any files. Output a single markdown report ~600-900 words.
```

#### T.3 — Section-by-section alignment

For each proposed section in the research report, ask via `AskUserQuestion` with options:
- **Approve** (preview shows section purpose + eval items)
- **Tweak** (free-text follow-up)
- **Discuss** (free-text follow-up)
- **Drop**

Capture decisions per section. Track which eval items survived.

#### T.4 — Frontmatter authoring

Confirm via `AskUserQuestion` (one batch):
- `tiers`: `[single]` / `[lite, full]`
- `default_preset`: pick from 4 built-in (or "user-defined" if applicable)
- `files_to_read`: confirm list

#### T.5 — Generate the 2 files

Write to `~/.pmos/artifacts/templates/<slug>/`:
- `template.md` — frontmatter + section markdown with embedded guidance per the alignment decisions.
- `eval.md` — per-criterion items per the alignment decisions.

Validate on write:
- Both files present.
- Frontmatter parses; required fields present.
- Every `## §N` in template.md has a matching `## §N` in eval.md.
- If validation fails, surface the specific error and offer to retry or abort.

#### T.6 — Optional dry-run

Ask: "Run a dry-run by creating one artifact with this template?" via `AskUserQuestion`. If yes, prompt for a feature folder (or use the most recent), then execute Phase 2 with the new template. User can iterate on sections/evals based on what the dry-run produces.

### `/artifact template list`

Read both built-in (`templates/`) and user (`~/.pmos/artifacts/templates/`) directories. Render a table:

```
| Slug              | Name                      | Tiers       | Source     |
|-------------------|---------------------------|-------------|------------|
| prd               | PRD                       | lite, full  | built-in   |
| experiment-design | Experiment Design Doc     | lite, full  | built-in   |
| eng-design        | Engineering Design Doc    | lite, full  | built-in   |
| discovery         | Discovery Doc             | single      | built-in   |
| okr-doc           | OKR Document              | single      | user       |
```

Read-only.

### `/artifact template remove <slug>`

1. If `<slug>` is a built-in: refuse with message "Built-in templates cannot be removed."
2. If `<slug>` is a user template: confirm via `AskUserQuestion` (Yes/No), then `rm -rf ~/.pmos/artifacts/templates/<slug>/`. Show the path that was removed.
3. If `<slug>` doesn't exist: list available user templates.

## Preset Management

### `/artifact preset add`

#### P.1 — Intake (one AskUserQuestion batch)

- **Slug** (validate against built-in: `concise`, `tabular`, `narrative`, `executive` — reject collisions)
- **Description** (1-line)
- **Inspiration** (existing preset to fork? other doc style?)

#### P.2 — Rendering rules per section type

Walk through 4 section types, asking the user for the rule per type via `AskUserQuestion` (4 questions batched in 2 calls of 2):

1. **Lists of objects** (metrics, variants, scope items, stories) — table / nested bullets / prose?
2. **Narrative sections** (Problem, User Journey, FAQ) — prose / bulleted / mixed?
3. **Procedural lists** (rollout phases, journey steps) — numbered / unnumbered / table?
4. **Diagrams** — text/ASCII / Mermaid / both / none?

#### P.3 — Voice and tone

Ask: 3-5 voice rules (active vs passive, sentence length cap, hedging, etc.). Free-text or AskUserQuestion preset list.

#### P.4 — Generate file

Write to `~/.pmos/artifacts/presets/<slug>.md`:

```markdown
---
name: <slug>
description: <line>
---

# Rendering rules

<rules from P.2>

# Voice

<rules from P.3>
```

### `/artifact preset list`

Render built-in + user presets in a table with `Slug | Description | Source`.

### `/artifact preset remove <slug>`

Symmetric to `template remove`. Reject if built-in.
