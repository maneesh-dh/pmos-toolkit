# /mytasks + /people Skills — Design

**Date:** 2026-04-25
**Status:** Draft (awaiting review)
**Plugin:** `pmos-toolkit`
**Scope:** Two new skills (`/mytasks`, `/people`) + one shared reference + one minor refactor of `/backlog`

---

## 1. Problem & Goals

### `/mytasks` — Personal task tracker

A lightweight, file-based personal task management system. Asana/Todoist-class personal life-OS layer, but local-first, AI-native, and embedded in the `pmos-toolkit` ecosystem. Captures and tracks:

- **Real-world tasks** (not project work items — those go to `/backlog`): meetings, follow-ups, reminders, calls, items to read, ideas worth tracking.
- **Importance, type, due dates, people involved, workstream, check-in cadence.**
- **Cross-cutting** — not tied to any repo. Tasks span workstreams, projects, and personal life.

### `/people` — Shared person/contact directory

A toolkit-wide entity store for people. Sibling to `/context`'s workstreams. Consumed by `/mytasks` (and any future people-aware skill — 1:1 notes, meeting prep, stakeholder tracking).

### Why two skills, not one

`/people` is a **cross-cutting registry**, not a `/mytasks` internal. Future skills plug in without `/mytasks` becoming an implicit dependency. `/mytasks` stays focused on its actual job (capture + list + update tasks).

### Hard boundaries

- **`/mytasks` is fully independent from `/backlog`.** No shared schema, no cross-references, no code paths reach across.
  - `/backlog` = repo-resident project work flowing into `/requirements → /spec → /plan → /execute → /verify`.
  - `/mytasks` = your personal life-OS layer.
- **`/mytasks` reads `/people` (via `find`); writes to `/people` only via explicit gates.**
- **`/people` doesn't know `/mytasks` exists.** Pure entity store.
- **Workstream awareness is read-only.** `/mytasks` reads `~/.pmos/workstreams/{slug}.md` and the active repo's `.pmos/settings.yaml` to default the `workstream:` field. Never writes either.

### Non-goals (explicit)

- ❌ No bridge to `/backlog`. The two stay independent.
- ❌ No notifications, no calendar sync, no mobile UI, no web dashboard.
- ❌ No team / multi-user features. Single-user, single-machine (synced via whatever the user does with `~/.pmos/`).
- ❌ No JSON / SQLite backing store. Markdown + YAML frontmatter only.
- ❌ No bucketed-by-status directories. Flat `items/`.
- ❌ No inline DSL for capture (`!leverage @sarah due:friday`). Two-mode capture only.
- ❌ No auto-prompt for "next follow-up" on `done`. Add later if manual usage shows the pattern.
- ❌ No migration of other pipeline skills (`/requirements`, `/spec`, `/plan`, `/verify`, `/context`) to the shared interactivity reference. `/backlog` Phase 5 only.
- ❌ No `1on1_cadence`, no Slack handle, no calendar integration on `/people`. Add fields when a second consumer needs them.

### Success criteria

The skill is "done" when all of the following hold:

1. **Quick-capture is single-tool-call.** `/mytasks Call sarah by Friday` writes one item file, regenerates one INDEX, returns one report line. No clarifying questions, no blocking, ever.
2. **Rich-capture works on AskUserQuestion AND falls back gracefully.** Manually verified in Claude Code (primary) and at least one fallback environment (Codex CLI per the platform-adaptation pattern).
3. **List filters compose with AND semantics.** `/mytasks list --workstream platform-q3 --due this-week --importance leverage` returns the intersection. Empty result returns `No items match.`, not an error.
4. **Named views resolve correctly.** `/mytasks today`, `week`, `overdue`, `waiting`, `checkins`, `for <handle>`, `in <workstream>` each match their `list --flag` equivalents.
5. **Default `/mytasks` view groups by importance** (leverage > neutral > overhead), with overdue items flagged inline.
6. **Person fuzzy-match works.** Exact / alias / initials / substring match in priority order. Quick-capture never blocks on ambiguity (flags in report). Rich-capture always prompts.
7. **Reactive person creation writes minimal records.** From `/mytasks` capture: `name` + `handle` + alias only, all other fields absent.
8. **Check-in mechanics.** `/mytasks checkin <id>` appends to `## Check-ins`, advances `next_checkin` correctly per cadence (daily / weekly / biweekly / monthly), prompts on `waiting → in-progress` transition.
9. **Archive correctness.** `/mytasks archive` moves only `completed` / `dropped` items >30 days old to `archive/YYYY-QN/`. Items remain readable via `show <id>`.
10. **`/backlog` Phase 5 still works identically in Claude Code.** No behavior regression. Fallback path improved per the shared reference.
11. **INDEX.md is regenerable.** Deleting either INDEX and running `rebuild-index` reconstructs it from items.
12. **Hard isolation from `/backlog`.** No code path in `/mytasks` reads or writes `<repo>/backlog/`. Verified by grep.

