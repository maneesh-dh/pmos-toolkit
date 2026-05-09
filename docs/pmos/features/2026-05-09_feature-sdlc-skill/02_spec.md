---
tier: 3
type: feature
feature: feature-sdlc-skill
spec_ref: 02_spec.md
date: 2026-05-09
status: verified
---

# Spec: /feature-sdlc

Tier: 3
Generated: 2026-05-09
Status: approved
Grilled: 2026-05-09 (standard depth, 11 dispositions)
Approved: 2026-05-09

## 1. One-line description

End-to-end SDLC orchestrator that turns an initial idea (text or doc) into a shipped feature by sequentially driving the full pmos-toolkit pipeline — worktree creation, requirements, grill, optional MSF/creativity/wireframes/prototype, spec, optional simulate-spec, plan, execute, verify, and complete-dev — auto-tiering each stage and persisting resumable state inside the worktree. Use when the user says "build this feature end-to-end", "run the full SDLC", "take this idea through to ship", "feature-sdlc this", "/feature-sdlc", or "drive the pipeline for me".

## 2. Argument hint

`<initial idea text | path to brief/doc> [--tier 1|2|3] [--resume] [--no-worktree] [--non-interactive | --interactive]`

## 3. Source / inputs

- **Initial context** — free-form text OR a file path (markdown/PDF/txt) OR a combination. If both arg and a file are passed, both are concatenated as seed input to `/requirements`.
- **No-arg invocation inside a worktree** — auto-detect `.pmos/feature-sdlc/state.yaml` and enter resume mode (Phase 0.b).
- **`--resume`** — explicit resume; errors if no state file found.
- **`--no-worktree`** — skip worktree creation, run in current cwd. For users who already prepared isolation.
- **`--tier N`** — override auto-tier; applies the same tier to all child skills that auto-tier (requirements, spec, plan, etc.).
- **Workstream context** — loaded via `_shared/pipeline-setup.md` if present. Inherited by every child skill.

## 4. Output

- **`./.pmos/feature-sdlc/state.yaml`** — resumable pipeline state (current phase, status per phase, artifact paths, slug, tier, mode, started_at, last_updated).
- **`./.pmos/feature-sdlc/00_pipeline.md`** — human-readable pipeline status doc with the same status table the user sees in chat (kept in sync with state.yaml).
- **Per-stage artifacts** — written by child skills under the configured `{docs_path}/features/{YYYY-MM-DD}_<slug>/` (requirements doc, spec, plan, etc.).
- **Git worktree + branch** — `feat/<slug>` (unless `--no-worktree`).
- **In-conversation deliverable** — pipeline-status table after every phase + final summary.
- **Happy path output:** "Pipeline complete for `<slug>`. Branch `feat/<slug>` merged to main and tagged via `/complete-dev`. State preserved at `./.pmos/feature-sdlc/state.yaml`."

## 5. Phases

| # | Phase | Purpose | Gate |
|---|-------|---------|------|
| 0 | Pipeline setup + load learnings + mode resolution | Read `.pmos/settings.yaml`, learnings, resolve mode (interactive/non-interactive), detect resume. | none |
| 0.a | Worktree + branch + slug | Inline git-worktree creation; LLM-derive slug from input, confirm via AskUserQuestion; `git worktree add` and `cd` into it. | AskUserQuestion (slug confirm) |
| 0.b | Resume detection | If `.pmos/feature-sdlc/state.yaml` exists, show status table and jump to first non-completed phase; skip Phases 0.a, 1. | none |
| 1 | Initialize state | Write initial `state.yaml` + `00_pipeline.md` with all phases as `pending`. | none |
| 2 | Compact checkpoint | Pre-heavy-phase prompt: Compact / Continue / Pause-resumable. Triggered before phases 4 (wireframes), 5 (prototype), 8 (simulate-spec), 10 (execute), 11 (verify). | AskUserQuestion |
| 3 | `/requirements` | Drive `/pmos-toolkit:requirements` with initial context as seed; capture artifact path; auto-tier reflects up. | child-skill completion |
| 3.b | `/grill` (Tier 2+, mandatory; skipped if `--non-interactive`) | Adversarial review of the requirements doc. | child-skill completion |
| 4.a | `/msf-req` confirm (Tier 3 mandatory, Tier 2 optional) | AskUserQuestion: run msf-req? | AskUserQuestion |
| 4.b | `/creativity` confirm (always optional) | AskUserQuestion: run creativity? | AskUserQuestion |
| 4.c | `/wireframes` confirm (only if frontend feature detected from req doc) | AskUserQuestion: run wireframes? | AskUserQuestion |
| 4.d | `/prototype` confirm (only if wireframes ran) | AskUserQuestion: run prototype? | AskUserQuestion |
| 5 | `/spec` | Drive `/pmos-toolkit:spec` with the requirements doc. | child-skill completion |
| 6 | `/simulate-spec` confirm (Tier 3 mandatory, Tier 2 optional) | AskUserQuestion: run simulate-spec? | AskUserQuestion |
| 7 | `/plan` | Drive `/pmos-toolkit:plan` with the spec. | child-skill completion |
| 8 | `/execute` | Drive `/pmos-toolkit:execute` with the plan. | child-skill completion |
| 9 | `/verify` | Drive `/pmos-toolkit:verify` (mandatory). | child-skill completion |
| 10 | `/complete-dev` | Drive `/pmos-toolkit:complete-dev` to merge, tag, push. | child-skill completion |
| 11 | Final summary | Pipeline-status table, links to all artifacts, branch + tag info. | terminal |
| 12 | Capture Learnings | Reflect on `/feature-sdlc` itself. | terminal |

