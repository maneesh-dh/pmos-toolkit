# /backlog Skill — Design

**Date:** 2026-04-25
**Status:** Draft (awaiting review)
**Plugin:** `pmos-toolkit`
**Pipeline position:** Feeder + sink for `/requirements → /spec → /plan → /execute → /verify`

---

## 1. Problem & Goals

A repo-resident, AI-readable backlog that serves two jobs at once:

1. **Capture buffer** — zero-friction inbox for ideas, bugs, deferred work that surfaces mid-flow (during `/plan`, `/execute`, `/verify`, or just while coding).
2. **Lightweight tracker** — items carry status, priority, acceptance criteria, and links to the spec/plan/PR docs they spawned. Replaces or complements GitHub Issues for solo / small-team work on workstreams already managed by `pmos-toolkit`.

**Non-goals.** Not a GitHub Issues replacement for teams. No SLA tracking, sprints, burn-down charts, assignees beyond a single label, or web UI. No real-time collaboration semantics — markdown + git is the sync mechanism.

**Success criteria.**
- Capture an idea mid-session in one tool call, no clarifying questions, no pipeline interruption.
- See every active item across all repos in the active workstream with `/backlog list --workstream`.
- Items birthed by `/plan` or `/verify` (deferred work) flow into the backlog automatically (with user confirmation), with a `source:` link back to the originating doc.
- An item promoted via `/backlog promote` seeds `/requirements` or `/spec` with its content; status auto-syncs back when those skills write their docs *if* the linkage is explicit.

---

## 2. Storage

### Per-repo, workstream-aware aggregation

Backlog files live at `<repo>/backlog/`, committed to git. They travel with the branch and survive merges normally.

The `/backlog list --workstream` view aggregates across all repos linked to the active workstream. Linkage resolution:

1. Read the current repo's `.pmos/settings.yaml` to find the active `workstream:` slug.
2. Read `~/.pmos/workstreams/{slug}.md` frontmatter for a `linked_repos:` list of absolute paths.
3. For each linked repo path that exists on disk, read its `backlog/items/`.

Each linked repo records its workstream membership in its own `.pmos/settings.yaml`; the workstream context file holds the canonical list of linked-repo paths. `/backlog` does not mutate either file — that is `/product-context`'s responsibility.

### Layout

```
<repo>/
└── backlog/
    ├── INDEX.md                          # Auto-generated table; cache, not source of truth
    ├── items/
    │   ├── 0001-ssl-renewal-cron-flaky.md
    │   ├── 0002-add-rate-limit-to-api.md
    │   └── ...
    └── archive/
        └── 2026-Q2/
            └── 0007-old-done-thing.md
```

- **`items/{id}-{slug}.md`** is the canonical record. One file per item.
- **`INDEX.md`** is regenerated from `items/` on every write op and on `/backlog` no-arg invocation. Manual drift is repaired by `/backlog rebuild-index`.
- **`archive/YYYY-QN/`** holds items moved by `/backlog archive`.

### IDs

Repo-scoped, zero-padded sequential ints (`0001`, `0002`, …). Per-repo counters; no global coordination. The aggregated workstream view disambiguates as `{repo-name}#0042`. Pure repo-local commands accept the bare id (`/backlog show 42`).

ID allocation: scan `items/` and `archive/` for the highest existing id, increment. Atomic per-write (the skill never holds open allocations).

---

## 3. Item Schema

### Filename

`backlog/items/{id}-{slug}.md` — `id` is 4-digit zero-padded; `slug` is kebab-cased title, max 60 chars.

### Frontmatter

```yaml
---
id: 0042
title: SSL renewal cron is flaky
type: bug                                # feature | bug | tech-debt | idea
status: inbox                            # inbox | ready | spec'd | planned | in-progress | done | wontfix
priority: should                         # must | should | could | maybe
score: 280                               # optional ICE (Impact × Confidence × Ease, 1-1000)
labels: [auth, ops]                      # optional, free strings
created: 2026-04-25
updated: 2026-04-25
source: docs/.pmos/2026-04-20-auth-rewrite-plan.md  # optional, originating doc
spec_doc: docs/.pmos/2026-04-25-ssl-cron-spec.md    # optional, set by /spec when --backlog linked
plan_doc:                                            # optional, set by /plan when --backlog linked
pr: https://github.com/.../pull/123                  # optional
parent: 0030                                         # optional, sub-item relationship
dependencies: [0015, 0028]                           # optional, ids
---
```

**Enum constraints (enforced by the skill, never invented at runtime):**

| Field | Allowed values |
|---|---|
| `type` | `feature`, `bug`, `tech-debt`, `idea` |
| `status` | `inbox`, `ready`, `spec'd`, `planned`, `in-progress`, `done`, `wontfix` |
| `priority` | `must`, `should`, `could`, `maybe` |

