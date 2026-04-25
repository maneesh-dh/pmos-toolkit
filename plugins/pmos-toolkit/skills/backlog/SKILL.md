---
name: backlog
description: Maintain a lightweight, AI-readable backlog of features, bugs, tech-debt, and ideas inside the repo. Zero-friction quick-capture (`/backlog add ...`) plus structured tracking with status, priority, and acceptance criteria. Integrates with the requirements -> spec -> plan -> execute -> verify pipeline via explicit `--backlog <id>` linkage. Use when the user says "add to backlog", "capture this idea", "track this bug", "show the backlog", "promote a backlog item", or "what's in the backlog".
user-invocable: true
argument-hint: "[<text> | add <text> | list [filters] | show <id> | refine <id> | set <id> <field>=<value> | promote <id> | link <id> <doc> | archive | rebuild-index]"
---

# Backlog

A repo-resident, AI-readable backlog. Two jobs: (1) zero-friction capture buffer for ideas/bugs/deferred-work that surface mid-flow, (2) lightweight tracker with status, priority, and pipeline linkage.

```
                                    ┌─ deferred items ──┐
/backlog (capture)                  ↓                   │
       │                                                │
       ▼                                                │
   inbox -> ready -> /backlog promote -> /requirements -> /spec -> /plan -> /execute -> /verify
                                          (or /spec)         │        │        │          │
                                                             ↓        ↓        ↓          ↓
                                                          spec'd  planned  in-progress  done
```

**Announce at start:** "Using the backlog skill to {capture|list|refine|...}."

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:
- **No `AskUserQuestion`:** State your assumption, document it in the output, and proceed. The user reviews after completion.
- **No subagents:** Perform research and analysis sequentially as a single agent.

## References

- `schema.md` — item file shape, enum values, `INDEX.md` format
- `inference-heuristics.md` — keyword → type table for quick-capture
- `pipeline-bridge.md` — how `--backlog <id>` integrates with pipeline skills

---

## Phase 0: Subcommand Routing

Parse the user's argument to determine the subcommand. Be liberal with the form — both `/backlog add foo` and `/backlog "foo"` work for capture.

| Argument shape | Subcommand |
|---|---|
| empty | Phase 1 (show local INDEX.md) |
| `add <text>` or any free text not matching another verb | Phase 2 (quick-capture) |
| `list [flags]` | Phase 3 (filtered list) |
| `show <id>` | Phase 4 (render item) |
| `refine <id>` | Phase 5 (interactive refine) |
| `set <id> <field>=<value>` | Phase 6 (single-field edit) |
| `promote <id>` | Phase 7 (hand off to pipeline) |
| `link <id> <doc-or-pr>` | Phase 8 (manual linkage) |
| `archive [--quarter Q]` | Phase 9 (archive done/wontfix) |
| `rebuild-index` | Phase 10 (regenerate INDEX.md) |

If the first token is not a recognized verb AND the argument is non-empty, treat the whole argument as `add <text>` (frictionless capture is the priority).

---

## Phase 1: Show Local INDEX

Triggered by `/backlog` with no arguments.

### Step 1: Resolve `backlog/`

If `<repo>/backlog/INDEX.md` does not exist (or `<repo>/backlog/` is missing entirely), output:

`No backlog yet. Capture an item with /backlog add <text>.`

Then exit.

### Step 2: Validate freshness

Compare `backlog/INDEX.md`'s "Last regenerated:" date against `git log -1 --format=%cI -- backlog/items/`. If items have been modified more recently than INDEX, regenerate (apply Phase 10) before rendering.

### Step 3: Render

Output the contents of `backlog/INDEX.md` to the user.

---

## Phase 2: Quick-Capture (`add` or bare text)

Triggered by `/backlog add <text>` OR `/backlog <any free text>` (no recognized verb).

**This phase MUST complete in a single tool-call sequence with NO clarifying questions.** Wrong inference is acceptable; capture friction is not.

### Step 1: Resolve `backlog/` location

- If `<repo>/backlog/items/` exists, use it.
- Else, create `<repo>/backlog/items/` with `mkdir -p`.

(`<repo>` = git repo root, found via `git rev-parse --show-toplevel`. If not in a git repo, use the current working directory.)

### Step 2: Allocate id

Scan `backlog/items/` and `backlog/archive/**/` for filenames matching `^([0-9]{4})-`. Take the max numeric prefix; allocate `id = max + 1`. If neither directory exists or is empty, `id = 1`. Format as 4-digit zero-padded.

### Step 3: Infer type

Apply `inference-heuristics.md` to `<text>` (case-insensitive, first-match-by-order). If no keyword matches, set `type: idea` and remember to emit the fallback notice in Step 6.

### Step 4: Build slug

- Lowercase the title.
- Replace any run of non-alphanumeric chars with a single hyphen.
- Trim leading/trailing hyphens.
- Truncate to 60 characters at a hyphen boundary if possible, otherwise hard-truncate.

### Step 5: Write the item file

Path: `backlog/items/{id}-{slug}.md`

Content (frontmatter only, no body):

