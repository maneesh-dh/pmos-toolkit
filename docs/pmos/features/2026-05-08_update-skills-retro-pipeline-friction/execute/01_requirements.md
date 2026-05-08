# /execute: --no-halt flag + resume-report log tail (E1+E2) — Requirements

**Date:** 2026-05-08
**Last updated:** 2026-05-08
**Status:** Draft
**Tier:** 3 — Feature (user-bumped from Tier 2; collapsed pipeline per /update-skills sub-run)

## Problem

Two friction points in `/execute`:

1. **E1 (friction):** Phase 2.5 hard-stops on every green phase boundary with `HALT_FOR_COMPACT`. The handshake is valuable for fresh sessions where context is full, but it forces a manual `/compact` + re-invoke at every boundary even when the user has explicitly said "keep going". In one retro session, the user typed "Continue without compacting" mid-Phase 3 and the running skill couldn't honor it — every subsequent phase boundary still emitted HALT.
2. **E2 (friction):** When resuming mid-task after an interruption, Phase 0.5's Resume Report names the resume task but doesn't show the in-flight task's last thinking trace. The resuming agent has to re-derive context (mid-test? about to write fixtures?) by greping git log + per-task log inspection. Costs context and time.

### Who experiences this?

Maintainers running long-running multi-phase plans via `/execute` — particularly anyone with plans that span ≥3 phases (the HALT cadence becomes a tax) or anyone resuming after a session crash / context interruption.

### Why now?

The retro paste-back in 2026-05-08 explicitly named both as workflow friction across 6 invocations of `/execute`. The HALT issue burns tokens at every boundary; the resume-trace issue burns time on every interrupted resume.

## Goals & Non-Goals

### Goals
- E1.1: `/execute` accepts a `--no-halt` CLI flag that suppresses Phase 2.5 HALT_FOR_COMPACT emission for the entire run; phase boundaries still run /verify and write phase-N.md, but do not pause for a manual /compact. Measured by: argument-hint includes `--no-halt`; Phase 2.5 step 5 prose explicitly checks the flag.
- E1.2: When the user emits an unambiguous continuation directive mid-run (literal token `[continue_through_phases]` OR plain-language "continue without compacting" / "no halts" / "skip compacts"), the executing agent treats the rest of the session as `--no-halt`. Measured by: Phase 2.5 step 5 names a "session-sticky honor" rule that lists the recognized directives.
- E1.3: Default behavior is unchanged when neither the flag nor a directive is present — HALT_FOR_COMPACT still fires on green at every phase boundary. Measured by: a SKILL.md run without the flag produces a HALT message identical to the current contract.
- E2.1: When Phase 0.5's Resume Report classifies a task as `in-flight` or `in-flight-with-commits`, the report appends the last 5 lines of that task's `task-NN.md` body section beneath the table. Measured by: Resume Report rendering template in `_shared/execute-resume.md` shows a "Last 5 lines from in-flight task body" section header with example content.
- E2.2: When no task is in-flight (clean fresh-start or all-done resume), the tail section is omitted entirely. Measured by: rendering template notes "omit when no in-flight tasks" rule.

### Non-Goals
- NOT auto-compacting on the user's behalf — because /compact is a Claude Code harness primitive that the agent doesn't drive; the flag only suppresses the prompt to compact, not the act of compacting.
- NOT tracking the `continue_through_phases` flag durably (e.g., in a settings file or session state file) — because a "session-sticky" semantic naturally lives in the conversation's running state; persisting across sessions would re-introduce the friction on the next run.
- NOT extending the resume tail to non-in-flight states — because `done`, `done-sealed`, `done-but-drifted`, and `not-started` either don't have unfinished thinking to replay, or have thinking that's already settled.
- NOT renaming `HALT_FOR_COMPACT` or restructuring Phase 2.5 — the change is purely opt-out semantics on top of the existing message.

## Solution Direction

In `execute/SKILL.md`:
1. Extend `argument-hint` frontmatter with `--no-halt`.
2. Phase 2.5 step 5 gets a precondition block: emit HALT only when `--no-halt` is NOT set AND the session-sticky `continue_through_phases` flag is NOT set. The block enumerates the recognized continuation directives.
3. A short Phase 2.5 prose addition documents the session-sticky escape hatch and how the executing agent recognizes it.

