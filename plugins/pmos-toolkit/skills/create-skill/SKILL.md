---
name: create-skill
description: Create a new skill in the user's agent-skills repo via a tiered workflow — interview, auto-tier, write spec to ~/.pmos/skill-specs/ (Tier 2+), adversarial review via /grill (Tier 3), then implement against the spec applying project conventions (save path, platform adaptation, description quality, findings protocol, release prereqs). Use when the user says "create a skill", "make a new skill", "turn this into a skill", "spec out a skill", or "I want a slash command for this".
user-invocable: true
argument-hint: "<what the skill should do> [--tier 1|2|3]"
---

# Create Skill

Tiered skill-creation workflow: gather requirements, write a spec to disk (Tier 2+), adversarially review it via `/grill` (Tier 3), then implement against the spec applying the project's Conventions. Replaces "draft directly from interview" with a checkpoint that catches design gaps before code.

**Announce at start:** "Using create-skill — running the tiered workflow: requirements → spec → (grill) → implement."

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:

- **No `AskUserQuestion`:** Conduct the interview as numbered free-form questions; record answers in the spec doc. Tier-pick falls back to "ask the user explicitly".
- **No subagents:** Run `/grill` inline (sequential question-by-question) rather than dispatching it as a separate agent.
- **No `/grill` available:** Skip Phase 5; emit a one-paragraph note in the spec under §14 Open questions warning the user that adversarial review was skipped.

## Track Progress

This skill has multiple phases. Create one task per phase using your agent's task-tracking tool (e.g., `TaskCreate` in Claude Code, `TodoWrite` in older harnesses, equivalent elsewhere). Mark each task in-progress when you start it and completed as soon as it finishes — do not batch completions.

## Load Learnings

Read `~/.pmos/learnings.md` if it exists. Note any entries under `## /create-skill` and factor them into your approach for this session.

---

## Phase 1: Intent capture

Confirm what the user wants to build in 2-3 sentences. If the slash argument is vague ("a skill that does X"), ask one clarifying `AskUserQuestion` to nail down the core verb (generates / critiques / tracks / orchestrates / transforms).

Defer detailed requirements to Phase 3 — Phase 1 is just enough signal to tier the work.

---

## Phase 2: Auto-tier

Pick a tier from interview signals. Honor `--tier 1|2|3` if the user passed it.

| Tier | Triggers | Workflow |
|------|----------|----------|
| **1** | One-shot utility; ≤ 2 phases; no `assets/`; no `reference/`; no eval rubric; no workstream awareness | Skip Phases 4, 5, 6 (plan). Implement (Phase 7) directly from the interview. Run Phase 8 /verify mandatorily. |
| **2** | 3+ phases OR has `reference/` files OR has `assets/` OR uses workstream context OR has a structured output format | Run Phases 4 (spec), 6 (plan), 7 (implement), 8 (/verify). Skip Phase 5 (grill). |
| **3** | 5+ phases AND (has eval rubric OR has external integrations OR multi-source/multi-tier behavior OR pipeline integration) | Run Phases 4, 5 (grill), 6 (plan), 7 (implement), 8 (/verify). Full pipeline. |

Surface the tier choice to the user via `AskUserQuestion` with the inferred tier as the recommended option and one-line rationale; allow override. Skip the question only if `--tier` was passed explicitly.

---

## Phase 3: Requirements gathering

Conduct a structured interview to populate every section of the spec template (`reference/spec-template.md`). Use `AskUserQuestion` batches of ≤ 4 per call. Cover at minimum:

- Source / inputs (what does the skill consume?)
- Output (what files / in-conversation artifacts does it produce?)
- Pipeline fit and workstream awareness
- Phase outline (the rough numbered list)
- External tools / dependencies (Playwright, MCP, other skills)
- Asset and reference file inventory
- Whether review/refinement loops are needed (drives Findings Presentation Protocol)

For Tier 1, this phase is shorter — skip the asset/reference/protocol questions and go straight to the phase outline.

---

## Phase 4: Write spec to disk (Tier 2+)

