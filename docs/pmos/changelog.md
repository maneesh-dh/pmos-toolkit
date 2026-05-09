# Changelog

## 2026-05-10 — pmos-toolkit 2.33.0: HTML-native artifact generation across feature-folder pipeline skills

Migrates 10 feature-folder pipeline skills (`/requirements`, `/spec`, `/plan`, `/msf-req`, `/msf-wf`, `/simulate-spec`, `/grill`, `/artifact`, `/verify`, `/design-crit`) plus the `/feature-sdlc` orchestrator's tracking artifacts from markdown-primary to HTML-primary authoring. Establishes a shared `_shared/html-authoring/` substrate (template, conventions, vendored turndown UMD + GFM plugin, hand-authored style.css ≤30 KB, single-script viewer.js with file:// fallback + sessionStorage try/catch + clipboard execCommand fallback, zero-deps serve.js with explicit MIME map + port-fallback, `html-to-md.js` CLI shim).

### What's new

- **HTML-primary feature-folder artifacts.** Every pipeline-stage artifact (`01_requirements.html`, `02_spec.html`, `03_plan.html`, plus `/msf-req`, `/msf-wf`, `/simulate-spec`, `/grill`, `/artifact`, `/verify`, `/design-crit` outputs and the `/feature-sdlc` `00_pipeline.html` + `00_open_questions_index.html`) is authored as semantic HTML5 with `<section>` per H2, kebab-case stable IDs, sibling `<artifact>.sections.json` ground-truth manifest, asset-relative `assets/*` references, and zero server-side MD→HTML conversion. Existing markdown artifacts in older feature folders are untouched (forward-only migration).
- **`output_format` resolution gate.** Settings `output_format ∈ {html, md, both}` (default `html`); the literal token `markdown` and any out-of-set value exit 64. Resolution precedence is per-skill `--format` flag → `.pmos/settings.yaml :: output_format` → built-in default. Inlined as a non-interactive-block-style gate in all 10 affected skills.
- **Format-aware input resolver (`_shared/resolve-input.md`).** Picks `<artifact>.html` then `<artifact>.md` then errors with a clear message; consumers (reviewer subagents, downstream stages) traverse the canonical resolution order without per-skill duplication.
- **Reviewer subagent input contract.** Five reviewer-dispatching skills (`/grill`, `/verify`, `/msf-req`, `/msf-wf`, `/simulate-spec`) carry a Phase-1 "Input Contract (when invoked as reviewer subagent)" subsection — each consumes chrome-stripped HTML and validates `sections_found` against the ground-truth `<artifact>.sections.json` (FR-50/50.1/52). Chrome-strip is the **parent's** responsibility: `_shared/html-authoring/chrome-strip.md` documents the algorithm; `_shared/html-authoring/assets/chrome-strip.js` (≤80 LOC ref impl) is the canonical implementation; `tests/scripts/assert_chrome_strip.sh` exercises a 5-fixture self-test. `/verify` Phase 3 Multi-Agent Code Quality Review block is carved out (FR-50.1) since those reviewers consume git diffs, not artifact HTML.
- **`/diagram` blocking subagent pattern.** `/spec` Phase 5 dispatches `/diagram` as a blocking Task subagent (300s timeout × 3 attempts → inline-SVG fallback after 3 failures; 30 min wall-clock cap per `/spec` run via `diagram_subagent_state` accumulator). `/plan` Execution-order section cross-references the pattern. Three figcaption provenance variants (subagent / fallback / inline). Selftest at `plugins/pmos-toolkit/skills/diagram/tests/run.py` exit 0.
- **Cross-doc anchor scan in `/verify` smoke (FR-92).** Broken cross-document anchors (e.g., `02_spec.html#nonexistent-section`) are hard-failed during `/verify` smoke runs.
- **Heading-id rule (FR-03.1).** Every `<h2>`/`<h3>` carries a kebab-case `id` derived from the visible heading text; `tests/scripts/assert_heading_ids.sh` enforces the contract across feature-folder fixtures.
- **viewer.js classic-script (FR-05.1).** Single-script viewer (≤30 KB budget; 12984 bytes actual) with no ES module patterns; lint enforced by `plugins/pmos-toolkit/tools/lint-no-modules-in-viewer.sh` + `tests/scripts/assert_no_es_modules_in_viewer.sh`. Eleven UI surfaces: chrome + iframe routing + per-section Copy MD + full-doc Copy MD + sessionStorage state restore (with try/catch fallback) + clipboard execCommand fallback + file:// fallback banner + legacy-md `<pre class="pmos-legacy-md">` shim + four others.
- **Eight new assert scripts in `tests/scripts/`** — `assert_resolve_input.sh` + `_resolve_input_harness.sh` (4 sub-fixtures), `assert_sections_contract.sh`, `assert_format_flag.sh` (10 skills), `assert_unsupported_format.sh` (10 skills), `assert_no_md_to_html.sh` (G2 enforcement), `assert_no_es_modules_in_viewer.sh`, `assert_heading_ids.sh`, `assert_cross_doc_anchors.sh` — plus `assert_chrome_strip.sh` and `assert_serve_js_unit.sh` from earlier phases.
- **Canonical fixture** at `tests/fixtures/repos/node/docs/pmos/features/2026-05-09_html-artifacts-fixture/` (5 HTML artifacts + sibling sections.json + 4 cross-doc anchors + index.html + 6 byte-identical assets) drives the assert suite end-to-end.

