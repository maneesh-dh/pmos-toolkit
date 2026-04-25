# /mytasks + /people Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship two new skills in `pmos-toolkit` — `/mytasks` (personal task tracker) and `/people` (shared person directory) — plus a `_shared/interactive-prompts.md` reference and a one-line refactor of `/backlog` Phase 5 to use it.

**Architecture:** Markdown-only skills. Storage at `~/.pmos/tasks/` (one file per task) and `~/.pmos/people/` (one file per person), each with a regenerable `INDEX.md` cache. `/mytasks` reads `/people` (via the `find` lookup) but never writes to it except through explicit user-gated entry points. Both skills share a single interactivity protocol via `_shared/interactive-prompts.md`. Hard isolation from `/backlog` — no cross-skill code paths.

**Tech Stack:** Pure markdown / agent prompts. No executable code. "Tests" are scenario fixtures: a fixture directory + a `scenarios.md` describing input commands and expected agent behavior, verified manually during skill development. Same approach as existing `pmos-toolkit` skills.

**Spec:** [`docs/superpowers/specs/2026-04-25-mytasks-skill-design.md`](../specs/2026-04-25-mytasks-skill-design.md)

---

## File Structure

### New files (created in this plan)

```
plugins/pmos-toolkit/skills/
├── _shared/
│   └── interactive-prompts.md           # NEW shared interactivity reference
├── mytasks/                             # NEW skill
│   ├── SKILL.md                         # Frontmatter + Phase 0 router + per-subcommand phases
│   ├── schema.md                        # Reference: enums, frontmatter, body sections, INDEX.md format
│   ├── inference-heuristics.md          # Reference: keyword + date parsing rules for quick-capture
│   └── tests/
│       ├── scenarios.md                 # All scenario specs in one file (fixture-name-keyed)
│       └── fixtures/
│           ├── empty-tasks/             # No ~/.pmos/tasks/ directory yet
│           ├── with-tasks/              # Several tasks across importance buckets
│           ├── with-checkins/           # Tasks with check-in cadence and history
│           └── with-archive/            # Tasks ready for archive
└── people/                              # NEW skill
    ├── SKILL.md
    ├── schema.md                        # Reference: enums, frontmatter, INDEX.md format
    ├── lookup.md                        # Reference: fuzzy-match algorithm spec
    └── tests/
        ├── scenarios.md
        └── fixtures/
            ├── empty-people/            # No ~/.pmos/people/ directory yet
            ├── with-people/             # Several records (Sarah Chen, Mark Davis, Sarah Patel for collision)
            └── with-aliases/            # Records with rich aliases for fuzzy-match coverage
```

### Modifications (small edits to existing files)

- `plugins/pmos-toolkit/skills/backlog/SKILL.md` — Phase 5 wording change + reference addition (Task 13)
- `plugins/pmos-toolkit/.claude-plugin/plugin.json` — version bump to `1.7.0` (Task 14)
- `plugins/pmos-toolkit/.codex-plugin/plugin.json` — mirror version bump to `1.7.0` (Task 14)

---

## Notes for the Implementer

**These are markdown-only skills.** TDD is adapted: for each behavior, first write the fixture + `scenarios.md` entry that describes the expected agent behavior, then write the SKILL.md prose that produces that behavior, then walk through the scenario manually (read the SKILL.md as it stands and confirm the prompt is unambiguous enough to produce the expected output).

**The two skills are tightly related but ship as independent units.** Implement `_shared/` first (Task 1), then `/people` end-to-end (Tasks 2-5), then `/mytasks` end-to-end (Tasks 6-12), then the `/backlog` refactor (Task 13), then plugin wiring (Task 14). Each task produces a coherent commit.

**Atomic-ish writes.** When the skill mutates files (item file + `INDEX.md`), write the item file first, then regenerate `INDEX.md`. If `INDEX.md` regeneration fails, the item file is still canonical and the user can run `<skill> rebuild-index` to recover. Never write a partial item file.

