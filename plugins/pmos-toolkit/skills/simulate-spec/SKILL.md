---
name: simulate-spec
description: Pressure-test a spec against realistic and adversarial scenarios before implementation — scenario trace, artifact fitness critique, interface cross-reference, targeted pseudocode. Optional validator between /spec and /plan in the requirements -> spec -> plan pipeline. Use when the user says "simulate the design", "validate this spec", "will this design actually work", "check for gaps in the design", or has a spec ready for end-to-end scrutiny before implementation.
user-invocable: true
argument-hint: "<path-to-spec-doc>"
---

# Spec Simulation Generator

Pressure-test a technical spec by walking realistic and adversarial scenarios through it, critiquing each artifact for fitness, cross-referencing interface and core, and producing a standalone simulation doc whose Gap Register drives coordinated spec patches. The output is both a quality gate and a durable "why we believe this design works" artifact.

This is an OPTIONAL VALIDATOR in the pipeline — runs between `/spec` and `/plan`:

```
/requirements  →  [/msf, /creativity]  →  /spec  →  [/simulate-spec]  →  /plan  →  /execute  →  /verify
                   optional enhancers              (this skill)
                                                  optional validator
```

**Announce at start:** "Using the simulate-spec skill to pressure-test the design."

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:
- **No `AskUserQuestion`:** State your assumption, document it in the output, and proceed. The user reviews after completion.
- **No subagents:** Perform research and analysis sequentially as a single agent.
- **No Playwright MCP:** Note browser-based verification as a manual step for the user.

## Track Progress

This skill has multiple phases. Create one task per phase using your agent's task-tracking tool (e.g., `TodoWrite` in Claude Code, equivalent in other agents). Mark each task in-progress when you start it and completed as soon as it finishes — do not batch completions.

## Load Learnings

Read `~/.pmos/learnings.md` if it exists. Note any entries under `## /simulate-spec` and factor them into your approach for this session.

## Locate Spec

Follow `../.shared/resolve-input.md` with `phase=specs`, `label="spec"`. Read the resolved file end-to-end before Phase 1.

---

## Phase 0: Load Workstream Context

Before any other work, follow the context loading instructions in `product-context/context-loading.md` (relative to the skills directory). This determines `{docs_path}` and loads workstream context if available. Use workstream context to inform critique — product constraints and tech-stack decisions shape what counts as a gap. Also note any entries under `## /simulate-spec` in `~/.pmos/learnings.md` and factor them into your approach for this session.

---

## Phase 1: Intake, Tier Detection & Scope Declaration

### 1.1 Locate the spec
Follow `../.shared/resolve-input.md` with `phase=specs`, `label="spec"`. Echo the resolved path before proceeding.

### 1.2 Read the spec end-to-end
Read the full file. Summarize back to the user in 3-5 bullets covering: problem, primary goals, tier, decisions already made. Confirm understanding via AskUserQuestion (or state assumption per Platform Adaptation if AskUserQuestion is unavailable).

### 1.3 Check for existing simulation
Look in `{docs_path}/simulations/` for an existing file covering this feature.
- **If found:** ask "Is this an update to the existing simulation, or a fresh start?" Update mode re-traces only against changed spec sections; fresh start re-runs all phases.
- **If not found:** proceed.

### 1.4 Detect tier from spec header

| Tier | Behavior |
|------|----------|
| **Tier 1** (bug fix) | Skill refuses to run. Announce: "This is a Tier 1 spec — simulation is overkill. Skipping." Then exit. |
| **Tier 2** (enhancement) | All phases run. Inline gap resolution (one gap at a time in Phase 7). 1 review loop. |
| **Tier 3** (feature / new system) | All phases run. Batched gap resolution (by category in Phase 7). 1 review loop. Deeper adversarial coverage in Phase 2. |

The tier is declared in the spec header (e.g., `**Tier:** 2`). If absent, infer from scope (single bug → Tier 1; behavior enhancement → Tier 2; new capability or major redesign → Tier 3) and announce the inferred tier for confirmation.

### 1.5 Scope Declaration

Auto-detect the layers present in the spec by scanning section headers (DB Schema, API Contracts, Frontend Design, CLI, Events, Infrastructure, etc.). Combine with the spec's Non-Goals section. Then ask the user via AskUserQuestion:

> "Scope check:
> - **In this spec:** [auto-detected layers]
> - **Out of scope** (deferred to separate spec or later phase)?
> - **Companion specs** (e.g., backend-spec.md and frontend-spec.md)? Paths if any.
> - **Downstream consumers we should anticipate** (e.g., 'web UI in Phase 2')?"

Record the answers. The scope drives everything downstream:
- **Out-of-scope layers** → their critique buckets in Phase 4 are SKIPPED, not flagged as gaps
- **Companion specs** → cross-referenced during Phase 5 wire-up (read the companion, do the cross-reference table against it)
- **Anticipated consumers** → produce **forward-compat notes** rather than gaps — soft flags like "API response lacks `discount_breakdown` — fine today but likely needed when the visual UI lands"

### 1.6 Record scope

Hold scope state in memory; it gets written into Phase 8's simulation doc Section 1 (Scope).

**Gate:** Do not proceed to Phase 2 until tier is confirmed and scope is declared.

## Phase 2: Scenario Enumeration

Stub — to be filled in T3.

## Phase 3: Scenario Trace

Stub — to be filled in T4.

## Phase 4: Artifact Fitness Critique

Stub — to be filled in T4.

## Phase 5: Interface ↔ Core Cross-Reference

Stub — to be filled in T4.

## Phase 6: Targeted Pseudocode

Stub — to be filled in T5.

## Phase 7: Gap Resolution

Stub — to be filled in T5.

## Phase 8: Write Simulation Doc

Stub — to be filled in T6.

## Phase 9: Review Loop

Stub — to be filled in T6.

## Phase 10: Workstream Enrichment

Stub — to be filled in T7.

## Phase 11: Capture Learnings

Stub — to be filled in T7.

---

## Anti-Patterns (DO NOT)

To be filled in T7.