### Known limitations / open questions

- **OQ-1 (deferred to pre-2.34.0)** — When `/complete-dev` is updated to handle the bootstrap markdown still present in this feature's own artifacts (`01_requirements.md`, `02_spec.md`, `03_plan.md`), the choice between auto-regenerate-as-HTML, hand-convert via turndown reverse, or leave-as-historical-MD is unresolved.
- **OQ-2 (deferred to pre-2.34.0)** — When `output_format` flips from `both` back to `html`, behaviour for existing `.md` sidecars from prior runs is undefined.
- **ADV-T19** — `msf-req/SKILL.md` lacks the canonical `<!-- non-interactive-block:start -->` contract carried by the other 9 affected skills (pre-existing rollout gap; not introduced by this feature).
- **ADV-T21** — `lint-no-modules-in-viewer.sh` is not yet wired into a multi-lint runner (none currently exists; tool + assert wrapper callable independently).
- **ADV-T24** — `audit-recommended.sh` fails on 13 unmarked `AskUserQuestion` call sites across `changelog`, `create-skill`, `execute`, `feature-sdlc` SKILL.md files (pre-existing on `main`; not introduced by this feature).

Single release; rollback = revert merge.

## 2026-05-09 — pmos-toolkit 2.32.0: `/create-skill` and `/update-skills` wired into `/complete-dev`

Closes the loop on the `requirements → spec → plan → execute → verify → complete-dev` pipeline by making the terminal `/complete-dev` edge real (not aspirational) at both batch entry points.

### What's new

- **`/create-skill` Phase 7 canonical-path precondition** — at write-time, refuses to write a skill outside `plugins/pmos-toolkit/skills/<skill-name>/`. Three options (Use canonical / Override-as-risk / Abort); default Recommended. Prevents the silent failure where a new skill is invisible to the plugin manifest.
- **`/create-skill` Phase 9 — Release via `/complete-dev`** — after `/verify` passes, prompts whether to invoke `/complete-dev` now / batch / skip. New row in the Phase 8 pipeline-status table for `complete-dev`. Old learnings phase renumbered to Phase 10.
- **`/update-skills` batch-level `/complete-dev` invocation** — Phase 8 dispatch now ends with one `/complete-dev` call per batch (after every approved skill passes `/verify`), not per-skill. Avoids N redundant version bumps / deploys / pushes when shipping multiple skill updates.
- **Pipeline-position diagrams updated** in both skills' bodies and frontmatter descriptions to terminate at `/complete-dev` instead of `/verify`. Convention 3 description guidance extended.
- **Repo `CLAUDE.md` added at root** — captures three project-level invariants that aren't obvious from directory structure: canonical pmos-toolkit skill path, paired-manifest version sync, `/complete-dev` as canonical release entry point. Loaded into every Claude Code session so manual skill moves/copies/renames are caught by the rule, not by coupling generic skills to repo-specific layouts.
- **Legacy `/push` references removed** in `/create-skill` Convention 1 and `/update-skills` Release-prereqs section; both now point at `/complete-dev`.