Note: Phases 4.a–4.d and 6 are "stage gates" — single AskUserQuestion calls each — not full sub-pipelines. The compact checkpoint (Phase 2) is a recurring micro-phase invoked before each heavy stage.

## 6. Tier classification rationale

Tier 3:
- 12+ phases (well above Tier 3 threshold of 5+)
- Multi-source / multi-tier behavior (resume mode vs. fresh, frontend-detection branching, --non-interactive plumbing)
- Pipeline integration as a top-level orchestrator
- External-skill dependencies on 9+ child skills
- Eval rubric implicit (per-stage gates, status table, failure-handling state machine)

User did not pass `--tier`.

## 7. Asset inventory

| File | Purpose | Format | Invoked by |
|------|---------|--------|------------|
| _none_ | — | — | — |

No `assets/` needed. The skill is pure orchestration; all heavy logic lives in child skills.

## 8. Reference inventory

| File | Purpose | Loaded by phase |
|------|---------|-----------------|
| `reference/state-schema.md` | Canonical YAML schema for `state.yaml` (phases, statuses, artifact paths, slug, tier, mode) — single source of truth for read/write logic | Phase 1, every phase end (status update), Phase 0.b (resume) |
| `reference/pipeline-status-template.md` | Markdown skeleton for `00_pipeline.md` and the in-chat status table | Phase 1, every status update |
| `reference/slug-derivation.md` | Rules for LLM slug derivation (kebab-case, length cap, collision check against existing branches) | Phase 0.a |
| `reference/frontend-detection.md` | Heuristics for detecting a frontend feature from the requirements doc (UI/UX/screen/page/component keywords + explicit "frontend" tag) | Phase 4.c gate |
| `reference/compact-checkpoint.md` | The exact AskUserQuestion structure for the compact prompt + the "Pause-resumable" exit sequence | Phase 2 (recurring) |
| `reference/failure-dialog.md` | The Retry / Skip-and-continue / Pause-resumable / Abort prompt structure | Per-stage failure handler |

## 9. Pipeline / workstream integration

**Pipeline position: top-level orchestrator.**

```
/feature-sdlc (this skill)
    └─> [worktree + slug]
        └─> /requirements
              └─> [/grill]                        # Tier 2+, skip if --non-interactive
              └─> [/msf-req]                      # Tier 3 mandatory, Tier 2 optional
              └─> [/creativity]                   # always optional
              └─> [/wireframes]                   # if frontend feature
                    └─> [/prototype]              # optional after wireframes
        └─> /spec
              └─> [/simulate-spec]                # Tier 3 mandatory, Tier 2 optional
        └─> /plan
        └─> /execute
        └─> /verify
        └─> /complete-dev
```