In `_shared/execute-resume.md`:
1. The "Resume Report Rendering" template gains a "Last 5 lines from in-flight task body" optional section, rendered ONLY when at least one task in the report is in-flight (or in-flight-with-commits).
2. The protocol prose explains how to compute the tail (read the body section after the YAML frontmatter terminator; take the last 5 non-blank lines; render under a sub-heading).

No new phases, no new reference files, no signature changes to existing functions in the resolver protocol.

## User Journeys

### Primary Journey 1 (E1 — opt-out via flag)
1. User invokes `/execute path/to/plan.md --no-halt`.
2. /execute runs T1, T2, ... TN as today.
3. At each phase boundary, /verify runs (with `--scope phase`); on green, phase-N.md is written.
4. Skill does NOT emit HALT_FOR_COMPACT; logs a one-line summary "Phase N verified green; --no-halt set, continuing to Phase N+1" and proceeds.

### Primary Journey 2 (E1 — opt-out via mid-run directive)
1. User invokes `/execute path/to/plan.md` (no flag).
2. After Phase 1 boundary HALT, user re-invokes with `--resume` and types: `Continue without compacting through the rest of the run.`
3. The executing agent, on encountering the directive in the user message, sets the session-sticky `continue_through_phases` flag.
4. Phase 2 boundary fires: /verify runs, phase log written, HALT suppressed; one-line summary emitted.
5. Phases 3+ proceed without HALT.

### Primary Journey 3 (E2 — resume with in-flight)
1. Session crashes mid-T17. T17's task log has `status: in-flight`, `started_at` set, no `completed_at`. The body has accumulated lines from the agent's mid-task work (e.g., "Wrote failing test for FR-22; about to inject fixtures into test_orders.py").
2. User runs `/execute path/to/plan.md --resume` in a new session.
3. Phase 0.5 classifies T17 as `in-flight`. Resume Report renders the table.
4. Below the table, the report renders:
   ```
   **Last 5 lines from T17 in-flight body:**
   - Wrote failing test for FR-22 (test_orders.py::test_partial_refund)
   - Confirmed test fails with current orders.py implementation
   - Reading checkout flow to find the right injection point
   - About to wire fixtures via tests/fixtures/orders.json
   - DEVIATION: plan assumes orders.fee_cents; actual model has fee_amount (decimal)
   ```
5. The agent now has the recent context to continue without re-deriving from git log.

### Self-grill (Tier 3 deviation: full /grill skipped per /update-skills sub-pipeline budget)

- **Q1: How does the agent distinguish "continue without compacting" as an imperative directive from "we should add no halts to the design" as descriptive prose?** A: The agent applies judgment in context — directives are typically standalone messages or imperative-mood sentences addressed to the running skill; descriptive uses appear inside larger prose. When ambiguous, the agent confirms via a single `AskUserQuestion` rather than silently flipping the session flag.
- **Q2: Does either opt-out persist across `/execute` invocations (e.g., into a `--resume` after compact)?** A: No. `--no-halt` is per-invocation (must be re-passed); the session-sticky directive is per-session (resets when the conversation ends). Both must be re-asserted on each fresh /execute run.
- **Q3: What if the resume tail's last 5 lines contain a `DEVIATION:` line that's been resolved in a subsequent body line — do we still surface the stale deviation?** A: Yes. The tail is a literal trace, not a summary. If the resolution is in the trace's last 5 lines, the agent sees both. If it's earlier, the agent reads the full body when deciding how to proceed; the tail is a prompt, not a substitute.

### Edge Cases
- **`--no-halt` set AND mid-run user directive ALSO present:** flag wins; the directive is a no-op (already in effect). No special handling needed.
- **Phase verify failed under `--no-halt`:** halt regardless. The flag suppresses the compact prompt on green only; failure escalation is unaffected.
- **Resume Report tail for an in-flight task whose body is empty:** render the section header with `(no body content recorded)` placeholder; don't omit the header if the task is in-flight.
- **Multiple in-flight tasks (rare but possible if multiple sessions crashed):** render one tail block per in-flight task, in T# order.
- **Body section longer than 5 lines but with leading/trailing blank lines:** strip blanks, then take the last 5. If fewer than 5 non-blank lines exist, render whatever exists.