---

## 2. Storage

### Runtime data layout

```
~/.pmos/
├── workstreams/                          # owned by /context (existing)
├── people/                               # owned by /people (NEW)
│   ├── INDEX.md                          # regenerable cache
│   └── {handle}.md
└── tasks/                                # owned by /mytasks (NEW)
    ├── INDEX.md                          # regenerable cache
    ├── items/{id}-{slug}.md
    └── archive/YYYY-QN/{id}-{slug}.md
```

The directory name `tasks/` (not `mytasks/`) follows the `~/.pmos/workstreams/` precedent of using the noun, not the skill name.

### IDs

Per-skill, zero-padded sequential ints (`0001`, `0002`, …). No global coordination.

**Allocation:** scan `items/` AND `archive/**/` for `^([0-9]{4})-`, take max + 1. Per-skill counters.

### Sync

`~/.pmos/` is local by default. The user can `git init ~/.pmos/` for version history and cross-machine sync. The skill suggests this in its docs but does not enforce.

---

## 3. Schemas

### `/mytasks` item — `~/.pmos/tasks/items/{id}-{slug}.md`

```yaml
---
id: 0042                                  # 4-digit zero-padded
title: Draft Q3 OKRs for Platform team
type: execution                           # enum
importance: leverage                      # enum (LNO)
status: pending                           # enum
workstream: platform-q3                   # optional, ideally a workstream slug
people: [sarah-chen, mark-davis]          # optional list of /people handles
labels: [okrs, planning]                  # optional free-string list
links: []                                 # optional list of URLs or file paths
due: 2026-05-12                           # optional ISO date
start: 2026-05-05                         # optional ISO date
checkin: weekly                           # optional enum
next_checkin: 2026-05-02                  # optional ISO date, auto-bumped
created: 2026-04-25
updated: 2026-04-25
completed:                                # ISO date, set when status -> completed/dropped
---

## Notes
Free-form. Optional.

## Check-ins
- 2026-04-25: Synced with Sarah, on track    # auto-managed by /mytasks checkin
```

#### Enums (skill MUST validate against these and never invent new values)

| Field | Allowed values |
|---|---|
| `type` | `execution`, `follow-up`, `reminder`, `idea`, `read`, `call` |
| `importance` | `leverage`, `neutral`, `overhead` |
| `status` | `pending`, `in-progress`, `waiting`, `completed`, `dropped` |
| `checkin` | `daily`, `weekly`, `biweekly`, `monthly`, `none` |

#### Defaults on quick-capture

- `status: pending`, `importance: neutral`, `type: execution` (or inferred — see §4.2)
- `created`, `updated`: today
- `workstream:` from current repo's `.pmos/settings.yaml` if present, else absent
- All other optional fields: absent

#### Defaults on rich-capture (`/mytasks add`)

All fields prompted via `_shared/interactive-prompts.md`. Each prompt has a sensible default; `<enter>` accepts.

#### Body

Entirely freeform. The skill recognizes (but does not require) two conventional H2 sections — `## Notes` (user-written) and `## Check-ins` (skill-managed by `/mytasks checkin`). Tasks captured quickly typically have no body.

---