```yaml
---
id: {id}
title: {original text, unchanged}
type: {inferred type}
status: inbox
priority: should
labels: []
created: {today YYYY-MM-DD}
updated: {today YYYY-MM-DD}
source:
spec_doc:
plan_doc:
pr:
parent:
dependencies: []
---
```

### Step 6: Regenerate `INDEX.md`

Apply Phase 10 (rebuild-index) inline. If regeneration fails, the item file is still written — emit a warning suggesting `/backlog rebuild-index`, but DO NOT roll back the item write.

### Step 7: Report

Output exactly one line:

`Captured #{id} ({type}, should): "{title}"`

If `type` was the fallback (`idea` from rule 4 of `inference-heuristics.md`), append:

` — type inferred as 'idea' (no strong signal); use /backlog set {id} type=... to correct.`

---

## Phase 3: Filtered List

Triggered by `/backlog list [flags]`.

Recognized flags (all optional, all combinable; AND semantics):

| Flag | Effect |
|---|---|
| `--type <feature\|bug\|tech-debt\|idea>` | Filter by type |
| `--status <inbox\|ready\|spec'd\|planned\|in-progress\|done\|wontfix>` | Filter by status |
| `--priority <must\|should\|could\|maybe>` | Filter by priority |
| `--label <name>` | Item must include this label |
| `--repo <name>` | (Workstream mode only) restrict to one linked repo |
| `--workstream` | Aggregate across all repos linked to the active workstream |
| `--include-archive` | Include items in `backlog/archive/**/` |

### Step 1: Resolve scope

- Without `--workstream`: read items from `<repo>/backlog/items/` (and `archive/**/` if `--include-archive`).
- With `--workstream`: apply the workstream aggregator from Phase 11.

### Step 2: Validate flag values against enums

Reject unknown flag values with the allowed list. Example: `Unknown status 'open'. Allowed: inbox, ready, spec'd, planned, in-progress, done, wontfix.`

### Step 3: Apply filters and sort

Sort: priority bucket (must > should > could > maybe) → score desc (nulls last) → updated desc.

### Step 4: Render

Render a markdown table identical in shape to a single section of `INDEX.md`, but with no priority grouping (sorted flat list). Columns: `id | type | status | priority | title | spec | plan | pr`. In `--workstream` mode, prepend a `repo` column.

If zero matches: `No items match.`

---

## Phase 4: Show Item

Triggered by `/backlog show <id>`.

### Step 1: Normalize id

Accept `42`, `0042`, or `repo-name#0042` (workstream form). For local form, zero-pad to 4 digits.

### Step 2: Locate the file

Search `<repo>/backlog/items/{id}-*.md`. If not found, search `<repo>/backlog/archive/**/{id}-*.md`.

### Step 3: Handle missing

If still not found:

1. Find existing items whose id starts with the same digit prefix.
2. Output: `No item with id {id}. Closest matches by prefix: {list or "(none)"}. Run /backlog list to see all items.`

### Step 4: Render

Output the file contents verbatim, fenced as markdown.

---

## Phase 5: Refine

Triggered by `/backlog refine <id>`. Interactive — use `AskUserQuestion` where available; otherwise, present the prompts as a list and collect a single response, parsing each section.

### Step 1: Load the item

Locate via Phase 4's lookup. If not found, error and exit (same message as Phase 4 Step 3).

### Step 2: Collect updates

Ask in this order, ONE field at a time when `AskUserQuestion` is available:

1. **Title** — show current; ask "Edit the title? (enter to keep)"
2. **Context** — multi-line free text; allow "skip"
3. **Acceptance criteria** — one per line; "done" to finish; allow zero
4. **Priority** — multi-choice from the enum; default to current
5. **Score (optional)** — integer 1-1000 or "skip"
6. **Labels (optional)** — comma-separated or "skip"

### Step 3: Write body

