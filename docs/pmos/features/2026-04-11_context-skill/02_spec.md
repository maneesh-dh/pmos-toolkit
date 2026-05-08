# /context Skill — Design Spec

**Date**: 2026-04-11
**Status**: Draft
**Skill**: `/pmos-toolkit:context`

---

## Problem

Every pmos-toolkit pipeline session starts cold. Users re-explain their product, domain, constraints, and goals each time they run `/requirements`, `/spec`, or `/plan`. Context that was established in one session evaporates before the next. This leads to generic output that doesn't reflect the user's actual product, users, or business constraints.

## Solution

A `/context` skill that creates and maintains persistent workstream context — accessible across repos and sessions. Context is stored globally, linked per-repo, and progressively enriched through document ingestion and pipeline skill sessions.

## Design Principles

1. **Progressive disclosure**: 2 questions to get started, grows richer over time
2. **Infer before asking**: Auto-scan repo for signals, ask only what can't be determined
3. **Concrete diffs, not vague offers**: Enrichment shows exactly what would change, user approves
4. **No degradation**: Skills work exactly as today when no context exists
5. **One file per workstream**: Flat structure, no nested hierarchies

---

## Storage Architecture

### Global context (cross-repo)

```
~/.pmos/
  workstreams/
    {slug}.md                     # one file per workstream
```

Each workstream file is a self-contained markdown document with YAML frontmatter and structured sections. Files follow one of three templates: product, charter, or feature.

### Local repo linkage

```
.pmos/
  settings.yaml                   # links repo to a workstream + local settings
  requirements/                   # pipeline artifacts (default location)
  specs/
  plans/
  session-log.md
  changelog.md
```

### settings.yaml

```yaml
# Which workstream context to load for this repo
workstream: my-fintech-app

# Where pipeline docs are stored (default: .pmos)
docs_path: .pmos
```

- Created automatically by `/context init` or by the fallback prompt when a pipeline skill runs without it
- `docs_path` controls where all pipeline skills write their artifacts. Default is `.pmos/`. Users can override to `docs` or any path. Every pipeline skill reads this setting.

### Context resolution

When a pipeline skill runs:

1. Read `.pmos/settings.yaml` in current repo
2. Load `~/.pmos/workstreams/{workstream}.md`
3. If the workstream is type `charter` or `feature` and has a `product` field in frontmatter, also load `~/.pmos/workstreams/{product}.md` as read-only parent context
4. Inject workstream content as context preamble before the skill does its work

If no `settings.yaml` exists, see Fallback Behavior below.

---

## Workstream Templates

### Product Template

For a full product — a SaaS tool, an app, a platform.

```markdown
---
name: {product name}
type: product
created: {date}
updated: {date}
---

## Description
{One-line description}

## Value Proposition
{Why does this product exist? What problem does it solve?}

## User Segments
{Who uses this? What are their characteristics?}

## Tech Stack
{Languages, frameworks, infrastructure, deployment}

## Competitors / Alternatives
{What else exists in this space? How is this different?}

## Key Metrics
{How do you measure success?}

## Charters

### {Charter Name}
- **Problem**:
- **North star metric**:
- **Active initiatives**:

## Rollout & Release (optional)
{Feature flags, staged rollout groups, release process, deployment mechanisms}

## Constraints & Scars (optional)
{Past incidents, hard-learned lessons, or organizational constraints that shape decisions}

## Team & Stakeholders (optional)
{Who's involved? What do they care about?}

## Key Decisions
{Significant decisions with rationale, added over time}
```

### Charter Template

For a specific problem area within a product — payments, growth, onboarding. Can be standalone or reference a parent product.

```markdown
---
name: {charter name}
type: charter
product: {parent product slug, if applicable}
created: {date}
updated: {date}
---

## Description
{What problem area does this charter own?}

## North Star Metric
{Primary measure of success}

## User Segments
{Which users does this charter serve?}

## Current Initiatives
{What's actively being worked on?}

## Constraints & Decisions
{Technical or business constraints, key decisions made}

## Team & Stakeholders (optional)
{Who's involved? What do they care about?}
```

