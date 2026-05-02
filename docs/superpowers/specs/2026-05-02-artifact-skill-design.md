# /artifact Skill — Design Spec

**Status:** Draft
**Date:** 2026-05-02
**Author:** Maneesh Dhabria + Claude (brainstormed)
**Target plugin:** `pmos-toolkit`

---

## 1. Summary

`/artifact` is a single skill that generates, refines, and updates structured PM/eng artifacts (PRD, Experiment Design Doc, Engineering Design Doc, Discovery Doc) from existing context (requirements docs, workstream, attached files) plus targeted gap-filling questions. Each artifact is produced through a draft → reviewer-subagent → auto-apply loop (max 2 iterations) governed by per-section eval criteria. Users get four built-in writing-style presets (Concise, Tabular, Narrative, Executive) and can author their own templates and presets that survive plugin upgrades.

The skill follows established `pmos-toolkit` conventions: Phase 0 workstream context loading via `product-context/context-loading.md`, feature-folder resolution via `_shared/feature-folder.md`, Findings Presentation Protocol for residual issues, learnings capture as a terminal phase.

## 2. Goals & Non-Goals

**Goals**

- Generate high-quality first drafts of 4 canonical artifact types from minimal user input
- Enforce section-level quality through pre-registered eval criteria and a reviewer-subagent loop
- Let users add custom templates and writing presets without those being clobbered by plugin updates
- Integrate into the requirements → spec → plan pipeline (auto-consume upstream artifacts in the same feature folder)
- Support stakeholder feedback loops as a distinct flow (`/artifact update`) separate from internal QA refinement

**Non-Goals**

- Replacing pipeline skills (`/requirements`, `/spec`, `/plan`). The pipeline stays self-contained; each pipeline skill owns its template, rigor, and tiers. `/artifact` is for **standalone documents** outside the pipeline (PRDs sent to stakeholders, RFCs for cross-team review, discovery docs done before requirements). It auto-CONSUMES pipeline outputs (reads `01_requirements.md`, `02_spec.md`, `03_plan.md` if present) but does not replace them. No `/plan`-equivalent template ships in v1 — a plan is internal execution scaffolding, not a stakeholder artifact.
- Real-time collaboration / multi-author merge. Artifacts are markdown files; collaboration uses the host system (git, Notion, Google Docs export).
- Auto-publishing to Notion/Confluence/Drive in v1. Out of scope; the user can export manually.
- Version-controlling artifacts inside the skill. Git in the host repo handles that.

### 2.1 Positioning vs Pipeline Skills

| Need | Use |
|---|---|
| Internal team-alignment requirements doc | `/requirements` (pipeline) |
| Internal implementation-bound spec | `/spec` (pipeline) |
| Internal task-level execution plan | `/plan` (pipeline) |
| PRD shaped for stakeholder/exec review | `/artifact create prd` |
| RFC for cross-team review | `/artifact create eng-design` |
| Pre-requirements discovery doc | `/artifact create discovery` |
| Experiment design doc | `/artifact create experiment-design` |

A user can run both pipelines on the same feature folder. `/artifact` reads pipeline outputs as upstream context; the reverse is not assumed.

## 3. Architecture

### 3.1 Command Surface

Default subcommand is `create` (highest-frequency use case).

| Invocation | Behavior |
|---|---|
| `/artifact` | Prompt for type (lists 4 built-in + any user templates). Run `create`. |
| `/artifact <type> [--tier lite\|full] [--preset <slug>]` | Sugar for `/artifact create <type>`. |
| `/artifact create <type> [--tier lite\|full] [--preset <slug>]` | Generate a new artifact. |
| `/artifact refine <path>` | Re-run the eval-loop judge against an existing artifact. **Internal QA**, no new external feedback. |
| `/artifact update <path>` | Apply stakeholder feedback (pasted comments, file, or dictated). Logs resolutions. **Stakeholder loop**, distinct from refine. |
| `/artifact template add\|list\|remove` | Manage user templates at `~/.pmos/artifacts/templates/<slug>/`. |
| `/artifact preset add\|list\|remove` | Manage user presets at `~/.pmos/artifacts/presets/<slug>.md`. |

Dropped: `list`, `show`, `template edit`, `preset edit` — filesystem and a text editor cover those.

