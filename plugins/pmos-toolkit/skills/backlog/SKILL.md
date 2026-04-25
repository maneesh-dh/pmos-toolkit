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
