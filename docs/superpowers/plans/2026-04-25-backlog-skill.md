# /backlog Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a `/backlog` skill in `pmos-toolkit` that serves as a zero-friction capture buffer and lightweight tracker, with explicit `--backlog <id>` integration into the existing `/requirements → /spec → /plan → /execute → /verify` pipeline.

**Architecture:** Markdown-only skill. Per-repo storage at `<repo>/backlog/` with one item per file (`items/{id}-{slug}.md`) plus an auto-regenerated `INDEX.md`. Workstream-wide aggregation reads `linked_repos:` from `~/.pmos/workstreams/{slug}.md`. Pipeline skills get small additions: accept `--backlog <id>`, optionally seed from backlog when invoked empty, and update item status only when the linkage is explicit. Item files are canonical; `INDEX.md` is a regenerable cache.

**Tech Stack:** Pure markdown / agent prompts. No executable code. "Tests" are scenario fixtures: a fixture directory + a `scenario.md` describing input commands and expected agent behavior, verified manually during skill development. Same approach as existing `pmos-toolkit` skills.

**Spec:** [`docs/superpowers/specs/2026-04-25-backlog-skill-design.md`](../specs/2026-04-25-backlog-skill-design.md)

---

## File Structure

### New skill (created in this plan)

```
plugins/pmos-toolkit/skills/backlog/
├── SKILL.md                   # Frontmatter + Phase 0 router + per-subcommand phases
├── schema.md                  # Reference: enums, frontmatter shape, body sections, INDEX.md format
├── inference-heuristics.md    # Reference: keyword → type table for quick-capture
├── pipeline-bridge.md         # Reference: how --backlog <id> flows through pipeline skills
└── tests/
    ├── scenarios.md           # All scenario specs in one file (fixture-name-keyed)
    └── fixtures/
        ├── empty-repo/
        ├── with-items/
        ├── multi-repo-workstream/
        │   ├── repo-a/
        │   └── repo-b/
        └── with-archive/
```

### Modifications (small additions to existing skills)

- `plugins/pmos-toolkit/skills/requirements/SKILL.md` — accept `--backlog <id>`; offer seeds when invoked empty
- `plugins/pmos-toolkit/skills/spec/SKILL.md` — accept `--backlog <id>`; offer seeds when invoked empty; on doc-write, update item if linked
- `plugins/pmos-toolkit/skills/plan/SKILL.md` — accept `--backlog <id>`; on doc-write, update item if linked; auto-capture deferred items
- `plugins/pmos-toolkit/skills/execute/SKILL.md` — accept `--backlog <id>`; on start, set status `in-progress` if linked
- `plugins/pmos-toolkit/skills/verify/SKILL.md` — accept `--backlog <id>`; on pass, set status `done` if linked; auto-capture deferred items
- `plugins/pmos-toolkit/.claude-plugin/plugin.json` — version bump
- `plugins/pmos-toolkit/.codex-plugin/plugin.json` — mirror version bump

Each pipeline-skill addition is a small, isolated section (≤ 30 lines) that no-ops when `--backlog` is absent. Existing behavior is preserved.

---

## Notes for the Implementer

**This is a markdown-only skill.** TDD is adapted: for each behavior, first write the fixture + scenario.md entry that describes the expected agent behavior, then write the SKILL.md prose that produces that behavior, then walk through the scenario manually (read the SKILL.md and confirm the prompt is unambiguous enough to produce the expected output).

**Atomic-ish writes.** When the skill mutates files (item file + `INDEX.md`), write the item file first, then regenerate `INDEX.md`. If `INDEX.md` regeneration fails, the item file is still canonical and the user can run `/backlog rebuild-index` to recover. Never write a partial item file.

**No magic ordering.** Where the spec says "top 5 items", the order is: priority bucket (`must` > `should` > `could` > `maybe`), then `score` desc (nulls last), then `updated` desc.

**Type inference is heuristic.** When ambiguous, fall back to `idea`. Never refuse capture or ask a clarifying question for `/backlog add`.

---

## Task 1: Scaffold the skill directory

**Files:**
- Create: `plugins/pmos-toolkit/skills/backlog/SKILL.md`
- Create: `plugins/pmos-toolkit/skills/backlog/schema.md`
- Create: `plugins/pmos-toolkit/skills/backlog/inference-heuristics.md`
- Create: `plugins/pmos-toolkit/skills/backlog/pipeline-bridge.md`
- Create: `plugins/pmos-toolkit/skills/backlog/tests/scenarios.md`

- [ ] **Step 1: Create skill directory and stub SKILL.md with frontmatter + Phase 0 router**

Create `plugins/pmos-toolkit/skills/backlog/SKILL.md` with this content:

```markdown
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

[Subsequent phases will be added in later tasks]
```

- [ ] **Step 2: Create stub reference docs**

Create `plugins/pmos-toolkit/skills/backlog/schema.md`:

```markdown
# Backlog Item Schema

[Filled in Task 2]
```

Create `plugins/pmos-toolkit/skills/backlog/inference-heuristics.md`:

```markdown
# Type Inference Heuristics

[Filled in Task 3]
```

Create `plugins/pmos-toolkit/skills/backlog/pipeline-bridge.md`:

```markdown
# Pipeline Bridge

[Filled in Task 11]
```

Create `plugins/pmos-toolkit/skills/backlog/tests/scenarios.md`:

```markdown
# Scenario Fixtures

Each section below describes an expected agent behavior given the matching fixture under `tests/fixtures/`.
```

- [ ] **Step 3: Verify the skill is discoverable**

Run: `ls plugins/pmos-toolkit/skills/backlog/`
Expected output:
```
SKILL.md
inference-heuristics.md
pipeline-bridge.md
schema.md
tests
```

- [ ] **Step 4: Commit**

```bash
git add plugins/pmos-toolkit/skills/backlog/
git commit -m "feat(pmos-toolkit/backlog): scaffold skill directory and Phase 0 router"
```

---

## Task 2: Document the item schema