**Hard isolation between `/mytasks` and `/backlog`.** No code path in `/mytasks` may read or write `<repo>/backlog/`. Verified at the end (Task 14, success criterion #12).

**Shared interactivity via `_shared/`.** All interactive flows (rich-capture, refine, unknown-person prompt) reference `_shared/interactive-prompts.md` rather than duplicating the protocol. The `/backlog` refactor (Task 13) brings `/backlog refine` onto the same shared reference.

**Date handling is local.** All dates are local-timezone ISO `YYYY-MM-DD`. "Today" is the system's local today. Day-of-week parsing follows §4.2 of the spec ("Friday" on a Friday = next Friday).

**Person handle derivation collision-resolution.** `firstname-lastinitial` (e.g., `sarah-c`) → if taken, `firstname-lastname` (`sarah-chen`) → if taken, `firstname-N` numeric suffix (`sarah-2`). Names without a last name use just `firstname`, then `firstname-N` on collision.

---

## Task 1: Shared interactivity reference

**Files:**
- Create: `plugins/pmos-toolkit/skills/_shared/interactive-prompts.md`

This is the prerequisite for both new skills and the `/backlog` refactor. Implement first.

- [ ] **Step 1: Create the directory and write the reference doc**

Create `plugins/pmos-toolkit/skills/_shared/interactive-prompts.md` with this exact content:

````markdown
# Interactive Prompts — Shared Protocol

Single source of truth for the interactive prompting protocol used by `pmos-toolkit` skills. Skills that collect multi-field input from the user (rich-capture, refine, multi-option choices) MUST follow this protocol.

## Two-path protocol

### Primary: `AskUserQuestion` (Claude Code)

When `AskUserQuestion` is available, use it for **one structured prompt per field**. Each prompt is a single tool call.

- **Enum fields:** render as multi-choice with the enum values as options. The current value (when refining) is the default option.
- **Free-string fields:** render as a text input. If a current value exists (refine flow), show it as the default; pressing accept keeps it.
- **Date fields:** text input with format hint `YYYY-MM-DD or "Friday", "tomorrow", "in 3 days"`. Parse the response using the same natural-language rules as quick-capture (see consumer skill's `inference-heuristics.md`).
- **List fields (e.g., `labels`, `aliases`):** text input with format hint `comma-separated`. Parse on `,`, trim whitespace, drop empties.
- **Multi-option choices** (e.g., the unknown-person three-option flow): single multi-choice prompt with the labeled options.

Best UX, single tool-call per field, lowest user friction.

### Fallback: numbered-response, one question at a time

When `AskUserQuestion` is unavailable (Copilot CLI, Codex, Gemini CLI, plain CLI), ask **one question per turn** as plain text with numbered choices for enum fields. Wait for the user to reply before asking the next question.

Example:
```
Importance? (current: neutral)
  1) leverage
  2) neutral  [default]
  3) overhead
Reply with a number, or press <enter> to keep the default.
```

- **Enum fields:** numbered list with `[default]` annotation on the current value. Accept either the number or the literal value.
- **Free-string fields:** plain text prompt with `(current: <value>)` annotation. `<enter>` keeps the current value.
- **Date fields:** plain text prompt with format hint `(YYYY-MM-DD or "Friday", "tomorrow", "in 3 days")`. Same natural-language parsing rules apply.
- **List fields:** plain text prompt with format hint `(comma-separated)`. `<enter>` keeps current; `clear` empties the list.
- **Skip:** the literal `skip` (or option `0` if shown) leaves the field at its current value (refine) or empty (add).

Same field order, same defaults, same validation as the primary path.

## Why per-field, not bulk-numbered-list

A single bulk numbered list (asked all at once) has known problems:
- Later answers can depend on earlier ones (e.g., `checkin` cadence is moot if no `due` date is set — the skill can skip it).
- Long forms produce parsing errors when one field is malformed.
- The user can't see the result of an answer before the next question.
- `<enter>` skip semantics don't translate cleanly to a single bulk response.

Per-field, one-at-a-time fixes all of these at the cost of more conversational turns. For interactive flows (rich-capture, refine), turn count is acceptable; the user is already in interactive mode.

## Validation

Skills MUST validate enum responses against their declared enum values BEFORE writing. On invalid input:
- Primary path: `AskUserQuestion` enforces choice; no validation needed at the consumer layer.
- Fallback path: re-ask the same question with the message `Unknown value '{value}'. Allowed: {comma-separated list}.`

Free-string fields are not validated (any non-empty string is accepted; empty string clears the field on refine, leaves blank on add).

## Defaults and skip semantics

- **Add flows** (no current value): each prompt may have a documented default (e.g., `importance` defaults to `neutral`). `<enter>` accepts the default; `skip` leaves the field absent from frontmatter.
- **Refine flows** (existing values): each prompt shows the current value as the default. `<enter>` keeps it; explicit new value replaces it; `clear` (for list fields) empties it.

Optional fields that are skipped MUST be written as bare keys with no value (e.g., `due:` not `due: null`) so the file shape is consistent.

## Consumers

This reference is the canonical source for:
- `/mytasks add` (rich capture)
- `/mytasks refine <id>`
- `/mytasks` unknown-person three-option prompt (during rich capture)
- `/people add` (proactive create)
- `/people refine <handle>`
- `/backlog refine <id>` (after Task 13 refactor)

Future skills with interactive flows SHOULD reference this doc rather than re-specifying the protocol.
````

- [ ] **Step 2: Verify the file was written**

Run: `cat plugins/pmos-toolkit/skills/_shared/interactive-prompts.md | head -5`
Expected: prints `# Interactive Prompts — Shared Protocol` and the next 4 lines.

- [ ] **Step 3: Commit**

```bash
git add plugins/pmos-toolkit/skills/_shared/interactive-prompts.md
git commit -m "feat(pmos-toolkit): add shared interactive-prompts reference"
```

---

## Task 2: `/people` skill scaffold + schema + default list view + rebuild-index

**Files:**
- Create: `plugins/pmos-toolkit/skills/people/SKILL.md`
- Create: `plugins/pmos-toolkit/skills/people/schema.md`
- Create: `plugins/pmos-toolkit/skills/people/lookup.md`
- Create: `plugins/pmos-toolkit/skills/people/tests/scenarios.md`
- Create: `plugins/pmos-toolkit/skills/people/tests/fixtures/empty-people/.gitkeep`
- Create: `plugins/pmos-toolkit/skills/people/tests/fixtures/with-people/INDEX.md`
- Create: `plugins/pmos-toolkit/skills/people/tests/fixtures/with-people/sarah-chen.md`
- Create: `plugins/pmos-toolkit/skills/people/tests/fixtures/with-people/mark-davis.md`
- Create: `plugins/pmos-toolkit/skills/people/tests/fixtures/with-people/sarah-patel.md`

This task ships the schema doc, scaffold, the default list view (renders INDEX.md), and the rebuild-index logic (needed for any write op to keep INDEX fresh).

- [ ] **Step 1: Write the schema reference**

Create `plugins/pmos-toolkit/skills/people/schema.md`:

````markdown
# /people Record Schema

Every person record is a markdown file at `~/.pmos/people/{handle}.md`.

## Filename

- `handle`: kebab-case, unique key, used in cross-skill references. Derived from the person's name on create (see `lookup.md` for derivation rules).
- No `.md`-less variants. The file extension is required.

## Frontmatter

```yaml
---
handle: sarah-chen
name: Sarah Chen
designation: VP Engineering         # optional — formal title
role: Eng Manager                   # optional — informal day-to-day role
working_relationship: peer          # optional enum
team: platform                      # optional
email: sarah@acme.com               # optional
workstreams: [platform-q3]          # optional list of workstream slugs
aliases: [sarah, schen, sc]         # optional fuzzy-match seeds
created: 2026-04-25
updated: 2026-04-25
---
```

### Enum values (the skill MUST validate against these and never invent new ones)

| Field | Allowed values |
|---|---|
| `working_relationship` | `boss`, `direct-report`, `peer`, `team-member`, `stakeholder`, `external`, `other` |

### Defaults on reactive create (called from `/mytasks` capture)

- `name`: from the prompt that disambiguated the unknown person.
- `handle`: auto-derived per `lookup.md`.
- `aliases`: seeded with the original token from the task (e.g., `[sarah]`).
- `created`, `updated`: today.
- All other fields: absent from frontmatter (bare keys not written).

### Defaults on proactive create (`/people add`)

- `name`: from the command argument or first prompt.
- `handle`: auto-derived per `lookup.md`.
- All other fields: prompted via `_shared/interactive-prompts.md`. Each skippable.
- `created`, `updated`: today.

## Body

```markdown
## Notes
Free-form. Context, prefs, history.
```

The `## Notes` section is optional. The skill never auto-writes to the body; users edit it freely.

## INDEX.md format

`~/.pmos/people/INDEX.md` is regenerable, never the source of truth. Shape:

```markdown
# People

Last regenerated: 2026-04-25

| handle | name | designation | role | working_relationship | team | email |
|--------|------|-------------|------|----------------------|------|-------|
| mark-davis | Mark Davis | Director of Product | PM Lead | peer | product | mark@acme.com |
| sarah-chen | Sarah Chen | VP Engineering | Eng Manager | peer | platform | sarah@acme.com |
| sarah-patel | Sarah Patel | | Designer | team-member | design | |
```

Sorted by `name` ascending. Empty optional fields render as empty cells (not `null` or dashes). Always include `Last regenerated: {today ISO date}` after the title.
````

- [ ] **Step 2: Write the lookup reference (fuzzy-match algorithm + handle derivation)**

Create `plugins/pmos-toolkit/skills/people/lookup.md`:

````markdown
# /people Lookup — Fuzzy Match + Handle Derivation

## Fuzzy-match algorithm (`/people find <text>`)

Used by `/mytasks` quick-capture and rich-capture, and by users directly via `/people find <text>`.

Match priority — return on first hit; ties resolved by `updated:` desc:

1. **Exact handle** match (case-insensitive, against `handle:`).
2. **Exact alias** match (case-insensitive, against any entry in `aliases:`).
3. **Exact name** match (case-insensitive, against `name:`).
4. **Substring match** on handle / name / aliases (case-insensitive). Handles 80% of "I typed half the name" queries.
5. **Initials match** — input length ≤ 3, all chars are letters → match against initials of `name:` (e.g., `sc` → `Sarah Chen`, `jpd` → `Jane Polly Doe`).

### Returns

- **0 matches:** empty list.
- **1 match:** single result.
- **N matches:** ranked list (priority tier first, then `updated:` desc within a tier).

### Caller behavior

The lookup is read-only. Callers decide what to do with multiple matches:

- **`/mytasks` quick-capture:** skips and flags as unresolved (never blocks).
- **`/mytasks` rich-capture (people prompt):** prompts the user to disambiguate via `_shared/interactive-prompts.md` multi-option flow.
- **`/people show <text>`:** if N matches, render the ranked list and ask the user to invoke `/people show <handle>` with the exact handle.
- **`/people set <text> ...` / `/people refine <text>`:** if N matches, refuse with the ranked list; the user must pick a handle. (Disambiguating writes is essential — otherwise edits go to the wrong record.)

## Handle derivation (used on every create)

Given a `name` (e.g., `Sarah Chen`):

1. Tokenize the name on whitespace; lowercase each token; drop tokens that are pure punctuation.
2. **Single-token name** (e.g., `Sarah`):
   - Try `sarah`.
   - On collision: `sarah-2`, `sarah-3`, … until free.
3. **Multi-token name** (e.g., `Sarah Chen`):
   - Try `firstname-lastinitial` (`sarah-c`).
   - On collision: try `firstname-lastname` (`sarah-chen`).
   - On further collision: try `firstname-lastname-N` numeric suffix.
4. Always lowercase ASCII; replace non-alphanumeric runs with `-`; trim leading/trailing `-`.

A "collision" means a file with that handle already exists at `~/.pmos/people/{handle}.md`.

The handle, once written, is immutable. Renaming a person updates `name:` only; `handle:` stays. To change a handle, the user creates a new record and migrates references manually (rare; not a v1 feature).
````

- [ ] **Step 3: Write the SKILL.md scaffold (frontmatter + Phase 0 router + Phase 1 default list + Phase 7 rebuild-index)**

Create `plugins/pmos-toolkit/skills/people/SKILL.md`:

````markdown
---
name: people
description: Shared person/contact directory for the pmos-toolkit. Stores handle, name, designation, role, working relationship, team, email, workstreams, aliases at ~/.pmos/people/. Consumed by /mytasks (and future people-aware skills). Use when the user says "add a person", "find someone", "who is X", "list people", or "/people".
user-invocable: true
argument-hint: "[ | add <name> | list [filters] | show <handle-or-name> | find <text> | set <handle> <field>=<value> | refine <handle> | rebuild-index]"
---

# People

A shared person/contact directory. Toolkit-wide entity store at `~/.pmos/people/`. Consumed by `/mytasks` (and future people-aware skills — 1:1 notes, meeting prep, stakeholder tracking).

**Announce at start:** "Using the people skill to {list|add|find|show|...}."

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:
- **No `AskUserQuestion`:** follow `_shared/interactive-prompts.md` fallback path — one question at a time as plain text with numbered responses.
- **No subagents:** sequential single-agent operation.

## References

- `schema.md` — record file shape, enum values, `INDEX.md` format
- `lookup.md` — fuzzy-match algorithm, handle derivation rules
- `_shared/interactive-prompts.md` — interactive prompting protocol

---

## Phase 0: Subcommand Routing

Parse the user's argument to determine the subcommand.

| Argument shape | Subcommand |
|---|---|
| empty | Phase 1 (show INDEX.md) |
| `add <name>` | Phase 3 (proactive create — interactive) |
| `list [flags]` | Phase 5 (filtered list) |
| `show <handle-or-name>` | Phase 4 (render record) |
| `find <text>` | Phase 2 (fuzzy-match lookup) |
| `set <handle> <field>=<value>` | Phase 6 (single-field edit) |
| `refine <handle>` | Phase 7 (interactive multi-field refine) |
| `rebuild-index` | Phase 8 (regenerate INDEX.md) |

Unknown verbs error: `Unknown subcommand '{verb}'. Run /people for the default list, or see argument hint for valid forms.`

---

## Phase 1: Show INDEX

Triggered by `/people` with no arguments.

### Step 1: Resolve `~/.pmos/people/`

If `~/.pmos/people/INDEX.md` does not exist (or `~/.pmos/people/` is missing entirely), output:

`No people yet. Add a person with /people add <name>.`

Then exit.

### Step 2: Validate freshness

Compare `INDEX.md`'s `Last regenerated:` date against the most recent mtime of any `~/.pmos/people/*.md` (excluding `INDEX.md` itself). If any record is more recent, regenerate INDEX.md (apply Phase 8) before rendering.

### Step 3: Render

Output the contents of `~/.pmos/people/INDEX.md` to the user.

---

## Phase 8: Rebuild Index

Triggered by `/people rebuild-index`. Also invoked internally by Phases 3, 6, 7 after any write.

### Step 1: Read records

Glob `~/.pmos/people/*.md` (excluding `INDEX.md`). For each, parse frontmatter. Skip files with malformed frontmatter (emit a one-line warning per skip; do not abort).

### Step 2: Sort

Sort by `name` ascending (case-insensitive).

### Step 3: Write INDEX.md

Overwrite `~/.pmos/people/INDEX.md` with the format defined in `schema.md` (### INDEX.md format section):

```markdown
# People

Last regenerated: {today ISO date}

| handle | name | designation | role | working_relationship | team | email |
|--------|------|-------------|------|----------------------|------|-------|
| {handle} | {name} | {designation or empty} | {role or empty} | {working_relationship or empty} | {team or empty} | {email or empty} |
```

Empty optional fields render as empty cells (no `null`, no dashes).

### Step 4: Report

If invoked directly (Phase 8 entered as `rebuild-index`): `Regenerated INDEX.md: {count} people.`
If invoked from another phase: silent on success, warn on failure.

---

(Phases 2, 3, 4, 5, 6, 7 are added in subsequent tasks.)
````

- [ ] **Step 4: Write the test fixtures**

Create the empty-people fixture (an empty directory marker):

```bash
mkdir -p plugins/pmos-toolkit/skills/people/tests/fixtures/empty-people
touch plugins/pmos-toolkit/skills/people/tests/fixtures/empty-people/.gitkeep
```

Create `plugins/pmos-toolkit/skills/people/tests/fixtures/with-people/sarah-chen.md`:

```markdown
---
handle: sarah-chen
name: Sarah Chen
designation: VP Engineering
role: Eng Manager
working_relationship: peer
team: platform
email: sarah@acme.com
workstreams: [platform-q3]
aliases: [sarah, schen, sc]
created: 2026-04-20
updated: 2026-04-22
---

## Notes
Prefers Slack DMs for sync requests.
```

Create `plugins/pmos-toolkit/skills/people/tests/fixtures/with-people/mark-davis.md`:

```markdown
---
handle: mark-davis
name: Mark Davis
designation: Director of Product
role: PM Lead
working_relationship: peer
team: product
email: mark@acme.com
workstreams: [platform-q3]
aliases: [mark, mdavis]
created: 2026-04-21
updated: 2026-04-21
---
```

Create `plugins/pmos-toolkit/skills/people/tests/fixtures/with-people/sarah-patel.md` (deliberate name collision with Sarah Chen for fuzzy-match testing):

```markdown
---
handle: sarah-patel
name: Sarah Patel
role: Designer
working_relationship: team-member
team: design
aliases: [sp]
created: 2026-04-22
updated: 2026-04-22
---
```

Create `plugins/pmos-toolkit/skills/people/tests/fixtures/with-people/INDEX.md`:

```markdown
# People

Last regenerated: 2026-04-22

| handle | name | designation | role | working_relationship | team | email |
|--------|------|-------------|------|----------------------|------|-------|
| mark-davis | Mark Davis | Director of Product | PM Lead | peer | product | mark@acme.com |
| sarah-chen | Sarah Chen | VP Engineering | Eng Manager | peer | platform | sarah@acme.com |
| sarah-patel | Sarah Patel |  | Designer | team-member | design |  |
```

- [ ] **Step 5: Write the scenario specs**

Create `plugins/pmos-toolkit/skills/people/tests/scenarios.md`:

````markdown
# Scenario Fixtures

Each section below describes an expected agent behavior given the matching fixture under `tests/fixtures/`. To verify, the implementer reads the relevant SKILL.md phases and walks through each scenario manually.

## Fixture: empty-people

A directory with no records (or a missing `~/.pmos/people/` directory).

### Scenario: `/people` (no args, empty fixture)

Expected:
- Output: `No people yet. Add a person with /people add <name>.`
- No files created.

### Scenario: `/people rebuild-index` (empty fixture)

Expected:
- Glob returns 0 files.
- Write `~/.pmos/people/INDEX.md` with header and empty table (column row only, no data rows).
- Output: `Regenerated INDEX.md: 0 people.`

## Fixture: with-people

Three records: `sarah-chen`, `mark-davis`, `sarah-patel`.

### Scenario: `/people` (no args, with-people fixture)

Expected:
- Read INDEX.md (skip regeneration since INDEX is fresh — `Last regenerated: 2026-04-22` matches the most recent record `updated:`).
- Render the INDEX.md table verbatim.

### Scenario: `/people` (no args, with-people fixture, after manual edit to sarah-chen.md without INDEX update)

Expected:
- Detect freshness drift (sarah-chen.md mtime newer than INDEX.md `Last regenerated:`).
- Regenerate INDEX.md (apply Phase 8).
- Render the regenerated INDEX.md.

### Scenario: `/people rebuild-index` (with-people fixture)

Expected:
- Read all 3 records.
- Sort by name ascending: Mark Davis, Sarah Chen, Sarah Patel.
- Write INDEX.md.
- Output: `Regenerated INDEX.md: 3 people.`
````

- [ ] **Step 6: Walk through the scenarios manually**

For each scenario in `tests/scenarios.md`, read the relevant SKILL.md phase and confirm the prose unambiguously produces the expected output. If a scenario reveals ambiguity, fix the SKILL.md prose before commit.

Specifically check:
- Phase 1 Step 1 fires correctly when the directory is missing.
- Phase 1 Step 2 freshness check correctly compares dates.
- Phase 8 Step 3 INDEX.md output exactly matches the format in `schema.md`.
- Phase 8 handles 0 records (empty table).

- [ ] **Step 7: Commit**

```bash
git add plugins/pmos-toolkit/skills/people/
git commit -m "feat(pmos-toolkit/people): scaffold + schema + default list + rebuild-index"
```

---

## Task 3: `/people` Phase 2 — fuzzy-match `find`

**Files:**
- Modify: `plugins/pmos-toolkit/skills/people/SKILL.md` (add Phase 2 section)
- Modify: `plugins/pmos-toolkit/skills/people/tests/scenarios.md` (add `find` scenarios)
- Modify: `plugins/pmos-toolkit/skills/people/tests/fixtures/with-people/sarah-chen.md` (add `aliases` if missing — already present from Task 2)

`find` is the API used by `/mytasks` capture. Implement it before `/mytasks` so `/mytasks` can integrate.

- [ ] **Step 1: Add `find` scenarios to scenarios.md**

Append to `plugins/pmos-toolkit/skills/people/tests/scenarios.md`:

````markdown

### Scenario: `/people find sarah-chen` (with-people fixture)

Expected (exact handle match, priority 1):
- Return single result: `sarah-chen`.
- Render: `1 match: sarah-chen (Sarah Chen)`.

### Scenario: `/people find sc` (with-people fixture)

Expected (alias match for sarah-chen, priority 2):
- Single result: `sarah-chen`.
- Render: `1 match: sarah-chen (Sarah Chen) — matched alias 'sc'`.

### Scenario: `/people find Sarah Chen` (with-people fixture)

Expected (exact name match, priority 3):
- Single result: `sarah-chen`.

### Scenario: `/people find sarah` (with-people fixture)

Expected (substring match on name; both Sarah Chen and Sarah Patel match):
- Two results, ranked: tier 4 (substring), within tier sorted by `updated` desc.
- sarah-patel (updated 2026-04-22) and sarah-chen (updated 2026-04-22) — tie on date, deterministic by handle alphabetical (sarah-chen first).
- Render:
  ```
  2 matches:
    sarah-chen (Sarah Chen) — substring match
    sarah-patel (Sarah Patel) — substring match
  ```

### Scenario: `/people find SP` (with-people fixture)

Expected (initials match for Sarah Patel, priority 5; input length 2, all letters):
- Single result: `sarah-patel`.
- Render: `1 match: sarah-patel (Sarah Patel) — initials match`.

### Scenario: `/people find xyz` (with-people fixture)

Expected (no match):
- Render: `No matches for 'xyz'.`
````

- [ ] **Step 2: Add Phase 2 (Fuzzy-Match Find) to SKILL.md**

Edit `plugins/pmos-toolkit/skills/people/SKILL.md`. Find the line `(Phases 2, 3, 4, 5, 6, 7 are added in subsequent tasks.)` and replace with the Phase 2 content (then re-add the marker for the remaining phases):

````markdown
## Phase 2: Fuzzy-Match Find

Triggered by `/people find <text>`. Read-only lookup. Used by `/mytasks` capture and by users directly.

Algorithm and tier definitions: see `lookup.md`.

### Step 1: Resolve and read

If `~/.pmos/people/` does not exist or contains no records, output: `No people in directory. Add one with /people add <name>.` Exit.

Otherwise, glob `~/.pmos/people/*.md` (excluding `INDEX.md`). Parse frontmatter for each. Skip malformed files with a one-line warning.

### Step 2: Match in priority order

Apply the 5-tier match algorithm from `lookup.md`. Stop at the first tier that produces matches; do not collect from lower tiers if a higher tier hit.

For each record, evaluate match tiers in order:
1. Exact handle (case-insensitive on `handle:`).
2. Exact alias (case-insensitive on any entry in `aliases:`).
3. Exact name (case-insensitive on `name:`).
4. Substring on handle / name / aliases.
5. Initials of `name:` (only if input length ≤ 3 AND input is all letters).

Within the matching tier, sort by `updated:` desc; break ties alphabetically by handle.

### Step 3: Render

- **0 matches:** `No matches for '{input}'.`
- **1 match:** `1 match: {handle} ({name}){match-note}.`
  - `{match-note}` is empty for tier 1, ` — matched alias '{alias}'` for tier 2, omitted for tier 3, ` — substring match` for tier 4, ` — initials match` for tier 5.
- **N matches:**
  ```
  {N} matches:
    {handle} ({name}){match-note}
    ...
  ```

### Step 4: Caller integration

When `find` is invoked programmatically by `/mytasks` (not a user-typed command), the caller reads the rendered output and parses out handles. The output format above is contract — do not change without updating callers.
````

Then add back the marker line:

```markdown
(Phases 3, 4, 5, 6, 7 are added in subsequent tasks.)
```

- [ ] **Step 3: Walk through find scenarios manually**

For each `find` scenario, read Phase 2 + `lookup.md` and confirm the algorithm produces the expected ranked output. Pay attention to:
- Tier 4 substring matching `sarah` against both Sarah Chen and Sarah Patel (both records have `sarah` in `aliases:`, so tier 2 fires first — actually, `sarah` is in `sarah-chen`'s aliases but NOT `sarah-patel`'s; verify against fixture). If tier 2 fires for sarah-chen alone, the scenario expectation needs revisiting.

**Critical fixture check:** the `find sarah` scenario above expects substring match (tier 4) returning both. But `sarah-chen` has alias `sarah`, so tier 2 fires first and returns ONLY `sarah-chen`. To make the substring scenario meaningful, either:
- (a) Update the scenario to expect `1 match: sarah-chen (Sarah Chen) — matched alias 'sarah'` (tier 2 wins), OR
- (b) Update the fixture to remove `sarah` from sarah-chen's aliases.

Pick (a) — it's the more honest test of the priority algorithm. Edit `tests/scenarios.md` to fix the `find sarah` scenario:

````markdown
### Scenario: `/people find sarah` (with-people fixture)

Expected (alias match for sarah-chen, priority 2 — beats substring tier):
- Single result: `sarah-chen` (alias `sarah` matches before substring tier fires).
- Render: `1 match: sarah-chen (Sarah Chen) — matched alias 'sarah'`.

### Scenario: `/people find sara` (with-people fixture)

Expected (substring match — `sara` is not an exact alias, so tier 4 fires):
- Two results, both Sarah-named records:
  - sarah-chen (updated 2026-04-22)
  - sarah-patel (updated 2026-04-22)
- Tie on date; alphabetical by handle.
- Render:
  ```
  2 matches:
    sarah-chen (Sarah Chen) — substring match
    sarah-patel (Sarah Patel) — substring match
  ```
````

- [ ] **Step 4: Commit**

```bash
git add plugins/pmos-toolkit/skills/people/SKILL.md plugins/pmos-toolkit/skills/people/tests/scenarios.md
git commit -m "feat(pmos-toolkit/people): add fuzzy-match find (Phase 2)"
```

---

## Task 4: `/people` Phase 3 — proactive `add` (interactive)

**Files:**
- Modify: `plugins/pmos-toolkit/skills/people/SKILL.md` (add Phase 3)
- Modify: `plugins/pmos-toolkit/skills/people/tests/scenarios.md` (add `add` scenarios)

- [ ] **Step 1: Add `add` scenarios to scenarios.md**

Append:

````markdown

## Fixture: empty-people (continued)

### Scenario: `/people add Sarah Chen` (empty fixture, no collisions)

Expected interactive flow (uses AskUserQuestion if available, else fallback per `_shared/interactive-prompts.md`):
1. Derive handle: `sarah-c` (single-token last name initial; no collision because empty fixture).
2. Prompt for `designation` (free string, skippable). User responds: `VP Engineering`.
3. Prompt for `role` (free string, skippable). User: `Eng Manager`.
4. Prompt for `working_relationship` (enum choice). User picks: `peer`.
5. Prompt for `team` (free string, skippable). User: `platform`.
6. Prompt for `email` (free string, skippable). User: `sarah@acme.com`.
7. Prompt for `workstreams` (comma-separated list, skippable). User: `platform-q3`.
8. Prompt for `aliases` (comma-separated list, skippable). User: `sarah, schen, sc`.
9. Write `~/.pmos/people/sarah-c.md` with all collected fields, `created`/`updated` = today.
10. Apply Phase 8 (regenerate INDEX.md).
11. Output: `Added sarah-c (Sarah Chen).`

### Scenario: `/people add Sarah Chen` (with-people fixture, sarah-c.md does NOT exist; sarah-chen.md DOES exist)

Expected:
- Derive handle: try `sarah-c` — not taken, use it. Write `~/.pmos/people/sarah-c.md`.
- All other steps as above.
- Output: `Added sarah-c (Sarah Chen).`

(This is a deliberate test of derivation collision handling: even though "sarah-chen" already exists as a different person's handle, the new "Sarah Chen" gets `sarah-c` because that's the first-tier derivation. The lookup algorithm distinguishes them by exact handle / aliases.)

### Scenario: `/people add Sarah` (with-people fixture, single-token name)

Expected:
- Derive handle: try `sarah` — not taken (no fixture record uses bare `sarah`), use it.
- Output: `Added sarah (Sarah).`
````

- [ ] **Step 2: Add Phase 3 to SKILL.md**

Replace the marker line `(Phases 3, 4, 5, 6, 7 are added in subsequent tasks.)` with Phase 3 content + remaining marker:

````markdown
## Phase 3: Proactive Create (`add`)

Triggered by `/people add <name>`. Interactive — collects rich attributes upfront.

### Step 1: Derive handle

Apply the handle derivation rules from `lookup.md` against the provided `<name>`:
1. Tokenize on whitespace, lowercase, drop pure-punctuation tokens.
2. Single-token name: try `<firstname>`, then `<firstname>-2`, etc.
3. Multi-token name: try `<firstname>-<lastinitial>`, then `<firstname>-<lastname>`, then `<firstname>-<lastname>-N`.

A "collision" means a file with that handle already exists at `~/.pmos/people/{handle}.md`.

### Step 2: Collect attributes via `_shared/interactive-prompts.md`

Ask in this order, ONE field at a time per the shared protocol:

1. **`designation`** — free string. Prompt: `Designation? (formal title, e.g., 'VP Engineering')`. Skippable.
2. **`role`** — free string. Prompt: `Role? (informal day-to-day, e.g., 'Eng Manager')`. Skippable.
3. **`working_relationship`** — enum. Prompt: `Working relationship?` Options: `boss`, `direct-report`, `peer`, `team-member`, `stakeholder`, `external`, `other`. Skippable (no default).
4. **`team`** — free string. Prompt: `Team?`. Skippable.
5. **`email`** — free string. Prompt: `Email?`. Skippable.
6. **`workstreams`** — comma-separated list. Prompt: `Workstreams? (comma-separated slugs from ~/.pmos/workstreams/)`. Skippable.
7. **`aliases`** — comma-separated list. Prompt: `Aliases? (comma-separated short forms for fuzzy match)`. Skippable.

### Step 3: Write the record file

Path: `~/.pmos/people/{handle}.md`.

Frontmatter (skipped fields are written as bare keys with no value, e.g., `email:` not absent):

```yaml
---
handle: {derived-handle}
name: {original name argument}
designation: {value or empty}
role: {value or empty}
working_relationship: {value or empty}
team: {value or empty}
email: {value or empty}
workstreams: [{values}]   # written as YAML list, even if single item; empty list as []
aliases: [{values}]
created: {today}
updated: {today}
---
```

No body section is auto-written. The user can add `## Notes` later via direct file edit or via `/people refine`.

### Step 4: Regenerate INDEX

Apply Phase 8 (rebuild-index) inline. If regeneration fails, the record file is still written — emit a warning suggesting `/people rebuild-index`, but DO NOT roll back the record write.

### Step 5: Report

Output: `Added {handle} ({name}).`

### Reactive create entry point (called by `/mytasks`, not user-invoked)

When `/mytasks` rich-capture hits an unknown person and the user picks "(a) create new person 'X'", `/mytasks` invokes a minimal create variant of this phase that:
- Skips Steps 2 (no prompts).
- Sets `name:` to the disambiguated name.
- Sets `aliases:` to `[<original-token>]` (e.g., `[sarah]` if the user wrote `@sarah`).
- All other fields absent.
- Returns the derived handle to the caller.

This entry point has no user-facing slash command — `/mytasks` invokes it directly via shared instruction reference.
````

Add back the marker:

```markdown
(Phases 4, 5, 6, 7 are added in subsequent tasks.)
```

- [ ] **Step 3: Walk through `add` scenarios manually**

Read Phase 3 + `lookup.md` and confirm:
- Handle derivation produces `sarah-c` (not `sarah-chen`) on the first try because the algorithm tries `firstname-lastinitial` first.
- The reactive-create variant correctly skips prompts and seeds aliases.
- Skipped optional fields are written as bare keys.

- [ ] **Step 4: Commit**

```bash
git add plugins/pmos-toolkit/skills/people/SKILL.md plugins/pmos-toolkit/skills/people/tests/scenarios.md
git commit -m "feat(pmos-toolkit/people): add proactive create (Phase 3) + reactive entry point"
```

---

## Task 5: `/people` Phases 4–7 — show, list, set, refine

**Files:**
- Modify: `plugins/pmos-toolkit/skills/people/SKILL.md` (add Phases 4, 5, 6, 7)
- Modify: `plugins/pmos-toolkit/skills/people/tests/scenarios.md` (add scenarios)

Bundle the remaining read/edit phases into one task — they're all small CRUD operations on existing records.

- [ ] **Step 1: Add scenarios for show, list, set, refine**

Append to `tests/scenarios.md`:

````markdown

## Fixture: with-people (continued)

### Scenario: `/people show sarah-chen`

Expected:
- Locate `~/.pmos/people/sarah-chen.md`.
- Render the file content verbatim, fenced as markdown.

### Scenario: `/people show Sarah Chen`

Expected:
- Apply Phase 2 fuzzy match → tier 3 exact name match → 1 result `sarah-chen`.
- Render that record verbatim.

### Scenario: `/people show sarah` (ambiguous)

Expected:
- Apply Phase 2 → tier 2 alias match → 1 result `sarah-chen`.
- Render that record verbatim.

### Scenario: `/people show sara` (ambiguous, substring tier)

Expected:
- Apply Phase 2 → tier 4 → 2 results.
- Output: `Multiple matches: sarah-chen, sarah-patel. Run /people show <handle> with the exact handle.`

### Scenario: `/people show xyz`

Expected:
- Apply Phase 2 → 0 matches.
- Output: `No matches for 'xyz'. Run /people for the full list.`

### Scenario: `/people show 999nonexistent`

Expected: same as `xyz` — `No matches for '999nonexistent'.`

### Scenario: `/people list --workstream platform-q3`

Expected:
- Read all records.
- Filter to records whose `workstreams:` contains `platform-q3`.
- With-people fixture: sarah-chen and mark-davis match.
- Render flat sorted (by name) table with INDEX.md columns.

### Scenario: `/people list --relationship peer`

Expected:
- Filter to `working_relationship: peer`.
- With-people fixture: sarah-chen, mark-davis match (sarah-patel is `team-member`).
- Render flat sorted table.

### Scenario: `/people list --workstream platform-q3 --relationship peer` (combined)

Expected: AND semantics. Same two records (both filters pass for sarah-chen and mark-davis).

### Scenario: `/people set sarah-chen team=infra`

Expected:
- Validate `team` is an allowed editable field. (`team` is free-string, no enum check.)
- Load sarah-chen.md, update `team: infra`, set `updated:` to today.
- Apply Phase 8 (regenerate INDEX).
- Output: `Updated sarah-chen: team = infra.`

### Scenario: `/people set sarah-chen working_relationship=invalid_value`

Expected:
- Validate against enum. `invalid_value` not in allowed list.
- Output: `Unknown working_relationship 'invalid_value'. Allowed: boss, direct-report, peer, team-member, stakeholder, external, other.`
- No write.

### Scenario: `/people set sarah-chen handle=new-handle`

Expected:
- `handle` is skill-managed; not editable directly.
- Output: `Field 'handle' cannot be set directly. The skill manages it.`
- No write.

### Scenario: `/people refine sarah-chen`

Expected interactive flow per `_shared/interactive-prompts.md` — same field order as Phase 3, but pre-filled with current values:
1. Prompt designation (current: `VP Engineering`). User: `<enter>` to keep.
2. Prompt role (current: `Eng Manager`). User: types `Director of Engineering`.
3. Prompt working_relationship (current: `peer`). User: `<enter>`.
4. Prompt team (current: `platform`). User: `<enter>`.
5. Prompt email (current: `sarah@acme.com`). User: `<enter>`.
6. Prompt workstreams (current: `platform-q3`). User: `<enter>`.
7. Prompt aliases (current: `sarah, schen, sc`). User: appends, types `sarah, schen, sc, schen2`.
8. Write back, set `updated:` to today.
9. Apply Phase 8.
10. Output: `Refined sarah-chen.`
````

- [ ] **Step 2: Add Phases 4, 5, 6, 7 to SKILL.md**

Replace the marker `(Phases 4, 5, 6, 7 are added in subsequent tasks.)` with the four phases in order:

````markdown
## Phase 4: Show Record

Triggered by `/people show <handle-or-name>`.

### Step 1: Resolve

If `<handle-or-name>` looks like a kebab-case handle (lowercase + hyphens only) AND `~/.pmos/people/{input}.md` exists, use it directly.

Otherwise, apply Phase 2 (find) to the input. Then:
- **0 matches:** `No matches for '{input}'. Run /people for the full list.`
- **1 match:** proceed with that handle.
- **N matches:** `Multiple matches: {comma-separated handles}. Run /people show <handle> with the exact handle.`

### Step 2: Render

Output the file contents verbatim, fenced as markdown.

---

## Phase 5: Filtered List

Triggered by `/people list [flags]`.

### Recognized flags (all optional, all combinable; AND semantics)

| Flag | Effect |
|---|---|
| `--workstream <slug>` | Records whose `workstreams:` contains `<slug>` |
| `--relationship <enum>` | Records whose `working_relationship:` equals the enum value |

### Step 1: Read records

Glob `~/.pmos/people/*.md` (excluding `INDEX.md`). Parse frontmatter for each. Skip malformed files with a one-line warning.

### Step 2: Validate flag values

For `--relationship`: must be in the enum. Reject with `Unknown relationship '{value}'. Allowed: boss, direct-report, peer, team-member, stakeholder, external, other.`

For `--workstream`: any string accepted (workstreams are free-text).

### Step 3: Filter and sort

Apply filters with AND semantics. Sort survivors by `name` ascending.

### Step 4: Render

Render the same table as INDEX.md (columns: handle, name, designation, role, working_relationship, team, email).

If 0 matches: `No people match.`

---

## Phase 6: Set Field

Triggered by `/people set <handle> <field>=<value>`.

### Step 1: Locate the record

`~/.pmos/people/{handle}.md` must exist. If not: `No record with handle '{handle}'. Run /people find {handle} for suggestions.`

### Step 2: Parse and validate field name

Allowed editable fields: `name`, `designation`, `role`, `working_relationship`, `team`, `email`, `workstreams`, `aliases`.

Disallowed (skill-managed): `handle`, `created`, `updated`. Reject: `Field '{field}' cannot be set directly. The skill manages it.`

Unknown fields: `Field '{field}' is not recognized. Allowed: {comma-separated list}.`

### Step 3: Validate value

| Field | Validation |
|---|---|
| `working_relationship` | Must be in enum |
| `workstreams`, `aliases` | Comma-separated; written as YAML list. Empty value clears the list. |
| `name`, `designation`, `role`, `team`, `email` | Free string. Empty value clears the field. |

On enum violation: `Unknown {field} '{value}'. Allowed: {comma-separated list}.` No write.

### Step 4: Edit and report

Load record, update only the named field, set `updated:` to today, write back. Apply Phase 8 (regenerate INDEX). Output: `Updated {handle}: {field} = {value}.`

---

## Phase 7: Refine

Triggered by `/people refine <handle>`. Interactive — pre-filled walk through all editable fields.

### Step 1: Locate the record

`~/.pmos/people/{handle}.md` must exist. If not: `No record with handle '{handle}'. Run /people find {handle} for suggestions.`

### Step 2: Walk through fields per `_shared/interactive-prompts.md`

Same field order as Phase 3 (designation → role → working_relationship → team → email → workstreams → aliases). Each prompt shows the current value as default; `<enter>` keeps it; explicit new value replaces; `clear` (for list fields) empties.

### Step 3: Write back

Replace each field with the new value (only if changed). Set `updated:` to today. Body is untouched.

### Step 4: Regenerate INDEX, report

Apply Phase 8. Output: `Refined {handle}.`
````

- [ ] **Step 3: Walk through scenarios manually**

For each scenario added in Step 1, read the relevant phase and confirm the prose unambiguously produces the expected behavior. Pay attention to:
- Phase 4's resolve logic correctly distinguishes handle-direct from name-fuzzy paths.
- Phase 5 filter validation rejects bad enum values cleanly.
- Phase 6 enum validation message format matches `_shared/interactive-prompts.md` rejection format.

- [ ] **Step 4: Commit**

```bash
git add plugins/pmos-toolkit/skills/people/SKILL.md plugins/pmos-toolkit/skills/people/tests/scenarios.md
git commit -m "feat(pmos-toolkit/people): add show/list/set/refine (Phases 4-7)"
```

---

## Task 6: `/mytasks` skill scaffold + schema + inference-heuristics + default daily view + rebuild-index

**Files:**
- Create: `plugins/pmos-toolkit/skills/mytasks/SKILL.md`
- Create: `plugins/pmos-toolkit/skills/mytasks/schema.md`
- Create: `plugins/pmos-toolkit/skills/mytasks/inference-heuristics.md`
- Create: `plugins/pmos-toolkit/skills/mytasks/tests/scenarios.md`
- Create: `plugins/pmos-toolkit/skills/mytasks/tests/fixtures/empty-tasks/.gitkeep`
- Create: `plugins/pmos-toolkit/skills/mytasks/tests/fixtures/with-tasks/INDEX.md`
- Create: `plugins/pmos-toolkit/skills/mytasks/tests/fixtures/with-tasks/items/0001-draft-q3-okrs.md`
- Create: `plugins/pmos-toolkit/skills/mytasks/tests/fixtures/with-tasks/items/0002-call-sarah-on-roadmap.md`
- Create: `plugins/pmos-toolkit/skills/mytasks/tests/fixtures/with-tasks/items/0003-fix-coffee-machine.md`
- Create: `plugins/pmos-toolkit/skills/mytasks/tests/fixtures/with-tasks/items/0004-read-okr-best-practices.md`

- [ ] **Step 1: Write the schema reference**

Create `plugins/pmos-toolkit/skills/mytasks/schema.md`:

````markdown
# /mytasks Item Schema

Every task is a markdown file at `~/.pmos/tasks/items/{id}-{slug}.md`.

## Filename

- `id`: 4-digit zero-padded sequential integer (`0001`, `0002`, …). Per-skill counter; no global coordination.
- `slug`: kebab-cased title, max 60 chars, ASCII letters/digits/hyphens only, no leading/trailing hyphens.

## Frontmatter

```yaml
---
id: 0042
title: Draft Q3 OKRs for Platform team
type: execution                  # enum
importance: leverage             # enum (LNO)
status: pending                  # enum
workstream: platform-q3          # optional, ideally a workstream slug
people: [sarah-chen, mark-davis] # optional list of /people handles
labels: [okrs, planning]         # optional free-string list
links: []                        # optional list of URLs or file paths
due: 2026-05-12                  # optional ISO date
start: 2026-05-05                # optional ISO date
checkin: weekly                  # optional enum
next_checkin: 2026-05-02         # optional ISO date, auto-bumped on /mytasks checkin
created: 2026-04-25
updated: 2026-04-25
completed:                       # ISO date, set when status -> completed/dropped
---
```

### Enum values (the skill MUST validate against these and never invent new ones)

| Field | Allowed values |
|---|---|
| `type` | `execution`, `follow-up`, `reminder`, `idea`, `read`, `call` |
| `importance` | `leverage`, `neutral`, `overhead` |
| `status` | `pending`, `in-progress`, `waiting`, `completed`, `dropped` |
| `checkin` | `daily`, `weekly`, `biweekly`, `monthly`, `none` |

### Defaults on quick-capture (`/mytasks <bare text>`)

- `status: pending`
- `importance: neutral`
- `type:` per inference (see `inference-heuristics.md`); fallback `execution`
- `created`, `updated`: today
- `workstream:` from current repo's `.pmos/settings.yaml` if present and contains `workstream:`, else absent
- `people:` from `@handle` tokens (resolved via `/people find`); unresolved tokens flagged in capture report
- `due:` from natural-language date parse if present, else absent
- All other optional fields: absent

### Defaults on rich-capture (`/mytasks add`)

All fields prompted via `_shared/interactive-prompts.md`. Each prompt has a sensible default; `<enter>` accepts.

## Body

Entirely freeform. The skill recognizes (but does not require) two conventional H2 sections:

```markdown
## Notes
Free-form. User-written.

## Check-ins
- 2026-04-25: synced with Sarah, on track   # auto-managed by /mytasks checkin
```

Tasks captured quickly typically have no body. The `## Check-ins` section is created by `/mytasks checkin <id>` if absent.

## INDEX.md format

`~/.pmos/tasks/INDEX.md` is regenerable, never the source of truth. Shape:

```markdown
# My Tasks

Last regenerated: 2026-04-25

## leverage
| id | type | status | due | next_checkin | title | workstream |
|----|------|--------|-----|--------------|-------|------------|
| 0001 | execution | in-progress | 2026-05-12 |  | Draft Q3 OKRs for Platform team | platform-q3 |

## neutral
| id | type | status | due | next_checkin | title | workstream |
|----|------|--------|-----|--------------|-------|------------|
| 0002 | call | pending | 2026-05-01 | 2026-05-08 | Call sarah on roadmap | platform-q3 |
| 0004 | read | pending |  |  | Read OKR best practices |  |

## overhead
| id | type | status | due | next_checkin | title | workstream |
|----|------|--------|-----|--------------|-------|------------|
| 0003 | execution | waiting |  |  | Fix coffee machine |  |
```

Items grouped by `importance` (`leverage`, `neutral`, `overhead`). Within each group, sorted by `due` asc (no-due last) → `updated` desc.

`completed` and `dropped` items are NOT in INDEX.md. Archived items (in `archive/`) are also NOT in INDEX.md.

Empty optional fields render as empty cells (no `null`, no dashes).

## Archive

Archived tasks live at `~/.pmos/tasks/archive/YYYY-QN/{id}-{slug}.md` with full content preserved. Archive structure mirrors `items/` and is never written to `INDEX.md`.
````

- [ ] **Step 2: Write the inference-heuristics reference**

Create `plugins/pmos-toolkit/skills/mytasks/inference-heuristics.md`:

````markdown
# /mytasks Inference Heuristics

Used by quick-capture (`/mytasks <bare text>`). Each rule is applied in order against the user's input. The whole input becomes the `title:` after parsed tokens are stripped.

## Type inference (case-insensitive, first match wins)

| Pattern | Resolves to |
|---|---|
| `\bcall\b`, `\bring\b` | `call` |
| `\bread\b`, `review article`, `review post`, `review doc` | `read` |
| `\bremind\b`, `\bremember\b` | `reminder` |
| `\bfollow up\b`, `\bfollowup\b`, `\bcheck in with\b`, `\bping\b` | `follow-up` |
| `\bidea\b`, `\bbrainstorm\b` | `idea` |
| (no match) | `execution` (fallback) |

Rules use word-boundary matches (`\b`) to avoid false positives on substrings (e.g., "recall" should NOT match `call`).

## Date inference (case-insensitive)

Applied to the input. First match wins. The matched substring is stripped from the title.

| Pattern | Resolves to |
|---|---|
| `\btoday\b`, `\bEOD\b` | today (ISO date) |
| `\btomorrow\b` | today + 1 day |
| `\bMonday\b` … `\bSunday\b` | next occurrence of that day, EXCLUSIVE of today (so `Friday` on a Friday = next Friday, not today) |
| `\bnext (Monday\|...\|Sunday)\b` | same as bare day name |
| `\bin (\d+) days?\b` | today + N days |
| `\bby (\d{4}-\d{2}-\d{2})\b` | the ISO date as-is |
| `\bby (\d{1,2})/(\d{1,2})\b` | MM/DD in current year; if resulting date is before today, roll to next year |
| `\bby (\d{1,2})/(\d{1,2})/(\d{4})\b` | MM/DD/YYYY |
| (no match) | empty (`due:` absent) |

The resolved date appears in the capture report so the user sees what was inferred.

## People inference (`@handle` tokens only)

Only `@`-prefixed tokens trigger person resolution. Bare names (e.g., `Sarah` without `@`) stay in the title unchanged.

For each `@handle` token:
1. Strip the leading `@`.
2. Call `/people find <handle>`.
3. **Single match** → use the resolved handle silently. The `@handle` token is stripped from the title.
4. **Multiple matches** → skip (token stays in title); flag as unresolved in capture report.
5. **No match** → skip (token stays in title); flag as unresolved in capture report.

The original `@handle` text remains in the title for unresolved cases — preserves user intent for later cleanup.

## Workstream inference

If invoked from a working directory that is inside a git repo AND that repo has `.pmos/settings.yaml` AND that yaml contains a `workstream:` key, set `workstream:` to that value. Otherwise leave absent.

Detection: `git rev-parse --show-toplevel` (silent on failure); check for `.pmos/settings.yaml` at the result; parse the YAML; read the `workstream:` key.

## What is NEVER inferred

- `importance` — too subjective. Always defaults to `neutral`.
- `status` — always `pending` on capture.
- `checkin`, `next_checkin`, `start`, `links`, `labels` — never inferred. Always absent on quick-capture.
````

- [ ] **Step 3: Write the SKILL.md scaffold (frontmatter + Phase 0 router + Phase 1 default daily view + Phase 12 rebuild-index)**

Create `plugins/pmos-toolkit/skills/mytasks/SKILL.md`:

````markdown
---
name: mytasks
description: Persistent personal task tracker — distinct from Claude Code's session-scoped TaskCreate/TaskList tools. Use for real-world tasks (LNO importance, due dates, people, check-ins, workstream). Lives at ~/.pmos/tasks/. Use when the user says "add a task", "what's on my plate", "tasks for sarah", "what's due this week", "check in on X", "/mytasks", or names a task to capture.
user-invocable: true
argument-hint: "[ | <text> | add <text> | list [filters] | today | week | overdue | waiting | checkins | for <handle> | in <workstream> | show <id> | set <id> <field>=<value> | refine <id> | done <id> [note] | drop <id> [reason] | checkin <id> [note] | archive | rebuild-index]"
---

# My Tasks

A lightweight, file-based personal task tracker. Asana/Todoist-class personal life-OS layer, but local-first, AI-native, and embedded in the `pmos-toolkit` ecosystem.

```
                                       ┌─ default daily view ──┐
/mytasks (capture)                     ↓                       │
       │                                                       │
       ▼                                                       │
   pending → in-progress → completed                           │
       │       │              │                                │
       │       ▼              ▼                                │
       │    waiting        dropped → /mytasks archive (>30d)   │
       └──────────────────────────────────────────────────────┘
```

**Hard isolation from `/backlog`.** No code path in `/mytasks` reads or writes `<repo>/backlog/`. The two skills are independent.

**Tip:** `~/.pmos/` is local by default. If you want version history and cross-machine sync, run `git init ~/.pmos/` and push it to a private remote. The skill never enforces this.

**Announce at start:** "Using the mytasks skill to {capture|list|refine|...}."

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:
- **No `AskUserQuestion`:** follow `_shared/interactive-prompts.md` fallback path — one question at a time as plain text with numbered responses.
- **No subagents:** sequential single-agent operation.

## References

- `schema.md` — item file shape, enum values, `INDEX.md` format
- `inference-heuristics.md` — quick-capture keyword + date + person + workstream parsing rules
- `_shared/interactive-prompts.md` — interactive prompting protocol (used by `add`, `refine`, unknown-person flow)
- Sibling skill `/people` — fuzzy-match person lookup via `/people find`

---

## Phase 0: Subcommand Routing

Parse the user's argument to determine the subcommand. Be liberal with the form — both `/mytasks add foo` and `/mytasks "foo"` work for capture.

| Argument shape | Subcommand |
|---|---|
| empty | Phase 1 (default daily view) |
| `add <text>` | Phase 3 (rich capture — interactive) |
| `list [flags]` | Phase 4 (filtered list) |
| `today` / `week` / `overdue` / `waiting` / `checkins` | Phase 5 (named view) |
| `for <handle>` / `in <workstream>` | Phase 5 (named view) |
| `show <id>` | Phase 6 (render item) |
| `set <id> <field>=<value>` | Phase 7 (single-field edit) |
| `refine <id>` | Phase 8 (interactive multi-field refine) |
| `done <id> [note]` | Phase 9 (status → completed shortcut) |
| `drop <id> [reason]` | Phase 9 (status → dropped shortcut) |
| `checkin <id> [note]` | Phase 10 (check-in mechanics) |
| `archive [--quarter Q]` | Phase 11 (archive completed/dropped) |
| `rebuild-index` | Phase 12 (regenerate INDEX.md) |
| (any other free text not matching a verb) | Phase 2 (quick capture) |

Quick capture (Phase 2) is the fall-through. If the first token is not a recognized verb AND the argument is non-empty, treat the whole argument as `<bare text>` for quick-capture.

---

## Phase 1: Default Daily View

Triggered by `/mytasks` with no arguments.

### Step 1: Resolve `~/.pmos/tasks/`

If `~/.pmos/tasks/INDEX.md` does not exist (or `~/.pmos/tasks/` is missing entirely), output:

`No tasks yet. Capture one with /mytasks <text> or /mytasks add <text>.`

Then exit.

### Step 2: Validate freshness

Compare `INDEX.md`'s `Last regenerated:` date against the most recent mtime of any `~/.pmos/tasks/items/*.md`. If items have been modified more recently, regenerate (apply Phase 12) before rendering.

### Step 3: Render

Output the contents of `~/.pmos/tasks/INDEX.md` to the user. The INDEX is already grouped by importance per `schema.md`, so the rendering is verbatim.

If `INDEX.md` exists but contains zero items (empty groups), output: `No active tasks. Capture one with /mytasks <text>.`

---

## Phase 12: Rebuild Index

Triggered by `/mytasks rebuild-index`. Also invoked internally by Phases 2, 3, 7, 8, 9, 10, 11 after any item write.

### Step 1: Read items

Glob `~/.pmos/tasks/items/*.md`. For each, parse frontmatter. Skip files with malformed frontmatter (emit one-line warning per skip; do not abort).

### Step 2: Filter

Exclude items with `status: completed` or `status: dropped`. They live only in item files; archived items live in `archive/` and are also excluded.

### Step 3: Group and sort

Group by `importance` (buckets: `leverage`, `neutral`, `overhead`). Items with no `importance:` field default to the `neutral` bucket. Within each group, sort by `due` ascending (no-due last) → `updated` descending.

### Step 4: Write INDEX.md

Overwrite `~/.pmos/tasks/INDEX.md` with the format defined in `schema.md`:

```markdown
# My Tasks

Last regenerated: {today}

## leverage
| id | type | status | due | next_checkin | title | workstream |
|----|------|--------|-----|--------------|-------|------------|
{rows or empty if bucket has zero items}

## neutral
| id | type | status | due | next_checkin | title | workstream |
|----|------|--------|-----|--------------|-------|------------|
{rows or empty}

## overhead
| id | type | status | due | next_checkin | title | workstream |
|----|------|--------|-----|--------------|-------|------------|
{rows or empty}
```

If a bucket has zero items, write the `## {bucket}` header and the column row, then an empty data section (no rows). Do NOT omit the bucket entirely.

### Step 5: Report

If invoked directly: `Regenerated INDEX.md: {N active items} ({completed_excluded} completed/dropped excluded).`
If invoked from another phase: silent on success, warn on failure.

---

(Phases 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 are added in subsequent tasks.)
````

- [ ] **Step 4: Create the test fixtures**

Create the empty fixture:

```bash
mkdir -p plugins/pmos-toolkit/skills/mytasks/tests/fixtures/empty-tasks
touch plugins/pmos-toolkit/skills/mytasks/tests/fixtures/empty-tasks/.gitkeep
```

Create `plugins/pmos-toolkit/skills/mytasks/tests/fixtures/with-tasks/items/0001-draft-q3-okrs.md`:

```markdown
---
id: 0001
title: Draft Q3 OKRs for Platform team
type: execution
importance: leverage
status: in-progress
workstream: platform-q3
people: [sarah-chen]
labels: [okrs, planning]
links: []
due: 2026-05-12
start: 2026-05-05
checkin:
next_checkin:
created: 2026-04-20
updated: 2026-04-23
completed:
---

## Notes
Aligning with Sarah on direction this week.
```

Create `plugins/pmos-toolkit/skills/mytasks/tests/fixtures/with-tasks/items/0002-call-sarah-on-roadmap.md`:

```markdown
---
id: 0002
title: Call sarah on roadmap
type: call
importance: neutral
status: pending
workstream: platform-q3
people: [sarah-chen]
labels: []
links: []
due: 2026-05-01
start:
checkin: weekly
next_checkin: 2026-05-08
created: 2026-04-22
updated: 2026-04-22
completed:
---
```

Create `plugins/pmos-toolkit/skills/mytasks/tests/fixtures/with-tasks/items/0003-fix-coffee-machine.md`:

```markdown
---
id: 0003
title: Fix coffee machine
type: execution
importance: overhead
status: waiting
workstream:
people: []
labels: []
links: []
due:
start:
checkin:
next_checkin:
created: 2026-04-21
updated: 2026-04-23
completed:
---
```

Create `plugins/pmos-toolkit/skills/mytasks/tests/fixtures/with-tasks/items/0004-read-okr-best-practices.md`:

```markdown
---
id: 0004
title: Read OKR best practices
type: read
importance: neutral
status: pending
workstream:
people: []
labels: [reading]
links: [https://example.com/okrs]
due:
start:
checkin:
next_checkin:
created: 2026-04-23
updated: 2026-04-23
completed:
---
```

Create `plugins/pmos-toolkit/skills/mytasks/tests/fixtures/with-tasks/INDEX.md`:

```markdown
# My Tasks

Last regenerated: 2026-04-23

## leverage
| id | type | status | due | next_checkin | title | workstream |
|----|------|--------|-----|--------------|-------|------------|
| 0001 | execution | in-progress | 2026-05-12 |  | Draft Q3 OKRs for Platform team | platform-q3 |

## neutral
| id | type | status | due | next_checkin | title | workstream |
|----|------|--------|-----|--------------|-------|------------|
| 0002 | call | pending | 2026-05-01 | 2026-05-08 | Call sarah on roadmap | platform-q3 |
| 0004 | read | pending |  |  | Read OKR best practices |  |

## overhead
| id | type | status | due | next_checkin | title | workstream |
|----|------|--------|-----|--------------|-------|------------|
| 0003 | execution | waiting |  |  | Fix coffee machine |  |
```

- [ ] **Step 5: Write the scenario specs**

Create `plugins/pmos-toolkit/skills/mytasks/tests/scenarios.md`:

````markdown
# Scenario Fixtures

Each section describes an expected agent behavior given the matching fixture under `tests/fixtures/`. To verify, the implementer reads the relevant SKILL.md phases and walks through each scenario manually.

## Fixture: empty-tasks

A directory with no items (or missing `~/.pmos/tasks/`).

### Scenario: `/mytasks` (no args, empty fixture)

Expected:
- Output: `No tasks yet. Capture one with /mytasks <text> or /mytasks add <text>.`
- No files created.

### Scenario: `/mytasks rebuild-index` (empty fixture)

Expected:
- Glob returns 0 item files.
- Write `~/.pmos/tasks/INDEX.md` with header + 3 empty buckets (each bucket has its `## {name}` header + column row, no data rows).
- Output: `Regenerated INDEX.md: 0 active items (0 completed/dropped excluded).`

## Fixture: with-tasks

Four items: 0001 (leverage, in-progress, due 2026-05-12), 0002 (neutral, call, pending, due 2026-05-01, next_checkin 2026-05-08), 0003 (overhead, waiting), 0004 (neutral, read, pending).

### Scenario: `/mytasks` (no args, with-tasks fixture)

Expected:
- Read INDEX.md (skip regen since INDEX is fresh).
- Render verbatim.
- Output groups: `## leverage` with 0001, `## neutral` with 0002 and 0004 (sorted by due asc; 0002 first because it has a due date), `## overhead` with 0003.

### Scenario: `/mytasks rebuild-index` (with-tasks fixture)

Expected:
- Read all 4 items.
- Group by importance: leverage (0001), neutral (0002, 0004), overhead (0003).
- Within neutral: sort by due asc, no-due last → 0002 (due 2026-05-01), then 0004 (no due).
- Write INDEX.md with the expected shape.
- Output: `Regenerated INDEX.md: 4 active items (0 completed/dropped excluded).`
````

- [ ] **Step 6: Walk through scenarios manually**

Read Phase 1 + Phase 12 + `schema.md` and confirm:
- Phase 1 correctly returns the `No tasks yet` message when directory is missing.
- Phase 12 correctly excludes completed/dropped items (none in this fixture, but the logic must handle it).
- Phase 12 produces the correct group ordering and within-group sort.
- Empty buckets in Phase 12 still render headers + column row.

- [ ] **Step 7: Commit**

```bash
git add plugins/pmos-toolkit/skills/mytasks/
git commit -m "feat(pmos-toolkit/mytasks): scaffold + schema + inference-heuristics + default view + rebuild-index"
```

---

## Task 7: `/mytasks` Phase 2 — quick capture (single tool-call, never blocks)

**Files:**
- Modify: `plugins/pmos-toolkit/skills/mytasks/SKILL.md` (add Phase 2)
- Modify: `plugins/pmos-toolkit/skills/mytasks/tests/scenarios.md` (add quick-capture scenarios)

- [ ] **Step 1: Add quick-capture scenarios**

Append to `tests/scenarios.md`:

````markdown

## Fixture: empty-tasks (continued — quick capture)

### Scenario: `/mytasks Call sarah about Q3 OKRs by Friday` (today is 2026-04-25, a Saturday)

Expected single tool-call sequence (no blocking, no questions):
1. Parse: `Call` → type `call`. `by Friday` → due `2026-05-01` (next Friday after Sat 2026-04-25).
2. Strip `by Friday` from the title; `Call` stays in title (it's the type signal but also natural language).
3. The remaining title: `Call sarah about Q3 OKRs`.
4. Allocate id `0001`.
5. Workstream: if invoked outside a `.pmos/settings.yaml` repo, leave absent.
6. People: `sarah` is bare (no `@`), stays in title. Empty `people:`.
7. Slug: `call-sarah-about-q3-okrs`.
8. Write `~/.pmos/tasks/items/0001-call-sarah-about-q3-okrs.md` with frontmatter only (no body).
9. Frontmatter: `id: 0001`, `title: Call sarah about Q3 OKRs`, `type: call`, `importance: neutral`, `status: pending`, `due: 2026-05-01`, `created`/`updated` = today, all other optional fields as bare keys.
10. Apply Phase 12 (rebuild INDEX).
11. Output: `Captured #0001 (call, neutral): "Call sarah about Q3 OKRs" — due 2026-05-01.`

### Scenario: `/mytasks Sync with @sarah on roadmap` (with-people fixture sibling exists; sarah → sarah-chen via alias)

Expected:
1. Parse: no type keyword, default `execution`. No date. `@sarah` → `/people find sarah` → tier 2 alias match → `sarah-chen`.
2. Strip `@sarah` from title (resolved). Remaining: `Sync with on roadmap`. Collapse double spaces: `Sync with on roadmap`. (Acceptable — preserve user's words; do NOT prettify mid-sentence.)
3. Allocate id `0002`.
4. Slug: `sync-with-on-roadmap`.
5. Write item file with `people: [sarah-chen]`, all other fields as default.
6. Output: `Captured #0002 (execution, neutral): "Sync with on roadmap" — people: sarah-chen.`

### Scenario: `/mytasks Sync with @unknown_person on roadmap`

Expected:
1. `@unknown_person` → `/people find unknown_person` → 0 matches.
2. Token NOT stripped from title (preserves user intent).
3. `people: []` (empty list).
4. Output includes unresolved warning:
   ```
   Captured #0003 (execution, neutral): "Sync with @unknown_person on roadmap"
     ⚠ unresolved: @unknown_person — run /people add unknown_person, then /mytasks set 0003 people=<handle>
   ```

### Scenario: `/mytasks Sync with @sara on roadmap` (with-people fixture; ambiguous — substring match returns sarah-chen and sarah-patel)

Expected:
1. `@sara` → `/people find sara` → tier 4 substring match → 2 results.
2. Multi-match: skip (do not pick), token stays in title.
3. `people: []`.
4. Output:
   ```
   Captured #0004 (execution, neutral): "Sync with @sara on roadmap"
     ⚠ unresolved: @sara — multiple matches (sarah-chen, sarah-patel); run /mytasks set 0004 people=<handle>
   ```

### Scenario: `/mytasks Read OKR doc tomorrow`

Expected:
1. `Read` → type `read`. `tomorrow` → due = today + 1.
2. Strip `tomorrow`. Title: `Read OKR doc`.
3. Output: `Captured #0005 (read, neutral): "Read OKR doc" — due {today+1}.`

### Scenario: `/mytasks Buy birthday gift` (no inferable type, no date)

Expected:
1. No type keyword → default `execution`. No date.
2. Title: `Buy birthday gift`.
3. Output: `Captured #0006 (execution, neutral): "Buy birthday gift".` (No due, no people, no workstream — minimal report.)
````

- [ ] **Step 2: Add Phase 2 (Quick Capture) to SKILL.md**

Replace the marker `(Phases 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 are added in subsequent tasks.)` with Phase 2 content + remaining marker:

````markdown
## Phase 2: Quick Capture (`<bare text>`)

Triggered by `/mytasks <text>` where `<text>` does not start with a recognized verb (`add`, `list`, `today`, `week`, `overdue`, `waiting`, `checkins`, `for`, `in`, `show`, `set`, `refine`, `done`, `drop`, `checkin`, `archive`, `rebuild-index`).

**This phase MUST complete in a single tool-call sequence with NO clarifying questions.** Wrong inference is acceptable; capture friction is not.

### Step 1: Resolve `~/.pmos/tasks/items/`

If `~/.pmos/tasks/items/` exists, use it. Otherwise, create it with `mkdir -p ~/.pmos/tasks/items`.

### Step 2: Allocate id

Scan `~/.pmos/tasks/items/` and `~/.pmos/tasks/archive/**/` for filenames matching `^([0-9]{4})-`. Take the max numeric prefix; allocate `id = max + 1`. If neither directory exists or both are empty, `id = 1`. Format as 4-digit zero-padded.

### Step 3: Apply inference rules

Per `inference-heuristics.md`:
1. **Type:** scan for keyword match; fallback `execution`.
2. **Date (`due:`):** scan for natural-language date pattern; strip the matched substring from the title.
3. **People:** scan for `@handle` tokens. For each, call `/people find <handle>`:
   - **Single match:** add resolved handle to `people:` list; strip `@handle` token from title.
   - **Multiple matches:** flag as unresolved (multi-match); leave token in title; collect for warning.
   - **No match:** flag as unresolved (no-match); leave token in title; collect for warning.
4. **Workstream:** check current working directory for `.pmos/settings.yaml`; if present and contains `workstream:` key, use it.

The **type keyword is NOT stripped from the title** (it's natural language; the title remains intelligible to the user).

### Step 4: Build slug from final title

After date stripping (and resolved-`@handle` stripping):
- Lowercase the title.
- Replace any run of non-alphanumeric chars with a single hyphen.
- Trim leading/trailing hyphens.
- Truncate to 60 characters at a hyphen boundary if possible, otherwise hard-truncate.

### Step 5: Write the item file

Path: `~/.pmos/tasks/items/{id}-{slug}.md`

Content (frontmatter only, no body):

```yaml
---
id: {id}
title: {final title text}
type: {inferred type}
importance: neutral
status: pending
workstream: {value or empty if not inferred}
people: [{resolved handles, comma-separated; empty list `[]` if none}]
labels: []
links: []
due: {value or empty if not inferred}
start:
checkin:
next_checkin:
created: {today YYYY-MM-DD}
updated: {today YYYY-MM-DD}
completed:
---
```

Optional fields with no value are written as bare keys (e.g., `start:`), not omitted, so the file shape is consistent.

### Step 6: Regenerate INDEX.md

Apply Phase 12 inline. If regeneration fails, the item file is still written — emit a warning suggesting `/mytasks rebuild-index`, but DO NOT roll back.

### Step 7: Report

Build the report line:

```
Captured #{id} ({type}, {importance}): "{final title}"
```

Append clauses for non-default values, separated by ` — `:
- `due {due}` if due was inferred.
- `workstream {workstream}` if inferred (annotate `(from current repo)` if from `.pmos/settings.yaml`).
- `people: {comma-separated handles}` if any resolved.

Then, on subsequent indented lines, list any unresolved `@handle` tokens:
- For no-match: `⚠ unresolved: @{token} — run /people add {token}, then /mytasks set {id} people=<handle>`
- For multi-match: `⚠ unresolved: @{token} — multiple matches ({comma-separated handles}); run /mytasks set {id} people=<handle>`

Example:
```
Captured #0042 (call, neutral): "Call sarah about Q3 OKRs" — due 2026-05-01
```

Or with unresolved person:
```
Captured #0043 (execution, neutral): "Sync with @sarah on roadmap"
  ⚠ unresolved: @sarah — multiple matches (sarah-chen, sarah-patel); run /mytasks set 0043 people=<handle>
```
````

Add back the marker:

```markdown
(Phases 3, 4, 5, 6, 7, 8, 9, 10, 11 are added in subsequent tasks.)
```

- [ ] **Step 3: Walk through quick-capture scenarios manually**

Read Phase 2 + `inference-heuristics.md` and confirm:
- Type keywords are matched with word boundaries (`\b`).
- Date "Friday" on a Friday correctly resolves to NEXT Friday (exclusive of today).
- `@handle` resolution correctly distinguishes single-match (silent, strip) from multi-match (skip, flag) from no-match (skip, flag).
- The unresolved-person warning differentiates multi-match from no-match in its message.
- The phase NEVER asks questions (verify by re-reading: no `AskUserQuestion`-related instructions, no prompts).

- [ ] **Step 4: Commit**

```bash
git add plugins/pmos-toolkit/skills/mytasks/SKILL.md plugins/pmos-toolkit/skills/mytasks/tests/scenarios.md
git commit -m "feat(pmos-toolkit/mytasks): add quick capture (Phase 2)"
```

---

## Task 8: `/mytasks` Phase 3 — rich capture (interactive `add`, includes unknown-person three-option flow)

**Files:**
- Modify: `plugins/pmos-toolkit/skills/mytasks/SKILL.md` (add Phase 3)
- Modify: `plugins/pmos-toolkit/skills/mytasks/tests/scenarios.md` (add rich-capture scenarios)

- [ ] **Step 1: Add rich-capture scenarios**

Append to `tests/scenarios.md`:

````markdown

### Scenario: `/mytasks add Prep board deck` (empty fixture)

Expected interactive flow per `_shared/interactive-prompts.md`:
1. Allocate id `0001`.
2. Prompt `importance` (enum): `leverage`, `neutral` (default), `overhead`. User picks: `leverage`.
3. Prompt `type` (enum): `execution` (default — no keyword inferred from "Prep board deck"), `follow-up`, `reminder`, `idea`, `read`, `call`. User: `<enter>` (keeps execution).
4. Prompt `workstream` (free string, default = inferred from `.pmos/settings.yaml` if present, else empty). User: `board-q2`.
5. Prompt `due` (date input). User: `Friday`. Skill parses → next Friday's ISO date.
6. Prompt `people` (comma-separated, skippable). User: `Mark, Lisa`.
7. For each name token, call `/people find`:
   - `Mark` → tier 2 alias match if `mark` is in mark-davis's aliases; assume yes → resolves silently.
   - `Lisa` → 0 matches → triggers unknown-person three-option prompt.
8. **Unknown-person prompt** (multi-option per `_shared/interactive-prompts.md`):
   ```
   No match for 'Lisa' — what would you like to do?
     (a) create new person 'Lisa'
     (b) pick existing: (none with similar name)
     (c) skip — leave 'Lisa' unresolved
   ```
   User picks `(a)`. Invoke `/people` reactive create with name `Lisa` → returns handle `lisa`. Append `lisa` to the task's `people:` list.
9. Prompt `checkin` (enum): `daily`, `weekly`, `biweekly`, `monthly`, `none` (default). User picks `weekly`. Skill auto-sets `next_checkin: today + 7 days`.
10. Build slug from title: `prep-board-deck`.
11. Write `~/.pmos/tasks/items/0001-prep-board-deck.md` with collected fields.
12. Apply Phase 12 (rebuild INDEX).
13. Output: `Added #0001 (execution, leverage): "Prep board deck" — due {Friday-date}, workstream board-q2, people: mark-davis, lisa, checkin weekly (next 2026-05-02).`

### Scenario: `/mytasks add Quick standalone task` (skip everything optional)

Expected:
1. Allocate id.
2. Prompt importance. User: `<enter>` (neutral default).
3. Prompt type. User: `<enter>` (execution default).
4. Prompt workstream. User: `skip` or `<enter>` (empty).
5. Prompt due. User: `skip`.
6. Prompt people. User: `skip`.
7. Prompt checkin. User: `<enter>` (none default).
8. Write item with frontmatter only, no body, all optional fields empty.
9. Output: `Added #{id} (execution, neutral): "Quick standalone task".` (No clauses since nothing optional was set.)
````

- [ ] **Step 2: Add Phase 3 to SKILL.md**

Replace the marker with Phase 3 + remaining marker:

````markdown
## Phase 3: Rich Capture (`add`)

Triggered by `/mytasks add <text>`. Interactive — collects rich attributes upfront via `_shared/interactive-prompts.md`.

### Step 1: Allocate id and resolve `~/.pmos/tasks/items/`

Same as Phase 2 Steps 1-2.

### Step 2: Walk through prompts per `_shared/interactive-prompts.md`

Ask in this order, ONE field at a time:

1. **`importance`** — enum. Options: `leverage`, `neutral` (default), `overhead`.
2. **`type`** — enum. Options: `execution` (default if no keyword inferred from `<text>`; otherwise the inferred value is the default), `follow-up`, `reminder`, `idea`, `read`, `call`.
3. **`workstream`** — free string. Default: value from current repo's `.pmos/settings.yaml` `workstream:` key if present, else empty. Skippable.
4. **`due`** — date input. Format hint: `YYYY-MM-DD or "Friday", "tomorrow", "in 3 days"`. Parse per `inference-heuristics.md` date rules. Skippable.
5. **`people`** — comma-separated names or handles. For each token (after stripping any `@` prefix), call `/people find`:
   - **Single match:** add the resolved handle silently.
   - **Multiple matches:** present a multi-option prompt per `_shared/interactive-prompts.md`:
     ```
     '{token}' matches multiple people — which one?
       (a) {handle-1} ({name})
       (b) {handle-2} ({name})
       ...
       (c) skip — leave '{token}' unresolved
     ```
     User picks one; add that handle. If "skip", leave unresolved (collect for warning).
   - **No match:** present a multi-option prompt:
     ```
     No match for '{token}' — what would you like to do?
       (a) create new person '{token}'
       (b) pick existing: {ranked-list-of-near-matches-or-"(none with similar name)"}
       (c) skip — leave '{token}' unresolved
     ```
     User picks. If `(a)`, invoke `/people` reactive create (per `/people` Phase 3 reactive entry point) with the name token; receive the new handle and add it. If `(b)` and there are near-matches, prompt to select; add the chosen handle. If `(c)` or no near-matches in `(b)`, leave unresolved.
6. **`checkin`** — enum. Options: `none` (default), `daily`, `weekly`, `biweekly`, `monthly`. If user picks any non-`none` cadence, also set `next_checkin: today + cadence` per Phase 10 cadence math.

### Step 3: Build slug from `<text>`

Same slug rules as Phase 2 Step 4.

### Step 4: Write the item file

Path: `~/.pmos/tasks/items/{id}-{slug}.md`. Frontmatter as in Phase 2 Step 5, but with all collected values from Step 2. Skipped fields are written as bare keys with no value.

### Step 5: Regenerate INDEX

Apply Phase 12. Same fail-soft semantics as Phase 2 Step 6.

### Step 6: Report

Build a report line:

```
Added #{id} ({type}, {importance}): "{title}"
```

Append clauses (` — ` separated) for any non-default values:
- `due {due}`
- `workstream {workstream}`
- `people: {comma-separated handles}`
- `checkin {cadence} (next {next_checkin})`

Then list any unresolved person tokens on indented lines (same format as Phase 2 Step 7).
````

Add back the marker:

```markdown
(Phases 4, 5, 6, 7, 8, 9, 10, 11 are added in subsequent tasks.)
```

- [ ] **Step 3: Walk through rich-capture scenarios manually**

Read Phase 3 + `_shared/interactive-prompts.md` and confirm:
- The unknown-person three-option flow is correctly defined and integrates with `/people` reactive create.
- The multi-match person flow correctly disambiguates (no silent first-match guess).
- Skip semantics are honored at every prompt.
- The default for `type:` is the inferred type if `<text>` matches a keyword, else `execution`.

- [ ] **Step 4: Commit**

```bash
git add plugins/pmos-toolkit/skills/mytasks/SKILL.md plugins/pmos-toolkit/skills/mytasks/tests/scenarios.md
git commit -m "feat(pmos-toolkit/mytasks): add rich capture with unknown-person flow (Phase 3)"
```

---

## Task 9: `/mytasks` Phase 4 — filtered list + Phase 5 — named views

**Files:**
- Modify: `plugins/pmos-toolkit/skills/mytasks/SKILL.md` (add Phase 4 + Phase 5)
- Modify: `plugins/pmos-toolkit/skills/mytasks/tests/scenarios.md` (add list/named-view scenarios)

- [ ] **Step 1: Add scenarios for filtered list and named views**

Append:

````markdown

## Fixture: with-tasks (continued — list & named views)

### Scenario: `/mytasks list` (no flags)

Expected:
- Read INDEX.md.
- Render flat sorted list (importance leverage > neutral > overhead → due asc → updated desc).
- Output table columns: id, type, status, due, next_checkin, title, workstream.
- Order: 0001, 0002, 0004, 0003.

### Scenario: `/mytasks list --status pending`

Expected:
- Filter to `status: pending`. From with-tasks: 0002, 0004 (0001 is in-progress, 0003 is waiting).
- Source: INDEX.md (status is an INDEX column).
- Render flat sorted: 0002 first (has due), 0004 second.

### Scenario: `/mytasks list --workstream platform-q3 --importance leverage`

Expected:
- AND filter: workstream platform-q3 AND importance leverage.
- Match: 0001 only.
- Source: INDEX.md (both filters map to INDEX columns; importance is the bucket).
- Output: single-row table.

### Scenario: `/mytasks list --label reading` (label not in INDEX)

Expected:
- Filter requires reading item files (labels not in INDEX).
- Read all items, filter to those whose `labels:` contains `reading`. Match: 0004.
- Output: single row.

### Scenario: `/mytasks list --person sarah-chen` (people not in INDEX)

Expected:
- Filter requires reading item files (people not in INDEX).
- Read all items, filter to those whose `people:` contains `sarah-chen`. Match: 0001, 0002.
- Output: two-row table, sorted by importance bucket (0001 leverage first, then 0002 neutral).

### Scenario: `/mytasks today` (assume today = 2026-05-01)

Expected:
- Equivalent to `/mytasks list --due today`.
- INDEX.md filter: `due: 2026-05-01`. Match: 0002.
- Output: single row.

### Scenario: `/mytasks week` (assume today = 2026-04-25)

Expected:
- Equivalent to `/mytasks list --due this-week`.
- "this-week" window: today through today + 7 days, i.e., 2026-04-25 to 2026-05-02.
- INDEX.md filter: `due` in window. Match: 0002 (due 2026-05-01).
- Output: single row.

### Scenario: `/mytasks overdue` (assume today = 2026-06-01)

Expected:
- Equivalent to `/mytasks list --due overdue`.
- Filter: `due < today` AND `status` NOT in (completed, dropped). All due dates are before 2026-06-01: 0001 (2026-05-12), 0002 (2026-05-01). 0003, 0004 have no due — excluded.
- Output: 2 rows.

### Scenario: `/mytasks waiting`

Expected:
- Equivalent to `/mytasks list --status waiting`.
- Match: 0003.
- Output: single row.

### Scenario: `/mytasks checkins` (today = 2026-05-08)

Expected:
- Equivalent to `/mytasks list --checkin-due`.
- Filter: `next_checkin <= today`. Match: 0002 (next_checkin 2026-05-08).
- Output: single row.

### Scenario: `/mytasks for sarah-chen`

Expected:
- Equivalent to `/mytasks list --person sarah-chen`.
- Reads item files. Match: 0001, 0002.

### Scenario: `/mytasks in platform-q3`

Expected:
- Equivalent to `/mytasks list --workstream platform-q3`.
- INDEX.md filter. Match: 0001, 0002.

### Scenario: `/mytasks list --status open` (invalid enum value)

Expected:
- Validate against status enum. `open` is not in the list.
- Output: `Unknown status 'open'. Allowed: pending, in-progress, waiting, completed, dropped.`
- No render.
````

- [ ] **Step 2: Add Phases 4 and 5 to SKILL.md**

Replace the marker with both phases + remaining marker:

````markdown
## Phase 4: Filtered List

Triggered by `/mytasks list [flags]`.

### Recognized flags (all optional, all combinable; AND semantics)

| Flag | Effect | INDEX-served? |
|---|---|---|
| `--status <pending\|in-progress\|waiting\|completed\|dropped>` | Filter by status | yes |
| `--type <execution\|follow-up\|reminder\|idea\|read\|call>` | Filter by type | yes |
| `--importance <leverage\|neutral\|overhead>` | Filter by LNO bucket | yes (bucket header) |
| `--workstream <slug>` | Filter by workstream | yes |
| `--person <handle>` | Filter by handle in `people:` | NO — read item files |
| `--label <name>` | Filter by label in `labels:` | NO — read item files |
| `--due <today\|this-week\|overdue\|next-7\|next-30>` | Date-window filter on `due:` | yes |
| `--checkin-due` | `next_checkin <= today` | yes |
| `--include-done` | Include `completed`, `dropped` (excluded by default) | requires reading archive too if set |

### Step 1: Choose source

If all provided flags are INDEX-served (per the table above) AND `--include-done` is NOT set, use `~/.pmos/tasks/INDEX.md` as the source. Otherwise, glob `~/.pmos/tasks/items/*.md` and parse frontmatter for each. If `--include-done` is set, also glob `~/.pmos/tasks/archive/**/*.md`.

### Step 2: Validate flag values against enums

Reject unknown enum values with: `Unknown {flag-name} '{value}'. Allowed: {comma-separated list}.` No render.

### Step 3: Apply filters and sort

AND semantics across flags. Default sort: `due` ascending (no-due last) → `updated` descending. Importance is the **grouping** key for the default `/mytasks` no-arg view; `list` renders flat (no grouping) unless explicitly grouped (not a v1 feature).

For `--due` window flags:
- `today` → `due == today`
- `this-week` → `today <= due <= today + 7`
- `overdue` → `due < today` AND `status` NOT in (completed, dropped)
- `next-7` → `today <= due <= today + 7`
- `next-30` → `today <= due <= today + 30`

### Step 4: Render

Render a markdown table with columns `id | type | status | due | next_checkin | title | workstream`.

For person- or label-filtered views, additionally include the relevant column (`people` or `labels`) since those flags read item files anyway.

If 0 matches: `No items match.`

---

## Phase 5: Named Views

Triggered by `/mytasks today`, `/mytasks week`, `/mytasks overdue`, `/mytasks waiting`, `/mytasks checkins`, `/mytasks for <handle>`, `/mytasks in <workstream>`.

Each named view dispatches to Phase 4 with the equivalent flags:

| Named view | Equivalent `list` invocation |
|---|---|
| `/mytasks today` | `list --due today` |
| `/mytasks week` | `list --due this-week` |
| `/mytasks overdue` | `list --due overdue` |
| `/mytasks waiting` | `list --status waiting` |
| `/mytasks checkins` | `list --checkin-due` |
| `/mytasks for <handle>` | `list --person <handle>` |
| `/mytasks in <workstream>` | `list --workstream <workstream>` |

The output is identical to the equivalent `list` invocation. No special formatting.
````

Add back the marker:

```markdown
(Phases 6, 7, 8, 9, 10, 11 are added in subsequent tasks.)
```

- [ ] **Step 3: Walk through scenarios manually**

Read Phase 4 + Phase 5 and confirm:
- `--label` and `--person` correctly trigger item-file reads (not INDEX).
- `--due overdue` correctly excludes completed/dropped items.
- Named views produce IDENTICAL output to their `list --flag` equivalents (no accidental divergence).
- Enum validation messages match the format used in `_shared/interactive-prompts.md`.

- [ ] **Step 4: Commit**

```bash
git add plugins/pmos-toolkit/skills/mytasks/SKILL.md plugins/pmos-toolkit/skills/mytasks/tests/scenarios.md
git commit -m "feat(pmos-toolkit/mytasks): add filtered list + named views (Phases 4-5)"
```

---

## Task 10: `/mytasks` Phases 6, 7, 8 — show, set, refine

**Files:**
- Modify: `plugins/pmos-toolkit/skills/mytasks/SKILL.md` (add Phases 6, 7, 8)
- Modify: `plugins/pmos-toolkit/skills/mytasks/tests/scenarios.md` (add scenarios)

- [ ] **Step 1: Add scenarios for show/set/refine**

Append:

````markdown

### Scenario: `/mytasks show 1` (with-tasks fixture)

Expected:
- Normalize id `1` → `0001`.
- Locate `~/.pmos/tasks/items/0001-*.md`.
- Render the file content verbatim, fenced as markdown.

### Scenario: `/mytasks show 999` (with-tasks fixture)

Expected:
- Search items/, search archive/. Not found.
- Find existing items whose id starts with the same digit prefix (`9` → none in fixture).
- Output: `No item with id 0999. Closest matches by prefix: (none). Run /mytasks list to see all items.`

### Scenario: `/mytasks set 2 importance=leverage` (with-tasks fixture)

Expected:
- Validate `leverage` against importance enum. Pass.
- Load 0002 file, update `importance: leverage`, set `updated:` to today, write back.
- Apply Phase 12.
- Output: `Updated #0002: importance = leverage.`

### Scenario: `/mytasks set 2 status=invalid_status`

Expected:
- Validate against status enum. Fail.
- Output: `Unknown status 'invalid_status'. Allowed: pending, in-progress, waiting, completed, dropped.`
- No write.

### Scenario: `/mytasks set 2 id=99`

Expected:
- `id` is skill-managed.
- Output: `Field 'id' cannot be set directly. The skill manages it.`
- No write.

### Scenario: `/mytasks set 2 title="Call sarah on Q3 roadmap"`

Expected:
- Edit `title:`.
- ALSO rename file: `0002-call-sarah-on-roadmap.md` → `0002-call-sarah-on-q3-roadmap.md` (preserve id prefix; recompute slug from new title).
- Set `updated:` to today.
- Apply Phase 12.
- Output: `Updated #0002: title = Call sarah on Q3 roadmap. Renamed to 0002-call-sarah-on-q3-roadmap.md.`

### Scenario: `/mytasks refine 1` (with-tasks fixture)

Expected interactive flow per `_shared/interactive-prompts.md`, same field order as Phase 3, pre-filled:
1. Prompt importance (current: `leverage`). User: `<enter>`.
2. Prompt type (current: `execution`). User: `<enter>`.
3. Prompt workstream (current: `platform-q3`). User: `<enter>`.
4. Prompt due (current: `2026-05-12`). User: `2026-05-15`. Skill parses date.
5. Prompt people (current: `sarah-chen`). User: `sarah-chen, mark-davis`. Skill resolves both via /people find.
6. Prompt checkin (current: empty/none). User: `weekly`. Skill auto-sets `next_checkin: today + 7 days`.
7. Title prompt added (refine includes title; rich-capture didn't because the title comes from `<text>` argument):
   Actually, refine SHOULD include a title prompt. Per spec §4.4 Flow C, rich-capture starts from `<text>` so title is fixed; refine starts from existing record so title is editable. Add it as the first prompt, before importance.
8. Write back, set `updated:` to today.
9. Apply Phase 12.
10. Output: `Refined #0001.`

(Implementer note: The above scenario reveals a small gap — refine should prompt for title. Update Phase 8 below to include a title prompt as the first field.)
````

- [ ] **Step 2: Add Phases 6, 7, 8 to SKILL.md**

Replace the marker with all three phases + remaining marker:

````markdown
## Phase 6: Show Item

Triggered by `/mytasks show <id>`.

### Step 1: Normalize id

Accept `42`, `0042`, or `42` with extra spaces. Zero-pad to 4 digits.

### Step 2: Locate the file

Search `~/.pmos/tasks/items/{id}-*.md`. If not found, search `~/.pmos/tasks/archive/**/{id}-*.md`.

### Step 3: Handle missing

If still not found:
1. Find existing items whose id starts with the same digit prefix.
2. Output: `No item with id {id}. Closest matches by prefix: {comma-separated list or "(none)"}. Run /mytasks list to see all items.`

### Step 4: Render

Output the file contents verbatim, fenced as markdown.

---

## Phase 7: Set Field

Triggered by `/mytasks set <id> <field>=<value>`.

### Step 1: Locate the item

Use Phase 6 normalize-and-locate. If not found, error and exit (same message).

### Step 2: Parse and validate field name

Allowed editable fields: `title`, `type`, `importance`, `status`, `workstream`, `people`, `labels`, `links`, `due`, `start`, `checkin`, `next_checkin`, `completed`.

Disallowed (skill-managed): `id`, `created`, `updated`. Reject: `Field '{field}' cannot be set directly. The skill manages it.`

Unknown fields: `Field '{field}' is not recognized. Allowed: {comma-separated list}.`

### Step 3: Validate value

| Field | Validation |
|---|---|
| `type` | Must be in `execution, follow-up, reminder, idea, read, call` |
| `importance` | Must be in `leverage, neutral, overhead` |
| `status` | Must be in `pending, in-progress, waiting, completed, dropped` |
| `checkin` | Must be in `daily, weekly, biweekly, monthly, none` |
| `due`, `start`, `next_checkin`, `completed` | ISO date `YYYY-MM-DD`, OR natural-language date parsed per `inference-heuristics.md`, OR empty (to clear) |
| `people`, `labels`, `links` | Comma-separated; written as YAML list |
| `title`, `workstream` | Free string |

For `people`: each token is treated as a literal handle (NOT fuzzy-matched). The user is responsible for typing exact handles when using `set`.

On enum violation: `Unknown {field} '{value}'. Allowed: {comma-separated list}.` No write.

### Step 4: Edit and report

Load item, update only the named field, set `updated:` to today, write back. If `title` changed, ALSO rename the file to match the new slug (preserve id prefix; recompute slug per Phase 2 Step 4 rules). Apply Phase 12. Output:

- For non-title changes: `Updated #{id}: {field} = {value}.`
- For title changes: `Updated #{id}: title = {value}. Renamed to {new-filename}.`

---

## Phase 8: Refine

Triggered by `/mytasks refine <id>`. Interactive — pre-filled walk through all editable fields.

### Step 1: Locate the item

Use Phase 6 normalize-and-locate. If not found, error and exit.

### Step 2: Walk through fields per `_shared/interactive-prompts.md`

Same field order as Phase 3, but with title added as the first prompt and each field pre-filled with its current value:

1. **`title`** — free string. Default = current title.
2. **`importance`** — enum. Default = current.
3. **`type`** — enum. Default = current.
4. **`workstream`** — free string. Default = current.
5. **`due`** — date input. Default = current.
6. **`people`** — comma-separated. Default = current. For each token, run `/people find`; on multi-match or no-match, present the same three-option flow as Phase 3 Step 2.
7. **`checkin`** — enum. Default = current. If user picks a non-`none` cadence, also prompt for whether to recompute `next_checkin: today + cadence` (default yes; only useful if the cadence is changing).

`<enter>` keeps current; explicit value replaces; `clear` (for list fields) empties.

### Step 3: Write back

Replace each field with the new value (only if changed). If `title` changed, rename the file (same logic as Phase 7 Step 4). Set `updated:` to today.

### Step 4: Regenerate INDEX, report

Apply Phase 12. Output: `Refined #{id}.` (Or `Refined #{id}. Renamed to {new-filename}.` if title changed.)
````

Add back the marker:

```markdown
(Phases 9, 10, 11 are added in subsequent tasks.)
```

- [ ] **Step 3: Walk through scenarios manually**

Read Phases 6, 7, 8 and confirm:
- Phase 6 prefix-matching for missing-id is correct (digit-prefix only, not substring).
- Phase 7 title rename preserves id prefix and uses the same slug rules as Phase 2.
- Phase 8 includes a title prompt as the first field (the gap noted in scenario step 1 above).
- `set people=...` does NOT fuzzy-match (literal handles only); refine DOES fuzzy-match (interactive).

- [ ] **Step 4: Commit**

```bash
git add plugins/pmos-toolkit/skills/mytasks/SKILL.md plugins/pmos-toolkit/skills/mytasks/tests/scenarios.md
git commit -m "feat(pmos-toolkit/mytasks): add show/set/refine (Phases 6-8)"
```

---

## Task 11: `/mytasks` Phase 9 — done/drop shortcuts + Phase 10 — checkin mechanics

**Files:**
- Modify: `plugins/pmos-toolkit/skills/mytasks/SKILL.md` (add Phases 9 + 10)
- Modify: `plugins/pmos-toolkit/skills/mytasks/tests/scenarios.md`
- Create: `plugins/pmos-toolkit/skills/mytasks/tests/fixtures/with-checkins/items/0001-weekly-1on1-prep.md`
- Create: `plugins/pmos-toolkit/skills/mytasks/tests/fixtures/with-checkins/items/0002-blocked-by-vendor.md`
- Create: `plugins/pmos-toolkit/skills/mytasks/tests/fixtures/with-checkins/INDEX.md`

- [ ] **Step 1: Create the with-checkins fixture**

Create `plugins/pmos-toolkit/skills/mytasks/tests/fixtures/with-checkins/items/0001-weekly-1on1-prep.md`:

```markdown
---
id: 0001
title: Weekly 1on1 prep
type: execution
importance: leverage
status: in-progress
workstream: platform-q3
people: [sarah-chen]
labels: []
links: []
due:
start:
checkin: weekly
next_checkin: 2026-04-25
created: 2026-04-15
updated: 2026-04-18
completed:
---

## Check-ins
- 2026-04-18: Synced on Q3 priorities, no blockers.
```

Create `plugins/pmos-toolkit/skills/mytasks/tests/fixtures/with-checkins/items/0002-blocked-by-vendor.md`:

```markdown
---
id: 0002
title: SSL cert renewal blocked on vendor
type: follow-up
importance: neutral
status: waiting
workstream:
people: []
labels: [ops]
links: []
due:
start:
checkin: weekly
next_checkin: 2026-04-25
created: 2026-04-18
updated: 2026-04-18
completed:
---
```

Create `plugins/pmos-toolkit/skills/mytasks/tests/fixtures/with-checkins/INDEX.md`:

```markdown
# My Tasks

Last regenerated: 2026-04-18

## leverage
| id | type | status | due | next_checkin | title | workstream |
|----|------|--------|-----|--------------|-------|------------|
| 0001 | execution | in-progress |  | 2026-04-25 | Weekly 1on1 prep | platform-q3 |

## neutral
| id | type | status | due | next_checkin | title | workstream |
|----|------|--------|-----|--------------|-------|------------|
| 0002 | follow-up | waiting |  | 2026-04-25 | SSL cert renewal blocked on vendor |  |

## overhead
| id | type | status | due | next_checkin | title | workstream |
|----|------|--------|-----|--------------|-------|------------|
```

- [ ] **Step 2: Add scenarios**

Append to `tests/scenarios.md`:

````markdown

### Scenario: `/mytasks done 1 wrapped this up` (with-checkins fixture, today = 2026-04-25)

Expected:
- Locate 0001.
- Set `status: completed`, `completed: 2026-04-25`, `updated: 2026-04-25`.
- Append note to `## Notes` (creating section if absent): `- 2026-04-25: wrapped this up`.
- Apply Phase 12 (item leaves INDEX since completed).
- Output: `Completed #0001: "Weekly 1on1 prep".`

### Scenario: `/mytasks done 1` (no note)

Expected: same as above but no note appended.

### Scenario: `/mytasks drop 2 vendor never responded` (with-checkins fixture, today = 2026-04-25)

Expected:
- Locate 0002.
- Set `status: dropped`, `completed: 2026-04-25`, `updated: 2026-04-25`.
- Append to `## Notes`: `- 2026-04-25: dropped — vendor never responded`.
- Apply Phase 12.
- Output: `Dropped #0002: "SSL cert renewal blocked on vendor".`

## Fixture: with-checkins (continued — checkin mechanics)

### Scenario: `/mytasks checkin 1 quick sync, all green` (today = 2026-04-25)

Expected:
- Locate 0001 (status: in-progress, checkin: weekly, next_checkin: 2026-04-25).
- Append to `## Check-ins`: `- 2026-04-25: quick sync, all green`. (Section already exists.)
- Advance `next_checkin: 2026-05-02` (today + 7 days).
- Status was `in-progress`, NOT `waiting` → no transition prompt.
- Set `updated: 2026-04-25`.
- Apply Phase 12.
- Output: `Checked in on #0001. Next checkin: 2026-05-02.`

### Scenario: `/mytasks checkin 2 still no response from vendor` (today = 2026-04-25, status: waiting)

Expected:
- Locate 0002.
- Append to `## Check-ins`: `- 2026-04-25: still no response from vendor`. (Section absent → create.)
- Advance `next_checkin: 2026-05-02`.
- Status was `waiting` → prompt: `Move to in-progress? [Y/n]`. User says `Y`.
- Set `status: in-progress`, `updated: 2026-04-25`.
- Apply Phase 12.
- Output: `Checked in on #0002. Status: waiting → in-progress. Next checkin: 2026-05-02.`

### Scenario: `/mytasks checkin 1` (no note, weekly cadence)

Expected:
- Append `- 2026-04-25:` (no note text after the colon).
- Advance next_checkin.
- Output as above.

### Scenario: cadence math edge cases

For `monthly` cadence: today = 2026-01-31. Advance to 2026-02-28 (clamp to last day of February since Feb 31 doesn't exist).
For `monthly` cadence: today = 2026-02-15. Advance to 2026-03-15.
For `daily`: today = 2026-04-25 → next 2026-04-26.
For `biweekly`: today = 2026-04-25 → next 2026-05-09.
For `none`: leave next_checkin blank.
````

- [ ] **Step 3: Add Phases 9 and 10 to SKILL.md**

Replace the marker with both phases + remaining marker:

````markdown
## Phase 9: Done / Drop Shortcuts

Triggered by `/mytasks done <id> [note]` (status → completed) or `/mytasks drop <id> [reason]` (status → dropped).

### Step 1: Locate the item

Use Phase 6 normalize-and-locate. If not found, error and exit.

### Step 2: Update frontmatter

- `status`: `completed` (for `done`) or `dropped` (for `drop`).
- `completed`: today's ISO date.
- `updated`: today's ISO date.

### Step 3: Append note to body (if `[note]` / `[reason]` provided)

Append to `## Notes` (creating the section at the END of the body if absent):

- For `done`: `- {today}: {note}`
- For `drop`: `- {today}: dropped — {reason}`

If no note/reason was provided, skip this step (no body change).

### Step 4: Regenerate INDEX, report

Apply Phase 12 (the item is now excluded from INDEX since status is completed/dropped).

Output:
- For `done`: `Completed #{id}: "{title}".`
- For `drop`: `Dropped #{id}: "{title}".`

---

## Phase 10: Check-in

Triggered by `/mytasks checkin <id> [note]`. Append a check-in entry, advance `next_checkin`, prompt status transition if `waiting`.

### Step 1: Locate the item

Use Phase 6 normalize-and-locate. If not found, error and exit.

### Step 2: Append to `## Check-ins` body section

If `## Check-ins` section exists, append a new line at the end of the section:
`- {today}: {note}` (or `- {today}:` with empty trailing note if no note arg).

If `## Check-ins` does not exist, create it at the end of the body:
```markdown

## Check-ins
- {today}: {note}
```

### Step 3: Advance `next_checkin`

If `checkin:` cadence is set:
| Cadence | New `next_checkin` |
|---|---|
| `daily` | today + 1 day |
| `weekly` | today + 7 days |
| `biweekly` | today + 14 days |
| `monthly` | today + 1 calendar month, clamped to the last day of the target month if necessary (e.g., Jan 31 → Feb 28; Aug 31 → Sep 30) |
| `none` | leave `next_checkin:` blank |

If `checkin:` is not set or empty, leave `next_checkin:` unchanged (the user hasn't enabled a cadence).

### Step 4: Status transition prompt

If `status:` was `waiting` BEFORE this checkin, prompt the user:

```
Move to in-progress? [Y/n]
```

(Use `_shared/interactive-prompts.md` primary path with a yes/no choice if `AskUserQuestion` is available; otherwise plain text prompt.)

- `Y` (or `<enter>` for default) → set `status: in-progress`.
- `n` → leave status as `waiting`.

For other statuses (`pending`, `in-progress`, `completed`, `dropped`), do NOT prompt; status stays.

### Step 5: Update `updated`, regenerate INDEX, report

Set `updated:` to today. Apply Phase 12.

Output (without status transition):
```
Checked in on #{id}. Next checkin: {next_checkin or "not scheduled"}.
```

Output (with status transition from waiting → in-progress):
```
Checked in on #{id}. Status: waiting → in-progress. Next checkin: {next_checkin or "not scheduled"}.
```
````

Add back the marker:

```markdown
(Phase 11 is added in the next task.)
```

- [ ] **Step 4: Walk through scenarios manually**

Read Phases 9 + 10 and confirm:
- Done/drop correctly remove items from INDEX (since INDEX excludes completed/dropped per Phase 12 Step 2).
- Checkin cadence math is correct (especially the monthly clamp).
- Waiting → in-progress prompt fires only when status was waiting (not on other statuses).
- Notes appended in the correct format (`- {date}: {text}` for both Notes and Check-ins).

- [ ] **Step 5: Commit**

```bash
git add plugins/pmos-toolkit/skills/mytasks/
git commit -m "feat(pmos-toolkit/mytasks): add done/drop shortcuts + checkin mechanics (Phases 9-10)"
```

---

## Task 12: `/mytasks` Phase 11 — archive

**Files:**
- Modify: `plugins/pmos-toolkit/skills/mytasks/SKILL.md` (add Phase 11)
- Modify: `plugins/pmos-toolkit/skills/mytasks/tests/scenarios.md`
- Create: `plugins/pmos-toolkit/skills/mytasks/tests/fixtures/with-archive/items/0010-recent-done-task.md`
- Create: `plugins/pmos-toolkit/skills/mytasks/tests/fixtures/with-archive/items/0011-old-done-task.md`
- Create: `plugins/pmos-toolkit/skills/mytasks/tests/fixtures/with-archive/items/0012-old-dropped-task.md`
- Create: `plugins/pmos-toolkit/skills/mytasks/tests/fixtures/with-archive/items/0013-active-task.md`
- Create: `plugins/pmos-toolkit/skills/mytasks/tests/fixtures/with-archive/INDEX.md`

- [ ] **Step 1: Create the with-archive fixture**

Today reference for the fixture: 2026-04-25. "Old" = `updated:` more than 30 days ago.

Create `plugins/pmos-toolkit/skills/mytasks/tests/fixtures/with-archive/items/0010-recent-done-task.md`:

```markdown
---
id: 0010
title: Recent done task
type: execution
importance: neutral
status: completed
workstream:
people: []
labels: []
links: []
due:
start:
checkin:
next_checkin:
created: 2026-04-15
updated: 2026-04-20
completed: 2026-04-20
---
```

(Updated 5 days ago — NOT eligible for archive.)

Create `plugins/pmos-toolkit/skills/mytasks/tests/fixtures/with-archive/items/0011-old-done-task.md`:

```markdown
---
id: 0011
title: Old done task
type: execution
importance: neutral
status: completed
workstream:
people: []
labels: []
links: []
due:
start:
checkin:
next_checkin:
created: 2026-02-01
updated: 2026-02-15
completed: 2026-02-15
---
```

(Updated 69 days ago — eligible. Q1 2026.)

Create `plugins/pmos-toolkit/skills/mytasks/tests/fixtures/with-archive/items/0012-old-dropped-task.md`:

```markdown
---
id: 0012
title: Old dropped task
type: idea
importance: overhead
status: dropped
workstream:
people: []
labels: []
links: []
due:
start:
checkin:
next_checkin:
created: 2026-02-10
updated: 2026-02-20
completed: 2026-02-20
---
```

(Updated 64 days ago — eligible. Q1 2026.)

Create `plugins/pmos-toolkit/skills/mytasks/tests/fixtures/with-archive/items/0013-active-task.md`:

```markdown
---
id: 0013
title: Active task
type: execution
importance: leverage
status: in-progress
workstream:
people: []
labels: []
links: []
due:
start:
checkin:
next_checkin:
created: 2026-04-20
updated: 2026-04-22
completed:
---
```

(Active — never eligible regardless of age.)

Create `plugins/pmos-toolkit/skills/mytasks/tests/fixtures/with-archive/INDEX.md`:

```markdown
# My Tasks

Last regenerated: 2026-04-22

## leverage
| id | type | status | due | next_checkin | title | workstream |
|----|------|--------|-----|--------------|-------|------------|
| 0013 | execution | in-progress |  |  | Active task |  |

## neutral
| id | type | status | due | next_checkin | title | workstream |
|----|------|--------|-----|--------------|-------|------------|

## overhead
| id | type | status | due | next_checkin | title | workstream |
|----|------|--------|-----|--------------|-------|------------|
```

(Note: completed/dropped items 0010, 0011, 0012 are NOT in INDEX per Phase 12 Step 2 logic, but they DO exist in `items/`.)

- [ ] **Step 2: Add scenarios**

Append:

````markdown

## Fixture: with-archive

Four items: 0010 (recent done, 5 days), 0011 (old done, 69 days, Q1), 0012 (old dropped, 64 days, Q1), 0013 (active).

### Scenario: `/mytasks archive` (today = 2026-04-25, no --quarter flag)

Expected:
- Eligible: status in (completed, dropped) AND today - updated > 30 days.
- 0010: completed, 5 days → NOT eligible.
- 0011: completed, 69 days → eligible. Target = year-of-updated 2026, quarter-of-updated Q1 → `2026-Q1`.
- 0012: dropped, 64 days → eligible. Target = `2026-Q1`.
- 0013: in-progress → NOT eligible.
- Move 0011 to `~/.pmos/tasks/archive/2026-Q1/0011-old-done-task.md`.
- Move 0012 to `~/.pmos/tasks/archive/2026-Q1/0012-old-dropped-task.md`.
- Apply Phase 12 (INDEX unchanged since archived items were already excluded).
- Output: `Archived 2 items: #0011 → 2026-Q1, #0012 → 2026-Q1.`

### Scenario: `/mytasks archive --quarter 2026-Q2` (today = 2026-04-25)

Expected:
- Same eligibility check.
- BUT target overridden to `2026-Q2` for both eligible items (--quarter override).
- Move 0011 and 0012 to `~/.pmos/tasks/archive/2026-Q2/`.
- Output: `Archived 2 items: #0011 → 2026-Q2, #0012 → 2026-Q2.`

### Scenario: `/mytasks archive` (today = 2026-04-25, with-tasks fixture which has zero eligible items)

Expected:
- 0001 (in-progress), 0002 (pending), 0003 (waiting), 0004 (pending) — all active, none eligible.
- No moves.
- Output: `Archived 0 items: nothing eligible.`
````

- [ ] **Step 3: Add Phase 11 to SKILL.md**

Replace the marker with Phase 11:

````markdown
## Phase 11: Archive

Triggered by `/mytasks archive [--quarter Q]`.

### Step 1: Determine target quarter

If `--quarter <Q>` is provided (format `YYYY-QN`, validated via regex `^[0-9]{4}-Q[1-4]$`), use it for the destination directory for ALL eligible items.

Otherwise, derive per-item: target = `{year-of-updated}-Q{quarter-of-updated}` based on the item's `updated:` date. Quarter math: month 1-3 → Q1, 4-6 → Q2, 7-9 → Q3, 10-12 → Q4.

### Step 2: Collect eligible items

For each file in `~/.pmos/tasks/items/*.md`:
- Parse frontmatter.
- Eligible if `status` in (`completed`, `dropped`) AND age (today - `updated:`) > 30 days.

### Step 3: Move

For each eligible item:
- Create `~/.pmos/tasks/archive/{quarter}/` if absent (`mkdir -p`).
- Move `~/.pmos/tasks/items/{file}` → `~/.pmos/tasks/archive/{quarter}/{file}` (use `mv`; if `~/.pmos/` is a git repo, prefer `git mv` to preserve history).

### Step 4: Regenerate INDEX, report

Apply Phase 12 (archive items are already excluded from INDEX, so this is mostly a no-op refresh — but ensures `Last regenerated:` is updated).

Output:
- If N > 0: `Archived {N} items: {comma-separated list of "#{id} → {quarter}"}.`
- If N = 0: `Archived 0 items: nothing eligible.`
````

- [ ] **Step 4: Walk through scenarios manually**

Read Phase 11 and confirm:
- Eligibility correctly checks BOTH status AND age.
- Quarter derivation per-item works (each item can land in a different quarter).
- `--quarter` override correctly applies to all items.
- Move uses `git mv` when in a git repo (since the user can `git init ~/.pmos/`).

- [ ] **Step 5: Commit**

```bash
git add plugins/pmos-toolkit/skills/mytasks/
git commit -m "feat(pmos-toolkit/mytasks): add archive (Phase 11)"
```

---

## Task 13: `/backlog` Phase 5 refactor — point at `_shared/interactive-prompts.md`

**Files:**
- Modify: `plugins/pmos-toolkit/skills/backlog/SKILL.md` (Phase 5 wording + References block)

This is a text-only refactor. No behavior change for `AskUserQuestion` users; strict UX improvement in fallback environments. The shared reference is shipped (Task 1), so this just points at it.

- [ ] **Step 1: Read the current Phase 5 content**

Run: `grep -n "## Phase 5" plugins/pmos-toolkit/skills/backlog/SKILL.md`
Expected: returns the line number of `## Phase 5: Refine`.

Read the surrounding ~30 lines starting at that line to see the current Phase 5 wording.

- [ ] **Step 2: Update Phase 5 to point at the shared reference**

Edit `plugins/pmos-toolkit/skills/backlog/SKILL.md`. The current text contains:

```
Triggered by `/backlog refine <id>`. Interactive — use `AskUserQuestion` where available; otherwise, present the prompts as a list and collect a single response, parsing each section.
```

Replace with:

```
Triggered by `/backlog refine <id>`. Interactive — follow `_shared/interactive-prompts.md` for the prompting protocol (primary path: `AskUserQuestion`; fallback: one question at a time with numbered responses).
```

The rest of Phase 5 (Steps 1-4) stays unchanged.

- [ ] **Step 3: Add the shared reference to the References block**

Find the `## References` section near the top of `plugins/pmos-toolkit/skills/backlog/SKILL.md`. Currently:

```
## References

- `schema.md` — item file shape, enum values, `INDEX.md` format
- `inference-heuristics.md` — keyword → type table for quick-capture
- `pipeline-bridge.md` — how `--backlog <id>` integrates with pipeline skills
```

Add one line:

```
- `_shared/interactive-prompts.md` — interactive prompting protocol used by Phase 5
```

So the section becomes:

```
## References

- `schema.md` — item file shape, enum values, `INDEX.md` format
- `inference-heuristics.md` — keyword → type table for quick-capture
- `pipeline-bridge.md` — how `--backlog <id>` integrates with pipeline skills
- `_shared/interactive-prompts.md` — interactive prompting protocol used by Phase 5
```

- [ ] **Step 4: Verify the change is text-only and minimal**

Run: `git diff plugins/pmos-toolkit/skills/backlog/SKILL.md`
Expected: 2 small hunks — Phase 5 sentence change, References block addition. No other changes.

- [ ] **Step 5: Walk through `/backlog refine` mentally**

Read the updated Phase 5 + `_shared/interactive-prompts.md` and confirm:
- The shared reference's primary path (`AskUserQuestion`) produces the same behavior as before for Claude Code users.
- The shared reference's fallback path (one-at-a-time numbered) is a strict improvement over the previous "list of prompts, single response" fallback.
- All Phase 5 Steps 2 (Collect updates) field order remains intact (title, context, ACs, priority, score, labels).

- [ ] **Step 6: Commit**

```bash
git add plugins/pmos-toolkit/skills/backlog/SKILL.md
git commit -m "refactor(pmos-toolkit/backlog): point Phase 5 at shared interactive-prompts reference"
```

---

## Task 14: Plugin manifest version bumps + final integration verification

**Files:**
- Modify: `plugins/pmos-toolkit/.claude-plugin/plugin.json` (version bump)
- Modify: `plugins/pmos-toolkit/.codex-plugin/plugin.json` (mirror version bump)

- [ ] **Step 1: Bump claude-plugin version**

Edit `plugins/pmos-toolkit/.claude-plugin/plugin.json`. Change:

```json
"version": "1.6.0",
```

to:

```json
"version": "1.7.0",
```

- [ ] **Step 2: Bump codex-plugin version (mirror)**

Edit `plugins/pmos-toolkit/.codex-plugin/plugin.json` to set the same `"version": "1.7.0"`.

- [ ] **Step 3: Verify both files are at 1.7.0**

Run: `grep '"version"' plugins/pmos-toolkit/.claude-plugin/plugin.json plugins/pmos-toolkit/.codex-plugin/plugin.json`
Expected: both files show `"version": "1.7.0",`.

- [ ] **Step 4: Verify hard isolation from `/backlog`** (success criterion #12)

Run: `grep -rn "backlog" plugins/pmos-toolkit/skills/mytasks/ plugins/pmos-toolkit/skills/people/`
Expected: only matches in scenarios.md or schema.md that EXPLICITLY mention `/backlog` as the OTHER skill (e.g., "distinct from /backlog"). No code paths in either skill should READ or WRITE `<repo>/backlog/` or `~/.pmos/backlog/`.

If any unexpected match: investigate and remove. The two skills must be code-isolated.

- [ ] **Step 5: Verify shared reference is consumed by all three SKILL.md files**

Run: `grep -l "_shared/interactive-prompts.md" plugins/pmos-toolkit/skills/`
Expected: 3 matches — `mytasks/SKILL.md`, `people/SKILL.md`, `backlog/SKILL.md`.

- [ ] **Step 6: Verify all 12 success criteria from the spec are addressable**

Walk through `docs/superpowers/specs/2026-04-25-mytasks-skill-design.md` §1 success criteria 1-12. For each, confirm a SKILL.md phase or scenario covers it:

1. **Quick-capture single tool-call** → mytasks Phase 2, scenarios in Task 7.
2. **Rich-capture works on AskUserQuestion AND falls back** → mytasks Phase 3 + `_shared/interactive-prompts.md`. Manual verification in Claude Code + one fallback environment is a post-implementation step (not in this plan; flag for /verify).
3. **List filters compose with AND** → mytasks Phase 4, scenarios in Task 9.
4. **Named views resolve correctly** → mytasks Phase 5, scenarios in Task 9.
5. **Default view groups by importance** → mytasks Phase 1 + Phase 12 grouping logic.
6. **Person fuzzy-match works** → people Phase 2 + lookup.md, scenarios in Task 3.
7. **Reactive person creation writes minimal records** → people Phase 3 reactive entry point, scenario in Task 4.
8. **Check-in mechanics** → mytasks Phase 10, scenarios in Task 11.
9. **Archive correctness** → mytasks Phase 11, scenarios in Task 12.
10. **`/backlog` Phase 5 still works identically in Claude Code** → Task 13 manual walkthrough.
11. **INDEX.md is regenerable** → mytasks Phase 12, people Phase 8.
12. **Hard isolation from `/backlog`** → grep verified in this task Step 4.

For #2 specifically: the post-implementation environment-specific verification belongs in /verify, not this plan. Note in the commit message that this is the only criterion not directly tested by scenarios.

- [ ] **Step 7: Final commit + version bump message**

```bash
git add plugins/pmos-toolkit/.claude-plugin/plugin.json plugins/pmos-toolkit/.codex-plugin/plugin.json
git commit -m "chore(pmos-toolkit): bump to v1.7.0 for /mytasks + /people skills"
```

---

## Final Verification Checklist

After all tasks complete, run these checks before declaring the plan done:

- [ ] `git log --oneline pmos-toolkit-mytasks-base..HEAD` shows ~14 commits, one per task, in order.
- [ ] All four new files in `plugins/pmos-toolkit/skills/mytasks/` exist (SKILL.md, schema.md, inference-heuristics.md, tests/scenarios.md) plus 4 fixture directories.
- [ ] All four new files in `plugins/pmos-toolkit/skills/people/` exist (SKILL.md, schema.md, lookup.md, tests/scenarios.md) plus 3 fixture directories.
- [ ] `_shared/interactive-prompts.md` exists at `plugins/pmos-toolkit/skills/_shared/`.
- [ ] `/backlog` SKILL.md has the updated Phase 5 wording and References entry.
- [ ] Both plugin.json files at 1.7.0.
- [ ] Manual smoke test: install the plugin in a Claude Code session, run `/mytasks Test capture`, verify a file appears at `~/.pmos/tasks/items/0001-test-capture.md` and INDEX.md is generated. Then `/people add Test User`, verify `~/.pmos/people/test-u.md`. Then `/mytasks` to see the daily view.
- [ ] Manual smoke test: `/backlog refine <id>` in the current session — verify the interactive flow uses AskUserQuestion as before (no behavior regression).
