---
tier: 3
type: feature
feature: feature-sdlc-skill
spec_ref: 02_spec.md
date: 2026-05-09
status: Planned
commit_cadence: per-task
contract_version: 1
---

# /feature-sdlc — Implementation Plan

## Overview

Build a new top-level pmos-toolkit orchestrator skill (`/feature-sdlc`) that drives the full requirements→complete-dev pipeline sequentially with auto-tiering, resumable state inside a git worktree, and pre-heavy-phase compact checkpoints. Implementation is markdown authoring only — SKILL.md plus six reference files; no `assets/`, no executable code. The closest sibling (`update-skills`) provides the dispatch + status-table pattern.

**Done when:** `plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md` exists with all 12 phases + 6 reference files; `/feature-sdlc` appears in the skill catalog after plugin reload; both `plugin.json` files have byte-identical descriptions; README updated; `/verify` Phase 5 grades all 11 FR-IDs from spec §15 as PASS.

**Done-when walkthrough:** (1) Run `ls plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md plugins/pmos-toolkit/skills/feature-sdlc/reference/{state-schema,pipeline-status-template,slug-derivation,frontend-detection,compact-checkpoint,failure-dialog}.md` — all 7 files exist. (2) Reload plugins; `/feature-sdlc` appears in available-skills list with the description. (3) `diff <(jq -r .description plugins/pmos-toolkit/.claude-plugin/plugin.json) <(jq -r .description plugins/pmos-toolkit/.codex-plugin/plugin.json)` exits 0. (4) Grep README for `/feature-sdlc` row under Pipeline / Orchestrators. (5) `/verify 02_spec.md` on this feature folder reports 0 critical findings against FR-PAUSE, FR-CHILD-RESUME, FR-SCHEMA, FR-OQ-INDEX, FR-PHASE-TAGS, FR-FRONTEND-GATE, FR-WORKTREE, FR-TIER-SCOPE, FR-FINDINGS-N-A, FR-MISSING-SKILL, FR-RELEASE.

**Execution order:**

```
Phase 1: Reference files (T1 → T2 → T3 → T4 → T5 → T6 → T7)   [7 tasks]
                                ↓
Phase 2: SKILL.md body + release (T8 → T9 → T10 → T11 → T12 → T13 → T14 → T15 → T16)   [9 tasks]
                                ↓
                              TN: Final verification
```

Tasks within Phase 1 are independent reference docs — could be parallelized but kept linear to allow each to cite earlier ones cleanly. Phase 2 builds SKILL.md top-down, then handles release prereqs.

---

## Decision Log

| # | Decision | Options Considered | Rationale |
|---|----------|-------------------|-----------|
| D1 | Markdown-only skill — TDD per task is `no — markdown skill, no executable code paths (FR-105 config/IaC analog)`. Verification is structural: spec-FR coverage check + skill-catalog load + plugin.json sync diff. | (a) Force TDD framing with synthetic "test the YAML schema" steps; (b) declare TDD inapplicable per FR-105 and verify structurally; (c) write a dedicated bats test suite under `tests/` | (b). Option (a) is ceremony — there is no behavior to red/green; the skill's "behavior" is the markdown content read by the agent at invocation time, which has no automated test harness. Option (c) is overkill for a 1-skill change; no other recently-added skill (`/polish`, `/complete-dev`) added bats tests. Verification quality comes from `/verify`'s spec-FR grading + multi-agent review (Phase 3) + interactive QA (Phase 4) — proven on the 12 prior pmos-toolkit skill releases. |
| D2 | Reuse `_shared/non-interactive.md`, `_shared/platform-strings.md`, `_shared/pipeline-setup.md`, `_shared/interactive-prompts.md`, `_shared/structured-ask-edge-cases.md` rather than inlining their contents in SKILL.md. The `<!-- non-interactive-block -->` boilerplate IS inlined verbatim per the cross-cutting contract that all user-invokable skills carry the canonical block. | (a) Inline everything for self-containment; (b) reuse via `_shared/` and inline only the canonical non-interactive block; (c) reuse via `_shared/` and use `Read`-time inclusion for the non-interactive block too | (b). The non-interactive block is mandated to be inlined byte-for-byte across every user-invokable skill (audit-recommended.sh greps for it). The other shared files are imported by `Read` at runtime per pmos-toolkit convention; that's how every other orchestrator (`/update-skills`, `/complete-dev`) does it. |
| D3 | `reference/state-schema.md` is the single source of truth for: schema_version, phase identifiers, hard/soft tags, status enum, paused_reason enum, missing_skill enum, open_questions_log entry shape. SKILL.md prose cites the schema doc rather than redeclaring fields. | (a) Inline schema in SKILL.md; (b) externalize fully into reference/state-schema.md; (c) duplicate across both | (b). Single source of truth prevents drift; SKILL.md stays focused on flow control. Mirrors `/spec` → `reference/spec-template.md` pattern. /verify Phase 5's spec-FR grading reads the schema doc directly. |
| D4 | Use `update-skills/SKILL.md` as the structural template (Phase numbering, release-prereqs section placement, anti-patterns block, learnings-capture phase number). Do NOT copy text; copy structure only. The non-interactive block is copied verbatim. | (a) Greenfield skill structure; (b) clone update-skills structure; (c) clone update-skills text and edit | (b). update-skills already passed `/verify` Phase 5 grading and is the closest analog (sequential pipeline dispatch + per-skill status table + resume marker). Cloning structure inherits the audit trail without inheriting orchestration that doesn't apply (Phase 6 triage approval has no analog here). |

---

## Code Study Notes

> Glossary inherited from spec — see `02_spec.md` §1–§5 for the orchestrator vocabulary. Plan introduces no new domain terms.

### Patterns to follow

