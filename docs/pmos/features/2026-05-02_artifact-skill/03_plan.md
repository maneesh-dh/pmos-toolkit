# /artifact Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the `/artifact` skill in pmos-toolkit per design spec at `docs/superpowers/specs/2026-05-02-artifact-skill-design.md`.

**Architecture:** Skill = SKILL.md (process orchestration) + `templates/<slug>/{template.md,eval.md}` (4 built-in templates) + `presets/<slug>.md` (4 built-in writing-style presets) + `reviewer-prompt.md` (subagent system prompt). User-owned templates and presets live at `~/.pmos/artifacts/` (created on first run). The skill itself produces no runtime code at author time — its outputs are markdown artifacts (PRD, ED, EDD, Discovery docs) emitted at invocation time.

**Tech Stack:** Markdown (SKILL.md, templates, presets), YAML frontmatter. No build step. Plugin delivery via `pmos-toolkit` (auto-discovery via `"skills": "./skills/"` in `plugin.json`).

**Reference implementations to mirror style of:**

- `plugins/pmos-toolkit/skills/mytasks/SKILL.md` — subcommand routing pattern (Phase 0)
- `plugins/pmos-toolkit/skills/wireframes/SKILL.md` — self-refinement loop with reviewer subagent + Findings Presentation Protocol
- `plugins/pmos-toolkit/skills/spec/SKILL.md` — multi-tier templates + Phase 0 context loading
- `plugins/pmos-toolkit/skills/_shared/feature-folder.md` — feature folder resolution (consume verbatim)
- `plugins/pmos-toolkit/skills/product-context/context-loading.md` — workstream loading (consume verbatim)
- `plugins/pmos-toolkit/skills/learnings/learnings-capture.md` — terminal learnings phase (consume verbatim)

**Spec reference:** All eval-item content, section structures, and tier sets are canonically defined in the spec. Tasks below cite spec section numbers (e.g., "spec §4.1") rather than re-paste 300+ lines of eval criteria. The implementer writes the template files following the spec.

**Verification model:** Skills are prompt-engineering artifacts, not executables. Per-task "tests" are file-existence checks, frontmatter validation, eval-section ID consistency, line-count sanity caps, and cross-reference integrity. End-to-end smoke test (Task 16) is a real `/artifact create prd` dry-run on a synthetic feature folder.

---

## File Structure

```
plugins/pmos-toolkit/skills/artifact/
  SKILL.md                              # main entrypoint, target ≤700 lines
  reviewer-prompt.md                    # subagent system prompt for refinement loop
  templates/
    prd/
      template.md                       # spec §4.1 — Lite 7 / Full 14 sections
      eval.md                           # spec §4.1 eval table — kind|check|gap_question|severity
    experiment-design/
      template.md                       # spec §4.2 — Lite 7 / Full 13
      eval.md                           # spec §4.2 eval table
    eng-design/
      template.md                       # spec §4.3 — Lite 8 / Full 14
      eval.md                           # spec §4.3 eval table
    discovery/
      template.md                       # spec §4.4 — single tier 7
      eval.md                           # spec §4.4 eval table
  presets/
    concise.md                          # nested bullets
    tabular.md                          # tables-by-default
    narrative.md                        # Amazon PR/FAQ prose
    executive.md                        # TL;DR-heavy, scannable
```

User-owned (created on first run, never inside the plugin):

```
~/.pmos/artifacts/
  templates/<user-slug>/{template.md,eval.md}
  presets/<user-slug>.md
```

---

## Task 1: Scaffold directory + plugin version bump + SKILL.md frontmatter

**Files:**
- Create: `plugins/pmos-toolkit/skills/artifact/SKILL.md`
- Modify: `plugins/pmos-toolkit/.claude-plugin/plugin.json` (bump version to `2.10.0`, add keyword `artifact`)

- [ ] **Step 1: Create skill directory**

```bash
mkdir -p plugins/pmos-toolkit/skills/artifact/templates/{prd,experiment-design,eng-design,discovery}
mkdir -p plugins/pmos-toolkit/skills/artifact/presets
```

- [ ] **Step 2: Bump plugin manifest**

Edit `plugins/pmos-toolkit/.claude-plugin/plugin.json`: change `"version": "2.9.0"` → `"version": "2.10.0"`. Add `"artifact"` to the `keywords` array.

- [ ] **Step 3: Write SKILL.md frontmatter and skeleton**

Write to `plugins/pmos-toolkit/skills/artifact/SKILL.md`:

```markdown
---
name: artifact
description: Generate, refine, and update structured PM/eng artifacts (PRD, Experiment Design Doc, Engineering Design Doc, Discovery Doc) from existing context plus targeted gap-filling questions. Each artifact passes through a reviewer-subagent + auto-apply loop (max 2 iters) governed by per-section eval criteria. Ships with 4 built-in templates and 4 writing-style presets (Concise, Tabular, Narrative, Executive); users can author their own at ~/.pmos/artifacts/. Use when the user says "draft a PRD", "create an experiment design", "write a design doc", "generate a discovery doc", "/artifact", or names an artifact type to produce.
user-invocable: true
argument-hint: "[ | <type> [--tier lite|full] [--preset <slug>] | create <type> [...] | refine <path> | update <path> | template add|list|remove [<slug>] | preset add|list|remove [<slug>]]"
---

# /artifact

<!-- TODO Tasks 8–15 fill in body -->
```

- [ ] **Step 4: Verify scaffold**

```bash
ls plugins/pmos-toolkit/skills/artifact/
# Expect: SKILL.md  presets/  templates/
```

- [ ] **Step 5: Commit**

```bash
git add plugins/pmos-toolkit/skills/artifact plugins/pmos-toolkit/.claude-plugin/plugin.json
git commit -m "feat(artifact): scaffold skill directory + version bump (v2.10.0)"
```

---

## Task 2: Built-in PRD template

**Files:**
- Create: `plugins/pmos-toolkit/skills/artifact/templates/prd/template.md`
- Create: `plugins/pmos-toolkit/skills/artifact/templates/prd/eval.md`

**Source of truth:** spec §4.1 (PRD section structure, tier mapping, per-section eval criteria, User Stories §8 authoring rules).

- [ ] **Step 1: Write `template.md` frontmatter**

```yaml
---
name: PRD
slug: prd
description: Product Requirements Document — problem, customers, metrics, scope, risks
tiers: [lite, full]
default_preset: narrative
files_to_read:
  - label: requirements doc
    pattern: "{feature_folder}/01_requirements*.md"
  - label: spec doc
    pattern: "{feature_folder}/02_spec*.md"
  - label: wireframes
    pattern: "{feature_folder}/wireframes/*"
  - label: workstream
    source: product-context
  - label: attached files
    source: user-args
---
```

- [ ] **Step 2: Write template body — Lite tier (7 sections)**

Sections per spec §4.1: TL;DR · Problem & Customer · Goals + Metrics · Solution Sketch · User Journey · Scope (MVP) · Risks. Each section gets:

```markdown
## §N. <Section Name>
<!-- tier: lite -->
<!-- purpose: <one-line purpose from spec> -->
<!-- guidance:
  - <eval criterion 1>
  - <eval criterion 2>
  ...
-->
{generation prompt: e.g., "Write a TL;DR that names the customer/segment, the change, and the expected outcome in ≤4 sentences."}
```