### `/people` record — `~/.pmos/people/{handle}.md`

```yaml
---
handle: sarah-chen                        # kebab-case, unique key, used in references
name: Sarah Chen
designation: VP Engineering               # optional — formal title
role: Eng Manager                         # optional — informal day-to-day role
working_relationship: peer                # optional enum
team: platform                            # optional
email: sarah@acme.com                     # optional
workstreams: [platform-q3]                # optional list of workstream slugs
aliases: [sarah, schen, sc]               # optional fuzzy-match seeds
created: 2026-04-25
updated: 2026-04-25
---

## Notes
Free-form. Context, prefs, history.
```

#### Enums

| Field | Allowed values |
|---|---|
| `working_relationship` | `boss`, `direct-report`, `peer`, `team-member`, `stakeholder`, `external`, `other` |

#### Defaults on **reactive** create (called from `/mytasks` capture, never user-invoked directly)

- `name` only (from the prompt that disambiguated the unknown person)
- `handle` auto-derived: `firstname-lastinitial` → falls through to `firstname-lastname` → falls through to `firstname-N` (numeric collision-resolved)
- `aliases:` seeded with the original `@token` from the task (e.g., `[sarah]`)
- All other fields absent
- `created`, `updated`: today

#### Defaults on **proactive** create (`/people add`)

All fields prompted, each skippable with `<enter>`.

---

### `INDEX.md` format

`~/.pmos/tasks/INDEX.md` is regenerable, never the source of truth. Shape:

```markdown
# My Tasks

Last regenerated: 2026-04-25

## leverage
| id | type | status | due | next_checkin | title | workstream |
|----|------|--------|-----|--------------|-------|------------|
| 0042 | call | pending | 2026-05-01 | | Call sarah about Q3 OKRs | platform-q3 |

## neutral
| id | type | status | due | next_checkin | title | workstream |
|----|------|--------|-----|--------------|-------|------------|
| ... |

## overhead
| ... |
```

Items grouped by `importance`. Within each group, sorted by `due` asc (no-due last) → `updated` desc. `completed` and `dropped` items are NOT in INDEX.md (they live only in item files; archived items move to `archive/`).

`~/.pmos/people/INDEX.md` is a single ungrouped table:

```markdown
# People

Last regenerated: 2026-04-25

| handle | name | designation | role | working_relationship | team | email |
|--------|------|-------------|------|----------------------|------|-------|
| sarah-chen | Sarah Chen | VP Engineering | Eng Manager | peer | platform | sarah@acme.com |
```

Sorted by `name` asc.

### Shared conventions

- **Filename slug:** lowercase, alphanumeric + hyphens only, max 60 chars, no leading/trailing hyphens.
- **`INDEX.md`** is regenerable, never the source of truth. Regenerated on every write op and on `<skill> rebuild-index`.
- **Date format:** ISO `YYYY-MM-DD`, all dates in local timezone.
- **Frontmatter:** unrecognized fields are preserved on edit but ignored by the skill.

---

## 4. `/mytasks` Commands & Flows

### 4.1 Command surface

| Subcommand | Purpose |
|---|---|
| `/mytasks` | Default daily view — pending + in-progress, grouped by importance |
| `/mytasks <bare text>` | **Quick capture** — single tool-call, infers what it can, never blocks |
| `/mytasks add <text>` | **Rich capture** — interactive prompt walk |
| `/mytasks list [filters]` | Filtered list (see §4.3) |
| `/mytasks today` / `week` / `overdue` / `waiting` / `checkins` | Named views (shortcuts) |
| `/mytasks for <handle>` | Shortcut: `list --person <handle>` |
| `/mytasks in <workstream>` | Shortcut: `list --workstream <slug>` |
| `/mytasks show <id>` | Render task file |
| `/mytasks set <id> <field>=<value>` | Single-field edit, validates enums |
| `/mytasks refine <id>` | Interactive multi-field walk, pre-filled |
| `/mytasks done <id> [note]` | Shortcut: status→completed, completed:→today, optional note appended |
| `/mytasks drop <id> [reason]` | Shortcut: status→dropped, completed:→today, reason appended |
| `/mytasks checkin <id> [note]` | Append check-in entry, advance `next_checkin`, prompt status change if `waiting` |
| `/mytasks archive [--quarter Q]` | Move completed/dropped >30 days old to `archive/YYYY-QN/` |
| `/mytasks rebuild-index` | Regenerate `INDEX.md` from items |

