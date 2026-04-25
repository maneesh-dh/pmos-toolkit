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

---

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

---

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

---

(Phases 6, 7, 8, 9, 10, 11 are added in subsequent tasks.)