**Skip if Tier 1.** Otherwise:

1. Resolve the spec path: `~/.pmos/skill-specs/<skill-name>/YYYY-MM-DD_<slug>.md`. If `<skill-name>` directory doesn't exist, create it. `<slug>` defaults to `initial`; bump to `v2`, `v3`, etc. on subsequent specs for the same skill.
2. Read `reference/spec-template.md` and fill every section from the Phase 3 interview answers. Sections you can't fill go under §14 Open questions.
3. Write the file. Set `Status: draft` in the spec header. Spec status lifecycle across the full pipeline: `draft → grilled (Tier 3, after Phase 5) → planned (Tier 2+, after Phase 6) → approved → implemented (after Phase 7) → verified (after Phase 8)`.
4. Show the user the spec path and ask via `AskUserQuestion`:

```
question: "Spec drafted at <path>. Review and approve, edit, or re-interview?"
options:
  - Approve and continue (Recommended)
  - Edit — open spec for manual changes, then continue
  - Re-interview — Phase 3 missed something; loop back
  - Cancel
```

Do not proceed to Phase 5, Phase 6, or Phase 7 until status is `approved`.

---

## Phase 5: Adversarial review via /grill (Tier 3 only)

**Skip if Tier 1 or Tier 2.** Otherwise:

1. Preserve the pre-grill spec: copy current spec to `YYYY-MM-DD_<slug>_pre-grill.md`.
2. Invoke `/pmos-toolkit:grill` with the spec path as the target. Specifically prompt grill to focus on:
   - Phase boundaries: are any phases silently skippable, and what's the gate?
   - Platform fallbacks: which tool dependencies have no fallback path?
   - Findings Presentation Protocol: is every review loop covered, with disposition options?
   - Description triggers: would a user typing X find this skill?
   - Release prereqs: is anything beyond README + version bump needed?
   - Convention checklist: any item that's vague enough to be silently skipped?
3. Apply dispositions back to the spec via `AskUserQuestion`-batched updates (Apply / Modify / Skip / Defer pattern, ≤ 4 per call).
4. Bump spec status to `grilled`, then to `approved` after a final user sign-off.

If `/grill` is unavailable, fall back to the platform-adaptation note (skip with warning logged in §14).

---

## Phase 6: Plan via /pmos-toolkit:plan (Tier 2+)

**Skip if Tier 1.** Otherwise:

1. Resolve the spec path written in Phase 4.
2. Invoke `/pmos-toolkit:plan <spec-path>`. Default-foreground.
3. On success: spec status `approved → planned`. The user approves the plan doc as part of `/plan`'s own Phase 5 review — do not gate again here.
4. On failure:
   - **`/plan` skill missing:** log a one-paragraph warning to spec §14, then `AskUserQuestion`: **Continue (skip plan, log warning)** / **Abort**. Default Continue. (Mirrors how Phase 5 handles missing `/grill`.)
   - **`/plan` cancelled or errored:** `AskUserQuestion`: **Retry** / **Abort**. Default Retry once; on second failure show the same dialog.
5. Do not proceed to Phase 7 until plan status is `approved` (or the user explicitly chose Continue on missing).

---

## Phase 7: Implement against the spec

This is where the actual SKILL.md, `reference/`, and `assets/` get written. Apply the **Conventions** section below as the implementation reference. If a plan was produced in Phase 6, implement against it; the plan is the source of truth, the spec is its parent. Every spec section maps to a part of SKILL.md:

| Spec section | SKILL.md location |
|--------------|-------------------|
| §1 description | frontmatter `description:` |
| §2 argument hint | frontmatter `argument-hint:` |
| §5 phases | numbered Phase sections in body |
| §7-§8 inventory | files written under `assets/` and `reference/` |
| §10 Findings Protocol | inline in the relevant phase |
| §11 Platform fallbacks | `## Platform Adaptation` section |
| §12 Anti-patterns | `## Anti-patterns` section |

After implementation, bump spec status to `implemented`.