## Design Decisions

| # | Decision | Options Considered | Rationale |
|---|----------|-------------------|-----------|
| D1 | Flag name: `--no-halt` (not `--continue-through-phases` or `--no-compact-handshake`) | (a) `--no-halt`, (b) `--continue-through-phases`, (c) `--no-compact`, (d) `--skip-handshake` | (a) — shortest, names the actual user-visible behavior (no halts at phase boundaries); other forms either describe internal state (b, d) or imply we're disabling /compact itself (c) which is wrong |
| D2 | Session-sticky directive is recognized via plain-language patterns AND a literal escape token | (a) Token only `[continue_through_phases]`, (b) plain-language only, (c) both | (c) — token gives an unambiguous machine-readable signal for power users; plain-language patterns ("continue without compacting", "no halts", "skip compacts") cover the natural-language case from the retro |
| D3 | Tail length is exactly 5 lines | (a) 3, (b) 5, (c) 10, (d) configurable | (b) — retro called for 5 explicitly; 3 is too thin, 10 floods the report when not needed; configurable adds surface area without need |
| D4 | Tail rendered as bullet list, not code-fenced block | (a) Bullet list, (b) ```` ``` ```` block, (c) blockquote | (a) — bullets render predictably across markdown viewers; code-fence implies the lines are commands or code, which they aren't (they're prose); blockquote weakens scanability |
| D5 | Tail extracted from the body section AFTER the frontmatter `---` terminator | (a) Whole file last-5, (b) body-only last-5 | (b) — the frontmatter is structured metadata, not thinking; including it in the tail would surface YAML keys (`status: in-flight`) instead of the actual trace |
| D6 | Failed-verify still halts even under `--no-halt` | (a) Always halt on failure, (b) flag suppresses both | (a) — `--no-halt` is opt-out for the GREEN-path compact prompt; failure escalation is a different code path that exists to protect the user from advancing on a broken contract |

## Acceptance Criteria

- [ ] AC1 (E1.1) — `argument-hint` frontmatter in `execute/SKILL.md` includes `--no-halt`.
- [ ] AC2 (E1.1) — Phase 2.5 step 5 prose names the `--no-halt` flag and describes its effect (suppress HALT_FOR_COMPACT emission on green; continue to next phase).
- [ ] AC3 (E1.2) — Phase 2.5 step 5 prose names the session-sticky `continue_through_phases` flag and lists the recognized directives (literal `[continue_through_phases]` token + plain-language patterns "continue without compacting", "no halts", "skip compacts" — case-insensitive match).
- [ ] AC4 (E1.3) — When neither the flag nor the directive is set, Phase 2.5 emits HALT_FOR_COMPACT identically to today (the original message text is preserved verbatim).
- [ ] AC5 (E2.1) — `_shared/execute-resume.md` "Resume Report Rendering" template includes a "Last 5 lines from in-flight task body" section under the report table, rendered as a bullet list, with example content.
- [ ] AC6 (E2.1) — Protocol prose explains: extract tail from body section AFTER `---` frontmatter terminator, strip leading/trailing blanks, take the last 5 non-blank lines, render as bullets under a sub-heading naming the task ID.
- [ ] AC7 (E2.2) — Rendering rule explicitly says: omit the tail section entirely when no task is in-flight.
- [ ] AC8 — Failed-verify behavior at phase boundaries is unchanged: regardless of `--no-halt` or the session flag, a failed verify escalates and writes `verify_status: failed`.
- [ ] AC9 — Phase numbering, function signatures in the resolver pseudocode, the AskUserQuestion option list, and the destructive-confirmation requirement at lines 184–190 of `_shared/execute-resume.md` are unchanged.

## Open Questions

_(none — D1–D6 cover the open design choices)_