### Body

Three fixed H2 sections, all optional but parsed deterministically when present:

```markdown
## Context
Why this exists, what problem it solves, links to discussions.

## Acceptance Criteria
- [ ] Behavior 1
- [ ] Behavior 2

## Notes
Free-form. Investigation, decisions, screenshots, links.
```

Quick-captured items (status `inbox`) need not have a body file at all — title-only is valid. A body file is created the first time the item is refined or promoted.

### INDEX.md shape

Auto-generated GFM table, one row per non-archived item, grouped by status. Columns:

```
| id | type | status | priority | title | spec | plan | pr |
```

Archived items are not listed. Workstream-aggregated view is rendered on demand by `/backlog list --workstream` and *not* stored to disk.

---

## 4. Subcommand Surface

| Command | Behavior |
|---|---|
| `/backlog` | Show `INDEX.md` for current repo. |
| `/backlog add <text>` | Quick-capture: infer type, allocate id, append to index, return id. **Single tool call, no clarifying questions.** |
| `/backlog list [--type X --status Y --priority Z --repo R --workstream]` | Filtered list. `--workstream` aggregates across linked repos. |
| `/backlog show <id>` | Render the item file. |
| `/backlog refine <id>` | Interactive: add ACs, set priority, write body file, transition `inbox → ready`. |
| `/backlog set <id> <field>=<value>` | Edit one frontmatter field. Validates against enums. |
| `/backlog promote <id>` | Hand off to `/requirements` (if `idea` or `feature` + status `inbox`) or `/spec` (if status `ready` and refined). Status flips to `spec'd` once `/spec` writes its doc. |
| `/backlog link <id> <doc-or-pr>` | Manually fill `spec_doc` / `plan_doc` / `pr` based on path inference. |
| `/backlog archive [--quarter Q]` | Move `done`/`wontfix` items whose `updated:` timestamp is older than 30 days into `archive/YYYY-QN/`, rewrite `INDEX.md`. Manual only. |
| `/backlog rebuild-index` | Regenerate `INDEX.md` from `items/`. Repair tool. |

### Quick-capture contract (non-negotiable)

`/backlog add <text>` MUST:
- Complete in one round-trip with zero clarifying questions.
- Infer `type` from keywords (heuristic table in the skill body, e.g., "flaky/broken/error" → `bug`, "we should/add/build" → `feature`, "TODO/later/cleanup" → `tech-debt`, anything ambiguous → `idea`).
- Default `status: inbox`, `priority: should`.
- Write title-only (no body file) unless the input contains a body marker (e.g., `--`).
- Be safe to invoke from inside any other skill or session. Stateless w.r.t. ambient pipeline state.

A noisy/wrong inference is acceptable; capture friction is not. The user corrects later via `/backlog set`.

---

## 5. Pipeline Integration

### 5a. Backlog → pipeline (promotion)

- **Manual:** `/backlog promote <id>` invokes `/requirements` (for `idea`/unrefined `feature`) or `/spec` (for `ready` with ACs) seeded with the item's content. The promoting skill receives `--backlog <id>` so the consent gate (5c) opens.
- **Auto-prompt:** when `/requirements` or `/spec` is invoked with an empty argument string, the skill offers the top 5 backlog items (status `ready` for `/spec`, status `inbox` or `ready` for `/requirements`, ordered by priority then `score` then `updated`) as starting seeds. User picks one or skips. Pipeline behavior is unchanged when an argument is provided.

### 5b. Pipeline → backlog (deferred capture)

- **Auto-capture:** `/plan` and `/verify` detect deferred / out-of-scope / "follow-up" items in their output. Before exiting, they propose new backlog entries (`status: inbox`, `type` inferred, `source:` set to the originating doc path) and ask the user to confirm-all / pick / skip.
- **Manual:** the user can always say "add this to the backlog" mid-session, which routes through `/backlog add`.

### 5c. Status sync (consent-gated)

Pipeline skills update backlog item status **only when the linkage is explicit**:

| Pipeline event | Backlog effect | Trigger |
|---|---|---|
| `/spec --backlog <id>` writes its doc | item `spec_doc:` set, status → `spec'd` | explicit `--backlog` flag, or implicit if invoked via `/backlog promote` |
| `/plan --backlog <id>` writes its doc | item `plan_doc:` set, status → `planned` | same |
| `/execute --backlog <id>` starts | status → `in-progress` | same |
| `/verify --backlog <id>` reports pass | status → `done`, `pr:` filled if available | same |

Without `--backlog <id>`, pipeline skills never mutate the backlog. This avoids surprise edits when a user runs `/spec` on something unrelated.