For Tier 1 (no spec): use the Phase 3 interview answers directly as the implementation guide.

---

## Phase 8: Verify via /pmos-toolkit:verify (mandatory all tiers)

**Mandatory at all tiers — no skip gate.**

1. Resolve the spec path (or, for Tier 1 with no spec, the new SKILL.md path itself).
2. Invoke `/pmos-toolkit:verify <spec-path>`. Default-foreground.
3. The release-prereq items (README row, version bump) live as FRs in the spec — `/verify` Phase 5 4b reads the spec and grades each FR-ID, so no separate hint mechanism is needed.
4. On success (no Critical findings): spec status `implemented → verified`.
5. On unresolved blocker findings: spec status stays `implemented`. The skill is flagged as not-ready in the Phase 8 pipeline-status table. The user may re-invoke `/pmos-toolkit:verify <spec-path>` directly (it is idempotent) — `/create-skill` itself has no `--resume` flag.
6. On `/verify` skill missing: HARD ERROR. `AskUserQuestion`: **Install/upgrade /verify** / **Accept-as-risk override** (logs a warning to spec §14 and sets status `unverified`) / **Abort**. Default Abort.
7. After Phase 8 returns, emit a pipeline-status summary table to chat (mirror of `/update-skills` Phase 8):

   | phase | status | artifact path | timestamp |
   |---|---|---|---|
   | requirements | completed/skipped/failed | <path or n/a> | <YYYY-MM-DD> |
   | spec | … | … | … |
   | grill | … | … | … |
   | plan | … | … | … |
   | implement | … | … | … |
   | verify | … | … | … |

---

## Phase 9: Capture Learnings

**This skill is not complete until the learnings-capture process has run.** Read and follow `learnings/learnings-capture.md` (relative to the skills directory) now. Reflect on whether this session surfaced anything worth capturing about `/create-skill` itself — tiering signals that misfired, spec sections that were chronically empty, grill questions that should be added to the default prompt. Proposing zero learnings is a valid outcome.

---

## Conventions (implementation reference for Phase 7)

The conventions below are the *content* of a well-formed SKILL.md. Phase 7 produces the SKILL.md by applying them; Phase 4 (spec) declares which conventions apply to this skill.

## Convention 1: Save Location

The `pmos-toolkit` plugin manifest at `plugins/pmos-toolkit/.claude-plugin/plugin.json` (and its codex twin) loads skills from a single directory:

```
~/Desktop/Projects/agent-skills/plugins/pmos-toolkit/skills/<skill-name>/SKILL.md
```

**Save new skills here.** Anywhere else (root `skills/`, anywhere under `plugins/<other-plugin>/`) will not be picked up by `pmos-toolkit` and will be flagged for relocation by `/push` Phase 1a.

The `<skill-name>` directory should be lowercase, hyphenated (e.g., `create-skill`, `msf`, `verify`). Check for name collisions:

```bash
ls ~/Desktop/Projects/agent-skills/plugins/pmos-toolkit/skills/
```

Once saved at the correct path, the skill is invokable as `/pmos-toolkit:<skill-name>` after a session restart or `/reload-plugins`. No symlink, no manual registration.

**Reference paths.** Convention 6 instructs new skills to reference `learnings/learnings-capture.md` and `_shared/pipeline-setup.md` as relative paths. These resolve as **siblings** inside `plugins/pmos-toolkit/skills/` — saving the new skill anywhere else will leave those references dangling.

**Sibling skills available to reference:**

```bash
ls ~/Desktop/Projects/agent-skills/plugins/pmos-toolkit/skills/ | grep -E '^(learnings|product-context|_shared)$'
```

---

## Convention 2: Cross-Platform Adaptation

Every skill MUST include this section after the "Announce at start" line:

```markdown
## Platform Adaptation

These instructions use Claude Code tool names. In other environments:
- **No `AskUserQuestion`:** State your assumption, document it in the output, and proceed. The user reviews after completion.
- **No subagents:** Perform research and analysis sequentially as a single agent.
- **No Playwright MCP:** Note browser-based verification as a manual step for the user.
```

