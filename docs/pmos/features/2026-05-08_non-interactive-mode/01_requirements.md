---
status: Approved
tier: 3
date: 2026-05-08
last_updated: 2026-05-08
---

# Non-Interactive Mode for pmos-toolkit Skills — Requirements

**Date:** 2026-05-08
**Last updated:** 2026-05-08
**Status:** Approved
**Tier:** 3 — Feature

## Problem

Every pmos-toolkit skill (`/requirements`, `/spec`, `/plan`, `/execute`, `/verify`, `/wireframes`, `/prototype`, `/artifact`, etc.) pauses at multiple `AskUserQuestion` checkpoints during a run. A code survey counted **~188 documented checkpoints across 23 skills** — `/artifact` (22), `/wireframes` (21), `/spec` (18), `/requirements` (18) lead the list. Each checkpoint blocks until a human answers, even when the skill has already proposed a clearly recommended default. **Users who want to run skills unattended — in CI, scripted pipelines, batch backfills, or just-go-do-it sessions — cannot do so today.** They either babysit every prompt or fork the skill.

### Who experiences this?

- **Power users** running multiple skills in sequence (e.g., `/requirements → /spec → /plan`) who want the pipeline to flow without per-step gating.
- **Scripted invokers / CI users** wiring pmos-toolkit into automated workflows (nightly artifact regeneration, post-PR hooks, batch jobs).
- **Parent skills / agents** that dispatch a pmos-toolkit skill as a subagent — the subagent has no human attached, so today every checkpoint is silently auto-defaulted via the "no `AskUserQuestion`" platform fallback, with no record of what was assumed.
- **Repeat-task users** for whom the same checkpoint answers are obvious (always Tier 3, always this feature folder, always Apply on findings) and the asking is friction.

### Why now?

- The toolkit has matured to ~23 skills with stable checkpoint conventions — the cost of a cross-cutting flag is now amortizable.
- The "(Recommended)" option pattern is now used consistently across skills, giving us a clean confidence signal for free.
- Multi-skill pipelines (requirements → spec → plan → execute → verify) and parent-skill orchestration (e.g., `/wireframes` invoking `/msf-wf`) have both grown — both produce friction proportional to checkpoint count.
- External agentic peers (Claude Code, Aider, Cursor/Cline) have all converged on some form of non-interactive flag; users now expect it.

## Goals & Non-Goals

> Goals are observable user outcomes; engineering acceptance criteria belong in `/spec`.

### Goals

- **Pre-flight audit completed:** every supporting skill has been swept so every non-deferring `AskUserQuestion` call carries a "(Recommended)" option, and every destructive checkpoint is explicitly tagged as defer-only — measured by **`tools/audit-recommended.sh` (or equivalent CI check) passes for every supporting skill before the flag ships**.
- A user can pass `--non-interactive` to any pmos-toolkit skill and the skill runs to completion without prompting — measured by **zero `AskUserQuestion` calls firing during the run**.
- The skill produces the same artifact shape it would in interactive mode, with one addition: an inline `## Open Questions` block at the end listing every checkpoint that was deferred plus the assumption made — measured by **artifact contains a populated Open Questions section iff at least one checkpoint deferred**.
- Destructive or irreversible operations (overwrite, restart-from-scratch, downstream-drift) are **never** silently auto-applied — measured by **zero data-loss incidents from non-interactive runs over the first 30 days** (proxy: every destructive checkpoint surfaces in Open Questions or stops the run).
- Users can set a repo-level default in `.pmos/settings.yaml` (`default_mode: non-interactive`) and override per-invocation with `--interactive` — measured by **mode resolution follows declared precedence: explicit flag > settings > interactive-default in 100% of runs**.
- Callers (CI, parent skills) can distinguish clean / deferred / error outcomes via exit code and frontmatter — measured by **exit-code contract `0 / 2 / 1` honored in every skill**.

### Non-Goals (explicit scope cuts)

