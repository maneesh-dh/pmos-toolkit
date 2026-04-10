# PMOS Toolkit

A plugin for Claude Code and Codex CLI that provides a structured software delivery pipeline — from requirements through to verification.

**Plugin name:** `pmos-toolkit`
**Namespace:** Skills are invoked as `/pmos-toolkit:<skill-name>`

## Repository Structure

```
agent-skills/
├── .claude-plugin/    Plugin manifest (Claude Code)
├── .codex-plugin/     Plugin manifest (Codex CLI)
├── skills/            Plugin skills (delivered via plugin system)
├── plugins/           Bundled third-party skills (e.g., impeccable design ecosystem)
├── agents/            Shared agent definitions
└── link-skills.sh     Symlink script for bundled third-party skills
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
| `/pmos-toolkit:macos-battery-drain-diagnostics` | Diagnose battery drain, orphaned processes, and cleanup opportunities |

**Pipeline flow:**
```
/requirements  →  [/msf, /creativity]  →  /spec  →  /plan  →  /execute  →  /verify
                   optional enhancers
```

## Installation

### Claude Code

**From GitHub:**

```bash
# Add the marketplace (one-time)
/plugin marketplace add maneeshdhabria/agent-skills

# Enable the plugin
/plugin enable pmos-toolkit
```

**Local development:**

```bash
# Clone the repo
git clone https://github.com/maneeshdhabria/agent-skills.git

# Load directly (per-session)
claude --plugin-dir /path/to/agent-skills

# Or set up a persistent local marketplace (see Local Development below)
```

### Codex CLI

Create or update `~/.agents/plugins/marketplace.json`:

```json
{
  "name": "local-plugins",
  "interface": { "displayName": "Local Plugins" },
  "plugins": [
    {
      "name": "pmos-toolkit",
      "source": { "source": "local", "path": "/path/to/agent-skills" },
      "policy": { "installation": "AVAILABLE" },
      "category": "Productivity"
    }
  ]
}
```

Then enable in `~/.codex/config.toml`:

```toml
[plugins."pmos-toolkit@local-plugins"]
enabled = true
```

### Verify

Open a new session. Try `/pmos-toolkit:verify` or `/pmos-toolkit:spec` to confirm the plugin is loaded.

## Local Development

For persistent local development without `--plugin-dir` on every session:

1. Clone this repo
2. Create a local marketplace directory:

```bash
mkdir -p ~/.claude/plugins/marketplaces/local-plugins/.claude-plugin
```

3. Create `~/.claude/plugins/marketplaces/local-plugins/.claude-plugin/marketplace.json`:

```json
{
  "name": "local-plugins",
  "owner": { "name": "Your Name" },
  "plugins": [
    {
      "name": "pmos-toolkit",
      "source": { "source": "local", "path": "/absolute/path/to/agent-skills" },
      "version": "1.0.0",
      "category": "productivity"
    }
  ]
}
```

4. Register the marketplace in `~/.claude/plugins/known_marketplaces.json`:

```json
{
  "local-plugins": {
    "source": { "source": "local", "path": "/path/to/local-plugins" },
    "installLocation": "/path/to/local-plugins"
  }
}
```

5. Enable in your `settings.json`:

```json
{
  "enabledPlugins": {
    "pmos-toolkit@local-plugins": true
  }
}
```

Changes to skill files take effect after restarting your session or running `/reload-plugins`.

## Bundled Third-Party Skills

The `plugins/` directory contains 23 design and frontend skills from the impeccable ecosystem (adapt, animate, arrange, audit, bolder, clarify, colorize, critique, delight, distill, extract, harden, impeccable, normalize, onboard, optimize, overdrive, polish, quieter, shape, typeset, etc.).

These are **not** part of the pmos-toolkit plugin. They're bundled for convenience and symlinked into config directories via `link-skills.sh`. If you already have the `frontend-design` plugin installed, you don't need these — the official plugin provides the same skills.

To set up the bundled skills:

```bash
# Edit CONFIG_DIRS in link-skills.sh to match your config directories, then:
./link-skills.sh
```

## Adding New Skills

Use `/pmos-toolkit:create-skill` inside a session, or manually:

1. Create `skills/<skill-name>/SKILL.md` with the required frontmatter:

```yaml
---
name: my-skill
description: What it does. When to use it. Natural trigger phrases.
user-invocable: true
argument-hint: "<what to pass>"
---
```

2. Restart your session or run `/reload-plugins`.

## Requirements

- Claude Code or Codex CLI
- Bash (for `link-skills.sh`, only needed for bundled third-party skills)