### 4.2 Quick-capture inference rules

`/mytasks <bare text>` → single tool-call, never blocks.

| Field | Inference rule | Fallback |
|---|---|---|
| `title` | Whole input, with parsed tokens stripped | — |
| `type` | Keyword match (case-insensitive, first wins): `call \| ring` → `call`; `read \| review article` → `read`; `remind \| remember` → `reminder`; `follow up \| followup \| check in with \| ping` → `follow-up`; `idea \| brainstorm` → `idea` | `execution` |
| `importance` | None — too subjective to infer | `neutral` |
| `due` | Natural-language date parse: `today`, `tomorrow`, `Friday` / `next Friday`, `EOD`, `by <date>`, `5/12`, `in 3 days` | empty |
| `people` | `@handle` tokens; for each, run `/people find` | empty |
| `workstream` | If invoked from inside a repo with `.pmos/settings.yaml` containing `workstream:`, use it | empty |
| `status` | always `pending` | — |
| `checkin` | None | empty |

#### Person resolution in quick-capture

For each `@handle` token:
- **Exact match** (handle / name / alias) → silently use the handle.
- **Multiple matches** → skip and flag as unresolved (per design Q8 decision: never block in quick mode).
- **No match** → skip and flag as unresolved.

Unresolved tokens appear in the capture report:

```
Captured #0042 (call, neutral): "Call sarah about Q3 OKRs by Friday"
  due: 2026-05-01
  workstream: platform-q3 (from current repo)
  ⚠ unresolved: @sarah — run /people add Sarah, then /mytasks set 0042 people=sarah-chen
```

#### Date parsing rule (resolves "Friday" ambiguity)

- Day-of-week names (`Monday` … `Sunday`) → next occurrence of that day, exclusive of today (so `Friday` on a Friday means the *next* Friday, not today).
- `next <day>` → same as bare day name (no semantic difference for v1; both mean "next occurrence").
- `today`, `tomorrow`, `EOD` → today / today + 1 / today.
- `in N days` → today + N.
- `by <ISO date>`, `<MM/DD>`, `<MM/DD/YYYY>` → parsed directly. `MM/DD` assumes current year; if resulting date is in the past, roll to next year.
- Resolved date appears in the capture report so the user sees what was inferred.

### 4.3 List flags

All optional, all combinable, AND semantics.

| Flag | Effect |
|---|---|
| `--status <pending\|in-progress\|waiting\|completed\|dropped>` | Filter by status |
| `--type <execution\|follow-up\|reminder\|idea\|read\|call>` | Filter by type |
| `--importance <leverage\|neutral\|overhead>` | Filter by LNO bucket |
| `--workstream <slug>` | Filter by workstream |
| `--person <handle>` | Filter by person involvement (any handle in `people:`) |
| `--label <name>` | Filter by label |
| `--due <today\|this-week\|overdue\|next-7\|next-30>` | Date-window filter on `due:` |
| `--checkin-due` | Tasks where `next_checkin <= today` |
| `--include-done` | Include `completed` and `dropped` (excluded by default) |

#### Default sort

Within any view: `due` asc (no-due last) → `updated` desc. Importance is the **grouping** key for the bare `/mytasks` view, not a within-group sort key.

#### Output shape

Default columns (match `INDEX.md`, served from cache without reading item files):

```
| id | type | status | due | next_checkin | title | workstream |
```

Person-filtered views (`/mytasks for <handle>`, `/mytasks list --person <handle>`) and label-filtered views additionally show the relevant column (`people` or `labels`) since they read item files anyway.

#### View rendering rules

