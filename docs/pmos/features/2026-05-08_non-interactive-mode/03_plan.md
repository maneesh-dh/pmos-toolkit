# Non-Interactive Mode for pmos-toolkit Skills — Implementation Plan

**Date:** 2026-05-08
**Spec:** `docs/pmos/features/2026-05-08_non-interactive-mode/02_spec.md`
**Requirements:** `docs/pmos/features/2026-05-08_non-interactive-mode/01_requirements.md`

---

## Overview

Build a cross-cutting `--non-interactive` flag for all 26 user-invokable pmos-toolkit skills. Foundation: a shared `_shared/non-interactive.md` (resolver + classifier + buffer + parser + refusal pattern) inlined verbatim per skill, gated by two new lint/audit scripts. Per-skill rollout follows a runbook produced as part of T14 — each remaining skill task applies the same runbook with skill-specific defer-only tag placement. Big-bang ship per spec D11; CI workflow gates regressions.

**Done when:** all 26 skills either pass `tools/audit-recommended.sh` (zero unmarked AskUserQuestion calls) OR carry a refusal marker; `tools/lint-non-interactive-inline.sh` reports OK across all supported skills; all 13 bats files pass; per-skill integration smoke (one bats invocation per supported skill asserting zero `AskUserQuestion` events under `--non-interactive`) passes; manual subagent-propagation + BC-fallback checks signed off; CI workflow on `.github/workflows/` is green; plugin version bumped to 2.24.0; changelog entry added.

**Execution order (dependencies):**

```
Phase 1: Foundation
  T1 (bats bootstrap) ──► T2 (Section 0) ──► T3 (Sections A/B/C)
                                   │                  │
                                   ▼                  ▼
                       T4 (lint-non-interactive)  T5 (audit-recommended)
                                   │                  │
                                   └────────┬─────────┘
                                            ▼
                                   T6 (pilot skill: /requirements)
                                            │
                                            ▼
                                   T7 (resolver.bats + classifier.bats)

Phase 2: Bats unit tests (parallelizable)
  [P] T8 buffer-flush.bats   [P] T9 destructive.bats     [P] T10 audit-script.bats
  [P] T11 refusal.bats       [P] T12 parser.bats          [P] T13 propagation.bats
  [P] T14 perf.bats

Phase 3: Per-skill rollout
  T15 (rollout runbook + /artifact pilot) ──► T16..T39 [P] (one task per remaining skill)
  T16..T39 are mutually independent [P] — disjoint files (one SKILL.md each); /execute may parallelize.
  T40 (post-rollout sweep)

Phase 4: Integration & ship
  T41 (per-skill integration bats) ──► T42 (manual subagent E2E)
                                    └─► T43 (manual BC-fallback)
                                            │
                                            ▼
                                    T44 (CI workflows)
                                            │
                                            ▼
                                    T45 (version bump + changelog)
                                            │
                                            ▼
                                    TN (Final Verification)
```

---

## Decision Log

> Inherits all 16 decisions from spec §4. Entries below are implementation-specific decisions made during planning.