**Files:**
- Modify: `plugins/pmos-toolkit/skills/backlog/schema.md`

- [ ] **Step 1: Write the fixture for the schema reference**

The schema.md is reference content; its "test" is that a reader (the agent) can produce a valid item file from it. Create `plugins/pmos-toolkit/skills/backlog/tests/fixtures/with-items/backlog/items/0001-ssl-renewal-cron-flaky.md` as the canonical example:

```markdown
---
id: 0001
title: SSL renewal cron is flaky
type: bug
status: ready
priority: should
score: 280
labels: [auth, ops]
created: 2026-04-20
updated: 2026-04-25
source: docs/.pmos/2026-04-15-auth-rewrite-plan.md
spec_doc:
plan_doc:
pr:
parent:
dependencies: []
---

## Context
The SSL renewal cron has failed silently three times in the last quarter, leading to expired certs in staging. The job logs nothing on failure and the alerting only fires on cert age, not job exit.

## Acceptance Criteria
- [ ] Cron job exits non-zero on failure
- [ ] Failures emit a structured log line consumed by the alerting pipeline
- [ ] A failing run pages oncall within 15 minutes

## Notes
Likely root cause: the wrapper script swallows certbot's exit code. Spotted while reading `/ops/cron/ssl-renew.sh`.
```

Add this entry to `plugins/pmos-toolkit/skills/backlog/tests/scenarios.md`:

```markdown
## Fixture: with-items

The `with-items` fixture contains canonical item files demonstrating every frontmatter field. After reading `schema.md`, the agent should be able to:
- Identify all enum values for `type`, `status`, `priority`.
- Reproduce the body section structure (## Context, ## Acceptance Criteria, ## Notes).
- Recognize that empty optional fields (`spec_doc:`, `plan_doc:`, `pr:`) are written as bare keys with no value, not omitted.
```

- [ ] **Step 2: Write `schema.md`**

Replace the stub at `plugins/pmos-toolkit/skills/backlog/schema.md` with:

```markdown
# Backlog Item Schema

Every backlog item is a markdown file at `backlog/items/{id}-{slug}.md`.

## Filename

- `id`: 4-digit zero-padded sequential integer (`0001`, `0002`, ...). Per-repo counters; no global coordination.
- `slug`: kebab-cased title, max 60 chars, ASCII letters/digits/hyphens only, no leading/trailing hyphens.

## Frontmatter

YAML frontmatter at the top of every item file. All fields below are recognized by the skill; unrecognized fields are preserved on edit but ignored.

```yaml
---
id: 0042
title: SSL renewal cron is flaky
type: bug                      # enum
status: inbox                  # enum
priority: should               # enum
score: 280                     # optional, integer 1-1000 (ICE: Impact x Confidence x Ease)
labels: [auth, ops]            # optional, free-string list
created: 2026-04-25            # ISO date, set on create, never modified
updated: 2026-04-25            # ISO date, updated on every write
source:                        # optional, path to originating doc (set by /plan, /verify auto-capture)
spec_doc:                      # optional, set by /spec --backlog
plan_doc:                      # optional, set by /plan --backlog
pr:                            # optional, set by /verify --backlog or `link`
parent:                        # optional, parent item id for sub-items
dependencies: []               # optional, list of item ids this item depends on
---
```

### Enum values (the skill MUST validate against these and never invent new ones)

| Field | Allowed values |
|---|---|
| `type` | `feature`, `bug`, `tech-debt`, `idea` |
| `status` | `inbox`, `ready`, `spec'd`, `planned`, `in-progress`, `done`, `wontfix` |
| `priority` | `must`, `should`, `could`, `maybe` |

### Defaults on create

- `status: inbox`
- `priority: should`
- `score:` omitted (the field is absent, not present-and-empty)
- `created`, `updated`: today's ISO date
- All other optional fields: present with empty value (e.g., `spec_doc:`)

## Body

Three fixed H2 sections, all optional. When present, they MUST appear in this order so a parser can read them deterministically:

```markdown
## Context
Why this exists, what problem it solves, links to discussions.

## Acceptance Criteria
- [ ] Behavior 1
- [ ] Behavior 2

## Notes
Free-form. Investigation, decisions, screenshots, links.
```

Items captured via `/backlog add` may have NO body at all — title-only is valid. The body is created on first refine/promote.

## INDEX.md format

`backlog/INDEX.md` is a regenerable cache — never the source of truth. The skill regenerates it from `items/` on every write op and on `/backlog rebuild-index`.

Shape:

```markdown
# Backlog

Last regenerated: 2026-04-25

## must
| id | type | status | title | spec | plan | pr |
|----|------|--------|-------|------|------|----|
| 0042 | bug | ready | SSL renewal cron is flaky | | | |

## should
| id | type | status | title | spec | plan | pr |
|----|------|--------|-------|------|------|----|
| 0017 | feature | spec'd | Add rate limit to API | docs/.pmos/2026-04-22-rate-limit-spec.md | | |

## could
...

## maybe
...
```

Items are grouped by `priority`, then sorted within each group by `score` desc (nulls last), then `updated` desc. Archived items are NOT listed. The `spec` / `plan` / `pr` columns show the filename only (not the full path) when set, otherwise blank.

## Archive

