# /complete-dev: detect Python/PyPI publish path in deploy norms (C3) — Requirements

**Date:** 2026-05-08
**Last updated:** 2026-05-08
**Status:** Draft
**Tier:** 2 — Enhancement (collapsed: requirements + spec + plan inline per pragmatic /update-skills sub-pipeline)

## Problem

`/complete-dev` Phase 5 detects deploy norms by probing CLAUDE.md, `package.json`, `Makefile`, GitHub workflows, and plugin manifests. Python/PyPI publishing via `pyproject.toml` is missed entirely. In the recent retro, a project that ships to PyPI via `uv publish` produced zero detected signals and the recommended action was "skip explicit deploy" — leaving the documented PyPI distribution path off the menu.

### Who experiences this?

Maintainers shipping Python packages (or polyglot repos with a Python backend) who run `/complete-dev` and expect their `pyproject.toml`-based publish flow to surface as a deploy option.

### Why now?

The pmos-toolkit pipeline's "verify-then-ship" loop relies on Phase 5 surfacing every viable deploy path. Missing PyPI silently leads to either (a) the user manually shipping after the skill exits, or (b) the artifact never reaching the registry.

## Goals & Non-Goals

### Goals
- Phase 5 detects `pyproject.toml` with `[project]` metadata at repo root and at common nested paths (e.g., `backend/`) — measured by: in a fixture repo with `pyproject.toml`, the detected-signals list includes a PyPI entry.
- When PyPI is detected, the deploy menu offers "Build + publish to PyPI via `uv publish`" as one option — measured by: option appears in the `AskUserQuestion` block before the "Skip" option.
- Existing detection signals (CLAUDE.md, package.json, Makefile, workflows, plugin manifest) continue to work unchanged — measured by: no test or behavior regression in fixtures that don't have `pyproject.toml`.

### Non-Goals
- NOT auto-running `uv publish` without user approval — because the skill's existing pattern is enumerate-then-ask, never silent execution.
- NOT supporting non-uv tools (`twine`, `flit`, `poetry publish`) in this iteration — because the user retro specifically named `uv publish` and expanding the surface invites scope creep; the menu can list alternatives in a follow-up.
- NOT validating that `[project] :: name` and `[project] :: version` are present beyond a structural check — because malformed `pyproject.toml` is the user's problem, not ours.

## Solution Direction

In Phase 5 of `complete-dev/SKILL.md` and in `reference/deploy-norms.md`, add a new signal #6: `pyproject.toml` probe. The probe checks `{repo_root}/pyproject.toml` and `{repo_root}/backend/pyproject.toml` (the most common nested layout) for a `[project]` table. When found, the detected-signals list includes "PyPI publish via `pyproject.toml` at `<path>`", and the deploy-menu options gain "Build + publish to PyPI via `uv publish` (Recommended for PyPI signal)" — the existing recommendation logic is extended so that PyPI signal alone recommends the publish option, but combined with CI auto-deploy still defers to CI.

## User Journeys

### Primary Journey
1. User runs `/complete-dev` on a repo with `pyproject.toml` and no other deploy signals.
2. Phase 5 enumerates: `(1) pyproject.toml at ./pyproject.toml — package "<name>" v<version>`.
3. Skill prompts: "Which deploy path?" with options including "Build + publish to PyPI via `uv publish` (Recommended)".
4. User picks PyPI publish; skill runs `uv build && uv publish` (gated by user confirmation in Phase 15 deploy step, not Phase 5).

### Edge Cases
- **Both `pyproject.toml` and CI auto-deploy detected:** Recommendation defers to CI (matches existing combined-signal logic); PyPI option remains available as an explicit choice.
- **`pyproject.toml` exists but lacks `[project]` table** (e.g., legacy `setup.py`-style or tooling-only config like `[tool.ruff]`-only): probe skips it (no PyPI signal); same behavior as no `pyproject.toml`.
- **Both root and nested `pyproject.toml`:** list both paths; pick the one with `[project]` metadata; if both have it, prompt the user which to ship.

## Design Decisions

| # | Decision | Options Considered | Rationale |
|---|----------|-------------------|-----------|
| D1 | Probe paths: `./pyproject.toml` and `./backend/pyproject.toml` only | (a) Root only, (b) root + `backend/`, (c) full repo glob | (b) — root covers single-package repos; `backend/` covers the agent-skills-style polyglot layout from the retro; full glob is too noisy and slow |
| D2 | Tool: `uv publish` (not `twine`/`poetry`) | (a) `uv`, (b) `twine`, (c) any tool detected from lockfile | (a) — retro named `uv publish` specifically; matches the pmos-toolkit convention of "one canonical recommendation per deploy norm"; alternatives can be added in follow-up |
| D3 | `[project]` table required to count as a PyPI signal | (a) File existence alone, (b) require `[project]` table, (c) require `[project] :: name` AND `version` | (b) — raw file presence false-positives on tooling-only configs (e.g., a repo using `pyproject.toml` only for `[tool.ruff]`); requiring full name+version is too strict because some packages use dynamic versioning |
| D4 | Combined CI + PyPI signal → defer to CI | (a) Defer to CI, (b) recommend PyPI, (c) ask user with no recommendation | (a) — matches existing combined-signal heuristic ("CI auto-deploy + local script → skip local; trust CI"); preserves the consistency of the rubric |

## Acceptance Criteria

- [ ] AC1 — Phase 5 in `SKILL.md` lists a 6th signal: `pyproject.toml` with `[project]` metadata; probe checks `./pyproject.toml` and `./backend/pyproject.toml`.
- [ ] AC2 — `reference/deploy-norms.md` gains a new signal section (#6 PyPI / pyproject.toml) with the same shape as existing signal sections (`bash` probe + parsing notes).
- [ ] AC3 — `reference/deploy-norms.md` Recommendation Logic table gains rows for PyPI-alone and PyPI+CI cases; per D4, PyPI+CI defers to CI; PyPI-alone recommends `uv publish`.
- [ ] AC4 — Phase 5 example block in `SKILL.md` updated to show a PyPI-detected example, OR a comment notes the new option appears in the menu.
- [ ] AC5 — When no `pyproject.toml` is present, Phase 5 behavior is byte-identical to today (no advisory, no extra menu option).
- [ ] AC6 — `argument-hint`, phase numbering, and any other public contract of `complete-dev` SKILL.md remain unchanged.

## Open Questions

_(none — D1–D4 cover the design choices)_
