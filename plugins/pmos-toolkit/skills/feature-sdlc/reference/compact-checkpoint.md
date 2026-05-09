# Compact checkpoint + Pause-resumable contract (`/feature-sdlc`)

`/feature-sdlc` cannot directly trigger `/compact` — that's a harness limitation; only the user can. So before each context-heavy phase, the skill surfaces a checkpoint via `AskUserQuestion`. If the user picks Pause, the skill exits cleanly and the user runs `/compact` and re-invokes the skill with `--resume`.

The exit contract is precise (per FR-PAUSE / spec §15 G1) — without that precision, resume can't be tested or trusted.

---

## When the checkpoint fires

Before each of these phases (per spec §5 Phase 2 trigger list):

- `wireframes` (Phase 4.c)
- `prototype` (Phase 4.d)
- `simulate-spec` (Phase 6)
- `execute` (Phase 8)
- `verify` (Phase 9)

Phases not listed here run without a checkpoint — their context cost is light enough that interrupting flow is the bigger cost.

---

## The `AskUserQuestion`

```
question: "About to enter <phase>. This phase is context-heavy. Compact your context window before continuing, continue without compacting, or pause to compact and resume later?"
options:
  - Continue (Recommended)
    description: Proceed with current context. Pick this if you compacted recently or you're confident the context window has headroom.
  - Pause to /compact, then resume
    description: I'll exit cleanly with state.yaml saved. You run /compact yourself, then re-invoke with --resume.
  - Continue without compacting
    description: Same as Continue — included for cases where the user explicitly wants to acknowledge they're not compacting.
```

Note: "Pause to /compact" is the only option that exits the skill. The other two continue execution.

This is **not** a Findings Presentation Protocol prompt — it's a single-turn structured ask with a clear `(Recommended)`. It does not need the protocol.

---

## Pause-resumable exit contract (FR-PAUSE)

When the user picks **Pause to /compact, then resume**, do exactly three things, in order:

### 1. Update `state.yaml`

In the `phases[]` entry for the phase about to start (the one the checkpoint precedes), set:

```yaml
- id: <phase>
  status: paused
  paused_at: <ISO-8601 now>
  paused_reason: compact
  last_error: null
```

Also update top-level `current_phase: <phase>` and `last_updated: <ISO-8601 now>`. Regenerate `00_pipeline.md` per `pipeline-status-template.md` "Update protocol".

### 2. Print the resume command to chat — verbatim

Emit exactly this line (substituting the worktree's absolute path and the phase id):

```
Paused at phase <phase-id>. To resume: cd <worktree-abs-path> && /pmos-toolkit:feature-sdlc --resume
```

The platform-aware variant of `/pmos-toolkit:feature-sdlc` comes from `_shared/platform-strings.md` (`execute_invocation`-style mapping). Use the platform-correct form.

### 3. Exit normally

- Exit code 0 (this is a clean pause, not an error).
- No thrown error or stack trace.
- No further phases run.

The next invocation of the skill (with `--resume`, or no-arg in a worktree containing a `paused` state.yaml) re-enters at Phase 0.b, surfaces the status table, and resumes from the paused phase. Resuming re-invokes the child skill from scratch — orchestrator state is phase-level only; child task-level resume is the child's responsibility (per spec §15 G2).

---

## Failure-pause variant

The same exit contract applies when the user picks `Pause-resumable` from a **failure dialog** (see `failure-dialog.md`), with two differences:

- `paused_reason: failure` (instead of `compact`).
- `last_error: <one-line summary>` populated from the failure that triggered the dialog.

Resume re-presents the failure dialog (Retry / [Skip on soft] / Pause-resumable / Abort) so the user can pick a different disposition.

---

## Anti-patterns

- **Don't auto-trigger /compact.** Skills cannot. Pretending otherwise breaks the resume contract — the next invocation finds inconsistent state.
- **Don't skip step 2.** The chat resume command is what makes the pause discoverable; without it the user doesn't know how to come back.
- **Don't write `paused_reason: compact` for every pause.** Failure-pauses use `failure`; user-initiated mid-phase pauses use `user`; missing-skill pauses use `missing_skill`. Drift here makes resume telemetry meaningless.
- **Don't update `state.yaml` and skip `00_pipeline.md`.** Both must agree at every read — atomic-write rule from `pipeline-status-template.md`.