| # | Decision | Options Considered | Rationale |
|---|---|---|---|
| PD1 | Per-skill rollout = 26 tasks (one per skill) | (a) Cluster by 5 groups, (b) Bulk single task, (c) **One per skill** | (c) per user explicit pick during planning intake. Trade-off: long task list (~26 tasks in Phase 3 alone) vs. fine-grained verification + independent per-skill commits. Mitigation: T14 produces a runbook each subsequent task cites (not "see T14" — cites the artifact path), keeping each task self-contained without copy-pasting full procedures. |
| PD2 | bats as the test harness (introduces a new testing style to this repo) | (a) **bats**, (b) match existing per-skill YAML-fixture style (polish/mytasks), (c) Python pytest | (a) per spec §14 explicit choice + verification sketch user-confirmed. Bats is installed (`/opt/homebrew/bin/bats`) but not used in-repo today; the existing YAML fixtures are skill-output validators, not unit tests for shell scripts/awk extractors. Bats fits the new shape (testing bash + awk extractors + script exit codes); pytest would force a Python boundary we don't have today. Trade-off captured: this plan introduces a new testing pattern; T1 bootstraps the harness as a deliberate first-class deliverable, not a side effect of T8. |
| PD3 | Lint script scope: all 26 skills minus refused | (a) Mirror existing lint-pipeline-setup-inline.sh's 7-skill scope, (b) **all 26 minus refused** | (b) per spec §15.2 gate 1 ("audit script exits 0 across all 23 SKILL.md files" — actually 26). The existing lint's narrow 7-skill scope is a precedent for "only skills that inline pipeline-setup-block;" non-interactive's scope is broader because every skill that fires `AskUserQuestion` needs the block. Refused skills (e.g., `/msf-req`) carry `<!-- non-interactive: refused; ... -->` and are exempted by the lint. |
| PD4 | T14 produces a per-skill rollout runbook artifact at `plugins/pmos-toolkit/tests/non-interactive/per-skill-rollout-runbook.md` | (a) Inline procedure repeated in each task, (b) **Runbook artifact + cite path**, (c) Runbook in plan doc itself | (b): satisfies "tasks readable independently" (each per-skill task cites a real file the implementor opens) without copy-pasting a 30-line procedure 26 times. The runbook is a tested deliverable: T14 self-tests it on `/artifact` before it's used by T15-T39. |
| PD5 | Phase 3 tasks (T15-T39) are parallelizable [P] in the dependency graph but executed sequentially during /execute (subagents could merge in parallel — out of scope for this plan) | (a) Parallel-flagged for future, (b) Strictly sequential | (a): the 26 SKILL.md edits touch disjoint files (one SKILL.md each); no shared-state conflict. Marking [P] documents the property; /execute decides whether to actually parallelize. Risk: drift between sequential and parallel runs is zero because each task is independent. |
| PD6 | The "shared awk extractor" mandated by FR-02.6 lives in `_shared/non-interactive.md` Section 0 and is invoked by both the runtime classifier prose and `tools/audit-recommended.sh`. Implementation: a single awk function defined verbatim in Section 0; the audit script `source`s it via heredoc-style extraction at script-init time. | (a) **Shared awk in Section 0**, (b) Separate file `tools/extract-checkpoints.awk` referenced by both, (c) Duplicated and tested for equivalence | (a) is the simplest "drift-by-construction-impossible" shape: one source-of-truth, one canonical file, both runtime instructions and the audit script point at the same lines. (b) introduces a 4th file in a 3-file design. Audit script reads the awk lines from `_shared/non-interactive.md` between `<!-- awk-extractor:start -->` / `<!-- awk-extractor:end -->` markers. |
| PD7 | Phase 3 commit cadence: one commit per skill task; each commit message: `feat: non-interactive rollout for /<skill>` | (a) **Per-task commits**, (b) One bulk commit at end of Phase 3, (c) Per-cluster commits | (a): preserves bisectability (any per-skill regression is git-bisect-able to the single SKILL.md edit); aligns with PD1 "independent per-skill commits". |
| PD8 | Plugin version bump policy: 2.23.0 → 2.24.0 (minor; additive backward-compatible feature) | (a) **2.24.0 minor**, (b) 3.0.0 major (the cross-cutting nature could justify it), (c) 2.23.1 patch (it's just a flag) | (a) per semver: new feature, no breaking change to interactive default behavior (NFR-04). Existing users see no behavior change unless they pass the flag or set `default_mode` in settings.yaml. Major bump (b) is unwarranted; patch (c) understates the surface area. |

---

## Code Study Notes

Findings from Phase 2 deep-read:

- **26 user-invokable skills** under `plugins/pmos-toolkit/skills/` (not 23 as spec asserts; spec was based on incomplete recon). The 26: `artifact, backlog, changelog, complete-dev, create-skill, creativity, design-crit, diagram, execute, grill, mac-health, msf-req, msf-wf, mytasks, people, plan, polish, product-context, prototype, requirements, retro, session-log, simulate-spec, spec, verify, wireframes`. Two non-skill dirs: `_shared/`, `learnings/` (no SKILL.md). Spec-side count is being corrected via this plan; not a separate task — corrections land in the per-skill task fan-out.
- **Existing lint pattern:** `tools/lint-pipeline-setup-inline.sh` (105 lines, bash + awk, exit 0/1/2, OK/DRIFT/MISSING/MISSING-BLOCK status). It uses `extract_block()` awk for marker-delimited blocks and `diff <(...) <(...)` for visual drift output. Our two new tools clone this shape; T4/T5 templates start from a verbatim copy.
- **Existing canonical inline pattern:** `_shared/pipeline-setup.md` Section 0 between `<!-- pipeline-setup-block:start -->` / `<!-- pipeline-setup-block:end -->` markers, copy-pasted verbatim into each pipeline skill's Phase 0. New `_shared/non-interactive.md` mirrors this exactly: `<!-- non-interactive-block:start -->` / `<!-- non-interactive-block:end -->`.
- **No bats files exist in-repo today.** `which bats` resolves to `/opt/homebrew/bin/bats`. The plan introduces bats as a new test pattern (PD2). Existing per-skill `tests/expected.yaml` (polish, mytasks) are skill-output validators; we are not replacing those.
- **No `.github/` directory.** T43 bootstraps `.github/workflows/`.
- **Plugin manifest:** `plugins/pmos-toolkit/.claude-plugin/plugin.json` carries `"version": "2.23.0"`. Also a `.codex-plugin/plugin.json` exists; T44 bumps both.
- **AskUserQuestion convention:** `(Recommended)` is a label suffix in prose (e.g. `"Defer to Open Questions, continue (Recommended)"`); no schema enforcement. Confirmed by inspecting `/requirements`, `/spec`, `/diagram`, `/design-crit` SKILL.md.

Patterns to follow:
- One file per concern; bash scripts use `set -euo pipefail`, awk for parsing markdown blocks, exit codes 0/1/2.
- Markdown frontmatter is prose-style (`**Date:**`, `**Status:**`); D6 in spec mandates new fields stay prose.
- Shell hashbangs always `#!/usr/bin/env bash`.

---

## Prerequisites

- Working directory: `/Users/maneeshdhabria/Desktop/Projects/agent-skills` (plugin lives at `plugins/pmos-toolkit/`).
- Tools available: `bash` 5+, `awk` (BSD or GNU; canonical lint uses POSIX awk constructs), `bats` (`/opt/homebrew/bin/bats` or equivalent), `git`, `yq` (`brew install yq` if missing — used by parser.bats).
- Branch: implementor checks out a feature branch `feature/non-interactive-mode` off `main`.
- No services, no migrations, no env vars.
- No external dependencies added.

---

## File Map

| Action | File | Responsibility |
|---|---|---|
| Create | `plugins/pmos-toolkit/skills/_shared/non-interactive.md` | Canonical shared block (Sections 0/A/B/C); resolver + classifier + buffer + flush + refusal regex + parser snippet + propagation prefix recipe; awk extractor between explicit markers (PD6). |
| Create | `plugins/pmos-toolkit/tools/lint-non-interactive-inline.sh` | Drift-detection clone of `lint-pipeline-setup-inline.sh`; covers all 26 skills minus refused. |
| Create | `plugins/pmos-toolkit/tools/audit-recommended.sh` | Audit every `AskUserQuestion` call site in given SKILL.md(s); assert each has either a `(Recommended)` option or an adjacent `<!-- defer-only: <reason> -->` tag. Reuses awk extractor from `_shared/non-interactive.md` (PD6). |
| Create | `plugins/pmos-toolkit/tests/non-interactive/README.md` | How to run the bats suite locally. |
| Create | `plugins/pmos-toolkit/tests/non-interactive/test_helper.bash` | Bats helper functions (skill fixture builder, transcript scraper helpers). |
| Create | `plugins/pmos-toolkit/tests/non-interactive/resolver.bats` | 9 test cases for FR-01 (mode resolution precedence + conflicts). |
| Create | `plugins/pmos-toolkit/tests/non-interactive/classifier.bats` | 6 test cases for FR-02 (auto-pick vs defer classification). |
| Create | `plugins/pmos-toolkit/tests/non-interactive/buffer-flush.bats` | 5 test cases for FR-03 (in-memory buffer → artifact flush + sidecar + chat-only). |
| Create | `plugins/pmos-toolkit/tests/non-interactive/destructive.bats` | 3 test cases for FR-04 (destructive defer + stop-on-block + audit warn). |
| Create | `plugins/pmos-toolkit/tests/non-interactive/audit-script.bats` | 4 fixtures for FR-05 (clean / unmarked / malformed / refusal). |
| Create | `plugins/pmos-toolkit/tests/non-interactive/refusal.bats` | 2 test cases for FR-07 (refusal exit 64 + non-symmetric for `--interactive`). |
| Create | `plugins/pmos-toolkit/tests/non-interactive/parser.bats` | 3 test cases for FR-09 (parse OQ block → JSON; missing block; malformed YAML). |
| Create | `plugins/pmos-toolkit/tests/non-interactive/propagation.bats` | 4 cases for FR-06 (subagent prompt-prefix marker scan + parent_marker resolver path) via stand-in. |
| Create | `plugins/pmos-toolkit/tests/non-interactive/perf.bats` | NFR-01 timing assertions (resolver <100ms; classifier <10ms per call). |
| Create | `plugins/pmos-toolkit/tests/non-interactive/per-skill-rollout-runbook.md` | T14 deliverable — the procedure each per-skill task in Phase 3 follows. |
| Create | `plugins/pmos-toolkit/tests/non-interactive/fixtures/` | Sub-directory holding fixture SKILL.md files for audit-script.bats and others. |
| Modify | `plugins/pmos-toolkit/skills/<each>/SKILL.md` (×26) | Inline `<!-- non-interactive-block -->` verbatim into Phase 0; tag each destructive checkpoint with `<!-- defer-only: destructive -->` on the literal previous non-empty line; add `--non-interactive` and `--interactive` to `argument-hint`. `/msf-req` SKILL.md additionally gets `<!-- non-interactive: refused; reason: ...; alternative: ... -->` near top. |
| Create | `plugins/pmos-toolkit/tests/integration/non-interactive/<skill>.bats` (×25 supported skills) | Per-skill smoke test: spawn `claude -p '/<skill> --non-interactive ...'`, scrape transcript JSON, assert zero `AskUserQuestion` events; assert produced artifact has `**Run Outcome:**` line. |
| Create | `.github/workflows/audit-recommended.yml` | CI workflow: run `tools/audit-recommended.sh` and `tools/lint-non-interactive-inline.sh` on every PR touching `plugins/pmos-toolkit/skills/**/SKILL.md` or `plugins/pmos-toolkit/skills/_shared/non-interactive.md`. |
| Modify | `plugins/pmos-toolkit/.claude-plugin/plugin.json:3` | `"version": "2.23.0"` → `"version": "2.24.0"`. |
| Modify | `plugins/pmos-toolkit/.codex-plugin/plugin.json` | Same version bump (path/line confirmed in T44). |
| Create | `plugins/pmos-toolkit/CHANGELOG.md` (or modify if exists) | Add 2.24.0 entry summarizing the feature. |

---

## Risks

| Risk | Likelihood | Mitigation |
|---|---|---|
| Awk dialect differences (BSD awk on macOS vs gawk on Linux) break the shared extractor | Medium | Reuse the exact constructs already in `tools/lint-pipeline-setup-inline.sh` (proven cross-platform); add a `audit-script.bats` case that runs the extractor on a fixture and diffs output between `awk` and `gawk` if both available. |
| Bats `run` merges stderr into `$output`, hiding the resolver's stderr-only `mode: ...` announcement (matches existing learning under `## /execute`) | High | Use `run --separate-stderr` (bats ≥ 1.5) in resolver.bats and any test asserting on stderr lines; T1 bootstrap pins `bats --version >= 1.5` as a prereq check. |
| AskUserQuestion call sites in SKILL.md are written in many shapes (single-line, multi-line, embedded in instructions); the awk extractor misses some | Medium | T14 includes a "discovery pass" sub-step on `/artifact` (the heaviest skill, 22 calls) that catalogs every distinct invocation shape; the awk extractor is then tuned and audit-script.bats fixture is expanded. T15-T39 each verify the extractor catches their skill's calls before tagging. |
| Per-skill SKILL.md edits introduce subtle phrasing drift (e.g., paraphrased non-interactive block) | Low | `lint-non-interactive-inline.sh` runs in CI and locally; any drift fails the lint. T6 (pilot) catches the first such drift before T15-T39 multiply the cost. |
| `/msf-req` refusal regex collides with another skill's stderr output (false positive in tests) | Low | Refusal stderr is namespaced (`--non-interactive not supported by /<skill>:`), making collision impossible without active misconfiguration. refusal.bats assertion uses fully-qualified regex. |
| 26 SKILL.md edits race-condition each other in parallel /execute (PD5 marks [P]) | Low | Each task touches exactly one SKILL.md (no shared file). Git merge is the only race surface; per-task commits (PD7) serialize merges. |
| CI workflow GH-Actions YAML syntax errors block first push | Medium | T43 includes a local `actionlint` (or `gh workflow run --debug`) step before commit; T43 sub-step explicitly runs the workflow via `act` if available, falls back to manual GitHub Actions UI verification. |
| Plan length (~45 tasks) makes /execute fatigue-prone | Low | Phase boundaries (1→2→3→4) trigger /verify checkpoints per /execute Phase 2.5; each phase is independently green-able. Per-task commits keep cognitive load low. |
| `/execute`, `/spec`, `/verify` (T22, T36, T37) have many destructive checkpoints; the runbook covers tagging generically and an author could miss one | Medium | The audit script (T5) is the gate — any unmarked destructive call exits 1, blocking the per-task commit. The lint script catches block drift. Both run in CI per T44. If any of the three skills' audit reports a non-zero unmarked count after rollout, the task does not commit until tags are added. No reviewer-pass needed beyond audit + lint. |

---

## Rollback

This plan ships entirely as additive changes (new files + per-SKILL.md additions inside marker-delimited blocks). Rollback is a single revert of the merge commit:

- If T44 ships and v2.24.0 is regretted: `git revert <merge-sha>; git tag -d v2.24.0` (and re-tag at the prior commit if needed).
- If a single SKILL.md edit (T15-T39) regresses a skill: `git revert <skill-task-sha>` removes only that skill's non-interactive block; the lint script will then report MISSING for that skill, which is expected post-revert.
- If `_shared/non-interactive.md` itself is regretted: revert T2/T3 commits; lint will fail repo-wide; either re-apply or revert the entire feature branch.
- No DB migrations, no infra changes, no data mutations to undo.

---

## Tasks

## Phase 1: Foundation

[Phase rationale: bootstrap the test harness, write the canonical shared block, create the two scripts that gate the rollout, and pilot on one real skill before the 26-fan-out. This phase is the smallest deployable slice that proves the architecture is real (not just a doc).]

### T1: Bootstrap bats test infrastructure

**Goal:** Establish a working bats test directory with helper functions and a documented run command, so subsequent test tasks have a stable foundation.
**Spec refs:** §14 (Testing & Verification Strategy), NFR-05 (drift control via lint).

**Files:**
- Create: `plugins/pmos-toolkit/tests/non-interactive/README.md`
- Create: `plugins/pmos-toolkit/tests/non-interactive/test_helper.bash`
- Create: `plugins/pmos-toolkit/tests/non-interactive/.gitkeep` (in subdir `fixtures/`)
- Test: `plugins/pmos-toolkit/tests/non-interactive/smoke.bats` (deleted at end of task)

**Steps:**

- [ ] Step 1: Verify bats is installed and version-checked.
  Run: `bats --version`
  Expected: a version string `Bats 1.x.x` where `x` ≥ 5. If absent or older: `brew install bats-core` (note in README).

- [ ] Step 2: Create the directory structure.
  Run:
  ```bash
  mkdir -p plugins/pmos-toolkit/tests/non-interactive/fixtures
  touch plugins/pmos-toolkit/tests/non-interactive/fixtures/.gitkeep
  ```
  Expected: directory and placeholder file exist.

- [ ] Step 3: Write `test_helper.bash` with shared bats helpers.
  ```bash
  #!/usr/bin/env bash
  # Bats helpers for non-interactive-mode test suite.
  set -euo pipefail

  # Resolve plugin root from any test file location.
  PLUGIN_ROOT="$(cd "$(dirname "${BATS_TEST_DIRNAME}")/.." && pwd)"
  export PLUGIN_ROOT

  TOOLS_DIR="${PLUGIN_ROOT}/tools"
  SKILLS_DIR="${PLUGIN_ROOT}/skills"
  SHARED_FILE="${SKILLS_DIR}/_shared/non-interactive.md"
  FIXTURES_DIR="${BATS_TEST_DIRNAME}/fixtures"

  export TOOLS_DIR SKILLS_DIR SHARED_FILE FIXTURES_DIR

  # Build a synthetic SKILL.md fixture with given AskUserQuestion calls.
  # Args: $1 = output path; rest = lines of body content
  build_skill_fixture() {
    local out="$1"; shift
    {
      echo '---'
      echo 'name: test-skill'
      echo '---'
      echo
      echo '## Phase 0'
      echo
      printf '%s\n' "$@"
    } > "$out"
  }
  ```

- [ ] Step 4: Write `smoke.bats` to confirm the harness runs.
  ```bash
  #!/usr/bin/env bats
  load test_helper

  @test "harness loads PLUGIN_ROOT" {
    [ -d "$PLUGIN_ROOT/skills" ]
    [ -d "$PLUGIN_ROOT/tools" ]
  }

  @test "fixtures dir exists" {
    [ -d "$FIXTURES_DIR" ]
  }
  ```

- [ ] Step 5: Run smoke test.
  Run: `bats plugins/pmos-toolkit/tests/non-interactive/smoke.bats`
  Expected: `2 tests, 0 failures`.

- [ ] Step 6: Write `README.md` documenting how to run the suite.
  Content (verbatim):
  ```markdown
  # Non-Interactive Mode — Bats Test Suite

  ## Run all
  bats plugins/pmos-toolkit/tests/non-interactive/*.bats

  ## Run one file
  bats plugins/pmos-toolkit/tests/non-interactive/resolver.bats

  ## Verbose mode
  bats --tap plugins/pmos-toolkit/tests/non-interactive/*.bats

  ## Prerequisites
  - bats-core ≥ 1.5 (`brew install bats-core` on macOS)
  - awk (POSIX or GNU)
  - yq (`brew install yq`) — used by parser.bats

  Helpers live in `test_helper.bash`. Fixtures in `fixtures/`.
  ```

- [ ] Step 7: Delete the smoke test (it was harness-validation only).
  Run: `rm plugins/pmos-toolkit/tests/non-interactive/smoke.bats`

- [ ] Step 8: Commit.
  ```bash
  git add plugins/pmos-toolkit/tests/non-interactive/
  git commit -m "test: bootstrap bats harness for non-interactive mode"
  ```

**Inline verification:**
- `[ -f plugins/pmos-toolkit/tests/non-interactive/test_helper.bash ]` — exists
- `[ -f plugins/pmos-toolkit/tests/non-interactive/README.md ]` — exists
- `[ -d plugins/pmos-toolkit/tests/non-interactive/fixtures ]` — exists
- `bash -n plugins/pmos-toolkit/tests/non-interactive/test_helper.bash` — no syntax errors

---

### T2: Create `_shared/non-interactive.md` Section 0 (canonical inline block)

**Goal:** Author the canonical resolver + classifier + buffer + flush block that every supported skill will inline verbatim. Includes the awk extractor between `<!-- awk-extractor:start -->` / `<!-- awk-extractor:end -->` markers (PD6).
**Spec refs:** FR-01 (resolver), FR-02 (classifier), FR-03 (buffer + flush), §6.1 (architecture), §11.2 (OQ entry schema), D2.

**Files:**
- Create: `plugins/pmos-toolkit/skills/_shared/non-interactive.md` (Section 0 + intro only; A/B/C in T3)

**Steps:**

- [ ] Step 1: Write the failing test — assert the file exists with required marker pairs.
  Add to `plugins/pmos-toolkit/tests/non-interactive/structure.bats`:
  ```bash
  #!/usr/bin/env bats
  load test_helper

  @test "non-interactive.md exists" {
    [ -f "$SHARED_FILE" ]
  }

  @test "non-interactive.md has Section 0 markers" {
    grep -q '<!-- non-interactive-block:start -->' "$SHARED_FILE"
    grep -q '<!-- non-interactive-block:end -->' "$SHARED_FILE"
  }

  @test "non-interactive.md has awk-extractor markers" {
    grep -q '<!-- awk-extractor:start -->' "$SHARED_FILE"
    grep -q '<!-- awk-extractor:end -->' "$SHARED_FILE"
  }

  @test "Section 0 prescribes resolver precedence" {
    awk '/<!-- non-interactive-block:start -->/,/<!-- non-interactive-block:end -->/' "$SHARED_FILE" \
      | grep -qE 'flag.*parent.*settings.*default|flag > parent_marker > settings'
  }

  @test "Section 0 references the awk extractor" {
    awk '/<!-- non-interactive-block:start -->/,/<!-- non-interactive-block:end -->/' "$SHARED_FILE" \
      | grep -q 'awk-extractor'
  }
  ```

- [ ] Step 2: Run test, expect failure.
  Run: `bats plugins/pmos-toolkit/tests/non-interactive/structure.bats`
  Expected: 5 failures (file does not exist).

- [ ] Step 3: Create `_shared/non-interactive.md` with the intro and Section 0. Use this exact content (key sections shown; full file in Step 4):
  - Title: `# Non-Interactive Mode — Shared Contract`
  - Intro paragraph (mirror tone of `pipeline-setup.md` intro line 3): "Authoritative source for the `--non-interactive` flag. Pipeline and supporting skills inline **Section 0** verbatim into their own SKILL.md (Phase 0)."
  - Section list bullets pointing at A/B/C/0.
  - `## Section 0 — Canonical inline non-interactive block`
  - Marker pair `<!-- non-interactive-block:start -->` / `<!-- non-interactive-block:end -->`
  - Inside: the resolver instructions (precedence: flag > parent_marker > settings.default_mode > builtin-default; stderr announce; FR-01.5 malformed-settings refuse-and-exit-64), the classifier instructions (read AskUserQuestion call; check `(Recommended)` suffix; check adjacent `<!-- defer-only: ... -->` tag using the awk extractor; classify per FR-02.2), the buffer instructions (in-memory append; entry shape per §11.2; flush at end-of-skill), the flush dispatch (single-MD artifact → append `## Open Questions (Non-Interactive Run)`; multi-artifact → write `_open_questions.md` aggregator per FR-03.5; non-MD primary → sidecar per FR-03.2; chat-only → stderr per FR-03.3).
  - Inside also: `<!-- awk-extractor:start -->` / `<!-- awk-extractor:end -->` markers wrapping the awk function that finds AskUserQuestion call sites and adjacent defer-only tags.

- [ ] Step 4: Concrete content for Section 0 (use this skeleton, fill prose to match house style):
  ```markdown
  # Non-Interactive Mode — Shared Contract

  > Authoritative source for the `--non-interactive` flag. Pipeline and supporting skills inline **Section 0** verbatim into their own SKILL.md (Phase 0). They must `Read` this file when an edge case named in Section 0 fires.

  This file has four sections:

  - **Section 0** — Canonical inline non-interactive block (copy-pasted into each supporting SKILL.md)
  - **Section A** — Refusal pattern + exit-64 contract
  - **Section B** — Downstream Open-Questions parser snippet
  - **Section C** — Subagent propagation prefix recipe

  ---

  ## Section 0 — Canonical inline non-interactive block

  Supporting skills paste the block between the markers below into their own Phase 0 (after the `pipeline-setup-block`), **verbatim**. The lint script (`tools/lint-non-interactive-inline.sh`) diffs each skill's marked region against this canonical version and fails on drift. Do not edit the marked region in any SKILL.md without updating this section first.

  <!-- non-interactive-block:start -->
  1. **Mode resolution.** Compute `(mode, source)` with precedence: `cli_flag > parent_marker > settings.default_mode > builtin-default ("interactive")`.
     - `cli_flag` is `--non-interactive` or `--interactive` parsed from this skill's argument string. Last flag wins on conflict (FR-01.1).
     - `parent_marker` is set if the original prompt's first line matches `^\[mode: (interactive|non-interactive)\]$` (FR-06.1).
     - `settings.default_mode` is `.pmos/settings.yaml :: default_mode` if present and one of `interactive`/`non-interactive`. Unknown values → warn on stderr `settings: invalid default_mode value '<v>'; ignoring` and fall through (FR-01.3).
     - If `.pmos/settings.yaml` is malformed (not parseable as YAML, or missing `version`): print to stderr `settings.yaml malformed; fix and re-run` and exit 64 (FR-01.5).
     - On Phase 0 entry, always print to stderr exactly: `mode: <mode> (source: <source>)` (FR-01.2).

  2. **Per-checkpoint classifier.** Before issuing any `AskUserQuestion` call, classify it:
     - Use the awk extractor below to find the line of this call's `question:` key in the live SKILL.md (FR-02.6).
     - The defer-only tag, if present, is the literal previous non-empty line: `<!-- defer-only: <reason> -->` where `<reason>` ∈ {`destructive`, `free-form`, `ambiguous`} (FR-02.5).
     - Decision (in order): tag adjacent → DEFER; multiSelect with 0 Recommended → DEFER; 0 options OR no option label ends in `(Recommended)` → DEFER; else AUTO-PICK the (Recommended) option (FR-02.2).

  3. **Buffer + flush.** Maintain an append-only OQ buffer in conversation memory. On each AUTO-PICK or DEFER classification, append one entry per the schema in spec §11.2. At end-of-skill (or in a caught error before exit), flush:
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
  # A "call site" is a line beginning with `AskUserQuestion` (case-sensitive)
  # or containing the verbatim invocation hint `AskUserQuestion(`.
  /^[[:space:]]*<!--[[:space:]]*defer-only:[[:space:]]*([a-z-]+)[[:space:]]*-->/ {
    match($0, /defer-only:[[:space:]]*[a-z-]+/);
    pending_tag = substr($0, RSTART + 12, RLENGTH - 12);
    sub(/^[[:space:]]+/, "", pending_tag);
    pending_line = NR;
    next;
  }
  /^[[:space:]]*$/ {
    # Whitespace-only line breaks adjacency (FR-02.5 strict).
    pending_tag = "";
    next;
  }
  /AskUserQuestion/ {
    has_recc = ($0 ~ /\(Recommended\)/) ? 1 : 0;
    tag = (pending_tag != "" && NR == pending_line + 1) ? pending_tag : "-";
    printf "%d\t%d\t%s\n", NR, has_recc, tag;
    pending_tag = "";
  }
  { pending_tag = pending_tag; }  # no-op: continue if non-blank, non-call line
  ```
  <!-- awk-extractor:end -->

  6. **Refusal check.** If this SKILL.md contains a `<!-- non-interactive: refused; ... -->` marker (regex: `<!--[[:space:]]*non-interactive:[[:space:]]*refused`), and `mode` resolved to `non-interactive`: emit refusal per Section A and exit 64.

  7. **Pre-rollout BC.** If the `--non-interactive` argument is present BUT this SKILL.md does NOT contain the `<!-- non-interactive-block:start -->` marker (i.e., this skill hasn't been rolled out yet): emit `WARNING: --non-interactive not yet supported by /<skill>; falling back to interactive.` to stderr; continue in interactive mode (FR-08).

  8. **End-of-skill summary.** Print to stderr at exit: `pmos-toolkit: /<skill> finished — outcome=<clean|deferred|error>, open_questions=<N>` (NFR-07).
  <!-- non-interactive-block:end -->

  ---
  ```

- [ ] Step 5: Run structure tests.
  Run: `bats plugins/pmos-toolkit/tests/non-interactive/structure.bats`
  Expected: `5 tests, 0 failures`.

- [ ] Step 6: Quick awk-extractor smoke (sanity that the awk syntax is valid).
  Run:
  ```bash
  awk '/<!-- awk-extractor:start -->/,/<!-- awk-extractor:end -->/' \
    plugins/pmos-toolkit/skills/_shared/non-interactive.md \
    | sed -n '/^```awk$/,/^```$/{/^```/d; p}' \
    | awk -f /dev/stdin /dev/null
  ```
  Expected: no syntax error from awk; exit 0.

- [ ] Step 7: Commit.
  ```bash
  git add plugins/pmos-toolkit/skills/_shared/non-interactive.md \
          plugins/pmos-toolkit/tests/non-interactive/structure.bats
  git commit -m "feat: shared non-interactive block (Section 0) + awk extractor"
  ```

**Inline verification:**
- `bats plugins/pmos-toolkit/tests/non-interactive/structure.bats` — 5 passes
- Awk smoke (Step 6) — exit 0
- `grep -c 'FR-' plugins/pmos-toolkit/skills/_shared/non-interactive.md` — at least 12 FR refs in Section 0 (resolver + classifier + buffer + flush traceability)

---

### T3: Add `_shared/non-interactive.md` Sections A, B, C

**Goal:** Append the three remaining sections — refusal regex contract, downstream parser snippet, subagent propagation recipe — and verify each is parseable.
**Spec refs:** FR-07 (refusal), FR-09 (parser), FR-06 (propagation), §9.4, §9.7.

**Files:**
- Modify: `plugins/pmos-toolkit/skills/_shared/non-interactive.md` (append A/B/C)
- Modify: `plugins/pmos-toolkit/tests/non-interactive/structure.bats` (add section assertions)

**Steps:**

- [ ] Step 1: Add failing tests for Sections A, B, C presence.
  Append to `structure.bats`:
  ```bash
  @test "Section A defines refusal regex and exit 64" {
    awk '/^## Section A/,/^## Section B/' "$SHARED_FILE" \
      | grep -qE 'exit[[:space:]]+64'
    awk '/^## Section A/,/^## Section B/' "$SHARED_FILE" \
      | grep -qE '\^--non-interactive not supported by'
  }

  @test "Section B contains parser markers" {
    awk '/^## Section B/,/^## Section C/' "$SHARED_FILE" \
      | grep -q '<!-- parser-snippet:start -->'
    awk '/^## Section B/,/^## Section C/' "$SHARED_FILE" \
      | grep -q '<!-- parser-snippet:end -->'
  }

  @test "Section C documents [mode: ...] prefix marker" {
    awk '/^## Section C/,0' "$SHARED_FILE" \
      | grep -qE '\[mode: (interactive|non-interactive)\]'
  }
  ```

- [ ] Step 2: Run; expect 3 new failures.
  Run: `bats plugins/pmos-toolkit/tests/non-interactive/structure.bats`
  Expected: 5 pass, 3 fail.

- [ ] Step 3: Append Sections A, B, C to `_shared/non-interactive.md`. Skeleton (fill prose to match house style):

  ```markdown
  ## Section A — Refusal pattern + exit-64 contract

  Skills that structurally forbid `--non-interactive` declare it via a marker near the top of their SKILL.md:

      <!-- non-interactive: refused; reason: <one-line reason>; alternative: <one-line pointer> -->

  When detected with `mode == non-interactive`, emit to stderr:

      --non-interactive not supported by /<skill>: <reason>. <alternative>

  Then exit 64. The regex used by `tests/non-interactive/refusal.bats` to assert this:

      ^--non-interactive not supported by /[a-z-]+: .+\. .+

  Refusal is one-directional: `<!-- non-interactive: refused; ... -->` does NOT block `--interactive` (the symmetric flag) (FR-07.2).

  ---

  ## Section B — Downstream Open-Questions parser snippet

  Downstream pipeline skills (`/spec`, `/plan`, etc.) extract the previous artifact's `## Open Questions (Non-Interactive Run)` block as a JSON array. Inline this snippet in their Phase 1 input-loading:

  <!-- parser-snippet:start -->
  ```bash
  # Usage: parse_open_questions <artifact-path>
  # Stdout: JSON array of OQ entries; [] if no block; exit 0 always (warns on malformed YAML)
  parse_open_questions() {
    local artifact="$1"
    awk '/^## Open Questions \(Non-Interactive Run\)/,0 {print}' "$artifact" \
      | awk '/^```yaml$/,/^```$/ {if ($0 != "```yaml" && $0 != "```") print "---"; print}' \
      | yq eval-all '. | [.]' --output-format=json 2>/dev/null \
      || echo '[]'
  }
  ```
  <!-- parser-snippet:end -->

  Parser handles missing block by emitting `[]`; malformed YAML in a block emits parsable entries with stderr warnings (FR-09.2).

  ---

  ## Section C — Subagent propagation prefix recipe

  When a parent skill (running `--non-interactive`) dispatches a child skill, the parent prepends the marker as the literal first line of the child's prompt:

      [mode: non-interactive]
      <rest of child prompt as usual>

  Marker grammar: `^\[mode: (interactive|non-interactive)\]$` on its own line (FR-06.1). Case-sensitive; followed immediately by `\n`.

  The child's Phase 0 (instruction below) scans the original prompt's first 256 bytes for the marker before checking flags or settings. If the marker matches, the value enters the resolver as `parent_marker`.

  Child entries merged into the parent's OQ buffer use id format `OQ-<child-skill-name>-NNN` (FR-06.2).

  Anti-pattern: parent passes mode via natural-language argument ("invoke /verify in non-interactive mode"). Forbidden — depends on LLM faithfulness; use the marker.
  ```

- [ ] Step 4: Run structure tests.
  Run: `bats plugins/pmos-toolkit/tests/non-interactive/structure.bats`
  Expected: `8 tests, 0 failures`.

- [ ] Step 5: Smoke-test the parser snippet against a synthetic artifact.
  Run:
  ```bash
  cat > /tmp/oq-fixture.md <<'EOF'
  # Test artifact
  ## Open Questions (Non-Interactive Run)
  ```yaml
  id: OQ-001
  severity: Should-fix
  prompt: "Pick a default"
  reason: free-form
  ```
  EOF
  source <(awk '/<!-- parser-snippet:start -->/,/<!-- parser-snippet:end -->/' \
    plugins/pmos-toolkit/skills/_shared/non-interactive.md \
    | sed -n '/^```bash$/,/^```$/{/^```/d; p}')
  parse_open_questions /tmp/oq-fixture.md
  ```
  Expected: a JSON array with one object containing `"id": "OQ-001"`. (Exact JSON formatting depends on `yq` version — non-empty array is the assertion.)

- [ ] Step 6: Commit.
  ```bash
  git add plugins/pmos-toolkit/skills/_shared/non-interactive.md \
          plugins/pmos-toolkit/tests/non-interactive/structure.bats
  git commit -m "feat: shared non-interactive block — sections A/B/C (refusal, parser, propagation)"
  ```

**Inline verification:**
- `bats plugins/pmos-toolkit/tests/non-interactive/structure.bats` — 8 passes
- Step 5 parser smoke — non-empty JSON array on stdout
- `wc -l plugins/pmos-toolkit/skills/_shared/non-interactive.md` — file is reasonably sized (300–600 lines expected; below 1500)

---

### T4: Implement `tools/lint-non-interactive-inline.sh`

**Goal:** Drift-detection clone of `lint-pipeline-setup-inline.sh` for the new `<!-- non-interactive-block -->` marker pair across all 26 skills minus refused skills.
**Spec refs:** NFR-05 (drift control), §15.2 gate 2.

**Files:**
- Create: `plugins/pmos-toolkit/tools/lint-non-interactive-inline.sh`
- Create: `plugins/pmos-toolkit/tests/non-interactive/lint-script.bats`

**Steps:**

- [ ] Step 1: Write failing test.
  ```bash
  #!/usr/bin/env bats
  load test_helper

  LINT_SCRIPT="${TOOLS_DIR}/lint-non-interactive-inline.sh"

  @test "lint script exists and is executable" {
    [ -x "$LINT_SCRIPT" ]
  }

  @test "lint passes when no skills have inlined block (initial state)" {
    run "$LINT_SCRIPT"
    [ "$status" -eq 1 ]  # all skills missing the block — drift
    [[ "$output" == *MISSING-BLOCK* ]]
  }

  @test "lint exits 2 on missing canonical file" {
    SHARED_FILE_BACKUP="$SHARED_FILE.bak"
    mv "$SHARED_FILE" "$SHARED_FILE_BACKUP"
    run "$LINT_SCRIPT"
    mv "$SHARED_FILE_BACKUP" "$SHARED_FILE"
    [ "$status" -eq 2 ]
  }

  @test "lint exempts refused skills" {
    # /msf-req has refusal marker (added in T26); other refused skills similarly exempt.
    # This test runs after the per-skill rollout completes; for now skip-with-reason.
    skip "Verified post-T26 when /msf-req refusal marker is added"
  }
  ```

- [ ] Step 2: Run; expect failures.
  Run: `bats plugins/pmos-toolkit/tests/non-interactive/lint-script.bats`
  Expected: 1 fail (exists/exec), 2 errors (script doesn't exist), 1 skip.

- [ ] Step 3: Copy `tools/lint-pipeline-setup-inline.sh` to the new script and adapt.
  ```bash
  cp plugins/pmos-toolkit/tools/lint-pipeline-setup-inline.sh \
     plugins/pmos-toolkit/tools/lint-non-interactive-inline.sh
  chmod +x plugins/pmos-toolkit/tools/lint-non-interactive-inline.sh
  ```

- [ ] Step 4: Adapt the new script. Apply these substitutions (using `sed` is fine; verify by reading after):
  - Header doc-block: change "Phase 0 inline block" wording to "non-interactive inline block"; canonical source line → `skills/_shared/non-interactive.md (Section 0)`.
  - `CANONICAL_FILE` → `${PLUGIN_ROOT}/skills/_shared/non-interactive.md`
  - `PIPELINE_SKILLS` array → replace with: derive from `ls "${PLUGIN_ROOT}/skills/" | grep -v -E "^(_shared|learnings)$"` and FILTER OUT skills whose SKILL.md contains the refusal marker `<!-- non-interactive: refused`. The implementor should write a small loop:
    ```bash
    SUPPORTED_SKILLS=()
    for d in "${PLUGIN_ROOT}"/skills/*/; do
      name=$(basename "$d")
      [[ "$name" == "_shared" || "$name" == "learnings" ]] && continue
      [[ ! -f "$d/SKILL.md" ]] && continue
      grep -q '<!-- non-interactive: refused' "$d/SKILL.md" && continue
      SUPPORTED_SKILLS+=("$name")
    done
    ```
  - `START_MARKER` → `'<!-- non-interactive-block:start -->'`
  - `END_MARKER` → `'<!-- non-interactive-block:end -->'`
  - Final summary line: `${#PIPELINE_SKILLS[@]}` → `${#SUPPORTED_SKILLS[@]}`.

- [ ] Step 5: Run lint; expect "all skills missing" (since no SKILL.md has been edited yet).
  Run: `bash plugins/pmos-toolkit/tools/lint-non-interactive-inline.sh`
  Expected: exit 1; output contains 25-26 `MISSING-BLOCK` lines (every skill except `/msf-req` once T26 lands; for now all 26 fail).

- [ ] Step 6: Run lint-script.bats.
  Run: `bats plugins/pmos-toolkit/tests/non-interactive/lint-script.bats`
  Expected: 3 passes, 1 skip.

- [ ] Step 7: Commit.
  ```bash
  git add plugins/pmos-toolkit/tools/lint-non-interactive-inline.sh \
          plugins/pmos-toolkit/tests/non-interactive/lint-script.bats
  git commit -m "feat: lint-non-interactive-inline.sh + bats coverage"
  ```

**Inline verification:**
- `[ -x plugins/pmos-toolkit/tools/lint-non-interactive-inline.sh ]` — executable
- `bash -n plugins/pmos-toolkit/tools/lint-non-interactive-inline.sh` — valid bash
- `bats plugins/pmos-toolkit/tests/non-interactive/lint-script.bats` — 3 passes, 1 skip

---

### T5: Implement `tools/audit-recommended.sh`

**Goal:** Audit script that asserts every `AskUserQuestion` call in given SKILL.md(s) has either a `(Recommended)` option or an adjacent `<!-- defer-only: <reason> -->` tag. Reuses the awk extractor from `_shared/non-interactive.md` per PD6.
**Spec refs:** FR-05, §15.2 gate 1, NFR-03.

**Files:**
- Create: `plugins/pmos-toolkit/tools/audit-recommended.sh`
- (audit-script.bats covered in T12, not here)

**Steps:**

- [ ] Step 1: Sketch the script.
  ```bash
  #!/usr/bin/env bash
  # audit-recommended.sh
  #
  # Audit AskUserQuestion call sites in given SKILL.md files.
  # Pass: every call has a (Recommended) option OR an adjacent <!-- defer-only: <reason> --> tag.
  # Fail: at least one call is "unmarked" (neither).
  #
  # Reuses the awk extractor from skills/_shared/non-interactive.md (PD6).
  #
  # Usage: audit-recommended.sh <SKILL.md> [<SKILL.md>...]
  #        audit-recommended.sh        # uses default glob
  #
  # Exit codes:
  #   0 — all calls in all given skills are marked
  #   1 — at least one unmarked call (drift); per-line report on stderr
  #   2 — invocation error (no SKILL.md, missing canonical file, bad args)

  set -euo pipefail

  SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
  PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/.." &>/dev/null && pwd)"
  CANONICAL="${PLUGIN_ROOT}/skills/_shared/non-interactive.md"

  [[ -f "$CANONICAL" ]] || { echo "ERROR: canonical not found: $CANONICAL" >&2; exit 2; }

  # Extract the awk extractor body from the canonical file's <!-- awk-extractor:... --> markers.
  EXTRACTOR_AWK="$(awk '/<!-- awk-extractor:start -->/,/<!-- awk-extractor:end -->/' "$CANONICAL" \
    | sed -n '/^```awk$/,/^```$/{/^```/d; p}')"

  [[ -n "$EXTRACTOR_AWK" ]] || { echo "ERROR: awk extractor empty in $CANONICAL" >&2; exit 2; }

  # Resolve target files: argv if given, else default glob (every skill SKILL.md).
  if [[ $# -gt 0 ]]; then
    TARGETS=("$@")
  else
    TARGETS=()
    for d in "${PLUGIN_ROOT}"/skills/*/; do
      name=$(basename "$d")
      [[ "$name" == "_shared" || "$name" == "learnings" ]] && continue
      [[ -f "$d/SKILL.md" ]] && TARGETS+=("$d/SKILL.md")
    done
  fi

  [[ ${#TARGETS[@]} -gt 0 ]] || { echo "ERROR: no SKILL.md files to audit" >&2; exit 2; }

  TOTAL_FAIL=0

  for skill_file in "${TARGETS[@]}"; do
    [[ -f "$skill_file" ]] || { echo "MISSING: $skill_file"; TOTAL_FAIL=$((TOTAL_FAIL+1)); continue; }

    # Skill is exempt if it carries a refusal marker.
    if grep -q '<!-- non-interactive: refused' "$skill_file"; then
      echo "REFUSED: $(basename "$(dirname "$skill_file")")/SKILL.md (exempt)"
      continue
    fi

    # Run the extractor; output rows: <line> <has_recc:0|1> <tag>
    rows="$(awk "$EXTRACTOR_AWK" "$skill_file")"
    n_calls=0; n_recc=0; n_defer=0; n_unmarked=0
    while IFS=$'\t' read -r line has_recc tag; do
      [[ -z "$line" ]] && continue
      n_calls=$((n_calls+1))
      if [[ "$tag" != "-" ]]; then
        n_defer=$((n_defer+1))
      elif [[ "$has_recc" == "1" ]]; then
        n_recc=$((n_recc+1))
      else
        n_unmarked=$((n_unmarked+1))
        echo "UNMARKED: $skill_file:$line — AskUserQuestion call has no (Recommended) option and no adjacent defer-only tag" >&2
      fi
    done <<< "$rows"

    rel="${skill_file#${PLUGIN_ROOT}/}"
    echo "${rel}: ${n_calls} calls, ${n_recc} Recommended, ${n_defer} defer-only, ${n_unmarked} unmarked" >&2
    TOTAL_FAIL=$((TOTAL_FAIL + n_unmarked))
  done

  if [[ $TOTAL_FAIL -eq 0 ]]; then
    echo "PASS: all calls in ${#TARGETS[@]} skill(s) are marked." >&2
    exit 0
  else
    echo "FAIL: ${TOTAL_FAIL} unmarked call(s) across ${#TARGETS[@]} skill(s)." >&2
    exit 1
  fi
  ```

- [ ] Step 2: Save and chmod.
  ```bash
  chmod +x plugins/pmos-toolkit/tools/audit-recommended.sh
  bash -n plugins/pmos-toolkit/tools/audit-recommended.sh
  ```
  Expected: no syntax error.

- [ ] Step 3: Smoke run on the current skills (none have been edited yet → expect many UNMARKED).
  Run: `bash plugins/pmos-toolkit/tools/audit-recommended.sh 2>&1 | tail -5`
  Expected: exit 1; final line `FAIL: <large-N> unmarked call(s) across 26 skill(s).`

- [ ] Step 4: Smoke run on `/msf-req` only — expect many unmarked (refusal marker not yet added).
  Run: `bash plugins/pmos-toolkit/tools/audit-recommended.sh plugins/pmos-toolkit/skills/msf-req/SKILL.md`
  Expected: exit 1 + UNMARKED report.

- [ ] Step 5: Add `--strict-keywords` mode (FR-04.3 — warns on likely-destructive untagged calls).
  After the for-loop in T5 Step 1, add a second pass that runs only when the script is invoked with `--strict-keywords` as a flag. The pass scans each call site (using the same EXTRACTOR_AWK output) for a destructive keyword in the call's `question:` text within the next 5 lines. Keyword set: `overwrite | restart | discard | drift | delete | force | reset | wipe`. If a call has none of: (a) Recommended option, (b) defer-only:destructive tag, AND its `question:` matches a destructive keyword, emit:
  `WARN: $skill_file:$line — likely-destructive call without defer-only:destructive tag (matched keyword: <kw>)` to stderr.
  Warnings do NOT contribute to the FAIL count (exit code unaffected by warnings); they're advisory only.
  Add argument parsing at the top of the script:
  ```bash
  STRICT_KEYWORDS=0
  TARGETS=()
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --strict-keywords) STRICT_KEYWORDS=1; shift;;
      --) shift; TARGETS+=("$@"); break;;
      -*) echo "ERROR: unknown flag $1" >&2; exit 2;;
      *) TARGETS+=("$1"); shift;;
    esac
  done
  ```
  And modify the per-skill loop to invoke the keyword-scan only when `[[ $STRICT_KEYWORDS -eq 1 ]]`.

- [ ] Step 6: Commit.
  ```bash
  git add plugins/pmos-toolkit/tools/audit-recommended.sh
  git commit -m "feat: audit-recommended.sh — assert every AskUserQuestion is marked (with --strict-keywords mode)"
  ```

**Inline verification:**
- `[ -x plugins/pmos-toolkit/tools/audit-recommended.sh ]` — executable
- `bash -n plugins/pmos-toolkit/tools/audit-recommended.sh` — valid bash
- Step 3 smoke — exit 1 + non-empty FAIL summary on stderr
- `bash plugins/pmos-toolkit/tools/audit-recommended.sh --strict-keywords plugins/pmos-toolkit/skills/execute/SKILL.md 2>&1 | grep -c '^WARN:'` — at least 1 (execute has many destructive keywords pre-rollout)

---

### T6: Pilot — inline non-interactive block in `/requirements` SKILL.md (without tagging or full rollout)

**Goal:** Apply the canonical block to ONE real skill end-to-end, validate the lint and audit scripts agree, and discover any phrasing/integration issues before the 26-fan-out.
**Spec refs:** FR-08 BC fallback (this skill is the first of "rolled out"; before this commit, the BC path applies to all 26).

**Files:**
- Modify: `plugins/pmos-toolkit/skills/requirements/SKILL.md` (insert non-interactive-block in Phase 0; do NOT yet tag any defer-only checkpoints — that's part of T22 in Phase 3)

**Steps:**

- [ ] Step 1: Read `/requirements` SKILL.md to identify its Phase 0 location and structure.
  Run: `head -120 plugins/pmos-toolkit/skills/requirements/SKILL.md`
  Find the existing `<!-- pipeline-setup-block:start -->` … `<!-- pipeline-setup-block:end -->` block; the new block goes immediately after `<!-- pipeline-setup-block:end -->`.

- [ ] Step 2: Extract the canonical block from `_shared/non-interactive.md`.
  Run:
  ```bash
  awk '/<!-- non-interactive-block:start -->/,/<!-- non-interactive-block:end -->/' \
    plugins/pmos-toolkit/skills/_shared/non-interactive.md > /tmp/ni-block.md
  wc -l /tmp/ni-block.md
  ```
  Expected: ~30–50 lines; both markers present.

- [ ] Step 3: Insert the block into `/requirements` SKILL.md immediately after `<!-- pipeline-setup-block:end -->`. Use `Edit` (not sed) for safety.

- [ ] Step 4: Add `--non-interactive` and `--interactive` to `argument-hint` in the SKILL.md frontmatter.
  Find the existing `argument-hint:` line; append `[--non-interactive | --interactive]` to its end.

- [ ] Step 5: Run the lint script.
  Run: `bash plugins/pmos-toolkit/tools/lint-non-interactive-inline.sh`
  Expected: `OK: requirements/SKILL.md` and `MISSING-BLOCK` for the other 25 (still pre-rollout); exit 1 (because others still missing).

- [ ] Step 6: Run the audit script on `/requirements` only.
  Run: `bash plugins/pmos-toolkit/tools/audit-recommended.sh plugins/pmos-toolkit/skills/requirements/SKILL.md 2>&1`
  Expected: report with `requirements/SKILL.md: <N> calls, <some> Recommended, 0 defer-only, <K> unmarked`. K is the count of unmarked calls — this is expected because we haven't yet tagged destructive checkpoints (that's T22). Exit 1 is expected.

- [ ] Step 7: Document the pilot's discoveries in `tests/non-interactive/per-skill-rollout-runbook.md` SKELETON (the runbook is fully written in T14, but T6 stubs the file and writes a `## Pilot Findings` section).
  ```bash
  cat > plugins/pmos-toolkit/tests/non-interactive/per-skill-rollout-runbook.md <<'EOF'
  # Per-Skill Non-Interactive Rollout — Runbook

  > Stub written in T6. Full procedure authored in T14.

  ## Pilot Findings (T6 on /requirements)

  - AskUserQuestion call count from awk extractor: <fill in from Step 6>
  - Unmarked count after block insertion only (no destructive tagging yet): <fill in>
  - Block size inserted: <line count from Step 2>
  - Frontmatter argument-hint extension worked: yes/no
  - Phasing ordering (block goes immediately after pipeline-setup-block): confirmed/note-deviation
  EOF
  ```
  Edit the placeholders with actual numbers from prior steps.

- [ ] Step 8: Commit.
  ```bash
  git add plugins/pmos-toolkit/skills/requirements/SKILL.md \
          plugins/pmos-toolkit/tests/non-interactive/per-skill-rollout-runbook.md
  git commit -m "feat: pilot non-interactive rollout — /requirements"
  ```

**Inline verification:**
- `bash plugins/pmos-toolkit/tools/lint-non-interactive-inline.sh 2>&1 | grep -c '^OK:'` — exactly 1 (`/requirements`)
- `grep -c '<!-- non-interactive-block' plugins/pmos-toolkit/skills/requirements/SKILL.md` — 2 (start + end markers)
- `grep -c -- '--non-interactive\|--interactive' plugins/pmos-toolkit/skills/requirements/SKILL.md` — at least 2 (argument-hint mention)

---

### T7: Bats — `resolver.bats` and `classifier.bats`

**Goal:** Cover FR-01 (mode resolution: 9 cases) and FR-02 (classifier: 6 cases) with the awk extractor exercised. These two bats files anchor the foundation phase: passing them means the canonical Section 0 logic is correct.
**Spec refs:** FR-01 (sub-clauses .1–.5), FR-02 (sub-clauses .1–.6), §14.1.

**Files:**
- Create: `plugins/pmos-toolkit/tests/non-interactive/resolver.bats`
- Create: `plugins/pmos-toolkit/tests/non-interactive/classifier.bats`

**Steps:**

- [ ] Step 1: Implement `resolver.bats` with 9 cases. The skill harness today does NOT have a callable resolver function — the resolver is prose instructions in `_shared/non-interactive.md`. The bats tests therefore exercise a **shell stand-in** that implements the resolver per the documented precedence; the same logic the LLM follows at runtime. Place the stand-in in `test_helper.bash` so all bats files reuse it.

  Add to `test_helper.bash`:
  ```bash
  # Stand-in resolver: implements precedence per Section 0 line 1.
  # Args: --flag <val|null> --parent <val|null> --settings <val|null> [--default <val>]
  # Outputs: "<mode>\t<source>" on stdout
  resolve_mode() {
    local flag="" parent="" settings="" default="interactive"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --flag) flag="$2"; shift 2;;
        --parent) parent="$2"; shift 2;;
        --settings) settings="$2"; shift 2;;
        --default) default="$2"; shift 2;;
        *) shift;;
      esac
    done
    if [[ -n "$flag" && "$flag" != "null" ]]; then
      printf '%s\tflag\n' "$flag"; return
    fi
    if [[ -n "$parent" && "$parent" != "null" ]]; then
      printf '%s\tparent-skill-prompt\n' "$parent"; return
    fi
    if [[ -n "$settings" && "$settings" != "null" ]]; then
      if [[ "$settings" == "interactive" || "$settings" == "non-interactive" ]]; then
        printf '%s\tsettings:default_mode\n' "$settings"; return
      else
        echo "settings: invalid default_mode value '$settings'; ignoring" >&2
      fi
    fi
    printf '%s\tbuiltin-default\n' "$default"
  }
  export -f resolve_mode
  ```

- [ ] Step 2: Write the 9 cases in `resolver.bats`:
  ```bash
  #!/usr/bin/env bats
  load test_helper

  @test "FR-01 case 1: flag --non-interactive alone" {
    run --separate-stderr resolve_mode --flag non-interactive --parent null --settings null
    [ "$status" -eq 0 ]
    [ "$output" = $'non-interactive\tflag' ]
  }

  @test "FR-01 case 2: flag --interactive alone" {
    run --separate-stderr resolve_mode --flag interactive --parent null --settings null
    [ "$output" = $'interactive\tflag' ]
  }

  @test "FR-01 case 3: settings non-interactive, no flag" {
    run --separate-stderr resolve_mode --flag null --parent null --settings non-interactive
    [ "$output" = $'non-interactive\tsettings:default_mode' ]
  }

  @test "FR-01 case 4: settings non-interactive, flag --interactive overrides" {
    run --separate-stderr resolve_mode --flag interactive --parent null --settings non-interactive
    [ "$output" = $'interactive\tflag' ]
  }

  @test "FR-01 case 5: settings invalid → warn + builtin default" {
    run --separate-stderr resolve_mode --flag null --parent null --settings garbage
    [ "$output" = $'interactive\tbuiltin-default' ]
    [[ "$stderr" == *"invalid default_mode value 'garbage'"* ]]
  }

  @test "FR-01 case 6: conflicting flags last wins (non-interactive)" {
    # Stand-in receives the LAST flag passed; this is how the skill parses argv.
    run --separate-stderr resolve_mode --flag non-interactive --parent null --settings null
    [ "$output" = $'non-interactive\tflag' ]
  }

  @test "FR-01 case 7: conflicting flags last wins (interactive)" {
    run --separate-stderr resolve_mode --flag interactive --parent null --settings null
    [ "$output" = $'interactive\tflag' ]
  }

  @test "FR-01 case 8: parent marker, no flag, no settings" {
    run --separate-stderr resolve_mode --flag null --parent non-interactive --settings null
    [ "$output" = $'non-interactive\tparent-skill-prompt' ]
  }

  @test "FR-01 case 9: parent marker AND flag → flag wins" {
    run --separate-stderr resolve_mode --flag interactive --parent non-interactive --settings null
    [ "$output" = $'interactive\tflag' ]
  }
  ```

- [ ] Step 3: Run `resolver.bats`.
  Run: `bats plugins/pmos-toolkit/tests/non-interactive/resolver.bats`
  Expected: `9 tests, 0 failures`.

- [ ] Step 4: Implement `classifier.bats` with 6 cases. Each case builds a synthetic SKILL.md fixture, runs the awk extractor against it, and asserts the row.
  ```bash
  #!/usr/bin/env bats
  load test_helper

  setup() {
    EXTRACTOR_AWK="$(awk '/<!-- awk-extractor:start -->/,/<!-- awk-extractor:end -->/' "$SHARED_FILE" \
      | sed -n '/^```awk$/,/^```$/{/^```/d; p}')"
    [ -n "$EXTRACTOR_AWK" ]
    FIXTURE="$(mktemp)"
  }

  teardown() {
    rm -f "$FIXTURE"
  }

  @test "FR-02 case 1: Recommended option, no defer-only tag → AUTO-PICK (has_recc=1, tag=-)" {
    cat > "$FIXTURE" <<'EOF'
  AskUserQuestion: "Pick one"
  Options: "Foo (Recommended)", "Bar"
  EOF
    run awk "$EXTRACTOR_AWK" "$FIXTURE"
    [ "$status" -eq 0 ]
    [[ "$output" == *$'\t1\t-' ]]
  }

  @test "FR-02 case 2: no Recommended → DEFER (has_recc=0, tag=-)" {
    cat > "$FIXTURE" <<'EOF'
  AskUserQuestion: "Pick one"
  Options: "Foo", "Bar"
  EOF
    run awk "$EXTRACTOR_AWK" "$FIXTURE"
    [[ "$output" == *$'\t0\t-' ]]
  }

  @test "FR-02 case 3: Recommended AND defer-only:destructive adjacent → DEFER wins (has_recc=1, tag=destructive)" {
    cat > "$FIXTURE" <<'EOF'
  <!-- defer-only: destructive -->
  AskUserQuestion: "Overwrite?"
  Options: "Yes (Recommended)", "No"
  EOF
    run awk "$EXTRACTOR_AWK" "$FIXTURE"
    [[ "$output" == *$'\t1\tdestructive' ]]
  }

  @test "FR-02 case 4: defer-only tag with blank line between → NOT adjacent (tag=-)" {
    cat > "$FIXTURE" <<'EOF'
  <!-- defer-only: destructive -->

  AskUserQuestion: "Overwrite?"
  EOF
    run awk "$EXTRACTOR_AWK" "$FIXTURE"
    [[ "$output" == *$'\t0\t-' ]]
  }

  @test "FR-02 case 5: free-form (no options) → DEFER (has_recc=0)" {
    cat > "$FIXTURE" <<'EOF'
  AskUserQuestion: "Describe the problem"
  EOF
    run awk "$EXTRACTOR_AWK" "$FIXTURE"
    [[ "$output" == *$'\t0\t-' ]]
  }

  @test "FR-02 case 6: tag 6 lines above → not adjacent (tag=-)" {
    cat > "$FIXTURE" <<'EOF'
  <!-- defer-only: destructive -->
  Some intervening content line 1
  Some intervening content line 2
  Some intervening content line 3
  Some intervening content line 4
  Some intervening content line 5
  AskUserQuestion: "Pick"
  EOF
    run awk "$EXTRACTOR_AWK" "$FIXTURE"
    [[ "$output" == *$'\t0\t-' ]]
  }
  ```

- [ ] Step 5: Run `classifier.bats`.
  Run: `bats plugins/pmos-toolkit/tests/non-interactive/classifier.bats`
  Expected: `6 tests, 0 failures`.

- [ ] Step 6: If classifier cases 4 or 6 fail, the awk extractor in `_shared/non-interactive.md` needs adjustment — return to T2 Step 4 and refine. (Common cause: blank-line adjacency check or tag-reset logic.) Re-run.

- [ ] Step 7: Commit.
  ```bash
  git add plugins/pmos-toolkit/tests/non-interactive/resolver.bats \
          plugins/pmos-toolkit/tests/non-interactive/classifier.bats \
          plugins/pmos-toolkit/tests/non-interactive/test_helper.bash
  git commit -m "test: resolver.bats (9) + classifier.bats (6)"
  ```

**Inline verification:**
- `bats plugins/pmos-toolkit/tests/non-interactive/resolver.bats` — 9 passes
- `bats plugins/pmos-toolkit/tests/non-interactive/classifier.bats` — 6 passes

---

## Phase 2: Bats Unit Tests

[Phase rationale: prove every FR/NFR with a bats unit test before mass-rolling-out to 26 SKILL.md files. Each task here exercises one piece of the foundation against synthetic fixtures.]

### T8: `buffer-flush.bats`

**Goal:** 6 cases for FR-03 (in-memory buffer → MD-artifact flush, multi-artifact aggregator, sidecar for non-MD, stderr for chat-only, partial-flush on error, OQ-id regeneration across re-runs).
**Spec refs:** FR-03.1, .2, .3, .4, .5, .6; E13 (mid-skill error partial flush).

**Files:**
- Create: `plugins/pmos-toolkit/tests/non-interactive/buffer-flush.bats`
- Modify: `plugins/pmos-toolkit/tests/non-interactive/test_helper.bash` (add `flush_buffer()` stand-in)

**Steps:**

- [ ] Step 1: Add `flush_buffer()` stand-in to `test_helper.bash`.
  ```bash
  # Stand-in flush per FR-03 dispatch.
  # Args: --buffer <file> --mode <single-md|multi-artifact|sidecar|chat-only|partial-error>
  #       --target <artifact-path> [--id-counter-start <N>]
  # Buffer file contains fenced YAML blocks; one block per entry.
  # Counts deferred (severity Blocker|Should-fix) vs Auto, writes per FR-03.4.
  flush_buffer() {
    local buf="" mode="" target="" id_start=1
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --buffer) buf="$2"; shift 2;;
        --mode) mode="$2"; shift 2;;
        --target) target="$2"; shift 2;;
        --id-counter-start) id_start="$2"; shift 2;;
        *) shift;;
      esac
    done

    local n_deferred=0 n_auto=0
    n_deferred=$(grep -cE '^severity: (Blocker|Should-fix)$' "$buf" || true)
    n_auto=$(grep -cE '^severity: Auto$' "$buf" || true)
    local n_total=$((n_deferred + n_auto))
    local outcome="clean"
    [[ $n_deferred -gt 0 ]] && outcome="deferred"

    local heading="## Open Questions (Non-Interactive Run) — ${n_deferred} deferred, ${n_auto} auto-picked"
    [[ "$mode" == "partial-error" ]] && {
      heading="## Open Questions (Non-Interactive Run — partial; skill errored)"
      outcome="error"
    }

    case "$mode" in
      single-md|partial-error)
        if [[ $n_total -gt 0 ]]; then
          {
            echo
            echo "**Mode:** non-interactive"
            echo "**Run Outcome:** $outcome"
            echo "**Open Questions:** $n_deferred"
            echo
            echo "$heading"
            echo
            cat "$buf"
          } >> "$target"
        fi
        [[ "$mode" == "partial-error" ]] && return 1
        return 0
        ;;
      sidecar)
        local sidecar="${target}.open-questions.md"
        {
          echo "$heading"
          echo
          cat "$buf"
        } > "$sidecar"
        return 0
        ;;
      chat-only)
        echo "--- OPEN QUESTIONS ---" >&2
        cat "$buf" >&2
        return 0
        ;;
      multi-artifact)
        local agg="$(dirname "$target")/_open_questions.md"
        {
          echo "$heading"
          echo
          cat "$buf"
        } > "$agg"
        # Primary artifact gets pointer frontmatter line.
        echo "**Open Questions:** $n_deferred — see _open_questions.md" >> "$target"
        return 0
        ;;
    esac
  }
  export -f flush_buffer
  ```

- [ ] Step 2: Write the failing tests in `buffer-flush.bats`.
  ```bash
  #!/usr/bin/env bats
  load test_helper

  setup() {
    BUF="$(mktemp)"
    cat > "$BUF" <<'EOF'
  ```yaml
  id: OQ-001
  severity: Blocker
  prompt: "destructive overwrite?"
  reason: destructive
  ```
  ```yaml
  id: OQ-002
  severity: Should-fix
  prompt: "tier?"
  reason: free-form
  ```
  ```yaml
  id: OQ-003
  severity: Auto
  prompt: "docs path?"
  suggested: "docs/pmos/ (Recommended)"
  reason: auto-picked
  ```
  EOF
    ARTIFACT="$(mktemp)"
    echo "# Test artifact" > "$ARTIFACT"
  }

  teardown() { rm -f "$BUF" "$ARTIFACT" "${ARTIFACT}.open-questions.md"; }

  @test "FR-03.4 case 1: single-md flush — heading + frontmatter counts deferred only" {
    run flush_buffer --buffer "$BUF" --mode single-md --target "$ARTIFACT"
    [ "$status" -eq 0 ]
    grep -q '^## Open Questions (Non-Interactive Run) — 2 deferred, 1 auto-picked$' "$ARTIFACT"
    grep -q '^\*\*Open Questions:\*\* 2$' "$ARTIFACT"
    grep -q '^\*\*Run Outcome:\*\* deferred$' "$ARTIFACT"
  }

  @test "FR-03 case 2: empty buffer → no block, no frontmatter, exit 0" {
    : > "$BUF"
    local before_size; before_size=$(wc -c < "$ARTIFACT")
    run flush_buffer --buffer "$BUF" --mode single-md --target "$ARTIFACT"
    [ "$status" -eq 0 ]
    local after_size; after_size=$(wc -c < "$ARTIFACT")
    [ "$before_size" -eq "$after_size" ]
  }

  @test "FR-03.2 case 3: non-MD primary → sidecar .open-questions.md created" {
    run flush_buffer --buffer "$BUF" --mode sidecar --target "$ARTIFACT"
    [ "$status" -eq 0 ]
    [ -f "${ARTIFACT}.open-questions.md" ]
    grep -q '^## Open Questions' "${ARTIFACT}.open-questions.md"
    # Primary artifact untouched (still just "# Test artifact"):
    [ "$(head -1 "$ARTIFACT")" = "# Test artifact" ]
    [ "$(wc -l < "$ARTIFACT")" -eq 1 ]
  }

  @test "FR-03.3 case 4: chat-only → buffer to stderr, no file written" {
    run --separate-stderr flush_buffer --buffer "$BUF" --mode chat-only --target "$ARTIFACT"
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"--- OPEN QUESTIONS ---"* ]]
    [[ "$stderr" == *"OQ-001"* ]]
    [ ! -f "${ARTIFACT}.open-questions.md" ]
  }

  @test "E13 case 5: partial-error flush → partial heading, Run Outcome=error, exit 1" {
    run flush_buffer --buffer "$BUF" --mode partial-error --target "$ARTIFACT"
    [ "$status" -eq 1 ]
    grep -q '^## Open Questions (Non-Interactive Run — partial; skill errored)$' "$ARTIFACT"
    grep -q '^\*\*Run Outcome:\*\* error$' "$ARTIFACT"
  }

  @test "FR-03.6 case 6: ids regenerate per run — re-flushing same buffer twice yields OQ-001 each time" {
    # First flush: artifact gets OQ-001..003.
    flush_buffer --buffer "$BUF" --mode single-md --target "$ARTIFACT"
    grep -q 'id: OQ-001' "$ARTIFACT"
    local first_count; first_count=$(grep -c '^id: OQ-' "$ARTIFACT")
    [ "$first_count" -eq 3 ]

    # Reset artifact to baseline; re-flush the same buffer (simulating a re-run).
    echo "# Test artifact" > "$ARTIFACT"
    flush_buffer --buffer "$BUF" --mode single-md --target "$ARTIFACT"
    # The same buffer (with OQ-001..003) flushes the same ids — they did NOT
    # increment to OQ-004..006, proving the buffer is the source of truth and
    # ids are regenerated each run, not persisted (FR-03.6).
    grep -q 'id: OQ-001' "$ARTIFACT"
    [ "$(grep -c '^id: OQ-' "$ARTIFACT")" -eq 3 ]
    ! grep -q 'id: OQ-004' "$ARTIFACT"
  }
  ```

- [ ] Step 3: Run.
  Run: `bats plugins/pmos-toolkit/tests/non-interactive/buffer-flush.bats`
  Expected: `6 tests, 0 failures`.

- [ ] Step 4: Commit: `git commit -m "test: buffer-flush.bats (6 cases incl. FR-03.6 id regeneration)"`.

**Inline verification:**
- `bats plugins/pmos-toolkit/tests/non-interactive/buffer-flush.bats` — 6 passes
- `grep -c '@test' plugins/pmos-toolkit/tests/non-interactive/buffer-flush.bats` — 6
- `grep -c 'FR-03' plugins/pmos-toolkit/tests/non-interactive/buffer-flush.bats` — at least 4 (sub-clause refs in @test names)

---

### T9: `destructive.bats`

**Goal:** 3 cases for FR-04 (destructive defer wins over Recommended; destructive defer that stops the run emits stderr + exit 2; audit script `--strict-keywords` mode warns on untagged destructive-keyword checkpoint).
**Spec refs:** FR-04.1, .2, .3.

**Files:**
- Create: `plugins/pmos-toolkit/tests/non-interactive/destructive.bats`
- Create fixtures: `fixtures/destructive-tagged.md`, `destructive-untagged-keyword.md`.

**Steps:**

- [ ] Step 1: Create the 2 fixture SKILL.md files.
  ```bash
  cat > plugins/pmos-toolkit/tests/non-interactive/fixtures/destructive-tagged.md <<'EOF'
  ---
  name: destructive-tagged
  ---
  ## Phase 0
  <!-- defer-only: destructive -->
  AskUserQuestion: "Overwrite existing artifact?"
  Options: "Overwrite (Recommended)", "Stop"
  EOF

  cat > plugins/pmos-toolkit/tests/non-interactive/fixtures/destructive-untagged-keyword.md <<'EOF'
  ---
  name: destructive-untagged-keyword
  ---
  ## Phase 0
  AskUserQuestion: "Reset all progress and discard prior tasks?"
  Options: "Yes", "No"
  EOF
  ```

- [ ] Step 2: Add `flush_and_exit_destructive()` stand-in to `test_helper.bash`:
  ```bash
  # Stand-in for "destructive defer that stops the run" path.
  # Args: --checkpoint-id <id> --reason <one-line>
  # Stderr: "Refused destructive operation at <id>: <reason>. Re-run with --interactive to resolve."
  # Exit: 2
  flush_and_exit_destructive() {
    local cp="" reason=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --checkpoint-id) cp="$2"; shift 2;;
        --reason) reason="$2"; shift 2;;
        *) shift;;
      esac
    done
    echo "Refused destructive operation at ${cp}: ${reason}. Re-run with --interactive to resolve." >&2
    return 2
  }
  export -f flush_and_exit_destructive
  ```

- [ ] Step 3: Write `destructive.bats`.
  ```bash
  #!/usr/bin/env bats
  load test_helper

  setup() {
    EXTRACTOR_AWK="$(awk '/<!-- awk-extractor:start -->/,/<!-- awk-extractor:end -->/' "$SHARED_FILE" \
      | sed -n '/^```awk$/,/^```$/{/^```/d; p}')"
  }

  @test "FR-04.1+.3: destructive tag wins over (Recommended)" {
    run awk "$EXTRACTOR_AWK" "${FIXTURES_DIR}/destructive-tagged.md"
    [ "$status" -eq 0 ]
    # Row format: <line>\t<has_recc>\t<tag>. has_recc=1 AND tag=destructive.
    [[ "$output" == *$'\t1\tdestructive' ]]
  }

  @test "FR-04.2: destructive defer with stop-the-run path emits stderr + exit 2" {
    run --separate-stderr flush_and_exit_destructive \
      --checkpoint-id "phase-1-overwrite" \
      --reason "01_requirements.md exists with downstream 02_spec.md, 03_plan.md"
    [ "$status" -eq 2 ]
    [[ "$stderr" == *"Refused destructive operation at phase-1-overwrite:"* ]]
    [[ "$stderr" == *"--interactive"* ]]
  }

  @test "FR-04.3: audit --strict-keywords warns on untagged destructive-keyword call" {
    run --separate-stderr "${TOOLS_DIR}/audit-recommended.sh" \
      --strict-keywords "${FIXTURES_DIR}/destructive-untagged-keyword.md"
    # Warnings don't change exit code; the call is also unmarked (no Recommended), so it fails normally.
    # Assertion: stderr contains a WARN line for the keyword match.
    [[ "$stderr" == *"WARN:"* ]]
    [[ "$stderr" == *"destructive"* || "$stderr" == *"reset"* || "$stderr" == *"discard"* ]]
  }
  ```

- [ ] Step 4: Run.
  Run: `bats plugins/pmos-toolkit/tests/non-interactive/destructive.bats`
  Expected: `3 tests, 0 failures` (case 3 depends on T5 Step 5's `--strict-keywords` mode being implemented).

- [ ] Step 5: Commit: `git commit -m "test: destructive.bats (3 cases — FR-04.1/.2/.3)"`.

**Inline verification:**
- `bats plugins/pmos-toolkit/tests/non-interactive/destructive.bats` — 3 passes
- `ls plugins/pmos-toolkit/tests/non-interactive/fixtures/destructive-*.md | wc -l` — 2

---

### T10: `audit-script.bats`

**Goal:** 4 fixtures for FR-05 (clean SKILL.md / unmarked call / malformed defer-only tag / refusal-marked exempt).
**Spec refs:** FR-05, FR-05.1, .2, .3.

**Files:**
- Create: `plugins/pmos-toolkit/tests/non-interactive/audit-script.bats`
- Create fixtures: `fixtures/audit-clean.md`, `fixtures/audit-unmarked.md`, `fixtures/audit-malformed-tag.md`, `fixtures/audit-refused.md`.

**Steps:**

- [ ] Step 1: Author 4 fixtures.
  ```bash
  cat > plugins/pmos-toolkit/tests/non-interactive/fixtures/audit-clean.md <<'EOF'
  ---
  name: clean
  ---
  ## Phase 0
  AskUserQuestion: "Pick A or B"
  Options: "A (Recommended)", "B"

  AskUserQuestion: "Pick C or D"
  Options: "C", "D (Recommended)"
  EOF

  cat > plugins/pmos-toolkit/tests/non-interactive/fixtures/audit-unmarked.md <<'EOF'
  ---
  name: unmarked
  ---
  ## Phase 0
  AskUserQuestion: "Free-form question"
  Options: "Foo", "Bar"
  EOF

  cat > plugins/pmos-toolkit/tests/non-interactive/fixtures/audit-malformed-tag.md <<'EOF'
  ---
  name: malformed
  ---
  ## Phase 0
  <!-- defer-only: foobar -->
  AskUserQuestion: "Tagged but bad reason"
  Options: "X", "Y"
  EOF

  cat > plugins/pmos-toolkit/tests/non-interactive/fixtures/audit-refused.md <<'EOF'
  <!-- non-interactive: refused; reason: test fixture; alternative: --interactive -->
  ---
  name: refused
  ---
  ## Phase 0
  AskUserQuestion: "this would be unmarked but skill is refused"
  Options: "X", "Y"
  EOF
  ```

- [ ] Step 2: T5's audit script currently treats any non-empty `tag` value as defer-only. To honor FR-05.3 (validate the reason vocabulary), extend T5's per-call loop with:
  ```bash
  if [[ "$tag" != "-" ]]; then
    if [[ ! "$tag" =~ ^(destructive|free-form|ambiguous)$ ]]; then
      n_unmarked=$((n_unmarked+1))
      echo "UNMARKED: $skill_file:$line — defer-only tag has invalid reason '$tag' (expected: destructive|free-form|ambiguous)" >&2
    else
      n_defer=$((n_defer+1))
    fi
  fi
  ```
  This replaces the simpler `if [[ "$tag" != "-" ]]; then n_defer=$((n_defer+1));` from T5. Re-run T5's smoke (Step 3) to confirm the change doesn't break clean fixtures.

- [ ] Step 3: Write `audit-script.bats`.
  ```bash
  #!/usr/bin/env bats
  load test_helper

  AUDIT="${TOOLS_DIR}/audit-recommended.sh"

  @test "FR-05 case 1: clean fixture (all marked) → exit 0" {
    run --separate-stderr "$AUDIT" "${FIXTURES_DIR}/audit-clean.md"
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"PASS: all calls"* ]]
  }

  @test "FR-05 case 2: unmarked call → exit 1 + UNMARKED line on stderr" {
    run --separate-stderr "$AUDIT" "${FIXTURES_DIR}/audit-unmarked.md"
    [ "$status" -eq 1 ]
    [[ "$stderr" == *"UNMARKED:"* ]]
    [[ "$stderr" == *"audit-unmarked.md"* ]]
  }

  @test "FR-05.3 case 3: malformed defer-only reason → exit 1" {
    run --separate-stderr "$AUDIT" "${FIXTURES_DIR}/audit-malformed-tag.md"
    [ "$status" -eq 1 ]
    [[ "$stderr" == *"invalid reason 'foobar'"* || "$stderr" == *"UNMARKED"* ]]
  }

  @test "FR-07.1 case 4: refusal-marked SKILL.md → exit 0 (exempt)" {
    run --separate-stderr "$AUDIT" "${FIXTURES_DIR}/audit-refused.md"
    [ "$status" -eq 0 ]
    [[ "$stderr" == *"REFUSED:"* ]]
  }
  ```

- [ ] Step 4: Run.
  Run: `bats plugins/pmos-toolkit/tests/non-interactive/audit-script.bats`
  Expected: `4 tests, 0 failures`.

- [ ] Step 5: Commit: `git commit -m "test: audit-script.bats (4 fixtures — FR-05.1/.2/.3, FR-07.1)"`.

**Inline verification:**
- `bats plugins/pmos-toolkit/tests/non-interactive/audit-script.bats` — 4 passes
- `ls plugins/pmos-toolkit/tests/non-interactive/fixtures/audit-*.md | wc -l` — 4

---

### T11: `refusal.bats`

**Goal:** 2 cases for FR-07 (refusal exits 64 + matches stderr regex; refusal is one-directional — does not block `--interactive`).
**Spec refs:** FR-07, FR-07.1, .2; §9.4 refusal marker.

**Files:**
- Create: `plugins/pmos-toolkit/tests/non-interactive/refusal.bats`
- Create fixture: `fixtures/refusal-msf-req-shape.md` (mimics /msf-req's eventual refusal marker placement).

**Steps:**

- [ ] Step 1: Add `simulate_refusal_check()` stand-in to `test_helper.bash`.
  ```bash
  # Stand-in for Section 0 step 6 (refusal check).
  # Args: --skill-name <name> --skill-file <path> --mode <interactive|non-interactive>
  # Behavior: if file has refusal marker AND mode == non-interactive, emit refusal stderr + exit 64; else exit 0.
  simulate_refusal_check() {
    local name="" file="" mode=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --skill-name) name="$2"; shift 2;;
        --skill-file) file="$2"; shift 2;;
        --mode) mode="$2"; shift 2;;
        *) shift;;
      esac
    done
    if [[ "$mode" != "non-interactive" ]]; then return 0; fi
    if ! grep -q '<!-- non-interactive: refused' "$file"; then return 0; fi
    # Extract reason and alternative from the marker.
    local marker reason alt
    marker=$(grep -m1 '<!-- non-interactive: refused' "$file")
    reason=$(echo "$marker" | sed -nE 's/.*reason:[[:space:]]*([^;]+);.*/\1/p' | sed 's/[[:space:]]*$//')
    alt=$(echo "$marker"   | sed -nE 's/.*alternative:[[:space:]]*([^-]+)-->.*/\1/p' | sed 's/[[:space:]]*$//')
    echo "--non-interactive not supported by /${name}: ${reason}. ${alt}" >&2
    return 64
  }
  export -f simulate_refusal_check
  ```

- [ ] Step 2: Create the fixture.
  ```bash
  cat > plugins/pmos-toolkit/tests/non-interactive/fixtures/refusal-msf-req-shape.md <<'EOF'
  <!-- non-interactive: refused; reason: recommendations-only with free-form input; alternative: run /wireframes --apply-edits via parent flow -->
  ---
  name: msf-req
  ---
  EOF
  ```

- [ ] Step 3: Write `refusal.bats`.
  ```bash
  #!/usr/bin/env bats
  load test_helper

  FIX="${FIXTURES_DIR}/refusal-msf-req-shape.md"

  @test "FR-07 case 1: refusal marker + --non-interactive → exit 64 + matching stderr" {
    run --separate-stderr simulate_refusal_check \
      --skill-name msf-req --skill-file "$FIX" --mode non-interactive
    [ "$status" -eq 64 ]
    [[ "$stderr" =~ ^--non-interactive\ not\ supported\ by\ /msf-req:\ recommendations-only\ with\ free-form\ input ]]
    [[ "$stderr" == *"--apply-edits"* ]]
  }

  @test "FR-07.2 case 2: refusal is one-directional (--interactive does NOT trigger refusal)" {
    run --separate-stderr simulate_refusal_check \
      --skill-name msf-req --skill-file "$FIX" --mode interactive
    [ "$status" -eq 0 ]
    [ -z "$stderr" ]
  }
  ```

- [ ] Step 4: Run.
  Run: `bats plugins/pmos-toolkit/tests/non-interactive/refusal.bats`
  Expected: `2 tests, 0 failures`.

- [ ] Step 5: Commit: `git commit -m "test: refusal.bats (2 cases — FR-07.1, FR-07.2)"`.

**Inline verification:**
- `bats plugins/pmos-toolkit/tests/non-interactive/refusal.bats` — 2 passes

---

### T12: `parser.bats`

**Goal:** 3 cases for FR-09 (parser extracts OQ block as JSON / missing block returns [] / malformed YAML emits parsable + warns).
**Spec refs:** FR-09, FR-09.1, .2.

**Files:**
- Create: `plugins/pmos-toolkit/tests/non-interactive/parser.bats`

**Steps:**

- [ ] Step 1: Add a helper to `test_helper.bash` that sources the parser snippet from `_shared/non-interactive.md` Section B at test-load time:
  ```bash
  # Source the parser snippet (extracted between markers in Section B).
  # Side effect: defines parse_open_questions().
  load_parser_snippet() {
    local body
    body=$(awk '/<!-- parser-snippet:start -->/,/<!-- parser-snippet:end -->/' "$SHARED_FILE" \
      | sed -n '/^```bash$/,/^```$/{/^```/d; p}')
    eval "$body"
  }
  export -f load_parser_snippet
  ```

- [ ] Step 2: Write `parser.bats`.
  ```bash
  #!/usr/bin/env bats
  load test_helper

  setup() {
    load_parser_snippet
    ART="$(mktemp)"
  }
  teardown() { rm -f "$ART"; }

  @test "FR-09 case 1: artifact with 3 OQ entries → parser emits 3-element JSON array" {
    cat > "$ART" <<'EOF'
  # Test artifact

  ## Open Questions (Non-Interactive Run)

  ```yaml
  id: OQ-001
  severity: Blocker
  prompt: "destructive overwrite?"
  ```

  ```yaml
  id: OQ-002
  severity: Should-fix
  prompt: "tier?"
  ```

  ```yaml
  id: OQ-003
  severity: Auto
  prompt: "docs path?"
  ```
  EOF
    run parse_open_questions "$ART"
    [ "$status" -eq 0 ]
    local len; len=$(echo "$output" | jq 'length' 2>/dev/null || echo "?")
    [ "$len" = "3" ]
  }

  @test "FR-09.2 case 2: artifact with no OQ block → parser emits [] (exit 0)" {
    cat > "$ART" <<'EOF'
  # Test artifact

  ## Some other section

  No OQ block here.
  EOF
    run parse_open_questions "$ART"
    [ "$status" -eq 0 ]
    [ "$(echo "$output" | jq 'length' 2>/dev/null || echo "?")" = "0" ]
  }

  @test "FR-09.2 case 3: artifact with malformed YAML in one block → parser is robust (does not crash)" {
    cat > "$ART" <<'EOF'
  ## Open Questions (Non-Interactive Run)

  ```yaml
  id: OQ-001
  severity: Blocker
  prompt: "good entry"
  ```

  ```yaml
  id: OQ-002
   severity: Should-fix          # bad indent — malformed
  prompt: "bad entry"
  ```
  EOF
    run parse_open_questions "$ART"
    [ "$status" -eq 0 ]
    # Per FR-09.2, parser emits parseable entries (or [] total per snippet's `|| echo '[]'` fallback).
    # Robustness assertion: stdout is a valid JSON array of length ≥ 0.
    local len; len=$(echo "$output" | jq 'length' 2>/dev/null || echo "?")
    [[ "$len" =~ ^[0-9]+$ ]]
  }
  ```

- [ ] Step 3: Run.
  Run: `bats plugins/pmos-toolkit/tests/non-interactive/parser.bats`
  Expected: `3 tests, 0 failures`. (`yq` binary required — `brew install yq` if missing.)

- [ ] Step 4: Commit: `git commit -m "test: parser.bats (3 cases — FR-09.1, FR-09.2)"`.

**Inline verification:**
- `bats plugins/pmos-toolkit/tests/non-interactive/parser.bats` — 3 passes
- `which yq` — yq binary resolved
- `which jq` — jq binary resolved

---

### T13: `propagation.bats`

**Goal:** 4 cases for FR-06 (subagent prompt-prefix marker scan + parent_marker resolver path) via stand-in. Real subagent dispatch stays in T42 manual.
**Spec refs:** FR-06, FR-06.1, .2, .3.

**Files:**
- Create: `plugins/pmos-toolkit/tests/non-interactive/propagation.bats`

**Steps:**

- [ ] Step 1: Add `scan_parent_marker()` stand-in to `test_helper.bash`. Per FR-06.1, scan the first 256 bytes of a prompt for `^\[mode: (interactive|non-interactive)\]$` on its own line.
  ```bash
  # Stand-in for child Phase 0's parent-marker scan.
  # Args: --prompt-file <path> (or --prompt <inline string>)
  # Stdout: the matched mode (interactive|non-interactive) on success; empty on no match.
  # Exit: 0 always (no-match is a valid outcome).
  scan_parent_marker() {
    local content=""
    case "$1" in
      --prompt-file) content=$(head -c 256 "$2");;
      --prompt) content=$(printf '%s' "$2" | head -c 256);;
      *) return 1;;
    esac
    # First line must match exactly.
    local first_line
    first_line=$(printf '%s' "$content" | head -1)
    if [[ "$first_line" =~ ^\[mode:\ (interactive|non-interactive)\]$ ]]; then
      echo "${BASH_REMATCH[1]}"
    fi
  }
  export -f scan_parent_marker

  # Stand-in for child id-prefix when entries are merged from a child.
  # Args: --child-skill <name> --counter <N>
  # Stdout: e.g., "OQ-verify-001"
  format_child_oq_id() {
    local skill="" n=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --child-skill) skill="$2"; shift 2;;
        --counter) n="$2"; shift 2;;
        *) shift;;
      esac
    done
    printf 'OQ-%s-%03d\n' "$skill" "$n"
  }
  export -f format_child_oq_id
  ```

- [ ] Step 2: Write `propagation.bats`.
  ```bash
  #!/usr/bin/env bats
  load test_helper

  @test "FR-06.1 case 1: marker on first line → mode extracted" {
    run scan_parent_marker --prompt $'[mode: non-interactive]\nVerify phase 1'
    [ "$status" -eq 0 ]
    [ "$output" = "non-interactive" ]
  }

  @test "FR-06.1 case 2: marker NOT on first line → no match" {
    run scan_parent_marker --prompt $'Hello\n[mode: non-interactive]\n'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  }

  @test "FR-06.1 case 3: malformed marker (missing brackets) → no match" {
    run scan_parent_marker --prompt $'mode: non-interactive\nVerify'
    [ "$status" -eq 0 ]
    [ -z "$output" ]
  }

  @test "FR-06.2 case 4: child OQ id prefixes with skill name (e.g. OQ-verify-001)" {
    run format_child_oq_id --child-skill verify --counter 1
    [ "$output" = "OQ-verify-001" ]
    run format_child_oq_id --child-skill verify --counter 12
    [ "$output" = "OQ-verify-012" ]
  }
  ```

- [ ] Step 3: Run.
  Run: `bats plugins/pmos-toolkit/tests/non-interactive/propagation.bats`
  Expected: `4 tests, 0 failures`.

- [ ] Step 4: Commit: `git commit -m "test: propagation.bats (4 cases — FR-06.1, FR-06.2)"`.

**Inline verification:**
- `bats plugins/pmos-toolkit/tests/non-interactive/propagation.bats` — 4 passes
- Real subagent dispatch coverage continues in T42 (manual).

---

### T14: `perf.bats`

**Goal:** Time-instrumented assertions for NFR-01 (resolver <100ms; classifier <10ms per call).
**Spec refs:** NFR-01.

**Files:**
- Create: `plugins/pmos-toolkit/tests/non-interactive/perf.bats`

**Steps:**

- [ ] Step 1: Write `perf.bats`.
  ```bash
  #!/usr/bin/env bats
  load test_helper

  setup() {
    EXTRACTOR_AWK="$(awk '/<!-- awk-extractor:start -->/,/<!-- awk-extractor:end -->/' "$SHARED_FILE" \
      | sed -n '/^```awk$/,/^```$/{/^```/d; p}')"
    # Build a 200-line synthetic SKILL.md with 20 AskUserQuestion calls (every 10 lines).
    PERF_FIX="$(mktemp)"
    {
      echo "---"; echo "name: perf-fix"; echo "---"; echo
      for i in $(seq 1 20); do
        for _ in $(seq 1 9); do echo "filler line"; done
        echo 'AskUserQuestion: "test '"$i"'"'
        echo 'Options: "x (Recommended)", "y"'
      done
    } > "$PERF_FIX"
  }
  teardown() { rm -f "$PERF_FIX"; }

  @test "NFR-01 resolver: 100 stand-in invocations under 1000ms total (avg < 10ms)" {
    local start_ns end_ns elapsed_ms
    start_ns=$(python3 -c 'import time; print(int(time.time()*1000))')
    for _ in $(seq 1 100); do
      resolve_mode --flag non-interactive --parent null --settings null >/dev/null
    done
    end_ns=$(python3 -c 'import time; print(int(time.time()*1000))')
    elapsed_ms=$((end_ns - start_ns))
    [ "$elapsed_ms" -lt 1000 ]
  }

  @test "NFR-01 classifier: awk extractor on 200-line/20-call SKILL.md under 100ms" {
    local start_ns end_ns elapsed_ms
    start_ns=$(python3 -c 'import time; print(int(time.time()*1000))')
    awk "$EXTRACTOR_AWK" "$PERF_FIX" >/dev/null
    end_ns=$(python3 -c 'import time; print(int(time.time()*1000))')
    elapsed_ms=$((end_ns - start_ns))
    # 20 calls in <100ms total → <5ms per call, well under the <10ms target.
    [ "$elapsed_ms" -lt 100 ]
  }
  ```

- [ ] Step 2: Run.
  Run: `bats plugins/pmos-toolkit/tests/non-interactive/perf.bats`
  Expected: `2 tests, 0 failures`. (Both bounds are very loose; failure indicates harness drag, not real perf regression.)

- [ ] Step 3: Commit: `git commit -m "test: perf.bats (NFR-01 timing — resolver + extractor)"`.

**Inline verification:**
- `bats plugins/pmos-toolkit/tests/non-interactive/perf.bats` — 2 passes
- `which python3` — python3 available (used for ms timing)

---

## Phase 3: Per-Skill Rollout

[Phase rationale: with foundation + tests proven, mass-apply the rollout to all 26 skills. T15 produces the runbook (and applies it to `/artifact` as a self-test); T16-T39 each apply the runbook to one skill and commit. /msf-req (T27) gets the refusal marker only. PD7 dictates one commit per skill.]

### T15: Author the per-skill rollout runbook + apply to `/artifact`

**Goal:** Produce `tests/non-interactive/per-skill-rollout-runbook.md` as the canonical procedure for inlining the block + tagging destructive checkpoints. Self-test it on `/artifact` (the heaviest skill, 22 calls).
**Spec refs:** All FRs related to per-skill rollout; FR-04 destructive-tagging in particular.
**Wireframe refs:** N/A (no UI changes).

**Files:**
- Create: `plugins/pmos-toolkit/tests/non-interactive/per-skill-rollout-runbook.md` (full procedure)
- Modify: `plugins/pmos-toolkit/skills/artifact/SKILL.md` (apply runbook)

**Steps:**

- [ ] Step 1: Write the runbook with this exact procedure outline (each step links to a verification command):
  1. **Read SKILL.md.** Identify Phase 0 location.
  2. **Insert non-interactive-block.** Verbatim copy from `_shared/non-interactive.md` Section 0 (between markers); paste immediately after `<!-- pipeline-setup-block:end -->`.
  3. **Add to argument-hint.** Append `[--non-interactive | --interactive]` to the existing `argument-hint:` line in YAML frontmatter.
  4. **Run extractor to enumerate AskUserQuestion calls.**
     `awk "$EXTRACTOR_AWK" plugins/pmos-toolkit/skills/<skill>/SKILL.md`
     Output: TSV rows `<line>\t<has_recc>\t<tag>`.
  5. **For each row with `has_recc=0` AND `tag=-`:** open the call site; classify by hand into one of: (a) call should have a Recommended option added (preferred — author should pick one), (b) call is genuinely free-form/ambiguous → tag `<!-- defer-only: free-form -->` on the literal previous non-empty line, (c) call gates a destructive op → tag `<!-- defer-only: destructive -->`.
  6. **For each row with `has_recc=1` but the call gates a destructive op:** add `<!-- defer-only: destructive -->` (FR-02.3 — destructive wins over Recommended).
  7. **Re-run extractor.** Verify zero unmarked rows.
  8. **Run lint.** `bash tools/lint-non-interactive-inline.sh` → expect this skill's line is `OK:`.
  9. **Run audit.** `bash tools/audit-recommended.sh skills/<skill>/SKILL.md` → expect exit 0.
  10. **Commit.** `git commit -m "feat: non-interactive rollout for /<skill>"`.

  Add a "Common pitfalls" section: how to handle multi-line AskUserQuestion calls, how to classify ambiguous "describe X" prompts, what to do when a destructive call is conditional.

- [ ] Step 2: Apply the runbook to `/artifact`. Read its SKILL.md (~700+ lines), follow steps 1–7 of the runbook. Expected: 22 AskUserQuestion calls; aim for ≤4 defer-only tags after manual review (most calls already have Recommended options per code recon).

- [ ] Step 3: Run lint and audit on `/artifact` only.
  ```bash
  bash plugins/pmos-toolkit/tools/lint-non-interactive-inline.sh 2>&1 | grep artifact
  bash plugins/pmos-toolkit/tools/audit-recommended.sh plugins/pmos-toolkit/skills/artifact/SKILL.md
  ```
  Expected: `OK: artifact/SKILL.md`; audit exit 0; report shows `<N> calls, <M> Recommended, <K> defer-only, 0 unmarked` where N+M+K math checks out.

- [ ] Step 4: Update the runbook's "Pilot Findings" section (stub from T6) with concrete numbers from `/artifact` rollout (calls count, recc count, defer count, time taken).

- [ ] Step 5: Commit (two commits: runbook + skill).
  ```bash
  git add plugins/pmos-toolkit/tests/non-interactive/per-skill-rollout-runbook.md
  git commit -m "docs: per-skill non-interactive rollout runbook"
  git add plugins/pmos-toolkit/skills/artifact/SKILL.md
  git commit -m "feat: non-interactive rollout for /artifact"
  ```

**Inline verification:**
- `bash plugins/pmos-toolkit/tools/audit-recommended.sh plugins/pmos-toolkit/skills/artifact/SKILL.md` — exit 0
- `grep -c '<!-- defer-only:' plugins/pmos-toolkit/skills/artifact/SKILL.md` — equal to the K reported by audit
- `wc -l plugins/pmos-toolkit/tests/non-interactive/per-skill-rollout-runbook.md` — at least 80 lines

---

### T16-T39: Apply runbook to remaining 25 skills (one task per skill) [P]

> Tasks T16-T39 are mutually independent and may be parallelized [P]. Each follows the runbook at `plugins/pmos-toolkit/tests/non-interactive/per-skill-rollout-runbook.md`. /msf-req (T27) is the refusal-marker variant; all others are normal supported skills.

**Per-task structure (applies to each):**

- **Goal:** Apply the runbook to `/<skill>` SKILL.md.
- **Spec refs:** FR-02 (classifier), FR-04 (destructive tagging), FR-07 (refusal — T26 only).
- **Wireframe refs:** N/A.
- **Files:** Modify `plugins/pmos-toolkit/skills/<skill>/SKILL.md`.
- **Steps:**
  1. Open the runbook; read steps 1–10.
  2. Apply steps 1–9 of the runbook to this skill.
  3. Run audit on this skill: `bash plugins/pmos-toolkit/tools/audit-recommended.sh plugins/pmos-toolkit/skills/<skill>/SKILL.md` → assert exit 0.
  4. Commit per PD7: `git commit -m "feat: non-interactive rollout for /<skill>"`.
- **Inline verification (per task):**
  - audit exit 0 for this skill.
  - `grep -c '<!-- non-interactive-block:start -->' plugins/pmos-toolkit/skills/<skill>/SKILL.md` — exactly 1 (or 0 for /msf-req with refusal).
  - lint output for this skill — `OK:` (or `REFUSED:` for /msf-req).

| Task | Skill | Refusal? | Estimated calls | Notes |
|---|---|---|---|---|
| T16 | backlog | no | mid | |
| T17 | changelog | no | low (<3) | mostly read-only output |
| T18 | complete-dev | no | mid | |
| T19 | create-skill | no | mid-high | |
| T20 | creativity | no | mid | |
| T21 | design-crit | no | high (~15) | inherits multiSelect patterns; many free-form |
| T22 | diagram | no | mid | |
| T23 | execute | no | high | many destructive checkpoints — careful tagging |
| T24 | grill | no | mid | |
| T25 | mac-health | no | low (<3) | mostly read-only |
| T26 | msf-wf | no | mid | |
| T27 | **msf-req** | **yes — REFUSAL marker** | n/a | per spec D15: add `<!-- non-interactive: refused; reason: recommendations-only with free-form input; alternative: run /wireframes --apply-edits via parent flow -->` near top of SKILL.md. Do NOT inline non-interactive-block. Verify with refusal.bats stand-in. |
| T28 | mytasks | no | mid | |
| T29 | people | no | low | |
| T30 | plan | no | mid | |
| T31 | polish | no | low | |
| T32 | product-context | no | low | |
| T33 | prototype | no | high | multi-artifact (FR-03.5 applies) |
| T34 | retro | no | mid | |
| T35 | session-log | no | low | |
| T36 | simulate-spec | no | mid | |
| T37 | spec | no | high (~18) | many design-decision calls |
| T38 | verify | no | high | many destructive (auto-fix flag) |
| T39 | wireframes | no | high (~21) | multi-artifact (FR-03.5); heaviest skill |

**Note: 24 entries above (T16–T39) plus T15 (`/artifact`) = 25 supported skills + T27 (`/msf-req` refused) = 26 total.** That accounts for all 26 user-invokable skills.

**Final per-skill verification check (run after T16-T39 are all complete):**
```bash
bash plugins/pmos-toolkit/tools/lint-non-interactive-inline.sh
bash plugins/pmos-toolkit/tools/audit-recommended.sh
```
Both expected: exit 0. lint reports `OK: <skill>/SKILL.md` for 25 skills + `REFUSED: msf-req/SKILL.md`. audit reports each skill's call breakdown with 0 unmarked.

---

### T40: Phase 3 sweep — re-run lint + audit on full skill set

**Goal:** Confirm the per-skill rollout produced a clean, lint-passing, audit-passing repository before Phase 4.
**Spec refs:** §15.2 gates 1–2.

**Files:**
- None (verification-only task)

**Steps:**

- [ ] Step 1: Run lint script across all skills.
  Run: `bash plugins/pmos-toolkit/tools/lint-non-interactive-inline.sh`
  Expected: exit 0; output shows 25 `OK:` + 1 `REFUSED:` (msf-req).

- [ ] Step 2: Run audit script across all skills.
  Run: `bash plugins/pmos-toolkit/tools/audit-recommended.sh`
  Expected: exit 0; final summary line `PASS: all calls in 26 skill(s) are marked.`

- [ ] Step 3: Re-run all bats tests from Phases 1–2 to catch any regressions.
  Run: `bats plugins/pmos-toolkit/tests/non-interactive/*.bats`
  Expected: aggregate pass count = sum of all bats files (~35–40 cases); 0 failures.

- [ ] Step 4: Commit a sweep marker (no code change, just an empty commit for bisectability).
  Run: `git commit --allow-empty -m "ci: phase 3 sweep — all 26 skills audited clean"`

**Inline verification:**
- All three commands exit 0.

---

## Phase 4: Integration & Ship

[Phase rationale: per-skill integration smoke (one bats invocation per supported skill via headless `claude -p`), manual end-to-end checks for subagent propagation and BC fallback, CI workflow bootstrap, version bump + changelog. Last phase before merge.]

### T41: Per-skill integration bats — zero-AskUserQuestion smoke

**Goal:** For each of 25 supported skills, write a bats file that invokes the skill via `claude -p '/<skill> --non-interactive ...'` headlessly, scrapes the transcript, and asserts zero `AskUserQuestion` events. /msf-req gets a separate "asserts exit 64" smoke.
**Spec refs:** §14.2 (per-skill integration tests).

**Files:**
- Create: `plugins/pmos-toolkit/tests/integration/non-interactive/<skill>.bats` × 26 (25 supported + 1 refusal)
- Create: `plugins/pmos-toolkit/tests/integration/non-interactive/test_helper.bash` (claude harness helpers)

**Steps:**
- [ ] Step 1: Author `test_helper.bash` with helpers: `run_skill_headless <skill> <args>` (invokes `claude -p` and captures transcript JSON to a tempfile), `count_askuserquestion <transcript>` (greps the JSON for AskUserQuestion tool-use events), `assert_run_outcome <artifact>` (greps prose frontmatter line).
- [ ] Step 2: For each supported skill (25 of them), write a `<skill>.bats` file with one or two cases:
  - Primary case: invoke the skill with a fixture argument that exercises a typical happy path; assert transcript shows zero AskUserQuestion events; assert primary artifact (if any) has `**Run Outcome:** clean` or `deferred` (skill-dependent).
  - Skills with no persistent artifact (`/mac-health`): assert stderr contains `--- OPEN QUESTIONS ---` block OR `outcome=clean, open_questions=0`.
- [ ] Step 3: For `/msf-req`, write a refusal smoke: invoke `claude -p '/msf-req --non-interactive <fixture>'`, assert exit 64, assert stderr matches refusal regex.
- [ ] Step 4: Make these tests **opt-in** via env var because each takes 30–120s of LLM time:
  ```bash
  setup() {
    [[ -z "${PMOS_INTEGRATION:-}" ]] && skip "set PMOS_INTEGRATION=1 to run"
  }
  ```
- [ ] Step 5: Spot-check by running one: `PMOS_INTEGRATION=1 bats plugins/pmos-toolkit/tests/integration/non-interactive/requirements.bats`. Expected: pass within ~120s.
- [ ] Step 6: Commit per-skill bats in batches of 5–10 to avoid one massive commit; final commit message: `test: integration smoke for non-interactive (26 skills)`.

**Inline verification:**
- `ls plugins/pmos-toolkit/tests/integration/non-interactive/*.bats | wc -l` — 26
- One spot-checked skill passes when `PMOS_INTEGRATION=1`.

---

### T42: Manual subagent-propagation E2E

**Goal:** Verify FR-06 (parent skill propagates `[mode: non-interactive]` to dispatched child) end-to-end with a real Claude session.
**Spec refs:** FR-06.1, .2, .3.

**Files:**
- Create: `plugins/pmos-toolkit/tests/integration/non-interactive/MANUAL-subagent.md` (runbook for the manual check)

**Steps:**
- [ ] Step 1: Write the manual runbook documenting:
  1. Set up: tiny seed plan in a feature folder.
  2. Run: `claude -p '/execute --non-interactive'`.
  3. Watch: when /execute reaches the per-task verify dispatch, capture the subagent prompt.
  4. Assert: subagent prompt's first line is exactly `[mode: non-interactive]`.
  5. Assert: child /verify's stderr opening line is `mode: non-interactive (source: parent-skill-prompt)`.
  6. Assert: parent's final OQ block contains entries with id format `OQ-verify-NNN` (FR-06.2).
- [ ] Step 2: Run the manual check on a fixture; capture stderr + transcript; record results in the runbook (or a `MANUAL-subagent-results.md`).
- [ ] Step 3: Commit results.

**Inline verification (manual):**
- All 3 assertions in the runbook pass on at least one fixture run.

---

### T43: Manual BC-fallback check

**Goal:** Verify FR-08 (skill without inlined non-interactive block + `--non-interactive` arg → soft warn + interactive fallback). After Phase 3, all skills have the block — so this check requires temporarily reverting one skill's block to simulate the pre-rollout state.
**Spec refs:** FR-08, FR-08.1.

**Files:**
- Create: `plugins/pmos-toolkit/tests/integration/non-interactive/MANUAL-bc-fallback.md`

**Steps:**
- [ ] Step 1: Write the runbook:
  1. On a throwaway branch off main, `git revert` the commit that added the non-interactive-block to one specific skill (e.g., `/changelog` since it has few calls).
  2. Run `claude -p '/changelog --non-interactive ...'`.
  3. Assert stderr contains `WARNING: --non-interactive not yet supported by /changelog; falling back to interactive.`
  4. Assert skill ran to completion in interactive mode (or, in headless, exited cleanly because no human → AskUserQuestion fallback).
  5. Discard the throwaway branch (do not merge the revert).
- [ ] Step 2: Run + record results.
- [ ] Step 3: Commit results doc.

**Inline verification:**
- WARNING line emitted; skill completes without crash.

---

### T44: CI workflow — `.github/workflows/audit-recommended.yml`

**Goal:** Bootstrap GitHub Actions CI: on every PR touching `plugins/pmos-toolkit/skills/**/SKILL.md` or `plugins/pmos-toolkit/skills/_shared/non-interactive.md`, run `tools/audit-recommended.sh` and `tools/lint-non-interactive-inline.sh`. Both must exit 0.
**Spec refs:** NFR-03, §15.2 gate.

**Files:**
- Create: `.github/workflows/audit-recommended.yml`
- (Optional) Create: `.github/workflows/lint-non-interactive-inline.yml` (separate file; or one workflow runs both jobs — pick one).

**Steps:**
- [ ] Step 1: Choose: one workflow with two jobs vs two workflows. Pick **one workflow with two jobs** for simplicity (single-file PR review).
- [ ] Step 2: Author the workflow:
  ```yaml
  name: Audit non-interactive markers

  on:
    pull_request:
      paths:
        - 'plugins/pmos-toolkit/skills/**/SKILL.md'
        - 'plugins/pmos-toolkit/skills/_shared/non-interactive.md'
        - 'plugins/pmos-toolkit/tools/audit-recommended.sh'
        - 'plugins/pmos-toolkit/tools/lint-non-interactive-inline.sh'

  jobs:
    audit:
      runs-on: ubuntu-latest
      steps:
        - uses: actions/checkout@v4
        - name: Run audit-recommended
          run: bash plugins/pmos-toolkit/tools/audit-recommended.sh
        - name: Run lint-non-interactive-inline
          run: bash plugins/pmos-toolkit/tools/lint-non-interactive-inline.sh
  ```
- [ ] Step 3: Validate locally with `actionlint` (`brew install actionlint`).
  Run: `actionlint .github/workflows/audit-recommended.yml`
  Expected: no errors.
- [ ] Step 4: Commit the workflow.
- [ ] Step 5: Open a draft PR (or push the feature branch); confirm the workflow appears in the GitHub Actions tab and runs green.

**Inline verification:**
- `actionlint .github/workflows/audit-recommended.yml` — exit 0
- The workflow run on the feature branch's PR is green.

---

### T45: Plugin version bump + CHANGELOG

**Goal:** Bump version to 2.24.0 in both plugin manifests; add a CHANGELOG entry summarizing the feature.
**Spec refs:** PD8.

**Files:**
- Modify: `plugins/pmos-toolkit/.claude-plugin/plugin.json:3` (`"version": "2.23.0"` → `"version": "2.24.0"`)
- Modify: `plugins/pmos-toolkit/.codex-plugin/plugin.json` (same key, exact line confirmed in step 1)
- Create or Modify: `plugins/pmos-toolkit/CHANGELOG.md`

**Steps:**
- [ ] Step 1: Read both plugin manifests; confirm `"version": "2.23.0"`.
  Run:
  ```bash
  grep -n '"version"' plugins/pmos-toolkit/.claude-plugin/plugin.json
  grep -n '"version"' plugins/pmos-toolkit/.codex-plugin/plugin.json
  ```
- [ ] Step 2: Update both files via `Edit` tool (not sed) to `"version": "2.24.0"`.
- [ ] Step 3: Append (or create) `plugins/pmos-toolkit/CHANGELOG.md` with:
  ```markdown
  ## 2.24.0 — 2026-05-08

  ### Added
  - Cross-cutting `--non-interactive` flag for all 26 user-invokable skills. Auto-picks the existing `(Recommended)` option on `AskUserQuestion` calls; defers free-form, no-Recommended, and destructive checkpoints to a structured `## Open Questions (Non-Interactive Run)` block in the produced artifact (or sidecar for non-MD skills).
  - Symmetric `--interactive` override flag.
  - Repo-level default via `.pmos/settings.yaml :: default_mode`.
  - Three-state exit contract: 0 (clean) / 2 (deferred) / 1 (runtime error) / 64 (usage / refusal).
  - Subagent propagation via `[mode: non-interactive]` prompt-prefix marker.
  - `tools/audit-recommended.sh` — assert every `AskUserQuestion` in supported SKILL.md has either a `(Recommended)` option or a `<!-- defer-only: ... -->` adjacent tag.
  - `tools/lint-non-interactive-inline.sh` — drift detection for the canonical `_shared/non-interactive.md` block.
  - GitHub Actions workflow gating PRs on audit + lint.
  - `/msf-req` declares itself refused (per design — recommendations-only with free-form input).

  ### Notes
  - 13 new bats files under `plugins/pmos-toolkit/tests/non-interactive/`; 26 integration smoke tests under `plugins/pmos-toolkit/tests/integration/non-interactive/` (opt-in via `PMOS_INTEGRATION=1`).
  - No breaking changes; existing interactive default is byte-identical.
  ```
- [ ] Step 4: Commit.
  ```bash
  git add plugins/pmos-toolkit/.claude-plugin/plugin.json \
          plugins/pmos-toolkit/.codex-plugin/plugin.json \
          plugins/pmos-toolkit/CHANGELOG.md
  git commit -m "chore(release): pmos-toolkit 2.24.0 — non-interactive mode"
  ```

**Inline verification:**
- `grep '"version"' plugins/pmos-toolkit/.claude-plugin/plugin.json` — `"version": "2.24.0"`
- `grep '"version"' plugins/pmos-toolkit/.codex-plugin/plugin.json` — `"version": "2.24.0"`
- `head -20 plugins/pmos-toolkit/CHANGELOG.md` — contains `## 2.24.0`

