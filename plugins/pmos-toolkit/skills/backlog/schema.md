# Backlog Item Schema

Every backlog item is a markdown file at `backlog/items/{id}-{slug}.md`.

## Filename

- `id`: 4-digit zero-padded sequential integer (`0001`, `0002`, …). Per-repo counters; no global coordination.
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
| `type` | one of: `feature` \| `enhancement` \| `bug` \| `tech-debt` \| `chore` \| `docs` \| `idea` \| `spike` |
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
