# `state.yaml` schema (`/feature-sdlc`)

Single source of truth for the resumable pipeline state file written at `<worktree>/.pmos/feature-sdlc/state.yaml`. SKILL.md prose cites this document rather than redeclaring fields. Companion: `pipeline-status-template.md` (the rendered Markdown view of this same data).

---

## schema_version

`schema_version: 1` is mandatory at the top of every `state.yaml`.

**Migration policy** (per FR-SCHEMA / spec §15 G3):

- `state.schema_version > current code's max supported` → abort with: `state file from newer /feature-sdlc version (vN); upgrade pmos-toolkit and retry`.
- `state.schema_version < current code's max` → auto-migrate by default-filling additive fields; log every migration to chat as `migration: state.schema vM → vN (added: <fields>)`.
- Same version → no migration.

Pipeline runs are short-lived (days, not years) so destructive migrations are not anticipated; if ever needed, bump the major schema number and refuse-not-migrate from that boundary.

---

## Top-level fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `schema_version` | int | yes | Always 1 in v1. |
| `slug` | string | yes | LLM-derived kebab-case identifier (per `slug-derivation.md`). |
| `tier` | int (1\|2\|3) \| null | yes | Set when known (either `--tier` flag or after `/requirements` Phase 3 auto-tier). `null` until then. |
| `mode` | string | yes | `interactive` or `non-interactive`. Resolved per the canonical non-interactive block at Phase 0. |
| `started_at` | string (ISO-8601) | yes | First creation timestamp. Never updated. |
| `last_updated` | string (ISO-8601) | yes | Updated on every status change. |
| `current_phase` | string | yes | The phase id currently being executed or the most recent paused/failed one. Matches one of the `phases[].id` values below. |
| `worktree_path` | string (abs path) \| null | yes | Absolute path of the worktree directory. `null` only when `--no-worktree` was passed. |
| `branch` | string \| null | yes | Branch name (typically `feat/<slug>`). `null` only when `--no-worktree`. |
| `feature_folder` | string (abs path) | yes | Resolved per `_shared/pipeline-setup.md` Section A — `<docs_path>/features/<YYYY-MM-DD>_<slug>/`. Child skills' artifacts land here. |
| `phases` | list | yes | One entry per pipeline phase, in declared order. See below. |
| `open_questions_log` | list | yes | Initialized `[]`. Appended to in `--non-interactive` mode after each child phase. See entry shape below. |

---

## `phases[]` entries

Every entry has at minimum:

| Field | Type | Description |
|-------|------|-------------|
| `id` | string | Phase identifier — one of the values listed under "Phase identifiers + hardness" below. |
| `hardness` | string | `hard`, `soft`, or `infra`. Drives failure-dialog construction (see `failure-dialog.md`). |
| `status` | string | One of the values listed under "Status enum" below. |
| `artifact_path` | string (rel path) \| null | Path of the canonical artifact this phase produced (relative to `feature_folder`). `null` when no artifact (e.g., phase `setup`, phase `compact-checkpoint`). |
| `started_at` | string (ISO-8601) \| null | When `status` first became `in_progress`. |
| `completed_at` | string (ISO-8601) \| null | When `status` became `completed`. |
| `paused_at` | string (ISO-8601) \| null | When `status` became `paused` (per FR-PAUSE / spec §15 G1). |
| `paused_reason` | string \| null | Why paused. See enum below. |
| `last_error` | string \| null | One-line error captured on failure-pause. |
| `child_tier` | int \| null | Child-skill auto-tier when it differs from the orchestrator tier (per spec §15 G8). |
| `child_tier_divergence` | string \| null | Free-form note when child reports a different tier. |
| `missing_skill` | string \| null | Set when `paused_reason: missing_skill` — names the missing child skill. |

### Phase identifiers + hardness

In declared execution order (matches spec §5):