Additionally, when writing skill instructions:
- Do NOT make `AskUserQuestion` the only way to get user input — always provide a "proceed with stated assumptions" fallback
- Do NOT delegate core logic to external plugins — include enough inline instructions that the skill works standalone
- Do NOT assume MCP tools are available — treat them as optional enhancements
- Do NOT assume subagent dispatch — write instructions that work sequentially too

**Self-contained skills should inline these patterns where applicable:**
- **Setup** — environment preparation, dependency detection, workspace isolation
- **Self-review & refinement loops** — review own output against requirements, iterate until quality bar is met (minimum 2 loops)
- **Escalation policy** — when to stop and ask for help vs. proceeding with stated assumptions
- **Evidence standards** — what constitutes proof that a step succeeded (command output, not "should work")

### Review loops MUST present findings via `AskUserQuestion`

Any skill that includes a self-review or refinement loop (requirements, spec, plan, simulate-spec, etc. all do) **must not dump findings as prose and wait for a free-form reply**. Prose dumps force the user to hand-write dispositions for each finding and lose structure.

Instead, every review loop in a new skill must include a "Findings Presentation Protocol" section that specifies:

1. **Group findings by category** (max 4 per batch — respects the `AskUserQuestion` 4-question limit).
2. **One question per finding** via `AskUserQuestion`:
   - `question`: one-sentence finding + proposed fix (concrete, not vague)
   - `options`: **Fix as proposed** / **Modify** / **Skip** / **Defer** (adapt names to domain — e.g., simulate-spec uses "Apply patch / Modify patch / Accept as risk / Defer as open question")
3. **Batch up to 4 questions per call**; issue multiple sequential calls for more findings.
4. **Open-ended findings** (those needing numeric values, free-form text, or trade-off discussion) should be asked inline as a follow-up after the structured batch — never shoehorn into options.
5. **Platform fallback** for environments without `AskUserQuestion`: present a numbered findings table with a disposition column; do NOT silently self-fix.
6. **Anti-pattern to call out explicitly:** "A wall of prose ending in 'Let me know what you'd like to fix.' Always structure the ask."

See the `requirements`, `spec`, `plan`, and `simulate-spec` skills for reference implementations of this protocol.

---

## Convention 3: Description Quality

The `description:` field in frontmatter must include:

1. **What it does** (1 sentence)
2. **Pipeline position** if it fits in the requirements→spec→plan→execute→verify pipeline
3. **Natural trigger phrases** — common things users say that should invoke this skill

Example of a good description:
```
description: Create a detailed technical specification from a requirements document — architecture, API contracts, DB schema, frontend design, testing strategy, verification plan. Second stage in the requirements -> spec -> plan pipeline. Auto-tiers by scope. Use when the user says "write the technical design", "design the system", "create the spec", or has a requirements doc ready for detailed design.
```

The trigger phrases matter because skill descriptions are how the agent decides whether to invoke a skill. Without natural-language triggers, users have to remember the exact slash command name.

---

## Convention 4: Pipeline Awareness

If the new skill fits into the existing pipeline, include the full pipeline diagram:

```markdown
/requirements  →  [/msf-req, /creativity]  →  /spec  →  /plan  →  /execute  →  /verify
                   optional enhancers
```

Mark the new skill's position with `(this skill)`. If it's an optional enhancer, show it in the brackets. If it's standalone (like `/verify`), note that in the description.

---

## Convention 5: Standard Frontmatter

Every skill must have at minimum:

```yaml
---
name: <skill-name>
description: <what + when — see Convention 3>
user-invocable: true
argument-hint: "<what to pass>"
---
```

---

## Convention 6: Learning Integration

Every pipeline skill MUST include two learning integration points:

**At startup** (in Phase 0 or as a standalone section after Platform Adaptation):