Archived items live at `backlog/archive/YYYY-QN/{id}-{slug}.md` with their full content preserved. Archive structure mirrors `items/` and is never written to `INDEX.md`.
```

- [ ] **Step 3: Manual verification**

Read `schema.md` against the fixture file `backlog/items/0001-ssl-renewal-cron-flaky.md`. Confirm:
- Every field in the fixture is documented in `schema.md`.
- Every enum value used in the fixture is listed.
- The body section order matches.

- [ ] **Step 4: Commit**

```bash
git add plugins/pmos-toolkit/skills/backlog/schema.md plugins/pmos-toolkit/skills/backlog/tests/
git commit -m "feat(pmos-toolkit/backlog): document item schema and add canonical fixture"
```

---

## Task 3: Quick-capture (`/backlog add`) with type inference

**Files:**
- Modify: `plugins/pmos-toolkit/skills/backlog/SKILL.md` (add Phase 2)
- Modify: `plugins/pmos-toolkit/skills/backlog/inference-heuristics.md`
- Create: `plugins/pmos-toolkit/skills/backlog/tests/fixtures/empty-repo/.gitkeep`
- Modify: `plugins/pmos-toolkit/skills/backlog/tests/scenarios.md`

- [ ] **Step 1: Write the fixture and scenario**

Create the empty-repo fixture marker:

```bash
mkdir -p plugins/pmos-toolkit/skills/backlog/tests/fixtures/empty-repo
touch plugins/pmos-toolkit/skills/backlog/tests/fixtures/empty-repo/.gitkeep
```

Append to `plugins/pmos-toolkit/skills/backlog/tests/scenarios.md`:

```markdown
## Fixture: empty-repo

A repo with no `backlog/` directory yet.

### Scenario: `/backlog add ssl renewal cron is flaky`

Expected agent behavior (single round-trip, no clarifying questions):
1. Create `backlog/`, `backlog/items/`.
2. Allocate id `0001`.
3. Infer `type: bug` (keyword "flaky").
4. Write `backlog/items/0001-ssl-renewal-cron-flaky.md` with frontmatter only (no body), `status: inbox`, `priority: should`, `created`/`updated` = today.
5. Generate `backlog/INDEX.md`.
6. Output: `Captured #0001 (bug, should): "ssl renewal cron is flaky"`.
7. Do NOT ask any clarifying questions. Do NOT load workstream context. Do NOT mention pipeline integration.

### Scenario: `/backlog "we should add OAuth"`

(No verb prefix; falls through Phase 0 router as add.)

Expected:
- id `0002`, `type: feature` (keyword "we should"), `status: inbox`, `priority: should`.
- Output: `Captured #0002 (feature, should): "we should add OAuth"`.

### Scenario: `/backlog add something completely vague`

Expected:
- id `0003`, `type: idea` (no keyword match → fallback), `status: inbox`.
- Output includes the inference fallback notice: `Captured #0003 (idea, should): "something completely vague" — type inferred as 'idea' (no strong signal); use /backlog set 0003 type=... to correct.`
```

- [ ] **Step 2: Write `inference-heuristics.md`**

Replace the stub at `plugins/pmos-toolkit/skills/backlog/inference-heuristics.md` with:

```markdown
# Type Inference Heuristics

For `/backlog add <text>`, infer `type` by scanning the text (case-insensitive) for these keywords. First-match wins; check in this order:

| Order | Type | Trigger keywords / patterns |
|------:|------|-----------------------------|
| 1 | `bug` | `bug`, `broken`, `fails`, `failing`, `flaky`, `crash`, `error`, `regression`, `incorrect`, `wrong output`, `should not`, `doesn't work`, `not working`, `500`, `404` |
| 2 | `tech-debt` | `refactor`, `cleanup`, `clean up`, `tech debt`, `technical debt`, `legacy`, `deprecated`, `tightly coupled`, `hardcoded`, `temporary`, `hack`, `TODO:`, `FIXME:` |
| 3 | `feature` | `add`, `we should`, `let's build`, `support for`, `new`, `enable`, `expose`, `allow users to`, `implement`, `introduce` |
| 4 | `idea` | (fallback — no match in 1-3) |

## Rules

1. **First match wins.** Order matters: a "refactor to fix the bug" sentence matches `bug` first because rule 1 is checked first. If you want it classified as `tech-debt`, correct it post-capture with `/backlog set <id> type=tech-debt`.
2. **Never ask.** If multiple keywords match, pick the first by order. If none match, fall through to `idea`.
3. **Always note the fallback.** When `type: idea` is assigned by fallback (rule 4), the capture output MUST include the notice: `type inferred as 'idea' (no strong signal); use /backlog set <id> type=... to correct.`
4. **No clarifying questions.** Capture must be one round-trip. Wrong inference is acceptable; capture friction is not.
```

- [ ] **Step 3: Add Phase 2 to `SKILL.md`**

Replace the line `[Subsequent phases will be added in later tasks]` in `plugins/pmos-toolkit/skills/backlog/SKILL.md` with:

```markdown
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
```

- [ ] **Step 4: Manual verification**

Walk through each scenario in `tests/scenarios.md` under "Fixture: empty-repo" by reading the SKILL.md prose. Confirm:
- The agent has unambiguous instructions for id allocation in an empty fixture (Step 2 handles "neither directory exists" → id 1).
- The output format is exactly specified (no room for the agent to invent a different format).
- No step asks the user a question.

- [ ] **Step 5: Commit**

```bash
git add plugins/pmos-toolkit/skills/backlog/SKILL.md plugins/pmos-toolkit/skills/backlog/inference-heuristics.md plugins/pmos-toolkit/skills/backlog/tests/
git commit -m "feat(pmos-toolkit/backlog): quick-capture with type inference (Phase 2)"
```

---

## Task 4: List, show, and rebuild-index

**Files:**
- Modify: `plugins/pmos-toolkit/skills/backlog/SKILL.md` (add Phases 1, 3, 4, 10)
- Modify: `plugins/pmos-toolkit/skills/backlog/tests/scenarios.md`

(Phase 1 = no-arg show, Phase 3 = filtered list, Phase 4 = show single item, Phase 10 = rebuild-index. Grouped because they all just read items.)

- [ ] **Step 1: Expand `with-items` fixture**

Create additional item files under `plugins/pmos-toolkit/skills/backlog/tests/fixtures/with-items/backlog/items/`:

`0002-add-rate-limit-to-api.md`:

```markdown
---
id: 0002
title: Add rate limit to API
type: feature
status: spec'd
priority: must
score: 720
labels: [api, security]
created: 2026-04-18
updated: 2026-04-22
source:
spec_doc: docs/.pmos/2026-04-22-rate-limit-spec.md
plan_doc:
pr:
parent:
dependencies: []
---