- **NOT building a new fully-autonomous "agent" mode** — `--non-interactive` skips approval *checkpoints*; it does not change the skill's existing logic, research depth, or output structure. Because the bar for an autonomous agent is much higher (judgment under uncertainty, multi-turn correction) and out of scope for this iteration.
- **NOT a YOLO / auto-approve-everything mode** — destructive operations always defer or stop. Because the failure modes observed in Aider (`#3903` skipped shell commands) and Cursor YOLO bypass research are unacceptable for a PM/eng toolkit that produces shared artifacts.
- **NOT a CLI/headless rewrite** — the flag works inside the existing skill harness (Claude Code, Codex, etc.). Because the value comes from removing checkpoints, not from changing where the skill runs.
- **NOT a per-checkpoint allowlist / deny-list** (Cline-style category tiering) — single binary flag in v1. Because the "(Recommended)" convention already gives us a uniform confidence signal; finer tiers can be added later if needed.
- **NOT auto-detecting non-TTY** to flip the mode — explicit activation only. Because subagent-dispatched runs are not always non-interactive (the parent skill may be ask-able), and silent mode-flips are a known-bad UX from Cline's `-y` auto-trigger.
- **NOT modifying skills that explicitly forbid mode flags** (e.g., `/msf-req` lists `--apply-edits` etc. as not-supported) without a per-skill design pass — those skills get a documented "non-interactive not supported" error rather than partial behavior. Because partial coverage (yarn `#5002`, `#6332`) is a worse failure mode than a clear refusal.

## User Experience Analysis

### Motivation

- **Job to be done:** "Run a pmos-toolkit skill end-to-end without babysitting prompts, and trust that anything the skill couldn't decide alone is surfaced clearly at the end."
- **Importance/Urgency:** **High for power users**, low for first-timers. A user running `/requirements` once a week may not feel the friction; a user running 5 skills in a pipeline several times a day feels every checkpoint. Without this, the toolkit's ceiling for productivity is bounded by human approval rate.
- **Alternatives:**
  - *Status quo (babysit prompts):* tolerable for occasional runs; breaks for CI and pipelines.
  - *Per-skill flags ad-hoc:* `/msf-wf --apply-edits`, `/diagram --selftest` already exist, but they're skill-specific and don't address checkpoint flow uniformly.
  - *Platform "no-AskUserQuestion" fallback (Codex/Slack):* already exists; assumes silently with no surfacing. Worse than what we're building because the user can't see what was assumed.
  - *Forking the skill to delete checkpoints:* maintenance nightmare, abandoned within weeks.
  - *Stay in Claude Code with manual hammering of "Recommended":* tedious; the user is just rubber-stamping.

### Friction Points

| Friction Point | Cause | Mitigation |
|---|---|---|
| "I don't know if it skipped something important" | Silent assumption; no record of what was decided | Inline `## Open Questions` block lists every deferred or auto-picked checkpoint with the assumption text |
| "It overwrote my draft" | Destructive op auto-applied | Destructive ops never auto; defer to Open Questions or stop with exit code 2 |
| "Half the prompts still fired" | Partial coverage (yarn `#5002` failure mode) | Per-skill audit during `/spec`; CI test asserts zero `AskUserQuestion` calls under the flag |
| "I forgot I'd set it as default" | Settings-level mode forgotten on next session | Skill announces resolved mode in its opening line ("Running in non-interactive mode (from settings.yaml)") |
| "The Open Questions block is huge and unreadable" | Many low-signal deferrals dilute the few that matter | Group by severity: destructive blockers first, then free-form deferrals, then minor assumptions |
| "I want prompts back for this one run" | Default flipped to non-interactive in settings | Symmetric `--interactive` override flag |
| "Subagent run silently assumed my whole tier" | Parent skill dispatched a child without flag awareness | Parent passes mode through explicitly; child with no parent and no flag uses interactive default |
| "CI shows green but the artifact has 30 open questions" | Exit code didn't reflect deferred state | Three-state exit (`0` clean / `2` deferred / `1` error) |

### Satisfaction Signals

- User runs `/requirements --non-interactive` and gets a complete `01_requirements.md` plus a short Open Questions block with maybe 1–3 entries — feels productive.
- Re-running the same command after answering the open questions in-place produces the same artifact with an empty Open Questions block — feels deterministic.
- A CI job exits `0` and merges; or exits `2` and posts the open questions to the PR — feels integrable.
- A power user notices their pipeline ran 4 skills end-to-end in one shot, with every assumption logged — feels like leverage, not abdication.