### 3.2 Storage Layout

**Built-in (ships in plugin, read-only at runtime):**

```
plugins/pmos-toolkit/skills/artifact/
├── SKILL.md
├── templates/
│   ├── prd/
│   │   ├── template.md       # sections + frontmatter (files_to_read, tier, default_preset)
│   │   └── eval.md           # per-criterion: kind (precondition|judgment), check, gap_question, severity
│   ├── experiment-design/
│   │   ├── template.md
│   │   └── eval.md
│   ├── eng-design/
│   │   ├── template.md
│   │   └── eval.md
│   └── discovery/
│       ├── template.md
│       └── eval.md
├── presets/
│   ├── concise.md
│   ├── tabular.md
│   ├── narrative.md
│   └── executive.md
└── reviewer-prompt.md        # subagent system prompt for the eval loop
```

**User-owned (survives plugin upgrades):**

```
~/.pmos/artifacts/
├── templates/
│   └── <user-slug>/          # must NOT collide with built-in slug
│       ├── template.md
│       └── eval.md
└── presets/
    └── <user-slug>.md        # must NOT collide with built-in slug
```

**Lookup order:** Built-in templates and presets always win on slug. User-defined slugs must be unique. Rationale: prevents silent shadowing on plugin upgrades; users who want to fork a built-in copy it under a new slug (e.g., `prd-acme`).

**Generated artifact output:** `{docs_path}/features/{YYYY-MM-DD}_{slug}/{artifact-type}.md` — same feature folder convention as `/requirements`, `/spec`, `/plan`. Resolved via `_shared/feature-folder.md`.

### 3.3 Template File Anatomy

Each template directory contains exactly **two** files. (Earlier drafts had a third `context.md`; it was redundant — every "needs evidence" rule was already an eval criterion. Eval items now carry metadata that drives both context-gathering and judging from a single source.)

**`template.md`** — Frontmatter + section markdown with embedded section-level guidance and tier markers.

```markdown
---
name: PRD
slug: prd
description: Product Requirements Document
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

# {Artifact Type}

## §1. TL;DR
<!-- tier: both -->
<!-- purpose: one-paragraph forcing-function -->
<!-- guidance:
  - Names the customer/segment (not "users")
  - Names the change/capability
  - States expected outcome (movement, not feature-ship)
  - <= 4 sentences
-->
{generation prompt for this section}
```

**`eval.md`** — Per-section criteria with metadata for both phases.

```markdown
## §2 Problem & Customer

- id: evidence-cited
  kind: precondition          # gathered before generation; gap-Q if missing
  tier: [lite, full]
  check: ≥1 evidence (quote, ticket, data point, or research session ref)
  gap_question: |
    No customer evidence found in attached files. Paste a quote / ticket
    reference / data point, or describe the source.
  severity: high

- id: workaround-described
  kind: judgment              # judge-only check on the generated draft
  tier: [lite, full]
  check: current customer workaround / coping behavior described
  severity: medium

- id: no-solution-language
  kind: judgment
  tier: [lite, full]
  check: no "we will build X" smuggled into the problem statement
  severity: medium
```

**Two consumers, one file:**

- **Phase 5 Gap Interview** filters `kind=precondition`, checks each `check` against `files_to_read` content (semantic match), and queues `gap_question` for unsatisfied items. Batched ≤4 per `AskUserQuestion` call.
- **Phase 8 Refinement Loop** runs the reviewer subagent against ALL items (both kinds), since precondition-style criteria still apply to the generated draft (e.g., draft must show the gathered evidence in §2).

This eliminates the duplication that existed when context.md and eval.md held separately authored copies of the same "evidence required" rule.

**Tabular schemas (per tabular-friendly section).** Sections that list objects (Metrics, Variants, User Stories, Alternatives, Risks, Scope, Dependencies, Decision Criteria, Assumption Tests) carry a `tabular_schema` annotation in their template.md guidance comment. The Tabular preset honors the schema; other presets ignore it. The reviewer subagent, when the tabular preset is in use, judges schema-adherence as a `kind: judgment` eval item.