- [ ] **Step 3: Write template body — Full tier (14 sections)**

Sections per spec §4.1 (note: User Stories is §8). Mark each `<!-- tier: full -->` (or `<!-- tier: both -->` for sections shared with Lite). For §5 Success Metrics, embed the per-primary-metric structure (baseline + target + timebox + mechanism). For §8 User Stories & AC, embed the journey-grouping requirement, the ≤12 stories cap, and the AC-form-per-story rule from spec §4.1.

- [ ] **Step 3b: Add `tabular_schema` blocks to tabular-friendly sections**

For each PRD section that lists objects, append a `<!-- tabular_schema: ... -->` block alongside the existing `<!-- guidance: ... -->`. Schemas:

```markdown
<!-- §5 Success Metrics -->
<!-- tabular_schema:
  columns: [Metric, Layer (primary|input|guardrail|counter), Baseline, Target, Timebox, Mechanism, Owner, Instrumentation]
  row_per: metric
-->

<!-- §8 User Stories & AC -->
<!-- tabular_schema:
  columns: [Story, AC form (G/W/T or checklist), Walking-skeleton?, Mapped goal §4]
  row_per: story
  group_by: journey activity
-->

<!-- §9 Scope: MVP vs Later -->
<!-- tabular_schema:
  columns: [Item, Cut (MVP|Later|Out forever), Rationale]
  row_per: scope item
-->

<!-- §10 Risks & Open Questions -->
<!-- tabular_schema:
  columns: [Risk, Cagan dim (V|U|F|V), Likelihood, Impact, Mitigation/Test]
  row_per: risk
-->

<!-- §11 Rollout & Experiment Plan (Full only) -->
<!-- tabular_schema:
  columns: [Phase, % traffic, Triggers, Kill criteria, Rollback step]
  row_per: phase
-->

<!-- §12 Dependencies & Stakeholders (Full only) -->
<!-- tabular_schema:
  columns: [Item, Type (dep|stakeholder), Owner team, By-when]
  row_per: dep/stakeholder
-->

<!-- §13 FAQ (Full only) -->
<!-- tabular_schema:
  columns: [Question, Answer, Hostile?]
  row_per: Q&A
-->
```

Sections WITHOUT a tabular_schema (TL;DR, Problem, Why Now, Goals/Non-Goals, Solution Overview, User Journey, Appendix) render as prose under the Tabular preset.

- [ ] **Step 4: Write `eval.md` for PRD**

Format (per spec §3.3):

```markdown
## §1 TL;DR

- id: customer-named
  kind: judgment
  tier: [lite, full]
  check: customer or segment is named (not generic "users")
  severity: high

- id: outcome-stated
  kind: judgment
  tier: [lite, full]
  check: states the expected outcome (movement, not feature-ship)
  severity: high

- id: length-cap
  kind: judgment
  tier: [lite, full]
  check: ≤4 sentences
  severity: low

## §2 Problem & Customer

- id: evidence-cited
  kind: precondition
  tier: [lite, full]
  check: ≥1 evidence (quote, ticket reference, data point, research session ref)
  gap_question: |
    No customer evidence found in attached files. Paste a quote / ticket reference / data point, or describe the source.
  severity: high

- id: workaround-described
  kind: judgment
  tier: [lite, full]
  check: current customer workaround / coping behavior described
  severity: medium

# ... continue for §3 through §14 ...
```

Translate every eval row from the spec §4.1 table into one or more eval items. For criteria that require user-supplied evidence (e.g., evidence cited, baseline value, strategy doc reference), use `kind: precondition` with a `gap_question`. For criteria that judge the draft itself (e.g., "no solution language smuggled in," "≤4 sentences"), use `kind: judgment`. Set `severity` per spec §7 rubric (high = breaks section purpose; medium = section still functional; low = stylistic nit).

- [ ] **Step 5: Verify**

```bash
ls plugins/pmos-toolkit/skills/artifact/templates/prd/
# Expect: template.md  eval.md
grep -c "^## §" plugins/pmos-toolkit/skills/artifact/templates/prd/template.md
# Expect: 14 (Full sections; Lite-only sections are subsumed visually since both tiers share §-numbering)
grep -c "^- id:" plugins/pmos-toolkit/skills/artifact/templates/prd/eval.md
# Expect: ≥30 (sum of eval items across 14 sections)
```

- [ ] **Step 6: Commit**

```bash
git add plugins/pmos-toolkit/skills/artifact/templates/prd
git commit -m "feat(artifact): built-in PRD template (lite 7 / full 14)"
```

---

## Task 3: Built-in Experiment Design template

**Files:**
- Create: `plugins/pmos-toolkit/skills/artifact/templates/experiment-design/template.md`
- Create: `plugins/pmos-toolkit/skills/artifact/templates/experiment-design/eval.md`

**Source of truth:** spec §4.2 (Lite 7 / Full 13 sections; eval table).

- [ ] **Step 1: Write `template.md` frontmatter**

```yaml
---
name: Experiment Design Doc
slug: experiment-design
description: Pre-registered experiment design — hypothesis, variants, metrics, decision criteria
tiers: [lite, full]
default_preset: tabular
files_to_read:
  - label: requirements doc
    pattern: "{feature_folder}/01_requirements*.md"
  - label: PRD if exists
    pattern: "{feature_folder}/prd*.md"
  - label: prior experiments
    pattern: "{feature_folder}/experiment-*.md"
  - label: workstream
    source: product-context
  - label: attached files
    source: user-args
---
```

- [ ] **Step 2: Write Lite body (7 sections)**

Sections: Summary · Hypothesis · Variants · Population · Metrics (primary + guardrail) · Sample Size + Duration · Decision Criteria. Embed per-section guidance comments per spec §4.2 eval table.

- [ ] **Step 3: Write Full body (13 sections)**

Sections per spec §4.2. The §9 Decision Criteria section is load-bearing; embed an explicit pre-registration date stamp requirement and the multi-metric correction plan note.

- [ ] **Step 3b: Add `tabular_schema` blocks**

```markdown
<!-- §4 Variants -->
<!-- tabular_schema:
  columns: [Variant, Description, Code path / screenshot, Allocation %]
  row_per: variant
-->

<!-- §6 Metrics -->
<!-- tabular_schema:
  columns: [Metric, Layer (OEC|secondary|guardrail|counter), Numerator, Denominator, Baseline, Variance, Threshold, Instrumentation]
  row_per: metric
-->

<!-- §9 Decision Criteria -->
<!-- tabular_schema:
  columns: [Outcome (ship|hold|kill|draw), Primary-metric threshold, Guardrail thresholds, Multi-metric correction]
  row_per: outcome
-->

<!-- §10 Risks & Trustworthiness (Full) -->
<!-- tabular_schema:
  columns: [Risk type (carryover|novelty|network|instr|A/A), Status, Mitigation]
  row_per: risk
-->

<!-- §12 Stakeholders & Timeline -->
<!-- tabular_schema:
  columns: [Role (owner|reviewer|eng|analyst), Person, Readout date]
  row_per: role
-->
```

Tabular preset is the default for experiment-design; most sections WILL render as tables.

- [ ] **Step 4: Write `eval.md`**