## Context
We're getting hit by aggressive scrapers. Need per-token rate limiting.

## Acceptance Criteria
- [ ] 100 req/min per token, configurable
- [ ] 429 response with Retry-After header
```

`0003-clean-up-legacy-auth.md`:

```markdown
---
id: 0003
title: Clean up legacy auth code
type: tech-debt
status: inbox
priority: could
labels: [auth]
created: 2026-04-25
updated: 2026-04-25
source:
spec_doc:
plan_doc:
pr:
parent:
dependencies: []
---
```

Append to `tests/scenarios.md`:

```markdown
### Scenario: `/backlog` (no args, with-items fixture)

Expected: render `INDEX.md` content (or regenerate then render). Output groups items by priority bucket, must-first.

### Scenario: `/backlog list --status inbox`

Expected: list only items with `status: inbox`. With the `with-items` fixture, only `#0003` matches.

### Scenario: `/backlog list --type feature`

Expected: only `#0002`.

### Scenario: `/backlog show 2`

Expected: render the full content of `backlog/items/0002-add-rate-limit-to-api.md` verbatim.

### Scenario: `/backlog show 999`

Expected: error `No item with id 0999. Closest matches by prefix: (none). Run /backlog list to see all items.`

### Scenario: `/backlog rebuild-index` after a manual edit

Expected: read all files in `items/`, regenerate `INDEX.md`, report `Regenerated INDEX.md: 3 items.`
```

- [ ] **Step 2: Add Phase 1 (no-arg show) to `SKILL.md`**

After Phase 0, before Phase 2, insert:

```markdown
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
```

- [ ] **Step 3: Add Phase 3 (list with filters) to `SKILL.md`**

After Phase 2, insert:

```markdown
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
```

- [ ] **Step 4: Add Phase 4 (show single item) to `SKILL.md`**

After Phase 3, insert:

```markdown
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
```

- [ ] **Step 5: Add Phase 10 (rebuild-index) to `SKILL.md`**

At the end of the phases section, insert:

```markdown
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
```

- [ ] **Step 6: Manual verification**

For each scenario in `tests/scenarios.md` under `with-items`, walk through the SKILL.md prose and confirm the agent has unambiguous steps to produce the expected output.

- [ ] **Step 7: Commit**

```bash
git add plugins/pmos-toolkit/skills/backlog/SKILL.md plugins/pmos-toolkit/skills/backlog/tests/
git commit -m "feat(pmos-toolkit/backlog): list, show, and rebuild-index (Phases 1, 3, 4, 10)"
```

---

## Task 5: Refine, set, and link

**Files:**
- Modify: `plugins/pmos-toolkit/skills/backlog/SKILL.md` (add Phases 5, 6, 8)
- Modify: `plugins/pmos-toolkit/skills/backlog/tests/scenarios.md`

- [ ] **Step 1: Add scenarios**

Append to `tests/scenarios.md`:

```markdown
### Scenario: `/backlog refine 3` (with-items fixture)

Expected: interactive flow (uses AskUserQuestion if available):
1. Show current title and ask if anything needs editing.
2. Ask for `## Context` content (multi-line; "skip" allowed).
3. Ask for acceptance criteria as a list (one per line; "done" to finish).
4. Confirm `priority` (default the current value).
5. Optionally collect `score` (skippable).
6. Optionally collect `labels` (comma-separated, skippable).
7. Write the body sections to the item file. Update `status: ready` if currently `inbox`. Update `updated:` to today.
8. Regenerate INDEX.md.
9. Output: `Refined #0003. Status: inbox -> ready.`

### Scenario: `/backlog set 3 priority=must`

Expected: validate `must` against the priority enum, edit only that field, update `updated:` to today, regenerate INDEX.md, output `Updated #0003: priority = must.`

### Scenario: `/backlog set 3 status=invalid-status`

Expected: error `Unknown status 'invalid-status'. Allowed: inbox, ready, spec'd, planned, in-progress, done, wontfix.` No file write.

### Scenario: `/backlog set 3 score=820`

Expected: write `score: 820` (creating the field if absent). Validate 1 <= score <= 1000.

### Scenario: `/backlog link 2 docs/.pmos/2026-04-22-rate-limit-spec.md`

Expected: infer field from filename pattern: `*-spec.md` -> `spec_doc`, `*-plan.md` -> `plan_doc`, anything matching `https://github.com/*/pull/*` -> `pr`. For this case, set `spec_doc:` to the path. Output: `Linked #0002: spec_doc = docs/.pmos/2026-04-22-rate-limit-spec.md.`

### Scenario: `/backlog link 2 https://github.com/foo/bar/pull/99`

Expected: set `pr:` to the URL. Output: `Linked #0002: pr = https://github.com/foo/bar/pull/99.`
```

- [ ] **Step 2: Add Phase 5 (refine) to `SKILL.md`**

After Phase 4, insert:

```markdown
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
```

- [ ] **Step 3: Add Phase 6 (set) to `SKILL.md`**

After Phase 5, insert:

```markdown
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
```

- [ ] **Step 4: Add Phase 8 (link) to `SKILL.md`**

After Phase 7 (which we'll add in Task 6 — for now, add Phase 8 right after Phase 6 with a placeholder for Phase 7):

```markdown
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
```

- [ ] **Step 5: Manual verification**

Walk each scenario in this task. Confirm:
- Refine flow handles `AskUserQuestion`-absent gracefully (single response collected and parsed).
- Set rejects disallowed fields by name (id, created, updated).
- Link's pattern table is unambiguous (no path matches multiple patterns).

- [ ] **Step 6: Commit**

```bash
git add plugins/pmos-toolkit/skills/backlog/SKILL.md plugins/pmos-toolkit/skills/backlog/tests/
git commit -m "feat(pmos-toolkit/backlog): refine, set, and link (Phases 5, 6, 8)"
```

---

## Task 6: Promote (hand off to pipeline)

**Files:**
- Modify: `plugins/pmos-toolkit/skills/backlog/SKILL.md` (add Phase 7)
- Modify: `plugins/pmos-toolkit/skills/backlog/tests/scenarios.md`

- [ ] **Step 1: Add scenarios**

Append to `tests/scenarios.md`:

```markdown
### Scenario: `/backlog promote 3` (status=inbox, with-items fixture)

