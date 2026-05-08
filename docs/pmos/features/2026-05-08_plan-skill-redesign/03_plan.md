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
| P9 | T23 implements regex-based frontmatter parse rather than a YAML library; error message format becomes "Spec frontmatter parse error: line N: \<observed token\>" rather than the spec FR-50a wording "\<yaml-lib message\>" | (a) Regex parse + revised error wording (chosen), (b) Halt this plan and edit spec FR-50a first, (c) Use the verbatim spec wording even though no yaml-lib exists | Skills run inside the Claude Code / Codex / Gemini harnesses with no dynamic library access — there is no Python yaml or js-yaml available at runtime. Implementing FR-50a literally would require introducing a runtime dependency that the skill harness can't provide. (a) preserves the spec's intent (refuse on malformed frontmatter, name the line) without inventing a fictional yaml-lib invocation. The deviation is bounded to the error message wording; behavior (refuse on malformed YAML) is preserved. Spec FR-50a should be revised in a follow-up edit but does not block this plan |

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
| Create | `tests/fixtures/specs/wireframes/01_dashboard.html` | Stub wireframe — exercises FR-16 positive coverage | T19 |
| Create | `tests/fixtures/specs/wireframes/02_settings.html` | Stub wireframe — exercises FR-16 positive coverage | T19 |
| Modify | `plugins/pmos-toolkit/skills/backlog/schema.md` | Extend `type` enum to 6 values | T21 |
| Modify | `plugins/pmos-toolkit/skills/backlog/inference-heuristics.md` | Keyword tables for new enum values | T22 |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md` (Phase 0) | Lockfile + backup + frontmatter validation | T23 |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md` (Phase 1) | Tier read, simulate-spec read, --fix-from branch | T24 |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md` (Phase 2) | Stack detection, peer-plan glob, greenfield, wireframes | T25 |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md` (Phase 3, plan template — frontmatter + tier gates + Done-when) | FR-20, FR-22 family, tier gates | T26a |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md` (Phase 3, Code Study + readability + glossary + tests-illustrative) | FR-100..103 | T26b |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md` (Phase 3, per-task fields) | FR-30..FR-39 + T0 + bug-fix TDD | T27 |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md` (Phase 3, structural sections + TN cleanup triggers) | Risks/Rollback/File Map/Mermaid/phase-verify + FR-92 | T28 |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md` (Phase 4 — hard cap + auto-classify) | FR-40, 40a, 41, 41a, 41b | T29a |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md` (Phase 4 — blind subagent) | FR-42, 42a, 42b | T29b |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md` (Phase 4 — Skip List sidecar + Phase 5 fold) | FR-43, 43a-d, 44, 45, 46 | T29c |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md` (Phase 4 — broken-ref + drift) | FR-31a, 31b | T30 |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md` (Operational modes — Edit/Replan/Append) | FR-60, 60a | T31a |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md` (Operational modes — non-interactive + picker + learnings) | FR-61, 61a, 64, 65 | T31b |
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

## Phase 2: /spec frontmatter + section anchors

> Lands second per FR-115 step 2. Back-compat: /plan v1 reads frontmatter loosely; new YAML keys are ignored. Phase boundary triggers full /verify.

### T13: Add frontmatter contract to /spec Tier 1 template

**Goal:** Replace the Tier 1 template's prose `**Date:** / **Status:** / **Requirements:**` header with a YAML frontmatter block requiring `tier: 1`, `type: bugfix|enhancement`, `feature`, `date`, `status`, `requirements`.
**Spec refs:** S6, FR-01, FR-05, §7.1
**Depends on:** none (cross-phase: relies on Phase 1 not touching spec/SKILL.md — verified at T12 Step 3)
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:** Modify `plugins/pmos-toolkit/skills/spec/SKILL.md` (Tier 1 template region, ~ll. 226-257)

**Steps:**

- [ ] Step 1: Write `/tmp/check_spec_t1_frontmatter.sh`:
  ```bash
  set -e
  F=plugins/pmos-toolkit/skills/spec/SKILL.md
  awk '/^### Tier 1 Template/{f=1} /^### Tier 2 Template/{f=0} f' "$F" > /tmp/t1.txt
  for k in 'tier: 1' 'type:' 'feature:' 'date:' 'status:' 'requirements:'; do
    grep -qF "$k" /tmp/t1.txt || { echo "FAIL: Tier 1 missing key: $k"; exit 1; }
  done
  echo PASS
  ```
- [ ] Step 2: Run — expected FAIL.
- [ ] Step 3: Replace Tier 1 template header with `---\ntier: 1\ntype: bugfix\nfeature: <slug>\ndate: YYYY-MM-DD\nstatus: Draft\nrequirements: <relative path to 01_requirements.md>\n---\n\n# <Bug/Fix Name> — Spec`. Keep Sections 1-6 unchanged.
- [ ] Step 4: Re-run — expected PASS. Sanity: `grep -c '^### Tier' plugins/pmos-toolkit/skills/spec/SKILL.md` returns 3.
- [ ] Step 5: Commit `git commit -m "feat(T13): /spec Tier 1 template emits frontmatter contract"`.

**Inline verification:** `/tmp/check_spec_t1_frontmatter.sh` exits 0.

---

### T14: Add frontmatter contract to /spec Tier 2 template

**Goal:** Same as T13 for Tier 2 (`tier: 2`, `type: enhancement`).
**Spec refs:** S6, FR-01, §7.1
**Depends on:** T13
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:** Modify `spec/SKILL.md` Tier 2 template

**Steps:**

- [ ] Step 1: Write `/tmp/check_spec_t2_frontmatter.sh`:
  ```bash
  set -e
  F=plugins/pmos-toolkit/skills/spec/SKILL.md
  awk '/^### Tier 2 Template/{f=1} /^### Tier 3 Template/{f=0} f' "$F" > /tmp/t2.txt
  for k in 'tier: 2' 'type:' 'feature:' 'date:' 'status:' 'requirements:'; do
    grep -qF "$k" /tmp/t2.txt || { echo "FAIL: Tier 2 missing key: $k"; exit 1; }
  done
  echo PASS
  ```
- [ ] Step 2: Run — expected FAIL.
- [ ] Step 3: Replace Tier 2 header with `---\ntier: 2\ntype: enhancement\nfeature: <slug>\ndate: YYYY-MM-DD\nstatus: Draft\nrequirements: <path>\n---\n\n# <Feature Name> — Spec`.
- [ ] Step 4: Re-run — expected PASS.
- [ ] Step 5: Commit `git commit -m "feat(T14): /spec Tier 2 template emits frontmatter contract"`.

**Inline verification:** `/tmp/check_spec_t2_frontmatter.sh` exits 0.

---

### T15: Add frontmatter contract to /spec Tier 3 template

**Goal:** Same for Tier 3 (`tier: 3`, `type: feature`).
**Spec refs:** S6, FR-01, §7.1
**Depends on:** T14
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:** Modify `spec/SKILL.md` Tier 3 template

**Steps:**

- [ ] Step 1: Write `/tmp/check_spec_t3_frontmatter.sh`:
  ```bash
  set -e
  F=plugins/pmos-toolkit/skills/spec/SKILL.md
  awk '/^### Tier 3 Template/{f=1} /^### Document Guidelines/{f=0} f' "$F" > /tmp/t3.txt
  for k in 'tier: 3' 'type:' 'feature:' 'date:' 'status:' 'requirements:'; do
    grep -qF "$k" /tmp/t3.txt || { echo "FAIL: Tier 3 missing key: $k"; exit 1; }
  done
  echo PASS
  ```
- [ ] Step 2: Run — expected FAIL.
- [ ] Step 3: Replace Tier 3 header with `---\ntier: 3\ntype: feature\nfeature: <slug>\ndate: YYYY-MM-DD\nstatus: Draft\nrequirements: <path>\n---\n\n# <Feature Name> — Spec`.
- [ ] Step 4: Re-run — expected PASS.
- [ ] Step 5: Commit `git commit -m "feat(T15): /spec Tier 3 template emits frontmatter contract"`.

**Inline verification:** `/tmp/check_spec_t3_frontmatter.sh` exits 0.

---

### T16: Anchor emission rule

**Goal:** Document the auto-derived-anchor rule (P3): H2/H3 emit `{#kebab-anchor}` markers; collisions get `-2/-3/...` suffix in document order.
**Spec refs:** FR-31, FR-31a, §7.1, P3
**Depends on:** T15
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:** Modify `spec/SKILL.md` — add `### Anchor Emission Rule` subsection between templates and `### Document Guidelines`

**Steps:**

- [ ] Step 1: Write `/tmp/check_spec_anchor_rule.sh`:
  ```bash
  set -e
  F=plugins/pmos-toolkit/skills/spec/SKILL.md
  grep -q '^### Anchor Emission Rule' "$F" || { echo "FAIL: subsection missing"; exit 1; }
  awk '/^### Anchor Emission Rule/{f=1} /^### Document Guidelines/{f=0} f' "$F" > /tmp/anchor.txt
  grep -q 'kebab' /tmp/anchor.txt && grep -q -- '-2' /tmp/anchor.txt && grep -q '{#' /tmp/anchor.txt || { echo "FAIL: rule incomplete"; exit 1; }
  echo PASS
  ```
- [ ] Step 2: Run — expected FAIL.
- [ ] Step 3: Insert section. Required content describes: kebab-case auto-derive (lowercase, alphanum + hyphens, runs of non-alphanum collapsed); collision dedupe with `-2/-3/...` suffix; rationale (FR-31 cites anchors, FR-31a hard-fails broken refs at /plan Phase 4); show `## Heading Text {#heading-text}` example.
- [ ] Step 4: Re-run — expected PASS.
- [ ] Step 5: Commit `git commit -m "feat(T16): /spec emits stable kebab-anchors at H2/H3"`.

**Inline verification:** `/tmp/check_spec_anchor_rule.sh` exits 0.

---

### T17: /spec Phase 1 — `type:` detection