Translate each row of the spec §4.2 eval table into eval items with `kind`/`tier`/`check`/`severity`. The "primary metric: baseline + variance" item is `kind: precondition` with `gap_question: "What's the metric's baseline value and weekly variance?"`. The "decision criteria pre-registered" item is `kind: judgment, severity: high`.

- [ ] **Step 5: Verify**

```bash
grep -c "^## §" plugins/pmos-toolkit/skills/artifact/templates/experiment-design/template.md
# Expect: 13 (Full)
grep -c "^- id:" plugins/pmos-toolkit/skills/artifact/templates/experiment-design/eval.md
# Expect: ≥25
```

- [ ] **Step 6: Commit**

```bash
git add plugins/pmos-toolkit/skills/artifact/templates/experiment-design
git commit -m "feat(artifact): built-in experiment-design template (lite 7 / full 13)"
```

---

## Task 4: Built-in Engineering Design Doc template

**Files:**
- Create: `plugins/pmos-toolkit/skills/artifact/templates/eng-design/template.md`
- Create: `plugins/pmos-toolkit/skills/artifact/templates/eng-design/eval.md`

**Source of truth:** spec §4.3 (Lite 8 / Full 14 sections; eval table).

- [ ] **Step 1: Write frontmatter**

```yaml
---
name: Engineering Design Doc
slug: eng-design
description: RFC/design doc — proposal, alternatives, cross-cutting concerns, operational readiness
tiers: [lite, full]
default_preset: tabular
files_to_read:
  - label: requirements doc
    pattern: "{feature_folder}/01_requirements*.md"
  - label: spec doc
    pattern: "{feature_folder}/02_spec*.md"
  - label: prior RFCs
    pattern: "{feature_folder}/eng-design*.md"
  - label: workstream
    source: product-context
  - label: attached files
    source: user-args
---
```

- [ ] **Step 2: Write Lite body (8 sections)**

Header · TL;DR · Context · Goals/Non-Goals · Proposal · Alternatives · Risks · Rollout. Per spec §4.3.

- [ ] **Step 3: Write Full body (14 sections)**

Per spec §4.3. The §7 Alternatives section is load-bearing; embed the "≥2 alts including the boring option" rule and the WHY-REJECTED requirement.

- [ ] **Step 3b: Add `tabular_schema` blocks**

```markdown
<!-- §4 Goals & Non-Goals -->
<!-- tabular_schema:
  columns: [Item, Type (goal|non-goal), Outcome, Rationale]
  row_per: item
-->

<!-- §7 Alternatives Considered -->
<!-- tabular_schema:
  columns: [Option, Tradeoffs, Why rejected, Boring-option?]
  row_per: alternative
-->

<!-- §8 Cross-Cutting Concerns (Full) -->
<!-- tabular_schema:
  columns: [Concern (security|privacy|compliance|observability|perf|cost), Status, Detail / Reason for N/A]
  row_per: concern
-->

<!-- §9 Migration / Rollout -->
<!-- tabular_schema:
  columns: [Phase, Action, Trigger, Rollback step, Owner]
  row_per: phase
-->

<!-- §11 Operational Readiness (Full) -->
<!-- tabular_schema:
  columns: [Capability (on-call|dashboard|alert|runbook|SLO), Status, Owner, Detail]
  row_per: capability
-->

<!-- §12 Risks & Open Questions -->
<!-- tabular_schema:
  columns: [Item, Type (risk|question), Likelihood/Severity, Impact, Mitigation / Owner+by-when]
  row_per: item
-->

<!-- §13 Timeline & Milestones (Full) -->
<!-- tabular_schema:
  columns: [Phase, Size, Exit criteria, Cross-team deps, Confidence]
  row_per: phase
-->
```

- [ ] **Step 4: Write `eval.md`**

Translate the spec §4.3 eval table. Notable preconditions: existing-system-named (gap-Q: "Which existing system / file path / service does this build on?"), SLOs (gap-Q: "What are the SLO targets — availability, latency p50/p99?"), on-call ownership (gap-Q: "Which team owns on-call for this service?"). Notable judgments: alternatives-include-boring-option, rollback-plan-named.

- [ ] **Step 5: Verify**

```bash
grep -c "^## §" plugins/pmos-toolkit/skills/artifact/templates/eng-design/template.md
# Expect: 14
grep -c "^- id:" plugins/pmos-toolkit/skills/artifact/templates/eng-design/eval.md
# Expect: ≥30
```

- [ ] **Step 6: Commit**

```bash
git add plugins/pmos-toolkit/skills/artifact/templates/eng-design
git commit -m "feat(artifact): built-in eng-design template (lite 8 / full 14)"
```

---

## Task 5: Built-in Discovery Doc template

**Files:**
- Create: `plugins/pmos-toolkit/skills/artifact/templates/discovery/template.md`
- Create: `plugins/pmos-toolkit/skills/artifact/templates/discovery/eval.md`

**Source of truth:** spec §4.4 (single tier, 7 sections, decision-first).

- [ ] **Step 1: Write frontmatter**

```yaml
---
name: Discovery Doc
slug: discovery
description: Decision-first discovery — what we're deciding, evidence gap, assumption tests
tiers: [single]
default_preset: narrative
files_to_read:
  - label: workstream
    source: product-context
  - label: prior research
    pattern: "{feature_folder}/research/*"
  - label: support tickets / data
    pattern: "{feature_folder}/data/*"
  - label: attached files
    source: user-args
---
```

- [ ] **Step 2: Write template body (7 sections)**

Decision · Opportunity / Job Story · Research Questions · Assumptions Map · Assumption Tests · Research Cadence & Methods · Decision Update & Next Steps. Per spec §4.4. For §5 Assumption Tests, embed both the pre-test field set (Hypothesis · Method · Metric · Success criterion · Owner · By-when) and post-test field set (Observation · Insight · Next decision) as a single section structure.

- [ ] **Step 2b: Add `tabular_schema` blocks**

```markdown
<!-- §1 Decision -->
<!-- tabular_schema:
  columns: [Field (Decision|Evidence needed|Evidence held|Gap|Owner|By-when), Value]
  row_per: field
-->

<!-- §3 Research Questions -->
<!-- tabular_schema:
  columns: [Question, Tied to gap (yes/which gap), Type (behavior|motivation|context)]
  row_per: question
-->

<!-- §4 Assumptions Map -->
<!-- tabular_schema:
  columns: [Assumption, Cagan dim (V|U|F|V), Importance, Evidence, Top-3?]
  row_per: assumption
-->

<!-- §5 Assumption Tests -->
<!-- tabular_schema:
  columns: [Assumption, Method, Metric, Success criterion, Owner, By-when, Observation, Insight, Next decision]
  row_per: test
-->
```

- [ ] **Step 3: Write `eval.md`**

Translate the spec §4.4 eval table. Notable preconditions: §1 decision-concrete (gap-Q: "What concrete decision are you trying to make? e.g., ship/don't, build/buy, persona-A vs B"), §2 evidence-cited (gap-Q: "Paste a customer quote / ticket / data point that supports this opportunity"). Notable judgments: §1 decision-not-vague ("learn about users" fails), §3 questions-not-leading.

- [ ] **Step 4: Verify**