---

## 6. Components & Boundaries

The skill decomposes into five independently-testable units:

| Unit | Responsibility | Inputs | Outputs |
|---|---|---|---|
| **Subcommand router** | Parse `/backlog <verb> <args>`, dispatch to handler. | argv | handler call |
| **Item store** | Read/write item files. Allocate ids. Validate frontmatter against enums. | filesystem | item objects |
| **Index renderer** | Generate `INDEX.md` from item files. Pure function over the item store. | item objects | markdown table |
| **Workstream aggregator** | Resolve linked repos for the active workstream, fan out reads to each repo's item store. | workstream slug | merged item list |
| **Pipeline bridge** | Translate `--backlog <id>` flags from pipeline skills into status/link mutations on items. | id, event type, doc path | item update |

Each unit can be reasoned about and tested without the others. The skill body imports them via clearly-named sections; no unit reaches into another's internals.

---

## 7. Error Handling

System-boundary validation only — internal calls trust each other.

- **Enum violation on `set`:** reject with the allowed values, no write.
- **Unknown id:** show closest match by id prefix, suggest `/backlog list`.
- **Index drift detected** (item file exists but missing from `INDEX.md`, or vice versa): warn once, suggest `/backlog rebuild-index`. Do not auto-rebuild silently.
- **Merge conflict in `INDEX.md`:** the file is regeneratable; instruct user to `git checkout --theirs INDEX.md && /backlog rebuild-index`. Item-file conflicts are normal markdown conflicts; no special handling.
- **Workstream aggregator: linked repo missing on disk:** skip with a single-line warning, continue aggregation.
- **Quick-capture write failure:** echo the captured text back to the user so it can be retried; never silently swallow.

---

## 8. Testing

Skill is markdown + prompts; no executable code. "Tests" are scenario fixtures under `plugins/pmos-toolkit/skills/backlog/tests/`:

- `tests/fixtures/empty-repo/` — fresh init.
- `tests/fixtures/with-items/` — assorted items in each status.
- `tests/fixtures/multi-repo-workstream/` — two linked repos with overlapping ids.
- `tests/fixtures/with-archive/` — items eligible for archival.

Each fixture is paired with a `scenario.md` describing input commands and expected agent behavior (file mutations, output shape, refusal cases). Verified manually during skill development. Same approach as existing pmos-toolkit skills.

Critical scenarios to cover:
1. Quick-capture from inside an active `/execute` session — no interruption, returns id.
2. Type inference on ambiguous input — falls back to `idea`.
3. `/spec` invoked without `--backlog` — backlog untouched.
4. `/plan --backlog 42` writes plan doc — item `plan_doc` filled, status `planned`.
5. Archive run with mixed-age `done` items — only items >30 days move.
6. Workstream aggregation with id collisions — both shown with repo prefix.
7. Manually-edited `INDEX.md` followed by `/backlog list` — drift warning fires.

---

## 9. Open Questions / Deferred

- **Cross-repo dependencies.** `dependencies: [0015]` is repo-local. If we ever need workstream-level deps, the format becomes `{repo}#0015`. Defer until a real case appears.
- **Template customization.** The H2 body sections are fixed. Users wanting different sections (e.g., `## Reproduction Steps` for bugs) would need a per-type template system. Defer; keep schema rigid for now.
- **GitHub Issues sync.** Out of scope for v1. The `pr:` field is a passive link; no two-way sync. A future `/backlog sync-github` could mirror to/from issues.
- **Workstream-scoped items** (items with no repo home). Deferred per the brainstorm. Workaround: drop in the workstream's primary repo with `labels: [cross-repo]`.

---

## 10. Skill File Layout

Following pmos-toolkit conventions:

```
plugins/pmos-toolkit/skills/backlog/
├── SKILL.md                    # Frontmatter + Phase 0 router + phase bodies
├── schema.md                   # Item schema reference (enums, frontmatter, body)
├── inference-heuristics.md     # Type-from-keywords table for quick-capture
├── pipeline-bridge.md          # How --backlog <id> flows through pipeline skills
└── tests/
    ├── fixtures/
    │   ├── empty-repo/
    │   ├── with-items/
    │   ├── multi-repo-workstream/
    │   └── with-archive/
    └── scenarios.md
```

Pipeline skills (`requirements`, `spec`, `plan`, `execute`, `verify`) get small additions:
- Accept `--backlog <id>` argument.
- On invocation with no seed, optionally pull from `/backlog list --status ready`.
- On doc-write success, if `--backlog <id>` is set, call into the backlog skill's pipeline-bridge to update the item.

These additions are kept small and isolated; the existing pipeline behavior is unchanged when `--backlog` is absent.