### Feature Template

For a focused piece of work that may span multiple enhancements over time.

```markdown
---
name: {feature name}
type: feature
product: {parent product slug, if applicable}
charter: {parent charter slug, if applicable}
created: {date}
updated: {date}
---

## Description
{What is this feature?}

## Problem
{What problem does it solve?}

## Success Metrics
{How do you know it worked?}

## Target Users
{Who benefits?}

## Technical Context
{Relevant tech constraints or dependencies}
```

### Template design rules

- Empty sections are placeholders for future enrichment, not obligations
- `updated` timestamp changes on every enrichment for staleness visibility
- Frontmatter `type` field lets skills know which template was used
- Users can add custom sections organically — templates are starting points
- Team & Stakeholders is optional — appears when relevant, doesn't clutter the template for solo users

---

## Skill Interface

### `/context init`

Creates a new workstream and links the current repo to it.

**Flow:**

1. **Auto-scan** the current repo for context signals:
   - `README.md`, `README`
   - `package.json`, `pyproject.toml`, `Cargo.toml` (name, description, dependencies for tech stack)
   - `CLAUDE.md`, `.cursorrules` (project conventions)
   - `docs/` directory (existing requirements, specs, PRDs)
   - Any existing `.pmos/` artifacts

2. **If rich signals found** → synthesize a draft context and present it:
   > "Based on your repo, here's what I gathered:"
   >
   > **Product**: BookCompanion — AI-powered reading companion
   > **Tech stack**: Next.js, Python/FastAPI backend, Postgres, Vercel
   > **User segments**: (couldn't determine — will fill in over time)
   >
   > "Does this look right? Want to adjust anything?"

   **If thin signals** (empty repo, minimal README) → fall back to asking:
   - Product/area name
   - "How would you explain this to someone at a dinner party who's genuinely interested?" — this framing gets richer, more natural descriptions than "describe your product"

3. **Ask scope question**:
   > "Is this the whole product, or are you focused on a specific area within it (like a particular problem space with its own goals)?"

   - If whole product → use product template
   - If specific area → ask area name + problem it focuses on, use charter template, ask for parent product name

4. **Document ingestion**:
   > "Got any existing docs, links, or notes? I can read files, URLs, or Notion pages to build a richer context. Or we can skip this and build context over time."
   >
   > "Things that work great: landing pages, pitch decks, strategy docs, competitor analyses, product tour transcripts (Loom/video transcripts), user research summaries, or even just a few paragraphs you've written about the product anywhere."

   If docs provided → ingest, synthesize, merge into appropriate template sections.

5. **Write files**:
   - Create `~/.pmos/workstreams/{slug}.md` using the appropriate template
   - Create `.pmos/settings.yaml` in current repo
   - Show what was created, offer to review

**Guard**: If `.pmos/settings.yaml` already exists, inform the user context is already set up and suggest `/context update` instead.

### `/context update`

Updates an existing workstream. Three modes:

- **No args**: "What would you like to update?" — open-ended. User describes changes, skill drafts edits to workstream file, shows diff, applies on approval.
- **With docs/URLs**: Ingests provided documents, identifies new signals, drafts additions to workstream file, shows diff, applies on approval.
- **With flags**:
  - `--add-charter "Growth"` — adds a charter section to a product workstream
  - `--add-stakeholder "Sarah, Eng Lead"` — adds to Team & Stakeholders section

**Enrichment prompts**: When `/context update` is called with no args, the skill can suggest specific areas to enrich based on what's empty in the workstream. Beyond the standard template sections, useful prompts include:
- "Are there any past mistakes, incidents, or 'scars' that heavily influence how decisions get made?" — surfaces hidden constraints that wouldn't appear in documentation but shape every spec and plan
- "What does your rollout/release process look like? Feature flags, staged rollouts, beta groups?" — useful context for `/spec` and `/plan` to produce realistic deployment strategies
- "How does your product grow? What's the growth model?" — helps `/requirements` tie features to business impact

### `/context show`

Reads `.pmos/settings.yaml`, loads the linked workstream (and parent if applicable), displays it. Simple utility for "what context do my skills see right now?"

---

## Fallback Behavior

When a pipeline skill runs and `.pmos/settings.yaml` doesn't exist:

1. Check if `~/.pmos/workstreams/` has any workstream files
2. **If workstreams exist** → list them with an option to create new:
   ```
   I found these workstreams:
   
     1. My Fintech App (product)
     2. Payments Redesign (charter)
     3. Search V2 (feature)
     4. Create a new workstream
   
   Which one is this repo related to? (or 'none' to skip)
   ```
   - If user picks an existing workstream → create `.pmos/settings.yaml`, continue with the skill
   - If user picks "Create a new workstream" → run `/context init` flow
3. **If no workstreams exist** → "No workstream context found. Want to set one up?" If yes → run `/context init`. If no → skill proceeds without context.

This is a one-time prompt per repo. After the first selection, `.pmos/settings.yaml` exists and the fallback never triggers again.

---

## Automatic Enrichment

### Which skills capture what

| Skill | Signals it can capture |
|-------|----------------------|
| `/requirements` | User segments, problem statements, metrics, value prop |
| `/spec` | Tech stack decisions, architectural constraints, API patterns |
| `/plan` | Technical dependencies, infrastructure details |
| `/execute` | Key decisions made during implementation |
| `/session-log` | Decisions, gotchas, learnings |

### How enrichment works

At session end, if a pipeline skill detected new context signals:

1. Compare what the skill produced against what's in the workstream file
2. Identify empty sections that now have relevant information, or existing sections that could be expanded
3. Draft specific additions as a concrete diff:

   ```
   Based on this session, I'd update your workstream context:
   
     ## User Segments
     + Small business owners (1-50 employees) managing        ← new
       invoices manually                                       ← new
     
     ## Key Metrics
     + Target: 40% reduction in manual invoice processing      ← new
     + Measurement: time-to-complete for invoice workflows     ← new
   
   Apply these updates? (y/n)
   ```

4. If approved → apply edits to workstream file, bump `updated` timestamp
5. If declined → nothing changes

### Signal detection logic

Not NLP — simple structural matching:
- If the workstream file has an empty `## User Segments` section and the requirements doc produced in this session describes user segments → propose adding them
- If `## Tech Stack` is empty and the spec names frameworks → propose adding them
- Compare produced content against existing workstream sections. Empty section + relevant output = propose an update.

---

## Impact on Existing Pipeline Skills

### Changes required

Each pipeline skill needs two additions:

1. **Context loading** (at skill start): Read `.pmos/settings.yaml` → load workstream → inject as preamble. If no settings file, trigger fallback behavior. If user skips, proceed without context.

2. **Enrichment check** (at skill end): Compare session output against workstream sections. If new signals found, draft diff and ask for approval.

3. **Docs path** (artifact output): Read `docs_path` from `.pmos/settings.yaml` to determine where to write requirements/specs/plans. Default to `.pmos/` if setting exists but `docs_path` is not specified. Default to `docs/` if no settings file exists (preserves backward compatibility). Skills create subdirectories (e.g., `requirements/`, `specs/`) under `docs_path` as needed on first write.

### Backward compatibility

- No `.pmos/settings.yaml` → skills work exactly as today, writing to `docs/`
- Existing repos with artifacts in `docs/` continue working. Migration to `.pmos/` is opt-in via `docs_path` setting.
- No workstream files → no context loaded, no enrichment proposed

---

## User-Facing Terminology

Internal terms mapped to user-facing language:

| Internal | User-facing |
|----------|------------|
| workstream | workstream (neutral, no jargon) |
| charter | "area" or "problem area" — used in prompts and questions |
| product | "product" — universally understood |
| feature | "feature" — universally understood |

The word "charter" appears only in template filenames and frontmatter `type` field. Users see "area" in all interactive prompts.

---

## Out of Scope for v1

- Staleness warnings ("your context is 3 months old") — future nicety
- Multi-workstream per repo — one repo links to one workstream
- Workstream archival or deletion commands
- Context sharing between users / team sync
- Automatic migration of existing `docs/` artifacts to `.pmos/`