- `plugins/pmos-toolkit/skills/update-skills/SKILL.md:36–46` — Phase 0 pipeline-setup inline pattern (Read settings → docs_path → feature folder → learnings).
- `plugins/pmos-toolkit/skills/update-skills/SKILL.md:49–132` — `<!-- non-interactive-block:start -->` canonical block (must be byte-identical across all user-invokable skills).
- `plugins/pmos-toolkit/skills/update-skills/SKILL.md:220–239` — Phase 8 sequential pipeline-dispatch pattern with per-phase status-table updates after each child completes; failure dialog with Continue / Retry / Abort + resume mode via existing-doc detection. Direct template for our Phase 3–10 dispatch.
- `plugins/pmos-toolkit/skills/update-skills/SKILL.md:253–256` — `## Phase N: Capture Learnings` numbered (not unnumbered trailing) per Convention 6.
- `plugins/pmos-toolkit/skills/update-skills/SKILL.md:258–263` — Release prereqs section format.
- `plugins/pmos-toolkit/skills/create-skill/reference/spec-template.md` — convention 5 frontmatter + convention 7 progress-tracking pattern.

### Existing code to reuse

- `plugins/pmos-toolkit/skills/_shared/pipeline-setup.md` — Section A (first-run setup), Section B (folder edge cases), Section C (workstream enrichment). Cited by Phase 0 in SKILL.md.
- `plugins/pmos-toolkit/skills/_shared/non-interactive.md` — referenced from inlined block.
- `plugins/pmos-toolkit/skills/_shared/platform-strings.md` — for cross-platform `execute_invocation`-style strings (used in compact-checkpoint resume command and missing-skill dialog).
- `plugins/pmos-toolkit/skills/_shared/interactive-prompts.md` — fallback for environments without `AskUserQuestion`.
- `plugins/pmos-toolkit/skills/_shared/structured-ask-edge-cases.md` — for failure-dialog / compact-checkpoint edge handling.
- `plugins/pmos-toolkit/skills/_shared/phase-boundary-handler.md` — analogous per-phase handshake pattern; cite as "see _shared/phase-boundary-handler.md for related per-phase boundary handshakes" rather than reusing directly (it's `/execute`-specific).

### Constraints discovered

- Skills are auto-discovered from `plugins/pmos-toolkit/skills/<name>/SKILL.md` — no `plugin.json` `skills` array to update (the manifest sets `"skills": "./skills/"` which means directory-glob).
- Both `plugins/pmos-toolkit/.claude-plugin/plugin.json` AND `plugins/pmos-toolkit/.codex-plugin/plugin.json` exist and must stay in sync (FR-RELEASE.iii). The pre-push hook enforces version equality but **does not** currently enforce description equality — must add this manually before push.
- The user's earlier instruction set says: don't add documentation files unless explicitly requested. The reference/ files ARE explicitly requested (per spec §8) so this is fine; no extra README inside the skill folder.
- `/grill` Phase 5 in `/create-skill` was already run on the spec; pre-grill copy is `02_spec_pre-grill.md` per convention.
- The user's project has worktree-related anti-pattern guidance: investigate before deleting/overwriting (re G7 (d) "branch already exists" → ask, don't auto-delete).

### Stack signals

- **Stack:** Markdown + plain text. No package manifests in scope for this skill folder. No build, no test runner. The host repo's `package.json` exists at root for plugin tooling but is not in this skill's scope.
- **Reference systems:** `update-skills` and `complete-dev` skills (most recent comparable orchestrator additions — both Tier 3, both passed `/verify`).
- Per FR-91, structural choices (file layout, frontmatter conventions, section ordering) are justified against `update-skills` and `complete-dev` as reference systems. Not greenfield.

---

## Prerequisites

- `git status` clean on `main` of `/Users/maneeshdhabria/Desktop/Projects/agent-skills` (or willing to create a worktree first).
- Editor / `Edit` / `Write` access to `plugins/pmos-toolkit/skills/`.
- `/verify` skill installed (mandatory Phase 8 of `/create-skill`).
- No collision: `plugins/pmos-toolkit/skills/feature-sdlc/` does not currently exist (verified Phase 2).

---

## File Map

| Action | File | Responsibility | Task |
|--------|------|---------------|------|
| Create | `plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md` | Top-level orchestrator skill body — 12 phases + frontmatter + non-interactive block + anti-patterns + release prereqs. | T1, T8–T14 |
| Create | `plugins/pmos-toolkit/skills/feature-sdlc/reference/state-schema.md` | Canonical YAML schema for `state.yaml` + `00_pipeline.md`: schema_version, phase enum + hard/soft tags, status enum, paused_reason enum, open_questions_log entry shape. | T2 |
| Create | `plugins/pmos-toolkit/skills/feature-sdlc/reference/pipeline-status-template.md` | Markdown skeleton for `00_pipeline.md` and the in-chat status table; one row per phase with status / artifact path / timestamp. | T3 |
| Create | `plugins/pmos-toolkit/skills/feature-sdlc/reference/slug-derivation.md` | Rules for LLM slug derivation: kebab-case, length 3–40 chars, ASCII only, branch-name validation, collision check against `git branch --list`. | T4 |
| Create | `plugins/pmos-toolkit/skills/feature-sdlc/reference/frontend-detection.md` | Heuristics for detecting frontend feature from requirements doc: keywords (UI/UX/screen/page/component/wireframe/CSS/HTML/visual/click/form/button), explicit "frontend"/"backend" tag, presence of /wireframes mention. Heuristic only biases the (Recommended) option per FR-FRONTEND-GATE. | T5 |
| Create | `plugins/pmos-toolkit/skills/feature-sdlc/reference/compact-checkpoint.md` | Exact AskUserQuestion structure for the pre-heavy-phase compact prompt + the Pause-resumable exit sequence per FR-PAUSE. Includes the chat output line template `Paused at phase <X>. To resume: cd <worktree-abs> && /pmos-toolkit:feature-sdlc --resume`. | T6 |
| Create | `plugins/pmos-toolkit/skills/feature-sdlc/reference/failure-dialog.md` | Failure-handling AskUserQuestion structure per FR-PHASE-TAGS (Skip hidden for hard phases) + missing-skill dialog per FR-MISSING-SKILL (Pause-to-install option). Cites state-schema.md for the hardness tag lookup. | T7 |
| Modify | `plugins/pmos-toolkit/.claude-plugin/plugin.json` | Bump version to next minor (per FR-RELEASE). Skills auto-discovered, no array edit needed. Description unchanged at plugin level (skill-level descriptions live in SKILL.md frontmatter). | T15 |
| Modify | `plugins/pmos-toolkit/.codex-plugin/plugin.json` | Mirror version bump byte-identically. | T15 |
| Modify | `README.md` (repo root) — under Pipeline / Orchestrators (or create subsection if absent) | Add `/feature-sdlc` row with one-line description; update standalone-skills line to include `/feature-sdlc`. | T15 |
| Modify | `~/.pmos/learnings.md` | Append `## /feature-sdlc` section header (idempotent — only if missing). | T16 |