**Workstream awareness:** Yes — Phase 0 loads workstream via `_shared/pipeline-setup.md`. Workstream is inherited by every child skill (each child skill already loads workstream itself; we just don't unload it).

**Cross-skill dependencies:** Hard — the skill is unusable if any of `requirements`, `spec`, `plan`, `execute`, `verify`, `complete-dev` is missing. Soft — `grill`, `msf-req`, `creativity`, `wireframes`, `prototype`, `simulate-spec` degrade to skip-with-warning if missing.

## 10. Findings Presentation Protocol applicability

**N/A at the orchestrator level.** `/feature-sdlc` does not present its own findings — every review/refinement loop is owned by a child skill (`/grill`, `/msf-req`, `/simulate-spec`, `/verify`). The orchestrator's only structured asks are:

1. Slug confirmation (Phase 0.a)
2. Optional-stage gates (Phases 4.a–4.d, 6)
3. Compact checkpoint (Phase 2)
4. Failure dialog (any phase)

These are all single-turn structured AskUserQuestion calls with clear (Recommended) options — they are not findings dumps and do not need the Findings Presentation Protocol.

## 11. Platform fallbacks

- **AskUserQuestion → numbered free-form prompts.** Slug confirmation, optional-stage gates, compact checkpoint, and failure dialog all degrade to "type 1, 2, 3, or 4". The non-interactive auto-pick contract still applies (Recommended → AUTO-PICK).
- **Subagents → sequential inline.** Pipeline dispatch is already sequential per-phase; no parallel work to degrade.
- **Playwright / MCP → not used by this skill** (child skills handle their own).
- **TaskCreate / TodoWrite → free-form prose progress.** Skill body works without task tracking; the pipeline-status table in `00_pipeline.md` is the canonical progress artifact.
- **`.pmos/settings.yaml` missing → run `_shared/pipeline-setup.md` Section A first-run setup.**
- **Worktree creation fails (no git, detached HEAD, dirty tree) →** print the precise git error, offer `--no-worktree` fallback via AskUserQuestion, or abort.
- **Child skill missing** — soft (optional) skills degrade to "skipped — skill not installed" log line + `state.yaml` status `skipped-unavailable`. Hard skills abort with a clear "install pmos-toolkit:<skill>" message.

## 11.2 Open-Question buffer schema (for --non-interactive flush)

Each entry: `{phase, question, options, picked, reason, ts}`. See `/update-skills` SKILL.md `<!-- non-interactive-block -->` section — same contract.

## 12. Anti-patterns

1. **Triggering `/compact` from the skill.** The harness does not allow it. The skill must surface a checkpoint, write `pause-resumable` state if the user picks Pause, and exit cleanly. Pretending it auto-compacts is a lie that breaks the resume contract.
2. **Skipping the worktree step "because the user knows what they're doing".** Per requirements, worktree is mandatory unless `--no-worktree` is explicitly passed. Auto-skipping when the user is already on a branch loses isolation and corrupts the resume state file's location semantics.
3. **Dispatching child skills with a "see the state file" prompt.** Each child gets a self-contained brief (initial context for `/requirements`; full requirements doc path for `/spec`; etc.). Child skills should not reach back into `state.yaml` — that file is the orchestrator's private state.
4. **Auto-running optional stages without the gate.** `/msf-req`, `/creativity`, `/wireframes`, `/prototype`, `/simulate-spec` each have an explicit AskUserQuestion gate. Recommended-default is fine; silent run is not.
5. **Frontend-detection by LLM gut-feel.** Use the `reference/frontend-detection.md` heuristics deterministically; surface uncertainty to the user via AskUserQuestion rather than guessing.
6. **Forgetting to update `state.yaml` after a child-skill completion.** Every phase end must atomically (a) update `state.yaml`, (b) regenerate `00_pipeline.md`, (c) print the in-chat status table. Skipping any of these breaks resume.
7. **Treating `--non-interactive` as "skip /grill silently".** The skill must log `phase: grill / status: skipped-non-interactive / reason: --non-interactive flag` so the user knows what was skipped on review.
8. **Resuming from a state file with stale artifact paths.** On resume (Phase 0.b), validate every recorded artifact path still exists; if any required artifact is missing, surface to user before continuing — do not re-invoke a phase silently.
9. **Conflating `--tier` override with per-child auto-tiering.** `--tier` sets the orchestrator's "expected scope" (which gates Phase 6 simulate-spec mandatory vs. optional, etc.). Child skills still auto-tier from their own inputs unless the user explicitly passes `--tier` through. Document which child skills accept tier passthrough.
10. **Skipping `/verify` because `/execute` looked clean.** Non-skippable per pipeline contract; no opt-out at any tier.

## 13. Release prerequisites

- README section: **Pipeline / Orchestrators** (new subsection if not present, alongside `/update-skills`).
- Standalone-line update: yes — add `/feature-sdlc` to the standalone-skills line.
- Version bump: **minor** (new top-level orchestrator skill, no breaking changes to existing skills).
- One-time bootstrap:
  - No new schema files outside the skill's own `reference/state-schema.md`.
  - No `plugin.json` array changes (skills are auto-discovered from the directory).
  - Add a `## /feature-sdlc` section header to `~/.pmos/learnings.md` (idempotent — script appends only if missing).
- Both `plugins/pmos-toolkit/.claude-plugin/plugin.json` and `plugins/pmos-toolkit/.codex-plugin/plugin.json` must bump in sync (pre-push hook enforces).

## 14. Open questions

Resolved by /grill on 2026-05-09 (see §15 Post-Grill Updates):
- ~~Worktree location~~ — sibling default; configurable via future setting if requested.
- ~~--tier passthrough~~ — single global tier (G8).
- ~~Frontend detection precision~~ — always-ask, heuristic biases Recommended only (G6).
- ~~Resume of partial child-skill run~~ — orchestrator owns phase-level only; children own task-level (G2).
- ~~--no-worktree + dirty tree~~ — fail-fast with actionable error (G7).

Still open:
1. **`--backlog <id>` plumbing** — should `/feature-sdlc` accept and pass through to `/requirements`? Default proposal: yes. Decide before implementation; track as Phase 7 implementation question.

## 15. Post-Grill Updates (2026-05-09)

The spec is the design contract; the dispositions below override conflicting earlier text. All 11 are Recommended-default acceptances unless tagged otherwise.

### G1. Pause-resumable contract (FR-PAUSE)

When the user picks **Pause-resumable** at any compact checkpoint or failure dialog:

1. Write `state.yaml` with: `current_phase: <X>`, `phases.<X>.status: paused`, `phases.<X>.paused_at: <ISO-8601>`, `phases.<X>.paused_reason: <compact|failure|user>`. On failure pause, also `phases.<X>.last_error: <one-line>`.
2. Print to chat verbatim: `Paused at phase <X>. To resume: cd <worktree-abs-path> && /pmos-toolkit:feature-sdlc --resume`
3. Exit normally (no non-zero status, no thrown error).

### G2. Child-skill resume contract (FR-CHILD-RESUME)

`/feature-sdlc` tracks **phase-level** state only. Child skills with internal task-level state (`/execute`, `/verify`) are responsible for detecting their own resume cursor from their workdir/artifacts when re-invoked. Child skills without resume support (`/grill`, `/msf-req`, `/creativity`, `/wireframes`, `/prototype`, `/simulate-spec`) re-run from scratch when their phase resumes — surface this in §12 anti-patterns and in the chat status table when resume re-enters such a phase.

### G3. State schema versioning (FR-SCHEMA)

`state.yaml` carries `schema_version: 1` at the top. On resume:
- `state.schema_version > current code's max supported` → abort with: `state file from newer /feature-sdlc version (vN); upgrade pmos-toolkit and retry`.
- `state.schema_version < current code's max` → auto-migrate by default-filling additive fields; log every migration to chat as `migration: state.schema vM → vN (added: <fields>)`.
- `reference/state-schema.md` is the canonical schema source; SKILL.md prose must not redeclare fields.

### G4. Open-questions aggregation (FR-OQ-INDEX)

After every child-skill phase that runs in `--non-interactive` mode:
1. Detect that child's OQ artifact path (the conventions documented in `<!-- non-interactive-block -->`: appended to primary MD, sidecar `.open-questions.md`, or `_open_questions.md` aggregator).
2. Record `{phase, child_skill, oq_artifact_path, deferred_count}` into `state.yaml.open_questions_log[]`.

At end-of-run AND end-of-pause, write `<feature_folder>/00_open_questions_index.md` with one section per logged child, linking to its OQ artifact and printing the deferred count. Index is the only doc the user opens to triage all deferred decisions.

### G5. Hard/soft phase tagging (FR-PHASE-TAGS)

Each phase carries a `tier_hardness: hard|soft` tag in `reference/state-schema.md`:
- **Hard (Skip option HIDDEN in failure dialog):** `requirements`, `spec`, `plan`, `execute`, `verify`, `complete-dev`.
- **Soft (Skip option SHOWN):** `grill`, `msf-req`, `creativity`, `wireframes`, `prototype`, `simulate-spec`.

Failure-dialog construction reads the tag to build the option list — single source of truth, no per-phase if/else in skill prose. Skip on a soft phase records `status: skipped-on-failure`.

### G6. Frontend gate is always-ask (FR-FRONTEND-GATE)

Phase 4.c (and by extension 4.d, since /prototype depends on /wireframes) **always** presents the AskUserQuestion. The `reference/frontend-detection.md` heuristic only chooses which option carries `(Recommended)`:
- Frontend-positive heuristic → `Run wireframes (Recommended)` first; `Skip` second.
- Frontend-negative heuristic → `Skip wireframes (Recommended)` first; `Run` second.

No silent skip path. Add to §12 anti-patterns: "Skipping the wireframes gate based on heuristic alone."

### G7. Worktree creation edge cases (FR-WORKTREE)

Phase 0.a inline git logic must enumerate all four:

| Case | Behavior |
|------|----------|
| (a) cwd not a git repo | Abort: `not a git repo — cd to your repo or pass --no-worktree` |
| (b) HEAD detached | Abort: `detached HEAD — checkout a branch first or pass --no-worktree` |
| (c) Dirty working tree | Abort: `dirty tree — commit/stash or pass --no-worktree` |
| (d) Branch `feat/<slug>` already exists | AskUserQuestion: **Use existing branch (Recommended)** / **Pick new slug** / **Abort**. "Use existing" enters resume mode if state.yaml is present in that branch's worktree; otherwise initializes state.yaml fresh on top of the existing branch (warning logged). |

Document all four in §12 anti-patterns.

### G8. --tier is a single global setting (FR-TIER-SCOPE)

`--tier N` (when passed) is recorded in `state.yaml.tier` and:
1. Passed verbatim to `/requirements`, `/spec`, `/plan` invocations.
2. Drives orchestrator gate logic:
   - **Tier 1** → `/grill` SKIPPED; optional gates (4.a, 4.b, 4.c, 4.d, 6) all default-recommend Skip.
   - **Tier 2** → `/grill` MANDATORY (skipped only by `--non-interactive`); optional gates default-recommend Skip; 4.c (wireframes) follows G6 heuristic.
   - **Tier 3** → `/grill` MANDATORY; 4.a (msf-req) and 6 (simulate-spec) default-recommend Run; 4.b/4.c/4.d default-recommend per their own rules.

Child skills retain the right to auto-tier-escalate from their own input analysis. If a child reports a different tier than the orchestrator's `--tier`, log to state.yaml as `phases.<X>.child_tier_divergence: <orchestrator=N, child=M>` and continue — do not override the child.

If `--tier` is not passed, the orchestrator infers from the requirements doc auto-tier output of `/requirements` (after Phase 3 completes). Until then, gate logic uses Tier 3 conservative defaults.

### G9. §10 Findings Protocol clarification (FR-FINDINGS-N-A)

Replace §10's body with:

> **N/A at the orchestrator level.** Findings Presentation Protocol governs review/refinement loops where the user must dispose of multiple discovered findings (Apply/Modify/Skip/Defer). `/feature-sdlc` has no such loop — every refinement is owned by a child skill. The orchestrator's structured asks (slug confirm, optional-stage gates, compact checkpoint, failure dialog, resume-status table) are each a single AskUserQuestion with a clear (Recommended) option, not findings dumps. The resume-status table specifically is **presentational**, not interrogative: it shows what was done so the user can pick one action ("continue from phase X / abort / restart") — no per-row disposition is required.

### G10. Missing-skill dialog (FR-MISSING-SKILL)

When a child skill is not installed at its phase's invocation point:

| Skill class | Dialog options |
|-------------|----------------|
| Soft | **Skip stage (Recommended)** / **Abort pipeline** / **Pause to install** |
| Hard | **Abort pipeline (Recommended)** / **Pause to install** |

`Pause to install` writes `status: paused`, `paused_reason: missing_skill`, `missing_skill: <name>` to state.yaml and prints resume command. `Skip stage` writes `status: skipped-unavailable`. No silent skips.

Detection: try to invoke the child skill; treat "skill not found" / "unknown skill" platform errors as the trigger. Pre-flight detection at Phase 0 is best-effort only — final source of truth is invocation result.

### G11. Release prereqs additions (FR-RELEASE)

§13 gains three explicit FR-checked items:

1. **Argument-hint matches parsed flags.** The `argument-hint:` frontmatter must enumerate every flag actually parsed in Phase 0 (`--tier`, `--resume`, `--no-worktree`, `--non-interactive`, `--interactive`, `--backlog` pending G14). `/verify` Phase 5 grades this.
2. **Natural-trigger phrases.** The `description:` field must include ≥5 user-spoken phrases. Reviewed list: "build this feature end-to-end", "run the full SDLC", "take this idea through to ship", "feature-sdlc this", "drive the pipeline for me". Plus "/feature-sdlc" literal.
3. **Plugin.json description sync.** `plugins/pmos-toolkit/.claude-plugin/plugin.json` and `plugins/pmos-toolkit/.codex-plugin/plugin.json` skill description fields must be byte-identical. Pre-push hook enforces; `/verify` Phase 5 also grades.

### Diff to Phase 5 table (rolling up G2/G5/G6/G7/G10)

Phase 0.a now explicitly enumerates 4 worktree edge cases. Phase 2 (compact checkpoint) and the failure-handling dialog are governed by G1 (pause contract). Phases 3–10 carry the hard/soft tag from G5. Phase 4.c is always-ask per G6.
