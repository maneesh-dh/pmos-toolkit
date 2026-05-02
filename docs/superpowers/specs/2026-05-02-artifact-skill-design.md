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

- Replacing `/spec` (technical specification used in pipeline) with `/artifact eng-design`. The two coexist: `/spec` is the implementation-bound spec inside the requirements→spec→plan pipeline; `/artifact eng-design` is a standalone RFC/design doc artifact.
- Real-time collaboration / multi-author merge. Artifacts are markdown files; collaboration uses the host system (git, Notion, Google Docs export).
- Auto-publishing to Notion/Confluence/Drive in v1. Out of scope; the user can export manually.
- Version-controlling artifacts inside the skill. Git in the host repo handles that.

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
│   │   ├── template.md       # tier-aware sections + per-section guidance
│   │   ├── eval.md           # section-level eval criteria for the judge
│   │   └── context.md        # what context to gather; what to ask if missing
│   ├── experiment-design/
│   │   ├── template.md
│   │   ├── eval.md
│   │   └── context.md
│   ├── eng-design/
│   │   ├── template.md
│   │   ├── eval.md
│   │   └── context.md
│   └── discovery/
│       ├── template.md
│       ├── eval.md
│       └── context.md
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
│       ├── eval.md
│       └── context.md
└── presets/
    └── <user-slug>.md        # must NOT collide with built-in slug
```

**Lookup order:** Built-in templates and presets always win on slug. User-defined slugs must be unique. Rationale: prevents silent shadowing on plugin upgrades; users who want to fork a built-in copy it under a new slug (e.g., `prd-acme`).

**Generated artifact output:** `{docs_path}/features/{YYYY-MM-DD}_{slug}/{artifact-type}.md` — same feature folder convention as `/requirements`, `/spec`, `/plan`. Resolved via `_shared/feature-folder.md`.

### 3.3 Template File Anatomy

Each template directory contains exactly three files:

**`template.md`** — Section markdown with embedded section-level guidance and tier markers. Format:

```markdown
# {Artifact Type}

<!-- tier: lite, full -->

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

**`eval.md`** — Per-section eval criteria the reviewer subagent uses. Returns JSON findings: `[{section, severity: high|medium|low, finding, suggested_fix}]`.

**`context.md`** — What files to auto-read (requirements doc, workstream, attached files), what gap-questions to ask if context is missing, and what evidence each section depends on.

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

**Tier Full (13 sections):** TL;DR · Problem & Customer · Why Now · Goals & Non-Goals · Success Metrics · Solution Overview · User Journey/Narrative · Scope: MVP vs Later · Risks & Open Questions · Rollout & Experiment Plan · Dependencies & Stakeholders · FAQ · Appendix

**Hypothesis** is folded into Success Metrics (per-primary-metric: direction + magnitude + window + mechanism).

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
| §8 Scope (MVP vs Later) | MVP = minimal set to test hypothesis • each Later item has deferral rationale • cut line ties to metrics • explicit OUTs called out |
| §9 Risks & Open Qs | Cagan 4 (V/U/F/V) all addressed or deferred • each risk: likelihood+impact+mitigation/test • Qs distinct from risks • Q owners + by-when |
| §10 Rollout (Full) | Phased ramp • kill criteria explicit (regression % per guardrail) • rollback plan named • tied to experiment doc if A/B • comms/launch deps |
| §11 Deps & Stakeholders (Full) | Dep team owners + by-when • stakeholders by role |
| §12 FAQ (Full) | ≥3 anticipated Qs • ≥1 hostile-skeptic Q |
| §13 Appendix (Full) | Pure links/data, no new prose • sources for above-cited evidence |

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

### Phase 2 — Create Flow

1. **Resolve template:** lookup by slug (built-in always wins; user templates use unique slugs). If not found, list available + offer fuzzy match.
2. **Tier detection (if applicable):** read `template.md` tier metadata. Auto-suggest based on signals (requirements doc richness, user input length, scope hints) and prompt user with a recommendation. `--tier` flag bypasses prompt.
3. **Resolve feature folder** via `_shared/feature-folder.md` (mandatory `{YYYY-MM-DD}_{slug}` prefix).
4. **Auto-consume upstream artifacts:** read requirements doc, spec doc, wireframes/prototype outputs in the feature folder. Read user-attached files. Read workstream context.
5. **Gap interview:** load template's `context.md`. For any required-context item not satisfied by Phase 2.4, ask the user one or two batched questions via `AskUserQuestion`. No needless questions.
6. **Preset selection:** if `--preset` flag present, use it. Else suggest a sensible default for the artifact type (e.g., Tabular for experiment-design, Narrative for PRD) and ask.
7. **Generate draft:** use `template.md` + selected preset rules + gathered context. Write to `{feature_folder}/{type}.md` (or `{type}-{tier}.md` if user wants tier preserved in filename — single file by default).

### Phase 3 — Self-Refinement Loop (max 2 iterations)

Mirrors `/wireframes` Phase 4 pattern.

1. **Dispatch reviewer subagent.** Prompt is `reviewer-prompt.md` + the artifact's `eval.md` + the draft. Subagent returns JSON: `[{section, severity: high|medium|low, finding, suggested_fix}]`.
2. **Auto-apply** all `high` and `medium` findings via `Edit`. Log `low` findings.
3. **Loop continuation:** if any `high` remain after applying, run loop 2. Hard cap: 2 loops.
4. **Residual surface:** any `high` remaining after loop 2, plus `medium`/`low` findings worth raising, get surfaced via Findings Presentation Protocol — batched ≤4 per `AskUserQuestion`, options Apply / Modify / Skip / Defer.

The reviewer subagent reads only the section-relevant eval items per finding, never invents criteria not in `eval.md`.

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

### Template/Preset Management Flows

- **`template add`** — Interactive guided. Prompts: name (must not collide with built-in), description, sections (one at a time), per-section purpose + eval criteria, context-needs. Generates `template.md` + `eval.md` + `context.md` at `~/.pmos/artifacts/templates/<slug>/`.
- **`template list`** — Show built-in + user templates with source labels. Read-only.
- **`template remove`** — Delete user template. Built-in templates cannot be removed; warn if attempted.
- **`preset add`** — Interactive guided. Prompts: name, description, rendering rules per section type, voice/tone. Writes `~/.pmos/artifacts/presets/<slug>.md`.
- **`preset list` / `preset remove`** — symmetric.

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
2. Built-in template files: `prd/`, `experiment-design/`, `eng-design/`, `discovery/` (template.md + eval.md + context.md each)
3. Built-in presets: `concise.md`, `tabular.md`, `narrative.md`, `executive.md`
4. `reviewer-prompt.md` for the eval loop subagent
5. Subcommand routing logic in SKILL.md
6. `~/.pmos/artifacts/` initialization on first run
7. `update` flow's feedback parser + Comment Resolution Log appender
8. Template/preset management flows (add/list/remove)
9. Plugin manifest registration (auto-discovered)
10. Documentation update in repo `README.md`

Subcommand pattern, gate language, and Findings Presentation Protocol are reused verbatim from `/wireframes`, `/mytasks`, and `/spec`.