No Move/Rename/Delete actions.

---

## Risks

| # | Risk | Likelihood | Impact | Severity | Mitigation | Mitigation in: |
|---|------|-----------|--------|----------|------------|----------------|
| R1 | Non-interactive block drift — copy/paste introduces a typo that breaks the cross-skill audit-recommended.sh classifier. | Medium | High | High | Copy block byte-for-byte from `update-skills/SKILL.md:49–132`; verify with `diff` against the source after writing. | T8 |
| R2 | Plugin.json description sync — manual sync drifts on next edit; pre-push hook only enforces version. | Medium | Medium | Medium | Document the byte-identity requirement in spec §15 G11.iii AND add a sync check to TN. Do NOT add a hook in this PR (out of scope); track as backlog idea instead. | T15, TN |
| R3 | Worktree creation guidance in SKILL.md Phase 0.a duplicates anti-pattern advice from elsewhere — drifts from system rules over time. | Low | Medium | Low | Cite the specific guidance briefly; do not redeclare safety rules — link to spec FR-WORKTREE and the user's CLAUDE.md guidance pattern. | T9 |
| R4 | Reference file sprawl — 6 reference files is high; future readers may not know which to load when. | Low | Low | Low | SKILL.md prose cites each reference file at the exact phase that loads it (per Phase 7 spec §8 mapping). | T8–T13 |
| R5 | Schema versioning policy in state-schema.md doesn't actually get exercised until v2 ships — easy for v2 to forget. | Medium | Medium | Medium | Bake `schema_version: 1` literal into pipeline-status-template.md so every state.yaml carries it from day one; document migration rule explicitly in state-schema.md so v2 author finds it. | T2, T3 |

---

## Rollback

Not required. This change is additive: new skill folder + version bump + README row + learnings header. No DB migrations, no deployments, no data mutations. If the skill must be retracted, `git revert <commit>` removes it cleanly; users get the previous catalog after plugin reload.

---

## Tasks

## Phase 1: Reference Files

Foundation phase: write the 6 reference files first so SKILL.md can cite them by exact path with confidence the content exists. Each reference file is independently reviewable. Phase boundary: full `/verify` after T7.

### T1: Scaffold skill directory + SKILL.md frontmatter

**Goal:** Create the skill folder and an empty SKILL.md with valid frontmatter so subsequent tasks can write into a known target.

**Spec refs:** §1 (description), §2 (argument hint), §13 (release prereqs — frontmatter completeness), Convention 5.

**Depends on:** none
**Idempotent:** yes
**TDD:** no — markdown skill, no executable code (FR-105 config/IaC analog)
**Files:**
- Create: `plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md`
- Create: `plugins/pmos-toolkit/skills/feature-sdlc/reference/` (directory only)

**Steps:**

- [ ] Step 1: Verify path collision: `test ! -e plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md` exits 0.
- [ ] Step 2: `mkdir -p plugins/pmos-toolkit/skills/feature-sdlc/reference`.
- [ ] Step 3: Write `plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md` with ONLY the frontmatter block + the H1 heading (body filled by T8+):

  ```markdown
  ---
  name: feature-sdlc
  description: End-to-end SDLC orchestrator that turns an initial idea (text or doc) into a shipped feature by sequentially driving the full pmos-toolkit pipeline — worktree creation, requirements, grill, optional MSF/creativity/wireframes/prototype, spec, optional simulate-spec, plan, execute, verify, and complete-dev — auto-tiering each stage and persisting resumable state inside the worktree. Use when the user says "build this feature end-to-end", "run the full SDLC", "take this idea through to ship", "feature-sdlc this", "/feature-sdlc", or "drive the pipeline for me".
  user-invocable: true
  argument-hint: "<initial idea text | path to brief/doc> [--tier 1|2|3] [--resume] [--no-worktree] [--non-interactive | --interactive] [--backlog <id>]"
  ---

  # Feature SDLC

  Body filled in subsequent tasks.
  ```

**Inline verification:**
- `head -10 plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md` — frontmatter renders cleanly; `name:`, `description:`, `user-invocable:`, `argument-hint:` all present.
- Description contains all 6 trigger phrases from FR-RELEASE.ii (grep each verbatim).
- `argument-hint` enumerates all 6 flags from FR-RELEASE.i (`--tier`, `--resume`, `--no-worktree`, `--non-interactive`, `--interactive`, `--backlog`).

---

### T2: Write `reference/state-schema.md`

**Goal:** Canonical YAML schema for `state.yaml` and `00_pipeline.md` — single source of truth for fields, enums, and hard/soft tags.

**Spec refs:** §15 G1 (FR-PAUSE — paused_reason enum), §15 G3 (FR-SCHEMA — schema_version), §15 G4 (FR-OQ-INDEX — open_questions_log shape), §15 G5 (FR-PHASE-TAGS — hardness tag), §15 G10 (FR-MISSING-SKILL — missing_skill recording).