```markdown
## §5 Success Metrics
<!-- tier: lite, full -->
<!-- purpose: how we'll know it worked -->
<!-- guidance:
  - Primary metric: baseline + target + timebox + mechanism
  - ≥1 input metric, ≥1 guardrail
  - Owner + instrumentation status per metric
-->
<!-- tabular_schema:
  columns: [Metric, Layer (primary|input|guardrail|counter), Baseline, Target, Timebox, Mechanism, Owner, Instrumentation]
  row_per: metric
-->
```

Schemas keep table columns deterministic across runs and let the reviewer flag column drift. Authoring cost: ~6–10 schemas per template (only for tabular-friendly sections).

### 3.4 Preset Anatomy

Each preset is a single markdown file with rendering rules per section type:

```markdown
---
name: tabular
description: Tables for any list-of-objects; short prose for narrative sections
---

# Rendering rules

- Lists of objects (metrics, variants, risks, deps, scope) → markdown tables
- Narrative sections (Problem, User Journey) → prose, no bullets
- Procedural lists (rollout phases, test steps) → numbered bullets
- Diagrams: text/ASCII preferred; Mermaid if available

# Voice
- Concise; no filler
- Active voice
- ...
```

The skill loads the preset and instructs the generator to follow the rules per section type.

## 4. Templates

### 4.1 PRD

**Tier Lite (7 sections):** TL;DR · Problem & Customer · Goals + Metrics · Solution Sketch · User Journey · Scope (MVP) · Risks

**Tier Full (14 sections):** TL;DR · Problem & Customer · Why Now · Goals & Non-Goals · Success Metrics · Solution Overview · User Journey/Narrative · **User Stories & Acceptance Criteria** · Scope: MVP vs Later · Risks & Open Questions · Rollout & Experiment Plan · Dependencies & Stakeholders · FAQ · Appendix

**Hypothesis** is folded into Success Metrics (per-primary-metric: direction + magnitude + window + mechanism).

**§8 User Stories & Acceptance Criteria** (Full only) — research-grounded structure synthesizing Cohn (3 Cs, INVEST), Patton (story map, walking skeleton), Adzic (impact-laddering), Jeffries (placeholder-for-conversation), Klement (job stories), and modern PM critique (Aakash/Lenny: stories belong to the backlog, PRD holds the spine). Authoring rules:

- **Group by user-journey activity** (Patton backbone), not by priority. A flat priority-grouped list (must/should/could) is the antipattern Patton calls "context-free mulch."
- **3–7 stories per group**, **≤12 stories total**. More than 12 means you're writing a backlog, not a PRD.
- **Per-story format:** Connextra (`As a [role], I want [capability], so that [benefit]`) OR job story (`When [situation], I want to [motivation], so I can [outcome]`). Prefer job-story for situational/transactional features.
- **`so that` must ladder to a goal in §4** (Adzic) — no orphan benefits.
- **Acceptance criteria inline** per story: Given/When/Then for behavioral, checklist for static rules. Pick one form per story, not both.
- **Walking-skeleton subset marked** — the minimum top-row stories needed for end-to-end value.
- **Each story ≤3 lines + AC.** Stories are placeholders for conversation, not specs (Jeffries).

**Section-level eval** (selected highlights — full criteria in `eval.md`):