Expected:
1. Item #0003 has `status: inbox` and minimal body.
2. Skill picks `/requirements` as the target (status `inbox` and `idea`/`tech-debt`/`feature` -> `/requirements`; status `ready` -> `/spec`).
3. Invokes `/requirements --backlog 0003` with the item's title + body as the seed.
4. The pipeline-bridge in `/requirements` recognizes `--backlog 0003` and, on doc-write, sets `source:` on item #0003.
5. After `/requirements` returns, output: `Promoted #0003 -> /requirements. (source linked)`.

### Scenario: `/backlog promote 2` (status=spec'd)

Expected: error `#0002 is already at status 'spec'd'. To replan, use /plan --backlog 0002 directly.`
```

- [ ] **Step 2: Add Phase 7 to `SKILL.md`**

Insert between Phases 6 and 8:

```markdown
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
```

- [ ] **Step 3: Manual verification**

Walk the scenarios. Confirm:
- Refused statuses are listed exhaustively (no "what about `done`?" gap).
- Phase 7 does NOT itself mutate the item — that's pipeline-bridge's job. (Important separation; otherwise a non-pipeline-aware target skill would leave stale state.)

- [ ] **Step 4: Commit**

```bash
git add plugins/pmos-toolkit/skills/backlog/SKILL.md plugins/pmos-toolkit/skills/backlog/tests/
git commit -m "feat(pmos-toolkit/backlog): promote items to pipeline (Phase 7)"
```

---

## Task 7: Archive

**Files:**
- Modify: `plugins/pmos-toolkit/skills/backlog/SKILL.md` (add Phase 9)
- Create: `plugins/pmos-toolkit/skills/backlog/tests/fixtures/with-archive/backlog/items/0001-old-done-thing.md`
- Create: `plugins/pmos-toolkit/skills/backlog/tests/fixtures/with-archive/backlog/items/0002-recent-done-thing.md`
- Create: `plugins/pmos-toolkit/skills/backlog/tests/fixtures/with-archive/backlog/items/0003-active-thing.md`
- Modify: `plugins/pmos-toolkit/skills/backlog/tests/scenarios.md`

- [ ] **Step 1: Build the with-archive fixture**

Create `plugins/pmos-toolkit/skills/backlog/tests/fixtures/with-archive/backlog/items/0001-old-done-thing.md`:

```markdown
---
id: 0001
title: Old done thing
type: feature
status: done
priority: should
created: 2025-12-01
updated: 2026-01-15
source:
spec_doc:
plan_doc:
pr:
parent:
dependencies: []
---
```

Create `0002-recent-done-thing.md` (today is 2026-04-25, so `updated` 30 days ago is 2026-03-26 — pick something more recent):

```markdown
---
id: 0002
title: Recent done thing
type: feature
status: done
priority: should
created: 2026-04-01
updated: 2026-04-20
source:
spec_doc:
plan_doc:
pr:
parent:
dependencies: []
---
```

Create `0003-active-thing.md`:

```markdown
---
id: 0003
title: Active thing
type: feature
status: ready
priority: should
created: 2026-04-25
updated: 2026-04-25
source:
spec_doc:
plan_doc:
pr:
parent:
dependencies: []
---
```

Append to `tests/scenarios.md`:

```markdown
## Fixture: with-archive

### Scenario: `/backlog archive` (today = 2026-04-25)

Expected:
1. Item #0001 (`status: done`, `updated: 2026-01-15`, age > 30d) -> moved to `backlog/archive/2026-Q1/0001-old-done-thing.md`.
2. Item #0002 (`status: done`, `updated: 2026-04-20`, age 5d) -> stays.
3. Item #0003 (`status: ready`) -> stays.
4. INDEX.md regenerated.
5. Output: `Archived 1 item: #0001 -> 2026-Q1.`

### Scenario: `/backlog archive --quarter 2026-Q1`

Expected: archive ALL eligible items into `2026-Q1` regardless of `updated:` quarter. Same rules otherwise (only `done`/`wontfix` and >30 days).
```

- [ ] **Step 2: Add Phase 9 to `SKILL.md`**

After Phase 8, insert:

```markdown
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
```

- [ ] **Step 3: Manual verification**

Walk both scenarios. Confirm:
- Eligibility rule is exact: `status in {done, wontfix}` AND `updated:` is more than 30 days ago.
- The `--quarter` flag overrides per-item quarter calculation but not eligibility.
- `git mv` is preferred for history preservation.

- [ ] **Step 4: Commit**

```bash
git add plugins/pmos-toolkit/skills/backlog/SKILL.md plugins/pmos-toolkit/skills/backlog/tests/
git commit -m "feat(pmos-toolkit/backlog): archive done/wontfix items (Phase 9)"
```

---

## Task 8: Workstream aggregation

**Files:**
- Modify: `plugins/pmos-toolkit/skills/backlog/SKILL.md` (add Phase 11 — workstream aggregator)
- Create: `plugins/pmos-toolkit/skills/backlog/tests/fixtures/multi-repo-workstream/repo-a/backlog/items/0001-thing-in-a.md`
- Create: `plugins/pmos-toolkit/skills/backlog/tests/fixtures/multi-repo-workstream/repo-b/backlog/items/0001-thing-in-b.md`
- Create: `plugins/pmos-toolkit/skills/backlog/tests/fixtures/multi-repo-workstream/workstream.md` (mock)
- Modify: `plugins/pmos-toolkit/skills/backlog/tests/scenarios.md`

- [ ] **Step 1: Build the multi-repo fixture**

Create `repo-a/backlog/items/0001-thing-in-a.md`:

```markdown
---
id: 0001
title: Thing in repo A
type: feature
status: ready
priority: should
created: 2026-04-20
updated: 2026-04-22
source:
spec_doc:
plan_doc:
pr:
parent:
dependencies: []
---
```

Create `repo-b/backlog/items/0001-thing-in-b.md`:

```markdown
---
id: 0001
title: Thing in repo B
type: bug
status: ready
priority: must
created: 2026-04-21
updated: 2026-04-24
source:
spec_doc:
plan_doc:
pr:
parent:
dependencies: []
---
```

Create the mock workstream context file `multi-repo-workstream/workstream.md`:

```markdown
---
name: test-workstream
type: product
linked_repos:
  - tests/fixtures/multi-repo-workstream/repo-a
  - tests/fixtures/multi-repo-workstream/repo-b