**Depends on:** T1
**Idempotent:** yes
**TDD:** no — markdown spec doc (FR-105)
**Files:**
- Create: `plugins/pmos-toolkit/skills/feature-sdlc/reference/state-schema.md`

**Steps:**

- [ ] Step 1: Write the schema with sections: `## schema_version` (always 1, version policy), `## top-level fields` (slug, tier, mode, started_at, last_updated, current_phase, worktree_path, branch, schema_version), `## phases[]` (table with id, hardness=hard|soft, mandatory phase identifier list per spec §5), `## phases[].status enum` (pending, in_progress, completed, paused, failed, skipped, skipped-on-failure, skipped-non-interactive, skipped-unavailable), `## paused_reason enum` (compact, failure, user, missing_skill), `## open_questions_log[] entry shape` (phase, child_skill, oq_artifact_path, deferred_count, ts), `## migration policy` (refuse-newer, auto-migrate-older, log-migration-to-chat).
- [ ] Step 2: Mark each phase id with hardness:
  - hard: `requirements`, `spec`, `plan`, `execute`, `verify`, `complete-dev`
  - soft: `grill`, `msf-req`, `creativity`, `wireframes`, `prototype`, `simulate-spec`
  - infra (always run, no Skip option, no failure dialog): `setup`, `worktree`, `init-state`, `final-summary`, `capture-learnings`
- [ ] Step 3: Document a fully-worked example state.yaml at the bottom showing every field populated for a Tier-3 mid-pipeline pause.

**Inline verification:**
- `grep -c "^## " state-schema.md` ≥ 7 (one per section above).
- `grep -E "^- (hard|soft|infra):" state-schema.md` lists every phase from spec §5 exactly once.
- Example block at bottom is a valid YAML doc (`python3 -c 'import yaml; yaml.safe_load(open("..."))'` exits 0; install yaml if missing or skip if no python).

---

### T3: Write `reference/pipeline-status-template.md`

**Goal:** Markdown skeleton for `00_pipeline.md` and the in-chat status table format.

**Spec refs:** §4 (Output — `00_pipeline.md`), §15 G3 (carries `schema_version: 1`).

**Depends on:** T2 (cites schema)
**Idempotent:** yes
**TDD:** no — markdown template (FR-105)
**Files:**
- Create: `plugins/pmos-toolkit/skills/feature-sdlc/reference/pipeline-status-template.md`

**Steps:**

- [ ] Step 1: Write template with: header section (slug, tier, mode, schema_version=1, started_at, last_updated, branch, worktree_path), pipeline status table with columns `phase | hardness | status | artifact_path | timestamp | notes`, footer pointer to `00_open_questions_index.md` if any deferred entries exist.
- [ ] Step 2: Pre-fill phase rows in canonical order (per spec §5) so generated `00_pipeline.md` is identical-shaped across runs; statuses default `pending`.
- [ ] Step 3: Document the in-chat short version (3 columns: phase | status | artifact) for terse status updates after each phase completion.

**Inline verification:**
- Template includes `schema_version: 1` literal (R5 mitigation).
- All 12 phase identifiers from spec §5 appear in the pre-filled table in declared order.

---

### T4: Write `reference/slug-derivation.md`

**Goal:** Deterministic-enough rules for LLM slug derivation so the agent produces consistent slugs across sessions on similar inputs.

**Spec refs:** §3 (slug derivation), §15 G7 (worktree branch collision).

**Depends on:** T1
**Idempotent:** yes
**TDD:** no — guidance doc (FR-105)
**Files:**
- Create: `plugins/pmos-toolkit/skills/feature-sdlc/reference/slug-derivation.md`

**Steps:**

- [ ] Step 1: Document rules: kebab-case, ASCII only, length 3–40 chars, no leading digit, no `--` runs, lowercase, drop stopwords (a/an/the/of/for/to/with) when length-pressed.
- [ ] Step 2: Document collision check: `git branch --list "feat/<slug>" "feat/<slug>-*"` — if matches found, append `-2`, `-3`, … OR enter G7 (d) prompt (Use existing / Pick new / Abort).
- [ ] Step 3: Provide 3 worked examples: ("Add OAuth refresh tokens for the dashboard" → `oauth-refresh-tokens`); ("/feature-sdlc skill itself" → `feature-sdlc-skill`); ("Fix bug where users can't reset password" → `fix-password-reset`).

**Inline verification:**
- All three examples manually reviewed for kebab-case + length compliance.
- Doc has explicit "no leading digit" rule (avoids `2026-…` looking like a date).

---

### T5: Write `reference/frontend-detection.md`

**Goal:** Heuristic for biasing the (Recommended) option of the wireframes gate per FR-FRONTEND-GATE — never silent skip.

**Spec refs:** §15 G6 (always-ask gate), §5 phase 4.c (frontend gate).

**Depends on:** T1
**Idempotent:** yes
**TDD:** no — heuristic doc (FR-105)
**Files:**
- Create: `plugins/pmos-toolkit/skills/feature-sdlc/reference/frontend-detection.md`

**Steps:**

- [ ] Step 1: Document the keyword list: ui, ux, screen, page, component, wireframe, css, html, visual, click, form, button, layout, design, mockup, modal, tooltip, navigation, dashboard, view, render. Plus negative signals: api-only, backend, daemon, cron, worker, library, sdk.
- [ ] Step 2: Document the explicit-tag check: a `frontend: true|false` line in requirements frontmatter wins over keywords.
- [ ] Step 3: Document the recommendation rule: `count(positive) - count(negative) > 0` → recommend Run; otherwise recommend Skip. Heuristic NEVER hides the gate (FR-FRONTEND-GATE invariant).
- [ ] Step 4: Add anti-pattern callout: "Don't bypass the gate based on confidence; the user always sees the choice."