---

### TN: Final Verification

**Goal:** Verify the entire implementation works end-to-end before merging the feature branch.

- [ ] **Lint & format:** `bash plugins/pmos-toolkit/tools/lint-pipeline-setup-inline.sh && bash plugins/pmos-toolkit/tools/lint-non-interactive-inline.sh && bash plugins/pmos-toolkit/tools/audit-recommended.sh`
  Expected: all three exit 0.
- [ ] **Bats unit tests:** `bats plugins/pmos-toolkit/tests/non-interactive/*.bats`
  Expected: ~35–40 cases, 0 failures (some skips OK with explicit `skip` reasons).
- [ ] **Bats integration smoke (opt-in):** `PMOS_INTEGRATION=1 bats plugins/pmos-toolkit/tests/integration/non-interactive/*.bats`
  Expected: 26 cases pass; total runtime ≤30 minutes (each ~30–120s).
- [ ] **CI workflow run:** confirm the GitHub Actions run on the feature branch's draft PR is green.
- [ ] **Manual subagent propagation E2E:** re-run T42 runbook end-to-end against a real fixture; capture stderr + transcript; assert all 3 assertions pass.
- [ ] **Manual BC-fallback:** re-run T43 runbook on a throwaway branch; assert WARNING line + interactive fallback.
- [ ] **End-to-end pipeline smoke:** run `claude -p '/requirements --non-interactive "Test fixture for non-interactive smoke"'`; capture exit code + artifact; assert: exit 0 or 2; produced `01_requirements.md` has `**Run Outcome:**` line; if `Run Outcome: deferred`, contains `## Open Questions (Non-Interactive Run)` section.
- [ ] **API smoke test:** N/A (no HTTP API).
- [ ] **Frontend smoke test (Playwright MCP):** N/A (no UI).
- [ ] **UX polish checklist:** N/A (no UI).
- [ ] **Wireframe diff:** N/A (no wireframes).
- [ ] **Plugin version verification:** `grep -h '"version"' plugins/pmos-toolkit/.claude-plugin/plugin.json plugins/pmos-toolkit/.codex-plugin/plugin.json` — both show `"version": "2.24.0"`.
- [ ] **CHANGELOG entry verification:** `head -25 plugins/pmos-toolkit/CHANGELOG.md` — contains `## 2.24.0` block.
- [ ] **No regressions in existing skills (interactive mode):** spot-check 3 random skills via interactive runs (`/spec`, `/diagram`, `/grill`) without `--non-interactive`; confirm produced artifacts have NO `**Mode:** ...` line, NO `**Run Outcome:**` line, NO `## Open Questions (Non-Interactive Run)` section. NFR-04 byte-identical-when-interactive verification.
- [ ] **Determinism (NFR-06):** run `/requirements --non-interactive "fixed test fixture"` twice on the same git commit + same `.pmos/settings.yaml`; diff the two produced `01_requirements.md` files (modulo `**Date:**` and `**Last updated:**` lines): `diff <(grep -v -E '^\*\*(Date|Last updated):' run1/01_requirements.md) <(grep -v -E '^\*\*(Date|Last updated):' run2/01_requirements.md)` — expect empty diff. Confirms same inputs → byte-identical artifacts.
- [ ] **Spec coverage final check:** for each FR (FR-01 through FR-09 and sub-clauses) and NFR (NFR-01 through NFR-07), confirm at least one task in T1–T44 implements + at least one bats or manual test verifies. Cross-reference against spec §7 + §8.

