# PMOS Toolkit

A plugin marketplace for Claude Code and Codex CLI that provides a structured software delivery pipeline — from requirements through to verification — plus supporting utilities for backlog tracking, personal tasks, prose polishing, and more.

**Plugin name:** `pmos-toolkit`
**Namespace:** Skills are invoked as `/pmos-toolkit:<skill-name>`

## Repository Structure

```
pmos-toolkit/
├── .claude-plugin/
│   └── marketplace.json       Marketplace manifest (this repo IS the marketplace)
├── .claude/
│   └── commands/              Project-scoped slash commands (e.g., /push)
├── .codex/
│   └── INSTALL.md             Codex installation instructions
├── plugins/
│   └── pmos-toolkit/
│       ├── .claude-plugin/
│       │   └── plugin.json    Claude Code plugin manifest
│       ├── .codex-plugin/
│       │   └── plugin.json    Codex plugin manifest
│       ├── skills/            Plugin skills
│       └── agents/            Shared agent definitions
├── docs/
│   ├── specs/                 Skill specs
│   └── plans/                 Implementation plans
└── skills/                    (Reserved for non-plugin skills; plugin loads from plugins/pmos-toolkit/skills/)
```

## Skills

### Pipeline (requirements → spec → plan → execute → verify)

| Skill | Description |
|-------|-------------|
| `/pmos-toolkit:requirements` | Brainstorm and shape a requirements document — first pipeline stage |
| `/pmos-toolkit:wireframes` | Generate static HTML wireframes (Tailwind, mid-fi, multi-device) for user-facing features — optional bridge between /requirements and /spec |
| `/pmos-toolkit:prototype` | High-fidelity interactive prototype (React via CDN + JSX, mock API) stitching wireframe screens into walkable journeys — optional bridge between /wireframes and /spec |
| `/pmos-toolkit:spec` | Technical specification from requirements — second pipeline stage |
| `/pmos-toolkit:simulate-spec` | Pressure-test a spec via scenario trace, fitness critique, interface cross-reference, targeted pseudocode — optional validator between /spec and /plan |
| `/pmos-toolkit:plan` | Execution plan from a spec — third pipeline stage |
| `/pmos-toolkit:execute` | Implement a plan end-to-end with TDD and verification |
| `/pmos-toolkit:verify` | Post-implementation verification gate — lint, test, multi-agent code review, interactive QA |

### Pipeline enhancers (optional)

| Skill | Description |
|-------|-------------|
| `/pmos-toolkit:msf` | Motivation, Satisfaction, Friction analysis with PSYCH scoring |
| `/pmos-toolkit:creativity` | Structured creativity techniques for non-obvious improvements |
| `/pmos-toolkit:grill` | Adversarially interview a plan, spec, or design to surface unresolved decisions and shaky assumptions |

### Artifacts & docs

| Skill | Description |
|-------|-------------|
| `/pmos-toolkit:artifact` | Generate, refine, and update PRDs, EDDs, Engineering Design Docs, Discovery Docs with section-level eval criteria + writing-style presets. Custom templates at `~/.pmos/artifacts/` |
| `/pmos-toolkit:polish` | Critique and refactor any markdown doc for clarity, concision, voice, and de-AI-slop — 14-check binary rubric with auto-apply + per-finding approval |
| `/pmos-toolkit:changelog` | Generate user-facing changelog entries after merging to main |
| `/pmos-toolkit:session-log` | Capture learnings, decisions, and patterns from a session |
| `/pmos-toolkit:retro` | Paste-back retrospective for every pmos-toolkit skill invoked in the session — severity-tagged feedback for skill authors |

### Tracking & context

| Skill | Description |
|-------|-------------|
| `/pmos-toolkit:product-context` | Persistent workstream context (product / area / feature) that enriches all pipeline skills across repos and sessions. Stored at `~/.pmos/workstreams/` |
| `/pmos-toolkit:backlog` | Lightweight, AI-readable backlog of features, bugs, tech-debt, and ideas inside the repo. Hybrid quick-capture + structured tracker; integrates with the pipeline via `--backlog <id>` |
| `/pmos-toolkit:mytasks` | Persistent personal task tracker (LNO importance, due dates, people, workstream). Lives at `~/.pmos/tasks/` |
| `/pmos-toolkit:people` | Shared person/contact directory consumed by /mytasks. Stored at `~/.pmos/people/` |

### Utilities

| Skill | Description |
|-------|-------------|
| `/pmos-toolkit:create-skill` | Create a new skill with cross-platform conventions and project save paths |
| `/pmos-toolkit:mac-health` | Diagnose battery drain, orphaned processes, browser extension leaks, and cleanup opportunities |

**Pipeline flow:**

```
/requirements  →  [/wireframes  →  /prototype]  →  [/msf, /creativity, /grill]  →  /spec  →  [/simulate-spec]  →  /plan  →  /execute  →  /verify
                   optional bridges (UI features)    optional enhancers              optional validator
```

`/polish`, `/artifact`, `/backlog`, `/mytasks`, `/people`, `/product-context`, `/changelog`, `/session-log`, `/retro`, `/create-skill`, `/mac-health` are standalone — invoke them at any point.

## Install

### Claude Code

```bash
/plugin marketplace add maneesh-dhabria/pmos-toolkit
/plugin install pmos-toolkit
```

### Codex

Tell Codex:

```
Fetch and follow instructions from https://raw.githubusercontent.com/maneesh-dhabria/pmos-toolkit/refs/heads/main/.codex/INSTALL.md
```

Or manually:

```bash
git clone https://github.com/maneesh-dhabria/pmos-toolkit.git ~/.codex/pmos-toolkit
mkdir -p ~/.agents/skills
ln -s ~/.codex/pmos-toolkit/plugins/pmos-toolkit/skills ~/.agents/skills/pmos-toolkit
```

Then restart Codex.

### Verify

Open a new session and run `/pmos-toolkit:spec` or `/pmos-toolkit:plan` to confirm the plugin is loaded.

## Local Development

For developing skills locally:

```bash
# Clone the repo
git clone https://github.com/maneesh-dhabria/pmos-toolkit.git

# Load directly (per-session)
claude --plugin-dir /path/to/pmos-toolkit
```

Changes to skill files take effect after restarting your session or running `/reload-plugins`. Plugin caching is keyed by `version` in `plugin.json` — bump the version on any skill content change, otherwise updates won't be picked up. Both `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` versions must match (enforced by `.githooks/pre-push`).

For pushing changes, use the project-scoped `/push` slash command. It walks pre-flight checks, version bump prompts, manifest sync verification, JSON schema validation, feature-branch reconciliation, commit-message review, stale branch cleanup, and sequential push to all 3 remotes.

## Adding New Skills

Use `/pmos-toolkit:create-skill` inside a session, or manually:

1. Create `plugins/pmos-toolkit/skills/<skill-name>/SKILL.md` with the required frontmatter:

```yaml
---
name: my-skill
description: What it does. When to use it. Natural trigger phrases.
user-invocable: true
argument-hint: "<what to pass>"
---
```

2. Bump `version` in BOTH `plugins/pmos-toolkit/.claude-plugin/plugin.json` and `plugins/pmos-toolkit/.codex-plugin/plugin.json` (must match).
3. Add a row to the Skills table in this README.
4. Restart your session or run `/reload-plugins`.

The `/push` command automates steps 2 and 3.

## Updating

```bash
# Claude Code updates automatically via the marketplace.
# For Codex:
cd ~/.codex/pmos-toolkit && git pull
```

## Requirements

- Claude Code or Codex CLI