**Inline verification:**
- Doc states the always-ask invariant explicitly.
- Anti-pattern callout present.

---

### T6: Write `reference/compact-checkpoint.md`

**Goal:** Exact AskUserQuestion shape for the pre-heavy-phase compact prompt + the Pause-resumable exit sequence per FR-PAUSE.

**Spec refs:** §15 G1 (FR-PAUSE three-part contract: state-write, chat-line, clean exit).

**Depends on:** T2 (cites state schema for paused fields)
**Idempotent:** yes
**TDD:** no — prompt doc (FR-105)
**Files:**
- Create: `plugins/pmos-toolkit/skills/feature-sdlc/reference/compact-checkpoint.md`

**Steps:**

- [ ] Step 1: Document the AskUserQuestion shape: `question`: "About to enter <phase> — context-heavy. Compact now (recommended), continue without compacting, or pause to compact and resume later?". `options`: **Continue (Recommended)** / **Pause to /compact, then I'll resume** / **Continue without compacting**. (Note: skill cannot trigger /compact directly; "Pause" just exits cleanly.)
- [ ] Step 2: Document the three-part Pause exit contract verbatim from FR-PAUSE: (1) state.yaml writes `current_phase: <X>`, `phases.<X>.status: paused`, `phases.<X>.paused_at: <ISO-8601>`, `phases.<X>.paused_reason: compact|failure|user`; on failure also `phases.<X>.last_error`. (2) Chat prints `Paused at phase <X>. To resume: cd <worktree-abs-path> && /pmos-toolkit:feature-sdlc --resume`. (3) Exit normally (no non-zero status, no thrown error).
- [ ] Step 3: List which phases trigger the checkpoint (per spec §5 Phase 2 entry: before phases 4.c wireframes, 4.d prototype, 6 simulate-spec, 8 execute, 9 verify).

**Inline verification:**
- All three contract clauses present and exact-quoted from spec §15 G1.
- Doc explicitly notes: "skill cannot trigger /compact; harness limitation."

---

### T7: Write `reference/failure-dialog.md`

**Goal:** Failure-handling AskUserQuestion structure that constructs option lists from the schema's hardness tags + missing-skill variant per FR-MISSING-SKILL.

**Spec refs:** §15 G5 (FR-PHASE-TAGS — hard/soft option construction), §15 G10 (FR-MISSING-SKILL — Pause-to-install).

**Depends on:** T2 (reads hardness tag from state-schema.md)
**Idempotent:** yes
**TDD:** no — prompt doc (FR-105)
**Files:**
- Create: `plugins/pmos-toolkit/skills/feature-sdlc/reference/failure-dialog.md`

**Steps:**

- [ ] Step 1: Document the failure-dialog construction algorithm: lookup `hardness` from state-schema.md for the current phase. If hard → options = [Retry (Recommended), Pause-resumable, Abort]. If soft → options = [Retry (Recommended), Skip stage, Pause-resumable, Abort]. Skip on soft writes `status: skipped-on-failure`.
- [ ] Step 2: Document missing-skill variant: detect via "skill not found" / "unknown skill" platform error after invocation attempt. If hard → [Abort pipeline (Recommended), Pause to install]. If soft → [Skip stage (Recommended), Abort pipeline, Pause to install]. Pause-to-install writes `status: paused, paused_reason: missing_skill, missing_skill: <name>`.
- [ ] Step 3: Cross-reference `_shared/structured-ask-edge-cases.md` for free-form / out-of-options reply handling.

**Inline verification:**
- The 4 dialog variants (hard-failure, soft-failure, hard-missing, soft-missing) all enumerated with exact option lists.
- Cite of `_shared/structured-ask-edge-cases.md` present.

---

## Phase 2: SKILL.md Body + Release

Build SKILL.md top-down, citing reference files written in Phase 1. End with release prereqs and learnings header. Phase boundary: full `/verify` after T16 → TN.

### T8: SKILL.md preamble — announce, pipeline diagram, Platform Adaptation, Track Progress, non-interactive block

**Goal:** Top-of-file scaffolding (above Phase 0) with the canonical inlined non-interactive block byte-for-byte from `update-skills`.

**Spec refs:** Convention 1 (save location), Convention 2 (platform adaptation), Convention 4 (pipeline diagram), Convention 7 (progress tracking).

**Depends on:** T1
**Idempotent:** yes
**TDD:** no (FR-105). R1 mitigation: byte-diff verification against the source.
**Files:**
- Modify: `plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md`

**Steps:**

- [ ] Step 1: After the H1, write Announce-at-start line: `**Announce at start:** "Using feature-sdlc — orchestrating the full SDLC pipeline for this feature."`
- [ ] Step 2: Write `## Pipeline position` with the diagram from spec §9 (top-level orchestrator above the pipeline). Mark `(this skill)`.
- [ ] Step 3: Write `## Platform Adaptation` covering AskUserQuestion fallback, Subagents N/A, Playwright/MCP not used, settings.yaml missing → `_shared/pipeline-setup.md` Section A, worktree-creation failures.
- [ ] Step 4: Write `## Track Progress` per Convention 7.
- [ ] Step 5: Inline the canonical `<!-- non-interactive-block:start -->` block VERBATIM from `update-skills/SKILL.md:49–132`. Use `cat plugins/pmos-toolkit/skills/update-skills/SKILL.md | sed -n '/<!-- non-interactive-block:start -->/,/<!-- non-interactive-block:end -->/p'` and paste byte-for-byte. R1 mitigation.

**Inline verification:**
- `diff <(sed -n '/<!-- non-interactive-block:start -->/,/<!-- non-interactive-block:end -->/p' plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md) <(sed -n '/<!-- non-interactive-block:start -->/,/<!-- non-interactive-block:end -->/p' plugins/pmos-toolkit/skills/update-skills/SKILL.md)` exits 0.
- Pipeline diagram contains `(this skill)` marker.

---

