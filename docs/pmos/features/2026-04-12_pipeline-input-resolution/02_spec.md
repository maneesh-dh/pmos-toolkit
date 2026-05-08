# Pipeline Input Resolution — Design

**Date:** 2026-04-12
**Scope:** pmos-toolkit pipeline skills (`/msf`, `/creativity`, `/spec`, `/plan`, `/execute`, `/verify`)

## Problem

Each pipeline skill consumes a document produced by the previous phase. Today, users often re-type or paste the path to that document. Behavior across skills is inconsistent — `/spec` has partial auto-discovery; others prompt. We want a predictable, low-friction resolution that still lets the user override.

## Solution

Introduce a shared resolution procedure at `plugins/pmos-toolkit/skills/.shared/resolve-input.md`, referenced by every pipeline consumer skill. Each skill passes two parameters when invoking the procedure: the **phase directory** (e.g., `requirements`, `specs`, `plans`) and a human label (e.g., "requirements doc").

### Resolution Order

The procedure tries these in order and stops at the first hit:

1. **Explicit argument** — if the user passed an argument to the slash command, use it verbatim. A path is read as a file; non-path text is treated as inline content. Echo `Using: <path or inline>` and proceed.

2. **Conversation history** — if a document under `{docs_path}/<phase>/` was written, edited, or read earlier in this session, use the most recent one. Echo `Using from this session: <path>` and proceed. No prompt — the echo is the confirmation; the user can interrupt if wrong.

3. **Numbered picker over recent files** — list up to 3 most recent files in `{docs_path}/<phase>/` by mtime:
   - **0 files:** report the empty dir and ask the user to provide a path or inline content.
   - **1 file:** skip the list. Echo `Using: <path>` and proceed.
   - **2–3 files:** present a numbered list with paths and mtimes. Default is `[1]` (most recent). On confirmation, echo `Using: <path>` and proceed.

### Echo Contract

Every successful resolution prints a single line of the form `Using: <path>` (or the session/inline variant) before the skill continues. This is the only signal the user gets, so it must always appear — it lets the user catch a wrong pick immediately.

### Per-Skill Wiring

| Skill | Phase dir | Label |
|---|---|---|
| `/msf` | `requirements` | requirements doc |
| `/creativity` | `requirements` | requirements doc |
| `/spec` | `requirements` | requirements doc |
| `/plan` | `specs` | spec doc |
| `/execute` | `plans` | plan doc |
| `/verify` | `plans` | plan doc |

Each skill's "Locate the input" step becomes a single pointer: *"Resolve input per `.shared/resolve-input.md` with phase=`<dir>`, label=`<label>`."*

`{docs_path}` comes from the existing `product-context/context-loading.md` flow, so no new configuration.

### Non-Goals

- No cross-workstream search. Docs live under `{docs_path}/<phase>/`, which is already workstream-scoped.
- No fuzzy matching on partial filenames in the argument — if the user passes a path, it must resolve as-is.
- No caching of the "session doc" across sessions. History-based inference is session-local.

## File Changes

- **New:** `plugins/pmos-toolkit/skills/.shared/resolve-input.md` — the shared procedure.
- **Edited:** the six skills above — replace each skill's current input-location paragraph with the pointer line.

## Risks

- **Wrong silent pick from history.** Mitigated by always echoing the resolved path on one line; the user sees it before the skill does meaningful work.
- **Stale file picked from dir.** Mitigated by sorting by mtime and defaulting to `[1]`; user can pick `2` or `3` or pass an explicit path.