| Invocation | Grouping | Source |
|---|---|---|
| `/mytasks` (no args) | Grouped by `importance` (`## leverage`, `## neutral`, `## overhead`) | INDEX.md |
| `/mytasks list` (no flags) | Flat sorted list | INDEX.md |
| `/mytasks list --<flags>` | Flat sorted list | INDEX.md when flags map to INDEX columns; item-file scan when not (see §11) |
| Named views (`today`, `week`, `overdue`, `waiting`, `checkins`) | Flat sorted list | INDEX.md |
| `/mytasks for <handle>` / `in <workstream>` | Flat sorted list | item files (`for`) / INDEX.md (`in`) |

### 4.4 Three key flows in detail

#### Flow A: Quick-capture happy path

`/mytasks Call sarah about Q3 OKRs by Friday`

1. Parse tokens: `call` (type keyword), `by Friday` (due date). Note: bare `sarah` is NOT person-tagged; only `@sarah` triggers person resolution. The string stays in the title.
2. Allocate id (scan items + archive, max + 1).
3. Resolve workstream from current repo's `.pmos/settings.yaml` if present.
4. Write `items/0042-call-sarah-about-q3-okrs-by-friday.md` with frontmatter only.
5. Regenerate `INDEX.md`.
6. Output: `Captured #0042 (call, neutral): "Call sarah about Q3 OKRs by Friday" — due 2026-05-01, workstream platform-q3 (from current repo).`

#### Flow B: Quick-capture with unknown person

`/mytasks Sync with @sarah on roadmap`

1. Parse `@sarah` → call `/people find sarah`.
2. **No match** → quick mode does NOT prompt; capture proceeds with `people: []` and flags `@sarah` as unresolved.
3. **Multiple matches** → quick mode skips and flags as unresolved.
4. **Single exact / strong match** → silently uses the handle.
5. Output: `Captured #0043 (execution, neutral): "Sync with @sarah on roadmap" ⚠ unresolved: @sarah — run /people add Sarah, then /mytasks set 0043 people=sarah-chen`.

#### Flow C: Rich-capture with new person

`/mytasks add Prep board deck`

1. Walk through prompts via `_shared/interactive-prompts.md`: importance → type → workstream → due → people → checkin.
2. At "people" prompt, user types `Sarah, Mark`.
3. For each token, call `/people find`.
4. **No match for "Sarah"** → rich mode prompts: `(a) create new person 'Sarah', (b) pick existing [list], (c) skip`.
5. If **(a)** → invoke `/people` reactive-create flow inline → returns handle → continue.
6. If **(b)** → user picks → use that handle.
7. If **(c)** → skip this person, continue.
8. After all prompts: write task, regenerate INDEX, report.

### 4.5 Check-in mechanics

`/mytasks checkin <id> [note]` does four things atomically:

1. Append `- {today}: {note}` to a `## Check-ins` body section (creating the section if absent).
2. Advance `next_checkin:` by the cadence:
   - `daily` → today + 1 day
   - `weekly` → today + 7 days
   - `biweekly` → today + 14 days
   - `monthly` → today + 1 calendar month (clamped to last day of target month if necessary, e.g., Jan 31 → Feb 28)
   - `none` → leave `next_checkin:` blank
3. If status was `waiting`, prompt: `Move to in-progress? [Y/n]`.
4. Set `updated:` to today.

### 4.6 Archive

`/mytasks archive [--quarter Q]`:

1. Determine target quarter — `--quarter <Q>` (format `YYYY-QN`) overrides; otherwise per-item, target = `{year-of-updated}-Q{quarter-of-updated}` based on item's `updated:` date.
2. Eligible items: status in `completed | dropped` AND age (today - `updated:`) > 30 days.
3. For each eligible item: create `archive/{quarter}/` if absent; `mv items/{file} archive/{quarter}/{file}`.
4. Regenerate `INDEX.md` (archive items excluded from INDEX).
5. Report: `Archived N items: {list of "#{id} -> {quarter}"}` (or `0 items: nothing eligible.`).

---

## 5. `/people` Commands & Flows

### 5.1 Command surface