### T9: SKILL.md Phase 0 — settings/learnings + Phase 0.a worktree + slug + Phase 0.b resume detection

**Goal:** Implement bootstrap: read settings, load learnings, mode resolution mention, then worktree creation with the 4 edge-case dialogs (G7), then resume detection (auto-detect state.yaml).

**Spec refs:** §5 (Phase 0/0.a/0.b), §15 G7 (worktree edges), §15 G8 (--tier sourcing for gates), Convention 6 (learnings).

**Depends on:** T8 (preamble in place), T2 (state-schema cited)
**Idempotent:** yes
**TDD:** no (FR-105)
**Files:**
- Modify: `plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md`

**Steps:**

- [ ] Step 1: Write `## Phase 0: Pipeline setup + Load Learnings + Mode Resolution` — inline `_shared/pipeline-setup.md` reference per `update-skills` pattern (lines 36–46); cite learnings under `## /feature-sdlc`.
- [ ] Step 2: Write `## Phase 0.a: Worktree + Slug + Branch` enumerating the 4 G7 edge cases as table (a) not-a-repo, (b) detached HEAD, (c) dirty tree, (d) branch exists. Include the `--no-worktree` escape. AskUserQuestion for slug confirmation per `reference/slug-derivation.md`.
- [ ] Step 3: Write `## Phase 0.b: Resume Detection` — if `.pmos/feature-sdlc/state.yaml` exists, run schema_version check (per FR-SCHEMA), validate recorded artifact paths still exist, print status table from `00_pipeline.md`, jump to first non-completed phase. On `--resume` flag with no state.yaml → hard error.

**Inline verification:**
- All 4 worktree edge cases (a–d) appear with their exact error strings or AskUserQuestion shape.
- Resume path includes schema_version refuse-newer / migrate-older logic citing FR-SCHEMA.
- `Read learnings` step cites `## /feature-sdlc` heading.

---

### T10: SKILL.md Phase 1 (init state) + Phase 2 (compact checkpoint mechanics)

**Goal:** Initialize state.yaml + 00_pipeline.md on fresh runs; document the compact checkpoint as a recurring micro-phase that wraps heavy stages.

**Spec refs:** §5 phases 1 & 2, §15 G1 (FR-PAUSE), §15 G4 (open_questions_log init).

**Depends on:** T9, T3 (pipeline-status-template), T6 (compact-checkpoint)
**Idempotent:** yes
**TDD:** no (FR-105)
**Files:**
- Modify: `plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md`

**Steps:**