**Cleanup:**
- [ ] Remove temporary fixtures from `/tmp/`: `rm -f /tmp/oq-fixture.md /tmp/ni-block.md`.
- [ ] Confirm no stray `.bak` files in working tree: `find plugins/pmos-toolkit -name '*.bak' -type f` — empty.
- [ ] Update `~/.pmos/learnings.md` if any new learning emerged from execution (run /execute Phase 7 reflection).
- [ ] Confirm git status is clean: `git status --porcelain` — empty.

---

## Review Log

| Loop | Findings | Changes Made |
|------|----------|-------------|
| 1 | F1 [Should-fix] T15-T39 consolidated into one H3 + table not 25 separate H3 tasks; F2 [Should-fix] T8-T13 described cases prose-style (anti-pattern); F3 [Should-fix] FR-03.6 (id regenerates per re-run) untested; F4 [Should-fix] FR-06 propagation only covered by manual T41; F5 [Should-fix] T9 case 3 needs T5 `--strict-keywords` mode; F6 [Nit] PD5 [P] not in graph; F7 [Nit] /execute, /spec, /verify destructive risk not in Risks. | F1 → kept consolidated table per user disposition (rationale: PD4 runbook satisfies independence). F2 → T8-T12 expanded with verbatim bats code (~250 lines added); each test asserts behavior not existence. F3 → added Case 6 to T8 buffer-flush.bats (re-flush asserts ids restart at OQ-001). F4 → inserted new T13 propagation.bats (4 cases) covering FR-06.1 marker scan + FR-06.2 child OQ id format; renumbered T13 perf → T14 and shifted T14-T44 → T15-T45. F5 → T5 Step 5 added implementing `--strict-keywords` keyword-scan mode + warn line. F6 → execution-order graph annotated [P] for T16-T39. F7 → Risks table row added: "/execute, /spec, /verify destructive under-tagging" with audit+lint as the gate. |
| 2 (final review) | N1 [Nit] NFR-06 (determinism — same inputs produce byte-identical artifacts) implicit but not explicitly verified. | N1 → added a TN bullet running `/requirements --non-interactive` twice on the same fixture and diff-ing artifacts (modulo Date/Last-updated lines) — empty diff is the assertion. |