| Subcommand | Purpose |
|---|---|
| `/people` | List all people (default view) |
| `/people add <name>` | **Proactive create** — interactive prompt walk |
| `/people list [--workstream <slug>] [--relationship <enum>]` | Filtered list |
| `/people show <handle-or-name>` | Render record |
| `/people find <text>` | Fuzzy-match lookup — used internally by `/mytasks` capture; also user-callable |
| `/people set <handle> <field>=<value>` | Single-field edit, validates enums |
| `/people refine <handle>` | Interactive multi-field walk, pre-filled |
| `/people rebuild-index` | Regenerate `INDEX.md` |

**Reactive create** is not a user-facing command — it's an internal entry point invoked by `/mytasks` rich-capture when the user picks "(a) create new person" at an unknown-person prompt. It writes a minimal record (name + handle + original token as alias) and returns the handle to the caller.

### 5.2 Fuzzy-match algorithm (`/people find <text>`)

Used by `/mytasks` quick-capture and rich-capture, and by users directly.

Match priority (return on first hit; ties resolved by `updated:` desc):

1. **Exact handle** match (case-insensitive).
2. **Exact alias** match (case-insensitive, against any entry in `aliases:`).
3. **Exact name** match (case-insensitive, against `name:`).
4. **Substring match** on handle / name / aliases.
5. **Initials match** — input length ≤ 3, all chars are letters → match against initials of `name:` (e.g., `sc` → `Sarah Chen`, `jpd` → `Jane Polly Doe`).

Returns:
- **0 matches** → empty list.
- **1 match** → single result.
- **N matches** → ranked list (priority tier first, then `updated:` desc).

The caller decides what to do with multiple matches (quick-capture skips, rich-capture prompts).

---

## 6. Shared Interactivity Reference

**New file: `plugins/pmos-toolkit/skills/_shared/interactive-prompts.md`**

Single source of truth for the interactive prompting protocol. Documents:

- **Primary path: `AskUserQuestion`** (Claude Code) — one structured prompt per field, with the field's allowed values as multi-choice options where applicable. Best UX, single tool-call per field. Enums always rendered as choices; free-string fields as text input; date fields with format hint.
- **Fallback path** (when `AskUserQuestion` is unavailable — Copilot / Codex / Gemini / CLI): **one question at a time as plain text with numbered responses**. Wait for user to reply with the number (or free text for non-enum fields) before asking the next question. Same field order, same defaults.
- **Skip semantics:** `<enter>` accepts the default; explicit `skip` (or option `0`) leaves the field blank.
- **Field-type rendering rules:** enum (numbered choices), free-string (text input with placeholder showing current value if any), date (ISO format hint, accept natural-language input parsed by the same rules as quick-capture), list (comma-separated, "done" terminator on multi-line variants).
- **Why this beats single-bulk-numbered-list fallback:** later answers can depend on earlier ones; cleaner conversation; easier to skip per-field with `<enter>`.

### Consumers

- `/mytasks add` (rich capture) — full field walk.
- `/mytasks refine <id>` — full field walk, pre-filled.
- `/mytasks` unknown-person prompt — three-option choice.
- `/people add` (proactive create) — full field walk.
- `/people refine <handle>` — full field walk, pre-filled.
- `/backlog refine <id>` — full field walk (refactored, see §7).

---

## 7. `/backlog` Phase 5 Refactor

**Scope:** Text-only refactor. No behavior change for `AskUserQuestion` users; strict UX improvement in fallback environments.

### Current Phase 5 wording (in `plugins/pmos-toolkit/skills/backlog/SKILL.md`)

> "interactive — use `AskUserQuestion` where available; otherwise, present the prompts as a list and collect a single response, parsing each section."

### Replacement

> "interactive — follow `_shared/interactive-prompts.md`."

Plus add `_shared/interactive-prompts.md` to `/backlog`'s `## References` block.

### Verification

- Run an interactive `/backlog refine <id>` in Claude Code: behavior unchanged (still uses `AskUserQuestion`).
- Run an interactive `/backlog refine <id>` in a fallback environment: questions arrive one at a time with numbered responses (was: single bulk numbered list).
- All other `/backlog` phases (capture, list, show, set, promote, link, archive, rebuild-index, workstream aggregator) untouched.