```bash
grep -c "^## §" plugins/pmos-toolkit/skills/artifact/templates/discovery/template.md
# Expect: 7
grep -c "^- id:" plugins/pmos-toolkit/skills/artifact/templates/discovery/eval.md
# Expect: ≥20
```

- [ ] **Step 5: Commit**

```bash
git add plugins/pmos-toolkit/skills/artifact/templates/discovery
git commit -m "feat(artifact): built-in discovery template (decision-first, 7 sections)"
```

---

## Task 6: Built-in writing-style presets

**Files:**
- Create: `plugins/pmos-toolkit/skills/artifact/presets/concise.md`
- Create: `plugins/pmos-toolkit/skills/artifact/presets/tabular.md`
- Create: `plugins/pmos-toolkit/skills/artifact/presets/narrative.md`
- Create: `plugins/pmos-toolkit/skills/artifact/presets/executive.md`

**Source of truth:** spec §5.

- [ ] **Step 1: Write `concise.md`**

```markdown
---
name: concise
description: Tight nested bullets; minimal prose; tables only when comparative data demands it
---

# Rendering rules

- Default to nested bullets with sub-bullets for detail.
- Prose only for sections that read poorly as bullets (Problem narrative, User Journey, TL;DR).
- Tables ONLY when comparing ≥3 dimensions across ≥3 items (e.g., alternatives matrix).
- Numbered lists for steps that must be in order (rollout phases, journey steps).
- No filler ("In order to", "It is important to note that"). Cut to the action.

# Voice

- Active voice. Present tense.
- Concrete nouns over abstractions ("Sarah" beats "the user").
- Sentences ≤25 words; aim for 12-18.
- One claim per bullet. Two claims = two bullets.
```

- [ ] **Step 2: Write `tabular.md`**

```markdown
---
name: tabular
description: Tables-by-default for any list-of-objects; short prose for narrative sections; honors per-section tabular_schema in templates
---

# Rendering rules

- **Honor `tabular_schema` from template.md.** When a section's guidance comment includes a `tabular_schema:` block, render the section as a table with EXACTLY those columns in that order. One row per the `row_per:` value. Never invent additional columns; never drop schema columns (use "—" for unknown values).
- For sections WITHOUT a `tabular_schema`, default behavior:
  - Lists of objects → table with inferred columns.
  - Narrative sections (Problem, User Journey, FAQ answers, TL;DR) → prose, no bullets.
  - Procedural lists (rollout phases, journey steps) → numbered bullets.
- Diagrams: text/ASCII preferred; Mermaid block when relationships matter.
- When a section has ≤2 items AND no schema, prose is fine — don't make a 2-row table.

# Voice

- Concise; same baseline as the Concise preset.
- Table cell content ≤8 words where possible.
- Use status emojis sparingly: ✅ ⚠️ ❌ — and only in dedicated status columns.
```

- [ ] **Step 3: Write `narrative.md`**

```markdown
---
name: narrative
description: Amazon PR/FAQ-style flowing prose; complete sentences; bullets only when truly enumerative
---

# Rendering rules

- Default to prose paragraphs. 3-6 sentences per paragraph.
- Bullets ONLY for genuinely parallel enumerable items (a list of metrics, a list of stakeholders).
- Tables only when prose obscures the comparison.
- Each section opens with a topic sentence stating the section's claim, then evidence, then implication.
- The TL;DR reads like a press release headline + subhead.

# Voice

- Active voice. Past or present tense as fits.
- Customer-first phrasing ("Sarah, a senior PM, struggles to..." not "Senior PMs struggle...").
- Specific over generic ("by 23%" beats "significantly").
- Sentences vary in length (8-30 words); rhythm matters.
- No corporate filler ("synergize", "leverage" used as verb).
```

- [ ] **Step 4: Write `executive.md`**

```markdown
---
name: executive
description: TL;DR-heavy, scannable; bolded key takeaways; dense exec summary; light body
---

# Rendering rules

- TL;DR is the longest single section — 5-8 sentences, every sentence a load-bearing claim.
- Each section opens with a **bolded key takeaway** in 1 sentence.
- Section body ≤150 words after the takeaway.
- Each section ends with a 1-line "What this means" callout in italics.
- Tables for comparative data; bullets for enumerable; prose used sparingly.
- Numbers get bolded inline (**$12M**, **23% lift**, **p99 < 200ms**).

# Voice

- Direct. No hedging ("might", "could potentially").
- Front-load the conclusion in every section.
- One claim per sentence. Long sentences = unread sentences.
- Cite source/owner for every number.
```

- [ ] **Step 5: Verify**

```bash
ls plugins/pmos-toolkit/skills/artifact/presets/
# Expect: concise.md  executive.md  narrative.md  tabular.md
for f in plugins/pmos-toolkit/skills/artifact/presets/*.md; do
  head -4 "$f" | grep -q "^name:" || echo "MISSING name: in $f"
done
# Expect: no output
```

- [ ] **Step 6: Commit**

```bash
git add plugins/pmos-toolkit/skills/artifact/presets
git commit -m "feat(artifact): built-in writing-style presets (concise, tabular, narrative, executive)"
```

---

## Task 7: Reviewer subagent prompt

**Files:**
- Create: `plugins/pmos-toolkit/skills/artifact/reviewer-prompt.md`

**Source of truth:** spec §3.3 (eval-item shape) and §7 (severity rubric, auto-apply rules).

- [ ] **Step 1: Write `reviewer-prompt.md`**

```markdown
# Artifact Reviewer Subagent Prompt

You are a reviewer subagent for the `/artifact` skill. You receive:

1. The full draft of an artifact (a markdown document).
2. The artifact's `eval.md` (per-section criteria with metadata).
3. This prompt.

Your job: judge the draft against ALL items in `eval.md` and return JSON findings only.

## Severity rubric (use exactly these three values)

- **high** — eval item failed in a way that breaks the section's purpose. Examples: Problem section with no evidence cited; Metrics section with no baseline; Alternatives section with only one alternative.
- **medium** — eval item failed but the section is still functional. Examples: one of three goals isn't outcome-shaped; missing one acceptance criterion on one story.
- **low** — stylistic / polish nit. Examples: TL;DR is 5 sentences instead of 4; preset adherence wobble.

## Output format (JSON only — no prose, no markdown around it)

```json
[
  {
    "section": "§2 Problem & Customer",
    "criterion_id": "evidence-cited",
    "severity": "high",
    "finding": "No customer quote, ticket reference, or data point present in §2. The eval item `evidence-cited` requires ≥1 evidence source.",
    "suggested_fix": "Add a 1-sentence evidence citation at the end of §2's first paragraph: e.g., '12 of 30 interviewed users described this exact frustration (research session 2026-04-15).'"
  }
]
```

## Rules

1. Run every eval item from `eval.md` against the draft. Do not skip items.
2. Never invent criteria not in `eval.md`.
3. Items with `kind: precondition` still apply — check that the precondition's evidence is visible IN the draft, not just gathered.
4. **Tabular schema adherence** — if the active preset is `tabular` AND a section's `tabular_schema` is present in the template, treat any column drift (missing schema column, extra column, wrong order) as a `medium`-severity finding with `criterion_id: tabular-schema-adherence`. Suggested fix: "Restructure the table to match the schema columns in order: [list from template.md]."
5. `suggested_fix` must be specific enough that an `Edit` tool call could apply it. Vague fixes ("rewrite this section better") are not acceptable.
6. If a section satisfies all its eval items, do not include it in the output.
7. Return `[]` (empty array) if the draft satisfies all items.
8. Output JSON ONLY. No surrounding text, no code fence labels, no commentary.
```

