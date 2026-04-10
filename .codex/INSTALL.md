# Installing PMOS Toolkit for Codex

Enable pmos-toolkit skills in Codex via native skill discovery. Just clone and symlink.

## Prerequisites

- Git

## Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/maneesh-dhabria/pmos-toolkit.git ~/.codex/pmos-toolkit
   ```

2. **Create the skills symlink:**
   ```bash
   mkdir -p ~/.agents/skills
   ln -s ~/.codex/pmos-toolkit/plugins/pmos-toolkit/skills ~/.agents/skills/pmos-toolkit
   ```

3. **Restart Codex** (quit and relaunch the CLI) to discover the skills.

## Verify

```bash
ls -la ~/.agents/skills/pmos-toolkit
```

You should see a symlink pointing to your pmos-toolkit skills directory.

## Updating

```bash
cd ~/.codex/pmos-toolkit && git pull
```

Skills update instantly through the symlink.

## Uninstalling

```bash
rm ~/.agents/skills/pmos-toolkit
```

Optionally delete the clone: `rm -rf ~/.codex/pmos-toolkit`