---

## 8. File Structure & Plugin Wiring

### Shipped artifacts

```
plugins/pmos-toolkit/skills/
├── _shared/
│   └── interactive-prompts.md            # NEW shared reference
├── mytasks/                              # NEW skill
│   ├── SKILL.md
│   ├── schema.md                         # task file shape, enums, INDEX format
│   ├── inference-heuristics.md           # quick-capture keyword/date rules
│   └── tests/                            # fixtures + test plan
├── people/                               # NEW skill
│   ├── SKILL.md
│   ├── schema.md
│   ├── lookup.md                         # fuzzy-match algorithm spec
│   └── tests/
├── backlog/
│   └── SKILL.md                          # Phase 5 refactored (one-line text change)
└── (everything else unchanged)
```

### Plugin manifest

- Bump `pmos-toolkit` plugin version (e.g., `1.6.0 → 1.7.0`).
- Add `/mytasks` and `/people` to plugin manifest skill list.

### SKILL.md descriptions (for discoverability)

**`/mytasks` description:**
> Persistent personal task tracker — distinct from Claude Code's session-scoped TaskCreate/TaskList. Use for real-world tasks (LNO importance, due dates, people, check-ins, workstream). Lives at `~/.pmos/tasks/`. Use when the user says "add a task", "what's on my plate", "tasks for sarah", "what's due this week", "check in on X", or "/mytasks".

**`/people` description:**
> Shared person/contact directory for the pmos-toolkit. Stores handle, name, designation, role, working relationship, team, email, workstreams, aliases. Consumed by `/mytasks` (and future people-aware skills). Use when the user says "add a person", "find someone", "who is X", or "/people".

---

## 9. Cross-Platform Adaptation

Both skills include the standard Platform Adaptation section:

- **No `AskUserQuestion`:** fall back per `_shared/interactive-prompts.md` — one question at a time with numbered responses. Quick-capture is unaffected (never prompts anyway).
- **No subagents:** sequential single-agent operation. Neither skill needs subagents.

---

## 10. Risks & Mitigations

