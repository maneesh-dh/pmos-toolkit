---
name: feature-sdlc
description: End-to-end SDLC orchestrator that turns an initial idea (text or doc) into a shipped feature by sequentially driving the full pmos-toolkit pipeline — worktree creation, requirements, grill, optional MSF/creativity/wireframes/prototype, spec, optional simulate-spec, plan, execute, verify, and complete-dev — auto-tiering each stage and persisting resumable state inside the worktree. Use when the user says "build this feature end-to-end", "run the full SDLC", "take this idea through to ship", "feature-sdlc this", "/feature-sdlc", or "drive the pipeline for me".
user-invocable: true
argument-hint: "<initial idea text | path to brief/doc> [--tier 1|2|3] [--resume] [--no-worktree] [--minimal] [--format <html|md|both>] [--non-interactive | --interactive] [--backlog <id>]"
---

# Feature SDLC

Top-level orchestrator that drives the full pmos-toolkit pipeline from initial idea to shipped feature. Creates a git worktree + branch, runs `/requirements → /grill → [/msf-req | /creativity | /wireframes | /prototype] → /spec → [/simulate-spec] → /plan → /execute → /verify → /complete-dev` sequentially, auto-tiers each stage, and persists resumable state inside the worktree.

**Announce at start:** "Using feature-sdlc — orchestrating the full SDLC pipeline for this feature."

## Pipeline position

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

`/feature-sdlc` is a top-level orchestrator, not a pipeline stage. Standalone — invoke at the moment you have an idea and want to ship it end-to-end.

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:

- **No interactive prompt tool:** Slug confirmation, optional-stage gates, compact checkpoint, failure dialog, and resume status table all degrade to numbered free-form prompts per `_shared/interactive-prompts.md`. The non-interactive auto-pick contract still applies (Recommended → AUTO-PICK).
- **No subagents:** Pipeline dispatch is sequential per-phase by design; no parallel work to degrade.
- **No Playwright / MCP:** Not used by this skill — child skills handle their own browser automation.
- **TaskCreate / TodoWrite missing:** Skill body works without task tracking; the pipeline-status table in `00_pipeline.{html,md}` is the canonical progress artifact.
- **`.pmos/settings.yaml` missing:** Run `_shared/pipeline-setup.md` Section A first-run setup before resolving paths.
- **Non-interactive contract:** the canonical `<!-- non-interactive-block -->` below inlines the contract from `_shared/non-interactive.md` byte-for-byte (audit-recommended.sh greps for it).
- **Platform-aware strings:** the resume command in `reference/compact-checkpoint.md` and the `[mode: <current-mode>]` subagent prefix use the per-platform `execute_invocation` mapping in `_shared/platform-strings.md`.
- **Out-of-options replies in any structured ask:** see `_shared/structured-ask-edge-cases.md`. Do not silently pick on the user's behalf.
- **Worktree creation fails (no git, detached HEAD, dirty tree, branch collision):** see Phase 0.a — surface the precise git error, offer `--no-worktree` fallback, or trigger the branch-collision dialog.
- **Child skill missing:** see Phase 0 step "Missing-skill detection" and `reference/failure-dialog.md` — present an explicit dialog (Skip / Abort / Pause-to-install). Hard skills omit Skip.

## Track Progress

This skill has multiple phases. Create one task per phase using your agent's task-tracking tool (e.g., `TaskCreate` in Claude Code, `TodoWrite` equivalent in older harnesses). Mark each task in-progress when you start it and completed as soon as it finishes — do not batch completions.

## Phase 0: Pipeline setup + Load Learnings

Inline `_shared/pipeline-setup.md` (relative to the skills directory) to:

