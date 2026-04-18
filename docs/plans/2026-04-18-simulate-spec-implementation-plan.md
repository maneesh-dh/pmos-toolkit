# `/simulate-spec` Skill — Implementation Plan

**Date:** 2026-04-18
**Spec:** `docs/specs/2026-04-18-simulate-spec-design.md`
**Requirements:** (none — spec was created via `/brainstorm`)

---

## Overview

Add a new pmos-toolkit skill `/simulate-spec` as an optional validator between `/spec` and `/plan`. The skill is prompt-based (no executable code), so implementation is content authoring against the design doc plus integration touches: plugin manifest version bumps, README update, pipeline-diagram updates in adjacent skills, and structural validation.

**TDD adaptation note:** Classical red/green TDD does not apply to markdown skill content. Instead, each task follows a **write → verify-presence → commit** pattern: write the content, run grep-based assertions to confirm required sections / phrases / tables are present, commit. The deeper *quality* check (does the prose match design intent) happens in T11 via a multi-agent code review — per the `/verify` learning in `~/.pmos/learnings.md` ("multi-agent code review reliably catches bugs that TDD misses").

**Done when:** `plugins/pmos-toolkit/skills/simulate-spec/SKILL.md` exists and matches the design doc; both plugin manifests are at version `1.3.0`; README and adjacent skills (`/spec`, `/plan`) reference the new skill in their pipeline diagrams; the plugin-validator agent reports no errors; a smoke invocation against an existing spec produces a well-formed simulation doc.

**Execution order:**
```
T1 (skeleton)
  └─> T2 (Phases 0-1)
        └─> T3 (Phase 2)
              └─> T4 (Phases 3-5)
                    └─> T5 (Phases 6-7)
                          └─> T6 (Phases 8-9)
                                └─> T7 (Phases 10-11 + Anti-Patterns)
                                      └─> T8 (manifest version bumps) [P]
                                      └─> T9 (README update)         [P]
                                      └─> T10 (pipeline diagrams in /spec, /plan) [P]
                                            └─> T11 (plugin-validator + coverage review)
                                                  └─> T12 (smoke invocation + final commit)
```

T8/T9/T10 are independent of each other but all depend on T7. T11 depends on T7-T10. T12 is the final gate.

---

## Decision Log

> Inherits architecture decisions from spec §4.

| # | Decision | Options Considered | Rationale |
|---|----------|--------------------|-----------|
| D1 | Author SKILL.md in 7 incremental tasks (T1-T7) by phase group rather than one monolithic write | (a) One big write, (b) 12 micro-tasks (one per phase), (c) 7 grouped tasks | Group reflects logical content boundaries (scaffold, intake, enumeration, trace+critique+wireup, pseudocode+resolution, output+review, closing+anti-patterns). Each commit is self-contained and reviewable. Avoids one-shot risk while not over-fragmenting. |
| D2 | Bump plugin version `1.2.1 → 1.3.0` (minor) | (a) Patch 1.2.2, (b) Minor 1.3.0, (c) Major 2.0.0 | New skill = new behavior, not bug fix or breaking. Per pre-push hook comment: "minor for new behavior." |
| D3 | Update pipeline diagrams in `/spec` and `/plan` only — defer `/requirements`, `/msf`, `/creativity`, `/execute`, `/verify` updates | (a) Update all skills with pipeline diagrams, (b) Update only adjacent (/spec, /plan), (c) Update none — let users discover via README | Adjacent skills are the natural handoff points (/spec offers next step; /plan reads from a spec). Other diagrams can be updated organically when those skills are next touched — avoids scope creep and reduces risk of inconsistent diagram language across skills. |
| D4 | Place targeted-pseudocode "Format per flow" example as a code block inside the skill (not extracted to `reference/`) | (a) Inline, (b) Extract to `simulate-spec/reference/pseudocode-format.md` | Skill stays under 500 lines. Inline keeps the format visible at the point of use — the example IS the instruction. |
| D5 | Use `Edit` tool for spec patches in Phase 7 (per design §17), not `Write` | (a) Edit tool, (b) Read-then-Write, (c) Generate diff for user to apply manually | Edit gives surgical, traceable changes. Each patch is one Edit call, logged in simulation doc §10. Avoids the "rewrite the whole spec" risk of Write. |
| D6 | Smoke test invocation in T12 uses the design doc itself as the input spec | (a) Use the design doc, (b) Use an existing spec like `2026-04-12-pipeline-input-resolution-design.md`, (c) Use a synthetic toy spec | Self-application is the strongest test: if the skill can find gaps in its OWN design, it works. Existing specs in this repo are already well-vetted (low gap count = weak signal). |
| D7 | Coverage review (T11) uses a subagent dispatched with the design doc + the new SKILL.md, not inline reading | (a) Subagent, (b) Inline read | Per `~/.pmos/learnings.md` `/verify` learning: "multi-agent code review reliably catches bugs that TDD misses." A fresh subagent without authoring bias catches drift between design intent and skill content. |

---

## Code Study Notes

- Repo has no `skills/` top-level dir; all skills live in `plugins/pmos-toolkit/skills/<name>/SKILL.md` (the `create-skill` doc is slightly stale on this point — match the actual convention)
- `~/.pmos/learnings.md` `/plan` section is empty. `/execute` learnings (SQLAlchemy identity map, sentinel terminators) are not relevant — this is prompt content, not Python. `/verify` learning about multi-agent review is relevant: dispatch a subagent for coverage review (D7)
- `creativity/SKILL.md` is a good structural reference for an optional-enhancer skill: announces, declares pipeline position, has Platform Adaptation, runs phases, ends with Workstream Enrichment + Capture Learnings + Anti-Patterns
- `learnings/learnings-capture.md` handles `~/.pmos/learnings.md` line-count check + summarization automatically — skill just calls into it
- `product-context/context-loading.md` Step 1 sets `{docs_path}` from `.pmos/settings.yaml` or falls back to `docs/`. The `/simulate-spec` skill creates `{docs_path}/simulations/` on first write
- Pre-push hook (`.githooks/pre-push`) requires version bump in BOTH `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` whenever any file under `plugins/pmos-toolkit/(skills|agents)/` changes — versions must match between the two manifests
- `plugin-validator` agent exists at `plugins/pmos-toolkit/agents/` (need to confirm in T11) — handles structural checks
- README.md has a Skills table that needs a new row for `/simulate-spec`
- `/spec` SKILL.md ends Phase 7 with a closing offer ("Do you have any remaining concerns, or shall we move to `/plan`?") — needs updating to mention `/simulate-spec` as optional
- `/plan` SKILL.md Phase 1 reads from `{docs_path}/specs/` — does NOT need to read simulation docs (the spec is the source of truth; simulation findings get patched into the spec). Pipeline diagram update only

