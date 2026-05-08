---
tier: 2
type: enhancement
feature: plan-skill-redesign
spec_ref: 02_spec.md
requirements_ref: ../../../.pmos/grills/2026-05-08_plan-skill-design.md
date: 2026-05-08
status: Draft
commit_cadence: per-task
contract_version: 1
---

# /plan Skill Redesign — Implementation Plan

**Date:** 2026-05-08
**Spec:** `docs/features/2026-05-08_plan-skill-redesign/02_spec.md`
**Requirements:** `.pmos/grills/2026-05-08_plan-skill-design.md` (grill report — 62 decisions, 7 cross-skill changes)

---

## Overview

Implement /plan v2 plus the coordinated cross-skill changes required by the spec's FR-115 rollout: tier-aware planning, stack-aware verification, platform-neutral templates, explicit /execute handshake (per-task `Depends on / Idempotent / Requires state from / Data`), convergent review loops with sidecar persistence, and non-interactive mode. The work ships as three deployable phases per FR-115 rollout order: (1) shared resources land first while v1 still runs, (2) /spec frontmatter+anchors land while back-compat reads ignore new fields, (3) /plan v2 + /execute v2 + /backlog `type` field merge atomically with a single plugin minor-version bump.

**Done when:** lint suite green (pipeline-setup-inline + new stack-libs + platform-strings + js-preamble), `_shared/stacks/{npm,pnpm,yarn-classic,yarn-berry,bun,python,rails,go,static}.md` and `_shared/platform-strings.md` exist with all required sections, /spec emits frontmatter `tier|type|feature|date|status|requirements` plus stable anchors at all tiers, /backlog `type` enum extended to 6 values, /plan v2 generates tier-correct plans for the three test-fixture specs (T1 bug-fix → 1 task no decision-log floor; T2 enhancement → 1 review loop; T3 feature → mermaid diagram + per-task new fields + sidecar `03_plan_review.md`), /execute v2 consumes new task fields and emits warning-not-error on missing fields, defect handoff round-trip works (write defect → `/plan --fix-from` → resume), plugin version bumped from 2.23.0 to 2.24.0 in both manifests.

**Execution order:**

```
Phase 1 (Shared Resources)             Phase 2 (/spec)              Phase 3 (atomic /plan+/execute+/backlog)
T1 platform-strings ─┐                 T13 spec frontmatter (T1)    T21 /backlog schema type enum
T2 stacks dir+lint   ├─[P after T1] →  T14 spec frontmatter (T2) ─→ T22 /backlog inference heuristics
T3 JS stacks (5)     │                 T15 spec frontmatter (T3)    T23..T33 /plan v2 (sequential)
T4 python.md         │ [P]             T16 anchor emission           T34..T37 /execute v2 (sequential)
T5 rails.md          │ [P]             T17 type detection            T38 test-fixture sub-repos [P]
T6 go.md             │ [P]             T18 spec exit validator       T39..T41 integration runs (sequential)
T7 static.md         │ [P]             T19 test-fixture specs [P]    T42 anti-pattern prune
T8 pipeline-setup    │                 T20 phase-2 verify gate       T43 plugin version bump
T9..T11 lint scripts │ [P after T2-T7]                                TN final verification
T12 phase-1 verify   ┘
```

`[P]` = parallelizable with prior tasks of the same group.

---

## Decision Log

> Inherits 62 grill decisions (D1–D62) and 8 spec decisions (S1–S8) from spec §4. Entries below are implementation-specific decisions made during this planning session.