| Section | Key eval items |
|---|---|
| §1 TL;DR | Customer/segment named • change concrete • outcome stated • ≤4 sentences |
| §2 Problem & Customer | Specific segment + JTBD • ≥1 evidence (quote/ticket/data) • frequency or impact quantified • workaround described • no solution language |
| §3 Why Now (Full) | Cites strategy/OKR/bet • names concrete trigger or closing window • opportunity cost articulated |
| §4 Goals & Non-Goals | Goals outcome-shaped (1–3 max, each measurable) • ≥2 non-goals, reasonable not strawmen, with rationale |
| §5 Success Metrics | Primary: baseline+target+timebox • mechanism stated (falsifiable) • ≥1 input metric • ≥1 guardrail • owner+instrumentation status • numerator+denominator for ratios |
| §6 Solution Overview | Customer narrative present • happy + 1 alt flow • wireframe/prototype linked or TBD • no schema/API creep • new vs reused called out |
| §7 User Journey | Specific persona • numbered steps (entry→action→outcome) • mental state at key steps • happy + ≥1 alt path • ends at JTBD outcome |
| §8 User Stories & AC (Full) | Grouped by journey activity (NOT priority groups) • ≤12 stories total • role is a named segment from §2 (no "As a system/user") • `so that` traces to a goal in §4 • AC per story: G/W/T or checklist (one form, not both) • AC describes observable outcome (not impl steps) • walking-skeleton subset marked • job-story preferred over Connextra for situational features • stories don't duplicate Solution Overview • no solution-prescriptive stories ("I want a dropdown") |
| §9 Scope (MVP vs Later) | MVP = minimal set to test hypothesis • each Later item has deferral rationale • cut line ties to metrics • explicit OUTs called out |
| §10 Risks & Open Qs | Cagan 4 (V/U/F/V) all addressed or deferred • each risk: likelihood+impact+mitigation/test • Qs distinct from risks • Q owners + by-when |
| §11 Rollout (Full) | Phased ramp • kill criteria explicit (regression % per guardrail) • rollback plan named • tied to experiment doc if A/B • comms/launch deps |
| §12 Deps & Stakeholders (Full) | Dep team owners + by-when • stakeholders by role |
| §13 FAQ (Full) | ≥3 anticipated Qs • ≥1 hostile-skeptic Q |
| §14 Appendix (Full) | Pure links/data, no new prose • sources for above-cited evidence |

### 4.2 Experiment Design Doc

**Tier Lite (7 sections):** Summary · Hypothesis · Variants · Population · Metrics (primary + guardrail) · Sample Size + Duration · Decision Criteria

**Tier Full (13 sections):** Summary · Background & Motivation · Hypothesis · Variants · Unit of Randomization & Population · Metrics (OEC, secondary, guardrails, counter) · Sample Size, MDE, Duration · Allocation & Ramp Plan · Decision Criteria (pre-registered) · Risks & Trustworthiness · Analysis Plan · Stakeholders & Timeline · Appendix

| Section | Key eval items |
|---|---|
| §1 Summary | Variants named • population • expected lift • primary metric • ≤4 sentences |
| §2 Background (Full) | Prior data/signal cited • prior related experiments named or "none" • opportunity cost articulated |
| §3 Hypothesis | Mechanism non-trivial • direction stated • magnitude or MDE-bound • falsifiable |
| §4 Variants | Control concrete (status quo) • treatments described with screenshot/copy/code path • differences explicit if multi-arm • variant count justified by sample size |
| §5 Population | Unit named • unit matches metric • eligibility filters explicit • exclusions explicit • estimated population size |
| §6 Metrics | Primary: numerator+denominator+baseline+variance • ≥1 guardrail w/ regression threshold • each metric: instrumentation status • (Full) ≥1 counter-metric |
| §7 Sample Size/MDE/Duration | MDE stated • power-calc inputs shown • duration ≥1 weekly cycle • calc method named • per-arm size for multi-arm |
| §8 Allocation & Ramp (Full) | Initial ramp % • ramp triggers explicit • SRM check planned • A/A pre-check or justification |
| §9 Decision Criteria | Ship/hold/kill thresholds quantitative • guardrail regression thresholds explicit • "draw" defined • multi-metric correction plan • tied to business cost of error • pre-registered date stamped |
| §10 Risks (Full) | Carryover/novelty addressed • network/spillover or N/A • instrumentation validity • A/A history or planned |
| §11 Analysis Plan (Full) | Segments declared up-front • heterogeneity hypotheses pre-stated • readout format named |
| §12 Stakeholders | Owner + reviewer + readout date + eng instrumentation owner if needed |
| §13 Appendix (Full) | Tracking spec + dashboard linked • prior related experiments referenced |

### 4.3 Engineering Design Doc / RFC

**Tier Lite (8 sections):** Header · TL;DR · Context · Goals/Non-Goals · Proposal · Alternatives · Risks · Rollout

**Tier Full (14 sections):** Title/Authors/Status/Reviewers · TL;DR · Context & Background · Goals & Non-Goals · Proposal/High-Level Design · Detailed Design · Alternatives Considered · Cross-Cutting Concerns · Migration/Rollout · Testing & Verification · Operational Readiness · Risks & Open Questions · Timeline & Milestones · Appendix