---

## Prerequisites

- On `main` branch with clean working tree (verified: `git status` shows clean)
- `~/.pmos/learnings.md` exists (verified earlier)
- `docs/specs/2026-04-18-simulate-spec-design.md` exists and is committed (verified: `0216800`)
- `docs/plans/` directory created on first write of this plan
- No existing simulation skill or simulation doc to migrate

---

## File Map

| Action | File | Responsibility |
|--------|------|----------------|
| Create | `plugins/pmos-toolkit/skills/simulate-spec/SKILL.md` | The new skill — frontmatter + 12 phases + anti-patterns |
| Modify | `plugins/pmos-toolkit/.claude-plugin/plugin.json` | Bump `version` 1.2.1 → 1.3.0 |
| Modify | `plugins/pmos-toolkit/.codex-plugin/plugin.json` | Bump `version` 1.2.1 → 1.3.0 (must match) |
| Modify | `README.md` | Add `/simulate-spec` row to Skills table; update pipeline diagram if present |
| Modify | `plugins/pmos-toolkit/skills/spec/SKILL.md` | Update pipeline diagram in opening section to include `[/simulate-spec]`; update Phase 7 closing offer to mention `/simulate-spec` as optional next step |
| Modify | `plugins/pmos-toolkit/skills/plan/SKILL.md` | Update pipeline diagram in opening section to include `[/simulate-spec]` |

**Read-only references** (do NOT modify; only invoke):
- `plugins/pmos-toolkit/skills/.shared/resolve-input.md`
- `plugins/pmos-toolkit/skills/learnings/learnings-capture.md`
- `plugins/pmos-toolkit/skills/product-context/context-loading.md`

---

