# Changelog

## pmos-toolkit 2.39.0 — 2026-05-13

### What's new

- **`/survey-analyse`** — new standalone utility, sister to `/survey-design`, that turns a raw survey response export (CSV / TSV / XLSX / XLS / PDF) into a defensible HTML report. Eight phases: ingest → user-confirmed schema (column-by-column; the LLM never silently auto-classifies) → cleaning (straightliners / speeders / incompletes / duplicates / attention checks, with rule counts logged) → per-question analysis via **bundled Python helper modules** (`scripts/helpers/{categorical,multi_select,likert,nps,ranking,matrix,numeric,stats,clean,ingest,schema,pii}.py` — pure stdlib + `openpyxl` for xlsx; each ships `--selftest`) — the LLM authors a per-run `analysis.py` that imports the helpers, then runs it via Bash with a single consolidated permission ask → open-end thematic coding via **subagent-per-question** (Braun & Clarke 6-phase contract; structured JSON return; validated against the verbatim ids) → whole-survey cross-tabs with **Holm correction applied by default** across each segment family (plain-language framing in the body; technical term in Methodology; `--raw-p-only` opts out) → HTML report through the `_shared/html-authoring/` substrate with executive summary, methodology & limitations, key findings, per-question, open-end themes, cross-tab appendix, data-quality log. Numbers are deterministic across runs on the same cleaned input; narrative + theme names are LLM-generated and disclosed as such. PII in verbatim quotes is **detect-and-warn only** — never auto-redacted. Bundled `reference/` files cover the per-question-type playbook, the thematic-coding contract, the cross-survey statistics (Holm, MoE, weighting), and the cleaning / reporting standards.

### Breaking changes

None.

### Migration

None — additive. New skill auto-discovered from `plugins/pmos-toolkit/skills/`.

## pmos-toolkit 2.36.0 — 2026-05-11

### What's new

- **`/survey-design`** — new standalone utility that turns a rough research intent (or an existing survey) into a fielded-ready survey. It interprets the design variables (audience, time budget, mode generative/evaluative/hybrid, optional question cap), generates a sectioned `survey.json` applying baked-in survey-methodology best practices and avoiding a built-in anti-pattern catalog (A1–E6, with detection signals), then runs a reviewer-critique pass and a simulated-respondent friction walk — each surfacing findings as batched, structured `Fix / Modify / Skip / Defer` questions — and renders a substrate-compliant `survey.html`, a standalone fillable `preview.html` (works on `file://`), a viewer `index.html`, and per-stage commits. Phase 8 emits import files for **Typeform** (`typeform.json` Create-API body), **SurveyMonkey** (`surveymonkey.json` + a plain-text paste fallback), and **Google Forms** (`build-google-form.gs` Apps Script), with unsupported types mapped down and every downgrade documented in `export/README.md`. Reference material lives in the skill's `reference/` directory (`survey-best-practices.md`, `question-antipatterns.md`, `platform-export.md`), loaded on demand.

### Breaking changes

None.

### Migration

None — additive. New skill auto-discovered from `plugins/pmos-toolkit/skills/`.

## pmos-toolkit 2.26.0 — 2026-05-08

### What's new

- **`/plan` v2** — tier-aware plan generation. Tier-1 bug-fixes ship as ≥1 task with reduced TN (no Decision-Log floor); Tier-3 features get mandatory Risks, ≥3 Decision-Log entries, and 2–4 review loops capped at 4 (FR-40). Plan documents now emit a YAML frontmatter contract (`tier`, `type`, `feature`, `spec_ref`, `requirements_ref`, `date`, `status`, `commit_cadence`, `contract_version`) so `/execute` can read them deterministically.
- **Stack-aware verification** — new `_shared/stacks/{npm,pnpm,yarn-classic,yarn-berry,bun,python,rails,go,static}.md` library. `/plan` v2 detects stack signals from manifest files and inlines the stack's lint / test / API-smoke commands into per-task verification steps (FR-10, FR-13). The 5 JS-stack files share a `## Common Preamble` enforced byte-equivalent by `tools/lint-js-stack-preambles.sh`.
- **Platform-neutral templates** — new `_shared/platform-strings.md` provides per-platform phrasing (claude-code, gemini, copilot, codex) for closing offers and skill-invocation refs.
- **Per-task contract fields** — every plan task now emits `**Depends on:**`, `**Idempotent:**`, `**Requires state from:**`, `**TDD:** yes — new-feature|yes — bug-fix|no — <reason>`, `**Data:**` alongside the existing `**Goal:**`/`**Spec refs:**`/`**Files:**`/`**Steps:**`. `/execute` v2 consumes them; missing optional fields trigger per-task `WARN:` lines on stderr (back-compat shim per FR-110).
- **Convergent review loops** — `/plan` v2 caps review at 4 loops; Loop 2 dispatches a fresh blind subagent (5-minute timeout, nested-subagent guard via `PMOS_NESTED=1`). Findings are auto-classified low-risk vs high-risk (default ambiguous → high-risk). Skip List persists across runs at `03_plan_skip-list.md` with hash-keyed entries.
- **Sidecar contracts** — review log accumulates at `03_plan_review.md`; non-interactive runs write `03_plan_auto.md` and on halt `03_plan_blocked.md`. All sidecar writes use same-directory-tempfile + `mv` rename for atomicity.
- **Defect handoff (E10)** — `/execute` v2 writes `03_plan_defect_<task-id>.md` on a planning defect; `/plan --fix-from <task-id>` consumes it; `/execute` deletes the defect file when the previously-defective task succeeds.
- **Spec frontmatter contract** — `/spec` Tier 1/2/3 templates emit `tier`/`type`/`feature`/`date`/`status`/`requirements`. Auto-derived kebab-case anchors at H2/H3 (collision dedupe via `-2/-3/...` suffix) so `/plan` Phase 4 can hard-fail on broken `02_spec.md#anchor` refs (FR-31a) and detect spec drift (FR-31b).
- **`/backlog` `type` enum extended** — adds `enhancement`, `chore`, `docs`, `spike` to the existing `feature`/`bug`/`tech-debt`/`idea`. Inference heuristics extended with keyword tables for the new values.
- **Operational modes** — `/plan` v2 supports Edit / Replan / Append modes plus `--non-interactive` (FR-61, FR-61a halt protocol with exit code 2 + `03_plan_blocked.md`).

### Breaking changes

- **None at runtime.** Back-compat shim in `/execute` v2 warns on missing optional task fields rather than failing (decision P5 / FR-110). `/plan` v1 plans still execute.
- The `/spec` Phase 7 promotion now `Edit`s the frontmatter `status: Draft` line (was the prose `**Status:** Draft` line). Specs written by /spec v1 need their `**Status:** Draft` line manually moved into frontmatter on next /spec re-run.

### Migration

- No code migration required. First run of /plan v2 against a /spec v1 spec emits a frontmatter-validation refusal — re-run /spec to re-emit with v2 frontmatter, then /plan.

---

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
