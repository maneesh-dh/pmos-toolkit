# Changelog

## pmos-toolkit 2.24.0 — 2026-05-08

### Added

- **`/update-skills`** — new pipeline enhancer that turns skill feedback (raw text or `/retro` paste-back) into shipped changes end-to-end. Parses findings, critiques each against the current skill source, gets per-finding keep/drop approval via the Findings Protocol, then runs `/requirements -> /spec -> [/grill] -> /plan -> /execute -> /verify` per affected skill (auto-tiered, sequential, halt-on-failure, resume-from-triage-doc).

### References

- `docs/pmos/features/2026-05-08_update-skills-skill/02_spec.md`
- `plugins/pmos-toolkit/skills/update-skills/SKILL.md`

## pmos-toolkit 2.23.0 — 2026-05-08

### Added

- **`/complete-dev`** — new 19-phase end-of-development orchestrator that follows `/verify`. Merges feature work into main, cleans up worktrees, detects deploy norms (CLAUDE.md / package.json / Makefile / CI / plugin manifest), captures diff-scoped learnings, refreshes the README skill inventory, runs `/changelog`, bumps paired plugin manifests, tags the release, and pushes sequentially to every configured remote with halt-on-origin-failure recovery. Supersedes the legacy `/push` skill. Terminal stage of the `requirements -> spec -> plan -> execute -> verify -> complete-dev` pipeline.

### References

- `plugins/pmos-toolkit/skills/complete-dev/SKILL.md`

## pmos-toolkit 2.22.0 — 2026-05-08

### Breaking changes

- **`/msf` removed**, replaced by two purpose-built skills:
  - `/msf-req` — MSF analysis on a requirements doc (recommendations-only).
  - `/msf-wf` — MSF + PSYCH analysis on a wireframes folder; pass `--apply-edits` to apply user-approved HTML edits inline (typically invoked by `/wireframes` Phase 6).
- **PSYCH scoring moved** from `/wireframes` Phase 6 into `/msf-wf`. `/wireframes` Phase 6 is now a thin wrapper that delegates to `/msf-wf --apply-edits` and aborts on non-zero return.
- **PSYCH artifact unified.** Pre-2.22 PSYCH wrote to a separate `psych-findings.md`; from 2.22 PSYCH lives as Section B of `msf-findings.md`. `reference/psych-output-format.md` moved from `/wireframes/reference/` to `/msf-wf/reference/`.
- **Removed flags:** `--wireframes`, `--skip-psych`, `--default-scope`. The only flag on the new skills is `--apply-edits` (on `/msf-wf` only).
- **Findings doc location:** moved from `docs/msf/YYYY-MM-DD-<feature>-msf-analysis.md` to `<feature_folder>/msf-findings.md` for pipeline runs (or `~/.pmos/msf/YYYY-MM-DD_<slug>.md` for ad-hoc).

### Migration

- Anywhere you wrote `/msf <req-doc>`, write `/msf-req <req-doc>`.
- Anywhere you wrote `/msf <req-doc> --wireframes <folder>`, write `/msf-wf <folder>` (drop `--wireframes` — the folder is now the positional argument).
- `/wireframes` end-to-end behavior unchanged from the user's perspective; PSYCH still runs in Phase 6, just delegated. If `/msf-wf` errors mid-run, `/wireframes` aborts (FR-39) — re-run `/msf-wf` manually before continuing with `/spec`.
- Standalone `/msf` runs that wrote back to the source doc no longer happen — both replacement skills are recommendations-only by default; only `/msf-wf --apply-edits` mutates files (and only HTML wireframes, never the requirements doc).

### Internal

- New shared module: `plugins/pmos-toolkit/skills/_shared/msf-heuristics.md` — persona-alignment template, M/F/S 24 considerations, executive-summary template (referenced by both `/msf-req` and `/msf-wf`).
- `/wireframes/SKILL.md` trimmed by ~150 lines (Phase 6 PSYCH walkthrough + Phase 7 inline `/msf` invocation removed).