**Goal:** Update /spec Phase 1 to detect `type` from `--backlog <id>` (read item's `type:` per FR-112) or via AskUserQuestion fallback.
**Spec refs:** S5, FR-05, FR-112, §7.1
**Depends on:** T16
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:** Modify `spec/SKILL.md` Phase 1 (~ll. 62-79)

**Steps:**

- [ ] Step 1: Write `/tmp/check_spec_type_detection.sh`:
  ```bash
  set -e
  F=plugins/pmos-toolkit/skills/spec/SKILL.md
  awk '/^## Phase 1: Intake & Tier Detection/{f=1} /^## Phase 2:/{f=0} f' "$F" > /tmp/p1.txt
  grep -q 'type:' /tmp/p1.txt && grep -qE '(backlog|--backlog)' /tmp/p1.txt && grep -qE 'AskUserQuestion' /tmp/p1.txt || { echo "FAIL: type detection rule incomplete"; exit 1; }
  echo PASS
  ```
- [ ] Step 2: Run — expected FAIL.
- [ ] Step 3: Add a numbered step 5 to Phase 1 with the precedence rule: `--backlog` item type (with mapping `bug→bugfix`, `feature→feature`, `enhancement→enhancement`, `chore/docs→enhancement`, `spike→feature`) → requirements doc `type:` tag → AskUserQuestion fallback. Persist in spec frontmatter; note that /plan FR-104a permits per-task TDD overrides logged as decisions.
- [ ] Step 4: Re-run — expected PASS.
- [ ] Step 5: Commit `git commit -m "feat(T17): /spec Phase 1 detects type from backlog or AskUserQuestion"`.

**Inline verification:** `/tmp/check_spec_type_detection.sh` exits 0.

---

### T18: /spec Phase 6/7 — frontmatter completeness gate

**Goal:** Add frontmatter-completeness check to Universal Exit Checklist + validation gate at Phase 7 promotion.
**Spec refs:** S6, §7.1
**Depends on:** T17
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:** Modify `spec/SKILL.md` Phase 6 Universal Exit Checklist + Phase 7 promotion ritual

**Steps:**

- [ ] Step 1: Write `/tmp/check_spec_exit_frontmatter.sh`:
  ```bash
  set -e
  F=plugins/pmos-toolkit/skills/spec/SKILL.md
  awk '/^### Universal Exit Checklist/{f=1; next} /^---$/{if(f)exit} f' "$F" > /tmp/exit.txt
  grep -qiE 'frontmatter.*complete|tier.*type.*feature' /tmp/exit.txt || { echo "FAIL: exit checklist does not gate on frontmatter"; exit 1; }
  awk '/^## Phase 7:/{f=1} /^## Phase 8:/{f=0} f' "$F" > /tmp/p7.txt
  grep -qi 'frontmatter' /tmp/p7.txt || { echo "FAIL: Phase 7 does not validate frontmatter"; exit 1; }
  echo PASS
  ```
- [ ] Step 2: Run — expected FAIL.
- [ ] Step 3: Insert new row into Universal Exit Checklist table between rows 10 and 11: `| 10b | Frontmatter contract complete: tier, type, feature, date, status, requirements all present and non-empty | Never N/A |`. Add to Phase 7 just before status promotion: `**Frontmatter validation gate:** before promoting status, re-read frontmatter; verify keys tier/type/feature/date/requirements present and non-empty. If any missing, halt with platform-aware error sourced via _shared/platform-strings.md (e.g., "[/spec] Cannot promote — frontmatter missing required key: <key>"). Do NOT promote.`
- [ ] Step 4: Re-run — expected PASS.
- [ ] Step 5: Commit `git commit -m "feat(T18): /spec exit gate validates frontmatter completeness"`.

**Inline verification:** `/tmp/check_spec_exit_frontmatter.sh` exits 0.

---

### T19: Test-fixture specs

**Goal:** Create three fixture specs at `tests/fixtures/specs/` (per P4) for Phase 3 integration tests.
**Spec refs:** §10.2, P4, Open Q #4
**Depends on:** T18
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:** Create `tests/fixtures/specs/{tier1_bugfix,tier2_enhancement,tier3_feature,README}.md` AND `tests/fixtures/specs/wireframes/{01_dashboard,02_settings}.html`

**Steps:**

- [ ] Step 1: Write `/tmp/check_fixture_specs.sh`:
  ```bash
  set -e
  D=tests/fixtures/specs
  for f in tier1_bugfix tier2_enhancement tier3_feature; do
    F="$D/$f.md"
    test -f "$F" || { echo "FAIL: $F missing"; exit 1; }
    head -20 "$F" | grep -q '^---$' && head -20 "$F" | grep -q '^tier:' && head -20 "$F" | grep -q '^type:' && head -20 "$F" | grep -q '^feature:' || { echo "FAIL: $F frontmatter incomplete"; exit 1; }
  done
  test -f "$D/README.md" || { echo "FAIL: README missing"; exit 1; }
  test -f "$D/wireframes/01_dashboard.html" || { echo "FAIL: wireframes/01_dashboard.html missing"; exit 1; }
  test -f "$D/wireframes/02_settings.html" || { echo "FAIL: wireframes/02_settings.html missing"; exit 1; }
  grep -q 'wireframes/01_dashboard\.html' "$D/tier3_feature.md" || { echo "FAIL: tier3 fixture does not reference 01_dashboard wireframe"; exit 1; }
  echo PASS
  ```
- [ ] Step 2: Run — expected FAIL.
- [ ] Step 3: Author the three fixtures (minimum content per tier):
  - `tier1_bugfix.md`: ~30 lines, single FR (e.g., "trim leading whitespace in user names"), Edge Cases table with 1 row, Testing Strategy with one assertion.
  - `tier2_enhancement.md`: ~80 lines, 3 FRs covering an additive feature (CSV-export endpoint), no wireframes.
  - `tier3_feature.md`: ~200 lines, 8 FRs, NFR table, API contract section, 3-component sequence diagram, references `wireframes/01_dashboard.html` AND `wireframes/02_settings.html` from FR text (positive UI signal — exercises FR-16 bidirectional coverage at T40).
  - `wireframes/01_dashboard.html` + `wireframes/02_settings.html`: stub HTML5 documents (~10 lines each — `<!doctype html><html><head><title>...</title></head><body><h1>Dashboard</h1><p>placeholder</p></body></html>`). Their presence + the spec's UI signal is what triggers FR-16 positive-case coverage during T40.
  - `README.md`: 5 lines explaining "Test fixtures consumed by /plan v2 integration tests (T39-T41). Not discovered by folder-pickers because they live under tests/, not docs/pmos/features/. The wireframes/ folder exercises FR-16 bidirectional coverage."
- [ ] Step 4: Re-run — expected PASS.
- [ ] Step 5: Verify no glob points at `tests/`:
  ```bash
  grep -r 'tests/fixtures' plugins/pmos-toolkit/skills/_shared/pipeline-setup.md plugins/pmos-toolkit/skills/plan/SKILL.md plugins/pmos-toolkit/skills/spec/SKILL.md
  ```
  Expected: no output.
- [ ] Step 6: Commit `git add tests/fixtures/specs/ && git commit -m "feat(T19): add tier1/2/3 fixture specs for /plan integration tests"`.

**Inline verification:** `/tmp/check_fixture_specs.sh` exits 0; no glob points at `tests/`.

---

### T20: Phase 2 boundary verification

**Goal:** Validate Phase 2 deliverables; confirm /plan v1 still parses new spec frontmatter.
**Spec refs:** S3, FR-26a, §10.3
**Depends on:** T13, T14, T15, T16, T17, T18, T19
**Requires state from:** T13–T19
**Idempotent:** yes
**TDD:** no — verification only
**Files:** (none)

**Steps:**

- [ ] Step 1: Re-run all Phase 1 lints — confirm no regression. All 4 must exit 0.
- [ ] Step 2: Confirm spec/SKILL.md modifications: `grep -c '^tier:' plugins/pmos-toolkit/skills/spec/SKILL.md` ≥ 3; `grep -q '^### Anchor Emission Rule'` succeeds.
- [ ] Step 3: Confirm fixtures have well-formed frontmatter:
  ```bash
  for f in tests/fixtures/specs/tier{1,2,3}_*.md; do
    awk 'NR==1{if($0!="---")exit 1} /^---$/{c++; if(c==2)exit 0}' "$f" || { echo "FAIL: $f frontmatter not closed"; exit 1; }
  done
  echo PASS
  ```
- [ ] Step 4: Back-compat probe (synthetic v1 reader):
  ```bash
  awk '/^---$/{c++;next} c==1' tests/fixtures/specs/tier3_feature.md | head -10
  grep -q '^requirements:' tests/fixtures/specs/tier3_feature.md
  ```
  Expected: prints frontmatter; `grep -q` exits 0.
- [ ] Step 5: Phase boundary commit: `git commit --allow-empty -m "chore(T20): Phase 2 (/spec frontmatter+anchors) complete — boundary marker"`.

**Inline verification:** Steps 1–4 pass.

---

## Phase 3: /plan v2 + /execute v2 + /backlog (atomic merge)

> Lands third per FR-115 step 3. All three changes ship in one minor-version bump (T43) so /plan v2 starts emitting new task fields exactly when /execute v2 starts consuming them. Phase boundary triggers full /verify.

### T21: Extend /backlog `type` enum

**Goal:** Add `enhancement`, `chore`, `docs`, `spike` to the `type` enum in `backlog/schema.md` (current values: `feature`, `bug`, `tech-debt`, `idea`).
**Spec refs:** FR-112, §7.3
**Depends on:** none (cross-phase: relies on Phase 2 not touching backlog/ — verified at T20 boundary)
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:** Modify `plugins/pmos-toolkit/skills/backlog/schema.md` (the type-enum row in the validation table)

**Steps:**

- [ ] Step 1: Write `/tmp/check_backlog_type_enum.sh`:
  ```bash
  set -e
  F=plugins/pmos-toolkit/skills/backlog/schema.md
  for v in feature bug tech-debt idea enhancement chore docs spike; do
    grep -q "\`$v\`" "$F" || { echo "FAIL: type enum missing: $v"; exit 1; }
  done
  echo PASS
  ```
- [ ] Step 2: Run — expected FAIL on `enhancement`.
- [ ] Step 3: In the enum-validation table row for `type`, replace `\`feature\`, \`bug\`, \`tech-debt\`, \`idea\`` with `\`feature\`, \`enhancement\`, \`bug\`, \`tech-debt\`, \`chore\`, \`docs\`, \`idea\`, \`spike\``. Note: spec FR-112 lists 6 values; we keep `tech-debt` and `idea` from current schema (additive — no value removed) so back-compat is preserved. Document the FR-112 mapping at /spec read-time (T17 already covers this) — `chore`/`docs` map to enhancement, `spike` to feature for /spec purposes.
- [ ] Step 4: Re-run — expected PASS.
- [ ] Step 5: Commit `git commit -m "feat(T21): extend /backlog type enum (enhancement, chore, docs, spike)"`.

**Inline verification:** `/tmp/check_backlog_type_enum.sh` exits 0.

---

### T22: Update /backlog inference heuristics

**Goal:** Add keyword tables in `backlog/inference-heuristics.md` for the new enum values so quick-capture (`/backlog add ...`) routes correctly.
**Spec refs:** FR-112
**Depends on:** T21
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:** Modify `plugins/pmos-toolkit/skills/backlog/inference-heuristics.md`

**Steps:**

- [ ] Step 1: Write `/tmp/check_backlog_heuristics.sh`:
  ```bash
  set -e
  F=plugins/pmos-toolkit/skills/backlog/inference-heuristics.md
  for kw in 'enhancement' 'chore' 'docs' 'spike'; do
    grep -qi "$kw" "$F" || { echo "FAIL: missing keyword class: $kw"; exit 1; }
  done
  echo PASS
  ```
- [ ] Step 2: Run — expected FAIL.
- [ ] Step 3: Add keyword sections (matching the existing style, which is keyword → type tables). Suggested keywords: `enhancement` ← "improve", "polish", "tune", "extend"; `chore` ← "cleanup", "rename", "reorganize", "tidy"; `docs` ← "doc", "readme", "comment", "document"; `spike` ← "spike", "investigate", "research", "explore", "prototype". Maintain the existing first-match-by-order rule. Place the new sections so `bug` and `feature` keywords still match first (preserve back-compat for the existing keyword catalog).
- [ ] Step 4: Re-run — expected PASS.
- [ ] Step 5: Commit `git commit -m "feat(T22): /backlog inference heuristics for new enum values"`.

**Inline verification:** `/tmp/check_backlog_heuristics.sh` exits 0.

---

### T23: /plan Phase 0 — lockfile + backup + frontmatter validation

**Goal:** Update /plan Phase 0 to acquire `.plan.lock` (FR-66), back up existing `03_plan.md` for cap-hit-abandon recovery (FR-67), and validate spec frontmatter (FR-50, FR-50a, E1).
**Spec refs:** FR-50, FR-50a, FR-66, FR-67, E1
**Depends on:** T22 (Phase 3 sequential start)
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:** Modify `plugins/pmos-toolkit/skills/plan/SKILL.md` Phase 0 (~ll. 43-58)

**Steps:**

- [ ] Step 1: Write `/tmp/check_plan_phase0.sh`:
  ```bash
  set -e
  F=plugins/pmos-toolkit/skills/plan/SKILL.md
  awk '/^## Phase 0:/{f=1} /^## Phase 1:/{f=0} f' "$F" > /tmp/plan_p0.txt
  grep -q '\.plan\.lock' /tmp/plan_p0.txt || { echo "FAIL: Phase 0 missing lockfile"; exit 1; }
  grep -q '03_plan_pre-cap-abandon' /tmp/plan_p0.txt || { echo "FAIL: Phase 0 missing backup rule"; exit 1; }
  grep -qE 'frontmatter.*tier|tier.*frontmatter' /tmp/plan_p0.txt || { echo "FAIL: Phase 0 missing frontmatter validation"; exit 1; }
  echo PASS
  ```
- [ ] Step 2: Run — expected FAIL.
- [ ] Step 3: Append new Phase 0 sub-steps AFTER the existing canonical inline block (do NOT modify the marked region — `lint-pipeline-setup-inline.sh` would fail). Add new step 7 `Acquire .plan.lock` (FR-66: write `{feature_folder}/.plan.lock` with `pid + ISO timestamp + skill_version`; if file exists, refuse with platform-aware error citing existing pid; release on completion or fatal error; `--force-lock` clears stale lock). Add step 8 `Back up existing plan` (FR-67: if `03_plan.md` exists, copy to `03_plan_pre-cap-abandon_<ISO>.md`; deleted on successful exit; restored on Cap-Hit Abandon disposition). Add step 9 `Validate spec frontmatter` (FR-50: refuse on missing spec with platform-aware error "No spec found at {path}. Run /spec first."; FR-50a *with deviation per Decision Log P9*: parse frontmatter via regex (extract YAML between leading `---` markers, line-by-line `^([a-z_]+):\s*(.*)$`); on malformed line refuse with platform-aware error "Spec frontmatter parse error at line N: <observed-token>. Fix YAML syntax and re-run." — wording differs from spec FR-50a's "<yaml-lib message>" because skills have no YAML library; behavior (refuse on malformed YAML, cite line) is preserved; E1: refuse with message "Spec at {path} missing required `tier:` frontmatter — re-run /spec to add it" if `tier` absent).
- [ ] Step 4: Re-run — expected PASS. Also re-run pipeline-setup lint to confirm canonical block untouched: `bash plugins/pmos-toolkit/tools/lint-pipeline-setup-inline.sh` exits 0.
- [ ] Step 5: Commit `git commit -m "feat(T23): /plan Phase 0 lockfile + backup + frontmatter validation"`.

**Inline verification:** `/tmp/check_plan_phase0.sh` exits 0; pipeline-inline lint still green.

---

### T24: /plan Phase 1 — tier read, simulate-spec, --fix-from

**Goal:** Update /plan Phase 1 to read `tier` from spec frontmatter (FR-01), surface `02_simulate-spec_*.md` findings (FR-51), and branch into `--fix-from <task-id>` mode reading `03_plan_defect_*.md` (FR-56, FR-67a, FR-67b).
**Spec refs:** FR-01, FR-51, FR-56, FR-67a, FR-67b, E10
**Depends on:** T23
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:** Modify `plan/SKILL.md` Phase 1 (~ll. 62-72)

**Steps:**

- [ ] Step 1: Write `/tmp/check_plan_phase1.sh` asserting Phase 1 mentions `tier` (read from frontmatter), `02_simulate-spec_`, `--fix-from`, `--widen-to`, `--cross-phase-downstream`, and `03_plan_defect_`.
- [ ] Step 2: Run — expected FAIL.
- [ ] Step 3: Rewrite Phase 1. Add a step to parse the spec frontmatter (re-using state from Phase 0 step 9), set `{tier}` and `{type}` variables for downstream phases. Add a step to glob `{feature_folder}/02_simulate-spec_*.md`; if present with unresolved findings, run §8.6 batched AskUserQuestion before proceeding. Add a `--fix-from <task-id>` branch: read `{feature_folder}/03_plan_defect_<task-id>.md` per §7.5; respect `--widen-to <upstream-task-id>` (FR-67a) and `--cross-phase-downstream` (FR-67b); enter Edit mode (FR-60) scoped per the flags.
- [ ] Step 4: Re-run — expected PASS.
- [ ] Step 5: Commit `git commit -m "feat(T24): /plan Phase 1 reads tier, surfaces simulate-spec, handles --fix-from"`.

**Inline verification:** `/tmp/check_plan_phase1.sh` exits 0.

---

### T25: /plan Phase 2 — stack detection, peer-plan glob, greenfield, wireframes

**Goal:** Update Phase 2 with stack detection (FR-10, FR-10a, FR-14, FR-14a), peer-plan conflict scan (FR-54, FR-54a), greenfield substitute (FR-91, E2), wireframe coverage (FR-16, FR-16a).
**Spec refs:** FR-10, FR-10a, FR-14, FR-14a, FR-16, FR-16a, FR-54, FR-54a, FR-91, E2, E3, E5
**Depends on:** T24
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:** Modify `plan/SKILL.md` Phase 2 (~ll. 76-97)

**Steps:**

- [ ] Step 1: Write `/tmp/check_plan_phase2.sh` asserting Phase 2 mentions stack-signal globs (manifest files: `package.json`, `Gemfile`, `go.mod`, `requirements.txt`, `Cargo.toml`, `pom.xml`, `composer.json`, `docker-compose.yml`, `Makefile`, `Dockerfile`), JS-stack lockfile disambiguation (`package-lock.json`, `yarn.lock`, `.yarnrc.yml`, `pnpm-lock.yaml`, `bun.lockb`), peer-plan glob with status filter (`Draft`, `Planned`, `Executing`), wireframe coverage rules (FR-16, FR-16a), AND the §8.7 spec-re-open AskUserQuestion shape with the literal options "Halt /plan and update spec" / "Document override in spec via Decision Log entry" / "Accept spec as-is despite divergence" / "Skip — not actually a conflict".
- [ ] Step 2: Run — expected FAIL.
- [ ] Step 3: Rewrite Phase 2. Insert new sub-step "Detect stack signals" (FR-10): glob manifest files, compute file-count weight per stack, log to "Stack signals" subsection of Code Study Notes (FR-100). Insert "JS lockfile disambiguation" sub-rule (FR-10a): map lockfile presence to npm/pnpm/yarn-classic/yarn-berry/bun; default npm + low-risk finding when no lockfile. Insert "Tiebreak" rule (FR-14a): equal weights → alphabetical; logged to `03_plan_auto.md` if `--non-interactive`. Insert "Greenfield substitute" (FR-91): when no signals, choose reference system; record in Code Study Notes. Insert "Peer-plan conflict scan" (FR-54): glob `{docs_path}/features/*/03_plan.md` (excluding current), filter by frontmatter status ∈ {Draft, Planned, Executing}, grep for impacted file paths; conflicts → Risks-table row + Open Question. Insert "Wireframe coverage" (FR-16): if `wireframes/` exists, every HTML file must be referenced by ≥1 task's Wireframe refs OR listed in `## Wireframes Out of Scope`. Insert "Vestigial wireframes" (FR-16a): no UI signal but folder exists → auto-emit Out-of-Scope subsection. Insert **"Spec re-open during planning" (§8.7, E13)**: when Phase 2 code study contradicts a spec decision (e.g., spec says "use Postgres" but `docker-compose.yml` shows MySQL), halt via `AskUserQuestion`: "Spec decision conflicts with repo standard. {Spec text} vs {observed standard}. How to resolve?" Options: **Halt /plan and update spec** (terminates this run; user re-runs /spec then /plan) / **Document override in spec via Decision Log entry** (open spec, add Decision Log entry citing the divergence with rationale, save, continue planning) / **Accept spec as-is despite divergence** (record decision in plan's Decision Log; proceed with spec's choice) / **Skip — not actually a conflict** (spec was correct; observation was misread). In `--non-interactive` mode this is a high-risk decision with no Recommended option → trigger FR-61a halt protocol (exit code 2 + write `03_plan_blocked.md`).
- [ ] Step 4: Re-run — expected PASS.
- [ ] Step 5: Commit `git commit -m "feat(T25): /plan Phase 2 stack detection, peer-plan scan, wireframe coverage"`.

**Inline verification:** `/tmp/check_plan_phase2.sh` exits 0.

---

### T26a: /plan Phase 3 — frontmatter contract + tier gates + Done-when rules

**Goal:** Replace the plan-doc template's prose header with a YAML frontmatter contract (FR-20) and document tier-aware section gating (FR-02/03/04, FR-22/22a/22b).
**Spec refs:** FR-02, FR-03, FR-04, FR-20, FR-22, FR-22a, FR-22b
**Depends on:** T25
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:** Modify `plan/SKILL.md` Phase 3 plan-doc template (~ll. 107-272) — header + tier-gates subsection

**Steps:**

- [ ] Step 1: Write `/tmp/check_plan_template_frontmatter.sh` asserting the plan template (between the example fenced block markers) starts with a YAML frontmatter block including all FR-20 keys: `tier`, `type`, `feature`, `spec_ref`, `requirements_ref`, `date`, `status`, `commit_cadence`, `contract_version`. Assert tier gates documented: `Tier 1` mentions reduced TN; `Tier 3` mentions full Risks. Assert Done-when rule: "lower bounds" mention + "Done-when walkthrough" mention.
- [ ] Step 2: Run — expected FAIL.
- [ ] Step 3: Replace the template's old `**Date:** / **Spec:** / **Requirements:**` prose header with a frontmatter block matching FR-20 keys exactly. Add a "Tier gates" subsection above the template that defines per-tier rules (FR-02/03/04): T1 = 1 task floor, no Decision-Log floor, no Phase 5, reduced TN (T0 + lint + test + Done-when walkthrough); T2 = ≥1 Decision Log entry, 1 review loop, optional Risks/Rollback, full TN; T3 = ≥3 Decision Log, 2-4 review loops, mandatory Risks, conditional Rollback, full TN. Add Done-when rules: lower-bounds + qualitative gates only (FR-22); ≥1 quantitative or executable assertion (FR-22a); "Done-when walkthrough" required at ALL tiers (FR-22b) — replaces the legacy "Manual spot check" line.
- [ ] Step 4: Re-run — expected PASS.
- [ ] Step 5: Commit `git commit -m "feat(T26a): /plan template — frontmatter + tier gates + Done-when"`.

**Inline verification:** `/tmp/check_plan_template_frontmatter.sh` exits 0.

---

### T26b: /plan Phase 3 — Code Study Notes + readability + glossary + tests-illustrative

**Goal:** Document Code Study Notes 4-subsection mandate (FR-100), readability promise (FR-101), glossary inheritance (FR-102), tests-illustrative rule (FR-103).
**Spec refs:** FR-100, FR-101, FR-102, FR-103
**Depends on:** T26ba
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:** Modify `plan/SKILL.md` Phase 3 — Code Study Notes section + readability/glossary/tests-illustrative rules

**Steps:**

- [ ] Step 1: Write `/tmp/check_plan_studynotes.sh`:
  ```bash
  set -e
  F=plugins/pmos-toolkit/skills/plan/SKILL.md
  for sec in 'Patterns to follow' 'Existing code to reuse' 'Constraints discovered' 'Stack signals'; do
    grep -qF "$sec" "$F" || { echo "FAIL: missing Code Study subsection: $sec"; exit 1; }
  done
  grep -qE 'codebase open but no prior conversation context' "$F" || { echo "FAIL: readability promise (FR-101) missing"; exit 1; }
  grep -qE 'cites?.*glossary|spec.*glossary' "$F" || { echo "FAIL: glossary inheritance (FR-102) missing"; exit 1; }
  grep -qE 'illustrative|shape preservation' "$F" || { echo "FAIL: tests-illustrative rule (FR-103) missing"; exit 1; }
  echo PASS
  ```
- [ ] Step 2: Run — expected FAIL.
- [ ] Step 3: Add the 4 Code Study subsections (FR-100): "Patterns to follow" (with `file:line` refs), "Existing code to reuse" (file paths), "Constraints discovered" (gotchas, hidden invariants), "Stack signals" (per FR-10) — each MAY be marked "None observed" but cannot be omitted. Update readability promise (FR-101): "executable by a developer with the codebase open but no prior conversation context. The plan inlines decisions and exact paths; the codebase remains source of truth for conventions." Add glossary inheritance (FR-102): plan inherits glossary from spec via citation (`see 02_spec.md §X for glossary`); plan introduces no new domain terms not already in the spec; Phase 4 check: novel domain term → finding (low-risk: re-word; high-risk: add to spec, halt). Add tests-illustrative rule (FR-103): plan tests are illustrative reference shape, not literal — /execute may adapt to host conventions (fixture names, framework version, helper signatures); Phase 4 checks shape preservation (same inputs/outputs/assertions), not literal text match.
- [ ] Step 4: Re-run — expected PASS.
- [ ] Step 5: Commit `git commit -m "feat(T26b): /plan Code Study + readability + glossary + tests-illustrative"`.

**Inline verification:** `/tmp/check_plan_studynotes.sh` exits 0.

---

### T27: /plan Phase 3 — per-task fields + T0 + bug-fix TDD

**Goal:** Update the per-task template to emit FR-30..FR-39 on every task; auto-generate T0 (FR-12, FR-12a) from detected stack; encode bug-fix TDD shape (FR-104, FR-104a, FR-105).
**Spec refs:** FR-12, FR-12a, FR-13, FR-30 through FR-39, FR-104, FR-104a, FR-105
**Depends on:** T26b
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:** Modify `plan/SKILL.md` per-task template region

**Steps:**

- [ ] Step 1: Write `/tmp/check_plan_task_fields.sh` asserting the task template includes the literal field labels: `**Goal:**`, `**Spec refs:**`, `**Wireframe refs:**`, `**Files:**`, `**Depends on:**`, `**Idempotent:**`, `**Requires state from:**`, `**TDD:**`, `**Data:**`, `**Steps:**`. Also assert template mentions T0 prereq, mandatory at all tiers (FR-12a), and bug-fix TDD 4-step shape (FR-104).
- [ ] Step 2: Run — expected FAIL on at least `**Depends on:**` and `**Idempotent:**`.
- [ ] Step 3: Rewrite the task template. Add the new field labels in the order documented in spec §6.4. Document `**Idempotent:**` validation (FR-35: non-idempotent → recovery substep required, Phase 4 hard-fail otherwise). Add T0 (Prerequisite Check) auto-generation rule (FR-12, FR-12a): T0 reads from detected `_shared/stacks/<stack>.md`; mandatory at all tiers; T1 reduced TN = "T0 + lint + test + Done-when walkthrough". Document FR-13: TN's API smoke step is generated from stack file, never `curl | json.tool` baked in. Document bug-fix TDD shape (FR-104): step 1 writes regression test reproducing bug, step 2 confirms test fails on pre-fix HEAD, step 3 implements fix, step 4 confirms test passes. Document three-signal precedence (FR-104a): per-task `**TDD:**` override → spec frontmatter `type:` → /backlog item `type=`; on override, emit Decision-Log entry. Document TDD-optional types (FR-105): pure refactors, config/IaC, CSS-only, prototype spikes, file moves — author states reason; Phase 4 reviews justification.
- [ ] Step 4: Re-run — expected PASS.
- [ ] Step 5: Commit `git commit -m "feat(T27): /plan per-task fields + T0 + bug-fix TDD shape"`.

**Inline verification:** `/tmp/check_plan_task_fields.sh` exits 0.

---

### T28: /plan Phase 3 — Risks/Rollback/File Map/Mermaid/phase-verify + TN cleanup triggers

**Goal:** Update structural sections: Risks-table coupling (FR-80, FR-81), File Map as generated index (FR-23, FR-24), auto-Mermaid execution-order diagram (FR-25), phase grouping & boundary verify (FR-26, FR-26a, FR-27, FR-90), and TN Cleanup trigger-based emission (FR-92).
**Spec refs:** FR-23, FR-24, FR-25, FR-26, FR-26a, FR-27, FR-80, FR-81, FR-90, FR-92
**Depends on:** T27
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:** Modify `plan/SKILL.md` Phase 3 (Risks, Rollback, File Map sections)

**Steps:**

- [ ] Step 1: Write `/tmp/check_plan_structural.sh` asserting Risks columns (Likelihood, Impact, Severity, Mitigation, Mitigation in:), Severity formula (FR-80), High-severity citation hard-fail (FR-81), File Map "generated index" language (FR-23), file-action verbs Create/Modify/Delete/Move/Rename/Test (FR-24), Move/Rename source-AND-destination rule, Mermaid auto-render rule (FR-25), phase-boundary /verify trigger (FR-26a), 30k-token soft cap (FR-90), AND TN Cleanup trigger-based emission (FR-92): rule body must mention all 4 triggers (files outside `src/`/`tests/` → temp-file cleanup; `--worktree` → container shutdown; feature flag added → flip line; user-facing change → docs-update line) AND the explicit "no `[only if applicable]` decoration" rule.
- [ ] Step 2: Run — expected FAIL.
- [ ] Step 3: Rewrite Risks/Rollback/File Map sections. For Risks: 5-column table including Severity = derived; Severity formula `any-H + no-L → High; any-H + any-L → Medium; both M → Medium; M + L → Low; both L → Low`; FR-81 hard-fails uncited High-severity at Phase 4. For File Map: "generated index pointing back to per-task `**Files:**` sections — tasks are source of truth (D12)"; verbs Create/Modify/Delete/Move/Rename/Test; Move/Rename rows show source AND destination. For Mermaid: ` ```mermaid ` fenced block auto-rendered from per-task `**Depends on:**` lines; emitted inline; rendered natively by GitHub. For phases: "deployable slices" rule (FR-27); phase-boundary /verify per FR-26a (intermediate boundaries each get /verify; last phase's verify IS the TN per FR-26); 30k-token soft cap per phase (FR-90). **For TN Cleanup (FR-92):** items are emitted only when their trigger fires. Triggers: any task creates files outside `src/`/`tests/` → emit "Remove temporary files and debug logging" line; `--worktree` flag was used during /execute → emit "Stop worktree containers if running: `docker compose -f docker-compose.worktree.yml -p <project> down`" line; any task adds a feature flag → emit "Flip feature flags if applicable" line; any user-facing change (UI signal per S4 OR docs files modified) → emit "Update documentation files (CLAUDE.md, changelogs, etc.)" line. Document the rule explicitly: NO `[only if applicable]` decoration in the rendered TN — if the trigger doesn't fire, omit the line entirely. Phase 4 structural check #11 (already in plan/SKILL.md) verifies trigger-correct emission.
- [ ] Step 4: Re-run — expected PASS.
- [ ] Step 5: Commit `git commit -m "feat(T28): /plan Risks/Rollback/File Map/Mermaid/phase-verify rules"`.

**Inline verification:** `/tmp/check_plan_structural.sh` exits 0.

---

### T29a: /plan Phase 4 — hard cap + auto-classification

**Goal:** Replace existing minimum-2-loops rule with hard cap of 4 (FR-40), document non-interactive cap-hit behavior (FR-40a), and document auto-classification rule (FR-41, FR-41a, FR-41b).
**Spec refs:** FR-40, FR-40a, FR-41, FR-41a, FR-41b, S7
**Depends on:** T28 (after T28; T29a opens Phase 4 series)
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:** Modify `plan/SKILL.md` Phase 4 — Loop Protocol + Findings Presentation Protocol regions (~ll. 392-421)

**Steps:**

- [ ] Step 1: Write `/tmp/check_plan_phase4_cap.sh`:
  ```bash
  set -e
  F=plugins/pmos-toolkit/skills/plan/SKILL.md
  awk '/^## Phase 4:/{f=1} /^## Phase 5:|^## Anti-Patterns/{f=0} f' "$F" > /tmp/p4.txt
  grep -qE 'cap.*4|hard cap of 4' /tmp/p4.txt || { echo "FAIL: hard cap 4 missing"; exit 1; }
  grep -qE 'Convergence Warning' /tmp/p4.txt || { echo "FAIL: Convergence Warning rule (FR-40a) missing"; exit 1; }
  grep -qE 'low-risk|high-risk' /tmp/p4.txt || { echo "FAIL: auto-classify rule missing"; exit 1; }
  grep -qE 'default.*high-risk|ambiguous.*high-risk' /tmp/p4.txt || { echo "FAIL: ambiguous default rule (FR-41a) missing"; exit 1; }
  echo PASS
  ```
- [ ] Step 2: Run — expected FAIL.
- [ ] Step 3: Replace minimum-2-loops rule with hard cap of 4 (FR-40). On cap-hit interactive: AskUserQuestion (continue / accept-and-proceed / abandon — abandon triggers FR-67 backup-restore). On cap-hit non-interactive: auto accept-and-proceed + write `## Convergence Warning` at TOP of `03_plan.md` body (FR-40a — explicitly state "in body, NOT sidecar — visibility to /verify and humans is the priority"). Document auto-classification (FR-41a) with full enumeration: **low-risk classes (a-f):** typos/grammar; missing exact command in verification step that already has expected output; lint-style suggestions; section-presence completions where content already exists elsewhere; wireframe-ref additions when wireframe file is unambiguous; cosmetic clarifications. **High-risk classes (a-g):** task split or merge; dependency-graph changes; new sections; decision-log reversals; TN-scope changes; tier-gated mandate shifts; frontmatter-contract or cross-skill-handshake changes. **Default for ambiguous: high-risk** (escalate, don't auto-apply). FR-41b: post-auto-apply re-validation deferred to Loop N+1 (avoid infinite-loop risk).
- [ ] Step 4: Re-run — expected PASS.
- [ ] Step 5: Commit `git commit -m "feat(T29a): /plan Phase 4 hard cap + auto-classification"`.

**Inline verification:** `/tmp/check_plan_phase4_cap.sh` exits 0.

---

### T29b: /plan Phase 4 — blind subagent dispatch

**Goal:** Document Loop 2 blind subagent (FR-42), 5-minute timeout (FR-42a), and nested-subagent skip rule (FR-42b).
**Spec refs:** FR-42, FR-42a, FR-42b
**Depends on:** T29ca
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:** Modify `plan/SKILL.md` Phase 4

**Steps:**

- [ ] Step 1: Write `/tmp/check_plan_phase4_blind.sh`:
  ```bash
  set -e
  F=plugins/pmos-toolkit/skills/plan/SKILL.md
  awk '/^## Phase 4:/{f=1} /^## Phase 5:|^## Anti-Patterns/{f=0} f' "$F" > /tmp/p4.txt
  grep -qE 'Loop 2|loop 2.*subagent|blind.*subagent' /tmp/p4.txt || { echo "FAIL: Loop 2 blind subagent missing"; exit 1; }
  grep -qE '5.minute|5-minute|five.minute|wall-clock' /tmp/p4.txt || { echo "FAIL: 5-minute timeout (FR-42a) missing"; exit 1; }
  grep -qE 'PMOS_NESTED|nested.*subagent' /tmp/p4.txt || { echo "FAIL: nested-subagent skip rule (FR-42b) missing"; exit 1; }
  echo PASS
  ```
- [ ] Step 2: Run — expected FAIL.
- [ ] Step 3: Document review-loop hierarchy: Loop 1 = self-review (structural + design checklists). Loop 2 (if reached) dispatches a fresh subagent (Explore or general-purpose) given only plan + spec for blind-review findings (FR-42); on platforms without subagents, Loop 2 falls back to a self-review with the prompt "review as if seeing this for the first time". 5-minute wall-clock timeout on the subagent dispatch (FR-42a); on timeout, skip subagent findings and emit a low-risk note in Review Log "Loop 2 subagent timed out; no blind-review findings consumed." Nested-subagent gating (FR-42b): when /plan itself runs as a subagent (detection: env marker `PMOS_NESTED=1`), do NOT dispatch the Loop-2 blind-review subagent — fall back to self-review on Loop 2.
- [ ] Step 4: Re-run — expected PASS.
- [ ] Step 5: Commit `git commit -m "feat(T29b): /plan Phase 4 blind subagent dispatch + timeout + nesting guard"`.

**Inline verification:** `/tmp/check_plan_phase4_blind.sh` exits 0.

---

### T29c: /plan Phase 4 — Skip List sidecar + Phase 5 fold

**Goal:** Document Skip List with hash integrity (FR-43, FR-43a-d), mode-aware preservation (FR-44), sidecar review log (FR-45), Phase 5 fold into Phase 4 (FR-46).
**Spec refs:** FR-43, FR-43a, FR-43b, FR-43c, FR-43d, FR-44, FR-45, FR-46
**Depends on:** T29cb
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:** Modify `plan/SKILL.md` Phase 4 + remove (or fold) Phase 5

**Steps:**

- [ ] Step 1: Write `/tmp/check_plan_phase4_skiplist.sh`:
  ```bash
  set -e
  F=plugins/pmos-toolkit/skills/plan/SKILL.md
  grep -qE 'entry_hash|SHA-?256' "$F" || { echo "FAIL: Skip List entry_hash (FR-43a) missing"; exit 1; }
  grep -qE 'Skip List heading|## Skip List heading|missing.*## Skip List' "$F" || { echo "FAIL: heading robustness (FR-43b) missing"; exit 1; }
  grep -qE 'tempfile.*rename|atomic|write-then-rename' "$F" || { echo "FAIL: atomic write rule (FR-43c) missing"; exit 1; }
  grep -qE 'pre-replan.*HH:MM:SS|HH:MM:SS|time-of-day suffix' "$F" || { echo "FAIL: archive heading uniqueness (FR-43d) missing"; exit 1; }
  grep -qE '03_plan_review\.md' "$F" || { echo "FAIL: sidecar review log location (FR-45) missing"; exit 1; }
  grep -qE 'Phase 5.*fold|fold.*Phase 5|Conciseness.*Blind.spot' "$F" || { echo "FAIL: Phase 5 fold (FR-46) missing"; exit 1; }
  echo PASS
  ```
- [ ] Step 2: Run — expected FAIL.
- [ ] Step 3: Document Skip List sidecar with frontmatter (`plan_ref`, `generated_at`, `skill_version`) and 3 required sections per §7.6: `## Skip List` (table: fingerprint | first_loop | last_seen_loop | rationale), `## Review Log` (table: loop | findings | dispositions | applied_at), optional `## Archived (pre-replan YYYY-MM-DD HH:MM:SS)` (FR-43d — time-of-day suffix prevents same-day Replan collisions). Document `entry_hash: SHA-256(fingerprint + rationale)` (FR-43a) — re-validate on read; tampered rows ignored with low-risk finding "Skip List entry hash mismatch — entry ignored". Document heading robustness (FR-43b): missing `## Skip List` → "no skip list active"; orphan entries ignored with low-risk finding. Document atomic write-then-rename (FR-43c): all sidecar writes use `tempfile + rename`; write failures abort /plan with platform-aware error rather than declaring loop done with stale state. Document mode-aware preservation (FR-44): Edit preserves Skip List; Replan archives under `## Archived (pre-replan ...)`; Append preserves. Sidecar location (FR-45): `{feature_folder}/03_plan_review.md` — NOT inline in 03_plan.md. Fold Phase 5 into Phase 4 (FR-46) — remove the standalone `## Phase 5: Final Review` heading; add "Conciseness" and "Blind spots" as new items in the Phase 4 design-critique checklist.
- [ ] Step 4: Re-run — expected PASS.
- [ ] Step 5: Commit `git commit -m "feat(T29c): /plan Phase 4 Skip List sidecar + Phase 5 fold"`.

**Inline verification:** `/tmp/check_plan_phase4_skiplist.sh` exits 0.

---

### T30: /plan Phase 4 — broken-ref + content-drift detection

**Goal:** Add anchor broken-ref hard-fail (FR-31a) and content-drift detection (FR-31b) to /plan Phase 4.
**Spec refs:** FR-31a, FR-31b
**Depends on:** T29c
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:** Modify `plan/SKILL.md` Phase 4 structural checklist

**Steps:**

- [ ] Step 1: Write `/tmp/check_plan_drift.sh` asserting Phase 4 structural checklist mentions: broken-ref detection on `**Spec refs:**`, broken-ref detection on `**Wireframe refs:**`, /verify Phase 4 re-runs both checks, SHA-256 content hash of cited spec sections recorded at Phase 0, re-hash at Phase 4, high-risk drift finding "spec content drift on FR-XX since plan started — re-validate task rationale".
- [ ] Step 2: Run — expected FAIL.
- [ ] Step 3: Add to Phase 4 structural checklist: "**Broken-ref detection.** For each task's `**Spec refs:**`, verify the cited anchor exists in the current `02_spec.md`. Hard-fail on miss. Same rule for `**Wireframe refs:**` — referenced HTML file in `wireframes/` must exist. /verify Phase 4 re-runs both checks before declaring done — catches drift introduced by post-plan spec or wireframe edits." Add: "**Content-drift detection.** Phase 0 records SHA-256 of each cited spec section's body (between its anchor heading and the next sibling heading). Phase 4 re-hashes the same sections; any task whose Spec refs cite a section whose hash changed produces a high-risk finding 'spec content drift on FR-XX since plan started — re-validate task rationale.' Catches mid-run spec edits that don't break anchors but invalidate task rationale."
- [ ] Step 4: Re-run — expected PASS.
- [ ] Step 5: Commit `git commit -m "feat(T30): /plan Phase 4 broken-ref + content-drift detection"`.

**Inline verification:** `/tmp/check_plan_drift.sh` exits 0.

---

### T31a: /plan operational modes — Edit/Replan/Append

**Goal:** Document Edit/Replan/Append modes (FR-60, FR-60a) including the fresh-IDs-no-reuse rule.
**Spec refs:** FR-60, FR-60a
**Depends on:** T30
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:** Modify `plan/SKILL.md` — add "Operational Modes: Edit / Replan / Append" subsection (anchored from Phase 1)

**Steps:**

- [ ] Step 1: Write `/tmp/check_plan_modes_basic.sh`:
  ```bash
  set -e
  F=plugins/pmos-toolkit/skills/plan/SKILL.md
  for mode in Edit Replan Append; do
    grep -qF "**$mode**" "$F" || grep -qE "^### .*$mode" "$F" || { echo "FAIL: mode $mode not documented"; exit 1; }
  done
  grep -qE 'fresh.*ID|no.*reuse|never reuse' "$F" || { echo "FAIL: Append fresh-ID rule (FR-60a) missing"; exit 1; }
  grep -qE 'Supersedes.*03_plan_pre-replan' "$F" || { echo "FAIL: Replan Supersedes header missing"; exit 1; }
  echo PASS
  ```
- [ ] Step 2: Run — expected FAIL.
- [ ] Step 3: Add an "Operational Modes" subsection. **Edit mode:** in-place fix, no review loops, no Supersedes header, Skip List preserved (FR-44). **Replan mode:** overwrite with `Supersedes: 03_plan_pre-replan_<ISO>.md` header, full Phase 4 loops, preserve completed-task refs, Skip List archived under `## Archived (pre-replan YYYY-MM-DD HH:MM:SS)` (FR-43d). **Append mode** (FR-60a): new tasks appended at end of existing task list with fresh IDs that never reuse any prior task ID (e.g., existing T1-T12 → new T13, T14, ... regardless of gaps); each new task's `**Depends on:**` may reference any existing task ID; Phase 4 review loop is scoped to (a) the new tasks AND (b) any existing task whose dependency graph the new tasks alter; Skip-List dedupe scope: fingerprints whose source-task-ID is in the reviewed scope are dedupe candidates; entries from out-of-scope tasks remain inert.
- [ ] Step 4: Re-run — expected PASS.
- [ ] Step 5: Commit `git commit -m "feat(T31a): /plan operational modes (Edit/Replan/Append)"`.

**Inline verification:** `/tmp/check_plan_modes_basic.sh` exits 0.

---

### T31b: /plan non-interactive + folder picker + learnings

**Goal:** Document `--non-interactive` flag (FR-61, FR-61a), folder picker (FR-65), learnings layering (FR-64).
**Spec refs:** FR-61, FR-61a, FR-64, FR-65
**Depends on:** T31ba
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:** Modify `plan/SKILL.md` — extend the Operational Modes subsection + Phase 0 / Phase 1 picker logic

**Steps:**

- [ ] Step 1: Write `/tmp/check_plan_modes_advanced.sh`:
  ```bash
  set -e
  F=plugins/pmos-toolkit/skills/plan/SKILL.md
  grep -qE '\-\-non-interactive' "$F" || { echo "FAIL: --non-interactive flag missing"; exit 1; }
  grep -qE '03_plan_auto\.md' "$F" || { echo "FAIL: auto-decisions sidecar missing"; exit 1; }
  grep -qE 'exit code 2|exit 2' "$F" || { echo "FAIL: FR-61a exit code 2 missing"; exit 1; }
  grep -qE '03_plan_blocked\.md' "$F" || { echo "FAIL: 03_plan_blocked.md missing"; exit 1; }
  grep -qE 'most-recently-modified.*best.*slug|best.*slug.*most-recently' "$F" || grep -qE 'recently-modified|slug-match' "$F" || { echo "FAIL: folder picker (FR-65) missing"; exit 1; }
  grep -qE 'override.*true|repo-local.*wins' "$F" || { echo "FAIL: learnings layering (FR-64) missing"; exit 1; }
  echo PASS
  ```
- [ ] Step 2: Run — expected FAIL.
- [ ] Step 3: Add `--non-interactive` (FR-61): suppresses confirmation gates; auto-applies Recommended even on high-risk; auto-decisions persist to `{feature_folder}/03_plan_auto.md` (overwritten on every /plan run; not append) per §7.6 frontmatter+section schema. Plan body includes a one-line pointer near the top: "See `03_plan_auto.md` for N auto-decisions made during non-interactive run." Halt protocol (FR-61a): when a high-risk decision has no Recommended option (e.g., spec re-open per §8.7/E13), /plan in `--non-interactive` does NOT silently default; halts with exit code 2 + writes `{feature_folder}/03_plan_blocked.md` containing the blocking decision (one sentence), the conflict observed, and a recommended human action; no partial `03_plan.md` is written. Folder picker (FR-65) — 4 options: {most-recently-modified folder} (Recommended) / {best slug-match against spec H1} / Create-new-with-derived-slug `{slug}` / Other (free-form, partial-match fallback); non-interactive default = best-slug-match if exact slug exists, else create-new (high/low confidence respectively, logged to `03_plan_auto.md`). Learnings layering (FR-64): both `~/.pmos/learnings.md` (global) and `<repo_root>/.pmos/learnings.md` (repo-local) are read; on conflict repo-local wins; both can be overridden by skill body unless tagged `override: true`.
- [ ] Step 4: Re-run — expected PASS.
- [ ] Step 5: Commit `git commit -m "feat(T31b): /plan non-interactive + folder picker + learnings layering"`.

**Inline verification:** `/tmp/check_plan_modes_advanced.sh` exits 0.

---

### T32: /plan closing offer + platform-neutral TN + backlog write-back

**Goal:** Update closing offer to source phrasing from `_shared/platform-strings.md` (FR-71, FR-72); rewrite TN frontend smoke as platform-neutral verbs (FR-70); add wireframe-diff/UX-polish triggers (FR-73); add /backlog write-back retry (FR-52, FR-52a) and deferred-work auto-capture (FR-53).
**Spec refs:** FR-52, FR-52a, FR-53, FR-55, FR-70, FR-71, FR-72, FR-73
**Depends on:** T31b
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:** Modify `plan/SKILL.md` Phase 5 (closing offer) + Phase 3 plan template's TN section + Backlog Bridge subsection

**Steps:**

- [ ] Step 1: Write `/tmp/check_plan_closing_tn.sh` asserting: closing offer cites `_shared/platform-strings.md`, names three next steps (/execute, /grill, /simulate-spec) per FR-72; TN frontend smoke uses platform-neutral verbs (no unconditional Playwright outside CC-flavored block); UX polish + wireframe diff conditional on UI signal (FR-73); /backlog write-back retry up to 3 times with exponential backoff 1s/2s/4s (FR-52a); deferred-work auto-capture targets out-of-scope notices in `## Notices` section (FR-53).
- [ ] Step 2: Run — expected FAIL.
- [ ] Step 3: Update closing offer (Phase 5): source phrasing from `_shared/platform-strings.md`. Required output shape: "Spec complete. Run **{execute_invocation}** to implement, **/grill 03_plan.md** to stress-test the plan adversarially before executing, or **/simulate-spec** to re-validate the upstream spec against scenarios. Each next-step is independent — pick zero, one, or several." Update TN's frontend smoke to platform-neutral verbs (FR-70): "navigate to X, hard-reload, force error path Y, capture evidence". CC-only Playwright commands appear only in a CC-flavored fenced block. UX polish + wireframe diff (FR-73) emit only when `S4` UI-signal is true. Update Backlog Bridge subsection: write-back retry (FR-52a) — try `/backlog set` up to 3 times, exponential backoff 1s/2s/4s; on final failure, low-risk warning + "Re-run `/backlog set BG-X plan_doc=03_plan.md status=planned` manually". Deferred-work auto-capture (FR-53) targets out-of-scope notices in `## Notices` section, NOT deferred spec items (those remain Phase 4 hard-fail). FR-55: when `--backlog <id>` passed, Phase 4 checks every backlog AC maps to a task, TN line, OR `## Backlog Out-of-Scope` subsection.
- [ ] Step 4: Re-run — expected PASS.
- [ ] Step 5: Commit `git commit -m "feat(T32): /plan platform-neutral closing/TN + backlog write-back retry"`.

**Inline verification:** `/tmp/check_plan_closing_tn.sh` exits 0.

---

### T33: /plan sidecar contracts — review.md, auto.md, atomic writes

**Goal:** Document sidecar contracts (§7.6) — `03_plan_review.md` and `03_plan_auto.md` with frontmatter, sections, atomic writes (FR-43c), version markers (FR-100a), lifecycle (FR-100b).
**Spec refs:** §7.6, FR-43c, FR-100a, FR-100b
**Depends on:** T32
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:** Modify `plan/SKILL.md` — add "Sidecar Contracts" subsection in Phase 3 (after plan template) OR Phase 4 (after Skip List)

**Steps:**

- [ ] Step 1: Write `/tmp/check_plan_sidecars.sh` asserting `plan/SKILL.md` documents both sidecars with full frontmatter (`plan_ref`, `generated_at`, `skill_version`, `non_interactive` for auto.md), required sections (`## Skip List`, `## Review Log`, `## Archived (pre-replan ...)` for review.md; `## Auto-decisions` for auto.md with confidence enum {high, medium, low}), atomic write-then-rename, version markers `pmos-toolkit/<semver>` (FR-100a), overwrite-on-each-run lifecycle (FR-100b).
- [ ] Step 2: Run — expected FAIL.
- [ ] Step 3: Add "Sidecar Contracts" subsection. For `03_plan_review.md` (owned by /plan, readable by /verify, /grill, /execute): frontmatter (plan_ref, generated_at, skill_version); 3 sections — Skip List (table: fingerprint | first_loop | last_seen_loop | rationale), Review Log (table: loop | findings | dispositions | applied_at), optional Archived. For `03_plan_auto.md` (only when `--non-interactive`): frontmatter (plan_ref, run_started_at, skill_version, non_interactive: true); 1 section Auto-decisions (table: question_text | chosen_option | rationale | confidence ∈ {high, medium, low}). FR-43c atomic writes: tempfile + rename, abort on failure with platform-aware error. FR-100a version markers in every sidecar's frontmatter. FR-100b lifecycle: review.md and auto.md overwritten on each /plan run; defect file owned by /execute and removed by /execute on successful resume past defect task (P7 decision — recorded in Decision Log). Document FR-110 fail-fast: /execute reading a plan with dependency cycle / missing required field / contract violation → halt with "plan defect" report (NOT defect-file handoff) + instruct user to run `/grill 03_plan.md` and re-plan; no auto-repair.
- [ ] Step 4: Re-run — expected PASS.
- [ ] Step 5: Commit `git commit -m "feat(T33): /plan sidecar contracts (review.md, auto.md, atomic writes)"`.

**Inline verification:** `/tmp/check_plan_sidecars.sh` exits 0.

---

### T34: /execute Phase 1 — read commit_cadence + contract_version

**Goal:** Update /execute to read `commit_cadence` (per-task / per-phase / squash) and `contract_version` from plan frontmatter (§7.2, FR-111).
**Spec refs:** §7.2, FR-111
**Depends on:** T33
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:** Modify `plugins/pmos-toolkit/skills/execute/SKILL.md` Phase 1 (~ll. 83-113)

**Steps:**

- [ ] Step 1: Write `/tmp/check_execute_phase1.sh` asserting Phase 1 (or 0.5) mentions parsing plan frontmatter for `commit_cadence` (with default `per-task`), reading `contract_version`, warning on contract_version mismatch.
- [ ] Step 2: Run — expected FAIL.
- [ ] Step 3: Add to /execute Phase 1 step 2 ("Read the plan and its upstream spec end-to-end"): "Parse the plan's frontmatter. Set `{commit_cadence}` (default `per-task`) — controls Phase 2 step 6 commit granularity (per-task = one commit per task as today; per-phase = one commit per phase boundary; squash = single commit at end of /execute). Set `{contract_version}` (default 1) — if it doesn't match this skill's supported version, emit a stderr warning '`WARN: contract_version mismatch — plan declares N, skill supports M; behavior may degrade`' and continue; do NOT halt." Update Phase 2 step 6 to reference `{commit_cadence}`: per-task = current behavior; per-phase = accumulate file changes, commit at phase boundary just before /verify; squash = accumulate everything, single commit at Phase 5.
- [ ] Step 4: Re-run — expected PASS.
- [ ] Step 5: Commit `git commit -m "feat(T34): /execute reads commit_cadence + contract_version"`.

**Inline verification:** `/tmp/check_execute_phase1.sh` exits 0.

---

### T35: /execute Phase 2 — consume new task fields + back-compat shim

**Goal:** /execute v2 consumes per-task `**Depends on:**` (ordering + [P]), `**Idempotent:**` (recovery prompt), `**Requires state from:**` (re-run setup), `**Data:**` (informational), with back-compat shim per S8 + FR-110.
**Spec refs:** §7.2, S8, FR-110, R2 (this plan)
**Depends on:** T34
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:** Modify `execute/SKILL.md` Phase 2 (~ll. 116-220)

**Steps:**

- [ ] Step 1: Write `/tmp/check_execute_phase2_fields.sh` asserting Phase 2 mentions: `Depends on`, `Idempotent`, `Requires state from`, `Data` field consumption; back-compat shim per-task `WARN:` lines on stderr (P5); FR-110 fail-fast on cycles or missing required fields.
- [ ] Step 2: Run — expected FAIL.
- [ ] Step 3: Add to Phase 2 a sub-step "Read task contract fields" (after step 2 "Read the task"): parse `**Depends on:**` for ordering — block this task until all deps in {`done`, `done-sealed`} state; tasks with no shared upstream may run [P] when supported. Parse `**Idempotent:**` — if `no — <recovery>`, prompt user via AskUserQuestion before retrying after a failure ("Task is non-idempotent. Run recovery substep <ref> first?" Yes/No). Parse `**Requires state from:**` — before this task's verification step, re-run upstream tasks' setup if marker shows their post-state has been disturbed (e.g., container restart, DB drop). Parse `**Data:**` — informational only; log to per-task log frontmatter as `data_source: <value>` for audit. Add back-compat shim (S8): if any of these fields are absent on a task, emit `WARN: T<N> missing field <name>; assuming defaults (Depends on: implicit by order; Idempotent: yes; Requires state from: none; Data: unspecified)` per task on stderr — do NOT error. Add FR-110 fail-fast: dependency cycle (parse all `Depends on` into a graph; tarjan SCC > 1 → halt) OR a required field missing on a task that explicitly opts in (e.g., declares `Idempotent: no` but lacks recovery substep ref) → halt with "plan defect — run /grill 03_plan.md and re-plan", do NOT write defect-file (defect-file is for runtime-discovered planning gaps).
- [ ] Step 4: Re-run — expected PASS.
- [ ] Step 5: Commit `git commit -m "feat(T35): /execute consumes per-task contract fields + back-compat shim"`.

**Inline verification:** `/tmp/check_execute_phase2_fields.sh` exits 0.

---

### T36: /execute defect handoff — write 03_plan_defect_<task-id>.md

**Goal:** /execute writes `{feature_folder}/03_plan_defect_<task-id>.md` per §7.5 on planning defect; deletes it on successful resume past the defect task (P7).
**Spec refs:** FR-56, §7.5, FR-100b, P7
**Depends on:** T35
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:** Modify `execute/SKILL.md` — add subsection in Phase 2 + lifecycle hook in Phase 0.5 / 1

**Steps:**

- [ ] Step 1: Write `/tmp/check_execute_defect.sh` asserting execute/SKILL.md mentions: defect file path `{feature_folder}/03_plan_defect_<task-id>.md`, frontmatter (`defect_task`, `generated_by_skill_version`, `generated_at`, `plan_ref`, `spec_ref`), 3 required body sections (Failure Context, Affected Artifacts, Suggested Fix Direction — last may be empty), instruction to user to run `/pmos-toolkit:plan --fix-from <task-id>`, deletion on successful resume past the defect task.
- [ ] Step 2: Run — expected FAIL.
- [ ] Step 3: Add to Phase 2 "Verify-Fix Loop" — when 3-attempt budget is exhausted AND root cause is a *planning defect* (i.e., the plan's assumption about the codebase is wrong, NOT just a flaky test or environment issue): write `{feature_folder}/03_plan_defect_<task-id>.md` per §7.5 frontmatter + 3-section body. Frontmatter requires `defect_task`, `generated_by_skill_version: pmos-toolkit/<semver>`, `generated_at: <ISO 8601>`, `plan_ref`, `spec_ref`. Body: `## Failure Context` (what happened, exit code if applicable, last-output excerpt ≤50 lines redacted of secrets, reproduction steps); `## Affected Artifacts` (files modified, db state changes, services touched, env side-effects); `## Suggested Fix Direction` (free-form hints; may be empty — /plan --fix-from reads frontmatter + sections 1-2 as authoritative). Instruct user via platform-aware closing message: "Run `{plan_invocation} --fix-from <task-id>` to repair the plan." Halt /execute (status: failed in per-task log). Add to Phase 0.5 / 1 lifecycle (resume): when /execute resumes past a previously-failed task and that task is now `done`, delete the corresponding `03_plan_defect_<task-id>.md` if present (P7 / FR-100b). Use `git rm` if the file is tracked, else `rm -f`.
- [ ] Step 4: Re-run — expected PASS.
- [ ] Step 5: Commit `git commit -m "feat(T36): /execute writes defect file + deletes on resume"`.

**Inline verification:** `/tmp/check_execute_defect.sh` exits 0.

---

### T37: Already covered by T34 — fold (no separate task)

**Goal:** `contract_version` read + warn-on-mismatch is implemented as part of T34. This task is a placeholder that asserts T34 covered FR-111 fully.
**Spec refs:** FR-111
**Depends on:** T34
**Idempotent:** yes
**TDD:** no — verification only (covered by T34's test)
**Files:** (none)

**Steps:**

- [ ] Step 1: Verify T34 covers FR-111: re-run `/tmp/check_execute_phase1.sh` (which asserts `contract_version` mention).
- [ ] Step 2: If passing, this task is a no-op — skip Steps 3-5.
- [ ] Step 3: If T34 is incomplete on `contract_version`, edit /execute Phase 1 to add the warn-on-mismatch behavior; commit `feat(T37): ...`.

**Inline verification:** `/tmp/check_execute_phase1.sh` exits 0 (already verified at T34).

*Decision-Log note:* T37 is intentionally folded into T34's scope — see Decision Log P5 rationale (single warning surface). The task ID is preserved for traceability against spec FR-111.

---

### T38: Test fixture sub-repos for stack detection

**Goal:** Create minimal sub-repos at `tests/fixtures/repos/{node,python,go}/` with the manifest signals each stack file expects, so T39-T41 integration runs detect the right stack.
**Spec refs:** §10.2, FR-10
**Depends on:** T19 (fixtures namespace established)
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:**
- Create: `tests/fixtures/repos/node/package.json`
- Create: `tests/fixtures/repos/node/package-lock.json`
- Create: `tests/fixtures/repos/python/requirements.txt`
- Create: `tests/fixtures/repos/go/go.mod`
- Create: `tests/fixtures/repos/README.md`

**Steps:**

- [ ] Step 1: Write `/tmp/check_fixture_repos.sh`:
  ```bash
  set -e
  test -f tests/fixtures/repos/node/package.json
  test -f tests/fixtures/repos/node/package-lock.json
  test -f tests/fixtures/repos/python/requirements.txt
  test -f tests/fixtures/repos/go/go.mod
  test -f tests/fixtures/repos/README.md
  echo PASS
  ```
- [ ] Step 2: Run — expected FAIL.
- [ ] Step 3: Create the fixtures. `node/package.json`: `{"name":"fixture-node","version":"0.0.0","scripts":{"test":"echo no tests"}}`. `node/package-lock.json`: `{"name":"fixture-node","lockfileVersion":3,"requires":true,"packages":{}}`. `python/requirements.txt`: `# fixture python project\n`. `go/go.mod`: `module fixturego\n\ngo 1.22\n`. `README.md`: 5 lines explaining "Fixture sub-repos consumed by /plan v2 integration tests T39-T41 to validate stack detection (FR-10)."
- [ ] Step 4: Re-run — expected PASS.
- [ ] Step 5: Commit `git add tests/fixtures/repos/ && git commit -m "feat(T38): add fixture sub-repos for stack detection tests"`.

**Inline verification:** `/tmp/check_fixture_repos.sh` exits 0.

---

### T39: Integration run — Tier 1 bug-fix on python repo

**Goal:** Drive /plan v2 against `tests/fixtures/specs/tier1_bugfix.md` from inside `tests/fixtures/repos/python/`; assert the produced plan is tier-correct (1 task, no decision-log floor, reduced TN).
**Spec refs:** §10.2 Tier-1 grep tests
**Depends on:** T33 (/plan v2 complete), T36 (/execute v2 complete), T19 + T38 (fixtures), T43 (plugin version bump must be in place for the freshly-loaded skill)
**Requires state from:** T33, T36, T38, T43
**Idempotent:** yes
**TDD:** no — integration test
**Files:**
- Create: `tests/fixtures/repos/python/docs/pmos/features/2026-05-09_fixture-bugfix/02_spec.md` (copied from tier1_bugfix.md, with `feature: fixture-bugfix`)
- Read-only verification on the produced `03_plan.md`

**Steps:**

- [ ] Step 1: From repo root, copy the tier-1 fixture into the sub-repo's pipeline path and stage:
  ```bash
  mkdir -p tests/fixtures/repos/python/docs/pmos/features/2026-05-09_fixture-bugfix
  cp tests/fixtures/specs/tier1_bugfix.md tests/fixtures/repos/python/docs/pmos/features/2026-05-09_fixture-bugfix/02_spec.md
  cat > tests/fixtures/repos/python/.pmos/settings.yaml <<'EOF'
  version: 1
  docs_path: docs/pmos/
  workstream: null
  current_feature: 2026-05-09_fixture-bugfix
  EOF
  mkdir -p tests/fixtures/repos/python/.pmos
  ```
- [ ] Step 2: Manual driving step (cannot fully automate /plan inside this same session): document the procedure for the user in a `RUN.md` file at `tests/fixtures/repos/python/RUN.md`:
  ```markdown
  # Manual integration run
  cd tests/fixtures/repos/python
  # Invoke /plan in this directory (separate Claude Code session, fresh context)
  # /plan @docs/pmos/features/2026-05-09_fixture-bugfix/02_spec.md
  # Then run: bash ../../../../scripts/assert_t39.sh
  ```
  Create the assertion script at `tests/scripts/assert_t39.sh`:
  ```bash
  #!/usr/bin/env bash
  set -e
  P=tests/fixtures/repos/python/docs/pmos/features/2026-05-09_fixture-bugfix/03_plan.md
  test -f "$P" || { echo "FAIL: plan not produced at $P"; exit 1; }
  task_count=$(grep -c '^### T[0-9]' "$P")
  [[ $task_count -eq 1 ]] || { echo "FAIL: expected 1 task, got $task_count"; exit 1; }
  ! grep -q '^## Decision Log$' "$P" || { echo "FAIL: T1 plan should skip Decision-Log floor"; exit 1; }
  grep -qiE 'done-when walkthrough|Done-when walkthrough' "$P" || { echo "FAIL: missing Done-when walkthrough"; exit 1; }
  ! grep -qi 'alembic' "$P" || { echo "FAIL: stack=python detected but alembic still leaked (should NOT appear in T1 reduced TN)"; exit 1; }
  echo PASS
  ```
  `chmod +x tests/scripts/assert_t39.sh`.
- [ ] Step 3: User runs the manual /plan invocation per RUN.md. After completion:
  Run: `bash tests/scripts/assert_t39.sh`
  Expected: prints `PASS`.
- [ ] Step 4: If assertion fails, log the failure mode and route back to /plan v2 fix (Edit mode on the relevant skill file). Re-run.
- [ ] Step 5: Commit
  ```bash
  git add tests/fixtures/repos/python/ tests/scripts/assert_t39.sh
  git commit -m "test(T39): integration — Tier 1 bug-fix on python fixture repo"
  ```

**Inline verification:** `bash tests/scripts/assert_t39.sh` exits 0.

---

### T40: Integration run — Tier 3 feature on node repo

**Goal:** Drive /plan v2 against `tier3_feature.md` from inside `tests/fixtures/repos/node/`; assert mermaid diagram, per-task new fields, sidecar review file, no leaked python commands.
**Spec refs:** §10.2 Tier-3 grep tests
**Depends on:** T33, T36, T19, T38, T43
**Requires state from:** T33, T36, T38, T43
**Idempotent:** yes
**TDD:** no — integration test
**Files:**
- Create: `tests/fixtures/repos/node/docs/pmos/features/2026-05-09_fixture-feature/02_spec.md`
- Create: `tests/scripts/assert_t40.sh`

**Steps:**

- [ ] Step 1: Stage fixture per T39's pattern but for tier3 + node.
- [ ] Step 2: Author `tests/scripts/assert_t40.sh`:
  ```bash
  #!/usr/bin/env bash
  set -e
  P=tests/fixtures/repos/node/docs/pmos/features/2026-05-09_fixture-feature/03_plan.md
  R=tests/fixtures/repos/node/docs/pmos/features/2026-05-09_fixture-feature/03_plan_review.md
  test -f "$P" || { echo "FAIL: plan not produced"; exit 1; }
  test -f "$R" || { echo "FAIL: review sidecar not produced"; exit 1; }
  grep -q '^## Phase 1' "$P" || { echo "FAIL: phases not used"; exit 1; }
  [[ $(grep -cE '^\*\*Depends on:\*\*' "$P") -gt 0 ]] || { echo "FAIL: no Depends on fields"; exit 1; }
  [[ $(grep -cE '^\*\*Idempotent:\*\*' "$P") -gt 0 ]] || { echo "FAIL: no Idempotent fields"; exit 1; }
  grep -q '^```mermaid' "$P" || { echo "FAIL: no mermaid diagram"; exit 1; }
  ! grep -qE 'curl.*json\.tool' "$P" || { echo "FAIL: stack=node but python smoke leaked"; exit 1; }
  ! grep -qi 'alembic' "$P" || { echo "FAIL: alembic leaked"; exit 1; }
  # FR-16 bidirectional wireframe coverage: every wireframes/*.html cited or in Out-of-Scope
  for wf in 01_dashboard.html 02_settings.html; do
    if ! grep -qF "wireframes/$wf" "$P"; then
      grep -qE '^## Wireframes Out of Scope' "$P" && grep -qF "$wf" "$P" || { echo "FAIL: wireframe $wf neither cited nor in Out-of-Scope"; exit 1; }
    fi
  done
  echo PASS
  ```
- [ ] Step 3: User runs /plan in the node sub-repo per RUN.md.
- [ ] Step 4: `bash tests/scripts/assert_t40.sh` — expected PASS.
- [ ] Step 5: Commit `git add tests/fixtures/repos/node/ tests/scripts/assert_t40.sh && git commit -m "test(T40): integration — Tier 3 feature on node fixture repo"`.

**Inline verification:** `bash tests/scripts/assert_t40.sh` exits 0.

---

### T41: Integration run — defect handoff round-trip

**Goal:** Test the /execute → defect-file → /plan --fix-from round-trip (E10).
**Spec refs:** FR-56, E10
**Depends on:** T36, T40
**Requires state from:** T40
**Idempotent:** yes
**TDD:** no — integration test
**Files:**
- Create: `tests/scripts/assert_t41.sh`
- Read-only on `03_plan.md` and `03_plan_defect_T7.md` produced during the run

**Steps:**

- [ ] Step 1: Author `tests/scripts/assert_t41.sh`:
  ```bash
  #!/usr/bin/env bash
  set -e
  D=tests/fixtures/repos/node/docs/pmos/features/2026-05-09_fixture-feature
  test -f "$D/03_plan_defect_T7.md" || { echo "FAIL: defect file not written"; exit 1; }
  awk '/^---$/{c++;next} c==1' "$D/03_plan_defect_T7.md" | grep -q '^defect_task: T7' || { echo "FAIL: bad defect frontmatter"; exit 1; }
  for sec in '## Failure Context' '## Affected Artifacts' '## Suggested Fix Direction'; do
    grep -qF "$sec" "$D/03_plan_defect_T7.md" || { echo "FAIL: missing section $sec"; exit 1; }
  done
  # After /plan --fix-from T7 + /execute resume past T7, defect file should be deleted (P7)
  echo PASS
  ```
- [ ] Step 2: User runs the manual round-trip per `tests/fixtures/repos/node/RUN.md` — synthetically force a planning defect on T7 (e.g., by editing the spec to reference a non-existent file mid-execution), let /execute write the defect file, then `/plan --fix-from T7`, then resume /execute.
- [ ] Step 3: `bash tests/scripts/assert_t41.sh` — expected PASS (intermediate state, defect file present).
- [ ] Step 4: After successful resume past T7, verify defect file is deleted: `! test -f tests/fixtures/repos/node/.../03_plan_defect_T7.md` succeeds.
- [ ] Step 5: Commit `git add tests/scripts/assert_t41.sh && git commit -m "test(T41): integration — defect handoff round-trip"`.

**Inline verification:** `bash tests/scripts/assert_t41.sh` exits 0; defect file deleted after resume (Step 4).

---

### T42: Anti-pattern prune

**Goal:** Confirm legacy strings removed from /plan and /spec per §10.5.
**Spec refs:** §10.5
**Depends on:** T33, T35
**Idempotent:** yes
**TDD:** yes — new-feature (the test verifies absence)
**Files:**
- (none — verification only)

**Steps:**

- [ ] Step 1: Write `/tmp/check_anti_patterns.sh`:
  ```bash
  set -e
  ! grep -q 'Do NOT do only 1 review loop' plugins/pmos-toolkit/skills/plan/SKILL.md || { echo "FAIL: legacy review-loop minimum still present"; exit 1; }
  ! grep -qE 'curl.*json\.tool' plugins/pmos-toolkit/skills/plan/SKILL.md || { echo "FAIL: hardcoded curl|json.tool still in plan/SKILL.md"; exit 1; }
  ! grep -qi 'alembic' plugins/pmos-toolkit/skills/plan/SKILL.md || { echo "FAIL: alembic still in plan/SKILL.md"; exit 1; }
  ! grep -qi 'pytest' plugins/pmos-toolkit/skills/plan/SKILL.md | grep -v '_shared/stacks' || { echo "FAIL: pytest leaked into plan body (should only appear in stacks/python.md)"; exit 1; }
  echo PASS
  ```
- [ ] Step 2: Run — expected PASS if T29 + T32 fully scrubbed legacy strings; FAIL otherwise.
- [ ] Step 3: If FAIL, Edit /plan/SKILL.md to remove the offending lines. Re-run.
- [ ] Step 4: Commit (only if changes were needed) `git commit -m "chore(T42): prune legacy stack-specific commands from /plan body"`.

**Inline verification:** `/tmp/check_anti_patterns.sh` exits 0.

---

### T43: Plugin version bump (atomic Phase 3 release)

**Goal:** Bump plugin version from 2.23.0 → 2.24.0 in both `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` (synced per pre-push hook), and add a CHANGELOG entry.
**Spec refs:** S3, FR-115
**Depends on:** T21, T22, T23, T24, T25, T26a, T26b, T27, T28, T29a, T29b, T29c, T30, T31a, T31b, T32, T33, T34, T35, T36, T42
**Requires state from:** ALL Phase 3 task changes must be committed
**Idempotent:** yes
**TDD:** yes — new-feature
**Files:**
- Modify: `plugins/pmos-toolkit/.claude-plugin/plugin.json`
- Modify: `plugins/pmos-toolkit/.codex-plugin/plugin.json`
- Modify: `CHANGELOG.md`

**Steps:**

- [ ] Step 1: Write `/tmp/check_version_bump.sh`:
  ```bash
  set -e
  for f in plugins/pmos-toolkit/.claude-plugin/plugin.json plugins/pmos-toolkit/.codex-plugin/plugin.json; do
    grep -q '"version": "2.24.0"' "$f" || { echo "FAIL: $f not at 2.24.0"; exit 1; }
  done
  grep -q '## 2.24.0' CHANGELOG.md || { echo "FAIL: CHANGELOG missing 2.24.0 entry"; exit 1; }
  echo PASS
  ```
- [ ] Step 2: Run — expected FAIL.
- [ ] Step 3: Edit both manifests: `"version": "2.23.0"` → `"version": "2.24.0"`. Add CHANGELOG entry under `## 2.24.0` heading describing /plan v2 + /execute v2 + /backlog type-enum extension + new shared resources, with a "Breaking changes: none — backwards-compat shim warns on missing optional fields" note (S8).
- [ ] Step 4: Re-run — expected PASS.
- [ ] Step 5: Commit `git commit -m "feat(T43): bump pmos-toolkit to 2.24.0 (atomic Phase 3 release)"`.

**Inline verification:** `/tmp/check_version_bump.sh` exits 0.

---

### TN: Final Verification

**Goal:** Verify the entire implementation works end-to-end. This task IS the last phase's /verify per FR-26 — there is no separate end-of-plan TN.

**Spec refs:** §10.5, FR-26, FR-26a

**Files:** (none — verification only)

**Steps:**

- [ ] Step 1: **Lint & format** — run all four pmos-toolkit lints:
  ```bash
  bash plugins/pmos-toolkit/tools/lint-pipeline-setup-inline.sh
  bash plugins/pmos-toolkit/tools/lint-stack-libraries.sh
  bash plugins/pmos-toolkit/tools/lint-platform-strings.sh
  bash plugins/pmos-toolkit/tools/lint-js-stack-preambles.sh
  ```
  Expected: each prints `PASS:` and exits 0.

- [ ] Step 2: **Markdownlint pass** (best-effort — only if `markdownlint` is on PATH):
  ```bash
  command -v markdownlint && markdownlint plugins/pmos-toolkit/skills/plan/SKILL.md plugins/pmos-toolkit/skills/spec/SKILL.md plugins/pmos-toolkit/skills/execute/SKILL.md plugins/pmos-toolkit/skills/_shared/stacks/*.md plugins/pmos-toolkit/skills/_shared/platform-strings.md || echo "SKIP: markdownlint not installed"
  ```
  Expected: exit 0 OR prints `SKIP:`.

- [ ] Step 3: **Phase-task assertion bundle** — re-run every per-task script written during this plan:
  ```bash
  for s in /tmp/check_platform_strings.sh /tmp/check_stacks_dir.sh /tmp/check_js_stacks.sh /tmp/check_python_stack.sh /tmp/check_rails_stack.sh /tmp/check_go_stack.sh /tmp/check_static_stack.sh /tmp/check_pipeline_setup_xref.sh /tmp/check_lint_stack_libs.sh /tmp/check_lint_platform_strings.sh /tmp/check_lint_js_preambles.sh /tmp/check_spec_t1_frontmatter.sh /tmp/check_spec_t2_frontmatter.sh /tmp/check_spec_t3_frontmatter.sh /tmp/check_spec_anchor_rule.sh /tmp/check_spec_type_detection.sh /tmp/check_spec_exit_frontmatter.sh /tmp/check_fixture_specs.sh /tmp/check_backlog_type_enum.sh /tmp/check_backlog_heuristics.sh /tmp/check_plan_phase0.sh /tmp/check_plan_phase1.sh /tmp/check_plan_phase2.sh /tmp/check_plan_template_frontmatter.sh /tmp/check_plan_task_fields.sh /tmp/check_plan_structural.sh /tmp/check_plan_phase4.sh /tmp/check_plan_drift.sh /tmp/check_plan_modes.sh /tmp/check_plan_closing_tn.sh /tmp/check_plan_sidecars.sh /tmp/check_execute_phase1.sh /tmp/check_execute_phase2_fields.sh /tmp/check_execute_defect.sh /tmp/check_fixture_repos.sh /tmp/check_anti_patterns.sh /tmp/check_version_bump.sh; do
    test -f "$s" && bash "$s" >/dev/null && echo "OK: $s" || echo "MISSING-OR-FAIL: $s"
  done | tee /tmp/tn_step3.log
  ! grep -q '^MISSING-OR-FAIL' /tmp/tn_step3.log
  ```
  Expected: every line is `OK:`; final `grep -q` returns non-zero (i.e., no MISSING-OR-FAIL).

- [ ] Step 4: **Done-when walkthrough** — verify each clause of the Overview's "Done when" line:
  - Lint suite green (Step 1 ✓)
  - 9 stack files + platform-strings.md present:
    ```bash
    ls plugins/pmos-toolkit/skills/_shared/stacks/{npm,pnpm,yarn-classic,yarn-berry,bun,python,rails,go,static}.md plugins/pmos-toolkit/skills/_shared/platform-strings.md
    ```
    Expected: no `ls` error.
  - /spec emits frontmatter + anchors at all tiers:
    ```bash
    grep -c '^tier:' plugins/pmos-toolkit/skills/spec/SKILL.md  # ≥3
    grep -q '^### Anchor Emission Rule' plugins/pmos-toolkit/skills/spec/SKILL.md
    ```
  - /backlog `type` enum has 6+ values: `bash /tmp/check_backlog_type_enum.sh` exits 0
  - /plan v2 generates tier-correct plans: `bash tests/scripts/assert_t39.sh && bash tests/scripts/assert_t40.sh`
  - /execute v2 consumes new fields + warning-not-error: confirm by inspecting `execute/SKILL.md`:
    ```bash
    grep -q 'WARN:' plugins/pmos-toolkit/skills/execute/SKILL.md
    grep -q 'Depends on' plugins/pmos-toolkit/skills/execute/SKILL.md
    ```
  - Defect handoff round-trip: `bash tests/scripts/assert_t41.sh`
  - Plugin version 2.24.0 in both manifests: `bash /tmp/check_version_bump.sh`

- [ ] Step 5: **Pre-push hook compatibility check** (does NOT push — local validation):
  ```bash
  # Simulate the hook's version-equality check
  v1=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' plugins/pmos-toolkit/.claude-plugin/plugin.json | head -n1)
  v2=$(sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' plugins/pmos-toolkit/.codex-plugin/plugin.json | head -n1)
  [[ "$v1" == "$v2" ]] || { echo "FAIL: manifest versions out of sync ($v1 vs $v2)"; exit 1; }
  [[ "$v1" == "2.24.0" ]] || { echo "FAIL: expected 2.24.0, got $v1"; exit 1; }
  echo "OK: manifest versions synced at $v1"
  ```

- [ ] Step 6: **Anti-pattern prune** — `bash /tmp/check_anti_patterns.sh` exits 0 (already in Step 3 bundle, double-check explicit).

- [ ] Step 7: **Cross-skill handshake smoke test** — synthetic spec with `### 6.2 Auth flow {#auth-flow}` → run /plan against it (manual) → confirm produced task carries `**Spec refs:** auth-flow` and that breaking the anchor in the spec triggers Phase 4 hard-fail. Document evidence in chat.

- [ ] Step 8: **Workstream enrichment** — settings.workstream is `null` per .pmos/settings.yaml; **skip** Phase 6 enrichment per Section C "skip if no workstream loaded".

- [ ] Step 9: **Capture learnings** — review session for surprises worth saving in `learnings/learnings-capture.md`. Candidates:
  - The repo had a layout transition mid-session (`docs/features/` → `docs/pmos/features/`) that interrupted the plan write — record as gotcha if learnings file exists at this skill's path
  - The pre-push hook's silent failure mode for un-synced version numbers is non-obvious — capture as toolkit-maintainer note if applicable

- [ ] Step 10: **Final commit** — only after all preceding TN steps pass:
  ```bash
  git status --porcelain  # expect clean working tree
  git log --oneline | head -50  # confirm task commit IDs T1..T43 all present
  git tag pmos-toolkit-v2.24.0  # local tag; do NOT push tag without user confirmation
  ```
  Do NOT auto-push — user explicitly approves the push per skill /push.

**Cleanup:**

- [ ] Remove `/tmp/check_*.sh` files (they're scratch validation scripts, not artifacts):
  ```bash
  rm -f /tmp/check_*.sh /tmp/tn_step3.log /tmp/t1.txt /tmp/t2.txt /tmp/t3.txt /tmp/anchor.txt /tmp/p1.txt /tmp/p7.txt /tmp/exit.txt /tmp/lint_stack_libs.out /tmp/lint_stack_libs.fail.out
  ```
- [ ] Update `CHANGELOG.md` with the v2.24.0 user-facing summary (already in T43)
- [ ] Optional: invoke `/changelog` skill to refine the user-facing CHANGELOG entry

---

## Review Log

| Loop | Findings | Changes Made |
|------|----------|-------------|
| 1    | **Structural (2 Blocker, 2 Should-fix):** F1 FR-92 TN cleanup triggers unmapped; F2 §8.7 spec-re-open AskUserQuestion shape (E13) unmapped; F3 T14/T15 used "same shape as T13" placeholder phrasing; F4 cross-skill defect with spec FR-50a "<yaml-lib message>" wording (skills have no YAML library). **Design (4 Should-fix):** F5 T26 covered 6 FRs (oversized); F6 T29 covered 13 FRs (oversized); F7 T31 covered 4 distinct concerns; F8 FR-16 positive case (UI signal + populated wireframes/) not exercised by integration tests. | All 8 dispositions = "Fix as proposed". F1: T28 extended with FR-92 trigger-based emission rule (4 triggers + no-decoration rule). F2: T25 extended with §8.7 AskUserQuestion shape + FR-61a non-interactive halt. F3: T14, T15 inlined full bash assertion shells. F4: Decision Log P9 added (regex-based parse + revised error wording); T23 wording revised to "Spec frontmatter parse error at line N: <observed-token>". F5: T26 split → T26a (frontmatter+tier gates+Done-when) + T26b (Code Study+readability+glossary+tests-illustrative). F6: T29 split → T29a (cap+classify) + T29b (blind subagent) + T29c (Skip List+Phase 5 fold). F7: T31 split → T31a (Edit/Replan/Append) + T31b (non-interactive+picker+learnings). F8: T19 extended with wireframes/01_dashboard.html + 02_settings.html stubs; T40 assert_t40.sh extended with bidirectional-coverage check. Downstream Depends-on chains (T27, T29a, T30, T32) and T43 dependency list updated to reference split sub-task IDs. File Map regenerated. |
| 2    | (pending blind subagent loop) | (pending) |

