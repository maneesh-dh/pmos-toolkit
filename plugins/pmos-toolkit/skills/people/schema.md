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
