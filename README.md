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

### Pipeline (requirements → spec → plan → execute → verify → complete-dev)

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
| `/pmos-toolkit:complete-dev` | End-of-dev orchestrator — merge, deploy per repo norms, capture learnings, /changelog, version bump, commit, tag, push to all remotes. Supersedes legacy /push (which remains available this release; will be removed next release) |

### Pipeline orchestrators

| Skill | Description |
|-------|-------------|
| `/pmos-toolkit:feature-sdlc` | End-to-end SDLC orchestrator — turns an initial idea into a shipped feature by sequentially driving requirements → grill → optional gates → spec → simulate-spec → plan → execute → verify → complete-dev. Auto-tiers, creates worktree + branch via `EnterWorktree` (with `cd <worktree> && claude --resume` handoff if the harness can't enter inline), persists resumable state inside the worktree, surfaces compact checkpoints before heavy phases. `/feature-sdlc list` shows in-flight features across all `feat/*` worktrees. `/feature-sdlc skill <description>` / `/feature-sdlc skill --from-feedback <…>` drive the same pipeline to author a new skill or apply feedback to existing skill(s), scoring each against a binary eval rubric before merge |
| `/pmos-toolkit:skill-sdlc` | Thin alias for `/feature-sdlc skill …` — create a new skill or apply retro/feedback to existing skill(s) via the full SDLC pipeline |
| `/pmos-toolkit:update-skills` | _Archived in 2.38.0 — superseded by `/feature-sdlc skill --from-feedback`; see `archive/skills/README.md`_ |

### Pipeline enhancers (optional)

| Skill | Description |
|-------|-------------|
| `/pmos-toolkit:msf-req` | Motivation/Satisfaction/Friction analysis on a requirements doc — recommendations-only |
| `/pmos-toolkit:msf-wf` | Grounded MSF + PSYCH analysis on a wireframes folder; `--apply-edits` to apply HTML edits inline (typically invoked from /wireframes Phase 6) |
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
| `/pmos-toolkit:create-skill` | _Archived in 2.38.0 — superseded by `/feature-sdlc skill <description>` (or the `/skill-sdlc` alias); see `archive/skills/README.md`_ |
| `/pmos-toolkit:diagram` | Generate a single SVG vector diagram from a free-form description — brainstorms 2–3 framings, drafts, and self-evaluates against a hybrid SVG-metrics + vision rubric |
| `/pmos-toolkit:survey-design` | Design a methodologically sound survey from a rough intent (or refine an existing one) — generates a sectioned `survey.json`, runs a reviewer-critique pass + a simulated-respondent friction walk, renders a fillable `preview.html`, and emits import files for Typeform / SurveyMonkey / Google Forms |
| `/pmos-toolkit:survey-analyse` | Analyse fielded survey responses (CSV / TSV / XLSX / XLS / PDF) and produce a defensible HTML report — bundled per-question-type Python helpers compute deterministic stats, the LLM authors a per-run `analysis.py`, open-end coding via subagent-per-question (Braun & Clarke), cross-tabs with Holm correction by default. Sister to `/survey-design` |
| `/pmos-toolkit:design-crit` | Critique an application URL, wireframes, or prototype on overall UX — captures flow screenshots via packaged Playwright script, evaluates against a Nielsen + WCAG 2.2 + visual + Gestalt + journey-friction rubric, runs a PSYCH/MSF pass, and synthesises prioritized recommendations |
| `/pmos-toolkit:mac-health` | Diagnose battery drain, orphaned processes, browser extension leaks, and cleanup opportunities |

**Pipeline flow:**

```
/requirements  →  [/wireframes  →  /prototype]  →  [/msf-req, /creativity, /grill]  →  /spec  →  [/simulate-spec]  →  /plan  →  /execute  →  /verify
                   optional bridges (UI features)    optional enhancers                  optional validator
```

`/polish`, `/artifact`, `/backlog`, `/mytasks`, `/people`, `/product-context`, `/changelog`, `/session-log`, `/retro`, `/feature-sdlc`, `/skill-sdlc`, `/diagram`, `/survey-design`, `/survey-analyse`, `/design-crit`, `/mac-health` are standalone — invoke them at any point.

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

Use `/pmos-toolkit:feature-sdlc skill <description>` (or the `/skill-sdlc` alias) inside a session, or manually:

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