| #  | Decision | Options Considered | Rationale |
|----|----------|-------------------|-----------|
| P1 | Treat the spec's tier-2 frontmatter as a misclassification and apply Tier-3 planning rigor (≥3 decision-log entries, 2 review loops, mandatory Risks, full TN, `## Phase N` groupings) without halting to update the spec frontmatter | (a) Apply Tier-3 rigor and note the override (chosen), (b) Halt and round-trip update spec to tier:3, (c) Apply Tier-2 rigor literally | User picked (a) when asked. Spec scope (115+ FRs across 5 skills, 3-step rollout) is unambiguously Tier-3 in workload. Round-trip costs an extra interview cycle for a frontmatter typo. Tier-3 rigor cannot under-serve a Tier-2 spec, so the downside is bounded. The override is logged here so the audit trail is preserved |
| P2 | Implement as a single monolithic 03_plan.md with three `## Phase N` groupings rather than three separate plan files | (a) One plan, three phases (chosen), (b) Three plan files (Plan A/B/C), (c) Single phase, ~40 flat tasks | User picked (a) when asked. FR-115 prescribes a strict rollout *order* but the changes interlock heavily (e.g., /plan v2 only matters once /spec emits anchors). Splitting into three plan files would require shared decision-log + risks + rollback duplicated across them. Phase boundaries already trigger /verify (per execute/SKILL.md Phase 2.5) so the deployable-slice property is preserved. Trade-off: one larger plan to navigate, but cohesion wins |
| P3 | Anchors in /spec are auto-derived from H2/H3 heading text (kebab-case, deduplicated by `-2/-3` suffix) rather than requiring explicit `{#anchor}` markers (resolves Open Question #1 from spec §11) | (a) Auto-derive from heading text (chosen), (b) Require explicit `{#anchor}` markers in every section, (c) Hybrid: explicit markers only on sections that have a numeric prefix (FR-N) | Auto-derive removes a manual discipline burden — every existing /spec output already has heading text. Explicit markers would be an extra rule the planner must remember. The dedupe-by-suffix rule handles collisions deterministically. Trade-off: heading rename = anchor break, but FR-31a hard-fails on broken refs at /plan Phase 4 so drift is caught. Decision recorded so /spec implementation in Phase 2 doesn't re-litigate |
| P4 | Test-fixture specs live at `tests/fixtures/specs/` (NOT `docs/features/_test-fixtures/`) — resolves Open Question #4 from spec §11 | (a) `tests/fixtures/specs/` (chosen), (b) `docs/features/_test-fixtures/`, (c) `plugins/pmos-toolkit/tests/fixtures/specs/` | (a) keeps test fixtures out of the user-facing `docs/features/` namespace where folder-picker logic globs. The repo-root `tests/` already exists culturally (tests reference paths like `tests/fixtures/repos/`). (b) would mean every /spec or /plan run sees the fixture folders in folder-picker output, which is noise. (c) is plugin-scoped but the fixtures exercise the host repo's pipeline-setup, so repo-root placement is more honest |
| P5 | Backwards-compat shim (S8) emits warnings via per-task `WARN:` log lines on stderr, not by writing to a sidecar | (a) Stderr per-task warnings (chosen), (b) Single aggregated warning at end of /execute, (c) Write to a `03_execute_compat.md` sidecar | Stderr lines surface in the user's terminal output during /execute, are easy to grep, and don't pollute the feature folder with another sidecar. Per-task placement makes the offending task obvious. Aggregation hides which task triggered the warning |
| P6 | The 5 JS-stack files share a "common preamble" via copy-paste with a CI lint that diffs them rather than via a templating mechanism (FR-11) | (a) Copy-paste + diff lint (chosen), (b) Skill-time include (`{{include}}` directive), (c) Generated at build-time from a single template | The skill harness has no templating engine — skills are read as plain markdown by the Skill tool. (b) would require introducing one. (c) requires a build step that doesn't exist. (a) keeps everything as plain markdown that any reader can grep, with the lint catching drift at PR time. Trade-off: 5 files have duplicated text; that's bounded |
| P7 | /plan --fix-from reads the defect file from `{feature_folder}/03_plan_defect_<task-id>.md` (per spec FR-56 / §7.5); /execute deletes it on successful resume past the defect task (per FR-100b) | (a) /execute owns lifecycle (write+delete) (chosen), (b) /plan --fix-from deletes after consuming, (c) Manual cleanup | (a) keeps the defect file as a "still defective" marker until past the bad task — if /plan --fix-from were the deleter, a re-run would have nothing to read. /execute knows when the previously-defective task has succeeded; it owns the lifecycle by virtue of being the writer. Recorded so neither skill duplicates the deletion |
| P8 | Phase 1 lint scripts are written in pure bash + awk (no jq, no python) to match the existing `lint-pipeline-setup-inline.sh` style | (a) Bash + awk (chosen), (b) Add jq dependency, (c) Write in Python | (a) keeps the toolchain dependency-free and matches the existing lint script's idiom. The validation logic (file-presence + section-grep + diff-of-preamble) is well within bash's strengths. (b) and (c) introduce dependencies that contributors might not have installed |

---

## Code Study Notes

### Patterns to follow

- **Phase 0 inline block** — `_shared/pipeline-setup.md:19-30` (canonical between markers). All pipeline skills inline this verbatim; lint enforces (`tools/lint-pipeline-setup-inline.sh`). New /plan v2 keeps the existing markers untouched
- **Skill template structure** — `plan/SKILL.md:107-272` defines the plan-doc template. Tier-aware version replaces this section but keeps the H2 ordering (Overview → Decision Log → Code Study Notes → Prerequisites → File Map → Risks → Rollback → Tasks → Review Log)
- **Findings Presentation Protocol** — `plan/SKILL.md:401-421` and `spec/SKILL.md:538-558` use the same protocol (severity-tagged batched AskUserQuestion); /plan v2 keeps this exact shape, adds the auto-classification rule (FR-41a)
- **Execute per-task log frontmatter** — `execute/SKILL.md:139-153` shows the schema (`task_number`, `task_goal_hash`, `files_touched`, `status`). /execute v2 extends but does NOT break this schema
- **Bash lint script idiom** — `tools/lint-pipeline-setup-inline.sh:1-104` pattern: extract block via awk, diff against canonical, accumulate failure count, exit 1 if any. New lint scripts follow this exact pattern

### Existing code to reuse

- `_shared/pipeline-setup.md` Section A.3 (slug derivation) — already exists; FR-63 just requires /plan to cite it (already does via Phase 0 step 1 chain)
- `_shared/structured-ask-edge-cases.md` — already used by /plan and /spec for the user-picks-non-recommended path; /plan v2 keeps the reference
- `_shared/interactive-prompts.md` — protocol used by /backlog Phase 5; /plan v2 cites it for the AskUserQuestion shapes
- `_shared/phase-boundary-handler.md` — already wired into /execute Phase 2.5; FR-26a just makes it explicit in /plan v2 docs (no code change to the handler)
- `_shared/execute-resume.md` — owns task-state classification; /execute v2 extends frontmatter parsing but keeps the resume logic
- `backlog/schema.md` and `backlog/inference-heuristics.md` — only the type enum and keyword tables change; rest of the schema is preserved

### Constraints discovered

- **Plugin version sync invariant** — `.githooks/pre-push` requires `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` to have identical `version` fields at push time. Forgetting one will fail the push silently from a sub-thread. T43 must touch both
- **Skill caching by version** — pre-push comment notes "Claude Code / Codex serve a stale version-keyed cache". Phase 3 changes will not be picked up by clients until version bump merges. This means manual /plan runs in T39-T41 must use the freshly-bumped plugin or a `cache_dir` override
- **Settings docs_path mismatch** — `.pmos/settings.yaml` has `docs_path: docs/pmos/` but the spec for this feature lives at `docs/features/...`. The plan saves alongside the spec (same folder). Don't try to "correct" the settings — that's an unrelated cleanup and would invalidate the user's existing folder
- **No root build/test command** — repo has no `package.json`, `pyproject.toml`, or `Makefile`. Verification is grep-based + bash lint scripts only. There is no test runner to invoke. Every task's "test" is a bash assertion or grep
- **AskUserQuestion option cap** — the AskUserQuestion tool caps at 4 options per question. The current spec's option enumerations (FR-41a low-risk classes (a)-(f), high-risk (a)-(g)) are documentation, not UI batches; do not try to render them as options
- **Pipeline-setup inline lint scope** — `tools/lint-pipeline-setup-inline.sh:23` hardcodes the list `(requirements spec plan execute verify wireframes prototype)`. /plan v2 doesn't add a skill, so the list stays fixed
- **Pre-existing simulate-spec trace** — `docs/features/2026-05-08_plan-skill-redesign/simulate-spec/2026-05-08-trace.md` exists. Spec FR-51 says /plan reads `02_simulate-spec_*.md` directly in feature folder; this trace is in a subfolder, so the FR doesn't fire. Do not promote it to top-level

### Stack signals

- **None observed at repo root.** Repo is bash + markdown + git. Verification harness will be bash + awk + grep + diff. Reference for `_shared/stacks/<stack>.md` content (the deliverable for Phase 1) comes from each stack's own ecosystem docs (npm, pip, cargo, etc.), NOT from this repo. Phase 2 greenfield substitute (FR-91) does not apply — Phase 1 deliverables are reference material themselves

---

## Prerequisites

- Working tree clean on `main` before starting Phase 1 (verification: `git status --porcelain` returns empty)
- Pre-push hook installed (`.githooks/pre-push`) — verification: `git config core.hooksPath` returns `.githooks` OR the hook is symlinked into `.git/hooks/`
- `tools/lint-pipeline-setup-inline.sh` currently green — verification: `bash plugins/pmos-toolkit/tools/lint-pipeline-setup-inline.sh` exits 0
- Plugin version 2.23.0 in both manifests (baseline) — verification: `grep '"version"' plugins/pmos-toolkit/.claude-plugin/plugin.json plugins/pmos-toolkit/.codex-plugin/plugin.json` shows 2.23.0 in both
- `awk`, `diff`, `grep`, `bash` >= 4 available on PATH (used by lint scripts)

---

## File Map

> Generated index — tasks are source of truth for per-file actions.

| Action | File | Responsibility | Task |
|--------|------|---------------|------|
| Create | `plugins/pmos-toolkit/skills/_shared/platform-strings.md` | Per-platform phrasing for closing offer + skill-invocation refs (CC/Gemini/Copilot/Codex) | T1 |
| Create | `plugins/pmos-toolkit/skills/_shared/stacks/README.md` | Index + extension policy for stack files | T2 |
| Create | `plugins/pmos-toolkit/skills/_shared/stacks/npm.md` | T0 prereqs, lint/test/format, HTTP smoke, common preamble | T3 |
| Create | `plugins/pmos-toolkit/skills/_shared/stacks/pnpm.md` | Same shape; pnpm-specific commands | T3 |
| Create | `plugins/pmos-toolkit/skills/_shared/stacks/yarn-classic.md` | Same shape; yarn-classic commands | T3 |
| Create | `plugins/pmos-toolkit/skills/_shared/stacks/yarn-berry.md` | Same shape; yarn-berry commands | T3 |
| Create | `plugins/pmos-toolkit/skills/_shared/stacks/bun.md` | Same shape; bun commands | T3 |
| Create | `plugins/pmos-toolkit/skills/_shared/stacks/python.md` | pytest/poetry/uv variants | T4 |
| Create | `plugins/pmos-toolkit/skills/_shared/stacks/rails.md` | RSpec/minitest variants | T5 |
| Create | `plugins/pmos-toolkit/skills/_shared/stacks/go.md` | `go test`, `gofmt -l` | T6 |
| Create | `plugins/pmos-toolkit/skills/_shared/stacks/static.md` | Build, file-existence, link-check | T7 |
| Modify | `plugins/pmos-toolkit/skills/_shared/pipeline-setup.md` | Cross-reference slug derivation (FR-63) and folder picker (FR-65) from /plan | T8 |
| Create | `plugins/pmos-toolkit/tools/lint-stack-libraries.sh` | Each stack file has required sections | T9 |
| Create | `plugins/pmos-toolkit/tools/lint-platform-strings.sh` | platform-strings.md has all 4 platforms × 2 keys | T10 |
| Create | `plugins/pmos-toolkit/tools/lint-js-stack-preambles.sh` | Diff common preamble across 5 JS stack files | T11 |
| Modify | `plugins/pmos-toolkit/skills/spec/SKILL.md` (Tier 1 template, ~ll. 224-257) | Frontmatter contract: tier/type/feature/date/status/requirements | T13 |
| Modify | `plugins/pmos-toolkit/skills/spec/SKILL.md` (Tier 2 template, ~ll. 259-310) | Same frontmatter contract | T14 |
| Modify | `plugins/pmos-toolkit/skills/spec/SKILL.md` (Tier 3 template, ~ll. 312-487) | Same frontmatter contract | T15 |
| Modify | `plugins/pmos-toolkit/skills/spec/SKILL.md` (Phase 5 + Document Guidelines) | Anchor emission rule + dedupe | T16 |
| Modify | `plugins/pmos-toolkit/skills/spec/SKILL.md` (Phase 1 Tier Detection) | `type:` detection from /backlog or AskUserQuestion | T17 |
| Modify | `plugins/pmos-toolkit/skills/spec/SKILL.md` (Phase 7 Universal Exit Checklist) | Frontmatter completeness gate | T18 |
| Create | `tests/fixtures/specs/tier1_bugfix.md` | Fixture spec, tier 1 + bugfix | T19 |
| Create | `tests/fixtures/specs/tier2_enhancement.md` | Fixture spec, tier 2 | T19 |
| Create | `tests/fixtures/specs/tier3_feature.md` | Fixture spec, tier 3 + wireframes folder | T19 |
| Modify | `plugins/pmos-toolkit/skills/backlog/schema.md` | Extend `type` enum to 6 values | T21 |
| Modify | `plugins/pmos-toolkit/skills/backlog/inference-heuristics.md` | Keyword tables for new enum values | T22 |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md` (Phase 0) | Lockfile + backup + frontmatter validation | T23 |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md` (Phase 1) | Tier read, simulate-spec read, --fix-from branch | T24 |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md` (Phase 2) | Stack detection, peer-plan glob, greenfield, wireframes | T25 |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md` (Phase 3, plan template) | Frontmatter contract, tier-aware sections | T26 |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md` (Phase 3, per-task fields) | FR-30..FR-39 + T0 + bug-fix TDD | T27 |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md` (Phase 3, structural sections) | Risks/Rollback/File Map/Mermaid/phase-verify | T28 |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md` (Phase 4) | Hard cap, auto-classify, blind subagent, skip list | T29 |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md` (Phase 4 + 5 fold) | Broken-ref detection, Phase 5 absorbed | T30 |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md` (Operational modes) | Edit/Replan/Append, --non-interactive, folder picker | T31 |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md` (Closing + backlog) | Platform-aware closing, /backlog write-back | T32 |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md` (Sidecar contracts) | 03_plan_review.md, 03_plan_auto.md, atomic writes | T33 |
| Modify | `plugins/pmos-toolkit/skills/execute/SKILL.md` (Phase 1) | Read commit_cadence from plan frontmatter | T34 |
| Modify | `plugins/pmos-toolkit/skills/execute/SKILL.md` (Phase 2) | Consume new task fields + back-compat shim | T35 |
| Modify | `plugins/pmos-toolkit/skills/execute/SKILL.md` (Phase 2 + 3) | Defect file write per §7.5 + lifecycle delete | T36 |
| Modify | `plugins/pmos-toolkit/skills/execute/SKILL.md` (Phase 1) | contract_version read + warn-on-mismatch | T37 |
| Create | `tests/fixtures/repos/node/package.json` + `package-lock.json` | npm-stack signal | T38 |
| Create | `tests/fixtures/repos/python/requirements.txt` | python-stack signal | T38 |
| Create | `tests/fixtures/repos/go/go.mod` | go-stack signal | T38 |
| Modify | `plugins/pmos-toolkit/.claude-plugin/plugin.json` | version 2.23.0 → 2.24.0 | T43 |
| Modify | `plugins/pmos-toolkit/.codex-plugin/plugin.json` | version 2.23.0 → 2.24.0 (synced) | T43 |
| Modify | `CHANGELOG.md` | v2.24.0 entry | T43 |

---

## Risks

| # | Risk | Likelihood | Impact | Severity | Mitigation | Mitigation in: |
|---|------|-----------|--------|----------|-----------|----------------|
| R1 | /plan v2 sidecar writes (atomic rename per FR-43c) cross-device-rename failures on exotic filesystems | Low | Medium | Low | Use same-directory tempfile to keep rename intra-device | T33 Step 4 |
| R2 | Phase 3 atomic merge ships with a back-compat shim (S8) that silently masks misconfigured plans | Medium | Medium | Medium | Per-task stderr WARN lines (P5 decision); explicit FR-110 fail-fast on dependency cycles / missing required fields (not optional ones) | T35, TN /verify step 7 |
| R3 | /spec frontmatter changes (Phase 2) merge before /plan v2 (Phase 3); old /plan reads new spec | Low | Low | Low | Spec frontmatter additions are additive (new keys); old /plan ignores unknown frontmatter keys (verified by reading current plan/SKILL.md Phase 1 — uses Read+resolve, not strict YAML parse) | Inherent in current plan code; T20 verifies |
| R4 | Test-fixture specs at `tests/fixtures/specs/` get picked up by some glob in pipeline tooling | Low | Medium | Low | Place under repo-root `tests/`, not `docs/pmos/features/`. Verify with `grep -r "tests/fixtures" plugins/pmos-toolkit/` returns no glob users | T19 Step 4 |
| R5 | JS-stack preamble drift between npm/pnpm/yarn-classic/yarn-berry/bun if maintainer edits one but not others | Medium | Low | Low | T11 lint catches drift; CI runs lint on every PR; document policy in `_shared/stacks/README.md` | T2, T11 |
| R6 | Plugin version not bumped in both manifests → pre-push hook silently fails sub-thread → cache stays stale | Low | High | Medium | T43 explicitly touches both files; TN step 14 greps both for `2.24.0`; pre-push hook itself is the secondary catch | T43, TN step 14 |
| R7 | Auto-derived anchors (P3) collide on repeat headings — e.g., two H2 "Edge Cases" subsections | Low | Medium | Low | Dedupe rule: append `-2`, `-3`, ... to colliding slugs in document order. Document in T16 | T16 |
| R8 | `/plan --fix-from` invoked when no defect file exists | Low | Low | Low | Phase 1 reads defect file; if absent, refuses with platform-aware "No defect file found at <path>. /execute writes this file on planning defect; nothing to fix from." | T24 Step 5 |

---

## Rollback

This plan creates new files (shared resources, lints, fixtures) and modifies skill markdown. No data migrations, no database changes, no production deploys. Rollback is git-based:

- **If TN final verification fails after Phase 3 atomic merge:** `git revert <merge-commit>` returns the repo to v2.23.0 state. The version bump (T43) ensures clients immediately fall back to the cached v2.23.0 skills
- **If a single skill regresses post-merge:** revert just that file via `git checkout <pre-merge-sha> -- plugins/pmos-toolkit/skills/<skill>/SKILL.md` and ship a v2.24.1 patch
- **If /spec frontmatter changes (Phase 2) cause downstream failures before Phase 3 ships:** `git revert` the Phase 2 commits; v1 /plan continues to ignore frontmatter additions (R3)
- **No defect-file or sidecar cleanup needed on rollback** — those are user-feature-folder-local artifacts; reverting code does not require touching user state

---

## Tasks

## Phase 1: Shared Resources

> Lands first per FR-115 step 1 — back-compat: v1 /plan ignores these new files; v1 /spec ignores them. After Phase 1 merges, /plan v1 still runs unchanged. Phase boundary triggers full /verify.

### T1: Create `_shared/platform-strings.md`

**Goal:** Ship the per-platform phrasing source so /plan v2 and other skills can adapt closing offers and skill-invocation references without inline conditionals.
**Spec refs:** FR-71, FR-72, §7.4
**Depends on:** none
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:**
- Create: `plugins/pmos-toolkit/skills/_shared/platform-strings.md`

**Steps:**

- [ ] Step 1: Write a failing assertion script at `/tmp/check_platform_strings.sh`:
  ```bash
  set -e
  F=plugins/pmos-toolkit/skills/_shared/platform-strings.md
  test -f "$F" || { echo "FAIL: $F missing"; exit 1; }
  for p in claude-code gemini copilot codex; do
    grep -q "^## $p$" "$F" || { echo "FAIL: missing platform $p"; exit 1; }
    awk -v p="$p" '$0=="## "p{f=1;next} /^## /{f=0} f' "$F" \
      | grep -q '^- `execute_invocation`:' || { echo "FAIL: $p missing execute_invocation"; exit 1; }
    awk -v p="$p" '$0=="## "p{f=1;next} /^## /{f=0} f' "$F" \
      | grep -q '^- `skill_reference`:' || { echo "FAIL: $p missing skill_reference"; exit 1; }
  done
  echo PASS
  ```

- [ ] Step 2: Run the test — expected: FAIL with "FAIL: <path> missing"
  Run: `bash /tmp/check_platform_strings.sh`
  Expected: exits non-zero, prints `FAIL: plugins/pmos-toolkit/skills/_shared/platform-strings.md missing`

- [ ] Step 3: Create the file with structured per-platform sections. Required content shape (prescriptive — fill in per-platform values from each platform's docs):
  ```markdown
  # Platform Strings

  Per-platform phrasing for closing offers, skill invocation references, and error prefixes. Consumers read by H2 platform name; each platform exposes the keys below as bulleted entries.

  ## claude-code
  - `execute_invocation`: `/pmos-toolkit:execute`
  - `skill_reference`: `/pmos-toolkit:<skill>`
  - `error_prefix`: `[/plan]`

  ## gemini
  - `execute_invocation`: activate the execute skill
  - `skill_reference`: activate the <skill> skill
  - `error_prefix`: [plan]

  ## copilot
  - `execute_invocation`: use the execute skill
  - `skill_reference`: use the <skill> skill
  - `error_prefix`: plan:

  ## codex
  - `execute_invocation`: run the execute skill
  - `skill_reference`: run the <skill> skill
  - `error_prefix`: [plan]
  ```

- [ ] Step 4: Re-run the test — expected: PASS
  Run: `bash /tmp/check_platform_strings.sh`
  Expected: prints `PASS`, exits 0

- [ ] Step 5: Verify behavioral parse via grep — confirm /plan-style consumers can extract a platform's keys:
  Run: `awk '$0=="## claude-code"{f=1;next} /^## /{f=0} f' plugins/pmos-toolkit/skills/_shared/platform-strings.md | grep '^- \`execute_invocation\`:'`
  Expected: prints `` - `execute_invocation`: `/pmos-toolkit:execute` ``

- [ ] Step 6: Commit
  ```bash
  git add plugins/pmos-toolkit/skills/_shared/platform-strings.md
  git commit -m "feat(T1): add _shared/platform-strings.md for cross-platform phrasing"
  ```

**Inline verification:**
- `bash /tmp/check_platform_strings.sh` exits 0
- `grep -c '^## ' plugins/pmos-toolkit/skills/_shared/platform-strings.md` returns ≥ 4

---

### T2: Create `_shared/stacks/` directory + extension policy README

**Goal:** Establish the stack-library directory and document the extension/maintenance policy referenced by FR-11 and Open Question #3 from the spec.
**Spec refs:** FR-11, §7.4, Open Q #3
**Depends on:** none
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:**
- Create: `plugins/pmos-toolkit/skills/_shared/stacks/README.md`

**Steps:**

- [ ] Step 1: Write failing assertion at `/tmp/check_stacks_dir.sh`:
  ```bash
  set -e
  D=plugins/pmos-toolkit/skills/_shared/stacks
  test -d "$D" || { echo "FAIL: dir $D missing"; exit 1; }
  test -f "$D/README.md" || { echo "FAIL: README.md missing"; exit 1; }
  grep -q '^## Maintenance Policy' "$D/README.md" || { echo "FAIL: missing Maintenance Policy section"; exit 1; }
  grep -q '^## Required Sections per Stack File' "$D/README.md" || { echo "FAIL: missing Required Sections list"; exit 1; }
  echo PASS
  ```

- [ ] Step 2: Run the test — expected: FAIL with "dir … missing"
  Run: `bash /tmp/check_stacks_dir.sh`
  Expected: exits non-zero

- [ ] Step 3: Create directory and README:
  ```bash
  mkdir -p plugins/pmos-toolkit/skills/_shared/stacks
  ```
  Then write `_shared/stacks/README.md` with sections: `## Purpose`, `## Required Sections per Stack File` (lists: Prereq commands, Lint/test commands, API smoke patterns, Common fixture patterns), `## JS-Stack Common Preamble` (states the 5 JS files share an identical preamble enforced by `tools/lint-js-stack-preambles.sh`), `## Maintenance Policy` (resolves Open Q #3 — toolkit maintainer owns major-version bumps; community PRs welcome for stack-conventions evolution; preamble changes require touching all 5 JS files; CI lint catches drift).

- [ ] Step 4: Re-run test — expected: PASS
  Run: `bash /tmp/check_stacks_dir.sh`
  Expected: prints `PASS`

- [ ] Step 5: Commit
  ```bash
  git add plugins/pmos-toolkit/skills/_shared/stacks/README.md
  git commit -m "feat(T2): add _shared/stacks/ directory + maintenance policy README"
  ```

**Inline verification:**
- `bash /tmp/check_stacks_dir.sh` exits 0

---

### T3: Create the 5 JS-stack files with shared preamble

**Goal:** Ship `_shared/stacks/{npm,pnpm,yarn-classic,yarn-berry,bun}.md` with the four required sections and an identical "Common Preamble" region.
**Spec refs:** FR-10, FR-10a, FR-11, §7.4
**Depends on:** T2
**Idempotent:** yes — re-running overwrites file content deterministically; if files already exist with correct content, no-op; if drifted, this task is the place to repair them
**TDD:** yes — new-feature
**Files:**
- Create: `plugins/pmos-toolkit/skills/_shared/stacks/npm.md`
- Create: `plugins/pmos-toolkit/skills/_shared/stacks/pnpm.md`
- Create: `plugins/pmos-toolkit/skills/_shared/stacks/yarn-classic.md`
- Create: `plugins/pmos-toolkit/skills/_shared/stacks/yarn-berry.md`
- Create: `plugins/pmos-toolkit/skills/_shared/stacks/bun.md`

**Steps:**

- [ ] Step 1: Write failing assertion at `/tmp/check_js_stacks.sh`:
  ```bash
  set -e
  D=plugins/pmos-toolkit/skills/_shared/stacks
  for s in npm pnpm yarn-classic yarn-berry bun; do
    F="$D/$s.md"
    test -f "$F" || { echo "FAIL: $F missing"; exit 1; }
    for sec in '## Prereq Commands' '## Lint/Test Commands' '## API Smoke Patterns' '## Common Fixture Patterns' '## Common Preamble'; do
      grep -qF "$sec" "$F" || { echo "FAIL: $s.md missing section: $sec"; exit 1; }
    done
  done
  echo PASS
  ```

- [ ] Step 2: Run test — expected: FAIL
  Run: `bash /tmp/check_js_stacks.sh`
  Expected: exits non-zero

- [ ] Step 3: Author the **Common Preamble** block once, e.g.:
  ```markdown
  ## Common Preamble

  This stack file inherits a shared preamble across the JS family (npm, pnpm, yarn-classic, yarn-berry, bun). The preamble describes node version detection (`.nvmrc` → `.node-version` → `engines.node` in package.json), TypeScript-vs-JavaScript detection (presence of `tsconfig.json`), and the convention that all install commands run with `--frozen-lockfile`-equivalent flags by default in CI contexts. CI lint `tools/lint-js-stack-preambles.sh` enforces byte-equivalence of this section across all five files.
  ```
  (One paragraph is sufficient. The exact prose is the lock — implementor picks final wording, but it lives in this preamble for all 5 files.)

- [ ] Step 4: Author each file with all five sections. Per-stack content:
  - **npm.md:** `## Prereq Commands` (`node --version`, `npm --version`, `npm ci`); `## Lint/Test Commands` (project-defined; cite `npm run lint`, `npm test`); `## API Smoke Patterns` (HTTP via `node --eval` `fetch`, GraphQL via curl, gRPC via `grpcurl` if installed); `## Common Fixture Patterns` (Jest/Vitest/node:test fixtures inline); `## Common Preamble` (verbatim from Step 3)
  - **pnpm.md:** same shape, prereq uses `pnpm install --frozen-lockfile`; cite `pnpm run` for scripts
  - **yarn-classic.md:** prereq `yarn install --frozen-lockfile`; scripts via `yarn <name>`
  - **yarn-berry.md:** prereq `yarn install --immutable`; mention zero-installs caveat (`.yarn/cache` may be checked in)
  - **bun.md:** prereq `bun install --frozen-lockfile`; scripts via `bun run`; tests via `bun test`

- [ ] Step 5: Re-run test — expected: PASS
  Run: `bash /tmp/check_js_stacks.sh`
  Expected: prints `PASS`

- [ ] Step 6: Verify common-preamble equivalence preview (the actual lint script lands in T11 — this is a hand-check):
  Run: `for s in npm pnpm yarn-classic yarn-berry bun; do awk '/^## Common Preamble/{f=1;next} /^## /{f=0} f' plugins/pmos-toolkit/skills/_shared/stacks/$s.md | sha256sum; done`
  Expected: all five sha256 sums identical

- [ ] Step 7: Commit
  ```bash
  git add plugins/pmos-toolkit/skills/_shared/stacks/{npm,pnpm,yarn-classic,yarn-berry,bun}.md
  git commit -m "feat(T3): add 5 JS-stack files with shared preamble"
  ```

**Inline verification:**
- `bash /tmp/check_js_stacks.sh` exits 0
- All 5 preamble sha256 sums identical (Step 6)

---

### T4: Create `_shared/stacks/python.md`

**Goal:** Ship the python stack file with the four required sections plus pytest/poetry/uv variants.
**Spec refs:** FR-11, §7.4
**Depends on:** T2
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:**
- Create: `plugins/pmos-toolkit/skills/_shared/stacks/python.md`

**Steps:**

- [ ] Step 1: Write failing assertion at `/tmp/check_python_stack.sh`:
  ```bash
  set -e
  F=plugins/pmos-toolkit/skills/_shared/stacks/python.md
  test -f "$F" || { echo "FAIL: $F missing"; exit 1; }
  for sec in '## Prereq Commands' '## Lint/Test Commands' '## API Smoke Patterns' '## Common Fixture Patterns'; do
    grep -qF "$sec" "$F" || { echo "FAIL: missing section: $sec"; exit 1; }
  done
  for variant in pytest poetry uv; do
    grep -qiE "\\b$variant\\b" "$F" || { echo "FAIL: missing variant: $variant"; exit 1; }
  done
  echo PASS
  ```

- [ ] Step 2: Run — expected FAIL
  Run: `bash /tmp/check_python_stack.sh`
  Expected: exits non-zero with "FAIL: <path> missing"

- [ ] Step 3: Author `python.md` with the four sections. Cover detection signals (presence of `pyproject.toml` → poetry/uv/hatch; `requirements.txt` → pip; `Pipfile` → pipenv); commands per variant: `pytest`, `ruff check`, `ruff format --check`, `pip install -e .` / `poetry install` / `uv sync`; HTTP smoke via `python -m http.client` or `curl` + `python -m json.tool`; common fixtures = pytest fixtures with `tmp_path`, `monkeypatch`.

- [ ] Step 4: Re-run — expected PASS
  Run: `bash /tmp/check_python_stack.sh`
  Expected: prints `PASS`

- [ ] Step 5: Commit
  ```bash
  git add plugins/pmos-toolkit/skills/_shared/stacks/python.md
  git commit -m "feat(T4): add _shared/stacks/python.md (pytest/poetry/uv)"
  ```

**Inline verification:**
- `bash /tmp/check_python_stack.sh` exits 0

---

### T5: Create `_shared/stacks/rails.md`

**Goal:** Ship the rails stack file with RSpec/minitest variants.
**Spec refs:** FR-11, §7.4
**Depends on:** T2
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:**
- Create: `plugins/pmos-toolkit/skills/_shared/stacks/rails.md`

**Steps:**

- [ ] Step 1: Write `/tmp/check_rails_stack.sh` — same shape as T4 but checks for variants `rspec` and `minitest`, sections same four.

- [ ] Step 2: Run — expected FAIL
  Run: `bash /tmp/check_rails_stack.sh`
  Expected: exits non-zero

- [ ] Step 3: Author `rails.md`. Detection: `Gemfile` + `bin/rails` present. Prereqs: `bundle install --frozen`, `bin/rails db:prepare`. Lint/test: `bundle exec rubocop`, `bundle exec rspec` OR `bin/rails test`. API smoke: HTTP via `curl`; assert JSON with `jq` if available else `python -m json.tool`. Fixtures: factory_bot OR rails fixtures.

- [ ] Step 4: Re-run — expected PASS

- [ ] Step 5: Commit
  ```bash
  git add plugins/pmos-toolkit/skills/_shared/stacks/rails.md
  git commit -m "feat(T5): add _shared/stacks/rails.md (rspec/minitest)"
  ```

**Inline verification:**
- `bash /tmp/check_rails_stack.sh` exits 0

---

### T6: Create `_shared/stacks/go.md`

**Goal:** Ship the go stack file.
**Spec refs:** FR-11, §7.4
**Depends on:** T2
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:**
- Create: `plugins/pmos-toolkit/skills/_shared/stacks/go.md`

**Steps:**

- [ ] Step 1: Write `/tmp/check_go_stack.sh` checking same four sections + presence of `go test` and `gofmt -l`.

- [ ] Step 2: Run — expected FAIL.

- [ ] Step 3: Author `go.md`. Detection: `go.mod`. Prereqs: `go version`, `go mod download`. Lint/test: `gofmt -l .` (no output = clean), `go vet ./...`, `go test ./...`. API smoke: HTTP via curl; gRPC via grpcurl. Fixtures: table-driven tests + `testdata/` directory convention.

- [ ] Step 4: Re-run — expected PASS.

- [ ] Step 5: Commit
  ```bash
  git add plugins/pmos-toolkit/skills/_shared/stacks/go.md
  git commit -m "feat(T6): add _shared/stacks/go.md"
  ```

**Inline verification:**
- `bash /tmp/check_go_stack.sh` exits 0

---

### T7: Create `_shared/stacks/static.md`

**Goal:** Ship the static-site stack file.
**Spec refs:** FR-11, §7.4
**Depends on:** T2
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:**
- Create: `plugins/pmos-toolkit/skills/_shared/stacks/static.md`

**Steps:**

- [ ] Step 1: Write `/tmp/check_static_stack.sh` — same four sections + presence of strings `link-check` and `file-existence` and `build`.

- [ ] Step 2: Run — expected FAIL.

- [ ] Step 3: Author `static.md`. Detection: presence of `_config.yml` (Jekyll), `astro.config.*`, `eleventy.config.*`, `hugo.toml`, OR plain HTML at root. Prereqs: depends on builder (cite per-builder). Lint/test: HTML validator (e.g., `tidy -e`), link checker (`linkchecker` or `lychee`). API smoke: file-existence via `test -f` for expected build artifacts. Fixtures: snapshot HTML files in `tests/fixtures/`.

- [ ] Step 4: Re-run — expected PASS.

- [ ] Step 5: Commit
  ```bash
  git add plugins/pmos-toolkit/skills/_shared/stacks/static.md
  git commit -m "feat(T7): add _shared/stacks/static.md"
  ```

**Inline verification:**
- `bash /tmp/check_static_stack.sh` exits 0

---

### T8: Update `_shared/pipeline-setup.md` cross-references

**Goal:** Document FR-63 (centralized slug derivation) and FR-65 (folder picker) by adding cross-reference back-pointers from /plan into Section A.3 and B; existing logic stays — this task is documentation alignment only.
**Spec refs:** FR-63, FR-65
**Depends on:** none
**Idempotent:** yes
**TDD:** yes — new-feature (the test verifies the cross-reference exists)
**Files:**
- Modify: `plugins/pmos-toolkit/skills/_shared/pipeline-setup.md` (Section A.3 and Section B intro)

**Steps:**

- [ ] Step 1: Write `/tmp/check_pipeline_setup_xref.sh`:
  ```bash
  set -e
  F=plugins/pmos-toolkit/skills/_shared/pipeline-setup.md
  grep -q 'FR-63' "$F" || { echo "FAIL: missing FR-63 cross-ref"; exit 1; }
  grep -q 'FR-65' "$F" || { echo "FAIL: missing FR-65 cross-ref"; exit 1; }
  bash plugins/pmos-toolkit/tools/lint-pipeline-setup-inline.sh > /dev/null || { echo "FAIL: pipeline inline lint regressed"; exit 1; }
  echo PASS
  ```

- [ ] Step 2: Run — expected FAIL on FR-63 cross-ref.

- [ ] Step 3: Add a one-line italicized cross-reference at the END of Section A.3 (after the existing 5-step algorithm): `*Cited by /plan v2 FR-63 — slug derivation is centralized here; pipeline skills MUST NOT re-implement.*` Add a similar one-liner at the END of Section B.4 step 1: `*Cited by /plan v2 FR-65 — folder picker offers (recently-modified | best slug-match | create-new | Other) per spec §8.5.*` Do not modify the canonical Phase 0 block (between the markers) — that would fail `lint-pipeline-setup-inline.sh`.

- [ ] Step 4: Re-run — expected PASS.

- [ ] Step 5: Commit
  ```bash
  git add plugins/pmos-toolkit/skills/_shared/pipeline-setup.md
  git commit -m "feat(T8): cross-reference /plan v2 FR-63 and FR-65 in pipeline-setup.md"
  ```

**Inline verification:**
- `bash /tmp/check_pipeline_setup_xref.sh` exits 0
- `bash plugins/pmos-toolkit/tools/lint-pipeline-setup-inline.sh` exits 0 (canonical block untouched)

---

### T9: CI lint — `tools/lint-stack-libraries.sh`

**Goal:** Lint each `_shared/stacks/<stack>.md` for the four required sections; bash + awk style matching `lint-pipeline-setup-inline.sh`.
**Spec refs:** §10.1
**Depends on:** T3, T4, T5, T6, T7
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:**
- Create: `plugins/pmos-toolkit/tools/lint-stack-libraries.sh`

**Steps:**

- [ ] Step 1: Write a meta-test at `/tmp/check_lint_stack_libs.sh` that exercises the script against (a) the current correct state — must exit 0, and (b) a synthetic missing-file case — must exit 1:
  ```bash
  set -e
  S=plugins/pmos-toolkit/tools/lint-stack-libraries.sh
  test -x "$S" || { echo "FAIL: $S not executable"; exit 1; }
  bash "$S" > /tmp/lint_stack_libs.out
  grep -q '^PASS:' /tmp/lint_stack_libs.out || { echo "FAIL: green case did not print PASS"; exit 1; }
  # Synthetic break — temporarily move npm.md aside; expect FAIL
  mv plugins/pmos-toolkit/skills/_shared/stacks/npm.md /tmp/npm.md.bak
  ! bash "$S" > /tmp/lint_stack_libs.fail.out
  grep -q '^FAIL:' /tmp/lint_stack_libs.fail.out || { mv /tmp/npm.md.bak plugins/pmos-toolkit/skills/_shared/stacks/npm.md; echo "FAIL: missing-file case did not produce FAIL"; exit 1; }
  mv /tmp/npm.md.bak plugins/pmos-toolkit/skills/_shared/stacks/npm.md
  echo PASS
  ```

- [ ] Step 2: Run — expected FAIL ("not executable" / file missing).

- [ ] Step 3: Author the lint script. Mirror `lint-pipeline-setup-inline.sh` style: `set -euo pipefail`, resolve `PLUGIN_ROOT` from script dir, iterate STACKS=(npm pnpm yarn-classic yarn-berry bun python rails go static), for each: assert file exists and contains each of `## Prereq Commands`, `## Lint/Test Commands`, `## API Smoke Patterns`, `## Common Fixture Patterns`. Print `OK: <stack>` on green, `DRIFT: <stack> missing <section>` on miss. Exit 0 / 1 / 2 with same semantics. `chmod +x` the script.

- [ ] Step 4: Re-run — expected PASS.

- [ ] Step 5: Commit
  ```bash
  git add plugins/pmos-toolkit/tools/lint-stack-libraries.sh
  git commit -m "feat(T9): add lint-stack-libraries.sh CI script"
  ```

**Inline verification:**
- `bash /tmp/check_lint_stack_libs.sh` exits 0
- `bash plugins/pmos-toolkit/tools/lint-stack-libraries.sh` prints `PASS:` and exits 0

---

### T10: CI lint — `tools/lint-platform-strings.sh`

**Goal:** Lint `_shared/platform-strings.md` for all 4 platforms × 2 mandatory keys (`execute_invocation`, `skill_reference`).
**Spec refs:** §10.1
**Depends on:** T1
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:**
- Create: `plugins/pmos-toolkit/tools/lint-platform-strings.sh`

**Steps:**

- [ ] Step 1: Write `/tmp/check_lint_platform_strings.sh` — green case + synthetic break (temporarily delete `gemini` H2, expect script to fail, restore). Same shape as T9 Step 1.

- [ ] Step 2: Run — expected FAIL.

- [ ] Step 3: Author the script. Iterate PLATFORMS=(claude-code gemini copilot codex), for each: assert `^## $platform$` line exists and the section (between this H2 and the next H2 or EOF) contains both `` `execute_invocation`: `` and `` `skill_reference`: ``. `chmod +x`.

- [ ] Step 4: Re-run — expected PASS.

- [ ] Step 5: Commit
  ```bash
  git add plugins/pmos-toolkit/tools/lint-platform-strings.sh
  git commit -m "feat(T10): add lint-platform-strings.sh CI script"
  ```

**Inline verification:**
- `bash /tmp/check_lint_platform_strings.sh` exits 0

---

### T11: CI lint — `tools/lint-js-stack-preambles.sh`

**Goal:** Diff the `## Common Preamble` region across the 5 JS-stack files; fail on any drift.
**Spec refs:** FR-11, §10.1
**Depends on:** T3
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:**
- Create: `plugins/pmos-toolkit/tools/lint-js-stack-preambles.sh`

**Steps:**

- [ ] Step 1: Write `/tmp/check_lint_js_preambles.sh` exercising green + synthetic break (append " " to `bun.md`'s preamble, expect FAIL, restore from git).

- [ ] Step 2: Run — expected FAIL.

- [ ] Step 3: Author the script. Extract the `## Common Preamble` block from each of the 5 files via the same awk pattern used in `lint-pipeline-setup-inline.sh`. Compute sha256 (or a normalized text comparison ignoring trailing whitespace) of each. If any differ, print a diff against the canonical (use `npm.md` as canonical) and exit 1. `chmod +x`.

- [ ] Step 4: Re-run — expected PASS.

- [ ] Step 5: Commit
  ```bash
  git add plugins/pmos-toolkit/tools/lint-js-stack-preambles.sh
  git commit -m "feat(T11): add lint-js-stack-preambles.sh CI script"
  ```

**Inline verification:**
- `bash /tmp/check_lint_js_preambles.sh` exits 0

---

### T12: Phase 1 boundary verification

**Goal:** Run all four lint scripts together; confirm Phase 1 deliverables are coherent. This task triggers full /verify on Phase 1 per FR-26a.
**Spec refs:** FR-26a, §10.1
**Depends on:** T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11
**Idempotent:** yes
**Requires state from:** T1, T2, T3, T4, T5, T6, T7, T8, T9, T10, T11
**TDD:** no — verification-only task; covered by Steps 1-3
**Files:**
- (none — verification only)

**Steps:**

- [ ] Step 1: Run all four lint scripts:
  ```bash
  bash plugins/pmos-toolkit/tools/lint-pipeline-setup-inline.sh
  bash plugins/pmos-toolkit/tools/lint-stack-libraries.sh
  bash plugins/pmos-toolkit/tools/lint-platform-strings.sh
  bash plugins/pmos-toolkit/tools/lint-js-stack-preambles.sh
  ```
  Expected: each prints `PASS:` and exits 0.

- [ ] Step 2: Confirm filesystem inventory:
  ```bash
  ls plugins/pmos-toolkit/skills/_shared/stacks/{npm,pnpm,yarn-classic,yarn-berry,bun,python,rails,go,static}.md
  ls plugins/pmos-toolkit/skills/_shared/platform-strings.md
  ls plugins/pmos-toolkit/tools/lint-{stack-libraries,platform-strings,js-stack-preambles}.sh
  ```
  Expected: all files present, no `ls` error.

- [ ] Step 3: Confirm Phase 1 changes do NOT touch v1-consumed files:
  ```bash
  git diff --name-only main...HEAD | grep -E 'plugins/pmos-toolkit/skills/(plan|spec|execute|backlog)/SKILL\.md|backlog/(schema|inference-heuristics)\.md' && echo "FAIL: Phase 1 touched v1-consumed file" || echo "OK: Phase 1 isolated to new files + cross-ref-only changes"
  ```
  Expected: prints `OK: Phase 1 isolated …` (i.e., grep finds nothing — only `pipeline-setup.md` was edited, which is documentation cross-ref per T8).

  *Note: `pipeline-setup.md` IS modified by T8, but only with cross-reference comments outside the canonical Phase 0 block — verified by Step 1's `lint-pipeline-setup-inline.sh` exit 0.*

- [ ] Step 4: Phase boundary commit (no code change, marker for /execute Phase 2.5):
  ```bash
  git commit --allow-empty -m "chore(T12): Phase 1 (shared resources) complete — boundary marker"
  ```

**Inline verification:**
- All 4 lint scripts exit 0 (Step 1)
- All 9 stack files + platform-strings.md + 3 new lint scripts present (Step 2)
- Phase 1 isolated to additive new files (Step 3)

---