### Why

`/complete-dev` superseded the legacy `/push` in 2.30.0 but the two batch-style entry points (`/create-skill`, `/update-skills`) still terminated at `/verify`, leaving the user to remember the manual release step. The pipeline diagrams claimed an edge that the skills didn't actually walk. This release makes the diagrams honest. The accompanying repo `CLAUDE.md` keeps the misplaced-skill guard out of `/complete-dev` itself — a generic release skill should not couple to one repo's directory layout.

## 2026-05-09 — pmos-toolkit 2.31.0: `/feature-sdlc` end-to-end SDLC orchestrator

New top-level orchestrator that turns an idea into a shipped feature by driving the full pipeline sequentially — with auto-tiering, resumable state inside a git worktree, pre-heavy-phase compact checkpoints, and `--non-interactive` plumbing through every child skill.

### `/feature-sdlc` (new)

- Drives `requirements → grill → [msf-req | creativity | wireframes → prototype] → spec → [simulate-spec] → plan → execute → verify → complete-dev` sequentially. Auto-tiers each gate from the requirements doc; honours an explicit `--tier 1|2|3` override that drives both child passthrough (where children accept it) and orchestrator gate logic.
- Creates a git worktree + `feat/<slug>` branch on entry; refuses fast on the four edge cases (not-a-repo / detached HEAD / dirty tree / branch already exists), with the existing-branch case offering Use / Pick-new-slug / Abort.
- Persists resumable state at `<worktree>/.pmos/feature-sdlc/state.yaml` (schema_version: 1, refuse-newer / auto-migrate-older). On no-arg invocation inside a worktree with state.yaml, auto-detects resume; jumps to the first non-completed phase after showing the status table.
- Surfaces a compact checkpoint before each context-heavy phase (wireframes, prototype, simulate-spec, execute, verify) with a precise three-part Pause-resumable exit contract: state.yaml records `paused_reason`, chat prints exact resume command including `cd <worktree>`, clean exit. Skills can't trigger `/compact` directly — this is the contract that makes pause work.
- Failure dialog is constructed from per-phase hard/soft tags in `state-schema.md` (single source of truth). Skip is hidden for the six hard phases (`requirements`, `spec`, `plan`, `execute`, `verify`, `complete-dev`); shown for the six soft phases. Missing-skill detection presents a Pause-to-install option instead of silent skip.
- `--non-interactive` plumbs through child skills and aggregates their deferred-question artifacts into a single `00_open_questions_index.md` written at end-of-run or end-of-pause. `/grill` is auto-skipped in non-interactive mode with an explicit chat log line (never silent).
- `/wireframes` gate is always presented per FR-FRONTEND-GATE; the keyword heuristic only biases which option is `(Recommended)`. Tier-1 always recommends Skip regardless of heuristic.

### README

- New "Pipeline orchestrators" subsection groups `/feature-sdlc` alongside `/update-skills` (moved from "Pipeline enhancers"). Standalone-line updated to include `/feature-sdlc`.

### References

- `docs/pmos/features/2026-05-09_feature-sdlc-skill/02_spec.md` — full Tier-3 spec (status: verified) including the 11 post-grill dispositions in §15.
- `docs/pmos/features/2026-05-09_feature-sdlc-skill/03_plan.md` — implementation plan (16 tasks + TN, 2 phases).
- `docs/pmos/features/2026-05-09_feature-sdlc-skill/verify/2026-05-09-review.md` — /verify report (PASS, 0 critical).
- `plugins/pmos-toolkit/skills/feature-sdlc/` — SKILL.md + 6 reference files (state-schema, pipeline-status-template, slug-derivation, frontend-detection, compact-checkpoint, failure-dialog).

---

## 2026-05-08 — pmos-toolkit 2.30.0: `/update-skills` retro friction fixes across `/changelog`, `/complete-dev`, `/verify`, `/execute`