---

# Test Workstream

Two repos, both with id `0001`, demonstrating prefix disambiguation.
```

Append to `tests/scenarios.md`:

```markdown
## Fixture: multi-repo-workstream

### Scenario: `/backlog list --workstream` (run from repo-a, workstream=test-workstream)

Expected:
- Aggregator reads workstream.md, finds linked_repos=[repo-a, repo-b].
- Reads items from each.
- Both items have id `0001` -> shown as `repo-a#0001` and `repo-b#0001`.
- Sorted: `repo-b#0001` (priority must) first, then `repo-a#0001` (priority should).
- Columns include a `repo` column.

### Scenario: `/backlog show repo-b#0001`

Expected: render `tests/fixtures/multi-repo-workstream/repo-b/backlog/items/0001-thing-in-b.md`.
```

- [ ] **Step 2: Add Phase 11 to `SKILL.md`**

After Phase 10, insert:

```markdown
## Phase 11: Workstream Aggregator

Used by Phases 3 (`list --workstream`) and 4 (`show repo#id`). Not user-invoked directly.

### Step 1: Find the workstream slug

Read `<repo>/.pmos/settings.yaml`. Extract `workstream:`. If absent, error: `Current repo has no workstream link. Run /product-context init or use /backlog list without --workstream.`

### Step 2: Find linked repos

Read `~/.pmos/workstreams/{slug}.md`. Parse frontmatter. Extract `linked_repos:` list. If absent or empty, error: `Workstream '{slug}' has no linked_repos. Add them via /product-context update.`

### Step 3: For each linked repo

For each path in `linked_repos`:
- If the path does not exist on disk, emit a one-line warning: `Skipping {path} (not on disk).`
- Otherwise, read items from `{path}/backlog/items/*.md`. Tag each item with its repo basename for disambiguation.

### Step 4: Merge

Return the merged list (or the located file, for `show repo#id`). Never write — the aggregator is read-only.

### Step 5: ID disambiguation

When listing, render each item's id as `{repo-basename}#{id}` (e.g., `repo-a#0001`). When the user invokes `/backlog show repo-a#0001`, parse the prefix to route to the right repo.

The Phase 11 aggregator does NOT mutate `~/.pmos/workstreams/{slug}.md` or any `.pmos/settings.yaml`. Linked-repo management is `/product-context`'s responsibility.
```

- [ ] **Step 3: Manual verification**

Walk the scenarios. Confirm:
- Aggregator handles missing-on-disk linked repos gracefully (warn, continue).
- ID-with-repo-prefix syntax (`repo-a#0001`) is parsed in Phase 4 (Step 1 already mentions accepting it).
- Aggregator is strictly read-only.

- [ ] **Step 4: Commit**

```bash
git add plugins/pmos-toolkit/skills/backlog/SKILL.md plugins/pmos-toolkit/skills/backlog/tests/
git commit -m "feat(pmos-toolkit/backlog): workstream aggregation (Phase 11)"
```

---

## Task 9: Pipeline bridge reference doc

**Files:**
- Modify: `plugins/pmos-toolkit/skills/backlog/pipeline-bridge.md`

- [ ] **Step 1: Write `pipeline-bridge.md`**

Replace the stub at `plugins/pmos-toolkit/skills/backlog/pipeline-bridge.md` with:

```markdown
# Pipeline Bridge

Defines the `--backlog <id>` contract that the `/backlog` skill and the pipeline skills (`/requirements`, `/spec`, `/plan`, `/execute`, `/verify`) jointly implement.

## Principle

Pipeline skills mutate backlog item state ONLY when `--backlog <id>` is explicitly passed. Without it, the backlog is invisible to them. This is the consent gate that prevents surprise edits when a user runs a pipeline skill on something unrelated.

## Lifecycle

| Pipeline event | Item update | Trigger |
|---|---|---|
| `/requirements --backlog <id>` writes its doc | item `source:` set to the requirements doc path | The `/requirements` skill invokes Phase 6 (set) on `/backlog` after writing its output |
| `/spec --backlog <id>` writes its doc | item `spec_doc:` set; status: `inbox`/`ready` -> `spec'd`; `planned`+ unchanged | `/spec` invokes Phase 6 (set) twice (one for spec_doc, one for status if applicable) |
| `/plan --backlog <id>` writes its doc | item `plan_doc:` set; status -> `planned` | `/plan` invokes Phase 6 (set) |
| `/execute --backlog <id>` starts | status -> `in-progress` | `/execute` invokes Phase 6 (set) at the start of execution |
| `/verify --backlog <id>` reports pass | status -> `done`; `pr:` filled if available from git context | `/verify` invokes Phase 6 (set) |

## Auto-prompt (offered seeds)

When `/requirements` or `/spec` is invoked with an empty argument string AND `--backlog` is not provided AND a `<repo>/backlog/items/` directory exists:

1. Read items via Phase 11 if a workstream is linked, else local items only.
2. Filter to candidate statuses: `/requirements` -> `inbox` or `ready`; `/spec` -> `ready`.
3. Sort by priority bucket (must>should>could>maybe), then `score` desc, then `updated` desc.
4. Take the top 5.
5. Offer them via `AskUserQuestion`:
   ```
   No seed provided. Pick a backlog item to start from?

     1. #0042 [must, bug] SSL renewal cron is flaky
     2. #0017 [should, feature] Add OAuth support
     ...
     6. (skip — proceed with no seed)
   ```