- `setup` — **infra** (always run; no failure dialog beyond pipeline-setup's own).
- `worktree` — **infra** (worktree creation; G7 dialog handled inline).
- `init-state` — **infra** (write state.yaml + 00_pipeline.md).
- `requirements` — **hard** (Skip option HIDDEN in failure dialog).
- `grill` — **soft** (Skip option SHOWN; also auto-skipped in `--non-interactive` per FR-TIER-SCOPE / spec §15 G8).
- `msf-req` — **soft**.
- `creativity` — **soft**.
- `wireframes` — **soft**.
- `prototype` — **soft**.
- `spec` — **hard**.
- `simulate-spec` — **soft**.
- `plan` — **hard**.
- `execute` — **hard**.
- `verify` — **hard**.
- `complete-dev` — **hard**.
- `final-summary` — **infra**.
- `capture-learnings` — **infra**.

The compact checkpoint (`compact-checkpoint.md`) is a recurring micro-phase, not a `phases[]` entry — it is invoked before phases `wireframes`, `prototype`, `simulate-spec`, `execute`, `verify` and writes its pause record into the *next* phase's entry (see `compact-checkpoint.md`).

### Status enum

- `pending` — declared but not started.
- `in_progress` — currently executing.
- `completed` — finished cleanly (child skill returned success).
- `paused` — exited cleanly mid-phase per FR-PAUSE; resumable via `--resume`.
- `failed` — errored; failure dialog will be re-presented on `--resume`.
- `skipped` — user picked Skip at the gate (soft phases only) or `--non-interactive` auto-recommendation chose Skip.
- `skipped-on-failure` — user picked Skip in the failure dialog after an error (soft phases only).
- `skipped-non-interactive` — explicit auto-skip in non-interactive mode (`grill` when `mode == non-interactive`).
- `skipped-unavailable` — child skill not installed and user (or `--non-interactive` auto-pick) chose Skip in the missing-skill dialog (soft phases only).

### `paused_reason` enum

- `compact` — user chose Pause-resumable at a compact checkpoint.
- `failure` — user chose Pause-resumable in a failure dialog.
- `user` — user chose Pause-resumable outside a dialog (e.g., interrupted between phases).
- `missing_skill` — user chose Pause-to-install in the missing-skill dialog (per FR-MISSING-SKILL / spec §15 G10). `missing_skill` field captures the child skill name.

---

## `open_questions_log[]` entry shape

Per FR-OQ-INDEX / spec §15 G4. Append-only; written after each `--non-interactive` child phase that flushed deferred questions.

```yaml
- phase: <phase id>
  child_skill: <e.g., requirements, spec, plan>
  oq_artifact_path: <relative path under feature_folder, e.g., 01_requirements.md or _open_questions.md>
  deferred_count: <int, count of DEFER classifications by the child>
  ts: <ISO-8601 when the entry was appended>
```

At end-of-run AND end-of-pause, `/feature-sdlc` writes `<feature_folder>/00_open_questions_index.md` summarizing every entry in this log with links to each child's OQ artifact.

---

## Worked example (Tier-3 mid-pipeline pause)

Captures every field for an `--resume`-ready pause. The pipeline ran cleanly through `requirements` and `grill`, paused at the compact checkpoint before `wireframes`.

```yaml
schema_version: 1
slug: oauth-refresh-tokens
tier: 3
mode: interactive
started_at: 2026-05-09T14:22:11Z
last_updated: 2026-05-09T14:48:32Z
current_phase: wireframes
worktree_path: /Users/example/code/myrepo-oauth-refresh-tokens
branch: feat/oauth-refresh-tokens
feature_folder: /Users/example/code/myrepo-oauth-refresh-tokens/docs/pmos/features/2026-05-09_oauth-refresh-tokens
phases:
  - id: setup
    hardness: infra
    status: completed
    artifact_path: null
    started_at: 2026-05-09T14:22:11Z
    completed_at: 2026-05-09T14:22:14Z
  - id: worktree
    hardness: infra
    status: completed
    artifact_path: null
    started_at: 2026-05-09T14:22:14Z
    completed_at: 2026-05-09T14:22:31Z
  - id: init-state
    hardness: infra
    status: completed
    artifact_path: 00_pipeline.md
    started_at: 2026-05-09T14:22:31Z
    completed_at: 2026-05-09T14:22:32Z
  - id: requirements
    hardness: hard
    status: completed
    artifact_path: 01_requirements.md
    started_at: 2026-05-09T14:22:32Z
    completed_at: 2026-05-09T14:35:04Z
  - id: grill
    hardness: soft
    status: completed
    artifact_path: grills/2026-05-09_01_requirements.md
    started_at: 2026-05-09T14:35:04Z
    completed_at: 2026-05-09T14:42:18Z
  - id: msf-req
    hardness: soft
    status: skipped
    artifact_path: null
  - id: creativity
    hardness: soft
    status: skipped
    artifact_path: null
  - id: wireframes
    hardness: soft
    status: paused
    artifact_path: null
    started_at: 2026-05-09T14:48:30Z
    paused_at: 2026-05-09T14:48:32Z
    paused_reason: compact
    last_error: null
  - id: prototype
    hardness: soft
    status: pending
  - id: spec
    hardness: hard
    status: pending
  - id: simulate-spec
    hardness: soft
    status: pending
  - id: plan
    hardness: hard
    status: pending
  - id: execute
    hardness: hard
    status: pending
  - id: verify
    hardness: hard
    status: pending
  - id: complete-dev
    hardness: hard
    status: pending
  - id: final-summary
    hardness: infra
    status: pending
  - id: capture-learnings
    hardness: infra
    status: pending
open_questions_log: []
```