Driven by the 2026-05-08 retro of a 6-run `/execute` + 4-run `/verify` + 1-run `/complete-dev` + 1-run `/changelog` session. Seven approved findings shipped; three skipped with reasons recorded in the triage doc.

### `/changelog`

- When `.pmos/settings.yaml :: docs_path` points somewhere other than `docs/` but a sibling `docs/changelog.md` already exists, `/changelog` now writes to the sibling and emits a one-line non-blocking advisory to reconcile `settings.yaml`. Previously you had to manually redirect at every run.

### `/complete-dev`

- Phase 5 deploy-norm detection now recognizes Python projects: any `./pyproject.toml` or `./backend/pyproject.toml` with `[project]` metadata surfaces as a deploy signal, and "Build + publish to PyPI via `uv publish`" appears as a deploy menu option (recommended when no other signals are present; defers to CI when CI auto-deploys).

### `/verify`

- Phase-scoped `--scope phase --feature <slug> --phase <N>` runs no longer require a duplicate `TodoWrite` task per FR-ID. The markdown table inside `review.md` is the structural enforcement when the per-task logs already carry evidence-typed FR coverage. `TodoWrite`-as-gate stays mandatory for standalone feature-scope runs.
- Phase 4 sub-step 3d evidence guidance now explicitly warns: synthesized `KeyboardEvent`s must use `bubbles: true` to reach document-level listeners, otherwise the listener won't fire and you'll log a false negative. (One retro session almost shipped a false-pass for FR-E09 because of this.)
- Phase 5 sub-section 4b now ships a copy-pasteable markdown table template with example rows for each of the three valid `Outcome` values (`Verified` / `NA — alt-evidence` / `Unverified — action required`). Bare `Pass` / `Fail` / `✓` are now explicitly listed as not valid.

### `/execute`

- New `--no-halt` flag suppresses the per-phase `HALT_FOR_COMPACT` handshake on green; phase verify still runs and `phase-N.md` is still written, but the skill rolls directly into the next phase without pausing for a manual `/compact`. Failure escalation is unaffected.
- Mid-run, the executing agent now honors a session-sticky continuation directive: typing `[continue_through_phases]`, "continue without compacting", "no halts", "skip compacts", or "don't halt at phase boundaries" sets the same opt-out for the rest of the conversation. Default behavior (HALT on every green) is unchanged when neither flag nor directive is set.
- Phase 0.5 Resume Reports now append a "Last 5 lines from in-flight task body" bullet list under the resume table whenever a task is `in-flight` or `in-flight-with-commits`. The resuming agent sees the recent thinking trace (last test written, current deviation, etc.) without re-deriving from `git log`. Omitted entirely when no task is in-flight.

### Skipped findings (recorded in retro triage)

Three retro findings were dropped after triage: a `task_goal_hash` helper script (maintenance overhead not worth it), a "first-tag-on-mature-project" version-bump heuristic (edge case, manual override is fine), and a Recommended-marker flip on `/complete-dev` Phase 6 learnings scan (current dedup nudge is more valuable than the capture default).

### References

- `docs/pmos/features/2026-05-08_update-skills-retro-pipeline-friction/00_triage.md` — full triage with disposition log, per-skill tier, and pipeline-status.
- Per-skill requirements + verify reviews under `docs/pmos/features/2026-05-08_update-skills-retro-pipeline-friction/{changelog,complete-dev,verify,execute}/`.

## 2026-05-08 — pmos-toolkit 2.29.0: `/diagram --on-failure` flag for deterministic non-interactive terminal failures

- `/diagram` now accepts `--on-failure {drop|ship-with-warning|exit-nonzero}` to make Phase 6.5 (terminal-failure handler) disposition deterministic when running in non-interactive mode. The flag bypasses the existing `AskUserQuestion` and dispatches on three values:
  - `drop` — write nothing, exit 3, print one-line reason; caller (e.g., `/rewrite`) drops the diagram slot.
  - `ship-with-warning` — write the SVG with a leading `<!-- WARNING: <fails> -->` comment, exit 0.
  - `exit-nonzero` (default when `--non-interactive` is set) — write nothing, exit 4, print one-line reason; caller decides.