| Risk | Mitigation |
|---|---|
| **Date parsing ambiguity** — "Friday" interpreted differently by different users / locales. | Rule documented in `inference-heuristics.md`: bare day-of-week = next occurrence, exclusive of today. Resolved date echoed in capture report so user sees what got inferred. |
| **Person handle collisions** — two "Sarah"s. | Handle derivation: `firstname-lastinitial` → `firstname-lastname` → `firstname-N`. Aliases on the original record cover the short forms. |
| **`~/.pmos/tasks/` not version-controlled by default** — disk failure could lose data. | `/mytasks` SKILL.md briefly suggests `git init ~/.pmos/` for sync/history. Not enforced. |
| **`/backlog` refactor regression** — Phase 5 text change accidentally drops a step. | Explicit verification step in §7. Refactor is text-only and points at a strict superset (the shared reference covers AskUserQuestion identically and improves fallback). |
| **`/mytasks` accidentally crosses into `/backlog` territory** — a task that should be a project work item. | Skill description and SKILL.md explicitly state the boundary. No bridge code path. Verified by grep at completion (success criterion #12). |
| **Workstream slug typos** in `workstream:` field — silent drift from real workstreams. | `workstream:` is free-string (intentional — user might track work outside any registered workstream). Auto-default from current repo's `.pmos/settings.yaml` covers the common case correctly. |

---

## 11. Implementation Approach

### Pure in-skill (no separate scripts shipped) for v1

All operations — capture, list, show, set, refine, done, drop, checkin, archive, rebuild-index — are implemented as **in-SKILL.md instructions** that Claude executes via `Glob`, `Read`, `Edit`, `Write`, and `Bash` tools. No Python/Bash helper scripts shipped. Consistent with `/backlog`, `/context`, and the rest of `pmos-toolkit`. Zero new dependencies.

### `INDEX.md` as the fast path for common views

`INDEX.md` already carries the most-used columns (`id, type, imp, status, due, title, workstream`) for every active item. The skill optimizes the common case by serving views from `INDEX.md` alone whenever possible:

| View | Source |
|---|---|
| Default `/mytasks` (no args) | `INDEX.md` only |
| `/mytasks today` / `week` / `overdue` | `INDEX.md` only (filter on `due` column) |
| `/mytasks waiting` | `INDEX.md` only (filter on `status` column) |
| `/mytasks checkins` | `INDEX.md` only (filter on `next_checkin` column) |
| `/mytasks list --status / --type / --importance / --workstream / --due / --checkin-due` | `INDEX.md` only |
| `/mytasks for <handle>` | requires `people:` — read item files |
| `/mytasks list --label <name>` | requires `labels:` — read item files |
| `/mytasks list --person <handle>` | requires `people:` — read item files |

**Note:** `INDEX.md` includes `next_checkin` (per §3) so `/mytasks checkins` stays fast. `people` and `labels` are list-typed and intentionally NOT in `INDEX.md` (they'd bloat the table); the rare views that need them pay the read-all-files cost.

### Upgrade path to helper scripts (B)

If list ops ever feel slow at scale (>1000 active items), the upgrade is additive and clean:
1. Drop `scripts/list.py` (or `.sh`) into `plugins/pmos-toolkit/skills/mytasks/scripts/`.
2. Replace the §4.3 in-SKILL filter-and-sort instructions with `Bash(scripts/list.py --flag value)`.
3. No schema changes, no data migration — the script reads the same item files.

This is explicitly NOT v1 scope; documented here so the upgrade path is obvious.

### Standalone CLI (C) is out of scope

A `~/.pmos/bin/mytasks` CLI for terminal use without Claude is a separate product with separate packaging concerns. Not bundled in this spec.

---

## 12. Open Questions

None — all design decisions resolved during brainstorming session. See §13 (Decision Log) for trace of each decision.

---

## 13. Appendix: Decision Log

Decisions made during the 2026-04-25 brainstorming session that locked in the design above:

| # | Decision | Rationale |
|---|---|---|
| 1 | `/mytasks` fully separate from `/backlog` | Different lifecycles; project work vs. personal life-OS |
| 2 | Storage at `~/.pmos/tasks/` | Mirrors `/context` precedent; zero config |
| 3 | Flat `items/{id}-{slug}.md` + regenerable `INDEX.md` | Mirrors `/backlog`; handles all attributes; greppable |
| 4 | Schema enums locked (see §3) | Explicit user picks during brainstorming |
| 5 | `/people` is a separate, shared skill | Cross-cutting registry; future skills plug in |
| 6 | `/people` schema includes `designation`, `working_relationship`, `email` | User-requested additions |
| 7 | Two-mode capture (quick + rich) on `/mytasks`; hybrid (reactive + proactive) on `/people` | Matches /backlog muscle memory; avoids over-prompting |
| 8 | Quick-capture inference rules (see §4.2); ambiguous person → flagged unresolved | Quick mode never blocks |
| 9 | List filters + 7 named views; default groups by importance | LNO is the user's prioritization framework |
| 10 | Update commands mirror `/backlog`; freeform body with conventional `## Notes` and `## Check-ins` sections | Personal tasks usually less ceremonious than backlog work items |
| 11 | Markdown + YAML frontmatter persistence (not JSON / SQLite) | Greppable, human-editable, git-friendly diffs, body-as-prose |
| 12 | Skill name: `/mytasks` (not `/tasks`) | Disambiguates from Claude Code's built-in `TaskCreate`/`TaskList` session tools |
| 13 | `_shared/interactive-prompts.md` shared reference; `/backlog` Phase 5 refactored to use it | Better fallback UX; one source of truth; pattern available for future skills |
| 14 | Pure in-skill implementation for v1 (no shipped scripts); `INDEX.md` extended with `next_checkin` for fast common views; helper scripts as documented upgrade path | Consistent with toolkit; zero new deps; common views stay fast; clean upgrade if needed |
