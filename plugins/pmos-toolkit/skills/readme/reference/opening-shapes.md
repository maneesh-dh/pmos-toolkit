# opening-shapes — per-repo-type README opening patterns

## Contents

1. [The 5-block pattern](#1-the-5-block-pattern)
   - 1.1 [library](#11-library)
   - 1.2 [cli](#12-cli)
   - 1.3 [plugin](#13-plugin)
   - 1.4 [app](#14-app)
   - 1.5 [monorepo-package](#15-monorepo-package)
2. [The map+identity pattern](#2-the-mapidentity-pattern)
   - 2.1 [monorepo-root](#21-monorepo-root)
   - 2.2 [plugin-marketplace-root](#22-plugin-marketplace-root)
3. [Anti-patterns](#3-anti-patterns)

---

## 1. The 5-block pattern

Used by code-bearing repos. Five blocks in order: **hero -> proof -> show-don't-tell -> install -> why**.

- **hero** (1 sentence) — what + for-whom + why.
- **proof** (1-2 lines, optional) — badge or single concrete claim ("12 ms p99 over 1M ops").
- **show-don't-tell** (5-15 lines code or screenshot) — the smallest illustrative example.
- **install** (1-3 lines) — copy-paste-ready command.
- **why** (3-5 sentences) — the one paragraph that earns the reader's attention to keep reading.

The five blocks roughly map to the rubric's "opening" cluster: a missing hero trips `hero-line-presence`, a missing install/quickstart trips `install-or-quickstart-presence`, and a hero that doesn't communicate purpose trips `what-it-does-in-60s`.

### 1.1 library

```markdown
# ripgrep-py

Recursive grep for Python codebases — 10x faster than `grep -r` on
trees with >100k files.

![bench](https://img.shields.io/badge/p99-12ms-green)

    >>> from ripgrep_py import search
    >>> search("TODO", path="./src")
    ['src/api.py:42: # TODO: cache this',
     'src/cli.py:88: # TODO: drop py3.8 support']

    pip install ripgrep-py

Built on the `ripgrep` Rust binary; uses memory-mapped I/O and parallel
walking. Zero-config — point it at a tree and go.
```

**Rubric check fires on:** hero-line-presence, install-or-quickstart-presence, what-it-does-in-60s.

### 1.2 cli

```markdown
# goose

Lint your shell scripts before they bite. POSIX-compatible, single
static binary, ~3 MB.

    $ goose ./scripts/
    scripts/deploy.sh:14: unquoted $VAR in rm command (SC2086)
    scripts/build.sh:3:  missing #!/usr/bin/env bash shebang
    2 issues found.

    brew install goose          # macOS
    curl -sSL goose.sh | sh     # Linux

Written in Go, no runtime deps. Pairs with `shellcheck` — goose catches
the structural smells shellcheck doesn't (e.g. inconsistent quoting
conventions across a tree).
```

**Rubric check fires on:** hero-line-presence, install-or-quickstart-presence, what-it-does-in-60s.

### 1.3 plugin

Plugins are loaded by a host (an editor, a marketplace, a framework), not installed by end users at a shell. The "install" block becomes a *registration* line pointing at the marketplace entry — and is often omitted entirely in favor of a one-liner in the why section.

```markdown
# slackbot-pmos

A Slack bot that surfaces your pmos-toolkit backlog, tasks, and PR
review state without leaving the channel.

![host](https://img.shields.io/badge/host-pmos--toolkit-blue)

    /backlog show high
    -> 3 items P1, oldest 4d
    /mytasks today
    -> 2 due, 1 overdue (#tax-form-W9)

Registered via the `agent-skills-marketplace` plugin index — no separate
install. Configure `SLACK_BOT_TOKEN` and you're live. Built for solo PMs
who live in Slack and don't want to context-switch to a TUI.
```

**Rubric check fires on:** hero-line-presence, what-it-does-in-60s. (Plugins legitimately drop the user-facing install command.)

### 1.4 app

End-user apps invert the install block: the "install" is a download link or a screenshot, not a code fence. Proof shifts toward a screenshot or product shot.

```markdown
# notes-app

A keyboard-first Markdown notes app for people who think in outlines,
not in files. macOS + Linux, single binary.

![screenshot](docs/screenshot.png)

    Download: notes-app.dev/download   (or)   brew install notes-app

Why another notes app? Because the existing ones either force you into
a database (Notion, Obsidian vaults) or force you to manage files
yourself. Notes-app does neither — it gives you one searchable outline
and gets out of the way.
```

**Rubric check fires on:** hero-line-presence, install-or-quickstart-presence, what-it-does-in-60s. (Quickstart can be a download link; the rubric counts a `Download:` line as quickstart-equivalent.)

### 1.5 monorepo-package

A package living inside a monorepo drops Install / Contributing / License — the root README owns those. The opening block adds a **Link Up** line back to the root.

```markdown
# @acme/parser

A streaming JSON parser used by every service in the acme monorepo.
Backpressure-aware, zero-copy on byte slices.

    import { parse } from "@acme/parser";
    for await (const tok of parse(stream)) { ... }

> Part of [acme/monorepo](../../README.md). See the root for
> install, contributing, and license.

Built because `JSON.parse` blocks the event loop on payloads >2 MB,
and our ingestion service routinely sees 50 MB chunks.
```

**Rubric check fires on:** hero-line-presence, what-it-does-in-60s, sections-in-recommended-order. (Monorepo-package legitimately drops contributing-link-or-section and license-present — the root carries them.)

## 2. The map+identity pattern

Used by repos that aren't themselves consumable code — they're collections. Pattern: **hero -> proof -> contents-table -> canonical-entry quickstart -> why-these-pieces**.

The "show-don't-tell" block is replaced by a *contents map* (the table). One canonical-entry quickstart anchors the reader so they know what a leaf looks like in practice.

### 2.1 monorepo-root

```markdown
# acme/monorepo

Backend services + shared libraries for acme.com — one repo, one CI,
one version-tagged release.

| Package          | Purpose                              |
| ---------------- | ------------------------------------ |
| @acme/parser     | streaming JSON parser                |
| @acme/api-server | the public HTTPS edge                |
| @acme/auth       | shared OAuth2 + session middleware   |

    # canonical entry: spin up the API
    pnpm install && pnpm --filter @acme/api-server dev

We co-locate these because they ship together and share types — a
breaking change in @acme/parser surfaces as a compile error in
@acme/api-server, not as a runtime bug in production.
```

**Rubric check fires on:** hero-line-presence, install-or-quickstart-presence, sections-in-recommended-order.

### 2.2 plugin-marketplace-root

```markdown
# agent-skills-marketplace

A curated set of Claude Code plugins for product, design, and engineering
workflows — installable individually or as a bundle.

| Plugin           | What it adds                                |
| ---------------- | ------------------------------------------- |
| pmos-toolkit     | requirements -> spec -> plan -> ship pipeline |
| frontend-design  | distinctive-UI generator                    |
| chrome-devtools  | browser automation via DevTools MCP         |

    # most-used: install pmos-toolkit
    /plugin install pmos-toolkit@agent-skills-marketplace

Why a marketplace and not one mega-plugin? Each plugin has a different
update cadence and a different audience — bundling them would force
every user to take every upgrade.
```

**Rubric check fires on:** hero-line-presence, install-or-quickstart-presence, sections-in-recommended-order.

## 3. Anti-patterns

- **Features-section-as-opening.** A bulleted Features list before the hero violates show-don't-tell. The reader doesn't yet know what the project IS — a list of attributes can't land.
- **Long preamble.** Multi-paragraph history/motivation before the hero. The hero earns the right to that history; flipping the order makes the reader work for information they haven't yet decided to want.
- **Install-before-what.** Pasting a `curl | sh` or `pip install` before the reader knows what they're installing or why. Install is block 4, never block 1.
- **Logo-only opening.** A centered SVG hero with no text sentence beneath it. Search engines, screen readers, and skim-readers all need the text hero — the logo is decoration, not substance.
- **Badge-wall opening.** Eight CI/coverage/version badges crammed above the hero. One proof badge max; the rest belong further down (or nowhere).