- New **Exit-Code contract table** documented in `/diagram` SKILL.md Phase 6.5 (codes: 0 success, 2 environmental, 3 drop, 4 exit-nonzero, 64 argument error). External callers can now rely on the contract without reading source.
- Interactive `/diagram` runs are unaffected — the existing `Ship-with-warning / Try-alt / Abandon` prompt remains the source of truth.
- New regression test `plugins/pmos-toolkit/tests/non-interactive/diagram-on-failure.bats` (7 assertions) locks in the SKILL.md contract.
- Per-skill addendum added to `plugins/pmos-toolkit/tests/non-interactive/per-skill-rollout-runbook.md` documenting the flag, the exit-code contract, and the awk-extractor false-positive gotcha (prose mentions of `AskUserQuestion` in tagged sections must be reworded to "interactive prompt" / "AUQ" to keep `audit-recommended.sh` green).
- Unblocks `/rewrite` v0.14.0's spec-only handoff swap, which depends on this contract for autonomous-default diagram generation.

### References
- [features/2026-05-08_update-skills-diagram-on-failure/01_requirements.md](features/2026-05-08_update-skills-diagram-on-failure/01_requirements.md)
- [features/2026-05-08_update-skills-diagram-on-failure/03_plan.md](features/2026-05-08_update-skills-diagram-on-failure/03_plan.md)
- [features/2026-05-08_update-skills-diagram-on-failure/verify/2026-05-08-review.md](features/2026-05-08_update-skills-diagram-on-failure/verify/2026-05-08-review.md)
- [../../plugins/pmos-toolkit/tests/non-interactive/diagram-on-failure.bats](../../plugins/pmos-toolkit/tests/non-interactive/diagram-on-failure.bats)

## 2026-05-08 — pmos-toolkit 2.28.1: /complete-dev rebase-default + parallel-worktree version-bump pre-flight