- [ ] **Step 2: Verify**

```bash
test -f plugins/pmos-toolkit/skills/artifact/reviewer-prompt.md && echo OK
# Expect: OK
```

- [ ] **Step 3: Commit**

```bash
git add plugins/pmos-toolkit/skills/artifact/reviewer-prompt.md
git commit -m "feat(artifact): reviewer subagent prompt for refinement loop"
```

---

## Task 8: SKILL.md — Phase 0 (load context) + Phase 1 (subcommand routing)

**Files:**
- Modify: `plugins/pmos-toolkit/skills/artifact/SKILL.md`

**Source of truth:** spec §6 Phase 0–1, §3.1 command surface.

- [ ] **Step 1: Replace TODO with body — Header + Phase 0**

Append below the frontmatter (replacing the `<!-- TODO -->` placeholder):

```markdown
# /artifact

Generate, refine, and update structured PM/eng artifacts (PRD, Experiment Design Doc, Engineering Design Doc, Discovery Doc) with section-level eval criteria, a reviewer-subagent refinement loop (max 2 iterations), and writing-style presets. Templates ship in this skill; user-defined templates and presets live at `~/.pmos/artifacts/` and survive plugin upgrades.

**Announce at start:** "Using /artifact to {create|refine|update} a {type}."

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:
- **No `AskUserQuestion`:** State your assumption inline, document it in the artifact's frontmatter as `assumed: <field>`, proceed. User reviews after.
- **No subagents:** Run the refinement reviewer inline as the same agent. Same eval.md; same output format.
- **Task tracking:** Use whatever task tool exists (TaskCreate / update_plan / verbal phase announcements).

## Phase 0 — Load Context

1. Follow `../product-context/context-loading.md` (relative to this skill dir) to resolve `{docs_path}` and load any active workstream context.
2. Read `~/.pmos/learnings.md` if it exists. Note entries under `## /artifact` and factor them into this session.
3. Ensure `~/.pmos/artifacts/` exists. If not, create the empty tree:
   ```
   ~/.pmos/artifacts/
     templates/
     presets/
   ```
4. Determine the subcommand and route to the appropriate phase. Default subcommand is `create`.
```

- [ ] **Step 2: Append Phase 1 routing table**

```markdown
## Phase 1 — Subcommand Routing

| Argument shape | Route to |
|---|---|
| `(empty)` | Phase 2.0 — type picker |
| `<type>` (one word matching a template slug) | Phase 2 — Create flow with `<type>` |
| `create <type> [flags]` | Phase 2 — Create flow |
| `refine <path>` | Refine flow |
| `update <path>` | Update flow |
| `template add` | Template Add flow |
| `template list` | Template List flow |
| `template remove <slug>` | Template Remove flow |
| `preset add` | Preset Add flow |
| `preset list` | Preset List flow |
| `preset remove <slug>` | Preset Remove flow |

If `<type>` doesn't match any template slug (built-in or user), list available templates and offer fuzzy match before erroring.

Recognized flags on `create`:
- `--tier lite|full` — bypass tier auto-detection
- `--preset <slug>` — bypass default preset selection
```

- [ ] **Step 3: Verify**

```bash
grep -c "^## Phase" plugins/pmos-toolkit/skills/artifact/SKILL.md
# Expect: ≥2
```

- [ ] **Step 4: Commit**

```bash
git add plugins/pmos-toolkit/skills/artifact/SKILL.md
git commit -m "feat(artifact): SKILL.md Phase 0 (context load) + Phase 1 (subcommand routing)"
```

---

## Task 9: SKILL.md — Phase 2 Create flow (steps 2.1 → 2.7)

**Files:**
- Modify: `plugins/pmos-toolkit/skills/artifact/SKILL.md`

**Source of truth:** spec §6 Phase 2 (the unified 7-step create flow).

- [ ] **Step 1: Append Phase 2 body**

```markdown
## Phase 2 — Create Flow

The same 7-step flow applies to every artifact type — built-in or user-defined.

### 2.0 — Type picker (only when invoked with no `<type>` argument)

Use `AskUserQuestion` to ask which type to create. Build options dynamically by listing all templates from:
- `templates/` in this skill dir (built-in)
- `~/.pmos/artifacts/templates/` (user)

Show source label `[built-in]` / `[user]` next to each. After selection, set `<type>` and proceed to 2.1.

### 2.1 — Resolve & validate template

1. Look up `<type>` in built-in templates first; if not found, in `~/.pmos/artifacts/templates/`. (Built-in always wins on slug — user templates use unique slugs by construction.)
2. Read `template.md` frontmatter and `eval.md`.
3. **Validate:**
   - Both files exist.
   - Frontmatter parses; required fields present: `name`, `slug`, `description`, `tiers`, `default_preset`, `files_to_read`.
   - Every section ID referenced in `eval.md` (e.g., `## §2`) exists in `template.md`.
   - If validation fails: stop, surface the specific error, do not proceed.

### 2.2 — Tier detection

If `template.md` frontmatter `tiers: [lite, full]`:
1. If `--tier <value>` flag was given, use it.
2. Otherwise auto-suggest based on signals:
   - Requirements doc richness: word count of `01_requirements*.md` if present (>1500 → suggest Full; <500 → suggest Lite).
   - User input length and tone (>200 chars with strategic terms like "OKR", "rollout", "stakeholders" → Full).
   - Default to Full when ambiguous.
3. Confirm with user via `AskUserQuestion` (preview shows the section list per tier).

If `tiers: [single]`, skip this step.

### 2.3 — Resolve feature folder

Follow `../_shared/feature-folder.md` with:
- `skill_name=artifact`
- `feature_arg=<value of --feature flag if any>`
- `feature_hint=<short feature name from user input or current type>`

Returned path becomes `{feature_folder}` for the rest of this run.

### 2.4 — Auto-consume upstream artifacts

For each entry in `template.md` frontmatter `files_to_read`:
- If `pattern:`, expand `{feature_folder}` and glob; read every match.
- If `source: product-context`, use the workstream content already loaded in Phase 0.
- If `source: user-args`, treat any file paths in the user's invocation as attached.

Concatenate all read content into a `gathered_context` block, tagged by source label.

### 2.5 — Gap interview

1. Filter `eval.md` items where `kind: precondition` AND the item's `tier:` includes the selected tier (or includes `single`).
2. For each precondition item, do a semantic check: does anything in `gathered_context` satisfy the item's `check`?
   - Use LLM judgment, not regex. Be generous — if the evidence is plausibly present, mark it satisfied.
3. For UNSATISFIED items only, queue the item's `gap_question`.
4. Batch queued questions ≤4 per `AskUserQuestion` call. Use multiple sequential calls if >4.
5. Append answers to `gathered_context` tagged `gap_answer:<criterion_id>`.

### 2.6 — Preset selection

