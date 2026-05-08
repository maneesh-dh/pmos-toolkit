# /changelog: prefer existing `docs/changelog.md` sibling over `settings.yaml` `docs_path` — Requirements

**Date:** 2026-05-08
**Last updated:** 2026-05-08
**Status:** Draft
**Tier:** 1 — Bug Fix

## Problem

`/changelog` resolves the changelog file by reading `docs_path` from `.pmos/settings.yaml` and writing to `{docs_path}/changelog.md` unconditionally. When a repo has `docs_path: .pmos` (or any non-`docs/` value) but already maintains a `docs/changelog.md` per its CLAUDE.md observed-convention guidance, the skill writes to the wrong file. The user must manually intercept and override — first noticed in the 2026-05-08 retro where the skill drafted toward `.pmos/changelog.md` while the project's CLAUDE.md explicitly said to follow the `docs/` sibling convention.

### Who experiences this?

Maintainers of pmos-toolkit-using repos whose `settings.yaml :: docs_path` was set before the repo adopted a `docs/` convention (or never aligned with it), and whose CLAUDE.md tells future agents to honor the observed `docs/` location.

### Reproduction / Root Cause

1. Repo has `.pmos/settings.yaml` with `docs_path: .pmos/`.
2. Repo also has `docs/changelog.md` with prior dated entries.
3. Repo's CLAUDE.md says to write changelog to `docs/` per observed convention.
4. Run `/changelog`.
5. **Observed:** skill targets `.pmos/changelog.md`; user must manually redirect.
6. **Expected:** skill detects the existing sibling, prefers it, and emits a one-line advisory about the settings/convention mismatch.

**Root cause:** `## Determine docs_path` in `plugins/pmos-toolkit/skills/changelog/SKILL.md:11–13` resolves a single path from settings with no probe for an existing sibling `docs/changelog.md`. Process steps 1 (scope read) and 5 (write) both consume that single resolution.

### Investigated

- `plugins/pmos-toolkit/skills/changelog/SKILL.md` lines 11–13 (resolution), 102 (scope read), 120 (write).

## Fix Direction

After resolving `docs_path` from settings, probe `{repo_root}/docs/changelog.md`. Prefer the existing sibling when (a) it exists AND (b) `docs_path` does not already resolve to `docs/`. Emit a single non-blocking advisory line noting the settings/observed-convention mismatch and suggesting the user reconcile `settings.yaml`. Apply the resolved path consistently to both Process steps 1 (scope read) and 5 (write). Behavior is unchanged when `docs_path == docs/` or no sibling `docs/changelog.md` exists.

## Acceptance Criteria

- [ ] When `.pmos/settings.yaml :: docs_path` is non-`docs/` AND `{repo_root}/docs/changelog.md` exists, the skill resolves the changelog path to `docs/changelog.md` (sibling-prefer behavior).
- [ ] When sibling-prefer behavior fires, the skill emits exactly one advisory line to the user noting the mismatch and suggesting `settings.yaml` reconciliation. The advisory does NOT block (no `AskUserQuestion`).
- [ ] When `docs_path == docs/`, the skill resolves to `docs/changelog.md` with no advisory.
- [ ] When `docs_path` is non-`docs/` AND no `docs/changelog.md` exists, the skill resolves to `{docs_path}/changelog.md` (current behavior preserved) with no advisory.
- [ ] Both Process step 1 (scope read of last entry date) and step 5 (prepend write) target the same resolved path within one run.
- [ ] No new phases are added; no new reference files are created; the `argument-hint` contract is unchanged.

## Decisions

| # | Decision | Options Considered | Rationale |
|---|----------|-------------------|-----------|
| D1 | Sibling-prefer rule scoped to `docs/changelog.md` only | (a) Only `docs/changelog.md`, (b) any sibling under `docs/`, (c) parameterize via settings | (a) — `changelog.md` is a single well-known artifact; broader sibling search adds surface area for false matches; settings parameter would invite the very mismatch the fix is correcting |
| D2 | Advisory is non-blocking (one stderr/console line) | (a) Block via `AskUserQuestion`, (b) one-line advisory, (c) silent | (b) — blocking re-introduces friction the fix is meant to remove; silent leaves the underlying settings drift uncorrected. One line surfaces the issue without interrupting flow |
| D3 | Mismatch detection uses string compare on resolved `docs_path` against `docs/` | (a) String compare with normalization, (b) realpath compare | (a) — settings store the literal string the user wrote; normalize trailing slash before compare; realpath would mask intent when symlinks involved |

## Open Questions

_(none — fix direction is unambiguous)_