6. If user picks one, set the seed to that item's content AND set `--backlog <id>` for the rest of the invocation.

This auto-prompt is a one-shot at the start of the skill; it does NOT recur.

## Auto-capture (deferred items flow into backlog)

`/plan` and `/verify` produce sections that surface deferred or out-of-scope work. Before those skills exit, they:

1. Detect candidate items in their output (heuristic: bulleted items under headings like "Deferred", "Out of scope", "Follow-up", "Future work", "Known limitations").
2. Construct a list of proposed backlog entries:
   - `title`: the bullet text (truncated to 100 chars)
   - `type`: inferred via `inference-heuristics.md`
   - `status`: `inbox`
   - `source`: the doc path being written
3. Show the proposed list to the user (`AskUserQuestion`):
   ```
   I detected 3 deferred items in this {plan|verify} output. Capture to backlog?

     1. Capture all
     2. Pick which to capture
     3. Skip
   ```
4. On confirm, invoke Phase 2 (`/backlog add ...`) for each, with the `source:` field pre-filled.

## Implementation pattern for pipeline skills

Each pipeline skill adds, near the top of its phase body, this Subroutine:

```markdown
### Subroutine: Backlog Bridge

If `--backlog <id>` was passed:
- After writing the primary output doc, invoke `/backlog set <id> {field}={value}` for the relevant field per the lifecycle table.
- If the set fails (item not found, etc.), emit a single-line warning and continue.

If `--backlog` was NOT passed AND argument is empty AND backlog/items/ exists:
- Run the auto-prompt flow above.

(For /plan and /verify) After the primary doc is written:
- Run the auto-capture flow above.
```

The skill body cites this reference document instead of restating the contract; only the per-field mapping changes per skill.
```

- [ ] **Step 2: Manual verification**

Read `pipeline-bridge.md` end to end. Confirm:
- Every pipeline event has an exact item-update mapping.
- The consent gate (`--backlog` required) is stated unambiguously at the top.
- Auto-prompt and auto-capture are well-defined and one-shot.

- [ ] **Step 3: Commit**

```bash
git add plugins/pmos-toolkit/skills/backlog/pipeline-bridge.md
git commit -m "feat(pmos-toolkit/backlog): document pipeline bridge contract"
```

---

## Task 10: Wire `--backlog` into pipeline skills

**Files:**
- Modify: `plugins/pmos-toolkit/skills/requirements/SKILL.md`
- Modify: `plugins/pmos-toolkit/skills/spec/SKILL.md`
- Modify: `plugins/pmos-toolkit/skills/plan/SKILL.md`
- Modify: `plugins/pmos-toolkit/skills/execute/SKILL.md`
- Modify: `plugins/pmos-toolkit/skills/verify/SKILL.md`

This task adds five small additions, each ≤ 30 lines. Each pipeline skill gets ONE new section called "Backlog Bridge" that cites `plugins/pmos-toolkit/skills/backlog/pipeline-bridge.md`.

- [ ] **Step 1: Update `requirements/SKILL.md`**

Locate the frontmatter and update `argument-hint` to mention `--backlog`. Then, immediately after the "Platform Adaptation" section, add:

```markdown
## Backlog Bridge

This skill optionally integrates with `/backlog`. See `plugins/pmos-toolkit/skills/backlog/pipeline-bridge.md` for the full contract.

**At skill start:**
- If `--backlog <id>` was passed: load the item via `cat <repo>/backlog/items/{id}-*.md` and use its content as the seed alongside any user-provided argument. Remember `<id>` for use at the end of the skill.
- If no argument was provided AND `<repo>/backlog/items/` exists: run the auto-prompt flow per `pipeline-bridge.md`. If the user picks an item, set `<id>` and use its content as the seed.

**At skill end (after writing the requirements doc):**
- If `<id>` was set, invoke `/backlog set {id} source={doc_path}`. On failure, warn and continue.
```

- [ ] **Step 2: Update `spec/SKILL.md`**

Same pattern. Add to `argument-hint`. Insert after Platform Adaptation:

```markdown
## Backlog Bridge

This skill optionally integrates with `/backlog`. See `plugins/pmos-toolkit/skills/backlog/pipeline-bridge.md`.

**At skill start:**
- If `--backlog <id>` was passed: load the item file as supplementary context.
- If no argument provided AND `<repo>/backlog/items/` has items with status=ready: run the auto-prompt flow.

**At skill end (after writing the spec doc):**
- If `<id>` was set, invoke `/backlog set {id} spec_doc={doc_path}`, then `/backlog set {id} status=spec'd` (only if current status is `inbox` or `ready`). On failure, warn and continue.
```

- [ ] **Step 3: Update `plan/SKILL.md`**

Same pattern. Insert after Platform Adaptation:

```markdown
## Backlog Bridge

This skill optionally integrates with `/backlog`. See `plugins/pmos-toolkit/skills/backlog/pipeline-bridge.md`.

**At skill start:**
- If `--backlog <id>` was passed: load the item file as supplementary context.

**At skill end (after writing the plan doc):**
- If `<id>` was set, invoke `/backlog set {id} plan_doc={doc_path}`, then `/backlog set {id} status=planned`. On failure, warn and continue.
- Run the auto-capture flow per `pipeline-bridge.md`: detect deferred-work bullets in the plan output, propose them as new backlog items via `AskUserQuestion`. On user confirmation, invoke `/backlog add` for each with `source:` pre-filled.
```

- [ ] **Step 4: Update `execute/SKILL.md`**

Insert after Platform Adaptation:

```markdown
## Backlog Bridge

This skill optionally integrates with `/backlog`. See `plugins/pmos-toolkit/skills/backlog/pipeline-bridge.md`.

