---
name: msf-req
description: Evaluate a requirements document from the end-user perspective using Motivation/Satisfaction/Friction analysis. Produces a recommendations-only findings doc; never edits the source. Use when the user says "evaluate UX of the requirements", "will the proposed solution work for users", "persona check on this PRD", or "friction analysis on requirements".
user-invocable: true
argument-hint: "<path-to-requirements-doc>"
---

# /msf-req — Motivation / Friction / Satisfaction on a Requirements Doc

Evaluate a requirements document by simulating end-user experience across personas and journeys. Identifies hidden friction, motivation gaps, and satisfaction shortfalls before `/spec`. Produces recommendations only — never edits the source requirements doc.

Best applied to **Tier 3 requirements** (features / product launches) after `/requirements` and before `/spec`. For wireframe-grounded analysis, use `/msf-wf` instead.

```
/requirements  →  [/msf-req, /creativity]  →  /spec  →  /plan  →  /execute  →  /verify
                   (this skill) ↑
```

**Announce at start:** "Using the /msf-req skill to evaluate user motivation, friction, and satisfaction on the requirements doc."

## Platform Adaptation

These instructions use Claude Code tool names. In other environments:
- **No `AskUserQuestion`:** state the proposed personas/dispositions and proceed; the user reviews after completion.
- **No subagents:** sequential single-agent analysis.

---

## Phase 0: Pipeline Setup (inline — do not skip)

Use workstream context (loaded by step 3 below) to inform analysis — product constraints and stakeholder concerns shape what counts as friction.

<!-- pipeline-setup-block:start -->
1. **Read `.pmos/settings.yaml`.**
   - If missing → you MUST invoke the `Read` tool on `_shared/pipeline-setup.md` Section A and run first-run setup before proceeding.
2. Set `{docs_path}` from `settings.docs_path`.
3. If `settings.workstream` is non-null → load `~/.pmos/workstreams/{workstream}.md` as context preamble; if frontmatter `type` is `charter` or `feature` and a `product` field exists, also load `~/.pmos/workstreams/{product}.md` read-only.
4. Resolve `{feature_folder}`:
   - If `--feature <slug>` was passed → glob `{docs_path}/features/*_<slug>/`.
   - Else if the argument's path resolves to a file inside `{docs_path}/features/<slug>/` → use that folder.
   - Else → ad-hoc invocation; `{feature_folder}` is unset.
5. Read `~/.pmos/learnings.md` if present; note entries under `## /msf-req` and factor them into approach (skill body wins on conflict).
<!-- pipeline-setup-block:end -->

---

## Phase 1: Wrong-input Guard

Before any other phase, inspect the argument:

- If the argument resolves to a **directory** → exit with: "Argument looks like a wireframes folder. Use `/msf-wf` instead." Do NOT continue.
- If the argument resolves to a single `.md` file → continue.
- If the argument is missing → continue to Phase 2 (resolve-input handles missing arg).

This guard runs before persona alignment, learnings load, or any analysis.

---

## Phase 2: Locate Requirements

Follow `../_shared/resolve-input.md` with `phase=requirements`, `label="requirements doc"`. Read the resolved file end-to-end before Phase 3.

---

## Phase 3: Persona Alignment

Follow `../_shared/msf-heuristics.md` "Persona Alignment" section. Behavior:

- First, extract any personas/journeys explicitly named in the requirements doc (sections like "Users", "Personas", "Stakeholders", or named in user journeys).
- Propose those for confirmation.
- If the requirements doc names no personas, propose 2–5 inferred personas (max 2 scenarios each) and confirm via `AskUserQuestion`.

The confirmation step is mandatory — never skipped.

---

## Phase 4: Journey Confirmation

List the key user journeys mentioned in the requirements doc. Confirm via `AskUserQuestion` before proceeding.

If the requirements doc does not name discrete journeys, propose 2–4 inferred journeys based on the goals + functional sections, and confirm.

---

## Phase 5: MSF Pass A

For each persona × scenario × journey, walk the M / F / S consideration questions in `../_shared/msf-heuristics.md` (Motivation Considerations, Friction Considerations, Satisfaction Considerations).

Because the source is text-only (no UI to ground in), state assumptions about flow ordering and surface them in the findings doc for user verification. Cite specific requirements-doc sections, FR-IDs, or user-journey steps when answering each consideration.

If a question isn't applicable for a given persona/scenario, say so briefly rather than skipping silently.

---

## Phase 6: Save Findings

Save the consolidated MSF analysis matrix.

**Save path:**
- If invoked inside a pipeline feature folder (`{feature_folder}` resolved in Phase 0 step 4) → `{feature_folder}/msf-findings.md`.
- Else (ad-hoc) → `~/.pmos/msf/YYYY-MM-DD_<slug>.md`, where `<slug>` is derived from the argument's filename (lowercase, hyphenated).

The findings doc has **no line cap**. Contains the full persona × scenario × journey × consideration matrix plus the prioritized Must / Should / Nice recommendations table per `../_shared/msf-heuristics.md` "Executive Summary Template".

**No actionable findings — terminal state.** When analysis surfaces nothing rated Must / Should / Nice, emit "no actionable findings" in chat and save the findings doc with empty recommendation tables. Do not pad with manufactured items.

---

## Phase 7: Executive Summary in Chat

Render the executive summary per `../_shared/msf-heuristics.md` "Executive Summary Template". Cap chat output at **200 lines**.

**Summary Overrides (req-mode):**

- No PSYCH section — wireframe-grounded scoring does not apply to a text-only artifact.
- If a wireframes folder exists adjacent to the requirements doc (e.g., `<feature_folder>/wireframes/`), append a one-line suggestion at the end of the summary: `Wireframes detected at <path>; consider /msf-wf for grounded analysis.`

After saving and rendering the summary, the skill **terminates**. Do not edit the requirements doc. The user folds findings into a revised doc themselves (manually or via `/requirements`) before `/spec`.

---

## Phase 8: Capture Learnings

**This skill is not complete until the learnings-capture process has run.** Read and follow `learnings/learnings-capture.md` (relative to the skills directory) now. Reflect on whether this session surfaced anything worth capturing under `## /msf-req` in `~/.pmos/learnings.md` — surprising persona-conditional findings, repeated friction patterns, non-obvious assumptions. Proposing zero learnings is a valid outcome.

---

## Anti-Patterns (DO NOT)

- Do NOT skip the persona-alignment confirmation step — analyzing without confirmed personas produces generic findings.
- Do NOT modify the requirements doc, ever. /msf-req is recommendations-only.
- Do NOT accept the flags `--apply-edits`, `--wireframes`, `--skip-psych`, or `--default-scope`. The argument-hint advertises only `<path-to-requirements-doc>`.
- Do NOT run PSYCH scoring — there is no UI to score. PSYCH lives in `/msf-wf`.
- Do NOT silently skip the wrong-input guard — a directory argument means the user wanted `/msf-wf`.
- Do NOT pad recommendations to fill the Must / Should / Nice template — emit "no actionable findings" instead.
- Do NOT present recommendations as a wall of text — use tables with severity and effort.