1. If `--preset <slug>` flag, use it.
2. Otherwise read `template.md` frontmatter `default_preset`.
3. Confirm with the user via `AskUserQuestion` showing the 4 built-in presets + any user presets, with `default_preset` marked `(default)`.

Load the chosen preset's rendering rules and voice notes for use in 2.7.

### 2.7 — Generate draft

Generate the artifact section-by-section using:
- `template.md` section ordering and per-section guidance comments
- The selected preset's rendering rules (per section type)
- `gathered_context` (auto-read + gap answers)

Write the draft to `{feature_folder}/{slug}.md` (e.g., `prd.md`, `experiment-design.md`). Include a frontmatter block in the artifact:

```yaml
---
type: prd
tier: full
preset: narrative
generated_at: 2026-05-02
template_version: pmos-toolkit@2.10.0
sources:
  - 01_requirements_v3.md
  - workstream:product-x
---
```

Then proceed to Phase 3.
```

- [ ] **Step 2: Verify**

```bash
grep -E "^### 2\." plugins/pmos-toolkit/skills/artifact/SKILL.md | wc -l
# Expect: 8 (2.0 through 2.7)
```

- [ ] **Step 3: Commit**

```bash
git add plugins/pmos-toolkit/skills/artifact/SKILL.md
git commit -m "feat(artifact): Phase 2 create flow (template resolve, tier, gap, preset, generate)"
```

---

## Task 10: SKILL.md — Phase 3 Refinement Loop

**Files:**
- Modify: `plugins/pmos-toolkit/skills/artifact/SKILL.md`

**Source of truth:** spec §6 Phase 3, §7 (loop detail).

- [ ] **Step 1: Append Phase 3**

```markdown
## Phase 3 — Self-Refinement Loop (max 2 iterations)

Mirrors `/wireframes` Phase 4 pattern.

### Loop iteration

1. **Dispatch reviewer subagent.**
   - Subagent type: `general-purpose`.
   - Inputs: `reviewer-prompt.md` (system instructions), the full `eval.md` for this template, and the current draft.
   - Background: false (this is a foreground call; we need findings before proceeding).
   - Subagent returns JSON of the shape defined in `reviewer-prompt.md`.

2. **Parse findings.** Each finding has `section`, `criterion_id`, `severity`, `finding`, `suggested_fix`.

3. **Auto-apply** all `high` and `medium` findings via `Edit` against the draft file. Apply the `suggested_fix` literally — the reviewer prompt requires fixes specific enough to apply directly.
4. **Log** all `low` findings to a `_residuals` accumulator (in-memory).

### Loop continuation

