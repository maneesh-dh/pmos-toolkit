# PMOS Toolkit

A plugin marketplace for Claude Code and Codex CLI that provides a structured software delivery pipeline — from requirements through to verification.

**Plugin name:** `pmos-toolkit`
**Namespace:** Skills are invoked as `/pmos-toolkit:<skill-name>`

## Repository Structure

```
pmos-toolkit/
├── .claude-plugin/
│   └── marketplace.json       Marketplace manifest (this repo IS the marketplace)
├── .codex/
│   └── INSTALL.md             Codex installation instructions
├── plugins/
│   └── pmos-toolkit/
│       ├── .claude-plugin/
│       │   └── plugin.json    Plugin manifest
│       ├── .codex-plugin/
│       │   └── plugin.json    Codex plugin manifest
│       ├── skills/            Plugin skills
│       └── agents/            Shared agent definitions
```

## Skills

| Skill | Description |
|-------|-------------|
| `/pmos-toolkit:requirements` | Brainstorm and shape a requirements document — first pipeline stage |
| `/pmos-toolkit:creativity` | Structured creativity techniques for non-obvious improvements (optional enhancer) |
| `/pmos-toolkit:msf` | Motivation, Satisfaction, Friction analysis with PSYCH scoring (optional enhancer) |
| `/pmos-toolkit:spec` | Technical specification from requirements — second pipeline stage |
| `/pmos-toolkit:plan` | Execution plan from a spec — third pipeline stage |
| `/pmos-toolkit:execute` | Implement a plan end-to-end with TDD and verification |
| `/pmos-toolkit:verify` | Post-implementation verification gate — lint, test, review, QA |
| `/pmos-toolkit:changelog` | Generate user-facing changelog entries after merging to main |
| `/pmos-toolkit:session-log` | Capture learnings, decisions, and patterns from a session |
| `/pmos-toolkit:create-skill` | Create a new skill with cross-platform conventions |
| `/pmos-toolkit:mac-health` | Diagnose battery drain, orphaned processes, and cleanup opportunities |

**Pipeline flow:**
```
/requirements  →  [/msf, /creativity]  →  /spec  →  /plan  →  /execute  →  /verify
                   optional enhancers
```

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

Changes to skill files take effect after restarting your session or running `/reload-plugins`.

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

2. Restart your session or run `/reload-plugins`.

## Updating

```bash
# Claude Code updates automatically via the marketplace.
# For Codex:
cd ~/.codex/pmos-toolkit && git pull
```

## Requirements

- Claude Code or Codex CLI