| Section | Key eval items |
|---|---|
| §1 Header | Descriptive title • authors + reviewers named • status enum • last-updated date |
| §2 TL;DR | Problem + chosen approach + key tradeoff • ≤5 sentences |
| §3 Context | Existing system named (file path or service) • prior docs linked • objective only • verbose schema deferred |
| §4 Goals & Non-Goals | Goals outcome-shaped (latency, correctness, cost, reliability — not "use Foo") • 1–5 goals • ≥2 non-goals reasonable • rationale per non-goal |
| §5 Proposal | System diagram present • end-to-end data flow • key interfaces named • tradeoffs surfaced here • reader can predict code shape |
| §6 Detailed Design (Full) | API contracts (signatures, error shapes) • data model • algorithms/state transitions • per-component failure modes • concurrency/races addressed or N/A |
| §7 Alternatives | ≥2 alternatives • one is the boring option (do nothing/use existing/off-the-shelf) • tradeoffs explicit • WHY REJECTED for each • comparison table |
| §8 Cross-Cutting (Full) | Security threat model or N/A • privacy PII • compliance regs named • observability (metrics+logs+traces+alerts) • perf budget + QPS • cost estimate. N/A entries must include reason. |
| §9 Migration/Rollout | Phasing • backfill/dual-write if data migration • rollback w/ trigger • deprecation path • compat shims removal date |
| §10 Testing (Full) | Unit/integration/load split • how we know it works in prod (synthetic/shadow/canary) • failure-injection plan |
| §11 Op Readiness (Full) | On-call owner • dashboards • alerts • runbook stub • SLOs quantified (availability, latency p50/p99) |
| §12 Risks | Each: likelihood+impact+mitigation • Qs distinct from risks • Q owners + by-when • rewrite-forcing risks called out |
| §13 Timeline (Full) | Sized phases not just dates • per-phase exit criteria • cross-team deps surfaced • confidence interval |
| §14 Appendix (Full) | No new content; links/schemas/data only |

### 4.4 Discovery Doc

**Single tier, 7 sections** — decision-shaped, synthesizing Sirjani (Decisions First Research), Torres (Continuous Discovery / Opportunity Solution Tree), Cagan (4 risks), JTBD job stories, Sharon/Hall (research questions), Strategyzer (assumption-test discipline minus the card terminology).

1. **Decision** (Sirjani) — decision being made · evidence needed · evidence we hold · evidence gap
2. **Opportunity / Job Story** (Torres + JTBD) — "When [situation], I want to [motivation], so I can [outcome]" + segment + evidence
3. **Research Questions** (Sharon / Hall) — 3–7 open-ended questions traceable to the evidence gap
4. **Assumptions Map** (Cagan + Strategyzer) — assumptions tagged V/U/F/V, plotted importance × evidence, top-3 riskiest called out
5. **Assumption Tests** — pre-test (Hypothesis · Method · Metric · Success criterion · Owner · By-when) and post-test (Observation · Insight · Next decision) for each riskiest assumption
6. **Research Cadence & Methods** — cadence, recruitment, method library, synthesis ritual
7. **Decision Update & Next Steps** — restates §1 decision + status (open/decided/reframed); handoff criteria to PRD if decided