## Solution Direction

A single cross-cutting `--non-interactive` flag, supported by every skill in the toolkit, that:

1. **Replaces every `AskUserQuestion` call** with one of two behaviors:
   - **Auto-pick the (Recommended) option** if the call has one. This is our "high confidence" signal — the skill author already declared a sensible default, we honor it.
   - **Defer to Open Questions** if no Recommended option exists, the call is free-form (no options), or the call gates a destructive operation.

2. **Records every auto-pick and deferral** in an inline `## Open Questions` section at the bottom of the produced artifact (or in a dedicated `OPEN_QUESTIONS.md` for skills that don't produce a markdown artifact). Each entry shows: the question, the auto-picked answer (or "deferred"), the reason, and how to resolve.

3. **Activates via** (precedence high → low):
   - Explicit `--non-interactive` flag on the skill invocation.
   - `default_mode: non-interactive` in `.pmos/settings.yaml`.
   - Default: interactive.
   - Symmetric `--interactive` flag forces ask-mode regardless of settings.

4. **Surfaces outcome via exit code + frontmatter:**
   - Exit `0` + `status: complete` — no checkpoints deferred; artifact is final.
   - Exit `2` + `status: deferred` + `open_questions: N` — at least one checkpoint deferred or destructive op stopped; artifact is provisional.
   - Exit `1` + `status: error` — hard failure (unchanged from today's behavior).
   - Plus a one-line stderr summary for log scrapers: `pmos-toolkit: /<skill> finished with N open questions; see <artifact>#open-questions`.

5. **Honors the existing "(Recommended)" convention.** No new confidence heuristic. If a skill author wants a checkpoint to auto-resolve under non-interactive, they mark a Recommended option (which is already best practice). If they want it to always defer, they omit Recommended. This makes the flag's behavior auditable per-call.

6. **Inherits through subagent dispatch.** When a parent skill invokes a child skill, the parent's mode is passed through explicitly; a parent in `--non-interactive` runs the child in `--non-interactive` unless overridden.

7. **Refuses cleanly on unsupported skills.** Skills that explicitly forbid mode flags (e.g., `/msf-req`) error with: `"--non-interactive not supported by /msf-req; design constraint, see SKILL.md"` rather than partially honoring it.

8. **Pre-flight Recommended-marker audit (in scope for v1).** Before the flag is activated for a given skill, that skill's SKILL.md is swept to ensure every `AskUserQuestion` call either (a) carries a Recommended option (will auto-pick) or (b) is explicitly tagged as defer-only (free-form, destructive, or deliberately ambiguous). The audit is part of v1 deliverables — not a follow-on. A skill is not "supported" until it passes this sweep.

### Rejected Alternatives

- **Log-and-warn-only (no flag, no settings, no Open Questions block).** "When `AskUserQuestion` cannot reach a human, log a warning and pick the first option." Rejected because: (i) no defer signal — caller can't tell whether the artifact is final or provisional; (ii) no destructive guard — silently picks "overwrite"; (iii) no exit-code differentiation; (iv) reproduces the exact partial-coverage failure mode that has plagued Aider, yarn, and Cline. The flag-plus-Open-Questions design costs more upfront but gives every caller a structured, auditable contract.
- **Per-skill ad-hoc auto flags (`/spec --auto`, `/wireframes --skip-prompts`).** Rejected because: skills already drift in flag conventions (`--apply-edits`, `--rigor`, `--screenshots`); adding 23 bespoke auto-flags would worsen this. Single cross-cutting `--non-interactive` is one concept to learn.
- **Tiered destructive flag (`--non-interactive` + `--yes-destructive`).** Rejected for v1 because destructive operations in the toolkit are rare enough that "always defer" is workable, and tiering doubles the surface area to audit and document. Revisit if real users hit recurring friction.

```
        ┌─────────────────────────────────────────────────────────┐
        │  user runs /skill --non-interactive                     │
        │                       │                                 │
        │     ┌─────────────────┴────────────────┐                │
        │     │ skill resolves mode (flag>settings>default)       │
        │     └─────────────────┬────────────────┘                │
        │                       │                                 │
        │            ┌──────────┴──────────┐                      │
        │            │  for each            │                     │
        │            │  AskUserQuestion:   │                      │
        │            └──────────┬──────────┘                      │
        │                       │                                 │
        │  ┌────────────────────┼────────────────────┐            │
        │  │                    │                    │            │
        │  ▼                    ▼                    ▼            │
        │ has              no                   destructive       │
        │ Recommended    Recommended /              op             │
        │ option         free-form                                 │
        │  │                    │                    │            │
        │  ▼                    ▼                    ▼            │
        │ auto-pick;       defer to            defer to OQ;        │
        │ log to OQ        OQ; safe            stop write or       │
        │                  no-op continue     -2 variant           │
        │                                                          │
        │  ─────────────► artifact written + ## Open Questions    │
        │                 + exit 0|2|1                            │
        └─────────────────────────────────────────────────────────┘
```

## User Journeys

### Primary Journey (Happy Path) — Power User runs /requirements unattended

1. User runs `/requirements --non-interactive Build a mode flag across skills.`
2. Skill announces: `Running in non-interactive mode. Open Questions will be surfaced at the end.`
3. Phase 0 setup: `.pmos/settings.yaml` is missing → first-run prompt would fire; instead the skill auto-picks Recommended for docs path (`docs/pmos/`), workstream (`None`), feature slug (derived from the argument), tier (signal-based), logs each pick to a running Open Questions buffer.
4. Phase 2 research, Phase 3 brainstorm: every `AskUserQuestion` either auto-resolves to Recommended or defers (free-form prompts always defer).
5. Phase 5 review loops: each finding's disposition auto-picks the Recommended option (typically "Fix as proposed"); user-confirmation gate for exit defers (it has no Recommended).
6. Phase 6: workstream enrichment defers (free-form addition).
7. Phase 7 learnings: skill emits the one-line learnings reflection unchanged.
8. Phase 8 handoff: skill writes `01_requirements.md` with frontmatter `status: deferred, open_questions: 3` and an `## Open Questions` block listing the 3 deferrals with resolution hints. Exit 2.
9. User reads the block, edits 3 lines in the artifact (or re-runs interactively to answer), commits.

### Alternate Journey — CI pipeline regenerates docs nightly

1. CI job runs `/spec --non-interactive --feature 2026-05-01_search-fix`.
2. Skill resolves mode, runs all phases, writes `02_spec.md` with `status: complete, open_questions: 0`. Exit 0.
3. CI auto-merges the doc-update PR.
4. If a future run produces deferred output (exit 2), CI marks the PR as needs-review and posts the Open Questions block as a PR comment.

### Alternate Journey — Parent skill (/execute) dispatches /verify in non-interactive

1. User runs `/execute --non-interactive`.
2. `/execute` advances task by task; at the end of each phase it dispatches `/verify` as a subagent **with `--non-interactive` propagated**.
3. `/verify` runs lint, tests, multi-agent code review; auto-applies Recommended dispositions on findings; defers any destructive fix or any finding without a Recommended option.
4. Both skills' Open Questions are merged into the parent's final summary.

### Alternate Journey — User has settings-level default but wants prompts for one run

1. `.pmos/settings.yaml` has `default_mode: non-interactive`.
2. User runs `/requirements --interactive Build the new login flow.`
3. Flag wins precedence; skill runs interactively. Settings unchanged.

### Error Journey — Destructive op blocks the run

1. User runs `/requirements --non-interactive` for a feature that already has `01_requirements.md`, `02_spec.md`, and `03_plan.md`.
2. Phase 1 detects downstream-drift checkpoint. This is destructive (will desync downstream artifacts). It defers.
3. Skill stops before overwriting. Writes nothing. Logs the deferral to stderr.
4. Exit code 2. Stderr: `Refused destructive overwrite: 01_requirements.md exists with downstream 02_spec.md, 03_plan.md. Re-run with --interactive or delete downstream artifacts.`

### Error Journey — Skill that forbids the flag

1. User runs `/msf-req --non-interactive`.
2. Skill detects unsupported flag in Phase 0; errors with: `--non-interactive not supported by /msf-req. This skill is recommendations-only by design and uses free-form input. Run interactively or use --apply-edits via /wireframes.`
3. Exit code 1. No artifact written.

### Error Journey — Free-form input with no inferable answer

1. User runs `/requirements --non-interactive` with an empty argument.
2. Phase 1 needs a problem statement. Free-form, no Recommended.
3. Skill cannot proceed without input; defers to Open Questions but **also halts before writing any artifact** because the deferral is structurally upstream of all output.
4. Exit code 2. Stderr: `Cannot proceed without a problem statement. Re-run with an argument or interactively.`

### Empty States & Edge Cases

| Scenario | Condition | Expected Behavior |
|---|---|---|
| First-run (no settings.yaml) | User passes `--non-interactive` | Auto-pick Recommended for all 3 first-run questions; log to Open Questions; proceed |
| Workstream linked but missing file | `settings.workstream` set but file deleted | Defer with assumption "workstream context unavailable; proceeding without"; do not error |
| Subagent invoked via Task tool | Parent did not pass mode through | Child runs in interactive default; parent must propagate explicitly |
| Generic Task-tool / orchestrator agent (non-pmos) calls a pmos skill | No pmos parent in the chain | Child uses interactive default unless `--non-interactive` is in the prompt the orchestrator sends; no auto-inheritance from non-pmos parents (settings.yaml may still apply) |
| User passes both `--non-interactive` and `--interactive` | Conflicting flags | Error: `Conflicting mode flags. Pick one.` Exit 1. |
| Settings says `default_mode: non-interactive` and no flag passed | Implicit non-interactive | Skill announces resolved mode in opening line; proceeds |
| Skill in middle of a `/loop` invocation | Recurring run via /loop | `--non-interactive` honored on each iteration; deferred runs surface as warnings in /loop output |
| Recommended option has been removed since last skill update | Skill author edits SKILL.md | Defer that checkpoint; do not pick a non-Recommended option silently |
| Feature folder ambiguous (multiple `*_<slug>` matches) | Glob returns 2+ | Defer (destructive: picking wrong folder breaks downstream). Do not auto-pick. |
| `--feature <slug>` passed with no match | 0 matches | Hard error (unchanged from interactive). Exit 1. |

## Design Decisions

| # | Decision | Options Considered | Rationale |
|---|---|---|---|
| D1 | Confidence signal = the existing "(Recommended)" option in `AskUserQuestion` calls | (a) New per-skill scoring rule, (b) Uniform heuristic ("one option scores 2× next"), (c) Reuse Recommended convention | (c) is already a best practice across all 23 skills; piggybacking avoids inventing a parallel signal that would drift. Skill authors can opt any checkpoint into auto-pick by adding a Recommended marker, or out by removing it. |
| D2 | Low-confidence policy = defer to Open Questions, continue (exit 2) | (a) Defer + continue, (b) Strict: error and stop (gh CLI), (c) Two flags `--non-interactive` + `--strict` | (a) matches the user's mental model of "best guess + flag the rest"; preserves artifact value even when partial. Strict mode is a follow-on (D9). |
| D3 | Destructive ops always defer; never auto | (a) Always defer, (b) Require separate `--yes-destructive`, (c) Auto with git-snapshot safety net | (a) is the safest baseline. Cursor YOLO bypass research and Aider `#3903` show silent destructive ops are the canonical failure mode. Tiered destructive flag (b) is over-engineered for v1. |
| D4 | Output: inline `## Open Questions` in the artifact + frontmatter status + stderr summary | (a) Inline + frontmatter, (b) Sidecar `_open_questions.md`, (c) stderr / chat only | (a) keeps deferred decisions co-located with the affected artifact; survives multi-skill pipelines (next skill reads it); frontmatter gives CI a structured field. Sidecar splits review surface; stderr-only loses in agent transcripts. |
| D5 | Activation precedence: explicit flag > settings > interactive default; symmetric `--interactive` override | (a) Flag only, (b) Flag + env var, (c) Flag + repo settings, (d) Auto-detect non-TTY | (c) lets repos opt in once for power users; explicit flag still wins per-invocation. Env var (b) adds a third source of truth — defer until requested. Auto-TTY (d) breaks subagent runs. |
| D6 | Scope v1: every skill in the toolkit (23) | (a) Top-5 heaviest, (b) Pipeline only, (c) All 23 | (c) is what the user asked for; partial coverage is a known-bad failure mode (yarn `#5002`). Skills that structurally cannot support it (e.g., `/msf-req`) error explicitly per D7. |
| D7 | Skills that forbid the flag error explicitly | (a) Silently fall back to interactive, (b) Partial honor, (c) Hard error with reason | (c) matches the doc-everything ethos; silent fallback (a) hides the constraint. The error message names the design reason and points at alternatives. |
| D8 | Subagent inheritance: explicit propagation from parent | (a) Auto-detect non-TTY, (b) Always inherit, (c) Explicit propagation, (d) Never inherit | (c) avoids surprises; parent skill author makes a deliberate choice. Documented in the per-skill checkpoint audit during `/spec`. |
| D9 | Exit codes: `0` clean / `2` deferred / `1` error | (a) Three-state, (b) Two-state, (c) Conventional 0/1 | (a) lets CI distinguish "needs human" from "broken"; aligns with how Terraform and gh CLI separate plan-vs-apply outcomes. |
| D10 | Naming: `--non-interactive` (and `--interactive` override) | (a) `--non-interactive`, (b) `--yes`, (c) `--auto`, (d) `--unattended` | (a) matches Debian/yarn/gh convention; signals "no human is here" rather than "answer yes"; the toolkit's prompts are open-ended, not yes/no, so `--yes` would mislead. |

## Success Metrics

| Metric | Baseline | Target | Measurement |
|---|---|---|---|
| Cross-skill coverage | 0 / 23 skills | 23 / 23 skills either support the flag end-to-end OR explicitly refuse it with a documented design reason in SKILL.md | Count of skills with declared status (supported / refused-with-reason) ≥ 23; zero "silently partial" skills |
| Checkpoint auto-resolution rate | n/a | ≥70% of checkpoints auto-pick (Recommended exists) | Per-skill telemetry: `auto_picked / (auto_picked + deferred)` averaged over real runs |
| Destructive incidents | n/a | 0 in first 30 days | Manual issue triage; any "skill overwrote my X" report counts |
| Time-to-artifact for a 4-skill pipeline | ~human-paced (variable, often 30+ min interactive) | ≤30% of interactive baseline for pipelines that fully auto-resolve | Stopwatch / log-scraper on representative pipelines |
| Open Questions per artifact (avg) | n/a | Median ≤3, p95 ≤8 | Parse frontmatter `open_questions` across runs |
| Mode-resolution defects | n/a | 0 | Test asserts precedence (flag > settings > default) in 100% of mode-resolution unit tests |
| Recommended-marker audit | uncounted today | 100% of supported-skill `AskUserQuestion` calls are either Recommended-tagged or defer-only-tagged | CI script greps each SKILL.md and reports any unmarked calls; gating for the flag's per-skill activation |
| Adoption | n/a | ≥1 user using `default_mode: non-interactive` in repo settings within 60 days | Settings.yaml grep on user repos (self-report or telemetry if exists) |

## Research Sources

| Source | Type | Key Takeaway |
|---|---|---|
| `plugins/pmos-toolkit/skills/` (23 skills) | Existing code | ~188 checkpoints; 5 categories; "(Recommended)" convention already uniform; `AskUserQuestion` is the central pause primitive |
| `plugins/pmos-toolkit/skills/_shared/pipeline-setup.md` | Existing code | Phase 0 setup pattern; first-run prompt; settings.yaml as the durable repo-level config — the right home for `default_mode` |
| Skills' "Platform Adaptation" blocks (every SKILL.md) | Existing pattern | Already documents the no-`AskUserQuestion` fallback ("State your assumption, document it, proceed") — the blueprint for non-interactive behavior |
| Existing flags: `--feature`, `--apply-edits`, `--rigor`, `--screenshots`, `--resume`, `--restart` | Existing convention | Skills already parse flags in Phase 0/1; no shared utility yet — likely a `_shared/parse-mode.md` artifact in `/spec` |
| Aider `--yes-always` + bug `#3903` | External | https://github.com/Aider-AI/aider/issues/3903 — "skipped shell commands without running them" is the canonical partial-coverage failure |
| Claude Code `--dangerously-skip-permissions` | External | https://code.claude.com/docs/en/permission-modes — naming-as-deterrent design pattern; reserved for follow-on if we ever need destructive auto |
| Terraform `plan` → `apply` | External | https://developer.hashicorp.com/terraform/cli/commands/apply — separate decide-from-execute is the spiritual model for our defer-to-Open-Questions block |
| gh CLI `GH_PROMPT_DISABLED` | External | https://github.com/cli/cli/issues/1739 — strict variant: error rather than guess. Possible follow-on `--strict` flag |
| LangGraph `interrupt()` / `Command(resume=...)` | External | https://docs.langchain.com/oss/python/langchain/human-in-the-loop — unanswered question as first-class structured state; informs our Open Questions schema |
| Debian `DEBIAN_FRONTEND=noninteractive` + `Dpkg::Options::="--force-confold"` | External | http://www.microhowto.info/howto/perform_an_unattended_installation_of_a_debian_package.html — non-interactive needs a default-resolution policy, not just prompt suppression |
| Cline auto-approve + bypass research | External | https://docs.cline.bot/features/auto-approve and https://www.theregister.com/2025/07/21/cursor_ai_safeguards_easily_bypassed/ — denylist bypass via subshell; informs D3 (always defer destructive) |
| cookiecutter `--no-input` | External | https://cookiecutter.readthedocs.io/en/stable/advanced/suppressing_prompts.html — defaults are template-author-time contract; aligns with our "Recommended is the contract" rule |
| yarn `--non-interactive` partial coverage `#5002` | External | https://github.com/yarnpkg/yarn/issues/5002 — informs D6 scope decision |

## Open Questions

| # | Question |
|---|---|
| 1 | Should `--strict` (gh CLI: error on uncertainty) be a v1 follow-on or a separate later iteration? Current direction: not in v1; defer until a real CI consumer requests it. |
| 2 | What's the exact format of an Open Questions entry — should it be a table, a numbered list, or YAML-structured for machine parsing? `/spec` to decide. |
| 3 | For skills that don't produce a markdown artifact (e.g., `/diagram` writes SVG, `/mac-health` is read-only), where does the Open Questions block live? Sidecar `<output>.open-questions.md`? Stderr only? `/spec` to decide. |
| 4 | Subagent propagation: should the parent's mode be passed via prompt prefix, an explicit argument, or a shared scratch file? `/spec` to decide. |
| 5 | Should the existing `_shared/pipeline-setup.md` get a new Section E "Mode resolution" that all skills inline in Phase 0 (mirroring how Section 0 is inlined today)? Strong implementation lean toward yes; confirm in `/spec`. |
| 6 | Telemetry: do we track per-checkpoint auto-pick / defer rates anywhere today? If not, how do we measure the "≥70% auto-resolution rate" goal? Maybe a learnings-style append to `~/.pmos/non-interactive-stats.jsonl`. |
| 7 | Should the artifact's `## Open Questions` block be merged with each skill's existing tier-template `## Open Questions` section (where one already exists) or kept as a separate block (e.g., `## Open Questions (Non-Interactive Run)`)? Lean: separate block, to distinguish "I asked the human and they didn't know" from "I auto-deferred." Confirm in `/spec`. |

## Review Log

| Loop | Findings | Changes Made |
|------|----------|-------------|
| 1 | F1 audit-prereq gap; F2 metric/D7 conflict; F3 generic-orchestrator subagent edge case; F4 minimalist alt not surfaced | Added Goal + Solution Direction §8 + new Success Metric for the audit prereq; reworded cross-skill-coverage metric; added Edge Case row for non-pmos orchestrator; added "Rejected Alternatives" subsection covering log-and-warn-only, ad-hoc per-skill flags, and tiered destructive flag |

---

**For UX friction analysis, run `/msf-req` after this doc is committed.**
**For optional alternative-angle ideation, run `/creativity`.**
**When ready: `/spec`.**