- `/complete-dev` Phase 3 now defaults to **rebase-onto-main + fast-forward** when a shared-branch guard passes (no upstream OR local SHA == remote SHA). Branches that have been pushed and diverged from local fall back to `--no-ff` merge with a one-line reason in the prompt. Rebase command sequence is now spelled out explicitly.
- `/complete-dev` Phase 9 now fetches `origin/main` and runs a 3-way (local / main / branch-point) version pre-flight that detects parallel-worktree bump collisions before commit. Five verdict states: Clean, Clean-after-rebase, Fresh local bump, Stale-bump (triggers recovery), and Anomaly.
- New `reference/version-bump-recovery.md` documents the stale-bump recovery recipe (restore both paired manifests from origin/main, re-bump from main's baseline) plus failure modes and manual fallback.
- Added anti-pattern entry: the shared-branch guard's `local==remote SHA` test is necessary-but-not-sufficient — documented as a runtime caveat to prefer the merge fallback for any branch shared for review.
- Pre-push hook unchanged — it remains the authoritative last line of defence; the new pre-flight catches collisions earlier and friendlier.

### References
- `docs/pmos/features/2026-05-08_update-skills-complete-dev-merge/01_requirements.md`
- `docs/pmos/features/2026-05-08_update-skills-complete-dev-merge/02_spec.md`
- `docs/pmos/features/2026-05-08_update-skills-complete-dev-merge/03_plan.md`
- `docs/pmos/features/2026-05-08_update-skills-complete-dev-merge/verify/2026-05-08-review.md`
- `plugins/pmos-toolkit/skills/complete-dev/SKILL.md`
- `plugins/pmos-toolkit/skills/complete-dev/reference/version-bump-recovery.md`

## 2026-05-08 — pmos-toolkit 2.28.0: cross-cutting `--non-interactive` mode

- All 26 user-invokable skills now accept a `--non-interactive` (and symmetric `--interactive`) flag. In non-interactive mode, every `AskUserQuestion` checkpoint is classified at runtime: calls with a `(Recommended)` option AUTO-PICK; calls without one (or with an adjacent `<!-- defer-only: <reason> -->` tag) DEFER to a structured `## Open Questions (Non-Interactive Run)` block in the produced artifact.
- Repo-level default via `.pmos/settings.yaml :: default_mode` (`interactive` | `non-interactive`); precedence: `cli_flag > parent_marker > settings.default_mode > builtin-default`.
- Three-state exit contract: `0` clean / `2` deferred / `1` runtime error / `64` usage-or-refusal.
- Subagent propagation: parent skill prepends `[mode: <current>]` as the literal first line of any child's prompt; child resolver detects + reports `mode: <m> (source: parent-skill-prompt)` on stderr.
- Per-checkpoint classifier with three defer-only reasons: `destructive` (overwrite/delete/reset/force), `free-form` (paste/file/dictate/free-text), `ambiguous` (confirm/picker without defensible auto-pick). Destructive tag wins over `(Recommended)` (FR-04.1).
- `/msf-req` declares itself refused (`<!-- non-interactive: refused; reason: recommendations-only with free-form persona inference -->`); `--non-interactive` against a refused skill exits 64 with a stderr-only diagnostic.
- Backward compatibility: a `--non-interactive` arg against a skill that has not yet been rolled out emits `WARNING: --non-interactive not yet supported by /<skill>; falling back to interactive.` and continues in interactive mode (FR-08).
- `tools/audit-recommended.sh` enforces that every `AskUserQuestion` in supported `SKILL.md` has either a `(Recommended)` option or a `<!-- defer-only: ... -->` adjacent tag (`destructive` | `free-form` | `ambiguous`); supports `--strict-keywords` to warn on un-tagged destructive vocabulary (`overwrite|restart|discard|drift|delete|force|reset|wipe`).
- `tools/lint-non-interactive-inline.sh` enforces drift-detection on the canonical `_shared/non-interactive.md` block across all supported skills.
- New CI: `.github/workflows/audit-recommended.yml` runs both scripts on every PR touching `plugins/pmos-toolkit/skills/**/SKILL.md` or the canonical `_shared/non-interactive.md`.
- 13 unit-bats files under `plugins/pmos-toolkit/tests/non-interactive/` (51 cases / 1 documented skip) cover resolver precedence, classifier decision tree, buffer-and-flush dispatch (single-MD / sidecar / chat-only / multi-artifact), destructive auto-pick override, refusal regex, parser, parent-marker propagation, child-OQ-id namespacing, and resolver/extractor perf budgets.
- 26 integration smoke tests under `plugins/pmos-toolkit/tests/integration/non-interactive/` (opt-in via `PMOS_INTEGRATION=1`; each takes 30–120s of LLM time) — invoke `claude -p '/<skill> --non-interactive ...'` and assert zero `AskUserQuestion` events.
- 2 manual E2E runbooks (`MANUAL-subagent.md` for FR-06 propagation, `MANUAL-bc-fallback.md` for FR-08).

### Notable plan deviations during execution

- The canonical awk extractor's marker regexes (`/<!-- non-interactive-block:start -->/`) originally matched their OWN literal substrings inside the inlined block (the awk script self-references the markers in its rule lines). This flipped `in_inlined` mid-block and let the awk's `/AskUserQuestion/` rule line itself escape the skip region. Fixed by anchoring marker regexes to whole-line (`/^...$/`).
- Plan estimate "≤4 defer-only tags per skill after manual review" assumed prose enumerates options inline with `(Recommended)`; in practice prose-style SKILL.md (the majority) describes calls semantically, so most skills got 5–18 tags.
- 17 of 26 skills lack an inlined `pipeline-setup-block` (Anchor B in the runbook); only 9 use Anchor A. Runbook documents both.
- 4 false-positive `AskUserQuestion` mentions per skill on average (Platform Adaptation notes, anti-pattern bullets, parenthetical asides, section headings) needed prose rephrasing rather than tagging — tagging would pollute the runtime OQ buffer with phantom DEFERs.

### References

- [`docs/pmos/features/2026-05-08_non-interactive-mode/02_spec.md`](features/2026-05-08_non-interactive-mode/02_spec.md) — non-interactive mode spec (FR-01..FR-09, NFR-01..NFR-07, E1..E14)
- [`docs/pmos/features/2026-05-08_non-interactive-mode/03_plan.md`](features/2026-05-08_non-interactive-mode/03_plan.md) — 45-task implementation plan (Phase 1 Foundation → Phase 4 Ship)
- [`plugins/pmos-toolkit/skills/_shared/non-interactive.md`](../../plugins/pmos-toolkit/skills/_shared/non-interactive.md) — canonical contract (Section 0 inline block, Section A refusal, Section B parser, Section C subagent propagation)
- [`plugins/pmos-toolkit/tests/non-interactive/per-skill-rollout-runbook.md`](../../plugins/pmos-toolkit/tests/non-interactive/per-skill-rollout-runbook.md) — 10-step procedure for adding the contract to a skill
- [`plugins/pmos-toolkit/tools/audit-recommended.sh`](../../plugins/pmos-toolkit/tools/audit-recommended.sh) and [`plugins/pmos-toolkit/tools/lint-non-interactive-inline.sh`](../../plugins/pmos-toolkit/tools/lint-non-interactive-inline.sh) — CI-enforced drift checks

---

## 2026-05-08 — pmos-toolkit 2.27.0: /create-skill plan+verify + /plan v2 cross-stack support + first changelog

> Note: v2.26.0 was tagged and shipped without a `docs/pmos/changelog.md` entry. This 2.27.0 release adds the first entry retroactively, covering the 2.24.0 → 2.27.0 span (everything between the previous tagged release and now).

- `/pmos-toolkit:create-skill` now runs the full pipeline. Tier 2+ runs `/plan` after spec/grill; all tiers run `/verify` after implement. The inline pre-save checklist is gone — `/verify` is the single source of truth for skill verification.
- Spec status lifecycle on skill creation extends to `draft → grilled → planned → approved → implemented → verified` so each phase boundary is auditable.
- `/spec` now emits a frontmatter contract (FR-01..FR-18 stable IDs, anchors per FR) so downstream `/plan` and `/verify` can reference requirements by anchor instead of line number.
- `/plan` v2: Phase 0 lockfile + backup, Phase 2 simulate-spec hook, Phase 4 hard task cap, blind-subagent review, skip-list and branch-strategy fields, "Done when" frontmatter contract, tier-aware templates.
- `/execute` v2: per-task `commit_cadence` (per-step / per-task / phase-end), new task frontmatter fields, back-compat with v1 plans.
- Cross-stack support added across `/plan`, `/execute`, `/spec`: shared stack preambles for Python (pytest/poetry/uv), Rails (rspec/minitest), Go, static-site, and Node variants. Skills now detect host stack and inline the right test/lint/build phrasing.
- CI lint scripts: `lint-stack-libraries.sh`, `lint-platform-strings.sh`, `lint-js-stack-preambles.sh` enforce cross-platform phrasing and prevent stack-specific drift in skill bodies.
- `/backlog` type enum extended with `enhancement`, `chore`, `docs`, `spike`; new heuristics auto-classify items at capture.
- Legacy commands pruned from the `/plan` body — fewer footguns, sharper guidance.
- Integration test fixtures and assert scripts shipped under `tests/fixtures/` so contributors can dry-run pipeline changes locally.

### References

- [`docs/pmos/features/2026-05-08_update-skills-add-plan-verify/02_spec.md`](features/2026-05-08_update-skills-add-plan-verify/02_spec.md) — /create-skill plan+verify spec
- [`docs/pmos/features/2026-05-08_update-skills-add-plan-verify/03_plan.md`](features/2026-05-08_update-skills-add-plan-verify/03_plan.md) — implementation plan
- [`plugins/pmos-toolkit/skills/create-skill/SKILL.md`](../../plugins/pmos-toolkit/skills/create-skill/SKILL.md) — updated /create-skill body
- [`plugins/pmos-toolkit/skills/plan/SKILL.md`](../../plugins/pmos-toolkit/skills/plan/SKILL.md) — /plan v2
- [`plugins/pmos-toolkit/skills/execute/SKILL.md`](../../plugins/pmos-toolkit/skills/execute/SKILL.md) — /execute v2
- [`plugins/pmos-toolkit/skills/_shared/stacks/`](../../plugins/pmos-toolkit/skills/_shared/stacks/) — cross-stack preambles