```markdown
Read `~/.pmos/learnings.md` if it exists. Note any entries under `## /skill-name` and factor them into your approach for this session.
```

**At end** — Workstream Enrichment and Capture Learnings MUST be numbered phases (not trailing unnumbered sections), otherwise they get skipped. Place them as the last two phases, before Anti-Patterns:

```markdown
## Phase N: Workstream Enrichment

**Skip if no workstream was loaded in Phase 0.** Otherwise, follow `_shared/pipeline-setup.md` Section C. For this skill, the signals to look for are:

- [skill-specific signal] → workstream `## [Section]`

This phase is mandatory whenever Phase 0 loaded a workstream — do not skip it just because the core deliverable is complete.

---

## Phase N+1: Capture Learnings

**This skill is not complete until the learnings-capture process has run.** Read and follow `learnings/learnings-capture.md` (relative to the skills directory) now. Reflect on whether this session surfaced anything worth capturing — surprising behaviors, repeated corrections, non-obvious decisions. Proposing zero learnings is a valid outcome for a smooth session; the gate is that the reflection happens, not that an entry is written.
```

If the skill doesn't load workstream context in Phase 0, omit the Workstream Enrichment phase and only include Capture Learnings.

This ensures new skills participate in the global feedback loop from day one and that the feedback loop actually runs.

---

## Convention 7: Progress Tracking for Multi-Phase Skills

If the skill has **3 or more sequential phases, steps, or user-approval gates**, include a progress-tracking instruction near the top (after Platform Adaptation). Single-shot skills (e.g., `/commit`, `/changelog`) should skip this — the overhead clutters them.

Use platform-neutral phrasing so the instruction works across Claude Code, Codex, and other agents:

```markdown
## Track Progress

This skill has multiple phases. Create one task per phase using your agent's task-tracking tool (e.g., `TodoWrite` in Claude Code, equivalent in other agents). Mark each task in-progress when you start it and completed as soon as it finishes — do not batch completions.
```

Rule of thumb: if a user reading the skill would benefit from seeing which phase you're in, add the tracking instruction. Otherwise don't.

---

## Anti-patterns

- **Skipping the spec at Tier 2+ to save time.** The spec is the cheapest place to catch a design gap. Skipping it pushes the cost into Phase 7 rewrites or, worse, into the first real invocation.
- **Auto-tiering a Tier 3 skill as Tier 2 because the user wants to ship fast.** Tier 3 indicators (eval rubric, multi-source, pipeline integration) mean the failure modes are non-obvious — `/grill` exists precisely to find them before code lands. Surface the tier choice; let the user override knowingly.
- **Reading the spec template once and then improvising.** Phase 4 must walk every section of `reference/spec-template.md`. Sections you genuinely can't fill go under §14 Open questions, not silently omitted.
- **Approving a spec with §14 Open questions still populated at Tier 2.** Tier 3 routes them through `/grill`; Tier 2 has no such gate, so the user must explicitly resolve them or accept the risk in writing before Phase 6 (/plan).
- **Implementing before status is `approved`.** Phase 7 is gated by approved spec status (and, at Tier 2+, an approved plan from Phase 6). "Approve and continue" is one click; skipping it loses the audit trail and the rollback point.
- **Writing the SKILL.md without referring back to the spec.** Phase 7 implements *against* the spec (and the Phase 6 plan, when present), not from memory of the interview. Each spec section maps to a SKILL.md location (table in Phase 7) — use it.
- **Treating the conventions as a checklist instead of an implementation guide.** The Conventions section below is what a well-formed SKILL.md *contains*; the spec declares which conventions apply; Phase 7 produces the SKILL.md by composing them. Skipping the spec turns conventions into post-hoc compliance.
- **Skipping the /plan phase at Tier 2+.** Plan is the cheapest place to map the spec to TDD-friendly tasks before code lands. Without it, Phase 7 implements from the spec directly and the implementor reverse-engineers task ordering.
- **Skipping /verify because /execute looked clean.** /verify is non-skippable per the per-skill pipeline contract; no opt-out at any tier. Visual confidence after implement is not evidence — /verify Phase 2 lint, Phase 3 multi-agent review, and Phase 5 spec compliance are the contract.