- [ ] Step 1: Write `## Phase 1: Initialize state` — atomically write state.yaml from the schema + 00_pipeline.md from the template, with all phases status=pending and `schema_version: 1`. Initialize `open_questions_log: []`.
- [ ] Step 2: Write `## Phase 2: Compact Checkpoint (recurring)` — invoked before phases 4.c (wireframes), 4.d (prototype), 6 (simulate-spec), 8 (execute), 9 (verify). Cite `reference/compact-checkpoint.md` for the AskUserQuestion shape. Document the Pause-resumable three-part exit contract with reference to FR-PAUSE.
- [ ] Step 3: Document the post-phase status update protocol: after every phase end (pass/fail/skip), atomically (a) update state.yaml, (b) regenerate 00_pipeline.md, (c) print 3-column in-chat status update (per Anti-pattern #6 — never skip).

**Inline verification:**
- Phase 1 step explicitly writes `schema_version: 1`.
- Phase 2 enumerates the 5 trigger phases (4.c, 4.d, 6, 8, 9).
- Atomic-write triple (a/b/c) called out as a single-step invariant.

---

### T11: SKILL.md Phase 3 (/requirements) + Phase 3.b (/grill, mandatory Tier 2+, skip in --non-interactive)

**Goal:** First two pipeline-dispatch phases with --tier passthrough (G8) and the explicit skip-grill-on-non-interactive logging (Anti-pattern #7).

**Spec refs:** §5 phases 3 & 3.b, §15 G8 (--tier scope), §15 G2 (child resume — re-invoke fresh).

**Depends on:** T10
**Idempotent:** yes — re-running phase 3 re-invokes /requirements which has its own resume per G2.
**TDD:** no (FR-105)
**Files:**
- Modify: `plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md`

**Steps:**

- [ ] Step 1: Write `## Phase 3: /requirements` — invoke `/pmos-toolkit:requirements` with the initial-context seed; pass `--tier <N>` if user supplied (G8 passthrough); after completion, capture artifact path into state.yaml; if mode is non-interactive, append child OQ artifact path to `open_questions_log[]` (G4).
- [ ] Step 2: Document that /requirements may auto-tier-escalate; if its output tier differs from orchestrator's, log `child_tier_divergence` per G8 and continue (do not override child).
- [ ] Step 3: Write `## Phase 3.b: /grill` — mandatory if state.yaml.tier ∈ {2, 3}; skipped if `mode == non-interactive` with explicit chat log line: `Skipped /grill: --non-interactive flag (Tier <N> normally requires it).` Status table records `status: skipped-non-interactive`.
- [ ] Step 4: For both phases, on failure run the failure dialog from `reference/failure-dialog.md`. Both are hard phases (no Skip option).

**Inline verification:**
- Phase 3.b explicitly logs the skip reason on non-interactive (Anti-pattern #7 satisfied).
- --tier passthrough mentioned with G8 reference.
- Both phases tagged hard (cross-check schema in T2).

---

### T12: SKILL.md Phases 4.a–4.d (optional stage gates: msf-req, creativity, wireframes, prototype)

**Goal:** Four soft-gate AskUserQuestion stages with G6 always-ask + G8 tier-driven Recommended + G10 missing-skill dialog.

**Spec refs:** §5 phases 4.a–4.d, §15 G6 (frontend always-ask), §15 G8 (tier-driven Recommended), §15 G10 (missing-skill dialog).

**Depends on:** T11, T5 (frontend-detection), T7 (failure-dialog for missing-skill variant)
**Idempotent:** yes
**TDD:** no (FR-105)
**Files:**
- Modify: `plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md`

**Steps:**

- [ ] Step 1: Write `## Phase 4.a: /msf-req gate` — AskUserQuestion: Run / Skip. Recommended = Run if tier=3, Skip if tier=2 or 1. Soft-skill missing-skill dialog applies.
- [ ] Step 2: Write `## Phase 4.b: /creativity gate` — AskUserQuestion: Run / Skip. Recommended always = Skip (always optional per spec). Soft-skill missing-skill dialog applies.
- [ ] Step 3: Write `## Phase 4.c: /wireframes gate` — invoke `reference/frontend-detection.md` heuristic to bias Recommended; gate ALWAYS PRESENTED per FR-FRONTEND-GATE invariant. Soft-skill missing-skill dialog applies.
- [ ] Step 4: Write `## Phase 4.d: /prototype gate` — only presented if 4.c chose Run. Recommended = Skip (always optional unless explicitly desired). Soft-skill missing-skill dialog applies.
- [ ] Step 5: For all four, on Run-and-failure use the soft-failure dialog from T7 (Skip option visible).

**Inline verification:**
- Phase 4.c includes the FR-FRONTEND-GATE always-ask invariant verbatim ("never silent skip").
- Each phase cites its tier-driven Recommended logic.

---

### T13: SKILL.md Phases 5–10 — /spec, /simulate-spec, /plan, /execute, /verify, /complete-dev

**Goal:** Six pipeline-dispatch phases. /spec, /plan, /execute, /verify, /complete-dev are hard. /simulate-spec is a soft gate. Each updates state.yaml + 00_pipeline.md after completion. Aggregate OQ artifacts (G4).

**Spec refs:** §5 phases 5–10, §15 G2 (child resume), §15 G4 (OQ index aggregation), §15 G5 (hard/soft for failure dialog), Anti-pattern #10 (/verify non-skippable).

**Depends on:** T12
**Idempotent:** yes per G2 (children own task-level resume)
**TDD:** no (FR-105)
**Files:**
- Modify: `plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md`

**Steps:**

- [ ] Step 1: Write `## Phase 5: /spec` (hard) — `## Phase 6: /simulate-spec gate` (soft, Recommended=Run if tier=3, Skip otherwise) — `## Phase 7: /plan` (hard) — `## Phase 8: /execute` (hard) — `## Phase 9: /verify` (hard, Anti-pattern #10 reminder, no Skip option ever) — `## Phase 10: /complete-dev` (hard).
- [ ] Step 2: For each phase, document: invoke command, --tier passthrough where applicable (G8: /spec, /plan accept --tier), capture artifact path, run failure dialog from T7 on error, append OQ artifact to `open_questions_log[]` if non-interactive (G4).
- [ ] Step 3: Document the compact checkpoint trigger before phases 6, 8, 9 (per spec §5 Phase 2 trigger list). Phase 5 (/spec) does not trigger compact (lighter context).
- [ ] Step 4: Cite `_shared/phase-boundary-handler.md` as related-but-not-reused (constraint discovered in code study).

**Inline verification:**
- Phase 9 (/verify) has explicit "no Skip option, ever" line citing Anti-pattern #10.
- Compact-checkpoint triggers match spec §5 Phase 2 trigger list (6, 8, 9).
- /spec and /plan show --tier passthrough; /execute, /verify, /complete-dev don't (they don't accept it).

---

### T14: SKILL.md Phase 11 final summary + Phase 12 capture learnings + Anti-patterns + Release prereqs

**Goal:** Final summary with status table + OQ index + branch+tag info; learnings phase per Convention 6; anti-patterns block (10 items from spec §12); release prereqs section per Convention 13 with the 3 added FR-RELEASE items.

**Spec refs:** §5 phases 11–12, §12 (anti-patterns, all 10), §13 + §15 G11 (release prereqs).

**Depends on:** T13
**Idempotent:** yes
**TDD:** no (FR-105)
**Files:**
- Modify: `plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md`

**Steps:**

- [ ] Step 1: Write `## Phase 11: Final summary` — print pipeline-status table, link to all artifacts, branch + tag info from /complete-dev, link to `00_open_questions_index.md` if any deferred entries (G4 emit-on-end).
- [ ] Step 2: Write `## Phase 12: Capture Learnings` per Convention 6 (read learnings/learnings-capture.md; reflect on /feature-sdlc itself).
- [ ] Step 3: Write `## Release prerequisites` (Convention 13 + FR-RELEASE) listing: README row under Pipeline / Orchestrators, standalone-line update, minor version bump, learnings header bootstrap, byte-identical plugin.json descriptions across .claude-plugin/.codex-plugin, argument-hint matches parsed flags, ≥5 natural trigger phrases.
- [ ] Step 4: Write `## Anti-Patterns (DO NOT)` listing all 10 anti-patterns from spec §12 verbatim.
- [ ] Step 5 (G9 — FR-FINDINGS-N-A): SKILL.md MUST NOT include a "Findings Presentation Protocol" or "Findings Protocol" section. Verify post-write: `grep -c -i "findings.*protocol\|findings presentation" SKILL.md` returns 0. Rationale: orchestrator has no review/refinement loops — every refinement is owned by a child skill (per spec §15 G9).

**Inline verification:**
- All 10 anti-patterns from spec §12 present (`grep -c "^[0-9]\+\." anti-patterns-section` ≥ 10).
- Release prereqs lists all 3 FR-RELEASE items + the 3 standard ones.
- Final summary explicitly links 00_open_questions_index.md emission per G4.
- `grep -ic "findings.*protocol\|findings presentation" plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md` returns 0 (G9 check).

---

### T15: README + plugin.json sync + version bump

**Goal:** Wire up the new skill in repo README and bump plugin versions. No `skills` array edit (auto-discovered).

**Spec refs:** §13 + §15 G11.

**Depends on:** T14
**Idempotent:** yes (re-running no-ops if version already bumped)
**TDD:** no (config edit, FR-105)
**Files:**
- Modify: `README.md` (repo root)
- Modify: `plugins/pmos-toolkit/.claude-plugin/plugin.json`
- Modify: `plugins/pmos-toolkit/.codex-plugin/plugin.json`

**Steps:**

- [ ] Step 1: Read current README.md to find the Pipeline / Orchestrators section (or insert near `/update-skills`). Add `/feature-sdlc` row with one-line description copied from SKILL.md frontmatter description (truncated to first sentence).
- [ ] Step 2: Update standalone-skills line if present; add `/feature-sdlc` to it.
- [ ] Step 3: Bump version in BOTH `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` from `2.30.0` → `2.31.0` (minor — new skill, no breaking changes).
- [ ] Step 4: Verify byte-identical descriptions: `diff <(jq -r .description plugins/pmos-toolkit/.claude-plugin/plugin.json) <(jq -r .description plugins/pmos-toolkit/.codex-plugin/plugin.json)` exits 0 with no output (R2 mitigation).

**Inline verification:**
- README grep: `grep -E "^/feature-sdlc|/feature-sdlc " README.md` finds the new row.
- `jq -r .version` on both plugin.json files returns `2.31.0`.
- Description diff is empty.

---

### T16: Add `## /feature-sdlc` header to ~/.pmos/learnings.md

**Goal:** Bootstrap the learnings entry per Convention 6 so Phase 12 has a section to write into. Idempotent — only append if missing.

**Spec refs:** §13 (one-time bootstrap), Convention 6.

**Depends on:** T14
**Idempotent:** yes (grep first, append only if absent)
**TDD:** no (FR-105)
**Files:**
- Modify: `~/.pmos/learnings.md` (user file outside repo)

**Steps:**

- [ ] Step 1: `grep -F "## /feature-sdlc" ~/.pmos/learnings.md`. If exit 0, skip steps 2–3.
- [ ] Step 2: Append `\n## /feature-sdlc\n\n_(no entries yet)_\n` to the file (preserve existing content).

**Inline verification:**
- `grep -c "^## /feature-sdlc$" ~/.pmos/learnings.md` returns 1 (exactly one header).

---

### TN: Final Verification

**Goal:** Verify the entire implementation works end-to-end and that `/verify` Phase 5 will pass on the spec FRs.

- [ ] **Structural lint:** all 7 created files exist; SKILL.md has valid frontmatter (`head -1` returns `---`, frontmatter block closes); reference/ files all present.
- [ ] **Skill catalog load:** after plugin reload, `/feature-sdlc` appears in available-skills list with the description string. (Manual: user reloads plugins; agent inspects the next available-skills system-reminder.)
- [ ] **Plugin.json sync:** `diff <(jq -r .description plugins/pmos-toolkit/.claude-plugin/plugin.json) <(jq -r .description plugins/pmos-toolkit/.codex-plugin/plugin.json)` empty; `jq -r .version` matches across both.
- [ ] **Non-interactive block byte-equality:** `diff <(sed -n '/<!-- non-interactive-block:start -->/,/<!-- non-interactive-block:end -->/p' plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md) <(sed -n '/<!-- non-interactive-block:start -->/,/<!-- non-interactive-block:end -->/p' plugins/pmos-toolkit/skills/update-skills/SKILL.md)` empty.
- [ ] **Spec-FR coverage check:** for each of the 11 FR-IDs in spec §15 (G1–G11), grep SKILL.md or the relevant reference file and confirm the FR is implemented or cited. Document each in the verify run.
- [ ] **Trigger-phrase audit:** description field contains all 6 trigger phrases listed in FR-RELEASE.ii (grep each verbatim).
- [ ] **Argument-hint audit:** argument-hint enumerates `--tier`, `--resume`, `--no-worktree`, `--non-interactive`, `--interactive`, `--backlog` (FR-RELEASE.i).
- [ ] **README + standalone update:** `/feature-sdlc` appears under Pipeline / Orchestrators and on the standalone-skills line.
- [ ] **Learnings header:** `grep -c "^## /feature-sdlc$" ~/.pmos/learnings.md` = 1.
- [ ] **Convention 6 placement:** `## Phase 12: Capture Learnings` is a numbered Phase (not unnumbered trailing) per the convention; positioned before `## Anti-Patterns`.
- [ ] **`_shared/` citation audit (D2 invariant):** `grep -c "_shared/pipeline-setup\|_shared/non-interactive\|_shared/platform-strings\|_shared/interactive-prompts\|_shared/structured-ask-edge-cases" plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md` returns ≥ 5 (each shared file cited at least once).
- [ ] **G9 absence check:** `grep -ic "findings.*protocol\|findings presentation" plugins/pmos-toolkit/skills/feature-sdlc/SKILL.md` returns 0 (orchestrator must NOT claim Findings Protocol).
- [ ] **Wireframe diff / UX polish checklist:** N/A — this is a markdown skill with no UI surface.
- [ ] **Done-when walkthrough:** trace each clause of the plan's Done-when line (file existence → catalog load → plugin.json diff → README → /verify FR-grade) — confirm each clause passes.

**Cleanup:** None — no temp files, no worktree containers, no feature flags, no docs files to update beyond README (already in T15).

---

## Review Log

> Sidecar: `03_plan_review.md` (will be created at first finding-bearing loop).

| Loop | Findings | Changes Made |
|------|----------|-------------|
| 1    | F1 (structural): G9 Findings-Protocol absence not enforced. F2 (structural): TN missing _shared/ citation audit. Both classified low-risk per FR-41 (section-presence completions); auto-applied. | T14 +Step 5 (G9 absence enforcement); TN + two grep checks (G9 + _shared/ citations). |