Build the body from collected values:
- Always write `## Context` (with content or "_TBD_" placeholder if user skipped — placeholder is fine here because refine is iterative)
- Always write `## Acceptance Criteria` if any were provided; omit the H2 if empty
- Omit `## Notes` (refine never collects notes — that's free-form for later edits)

Replace the entire body of the item file with the new sections. Keep frontmatter intact except:
- `updated:` -> today
- `status:` -> `ready` if currently `inbox`; otherwise unchanged
- `priority:`, `score:`, `labels:` if changed

### Step 4: Regenerate INDEX, report

Apply Phase 10. Output: `Refined #{id}. Status: {old_status} -> {new_status}.` (omit the arrow if status unchanged).

---

## Phase 6: Set Field

Triggered by `/backlog set <id> <field>=<value>`.

### Step 1: Parse and validate field name

Allowed fields: `title`, `type`, `status`, `priority`, `score`, `labels`, `parent`, `dependencies`, `source`, `spec_doc`, `plan_doc`, `pr`.

Disallowed (skill-managed only): `id`, `created`, `updated`. Reject with: `Field '{field}' cannot be set directly. The skill manages it.`

### Step 2: Validate value

| Field | Validation |
|---|---|
| `type` | Must be in `feature, bug, tech-debt, idea` |
| `status` | Must be in `inbox, ready, spec'd, planned, in-progress, done, wontfix` |
| `priority` | Must be in `must, should, could, maybe` |
| `score` | Integer, 1 <= n <= 1000, or empty (to clear) |
| `labels` | Comma-separated; written as a YAML list |
| `dependencies` | Comma-separated ids; validate each exists in `items/` (warn on missing, but proceed) |
| `parent` | Single id; validate exists |
| `title`, `source`, `spec_doc`, `plan_doc`, `pr` | Free string |

On enum violation: `Unknown {field} '{value}'. Allowed: {comma-separated list}.` No write.

### Step 3: Edit and report

Load item, update only the named field, set `updated:` to today, write back. If `title` changed, ALSO rename the file to match the new slug (preserve id prefix). Apply Phase 10. Output: `Updated #{id}: {field} = {value}.` (or `... renamed to {new-filename}.` if a rename occurred).

---

## Phase 7: Promote

Triggered by `/backlog promote <id>`. Hands off the item to the appropriate pipeline skill.

### Step 1: Load and check status

Locate the item. Map status to target skill:

| Current status | Target | Notes |
|---|---|---|
| `inbox` | `/requirements` | Item likely lacks ACs |
| `ready` | `/spec` | Item has ACs already |
| `spec'd` | refuse | Use `/plan --backlog <id>` directly |
| `planned` | refuse | Use `/execute --backlog <id>` directly |
| `in-progress` | refuse | Already running |
| `done`, `wontfix` | refuse | Use `/backlog set` to revive first |

On refuse, output: `#{id} is already at status '{status}'. {next_step_message}.` No further action.

### Step 2: Build the seed

Construct a seed string from the item:

```
[Backlog #{id} | {type} | priority {priority}]
Title: {title}

{body if present, otherwise just the title}

Source: backlog/items/{id}-{slug}.md
```

### Step 3: Invoke the target skill

Invoke the target skill (`/requirements` or `/spec`) with the seed AND `--backlog {id}` so the pipeline-bridge consent gate opens. The user's session continues inside the target skill.

### Step 4: On return, report

Once the target skill exits, output: `Promoted #{id} -> {target}. (source linked)` if the target wrote a doc, or `Promoted #{id} -> {target}. (target did not write a doc — re-invoke when ready.)` otherwise.

The actual frontmatter update on the item (e.g., `source:` or `spec_doc:`) is the target skill's responsibility per `pipeline-bridge.md`. Phase 7 does NOT mutate item frontmatter — it only invokes.

---

## Phase 8: Link Doc or PR

Triggered by `/backlog link <id> <doc-path-or-url>`.

### Step 1: Infer target field

| Pattern | Target field |
|---|---|
| URL matching `https?://github\.com/[^/]+/[^/]+/pull/\d+` | `pr` |
| Path ending in `-spec.md` or matching `*-{anything}-spec.md` | `spec_doc` |
| Path ending in `-plan.md` | `plan_doc` |
| Path ending in `-requirements.md` or under `requirements/` | `source` (treated as originating doc) |
| Anything else | error: `Cannot infer link type from '{value}'. Use /backlog set {id} <field>=<value>.` |

### Step 2: Apply

Delegate to Phase 6 (set) with the inferred `field=value`. Output: `Linked #{id}: {field} = {value}.`

---

## Phase 9: Archive

Triggered by `/backlog archive [--quarter Q]`.

### Step 1: Determine target quarter

If `--quarter <Q>` is provided (format `YYYY-QN`), use it for the destination directory.
Otherwise, derive per-item: for each eligible item, target = `{year-of-updated}-Q{quarter-of-updated}` based on the item's `updated:` date.

### Step 2: Collect eligible items

For each file in `backlog/items/*.md`:
- Parse frontmatter.
- Eligible if `status` in `done, wontfix` AND age (today - `updated:`) > 30 days.

### Step 3: Move

For each eligible item:
- Create `backlog/archive/{quarter}/` if absent.
- `git mv backlog/items/{file} backlog/archive/{quarter}/{file}` (preserves history).
- If git mv fails (e.g., not in a git repo), fall back to a regular file move.

### Step 4: Regenerate and report

Apply Phase 10 (rebuild-index — archive items are excluded from INDEX). Output:

`Archived {N} items: {list of "#{id} -> {quarter}"} (or "0 items: nothing eligible.").`

---

## Phase 10: Rebuild Index

Triggered by `/backlog rebuild-index`. Also invoked internally by Phases 2, 5, 6, 7, 8, 9 after any item write.

### Step 1: Read items

Glob `<repo>/backlog/items/*.md`. For each, parse frontmatter. Skip files with malformed frontmatter (emit one-line warning per skip; do not abort).

### Step 2: Group and sort

Group by `priority`. Within each group, sort by `score` desc (nulls last), then `updated` desc.

### Step 3: Write `INDEX.md`

Overwrite `<repo>/backlog/INDEX.md` with the format defined in `schema.md` (### INDEX.md format section). Include `Last regenerated: {today}` after the title.

### Step 4: Report

If invoked directly: `Regenerated INDEX.md: {count} items.`
If invoked from another phase: silent on success, warn on failure.