**At skill start:**
- If `--backlog <id>` was passed: invoke `/backlog set {id} status=in-progress`. On failure, warn and continue.

**At skill end:**
- No automatic status change here; `/verify` is responsible for the `done` transition.
```

- [ ] **Step 5: Update `verify/SKILL.md`**

Insert after Platform Adaptation:

```markdown
## Backlog Bridge

This skill optionally integrates with `/backlog`. See `plugins/pmos-toolkit/skills/backlog/pipeline-bridge.md`.

**At skill start:**
- If `--backlog <id>` was passed: load the item file as supplementary context.

**At skill end (only if the verify pass is reported successful):**
- If `<id>` was set, invoke `/backlog set {id} status=done`. If the active branch has an associated PR (detect via `gh pr view --json url`), also invoke `/backlog set {id} pr={url}`. On failure, warn and continue.
- Run the auto-capture flow per `pipeline-bridge.md`: scan the verify output for "Known issues" / "Follow-up" sections and propose new backlog items.
```

- [ ] **Step 6: Manual verification**

For each pipeline SKILL.md, confirm:
- The Backlog Bridge section is ≤ 30 lines.
- Existing content is unmodified except for `argument-hint` and the new section.
- The new section says "warn and continue" on backlog failure (the pipeline skill must not abort because of a backlog hiccup).

- [ ] **Step 7: Commit**

```bash
git add plugins/pmos-toolkit/skills/{requirements,spec,plan,execute,verify}/SKILL.md
git commit -m "feat(pmos-toolkit): wire --backlog <id> into pipeline skills"
```

---

## Task 11: Plugin manifest version bump

**Files:**
- Modify: `plugins/pmos-toolkit/.claude-plugin/plugin.json`
- Modify: `plugins/pmos-toolkit/.codex-plugin/plugin.json`

- [ ] **Step 1: Bump `.claude-plugin/plugin.json`**

Read `plugins/pmos-toolkit/.claude-plugin/plugin.json`. Bump `version` from `1.5.0` to `1.6.0`.

- [ ] **Step 2: Mirror to `.codex-plugin/plugin.json`**

Read `plugins/pmos-toolkit/.codex-plugin/plugin.json`. Apply the same version bump (and any other diff between the two files — they should otherwise be identical except for codex-specific fields).

- [ ] **Step 3: Verify**

```bash
grep -H '"version"' plugins/pmos-toolkit/.claude-plugin/plugin.json plugins/pmos-toolkit/.codex-plugin/plugin.json
```

Expected: both show `"version": "1.6.0"`.

- [ ] **Step 4: Commit**

```bash
git add plugins/pmos-toolkit/.claude-plugin/plugin.json plugins/pmos-toolkit/.codex-plugin/plugin.json
git commit -m "chore(pmos-toolkit): bump to v1.6.0 for /backlog skill"
```

---

## Task 12: End-to-end manual scenario walk-through

**Files:** none modified — verification only.

- [ ] **Step 1: Walk every scenario in `tests/scenarios.md`**

For each scenario, read the relevant SKILL.md prose end-to-end as if you were the agent receiving the user command. Confirm:

1. The agent has unambiguous instructions for every step.
2. No step requires a clarifying question that the scenario didn't anticipate.
3. The expected output format matches what the SKILL.md instructs.

- [ ] **Step 2: Walk a cross-skill scenario**

End-to-end:
1. `/backlog add ssl renewal cron is flaky` (Phase 2)
2. `/backlog refine 1` adds Context, ACs, sets priority=must (Phase 5)
3. `/backlog promote 1` -> invokes `/spec --backlog 0001` (Phase 7)
4. `/spec` Backlog Bridge fires, sets `spec_doc` + `status=spec'd` on item #0001
5. `/plan --backlog 0001` runs, sets `plan_doc` + `status=planned`, captures any deferred items as new inbox items
6. `/execute --backlog 0001` -> sets `status=in-progress`
7. `/verify --backlog 0001` -> sets `status=done`, fills `pr` if available

Walk through each step, citing the SKILL.md sections that produce each frontmatter mutation. Confirm the chain is intact and each step's success criteria are explicit.

- [ ] **Step 3: Document any gaps**

If any scenario reveals a gap, append a new task to this plan (not a new commit yet) and address it before the final commit.

- [ ] **Step 4: Final summary commit**

If no gaps were found, no commit is needed. If gaps were addressed, commit each fix individually with descriptive messages.

---

## Self-Review Checklist

(Run after writing the plan, before handing off.)

**Spec coverage:**
- [x] §1 Problem & Goals — Tasks 3 (capture), 6 (promote), 10 (pipeline bridge)
- [x] §2 Storage — Tasks 1 (scaffold), 7 (archive), 8 (workstream)
- [x] §3 Item Schema — Task 2
- [x] §4 Subcommand Surface — Tasks 3 (add), 4 (list/show/rebuild), 5 (refine/set/link), 6 (promote), 7 (archive)
- [x] §5 Pipeline Integration — Tasks 9 (bridge doc), 10 (wiring)
- [x] §6 Components & Boundaries — implicit in task decomposition (router/store/index/aggregator/bridge each get their own task or section)
- [x] §7 Error Handling — covered inline in each phase (enum violation, unknown id, drift, missing repo)
- [x] §8 Testing — fixtures and scenarios threaded through every implementation task
- [x] §10 File Layout — Tasks 1, 9

**Placeholder scan:** No "TBD"/"TODO"/"fill in" markers. The one `_TBD_` placeholder text in Phase 5 (refine, when user skips Context) is intentional content the skill writes, not a plan placeholder.

**Type consistency:** Field/phase names verified — `Phase 2`, `Phase 6` (set), `Phase 10` (rebuild-index), `Phase 11` (workstream aggregator) referenced consistently across tasks. Lifecycle field names (`source`, `spec_doc`, `plan_doc`, `pr`) match across schema.md, pipeline-bridge.md, and pipeline-skill additions.

**Scope:** One skill plus five small wiring additions to existing skills. Bounded; no decomposition needed.