## Risks

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| SKILL.md exceeds 500-line convention | Medium | Extract reference content (pseudocode format example, full adversarial checklist explanations) to `simulate-spec/reference/` if line count crosses 480 mid-write. Re-check after T7. |
| Pipeline diagram inconsistency — only `/spec` and `/plan` updated, others reference old pipeline | Low | Documented as deferred in D3. Add a follow-up note in commit message; users will see updated diagram in adjacent skills which are the only ones that hand off to/from /simulate-spec. |
| Pre-push hook rejects push due to version mismatch between manifests | Low | T8 explicitly bumps both files. Verification step compares both versions are equal. |
| Smoke test (T12) reveals design issues — not just implementation issues | Medium | If smoke test surfaces design flaws, fix them in the design doc first (don't paper over in skill). Acceptable outcome: small spec patch + skill update. |
| Self-application smoke test is too "easy" — design doc is well-vetted, skill finds nothing | Low-Medium | If gap count is 0, that's a SIGNAL the skill might be too lenient. Run on an older spec (`2026-04-11-context-skill-design.md`) as a fallback to verify gap-detection capability. |
| `plugin-validator` agent doesn't exist or doesn't validate skills the way we expect | Low | Confirmed `plugins/pmos-toolkit/agents/` exists. T11 starts by listing the agent and reading its config; if it doesn't validate skills, fall back to manual structural review using the create-skill checklist. |

---

## Rollback

Not strictly needed (this is purely additive: new skill file, version bump, doc updates). If something goes wrong during commits:

- If skill content has issues post-commit but pre-push: amend or new commit
- If push is rejected by pre-push hook: fix version mismatch and re-push
- If the new skill misbehaves at invocation time: revert the skill file commit; version stays bumped (forward-only is fine, no downstream consumers depend on 1.2.1)

No data mutation, no migrations, no deploys.

---

## Tasks

### T1: Create skill scaffold (frontmatter + structural sections)

**Goal:** Create the `SKILL.md` file with frontmatter, Platform Adaptation, Track Progress, Load Learnings, and empty phase headers (0-11) plus Anti-Patterns header. Verifies the file exists, parses, and has the right top-level structure before content is filled in.

**Spec refs:** §6 (Phase Structure), §16 (Skill Frontmatter), §17 (Integration with Existing Patterns)

**Files:**
- Create: `plugins/pmos-toolkit/skills/simulate-spec/SKILL.md`

**Steps:**

- [ ] Step 1: Create the skill directory
  ```bash
  mkdir -p plugins/pmos-toolkit/skills/simulate-spec
  ```

- [ ] Step 2: Write SKILL.md with the following structure:
  - YAML frontmatter (name, description, user-invocable: true, argument-hint)
  - H1 title: `# Spec Simulation Generator`
  - Opening paragraph (2-3 sentences) explaining purpose
  - Pipeline diagram with `[/simulate-spec]` marked as `(this skill)`
  - "Announce at start" line
  - `## Platform Adaptation` section (standard text from create-skill convention)
  - `## Track Progress` section (standard text — this skill has 12 phases)
  - `## Load Learnings` section (read `~/.pmos/learnings.md`, note `## /simulate-spec` entries)
  - `## Locate Spec` section (follows `../.shared/resolve-input.md` with `phase=specs`, `label="spec"`)
  - 12 phase headers as `## Phase N: <Name>` with one-line stub each
  - `## Anti-Patterns (DO NOT)` header with placeholder

  Frontmatter values:
  ```yaml
  ---
  name: simulate-spec
  description: Pressure-test a spec against realistic and adversarial scenarios before implementation — scenario trace, artifact fitness critique, interface cross-reference, targeted pseudocode. Optional validator between /spec and /plan in the requirements -> spec -> plan pipeline. Use when the user says "simulate the design", "validate this spec", "will this design actually work", "check for gaps in the design", or has a spec ready for end-to-end scrutiny before implementation.
  user-invocable: true
  argument-hint: "<path-to-spec-doc>"
  ---
  ```

- [ ] Step 3: Verify file exists and frontmatter parses
  Run: `head -10 plugins/pmos-toolkit/skills/simulate-spec/SKILL.md`
  Expected: shows the YAML frontmatter block with all four fields

- [ ] Step 4: Verify all 12 phase headers present
  Run: `grep -c '^## Phase' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md`
  Expected: `12`

- [ ] Step 5: Commit
  ```bash
  git add plugins/pmos-toolkit/skills/simulate-spec/SKILL.md
  git commit -m "feat(pmos-toolkit): scaffold /simulate-spec skill (frontmatter + phase headers)"
  ```

**Inline verification:**
- `head -10 plugins/pmos-toolkit/skills/simulate-spec/SKILL.md` shows valid YAML frontmatter with `name: simulate-spec`
- `grep -c '^## Phase' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md` returns `12`
- `grep -E '^## (Platform Adaptation|Track Progress|Load Learnings|Locate Spec|Anti-Patterns)' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md | wc -l` returns `5`
- File is well-formed Markdown (no broken code fences) — visual inspection or `markdownlint` if available

---

### T2: Fill Phase 0 + Phase 1 (Workstream + Intake + Tier Detection + Scope Declaration)

**Goal:** Replace the Phase 0 and Phase 1 stubs with full content, including the Scope Declaration step (the design's most distinctive Phase 1 addition).

**Spec refs:** §6 (Phase Structure rows 0-1), §7 (Tier Adaptation), §8 (Phase 1 — Intake, Tier Detection & Scope Declaration)

**Files:**
- Modify: `plugins/pmos-toolkit/skills/simulate-spec/SKILL.md` (Phase 0 and Phase 1 sections only)

**Steps:**

- [ ] Step 1: Write Phase 0 content
  ```markdown
  ## Phase 0: Load Workstream Context

  Before any other work, follow the context loading instructions in `product-context/context-loading.md` (relative to the skills directory). This determines `{docs_path}` and loads workstream context if available. Use workstream context to inform critique — product constraints and tech-stack decisions shape what counts as a gap.
  ```

- [ ] Step 2: Write Phase 1 content covering all 6 substeps from spec §8:
  1. Locate spec via shared `resolve-input.md` with `phase=specs`, `label="spec"`
  2. Read end-to-end + confirm understanding (3-5 bullet summary, AskUserQuestion to confirm — with assumption fallback per Platform Adaptation)
  3. Check for existing simulation in `{docs_path}/simulations/` — ask update vs fresh start if found
  4. Detect tier from spec header. Tier 1 → announce skip + exit
  5. Scope Declaration (auto-detect layers + Non-Goals + ask user via AskUserQuestion for: in-scope, out-of-scope, companion specs, downstream consumers anticipated)
  6. Record scope (will be written into simulation doc §1 in Phase 8)

  Include the Tier Adaptation table from spec §7 inside Phase 1.

  Include explicit gates:
  - "Gate: Do not proceed to Phase 2 until tier is confirmed and scope is declared."

- [ ] Step 3: Verify content is in place
  Run: `awk '/^## Phase 0:/,/^## Phase 2:/' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md | wc -l`
  Expected: ≥ 40 lines (Phase 0 stub was 1 line, Phase 1 was 1 line; combined content should be substantial)

- [ ] Step 4: Verify all 6 Phase 1 substeps are present
  Run: `grep -cE '(Locate spec|Read.*end-to-end|existing simulation|Detect.*tier|Scope Declaration|Record scope)' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md`
  Expected: ≥ 6

- [ ] Step 5: Commit
  ```bash
  git add plugins/pmos-toolkit/skills/simulate-spec/SKILL.md
  git commit -m "feat(pmos-toolkit): /simulate-spec Phase 0-1 (workstream + intake + scope declaration)"
  ```

**Inline verification:**
- Phase 0 content references `product-context/context-loading.md`
- Phase 1 includes the Tier Adaptation table verbatim from design §7
- Phase 1 includes the Scope Declaration question template from design §8 step 5
- No "TBD" / "TODO" / "[fill in]" remaining in this section: `grep -E '(TBD|TODO|\[fill in\])' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md` returns nothing

---

### T3: Fill Phase 2 (Scenario Enumeration with 4 passes)

**Goal:** Write Phase 2 covering all four enumeration passes (extract, generate happy variants, adversarial checklist, model-driven) plus the consolidation table format and the user-confirmation gate.

**Spec refs:** §6 (Phase Structure row 2), §9 (Phase 2 — Scenario Enumeration)

**Files:**
- Modify: `plugins/pmos-toolkit/skills/simulate-spec/SKILL.md` (Phase 2 section only)

**Steps:**

- [ ] Step 1: Write Phase 2 with four sub-passes (2a, 2b, 2c, 2d) verbatim from design §9
  - 2a: Extract scenarios from spec User Journeys + Edge Cases → numbered S1, S2, ...
  - 2b: Generate missing happy-path variants (different personas, entry points, starting states)
  - 2c: Adversarial checklist with all 10 categories listed inline (Service down, Concurrent writes, Partial failures, Retries & idempotency, Stale data / cache, Permission/auth edges, Data size / pagination, Network partition / timeout, Ordering, Empty/null/malformed)
  - 2d: Model-driven pass (3-5 design-specific failure modes)

- [ ] Step 2: Include the consolidated scenario table format (from design §9):
  ```markdown
  | # | Scenario | Source | Category |
  |---|----------|--------|----------|
  ```
  Plus 1-2 example rows.

- [ ] Step 3: Add the explicit user-confirmation gate
  > "Gate: Present consolidated scenario list. Ask 'Here are N scenarios. Any missing? Any to remove?' Wait for user confirmation (or stated assumption per Platform Adaptation) before Phase 3."

- [ ] Step 4: Verify all 10 adversarial categories are present
  Run: `grep -cE '(Service.*down|Concurrent writes|Partial failures|Retries|Stale data|Permission.*auth|pagination limits|Network partition|Ordering|Empty.*null.*malformed)' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md`
  Expected: ≥ 10

- [ ] Step 5: Verify the four sub-pass headers exist (2a, 2b, 2c, 2d)
  Run: `grep -cE '^\*\*2[abcd]\.' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md`
  Expected: `4`

- [ ] Step 6: Commit
  ```bash
  git add plugins/pmos-toolkit/skills/simulate-spec/SKILL.md
  git commit -m "feat(pmos-toolkit): /simulate-spec Phase 2 (scenario enumeration with 4 passes)"
  ```

**Inline verification:**
- All 10 adversarial categories named (grep above)
- 4 sub-passes (2a-2d) clearly delineated
- Gate language is unambiguous about waiting for user confirmation

---

### T4: Fill Phases 3-5 (Scenario Trace + Artifact Fitness Critique + Interface Cross-Reference)

**Goal:** Write the three middle phases that produce the bulk of findings: scenario trace (coverage matrix), artifact fitness critique (6 buckets), and the interface ↔ core cross-reference table.

**Spec refs:** §10 (Phase 3 — Scenario Trace), §11 (Phase 4 — Artifact Fitness Critique), §12 (Phase 5 — Interface ↔ Core Cross-Reference)

**Files:**
- Modify: `plugins/pmos-toolkit/skills/simulate-spec/SKILL.md` (Phases 3, 4, 5 only)

**Steps:**

- [ ] Step 1: Write Phase 3 (Scenario Trace) with the coverage matrix table format and the gap-flagging rule from design §10:
  ```markdown
  | Scenario | Step | Spec Artifact | Status |
  |----------|------|---------------|--------|
  ```
  Plus the rule: "If no spec artifact exists for a step, flag as **GAP** and append to the Gap Register."

  Define the Gap Register here (it's referenced through Phases 3-7):
  > "**Gap Register:** A running list of all findings from Phases 3-6. Each entry: `{# | Gap | Exposed By | Severity | Disposition}`. Severity is one of: blocker / significant / minor / forward-compat."

- [ ] Step 2: Write Phase 4 (Artifact Fitness Critique) with all 6 buckets inline. For each bucket, list the critique prompts verbatim from design §11:
  - Bucket 1: Data & Storage (schema shape, constraints, indexes, lifecycle, temporal/audit, idempotency, versioning, soft-delete, config & feature flags)
  - Bucket 2: Service Interfaces (request completeness, response usefulness, error enumeration, pagination/filtering/sorting, idempotency keys, versioning, events/messages/webhooks)
  - Bucket 3: Behavior (state coverage, transition completeness, dead states, side-effect specification)
  - Bucket 4: Interface (adaptive — sub-variants for UI, CLI, Library, or skip if none)
  - Bucket 5: Wire-up (placeholder note: "handled in Phase 5")
  - Bucket 6: Operational (NFR specificity, observability, rollout/rollback/feature flags, architecture diagram)

  Include the extensibility clause verbatim:
  > "Scan the spec for any artifact types not covered above (CLI, cron, IaC resources, ML training loops, etc.). For each, apply the same 'right vs. just present' critique."

  State that findings get appended to the Gap Register with a severity label.

- [ ] Step 3: Write Phase 5 (Interface ↔ Core Cross-Reference) with:
  - The interface-type → table-format mapping (UI ↔ API, CLI ↔ API/function, External caller ↔ endpoint, Public function ↔ internal logic, or skip)
  - The standard column set from design §12
  - The reverse scan rule (every endpoint → consumer; every mutating action → endpoint; orphans become gaps)
  - One example row showing all columns filled

- [ ] Step 4: Verify all 6 fitness buckets are present as headers
  Run: `grep -cE '^\*\*Bucket [1-6]:' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md`
  Expected: `6`

- [ ] Step 5: Verify Gap Register defined exactly once
  Run: `grep -c 'Gap Register:' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md`
  Expected: `1`

- [ ] Step 6: Verify all four interface types covered in Phase 5
  Run: `grep -cE '(UI ↔ API|CLI ↔|External.*↔|Public function ↔)' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md`
  Expected: ≥ 4

- [ ] Step 7: Commit
  ```bash
  git add plugins/pmos-toolkit/skills/simulate-spec/SKILL.md
  git commit -m "feat(pmos-toolkit): /simulate-spec Phases 3-5 (trace + fitness critique + interface cross-ref)"
  ```

**Inline verification:**
- Phase 3 includes Gap Register definition with 4-tier severity labels
- Phase 4 lists all 6 buckets with critique prompts per bucket; extensibility clause present
- Phase 5 covers all 4 interface types and includes reverse-scan rule
- No bucket has placeholder content like "..." in the critique prompts

---

### T5: Fill Phases 6-7 (Targeted Pseudocode + Gap Resolution)

**Goal:** Write the two phases that produce concrete artifacts: targeted pseudocode for complex flows, and the gap-resolution protocol where the agent proposes spec patches.

**Spec refs:** §13 (Phase 6 — Targeted Pseudocode), §14 (Phase 7 — Gap Resolution)

**Files:**
- Modify: `plugins/pmos-toolkit/skills/simulate-spec/SKILL.md` (Phases 6, 7 only)

**Steps:**

- [ ] Step 1: Write Phase 6 (Targeted Pseudocode) with:
  - The 5 selection-criteria triggers verbatim from design §13 (state machine 3+ states, algorithmic complexity, multi-step write with rollback, reconciliation/retry/idempotency, concurrency-sensitive)
  - The hard cap: "Max 2-3 flows. Do NOT pseudocode every flow."
  - The format-per-flow code block from design §13:
    ```
    Flow: <name>
    Entry: <trigger>

    FUNCTION <name>(<params>):
      # English description of step
      <variable> = <db call or logic>
      IF <condition>:
        ...
      RETURN <shape>
    ```
  - The four required follow-up sections per flow: DB calls, State transitions, Error branches, Concurrency notes

- [ ] Step 2: Write Phase 7 (Gap Resolution) covering:
  - For each gap in the Gap Register, generate: context (which scenario/artifact, severity) + proposed patch (specific spec change with exact section + new content)
  - Tier-based interaction: Tier 2 inline per-gap; Tier 3 batched by category
  - The four user actions: Apply patch (use Edit tool on spec file) / Modify patch (refine then apply) / Accept as risk (log in §8 Accepted Risks) / Defer as open question (log in §9 Open Questions)
  - Spec edits use `Edit` tool — log every patch in simulation doc §10 (Spec Patches Applied)
  - Exit gate: "Every gap must have a disposition before Phase 8 writes the simulation doc."

- [ ] Step 3: Verify Phase 6 has the cap and all 5 triggers
  Run: `grep -cE '(state machine|algorithmic|Multi-step write|Reconciliation|Concurrency-sensitive)' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md`
  Expected: ≥ 5

  Run: `grep -E 'Max 2-3 flows' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md`
  Expected: matches

- [ ] Step 4: Verify Phase 7 has all four user actions
  Run: `grep -cE '(Apply patch|Modify patch|Accept as risk|Defer as open question)' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md`
  Expected: ≥ 4

- [ ] Step 5: Verify Phase 7 explicit gate
  Run: `grep -E 'Every gap must have a disposition' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md`
  Expected: matches

- [ ] Step 6: Commit
  ```bash
  git add plugins/pmos-toolkit/skills/simulate-spec/SKILL.md
  git commit -m "feat(pmos-toolkit): /simulate-spec Phases 6-7 (pseudocode + gap resolution)"
  ```

**Inline verification:**
- Phase 6 lists all 5 triggers and the 2-3 cap
- Phase 7 lists all 4 dispositions and references Edit tool for spec patches
- Gate language ensures every gap has a disposition before Phase 8

---

### T6: Fill Phases 8-9 (Write Simulation Doc + Review Loop)

**Goal:** Write the two phases that produce and quality-check the final simulation doc artifact.

**Spec refs:** §15 (Simulation Doc Template), §6 (Phase Structure rows 8-9), §4 D10 (single review loop decision)

**Files:**
- Modify: `plugins/pmos-toolkit/skills/simulate-spec/SKILL.md` (Phases 8, 9 only)

**Steps:**

- [ ] Step 1: Write Phase 8 (Write Simulation Doc) with:
  - Output path: `{docs_path}/simulations/YYYY-MM-DD-<feature>-simulation.md` (create directory if it doesn't exist)
  - Full simulation doc template from design §15 inlined as a code block (sections 1 through 11)
  - Instruction: "Populate sections from accumulated state — Scope (Phase 1), Scenario Inventory (Phase 2), Coverage Matrix (Phase 3), Fitness Findings (Phase 4), Cross-Reference (Phase 5), Pseudocode (Phase 6), Gap Register (Phases 3-6), Accepted Risks + Open Questions + Spec Patches (Phase 7), Review Log (Phase 9)."
  - Commit: `git add {docs_path}/simulations/<file> && git commit -m "docs: simulation for <feature>"`

- [ ] Step 2: Write Phase 9 (Review Loop — single pass) covering:
  - Single review pass (per design D10: simulation is already adversarial; second pass is "critique the critique")
  - Review checks: did we miss any scenarios? any artifact bucket under-critiqued? any wire-up gaps not in cross-reference table? any high-severity gap left without proposed patch?
  - If issues found: append to Gap Register, return to Phase 7 for resolution, then re-write the doc
  - Log findings in simulation doc §11 (Review Log)
  - Exit criteria: review pass found only cosmetic issues OR no issues at all
  - User confirmation gate: "Do not declare simulation complete until user confirms no further concerns."

- [ ] Step 3: Verify Phase 8 inlines the full doc template (all 11 sections)
  Run: `grep -cE '^## [0-9]+\. (Scope|Scenario Inventory|Scenario Coverage Matrix|Artifact Fitness Findings|Interface ↔|Targeted Pseudocode|Gap Register|Accepted Risks|Open Questions|Spec Patches Applied|Review Log)' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md`
  Expected: ≥ 11 (within the inlined template code block)

- [ ] Step 4: Verify Phase 9 single-pass language
  Run: `grep -E 'single (review )?(loop|pass)' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md`
  Expected: matches

- [ ] Step 5: Commit
  ```bash
  git add plugins/pmos-toolkit/skills/simulate-spec/SKILL.md
  git commit -m "feat(pmos-toolkit): /simulate-spec Phases 8-9 (write doc + review loop)"
  ```

**Inline verification:**
- Phase 8 includes the full 11-section template
- Phase 9 explicitly says single pass with rationale (or short reference to D10)
- User confirmation gate present in Phase 9

---

### T7: Fill Phases 10-11 + Anti-Patterns

**Goal:** Write the closing phases (workstream enrichment, capture learnings) and the anti-patterns section that locks in the design's "do not" rules.

**Spec refs:** §17 (Integration with Existing Patterns), §18 (Anti-Patterns)

**Files:**
- Modify: `plugins/pmos-toolkit/skills/simulate-spec/SKILL.md` (Phases 10, 11, Anti-Patterns)

**Steps:**

- [ ] Step 1: Write Phase 10 (Workstream Enrichment) using the standard template from `create-skill/SKILL.md` Convention 6:
  ```markdown
  ## Phase 10: Workstream Enrichment

  **Skip if no workstream was loaded in Phase 0.** Otherwise, follow the enrichment instructions in `product-context/context-loading.md` Step 4. For this skill, the signals to look for are:

  - Recurring gap categories across simulations → workstream `## Constraints & Scars`
  - Tech-stack-specific failure modes encountered → workstream `## Tech Stack`
  - Architectural patterns that resist gaps well → workstream `## Key Decisions`

  This phase is mandatory whenever Phase 0 loaded a workstream — do not skip it just because the core deliverable is complete.
  ```

- [ ] Step 2: Write Phase 11 (Capture Learnings) using the standard template:
  ```markdown
  ## Phase 11: Capture Learnings

  **This skill is not complete until the learnings-capture process has run.** Read and follow `learnings/learnings-capture.md` (relative to the skills directory) now. Reflect on whether this session surfaced anything worth capturing — surprising behaviors, repeated corrections, non-obvious decisions. Proposing zero learnings is a valid outcome for a smooth session; the gate is that the reflection happens, not that an entry is written.
  ```

- [ ] Step 3: Write Anti-Patterns section with all 11 items from design §18:
  - Do NOT run on Tier 1 bug-fix specs
  - Do NOT trace scenarios before user confirms the scenario list
  - Do NOT write pseudocode for every flow — max 2-3
  - Do NOT flag out-of-scope layers as gaps
  - Do NOT silently update the spec — every patch requires user approval
  - Do NOT conflate "not specified" with "wrong"
  - Do NOT run simulation without reading spec end-to-end
  - Do NOT skip Scope Declaration
  - Do NOT rubber-stamp gaps as "accepted risk" without rationale
  - Do NOT batch gap resolution until after Phase 8
  - Do NOT produce simulation doc before all gaps have a disposition

  Add a final closing line:
  > "Simulation complete. Run `/pmos-toolkit:plan` to generate the implementation plan, or review the simulation first?"

  (placed at the end of Phase 11, per `/plan` skill's pattern)

- [ ] Step 4: Verify all 11 anti-pattern items
  Run: `awk '/^## Anti-Patterns/,/^---|^$/' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md | grep -c '^- Do NOT'`
  Expected: `11`

- [ ] Step 5: Verify line count is under 500 (extract to reference/ if exceeded)
  Run: `wc -l plugins/pmos-toolkit/skills/simulate-spec/SKILL.md`
  Expected: ≤ 500. If > 500, extract the simulation-doc template (Phase 8 step 1 inlined block) to `plugins/pmos-toolkit/skills/simulate-spec/reference/simulation-doc-template.md` and replace inline with a `Read this template:` reference, then re-check.

- [ ] Step 6: Verify Phase 10 and Phase 11 are NUMBERED (not unnumbered trailing sections)
  Run: `grep -E '^## Phase (10|11):' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md | wc -l`
  Expected: `2`

- [ ] Step 7: Commit
  ```bash
  git add plugins/pmos-toolkit/skills/simulate-spec/SKILL.md plugins/pmos-toolkit/skills/simulate-spec/reference/ 2>/dev/null
  git commit -m "feat(pmos-toolkit): /simulate-spec Phases 10-11 + anti-patterns"
  ```

**Inline verification:**
- Phase 10 follows Convention 6 template with skill-specific signals
- Phase 11 has terminal-gate language ("not complete until...")
- All 11 anti-patterns present
- Closing handoff to `/pmos-toolkit:plan` present
- Line count ≤ 500

---

### T8: Bump plugin version (both manifests) [P]

**Goal:** Bump version `1.2.1 → 1.3.0` in both `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json` so the pre-push hook accepts the push and so the plugin cache invalidates.

**Spec refs:** §17 (Integration), §21 (Rollout — single commit, plugin version bump)

**Files:**
- Modify: `plugins/pmos-toolkit/.claude-plugin/plugin.json` (`version` field)
- Modify: `plugins/pmos-toolkit/.codex-plugin/plugin.json` (`version` field)

**Steps:**

- [ ] Step 1: Edit `plugins/pmos-toolkit/.claude-plugin/plugin.json`, change `"version": "1.2.1"` to `"version": "1.3.0"`

- [ ] Step 2: Edit `plugins/pmos-toolkit/.codex-plugin/plugin.json`, change `"version": "1.2.1"` to `"version": "1.3.0"`

- [ ] Step 3: Verify both files have matching version
  Run: `grep '"version"' plugins/pmos-toolkit/.claude-plugin/plugin.json plugins/pmos-toolkit/.codex-plugin/plugin.json`
  Expected: both show `"version": "1.3.0"`

- [ ] Step 4: Verify JSON validity
  Run: `python3 -c "import json; json.load(open('plugins/pmos-toolkit/.claude-plugin/plugin.json')); json.load(open('plugins/pmos-toolkit/.codex-plugin/plugin.json')); print('OK')"`
  Expected: `OK`

- [ ] Step 5: Commit
  ```bash
  git add plugins/pmos-toolkit/.claude-plugin/plugin.json plugins/pmos-toolkit/.codex-plugin/plugin.json
  git commit -m "chore(pmos-toolkit): bump version 1.2.1 -> 1.3.0 for /simulate-spec skill"
  ```

**Inline verification:**
- Both files report `1.3.0`
- Both files parse as valid JSON
- Versions match between the two manifests

---

### T9: Update README.md (Skills table) [P]

**Goal:** Add a row for `/simulate-spec` to the Skills table in README.md so the new skill is discoverable from the repo root.

**Spec refs:** §17 (Integration with Existing Patterns)

**Files:**
- Modify: `README.md` (Skills table; add pipeline diagram update if one exists)

**Steps:**

- [ ] Step 1: Read README.md Skills table to identify exact insertion point (alphabetical or pipeline-order? — observed: appears to be pipeline order: requirements, creativity, msf, spec, plan, execute, verify, ...)

- [ ] Step 2: Insert the new row immediately after `/pmos-toolkit:spec` and before `/pmos-toolkit:plan`:
  ```markdown
  | `/pmos-toolkit:simulate-spec` | Pressure-test a spec via scenario trace, artifact fitness critique, interface cross-reference, and targeted pseudocode (optional validator between /spec and /plan) |
  ```

- [ ] Step 3: If README.md contains a pipeline diagram (check for `/requirements →`), update it to include `[/simulate-spec]` between `/spec` and `/plan`

- [ ] Step 4: Verify the new row is present
  Run: `grep -F '/pmos-toolkit:simulate-spec' README.md`
  Expected: matches one row in the Skills table

- [ ] Step 5: Verify the row is positioned between spec and plan
  Run: `grep -nE '/pmos-toolkit:(spec|simulate-spec|plan)' README.md`
  Expected: line numbers in order spec → simulate-spec → plan

- [ ] Step 6: Commit
  ```bash
  git add README.md
  git commit -m "docs: add /simulate-spec to README skills table"
  ```

**Inline verification:**
- Row present and ordered correctly between spec and plan
- Description matches the skill's frontmatter description shape (terse, mentions optional validator)
- Pipeline diagram (if present) updated

---

### T10: Update pipeline diagrams in /spec and /plan [P]

**Goal:** Update the pipeline diagrams in `/spec` and `/plan` SKILL.md files so users see `[/simulate-spec]` as an optional step between them. Update `/spec`'s closing offer to mention it.

**Spec refs:** §5 (Pipeline Position), D3 (defer other diagrams)

**Files:**
- Modify: `plugins/pmos-toolkit/skills/spec/SKILL.md` (pipeline diagram in opening section + Phase 7 closing offer)
- Modify: `plugins/pmos-toolkit/skills/plan/SKILL.md` (pipeline diagram in opening section)

**Steps:**

- [ ] Step 1: In `/spec` SKILL.md, find the existing pipeline diagram (currently around line 13):
  ```
  /requirements  →  [/msf, /creativity]  →  /spec  →  /plan  →  /execute  →  /verify
                     optional enhancers     (this skill)
  ```
  Replace with:
  ```
  /requirements  →  [/msf, /creativity]  →  /spec  →  [/simulate-spec]  →  /plan  →  /execute  →  /verify
                     optional enhancers     (this skill)    optional validator
  ```

- [ ] Step 2: In `/spec` SKILL.md, find the Phase 7 closing offer (currently `"I believe the spec is ready. Do you have any remaining concerns, or shall we move to /plan?"`).
  Replace with:
  > "I believe the spec is ready. Do you have any remaining concerns? Next options:
  > - `/pmos-toolkit:simulate-spec` — pressure-test the design before planning (recommended for Tier 2-3)
  > - `/pmos-toolkit:plan` — proceed directly to implementation planning"

- [ ] Step 3: In `/plan` SKILL.md, find the existing pipeline diagram (currently around line 12):
  ```
  /requirements  →  [/msf, /creativity]  →  /spec  →  /plan  →  /execute  →  /verify
                     optional enhancers              (this skill)
  ```
  Replace with:
  ```
  /requirements  →  [/msf, /creativity]  →  /spec  →  [/simulate-spec]  →  /plan  →  /execute  →  /verify
                     optional enhancers              optional validator     (this skill)
  ```

- [ ] Step 4: Verify both pipeline diagrams now reference `/simulate-spec`
  Run: `grep -l 'simulate-spec' plugins/pmos-toolkit/skills/spec/SKILL.md plugins/pmos-toolkit/skills/plan/SKILL.md`
  Expected: both file paths listed

- [ ] Step 5: Verify `/spec` closing offer mentions both options
  Run: `grep -E 'simulate-spec.*Tier 2-3|pressure-test the design' plugins/pmos-toolkit/skills/spec/SKILL.md`
  Expected: matches

- [ ] Step 6: Commit
  ```bash
  git add plugins/pmos-toolkit/skills/spec/SKILL.md plugins/pmos-toolkit/skills/plan/SKILL.md
  git commit -m "docs(pmos-toolkit): reference /simulate-spec in /spec and /plan pipeline diagrams"
  ```

**Inline verification:**
- Both `/spec` and `/plan` SKILL.md contain `simulate-spec` references
- `/spec` Phase 7 closing offer presents both options (simulate-spec recommended for Tier 2-3, plan as direct path)
- Pipeline diagrams use the same shape: `/spec  →  [/simulate-spec]  →  /plan`

---

### T11: Plugin validation + content coverage review

**Goal:** Run the plugin-validator agent to check structural correctness, then dispatch a code-review subagent to compare the new SKILL.md against the design doc for content coverage.

**Spec refs:** §20 (Testing & Verification Strategy), §17 (multi-agent code review per `/verify` learning)

**Files:**
- No file modifications expected. If issues are found, fix in this task and re-run.

**Steps:**

- [ ] Step 1: Confirm plugin-validator agent exists
  Run: `ls plugins/pmos-toolkit/agents/`
  Expected: lists at least one agent file. If `plugin-validator.md` exists, use it; otherwise note absence and use the `plugin-dev:plugin-validator` agent (available via the cached plugin per the agent list).

  **Fallback:** If neither validator is reachable, perform manual structural review using the `create-skill/SKILL.md` "Checklist Before Saving" (Convention 12 / lines 165-183) as the rubric. Walk every checkbox and report results inline.

- [ ] Step 2: Dispatch plugin-validator agent
  Use the Agent tool with `subagent_type: plugin-dev:plugin-validator` and prompt:
  > "Validate the pmos-toolkit plugin. Specifically check the new skill at `plugins/pmos-toolkit/skills/simulate-spec/SKILL.md`. Report: (a) frontmatter validity, (b) plugin manifest version match between `.claude-plugin/plugin.json` and `.codex-plugin/plugin.json`, (c) any structural issues with the new skill (broken markdown, missing required sections per the create-skill conventions). Report under 300 words."

- [ ] Step 3: Dispatch a code-review subagent for content coverage
  Use the Agent tool with `subagent_type: superpowers:code-reviewer` and prompt:
  > "Compare the new skill `plugins/pmos-toolkit/skills/simulate-spec/SKILL.md` against the design spec `docs/specs/2026-04-18-simulate-spec-design.md`. For each spec section (1-22), confirm the corresponding skill content is present and faithful. Specifically verify: (a) all 12 phases present and numbered correctly, (b) all 10 adversarial categories named in Phase 2, (c) all 6 fitness buckets present in Phase 4 with critique prompts, (d) all 5 pseudocode triggers in Phase 6, (e) all 4 gap dispositions in Phase 7, (f) all 11 sections in the simulation doc template in Phase 8, (g) all 11 anti-patterns. Report: missing items, faithful sections, and any drift from the design. Under 400 words."

- [ ] Step 4: Address any issues found
  - If plugin-validator flags errors: fix them in this task (additional commits with `fix(pmos-toolkit):` prefix).
  - If coverage review flags missing content: add it to the appropriate phase, commit with `fix(pmos-toolkit): /simulate-spec coverage gap — <what>`.
  - If both reports are clean: proceed to T12.

- [ ] Step 5: Verify line count remains under 500
  Run: `wc -l plugins/pmos-toolkit/skills/simulate-spec/SKILL.md`
  Expected: ≤ 500

- [ ] Step 6: Verify no placeholder language remains
  Run: `grep -nE '(TBD|TODO|FIXME|\[fill in\]|\[placeholder\])' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md`
  Expected: no matches

**Inline verification:**
- plugin-validator returns clean (or all issues fixed)
- Coverage review confirms all design-spec sections are reflected
- Line count ≤ 500
- No placeholder language

---

### T12: Smoke invocation + final verification + push

**Goal:** Run the new skill end-to-end against a real spec to verify it works, then push.

**Spec refs:** §20 (Testing & Verification Strategy — smoke test)

**Files:**
- Possibly creates: `docs/simulations/2026-04-18-<feature>-simulation.md` (smoke test output — kept as evidence; commit it to preserve the evidence)
- Possibly modifies: spec under test, if real gaps surface and user approves patches during smoke run

**Steps:**

- [ ] Step 1: Restart Claude Code session or run `/reload-plugins` so the new skill is discoverable.
  > **Manual step:** This requires the user to restart or reload. Pause here and prompt the user.

- [ ] Step 2: Invoke the new skill on the design doc itself
  ```
  /pmos-toolkit:simulate-spec docs/specs/2026-04-18-simulate-spec-design.md
  ```
  Expected behavior:
  - Phase 0 loads workstream context (none for this repo — fallback to docs/)
  - Phase 1 reads the design doc, detects tier (this design doc reads as Tier 2-3), runs Scope Declaration
  - Phase 2 enumerates scenarios (since the design doc itself is a spec for a SKILL, the "scenarios" are: invocation flows, multi-tier behavior, scope variants, gap-disposition paths)
  - Phases 3-7 produce a coverage matrix, fitness findings, cross-reference table (likely "library" interface variant), pseudocode (probably 0 — skill itself isn't algorithmic), gap resolution
  - Phase 8 produces simulation doc at `docs/simulations/2026-04-18-simulate-spec-simulation.md`
  - Phase 9 single review loop
  - Phases 10-11 enrichment + learnings

- [ ] Step 3: Inspect the simulation doc that was produced
  - Verify all 11 sections from template are populated
  - Verify Gap Register has at least one entry (zero entries = signal that simulation is too lenient; if zero, run on a different spec like `2026-04-12-pipeline-input-resolution-design.md` as a fallback)
  - Verify any gap dispositions logged are coherent

- [ ] Step 4: If smoke test surfaces any real issues with the skill itself (vs. the design doc being simulated), fix them in additional commits with `fix(pmos-toolkit): /simulate-spec — <what>` prefix

- [ ] Step 5: Run final verification commands

  - [ ] **Plugin manifest sanity check (both versions match, both bumped):**
    ```bash
    grep '"version"' plugins/pmos-toolkit/.claude-plugin/plugin.json plugins/pmos-toolkit/.codex-plugin/plugin.json
    ```
    Expected: both `"version": "1.3.0"`

  - [ ] **Skill file is well-formed:**
    ```bash
    head -10 plugins/pmos-toolkit/skills/simulate-spec/SKILL.md
    ```
    Expected: valid YAML frontmatter

  - [ ] **All 12 phases present:**
    ```bash
    grep -c '^## Phase' plugins/pmos-toolkit/skills/simulate-spec/SKILL.md
    ```
    Expected: `12`

  - [ ] **README references the new skill:**
    ```bash
    grep -F '/pmos-toolkit:simulate-spec' README.md
    ```
    Expected: matches

  - [ ] **/spec and /plan reference the new skill in pipeline diagrams:**
    ```bash
    grep -l 'simulate-spec' plugins/pmos-toolkit/skills/spec/SKILL.md plugins/pmos-toolkit/skills/plan/SKILL.md
    ```
    Expected: both file paths

  - [ ] **Git status is clean (or only contains the simulation-doc smoke output):**
    ```bash
    git status
    ```
    Expected: working tree clean OR only `docs/simulations/<file>` showing as untracked

  - [ ] **Git log shows expected commit chain:**
    ```bash
    git log --oneline -15
    ```
    Expected: 7-12 commits matching the task pattern (T1-T12) with `feat(pmos-toolkit):`, `chore(pmos-toolkit):`, `docs:` prefixes

- [ ] Step 6: Commit smoke test simulation doc (if produced) for evidence
  ```bash
  git add docs/simulations/
  git commit -m "docs: add smoke-test simulation output for /simulate-spec"
  ```

- [ ] Step 7: Push (pre-push hook will validate version bump)
  ```bash
  git push origin main
  ```
  > **Pause here for user confirmation.** Pushing to main is a shared-state action — confirm with user before pushing.
  > - If user **approves**: run the push command; pre-push hook validates version bump.
  > - If user **declines**: leave all commits local. They can `git push origin main` themselves later. Plan is still considered complete — push is a deferred action, not a blocker.

  Expected (if push proceeds): pre-push hook accepts (versions bumped correctly, manifests match), push succeeds.

**Cleanup:**

- [ ] Remove any temporary test files (none expected for this task)
- [ ] Verify no debug logging left in skill content
- [ ] Update `~/.pmos/learnings.md` if any session-specific learnings emerged (handled via Phase 11 of the smoke-test invocation, automatic)

**Inline verification:**
- Smoke test produces a well-formed simulation doc
- All file-state checks pass
- Push succeeds (or is queued for user)

---

## Review Log

| Loop | Findings | Changes Made |
|------|----------|--------------|
| 1    | (a) TDD framing unclear for prompt content; (b) T12 push step ambiguous on user decline; (c) T11 fallback path needs stronger statement when no validator reachable | (a) Added "TDD adaptation note" to Overview explaining write→verify-presence→commit pattern; (b) Expanded T12 step 7 with explicit approve/decline branches; (c) Added explicit fallback rubric reference in T11 step 1 |
| 2    | (pending) | (pending) |