1. Read `.pmos/settings.yaml`. If missing → run Section A first-run setup before proceeding.
2. Set `{docs_path}` from `settings.docs_path`.
3. Resolve `{feature_folder}` for this run: `{docs_path}/features/{YYYY-MM-DD}_<slug>/`. The `<slug>` is derived in Phase 0.a (worktree + slug); placeholder until then.
4. If `settings.workstream` is non-null → load `~/.pmos/workstreams/{workstream}.md` and pass through to every child skill (each child loads workstream itself; we just don't unload it).
5. Read `~/.pmos/learnings.md` if present; note any entries under `## /feature-sdlc` and factor them into your approach. Skill body wins on conflict; surface conflicts to user before applying.

Workstream IS loaded — this is a feature-level orchestrator.

### Phase 0 addendum: output_format resolution (FR-12)

6. **Resolve `output_format`.** Read `output_format` from `.pmos/settings.yaml` (default: `html`; valid values: `html`, `md`, `both`). A `--format <html|md|both>` argument-string flag overrides settings (last flag wins on conflict, per FR-12). Print to stderr exactly: `output_format: <value> (source: <cli|settings|default>)` once at Phase 0 entry. Pass the resolved value through to every dispatched child skill via the `[mode: <current-mode>]\n` first-line convention plus an additional `[output_format: <resolved>]\n` line so children inherit without re-reading settings.

<!-- non-interactive-block:start -->
1. **Mode resolution.** Compute `(mode, source)` with precedence: `cli_flag > parent_marker > settings.default_mode > builtin-default ("interactive")` (FR-01).
   - `cli_flag` is `--non-interactive` or `--interactive` parsed from this skill's argument string. Last flag wins on conflict (FR-01.1).
   - `parent_marker` is set if the original prompt's first line matches `^\[mode: (interactive|non-interactive)\]$` (FR-06.1).
   - `settings.default_mode` is `.pmos/settings.yaml :: default_mode` if present and one of `interactive`/`non-interactive`. Unknown values → warn on stderr `settings: invalid default_mode value '<v>'; ignoring` and fall through (FR-01.3).
   - If `.pmos/settings.yaml` is malformed (not parseable as YAML, or missing `version`): print to stderr `settings.yaml malformed; fix and re-run` and exit 64 (FR-01.5).
   - On Phase 0 entry, always print to stderr exactly: `mode: <mode> (source: <source>)` (FR-01.2).

2. **Per-checkpoint classifier.** Before issuing any `AskUserQuestion` call, classify it (FR-02):
   - Use the awk extractor below to find the line of this call's `question:` key in the live SKILL.md (FR-02.6).
   - The defer-only tag, if present, is the literal previous non-empty line: `<!-- defer-only: <reason> -->` where `<reason>` ∈ {`destructive`, `free-form`, `ambiguous`} (FR-02.5).
   - Decision (in order): tag adjacent → DEFER; multiSelect with 0 Recommended → DEFER; 0 options OR no option label ends in `(Recommended)` → DEFER; else AUTO-PICK the (Recommended) option (FR-02.2).

3. **Buffer + flush.** Maintain an append-only OQ buffer in conversation memory. On each AUTO-PICK or DEFER classification, append one entry per the schema in spec §11.2. At end-of-skill (or in a caught error before exit), flush (FR-03):
   - Primary artifact is single Markdown → append `## Open Questions (Non-Interactive Run)` section with one fenced YAML block per entry; update prose frontmatter (`**Mode:**`, `**Run Outcome:**`, `**Open Questions:** N` where N counts deferred only — see FR-03.4) (FR-03.1).
   - Skill produces multiple artifacts → write a single `_open_questions.md` aggregator at the artifact directory root; primary artifact's frontmatter `**Open Questions:** N — see _open_questions.md` (FR-03.5).
   - Primary artifact is non-MD (SVG, etc.) → write sidecar `<artifact>.open-questions.md` (FR-03.2).
   - No persistent artifact (chat-only) → emit buffer to stderr at end-of-run as a single block prefixed `--- OPEN QUESTIONS ---` (FR-03.3).
   - Mid-skill error → flush partial buffer under heading `## Open Questions (Non-Interactive Run — partial; skill errored)`; set `**Run Outcome:** error`; exit 1 (E13).

4. **Subagent dispatch.** When dispatching a child skill via Task tool or inline invocation, prepend the literal first line: `[mode: <current-mode>]\n` to the child's prompt (FR-06).

5. **Awk extractor.** The classifier and `tools/audit-recommended.sh` MUST both use the function below. Loaded at script init time; sourcing differs per consumer.

<!-- awk-extractor:start -->
```awk
# Find AskUserQuestion call sites and their adjacent defer-only tags.
# Input: a SKILL.md file (stdin or argv).
# Output (TSV): <line_no>\t<has_recommended:0|1>\t<defer_only_reason or "-">
# A "call site" is a line referencing `AskUserQuestion` in the SKILL's own prose
# (backtick mentions, prose instructions, multi-line invocation hints).
# `(Recommended)` is detected on the call site line OR any subsequent non-blank
# line (the option-list block) until a blank line, defer-only tag, or another
# AskUserQuestion call closes the pending call. Lines inside the inlined
# `<!-- non-interactive-block:... -->` region are canonical contract text and
# never count as call sites.
function emit_pending() {
  if (pending_call > 0) {
    out_tag = (pending_call_tag != "") ? pending_call_tag : "-";
    printf "%d\t%d\t%s\n", pending_call, pending_has_recc, out_tag;
    pending_call = 0;
    pending_has_recc = 0;
    pending_call_tag = "";
  }
}
/^<!-- non-interactive-block:start -->$/ { in_inlined=1; next }
/^<!-- non-interactive-block:end -->$/   { in_inlined=0; next }
in_inlined { next }
/^[[:space:]]*<!--[[:space:]]*defer-only:[[:space:]]*([a-z-]+)[[:space:]]*-->/ {
  emit_pending();
  match($0, /defer-only:[[:space:]]*[a-z-]+/);
  pending_tag = substr($0, RSTART + 12, RLENGTH - 12);
  sub(/^[[:space:]]+/, "", pending_tag);
  pending_line = NR;
  next;
}
/^[[:space:]]*$/ {
  emit_pending();
  pending_tag = "";
  next;
}
/AskUserQuestion/ {
  emit_pending();
  pending_call = NR;
  pending_has_recc = ($0 ~ /\(Recommended\)/) ? 1 : 0;
  pending_call_tag = (pending_tag != "" && NR == pending_line + 1) ? pending_tag : "";
  pending_tag = "";
  next;
}
{
  if (pending_call > 0 && $0 ~ /\(Recommended\)/) {
    pending_has_recc = 1;
  }
}
END { emit_pending() }
```
<!-- awk-extractor:end -->

6. **Refusal check.** If this SKILL.md contains a `<!-- non-interactive: refused; ... -->` marker (regex: `<!--[[:space:]]*non-interactive:[[:space:]]*refused`), and `mode` resolved to `non-interactive`: emit refusal per Section A and exit 64 (FR-07).

7. **Pre-rollout BC.** If the `--non-interactive` argument is present BUT this SKILL.md does NOT contain the `<!-- non-interactive-block:start -->` marker (i.e., this skill hasn't been rolled out yet): emit `WARNING: --non-interactive not yet supported by /<skill>; falling back to interactive.` to stderr; continue in interactive mode (FR-08).

8. **End-of-skill summary.** Print to stderr at exit: `pmos-toolkit: /<skill> finished — outcome=<clean|deferred|error>, open_questions=<N>` (NFR-07).
<!-- non-interactive-block:end -->

### Tier resolution

`{tier}` is set from (in precedence order):

1. `--tier N` flag if passed.
2. After Phase 3 `/requirements` completes — read its auto-tier output.
3. Until Phase 3 completes, gate-recommendation logic uses Tier-3 conservative defaults.

Per FR-TIER-SCOPE / spec §15 G8: `{tier}` drives BOTH child-skill `--tier` passthrough (only for children that accept it: `/requirements`, `/spec`, `/plan`) AND orchestrator gate logic (Phases 3.b grill, 4.b creativity, 4.c wireframes, 4.d prototype, 13 retro). Phases 4.a (msf-req) and 6 (simulate-spec) were removed in v2.34.0 — folded into /requirements (Phase 5.5) and /spec (Phase 6.5) respectively. Child skills retain the right to auto-tier-escalate; if a child reports a different tier, log to `state.yaml.phases.<X>.child_tier_divergence` and continue — do not override the child.

### Missing-skill detection

When a child skill invocation returns "skill not found" / "unknown skill" platform error, present the missing-skill dialog from `reference/failure-dialog.md`. Hard phases omit Skip; soft phases include it. Pause-to-install writes `status: paused, paused_reason: missing_skill, missing_skill: <name>` and exits per the Pause contract.

## Phase 0.a: Worktree + Slug + Branch

**Skip if `--no-worktree` was passed** — record `worktree_path: null, branch: null` in `state.yaml` and continue in cwd. (Dirty-tree case: still refuse — see (c) below — even with `--no-worktree`, since `/execute` will commit to the current branch.)

### Step 1 — Derive slug

Apply `reference/slug-derivation.md` rules to the initial-context input. Surface the proposed slug via `AskUserQuestion`:

```
question: "Proposed feature slug: <slug>. Confirm or edit?"
options:
  - Use this slug (Recommended)
  - Edit
  - Cancel
```

### Step 2 — Worktree edge cases

Before `git worktree add`, check the four edge cases from FR-WORKTREE / spec §15 G7:

| Case | Behavior |
|------|----------|
| (a) cwd is not a git repo | Abort: `not a git repo — cd to your repo or pass --no-worktree` |
| (b) HEAD detached | Abort: `detached HEAD — checkout a branch first or pass --no-worktree` |
| (c) Dirty working tree | Abort: `dirty tree — commit/stash or pass --no-worktree` |
| (d) Branch `feat/<slug>` already exists | `AskUserQuestion`: **Use existing branch (Recommended)** / **Pick new slug** / **Abort**. "Use existing" enters resume mode (Phase 0.b) if state.yaml is present in that worktree; otherwise initializes state.yaml fresh on top of the existing branch with a warning logged in `state.yaml.notes`. |

Detection commands:
- (a): `git rev-parse --is-inside-work-tree` returns false.
- (b): `git symbolic-ref -q HEAD` returns non-zero.
- (c): `git status --porcelain` returns non-empty output.
- (d): `git branch --list "feat/<slug>"` returns non-empty.

### Step 3 — Create worktree

Default location: sibling directory `<repo-parent>/<repo-name>-<slug>/` to keep navigation predictable.

```bash
git worktree add -b feat/<slug> <abs-worktree-path>
cd <abs-worktree-path>
```

Record `worktree_path` and `branch` in `state.yaml` (created in Phase 1).

## Phase 0.b: Resume detection

**Skip if `--resume` was NOT passed AND no `.pmos/feature-sdlc/state.yaml` exists in the current worktree.**

If `--resume` was passed but state.yaml is absent → hard error: `--resume specified but no .pmos/feature-sdlc/state.yaml found in <cwd>. Either cd to the right worktree or omit --resume.` Exit 64.

When state.yaml is present:

1. **Schema-version check** (FR-SCHEMA / spec §15 G3, see `reference/state-schema.md`):
   - `state.schema_version > current code's max` → abort with: `state file from newer /feature-sdlc version (vN); upgrade pmos-toolkit and retry`.
   - `state.schema_version < current code's max` → auto-migrate; log to chat: `migration: state.schema vM → vN (added: <fields>)`.
2. **Validate recorded artifact paths.** For every `phases[].artifact_path` that's non-null, check that the file exists. On any missing required artifact, print the list to chat and `AskUserQuestion`: **Continue anyway (treat as orphaned)** / **Abort**.
3. **Print status table** to chat from `00_pipeline.{html,md}` short-form (3 columns: phase | status | artifact). This table is **presentational, not interrogative** — see Anti-pattern below.
4. **Resume cursor:** find the first `phases[]` entry whose status is in `{paused, failed, pending, in_progress}` and jump to that phase. If a `paused` or `failed` entry is found first, surface the corresponding dialog (`reference/compact-checkpoint.md` for compact-paused; `reference/failure-dialog.md` for failed/failure-paused).
5. **Skip Phases 0.a and 1** — worktree, slug, and state.yaml already exist.

The resume status table is **presentational**, not interrogative — followed by at most a single structured ask (continue / abort) when needed. The orchestrator has no review/refinement loops of its own; every refinement is owned by a child skill. Per spec §15 G9.

### Auto-migration of pre-2.34.0 state files

Two phase IDs were removed in v2.34.0:

- `msf-req` — folded into `/requirements` as Phase 5.5 (W1).
- `simulate-spec` — folded into `/spec` as Phase 6.5 (W3, delegating to `_shared/sim-spec-heuristics.md`).

When `--resume` reads a pre-2.34.0 `state.yaml` carrying these phase entries, transparently elide them on read (do NOT block, do NOT prompt). The resume cursor advances to the next non-elided phase. See `reference/state-schema.md` Schema v2 auto-migration block for the exact 4-step idempotent migration contract. This back-compat handling is silent on a clean migration; if migration fails (e.g., `rename(2)` error per NFR-08), surface the failure dialog.

## Phase 1: Initialize state

**Skip if Phase 0.b entered resume mode.**

Atomically (per `reference/pipeline-status-template.md` Update protocol):

1. Write `.pmos/feature-sdlc/state.yaml` from the schema in `reference/state-schema.md`:
   - `schema_version: 1`
   - top-level fields populated from Phases 0/0.a (slug, mode, started_at = now, last_updated = now, worktree_path, branch, feature_folder).
   - `tier: null` (set after Phase 3 unless `--tier` was passed).
   - `current_phase: requirements` (the next phase to run).
   - `phases[]` populated in declared order from `state-schema.md` "Phase identifiers + hardness", every status `pending`.
   - `open_questions_log: []`.
2. Write `<feature_folder>/00_pipeline.html` from the template in `reference/pipeline-status-template.md`, rendered through the substrate at `${CLAUDE_PLUGIN_ROOT}/skills/_shared/html-authoring/`.

   - **Atomic write (FR-10.2):** temp-then-rename.
   - **Asset substrate (FR-10):** copy `assets/*` from `${CLAUDE_PLUGIN_ROOT}/skills/_shared/html-authoring/assets/` to `<feature_folder>/assets/` (`cp -n` is idempotent).
   - **Asset prefix (FR-10.1):** `assets/` (top-level feature-folder write).
   - **Cache-bust (FR-10.3):** `?v=<plugin-version>` on all asset URLs.
   - **Heading IDs (FR-03.1):** every `<h2>` and `<h3>` carries a stable kebab-case `id` per `_shared/html-authoring/conventions.md` §3.
   - **No sections.json companion** for orchestrator artifacts (per runbook edge case row 3 — `00_pipeline.html` has no `<h2>`-anchored TOC of substantive content; the status table is the body).
   - **Index regeneration (FR-22, §9.1):** seed `<feature_folder>/index.html` via `_shared/html-authoring/index-generator.md` — at this point the manifest contains a single entry for `00_pipeline.html` (subsequent child-skill writes will trigger their own regenerations to extend the manifest).
   - **Mixed-format sidecar (FR-12.1):** when `output_format` resolves to `both`, also emit `00_pipeline.md` via `bash node <feature_folder>/assets/html-to-md.js 00_pipeline.html > 00_pipeline.md`.
3. Print the in-chat short-form status table.

## Phase 2: Compact checkpoint (recurring micro-phase)

**Not a phase that runs once — invoked before each of:** `wireframes` (4.c), `prototype` (4.d), `execute` (8), `verify` (9). See `reference/compact-checkpoint.md` for the exact `AskUserQuestion` shape and the three-part Pause-resumable exit contract (FR-PAUSE / spec §15 G1). (Phase 6 simulate-spec is no longer a checkpoint trigger — it was folded into /spec in v2.34.0.)

Skills cannot trigger `/compact` directly — only the user can. The checkpoint surfaces the choice; "Pause" exits cleanly so the user can `/compact` and re-run with `--resume`.

### Atomic post-phase update protocol

After every phase end (pass / fail / skip / pause), do all three atomically — never partial:

1. Update `state.yaml`.
2. Regenerate `00_pipeline.html` (and `00_pipeline.md` sidecar when `output_format=both`) via the atomic-write + cache-bust + asset-prefix rules from Phase 1 step 2. The index regen on each phase-end picks up any sibling artifacts emitted by the just-completed child phase.
3. Print the in-chat short-form status table.

A failed update of any one of these three breaks the resume contract. Rolling back the partial write is the implementor's responsibility.

## Phase 3: /requirements (hard)

Invoke `/pmos-toolkit:requirements` with the initial-context as seed. Pass `[mode: <current-mode>]\n` as the first line of the child prompt (per FR-06). Pass `--tier <N>` if `{tier}` is set.

Pass `--backlog <id>` through if it was given to `/feature-sdlc`.

After completion:

- Capture artifact path: `<feature_folder>/01_requirements.{html,md}` (resolve via `_shared/resolve-input.md` `phase=requirements` to find whichever extension the child wrote based on the resolved `output_format`). Write to `state.yaml.phases.requirements.artifact_path`.
- Read auto-tier from the requirements doc frontmatter; if `{tier}` was unset, set it now. If `{tier}` was set and the auto-tier differs, log `child_tier_divergence: <orchestrator=<N>, child=<M>>` and continue (do not override).
- If `mode == non-interactive`, locate the child's OQ artifact (per the canonical non-interactive block conventions) and append to `state.yaml.open_questions_log[]`.

On failure: present the hard-phase failure dialog from `reference/failure-dialog.md`. No Skip option. Anti-pattern #10 (in spec §12) applies — `/verify` is non-skippable; same principle for hard phases here.

## Phase 3.b: /grill (soft, mandatory at Tier 2+, auto-skip in --non-interactive)

**Skip if `{tier}` is 1.**

**Auto-skip if `mode == non-interactive`** with explicit chat log line — never silent. The line must read:

```
Skipped /grill: --non-interactive flag (Tier <N> normally requires it).
```

Status table records `status: skipped-non-interactive`. Per FR-PHASE-TAGS (spec §15 G5) and Anti-pattern #7 (spec §12).

Otherwise, invoke `/pmos-toolkit:grill` per the **Reviewer-subagent contract (FR-50/51/52, T13a)** below.

**Reviewer-subagent contract (FR-50/51/52, T13a):** before invoking /grill, chrome-strip the artifact via `Bash('node ${CLAUDE_PLUGIN_ROOT}/skills/_shared/html-authoring/assets/chrome-strip.js <feature_folder>/01_requirements.html > /tmp/grill-stripped.html')`. Pass the stripped HTML inline to the subagent prompt with the canonical FR-51 template: *"Read this HTML content (the document's `<main>` body — chrome already stripped). First, enumerate every `<section>` id and every `<h2>`/`<h3>` id you can locate — return as `sections_found: [...]`. Then evaluate against the rubric below. For every finding, return `{section_id, severity, message, quote: \"<≥40-char verbatim from source>\"}`."*

After the subagent returns, run FR-52 validation (hard-fail on any miss): (1) read `<feature_folder>/01_requirements.sections.json`; (2) assert `sections_found` set-equality with sections.json `ids[]` — any miss/extra → hard-fail with `[/feature-sdlc] reviewer grill returned sections_found that do not match 01_requirements.sections.json: missing=[...], extra=[...]`; (3) for each finding, substring-grep `quote` against the un-stripped source HTML — any miss → hard-fail with `[/feature-sdlc] reviewer grill returned quote not found in source: <quote-prefix-30char>...`; (4) "no findings" return is allowed only if `sections_found` matches AND the rubric explicitly permits it. On any FR-52 hard-fail, pause with `reference/failure-dialog.md` (soft-phase variant).

After completion:

- Capture artifact path: `<feature_folder>/grills/<YYYY-MM-DD>_01_requirements.{html,md}` (extension follows /grill's resolved `output_format`). Write to `state.yaml`.
- Append OQ artifact to `open_questions_log[]` if non-interactive.

On failure: soft-phase failure dialog from `reference/failure-dialog.md` (Skip option SHOWN).

## Phase 4.b: /creativity gate (soft)

`AskUserQuestion`:

```
question: "Run /creativity for non-obvious improvement ideas?"
options:
  - Skip (Recommended)
  - Run /creativity
```

Always optional; Recommended is always Skip. User can opt in.

On Run: invoke `/pmos-toolkit:creativity` with the requirements doc. On missing-skill: soft-variant missing-skill dialog.

## Phase 4.c: /wireframes gate (soft, always-ask per FR-FRONTEND-GATE)

The gate is **always presented** per FR-FRONTEND-GATE / spec §15 G6 — never silent skip.

**Tier-1 override (FR-TIER-SCOPE):** at Tier 1, `(Recommended)` is always `Skip wireframes` regardless of the heuristic — Tier 1 (bug fix) does not warrant wireframes even when UI keywords appear. The gate is still presented; only the recommendation changes.

**Tier 2/3:** apply the heuristic in `reference/frontend-detection.md` to bias which option carries `(Recommended)`:

- Frontend-positive heuristic → `Run wireframes (Recommended)` first; `Skip wireframes` second.
- Frontend-negative heuristic → `Skip wireframes (Recommended)` first; `Run wireframes` second.

```
question: "Detected <UI feature | no UI signal>. Generate wireframes?"
options:
  - Run wireframes                     # (Recommended) on frontend-positive
  - Skip wireframes                    # (Recommended) on frontend-negative
```

Before invoking `/pmos-toolkit:wireframes`, run the **compact checkpoint** (Phase 2) — this is a heavy phase.

On missing-skill: soft-variant missing-skill dialog.

## Phase 4.d: /prototype gate (soft)

**If Phase 4.c was Skipped, this gate STILL presents but with `Skip (Recommended)` since there are no wireframes to prototype.** Per FR-FRONTEND-GATE / spec §15 G6 ("by extension 4.d") — never silent skip, even when the input artifact is missing. The user can still pick Run if they want a prototype built directly from the spec.

`AskUserQuestion`:

```
question: "Build a clickable prototype on top of the wireframes?"
options:
  - Skip (Recommended)
  - Run /prototype
```

Always optional; Recommended is always Skip.

Before invoking `/pmos-toolkit:prototype`, run the **compact checkpoint**.

On missing-skill: soft-variant missing-skill dialog.

## Phase 5: /spec (hard)

Invoke `/pmos-toolkit:spec` with `<feature_folder>/01_requirements.{html,md}` (resolved primary) and `--tier <N>` (passthrough). Prepend `[mode: <current-mode>]\n` and `[output_format: <resolved>]\n`.

After completion:

- Capture artifact path: `<feature_folder>/02_spec.{html,md}` (resolve via `_shared/resolve-input.md` `phase=spec`).
- Append OQ artifact to `open_questions_log[]` if non-interactive.

No compact checkpoint before this phase — `/spec` context is moderate.

On failure: hard-phase failure dialog (no Skip).

## Phase 7: /plan (hard)

Invoke `/pmos-toolkit:plan` with `<feature_folder>/02_spec.{html,md}` (resolved primary; the spec is the source of truth; `/plan` will resolve the feature folder from settings + `--feature` if needed). Pass `--tier <N>` (passthrough). Prepend `[mode: <current-mode>]\n` and `[output_format: <resolved>]\n`.

After completion: capture `<feature_folder>/03_plan.{html,md}` (resolve via `_shared/resolve-input.md` `phase=plan`). Append OQ artifact if non-interactive.

On failure: hard-phase failure dialog.

## Phase 8: /execute (hard)

Run the **compact checkpoint** first — `/execute` is heavy (TDD task-by-task implementation).

Invoke `/pmos-toolkit:execute` with the plan. **`/execute` does not accept `--tier`** — it derives tier from the plan's frontmatter.

On resume, `/execute` has its own task-level resume semantics — orchestrator re-invokes fresh and `/execute` detects its own state from the worktree's git history + plan-status markers. Per FR-CHILD-RESUME / spec §15 G2.

Cite `_shared/phase-boundary-handler.md` as the related phase-boundary handshake pattern (used by `/execute` between its internal phases — not reused directly here).

On failure: hard-phase failure dialog.

## Phase 9: /verify (hard, non-skippable)

Run the **compact checkpoint** first — `/verify` is heavy (multi-agent code review + interactive QA + spec compliance grading).

Invoke `/pmos-toolkit:verify` with the spec path. **`/verify` is non-skippable per the pipeline contract — no Skip option, ever** (Anti-pattern #10 in spec §12; mirrored below).

`/verify` does not accept `--tier`.

On failure: hard-phase failure dialog (Retry / Pause / Abort — no Skip).

## Phase 10: /complete-dev (hard)

Invoke `/pmos-toolkit:complete-dev` to merge, capture learnings into CLAUDE.md/AGENTS.md, regenerate changelog, bump versions, deploy per repo norms, tag release, and push to all remotes.

`/complete-dev` does not accept `--tier`.

On failure: hard-phase failure dialog.

## Phase 11: Final summary

Print the full pipeline-status table from `00_pipeline.html` (or `00_pipeline.md` sidecar in mixed-format mode), plus:

- Branch + tag info from `/complete-dev` output.
- Links to every artifact (`01_requirements.{html,md}`, `02_spec.{html,md}`, `03_plan.{html,md}`, plus child-skill sidecars). Use the resolver substrate (or `<feature_folder>/index.html`'s inlined manifest) to find each artifact's actual on-disk extension.
- If `state.yaml.open_questions_log[]` is non-empty: write `<feature_folder>/00_open_questions_index.html` with one section per logged child skill (path + deferred count) per FR-OQ-INDEX / spec §15 G4. Apply the same write-phase rules as `00_pipeline.html` (atomic write, asset prefix `assets/`, cache-bust, heading IDs, no `sections.json` companion per runbook edge case row 3, index regen). Mixed-format sidecar emitted as `00_open_questions_index.md` when `output_format=both`. Link to the HTML primary in the chat summary.
- Final one-liner: `Pipeline complete for <slug>. Branch feat/<slug> merged to main and tagged via /complete-dev.`

## Phase 13: /retro gate (soft, Recommended=Skip; new in v2.34.0 per W7)

After `/complete-dev` lands the release, surface an optional retro gate. The default is Skip — most users ship and move on; retro is opt-in for sessions that surfaced patterns worth analyzing across this and prior runs.

`AskUserQuestion`:

```
question: "Run /retro to capture cross-session learnings before closing the pipeline?"
options:
  - Skip (Recommended)
    description: Pipeline complete; close out without retro.
  - Run /retro
    description: Single-session retro on the just-finished /feature-sdlc run.
  - Run /retro --last 5
    description: Multi-session retro across the last 5 transcripts (recurring patterns + unique findings).
  - Defer
    description: Log to OQ index; user runs /retro later.
```

**Auto-skip if `_minimal_active` is true** per Phase 0 `--minimal` directive (T11). Log `[orchestrator] phase_minimal_skip: retro` to chat and proceed to Phase 11 final-summary without issuing the AskUserQuestion.

On Run: invoke `/pmos-toolkit:retro` with the appropriate flags. The retro phase entry in `state.yaml.phases.retro` is initialized by Phase 1 fresh-init (per state-schema.md v2). On Defer: append a stub entry to `state.yaml.open_questions_log[]` so /feature-sdlc Phase 11 surfaces the deferral.

On missing-skill: soft-variant missing-skill dialog from `reference/failure-dialog.md`. Skip option is the Recommended default.

## Phase 12: Capture Learnings

**This skill is not complete until the learnings-capture process has run.** Read and follow `learnings/learnings-capture.md` (relative to the skills directory) now. Reflect on whether this session surfaced anything worth capturing about `/feature-sdlc` itself — gate prompts that misfired, resume-state edges, child-skill missing-dialog mistakes, places `--tier` propagation got confused, paused-state recovery friction. Proposing zero learnings is a valid outcome; the gate is that the reflection happens, not that an entry is written.

## Release prerequisites

(Surfaced here per Convention 13 + FR-RELEASE / spec §15 G11 so the next `/push` (or `/complete-dev`) is not surprising.)

- README row added under **Pipeline / Orchestrators** (alongside `/update-skills`); standalone-line updated to include `/feature-sdlc`.
- Next release will require a **minor** version bump in BOTH `plugins/pmos-toolkit/.claude-plugin/plugin.json` and `plugins/pmos-toolkit/.codex-plugin/plugin.json` (versions must stay in sync — pre-push hook enforces).
- **Plugin.json description sync (FR-RELEASE.iii):** the skill description fields in both manifests must be byte-identical.
- **Argument-hint matches parsed flags (FR-RELEASE.i):** the `argument-hint:` frontmatter must enumerate every flag actually parsed in Phase 0 (`--tier`, `--resume`, `--no-worktree`, `--format`, `--non-interactive`, `--interactive`, `--backlog`).
- **Natural-trigger phrases (FR-RELEASE.ii):** the `description:` field must include ≥5 user-spoken phrases. Current set: "build this feature end-to-end", "run the full SDLC", "take this idea through to ship", "feature-sdlc this", "/feature-sdlc", "drive the pipeline for me".
- **Learnings header bootstrap:** add `## /feature-sdlc` section header to `~/.pmos/learnings.md` (idempotent — only append if missing).
- No new schema files outside this skill's own `reference/state-schema.md`. No `plugin.json` `skills` array changes (skills auto-discovered from directory).

## Anti-Patterns (DO NOT)

1. **Triggering `/compact` from the skill.** The harness does not allow it. Surface a checkpoint, write `paused-resumable` state if the user picks Pause, and exit cleanly. Pretending it auto-compacts is a lie that breaks the resume contract.
2. **Skipping the worktree step "because the user knows what they're doing".** Worktree is mandatory unless `--no-worktree` is explicitly passed. Auto-skipping when the user is already on a branch loses isolation and corrupts the resume state file's location semantics. The four worktree edge cases (a) not-a-repo, (b) detached HEAD, (c) dirty tree, (d) branch already exists — all handled in Phase 0.a — are non-bypassable; do not auto-stash, auto-rename, or auto-delete to make them go away.
3. **Dispatching child skills with a "see the state file" prompt.** Each child gets a self-contained brief (initial context for `/requirements`; full requirements doc path for `/spec`; etc.). Child skills must not reach into `state.yaml` — that file is the orchestrator's private state.
4. **Auto-running optional stages without the gate.** `/creativity`, `/wireframes`, `/prototype` each have an explicit `AskUserQuestion` gate. Recommended-default is fine; silent run is not. (`/msf-req` and `/simulate-spec` no longer have orchestrator gates — they are folded inside `/requirements` Phase 5.5 and `/spec` Phase 6.5 respectively, default-on at Tier 3.) Note: `--minimal`-driven Skip on the four soft gates (creativity, wireframes, prototype, retro) is user-explicit and does not violate this rule — see Phase 0 `_minimal_active` directive.
5. **Frontend-detection by LLM gut-feel.** Use `reference/frontend-detection.md` heuristics deterministically; surface uncertainty via `AskUserQuestion` rather than guessing. The gate is always presented (FR-FRONTEND-GATE).
6. **Forgetting to update `state.yaml` after a child-skill completion.** Every phase end must atomically (a) update `state.yaml`, (b) regenerate `00_pipeline.html` (and the `.md` sidecar when `output_format=both`), (c) print the in-chat status table. Skipping any of these breaks resume.
7. **Treating `--non-interactive` as "skip /grill silently".** The skill must log `phase: grill / status: skipped-non-interactive / reason: --non-interactive flag` so the user knows what was skipped on review.
8. **Resuming from a state file with stale artifact paths.** On resume (Phase 0.b), validate every recorded artifact path still exists; if any required artifact is missing, surface to user before continuing — do not re-invoke a phase silently.
9. **Conflating `--tier` override with per-child auto-tiering.** `--tier` sets the orchestrator's expected scope (drives gates) AND is passed to children that accept it (`/requirements`, `/spec`, `/plan`). Children may auto-tier-escalate; log divergence in `child_tier_divergence` rather than overriding.
10. **Skipping `/verify` because `/execute` looked clean.** Non-skippable per pipeline contract; no opt-out at any tier.