| Section | Key eval items |
|---|---|
| §1 Decision | Decision concrete (ship/don't, build/buy, A vs B — not "understand users") • owner + by-when • evidence-needed specific (numbers/behaviors/quotes) • evidence-held cites sources • gap explicit |
| §2 Opportunity | Canonical job-story format • specific situation • outcome = user end-state not feature • segment named • ≥1 evidence cited |
| §3 Research Qs | 3–7 questions • open-ended (not yes/no) • each traces to gap (no orphans) • mix of behavior/motivation/context • answer "what we don't know", not "what we want them to say" |
| §4 Assumptions Map | All 4 Cagan dims represented • each phrased as falsifiable belief ("we believe X") not a question • importance + evidence rated • top 3 riskiest called out |
| §5 Assumption Tests | Hypothesis is assumption restated as falsifiable statement • method matches assumption type • metric explicit • success criterion pre-registered • smallest viable test • owner + by-when • (post) observation is data not interpretation • insight names what changed in our model • next decision concrete |
| §6 Cadence | Cadence stated • recruitment channel • method library (when to use which) • synthesis ritual |
| §7 Decision Update | Restates §1 + status • if decided: handoff criteria • if open: next test + by-when • if reframed: original archived, new decision named |

## 5. Writing-Style Presets

Four built-in presets, each a single `.md` file with rendering rules per section type plus a voice/tone guide.

| Preset | Default tone | Section rendering |
|---|---|---|
| **Concise** | Tight, terse | Nested bullets; minimal prose; tables only when comparative data |
| **Tabular** | Same as Concise but tables-by-default | Tables for any list-of-objects (metrics, variants, risks, deps, scope); short prose for narrative sections (Problem, User Journey); numbered bullets for procedural lists |
| **Narrative** | Amazon PR/FAQ prose | Complete sentences; flowing prose; bullets only when truly enumerative |
| **Executive** | TL;DR-heavy, scannable | Bolded key takeaways; dense exec summary; light body; section-end "What this means" callouts |

User can author additional presets via `/artifact preset add` (interactive guided flow). Presets are independent of templates — any preset works with any template.

## 6. Pipeline (Skill Phases)

The skill follows the pmos-toolkit phase pattern with explicit gates.

### Phase 0 — Load Context

1. Follow `product-context/context-loading.md` to resolve `{docs_path}` and load workstream context.
2. Read `~/.pmos/learnings.md`; note entries under `## /artifact`.
3. Resolve subcommand (default `create`) and route.

### Phase 1 — Subcommand Routing

| Argument | Phase entry |
|---|---|
| `(empty)` or `<type>` | → create flow |
| `create <type>` | → create flow |
| `refine <path>` | → refine flow |
| `update <path>` | → update flow |
| `template add\|list\|remove` | → template-management flow |
| `preset add\|list\|remove` | → preset-management flow |

### Phase 2 — Create Flow (unified across all artifact types)

The same 12-phase flow applies to PRD, Experiment Design, Eng Design, Discovery, and any user-defined template.

1. **Resolve template:** lookup by slug (built-in always wins; user templates use unique slugs). If not found, list available + offer fuzzy match. Validate: `template.md` and `eval.md` present; frontmatter parses; eval section IDs match template section IDs.
2. **Tier detection:** read `template.md` frontmatter `tiers` list. If `[lite, full]`, auto-suggest based on signals (requirements doc richness, user input length, scope hints) and prompt user with a recommendation. `--tier` flag bypasses prompt. Single-tier templates (e.g., Discovery) skip this step.
3. **Resolve feature folder** via `_shared/feature-folder.md` (mandatory `{YYYY-MM-DD}_{slug}` prefix).
4. **Auto-consume upstream artifacts:** read every `files_to_read` entry from `template.md` frontmatter. Built-in patterns include: requirements doc, spec doc, wireframes/prototype outputs in the feature folder; user-attached files; workstream context.
5. **Gap interview:** load `eval.md`, filter items where `kind: precondition`. For each, do a semantic check against the auto-read content (does anything in those files satisfy the `check`?). For unsatisfied items, queue the item's `gap_question`. Batch ≤4 questions per `AskUserQuestion` call. Skip questions whose evidence was already supplied.
6. **Preset selection:** if `--preset` flag present, use it. Else use `template.md` frontmatter `default_preset` (e.g., Tabular for experiment-design, Narrative for PRD), confirming with user before proceeding.
7. **Generate draft:** use `template.md` sections + selected preset rules + gathered context (auto-read content + gap-question answers). Write to `{feature_folder}/{type}.md` (single file by default; `--tier` is recorded in the artifact's frontmatter, not the filename).

### Phase 3 — Self-Refinement Loop (max 2 iterations)

Mirrors `/wireframes` Phase 4 pattern.

1. **Dispatch reviewer subagent.** Prompt is `reviewer-prompt.md` + the artifact's `eval.md` (ALL items — both `precondition` and `judgment` kinds, since precondition rules still apply to the rendered draft) + the draft. Subagent returns JSON: `[{section, criterion_id, severity: high|medium|low, finding, suggested_fix}]`.
2. **Auto-apply** all `high` and `medium` findings via `Edit`. Log `low` findings.
3. **Loop continuation:** if any `high` remain after applying, run loop 2. Hard cap: 2 loops.
4. **Residual surface:** any `high` remaining after loop 2, plus `medium`/`low` findings worth raising, get surfaced via Findings Presentation Protocol — batched ≤4 per `AskUserQuestion`, options Apply / Modify / Skip / Defer.

The reviewer subagent reads only the section-relevant eval items per finding and never invents criteria not in `eval.md`.

### Phase 4 — Save & Confirm

1. Write final artifact to `{feature_folder}/{type}.md`.
2. Show user a one-paragraph summary: sections written, eval-loop iterations, residuals deferred.
3. Offer to `git add` + commit (do not auto-commit; consistent with other pmos-toolkit skills).

### Phase 5 — Workstream Enrichment

Propose updates to `~/.pmos/workstreams/{workstream}.md` based on signals discovered (new user segments, metrics, decisions). User approves each addition.

### Phase 6 — Capture Learnings

Read `learnings/learnings-capture.md` and reflect on capture-worthy patterns from this session. Terminal gate.

### Refine Flow (`/artifact refine <path>`)

1. Read existing artifact at `<path>` and its template + eval (inferred from artifact type frontmatter or asked).
2. Run Phase 3 self-refinement loop.
3. Run Phase 4 save (overwrite or write a `.refined.md` sibling — ask).

### Update Flow (`/artifact update <path>`)

1. Accept feedback input: pasted comments, file path, inline notes, or "I'll dictate" mode.
2. Parse feedback into structured items: `[{section, type: edit|expand|trim|question|accept|reject, content}]`. Ambiguous items get a clarifying question (one batched call).
3. Apply items via Findings Presentation Protocol: Apply / Modify / Skip / Defer per item, batched ≤4 per `AskUserQuestion`.
4. Append a "Comment Resolution Log" section to the artifact: `[date] [reviewer] [section] [feedback] [resolution]`.
5. Optionally re-run Phase 3 eval loop after applying (ask).
6. Save.

### Template Management Flow (`/artifact template add`)

Multi-phase research-grounded authoring; mirrors the brainstorm that produced the 4 built-in templates so user templates ship at comparable quality. A `--quick` flag drops to scaffold-only mode for power users who already have a clear template in mind.

1. **Intake.** User describes: name + slug (must not collide with built-in), purpose / when used, audience, examples (links / pasted reference docs), inspirations / frameworks they want grounded in. Validate slug uniqueness against built-in templates.
2. **Research subagent** (skip if `--quick` or user opts out). Dispatched with the artifact-class name + cited inspirations. Subagent web-searches canonical sources (e.g., "OKR doc," "incident postmortem," "design review checklist"), returns: proposed sections with one-line purpose each, proposed eval items per section (with `kind`, `check`, `gap_question`, `severity`), proposed `files_to_read`, and cited source links.
3. **Section-by-section alignment.** For each proposed section, present an `AskUserQuestion` with options Approve / Tweak / Discuss / Drop, showing the section's purpose and eval criteria as a preview. Capture decisions.
4. **Frontmatter authoring.** Confirm `files_to_read`, `tiers` (single vs lite/full), `default_preset` with the user.
5. **Generate the 2-file template** at `~/.pmos/artifacts/templates/<slug>/`: `template.md` (frontmatter + section markdown with embedded guidance) and `eval.md` (per-criterion items with metadata). Validate on write — frontmatter parses, eval section IDs match template section IDs.
6. **Optional dry-run.** Offer to generate one artifact with the new template (using the user's last feature folder or a synthetic input) so they can stress-test it. User can iterate on sections/evals based on what the dry-run produces.

### Other Management Flows

- **`template list`** — Show built-in + user templates with source labels (`[built-in]` / `[user]`). Read-only.
- **`template remove`** — Delete user template. Built-in templates cannot be removed; warn if attempted.
- **`preset add`** — Interactive guided. Prompts: name, description, rendering rules per section type, voice/tone. Writes `~/.pmos/artifacts/presets/<slug>.md`. Slug must not collide with built-in.
- **`preset list` / `preset remove`** — symmetric to template list/remove.

## 7. Self-Refinement Loop — Detail

The reviewer subagent receives:

- The full draft
- The template's `eval.md` (section-level criteria)
- A reviewer system prompt (`reviewer-prompt.md`) instructing it to: (a) read each section, (b) check against the eval items for that section, (c) return JSON findings only, (d) never invent criteria.

Severity rubric:

- **high** — eval item failed in a way that breaks the section's purpose (e.g., problem section with no evidence; metrics section with no baseline)
- **medium** — eval item failed but section is still functional (e.g., one of three goals isn't outcome-shaped)
- **low** — stylistic/polish nit (preset adherence, length)

Auto-apply rules:

- High: always auto-fix per `suggested_fix`
- Medium: always auto-fix per `suggested_fix`
- Low: log only; surface only if loop 2 still has residuals worth a user decision

Loop terminates when: zero `high` remain OR loop 2 completes. Diminishing returns past 2.

## 8. Risks & Open Questions

**Risks**

- **Template slug collision on plugin upgrade.** New built-in template added with slug a user already used. Mitigation: skill detects collision at load; warns; user is asked to rename theirs (one-shot migration).
- **Reviewer subagent self-fulfilling.** Same-model judging same-model output can rubber-stamp. Mitigation: eval criteria are concrete pass/fail, not "is this good?". Mid-build, evaluate by manually grading 10 generated artifacts vs reviewer findings.
- **Auto-apply destroys user intent.** A reviewer auto-fix might overwrite something the user wrote deliberately. Mitigation: refine flow defaults to writing `.refined.md` sibling, not overwrite; create flow always shows summary before save.
- **Update flow ambiguity.** Stakeholder feedback rarely maps cleanly to sections. Mitigation: ambiguous items get a clarifying question batch; un-mappable items go into a "General feedback" appendix to the artifact.

**Open Questions**

- Should `eval.md` be loadable per-section to keep the subagent prompt small, or is a single-file load fine? (Likely fine until templates exceed ~15 sections; revisit if perf is an issue.) — Owner: implementer, by first internal use.
- Should presets be selectable per-section (e.g., Narrative for Problem, Tabular for Metrics) instead of doc-wide? Probably yes long-term, but v1 is doc-wide. — Owner: PM, by v1 dogfooding feedback.
- Should `/artifact update` support inline-comment formats from common tools (Google Docs export, Notion comment dumps)? v1 supports raw paste + file; format-specific parsers later. — Owner: implementer, by v2.

## 9. Dependencies

- `_shared/feature-folder.md` (existing) — for folder resolution
- `_shared/interactive-prompts.md` (existing) — for AskUserQuestion fallback
- `product-context/context-loading.md` (existing) — for workstream context
- `learnings/learnings-capture.md` (existing) — for learnings phase
- Reviewer subagent capability — relies on `Agent` tool with `general-purpose` subagent or a dedicated subagent type. v1 uses `general-purpose`.

## 10. Testing & Verification

- Unit-equivalent: render each built-in template with synthetic context, verify all required sections present.
- Integration: end-to-end run for each artifact type with a real-ish requirements doc; verify eval loop reduces high-severity findings to zero or surfaces residuals; verify save path; verify Comment Resolution Log on `update`.
- Manual: dogfood by generating 2 PRDs, 2 EDs, 2 EDDs, 1 Discovery in a real feature folder; rate quality 1–5 by hand; compare to baseline (no eval loop) on 2 of them.
- Plugin-upgrade safety: temp `~/.pmos/artifacts/` with custom template + preset; bump plugin version; verify custom items still load and aren't shadowed.

## 11. Implementation Outline

This spec hands off to `/plan`. The plan should cover, in order:

1. Skill scaffold (`plugins/pmos-toolkit/skills/artifact/SKILL.md`) with Phase 0–6 structure
2. Built-in template files: `prd/`, `experiment-design/`, `eng-design/`, `discovery/` (template.md + eval.md each — eval-item metadata drives both gap-interview and judge phases)
3. Built-in presets: `concise.md`, `tabular.md`, `narrative.md`, `executive.md`
4. `reviewer-prompt.md` for the eval loop subagent
5. Subcommand routing logic in SKILL.md
6. `~/.pmos/artifacts/` initialization on first run
7. `update` flow's feedback parser + Comment Resolution Log appender
8. Template/preset management flows (add/list/remove)
9. Plugin manifest registration (auto-discovered)
10. Documentation update in repo `README.md`

Subcommand pattern, gate language, and Findings Presentation Protocol are reused verbatim from `/wireframes`, `/mytasks`, and `/spec`.