- If any `high` findings remained AFTER applying loop-1 (i.e., the auto-fix didn't fully resolve them — should be rare; reviewer should regenerate the section), run loop 2.
- Hard cap: **2 loops total.** No third loop, ever.

### Residual presentation

After loop 2 (or loop 1 if no high remain):

- Surface any `high` still remaining + all `medium` from loop 2 + any `low` deemed worth raising via the **Findings Presentation Protocol**:
  - Batch ≤4 findings per `AskUserQuestion` call.
  - Per finding, options: **Apply as proposed** / **Modify** / **Skip** / **Defer**.
  - Apply user-confirmed fixes via `Edit`. "Defer" appends the finding to a `## Deferred Improvements` section at the end of the artifact.

### Anti-patterns (do NOT)

- Run a 3rd loop "just in case." Diminishing returns are real; surface to user instead.
- Silently fix `low` findings without user input — log them, surface only on request or at handoff.
- Invoke the reviewer with a different prompt than `reviewer-prompt.md`. The prompt enforces the JSON contract.
```

- [ ] **Step 2: Verify**

```bash
grep -A1 "^## Phase 3" plugins/pmos-toolkit/skills/artifact/SKILL.md | head -5
```

- [ ] **Step 3: Commit**

```bash
git add plugins/pmos-toolkit/skills/artifact/SKILL.md
git commit -m "feat(artifact): Phase 3 refinement loop (reviewer subagent, auto-apply, max 2)"
```

---

## Task 11: SKILL.md — Phases 4–6 (save, workstream enrichment, learnings)

**Files:**
- Modify: `plugins/pmos-toolkit/skills/artifact/SKILL.md`

**Source of truth:** spec §6 Phases 4–6.

- [ ] **Step 1: Append Phases 4–6**

```markdown
## Phase 4 — Save & Confirm

1. The artifact file at `{feature_folder}/{slug}.md` already exists from Phase 2.7 and was edited in Phase 3.
2. Show the user a one-paragraph summary:
   - Artifact type + tier
   - Preset used
   - Sections written
   - Refinement-loop iterations (1 or 2) and counts: `N high resolved, M medium resolved, K low logged`
   - Residuals deferred (count + names)
3. Offer to `git add` + commit. Do NOT auto-commit. Suggested commit message:
   ```
   docs({type}): add {tier} {type} for {feature-slug}
   ```

## Phase 5 — Workstream Enrichment

If a workstream was loaded in Phase 0:

1. Scan the gathered context + the final draft for signals worth persisting to the workstream:
   - New user segments named
   - Metrics with baselines / targets
   - Strategic decisions / OKR links
   - Stakeholders / teams not previously listed
2. Surface each candidate addition via `AskUserQuestion` (Apply / Modify / Skip), batched ≤4 per call.
3. Apply approved additions to `~/.pmos/workstreams/{workstream}.md`.

If no workstream is active, skip this phase.

## Phase 6 — Capture Learnings

Read `../learnings/learnings-capture.md` (relative to this skill dir) and follow it. This phase is a **terminal gate** — the skill is not complete until learnings have been processed.
```

- [ ] **Step 2: Verify**

```bash
grep -c "^## Phase" plugins/pmos-toolkit/skills/artifact/SKILL.md
# Expect: 7 (Phase 0 through Phase 6)
```

- [ ] **Step 3: Commit**

```bash
git add plugins/pmos-toolkit/skills/artifact/SKILL.md
git commit -m "feat(artifact): Phases 4-6 (save, workstream enrich, learnings capture)"
```

---

## Task 12: SKILL.md — Refine flow

**Files:**
- Modify: `plugins/pmos-toolkit/skills/artifact/SKILL.md`

**Source of truth:** spec §6 "Refine Flow".

- [ ] **Step 1: Append Refine flow body**

```markdown
## Refine Flow (`/artifact refine <path>`)

Re-run the eval-loop judge on an existing artifact. **Internal QA only — does NOT accept new external feedback.**

1. Read the artifact at `<path>`. Parse its frontmatter to determine `type`. If frontmatter is missing or `type` cannot be inferred, ask the user via `AskUserQuestion`.
2. Resolve the template (same 2.1 logic) and load `eval.md`.
3. Ask the user: "Overwrite `<path>` or write to `<path>.refined.md`?" via `AskUserQuestion`. Default = `.refined.md` (safer).
4. Run Phase 3 refinement loop against the artifact (or its `.refined.md` copy).
5. Run Phase 4 save & confirm — point at the chosen output path.
6. Skip Phase 5 (no new workstream signals from a re-run).
7. Run Phase 6 learnings capture (terminal gate).
```

- [ ] **Step 2: Commit**

```bash
git add plugins/pmos-toolkit/skills/artifact/SKILL.md
git commit -m "feat(artifact): refine flow (re-run eval loop on existing artifact)"
```

---

## Task 13: SKILL.md — Update flow

**Files:**
- Modify: `plugins/pmos-toolkit/skills/artifact/SKILL.md`

**Source of truth:** spec §6 "Update Flow".

- [ ] **Step 1: Append Update flow**

```markdown
## Update Flow (`/artifact update <path>`)

Apply stakeholder feedback to an existing artifact. **Distinct from refine — this is a stakeholder loop, not internal QA.**

### Phase U.1 — Accept feedback input

Ask the user via `AskUserQuestion`:
- **Paste comments** — user pastes block of feedback inline.
- **File path** — user provides path to a feedback file (Notion export, email dump, .md notes).
- **Dictate** — user describes feedback conversationally; agent transcribes.

### Phase U.2 — Parse into structured items

Extract each feedback item into the shape:

```json
{
  "section": "§2 Problem & Customer",
  "type": "edit | expand | trim | question | accept | reject",
  "content": "verbatim feedback or summary"
}
```

For ambiguous items (no clear section, or unclear intent), batch clarifying questions via `AskUserQuestion` (≤4 per call).

For un-mappable items (don't fit any section), append them to a `## General Feedback` section in the artifact and continue.

### Phase U.3 — Apply via Findings Presentation Protocol

Per parsed item, batch ≤4 per `AskUserQuestion`. Options: **Apply as proposed** / **Modify** / **Skip** / **Defer**. Apply approvals via `Edit`. "Defer" appends to `## Deferred Improvements`.

### Phase U.4 — Append Comment Resolution Log

At the bottom of the artifact, append (or extend) a `## Comment Resolution Log` section with one row per resolved item:

```markdown
| Date | Reviewer | Section | Feedback | Resolution |
|---|---|---|---|---|
| 2026-05-02 | (paste) | §2 | Add competitor benchmark | Applied |
| 2026-05-02 | sarah@ | §5 | Tighten guardrails | Modified |
```

### Phase U.5 — Optional re-run of refinement loop

Ask: "Run the eval loop on the updated artifact?" via `AskUserQuestion`. If yes, run Phase 3.

### Phase U.6 — Save, then Phase 6 learnings capture (terminal gate)

Same as Phase 4 + Phase 6 from the create flow.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/pmos-toolkit/skills/artifact/SKILL.md
git commit -m "feat(artifact): update flow (stakeholder feedback w/ Comment Resolution Log)"
```

---

## Task 14: SKILL.md — Template management flows (add / list / remove)

**Files:**
- Modify: `plugins/pmos-toolkit/skills/artifact/SKILL.md`

**Source of truth:** spec §6 "Template Management Flow" (research-grounded `template add`, plus list and remove).

- [ ] **Step 1: Append Template Management section**

```markdown
## Template Management

### `/artifact template add` — research-grounded authoring

`--quick` flag drops to scaffold-only mode (skip phases T.2 and T.3, jump to T.4 with empty proposed sections).

#### T.1 — Intake

Ask via `AskUserQuestion` (one batch ≤4):
- Template **name** + **slug** (slug must not collide with built-in templates: `prd`, `experiment-design`, `eng-design`, `discovery`. Validate at capture time and reject collisions before continuing.)
- **Purpose / when used** (1-2 sentences)
- **Audience**
- **Examples** — links or pasted reference docs (optional)
- **Inspirations / frameworks** to ground in (optional)

#### T.2 — Research subagent (skip if `--quick` or user opts out via AskUserQuestion)

Dispatch a `general-purpose` subagent. Foreground call. Prompt:

```
Research best practices for the artifact class "<name>" (purpose: <purpose>; inspirations: <list>).

Survey canonical sources via WebSearch and WebFetch. Cite each source.

Return a proposal:
- Sections (8-15) with one-line purpose each
- Per-section eval items with kind (precondition|judgment), check, severity (high|medium|low), and gap_question for preconditions
- Frontmatter files_to_read suggestions
- A recommended default_preset (concise|tabular|narrative|executive)
- Cited source links

Do NOT write any files. Output a single markdown report ~600-900 words.
```

#### T.3 — Section-by-section alignment

For each proposed section in the research report, ask via `AskUserQuestion` with options:
- **Approve** (preview shows section purpose + eval items)
- **Tweak** (free-text follow-up)
- **Discuss** (free-text follow-up)
- **Drop**

Capture decisions per section. Track which eval items survived.

#### T.4 — Frontmatter authoring

Confirm via `AskUserQuestion` (one batch):
- `tiers`: `[single]` / `[lite, full]`
- `default_preset`: pick from 4 built-in (or "user-defined" if applicable)
- `files_to_read`: confirm list

#### T.5 — Generate the 2 files

Write to `~/.pmos/artifacts/templates/<slug>/`:
- `template.md` — frontmatter + section markdown with embedded guidance per the alignment decisions.
- `eval.md` — per-criterion items per the alignment decisions.

Validate on write:
- Both files present.
- Frontmatter parses; required fields present.
- Every `## §N` in template.md has a matching `## §N` in eval.md.
- If validation fails, surface the specific error and offer to retry or abort.

#### T.6 — Optional dry-run

Ask: "Run a dry-run by creating one artifact with this template?" via `AskUserQuestion`. If yes, prompt for a feature folder (or use the most recent), then execute Phase 2 with the new template. User can iterate on sections/evals based on what the dry-run produces.

### `/artifact template list`

Read both built-in (`templates/`) and user (`~/.pmos/artifacts/templates/`) directories. Render a table:

```
| Slug              | Name                      | Tiers       | Source     |
|-------------------|---------------------------|-------------|------------|
| prd               | PRD                       | lite, full  | built-in   |
| experiment-design | Experiment Design Doc     | lite, full  | built-in   |
| eng-design        | Engineering Design Doc    | lite, full  | built-in   |
| discovery         | Discovery Doc             | single      | built-in   |
| okr-doc           | OKR Document              | single      | user       |
```

Read-only.

### `/artifact template remove <slug>`

1. If `<slug>` is a built-in: refuse with message "Built-in templates cannot be removed."
2. If `<slug>` is a user template: confirm via `AskUserQuestion` (Yes/No), then `rm -rf ~/.pmos/artifacts/templates/<slug>/`. Show the path that was removed.
3. If `<slug>` doesn't exist: list available user templates.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/pmos-toolkit/skills/artifact/SKILL.md
git commit -m "feat(artifact): template management (research-grounded add, list, remove)"
```

---

## Task 15: SKILL.md — Preset management flows

**Files:**
- Modify: `plugins/pmos-toolkit/skills/artifact/SKILL.md`

**Source of truth:** spec §5 + §6 "Preset Add/List/Remove".

- [ ] **Step 1: Append Preset Management section**

```markdown
## Preset Management

### `/artifact preset add`

#### P.1 — Intake (one AskUserQuestion batch)

- **Slug** (validate against built-in: `concise`, `tabular`, `narrative`, `executive` — reject collisions)
- **Description** (1-line)
- **Inspiration** (existing preset to fork? other doc style?)

#### P.2 — Rendering rules per section type

Walk through 4 section types, asking the user for the rule per type via `AskUserQuestion` (4 questions batched in 2 calls of 2):

1. **Lists of objects** (metrics, variants, scope items, stories) — table / nested bullets / prose?
2. **Narrative sections** (Problem, User Journey, FAQ) — prose / bulleted / mixed?
3. **Procedural lists** (rollout phases, journey steps) — numbered / unnumbered / table?
4. **Diagrams** — text/ASCII / Mermaid / both / none?

#### P.3 — Voice and tone

Ask: 3-5 voice rules (active vs passive, sentence length cap, hedging, etc.). Free-text or AskUserQuestion preset list.

#### P.4 — Generate file

Write to `~/.pmos/artifacts/presets/<slug>.md`:

```markdown
---
name: <slug>
description: <line>
---

# Rendering rules

<rules from P.2>

# Voice

<rules from P.3>
```

### `/artifact preset list`

Render built-in + user presets in a table with `Slug | Description | Source`.

### `/artifact preset remove <slug>`

Symmetric to `template remove`. Reject if built-in.
```

- [ ] **Step 2: Commit**

```bash
git add plugins/pmos-toolkit/skills/artifact/SKILL.md
git commit -m "feat(artifact): preset management (add, list, remove)"
```

---

## Task 16: End-to-end smoke test + README + CHANGELOG

**Files:**
- Modify: `README.md` (repo root) — add `/artifact` to the skills list
- Create: `docs/superpowers/specs/2026-05-02-artifact-skill-smoke-test.md` — smoke test transcript

- [ ] **Step 1: Update repo `README.md`**

Find the section listing pmos-toolkit skills and add a row for `/artifact`. Keep alphabetical or insertion order consistent with neighbors.

```markdown
- **`/artifact`** — Generate, refine, and update PRDs, Experiment Design Docs, Engineering Design Docs, and Discovery Docs with section-level eval criteria + writing-style presets. Custom templates at `~/.pmos/artifacts/`.
```

- [ ] **Step 2: Smoke test — create a synthetic feature folder**

```bash
mkdir -p /tmp/artifact-smoke/features/2026-05-02_demo-flag
cat > /tmp/artifact-smoke/features/2026-05-02_demo-flag/01_requirements.md <<'EOF'
# Requirements — Demo Flag

## Problem
Sarah, a senior PM at a B2B SaaS company, can't easily share early prototypes
with her CEO because the production app gates everything behind auth. She
currently sends Loom videos, which take 15 min to produce per iteration.
12/30 PMs we interviewed described this exact frustration (research session
2026-04-15).

## Goals
- Cut prototype-share time from 15 min to <2 min for internal stakeholders.
- Maintain SOC2 audit trail.

## Out
- External (non-employee) prototype sharing — separate project.
EOF
```

- [ ] **Step 3: Smoke test — invoke `/artifact create prd` against synthetic context**

In a fresh Claude Code session, with cwd set to `/tmp/artifact-smoke`:

```
/artifact create prd --tier lite --preset narrative
```

Expected:
- Skill loads built-in `prd` template.
- Phase 2.4 reads `01_requirements.md`.
- Phase 2.5 satisfies most preconditions from the requirements doc, asks ≤2 gap questions (likely metric baseline + strategy link).
- Phase 2.7 writes `prd.md` with 7 Lite sections.
- Phase 3 reviewer subagent returns ≤5 high+medium findings; auto-applies them.
- Phase 4 prints summary; offers commit.

- [ ] **Step 4: Verify outputs**

```bash
test -f /tmp/artifact-smoke/features/2026-05-02_demo-flag/prd.md && echo OK
grep -c "^## §" /tmp/artifact-smoke/features/2026-05-02_demo-flag/prd.md
# Expect: 7 (Lite sections)
head -10 /tmp/artifact-smoke/features/2026-05-02_demo-flag/prd.md
# Expect: frontmatter with type, tier, preset, generated_at
```

- [ ] **Step 5: Document smoke-test transcript**

Create `docs/superpowers/specs/2026-05-02-artifact-skill-smoke-test.md`:

```markdown
# /artifact Skill — v2.10.0 Smoke Test

**Date:** 2026-05-02
**Scenario:** create prd lite narrative on synthetic feature folder

## Inputs
- Requirements doc with problem, goals, out-of-scope (see Task 16 Step 2 of the plan)

## Outputs
- prd.md generated, 7 sections, narrative preset
- Refinement loop: <N> findings, <M> auto-applied, <K> deferred
- Time-to-draft: <T> seconds

## Issues found
- (fill in during smoke test)

## Decisions captured for next iteration
- (fill in)
```

- [ ] **Step 6: Final commit**

```bash
git add README.md docs/superpowers/specs/2026-05-02-artifact-skill-smoke-test.md
git commit -m "docs(artifact): README entry + smoke test transcript (v2.10.0)"
```

---

## Self-Review

After Task 16 commits, do a final consistency pass:

- [ ] **Spec coverage check.** Open spec §3 (Architecture), §4 (Templates), §6 (Pipeline), §10 (Testing). Map each spec subsection to a task in this plan:
  - §3.1 Command Surface → Task 8 (routing) + 14 (template mgmt) + 15 (preset mgmt)
  - §3.2 Storage Layout → Task 1 (built-in dirs) + Task 8 Phase 0 (user dir creation)
  - §3.3 Template Anatomy → Tasks 2-5 (per-template) + 14 (validation rules)
  - §3.4 Preset Anatomy → Task 6
  - §4.1-4.4 Templates → Tasks 2-5
  - §5 Presets → Task 6
  - §6 Phases 0-6 → Tasks 8-11
  - §6 Refine flow → Task 12
  - §6 Update flow → Task 13
  - §6 Template/Preset mgmt → Tasks 14-15
  - §7 Self-refinement loop detail → Task 7 (reviewer prompt) + Task 10 (loop logic)
  - §8 Risks → not implemented as code; tracked in spec
  - §9 Dependencies → all listed are existing files referenced via relative paths
  - §10 Testing → Task 16
  - §11 Implementation Outline → all 11 items mapped to tasks above

- [ ] **Placeholder scan.** Search the plan for `TBD`, `TODO`, `fill in details`, `appropriate error handling`. No matches expected (the only `<!-- TODO -->` is the placeholder inside Task 1's SKILL.md scaffold, which Task 8 replaces).

- [ ] **Type / name consistency.**
  - Slug names: `prd`, `experiment-design`, `eng-design`, `discovery` — used identically across Tasks 1-5, 8, 9, 14, 16.
  - Preset slugs: `concise`, `tabular`, `narrative`, `executive` — Tasks 6, 9, 15.
  - Frontmatter fields: `name`, `slug`, `description`, `tiers`, `default_preset`, `files_to_read` — consistent across template tasks.
  - Eval-item fields: `id`, `kind`, `tier`, `check`, `gap_question` (precondition only), `severity` — consistent.
  - Phase numbering: 0, 1, 2 (with sub-steps 2.0–2.7), 3, 4, 5, 6 — consistent.

- [ ] **Cross-reference integrity.** Every `../<skill>/<file>.md` reference in the SKILL.md tasks resolves:
  - `../product-context/context-loading.md` ✓ (exists)
  - `../_shared/feature-folder.md` ✓ (exists)
  - `../learnings/learnings-capture.md` ✓ (exists)
  - `reviewer-prompt.md` ✓ (created Task 7)

If any check fails, fix inline and continue.
