# Spec: /update-skills

Tier: 3
Generated: 2026-05-08
Status: implemented

## 1. One-line description

Ingest feedback (raw text or `/retro` paste-back), summarize and critique proposed changes per affected pmos-toolkit skill, get user approval on the keep/drop set, then run the requirements -> spec -> plan -> execute -> verify pipeline (auto-tiered per skill) sequentially. Use when the user says "update these skills based on feedback", "process this retro output", "fix the issues from /retro", "run the pipeline on this skill feedback", or pastes retro/feedback text and wants the updates implemented end-to-end.

## 2. Argument hint

`<feedback text or path to feedback file or triage-doc path> [--from-retro] [--skill <name>]`

- Bare invocation with no arg → prompt user to paste feedback (interactive fallback).
- Path detection: if arg resolves to a readable file → file input. If file is a /update-skills triage doc (header marker present) → resume mode (see Phase 1).
- Otherwise treat as inline text.
- `--from-retro`: pull most-recent `/retro` output from this session's transcript; if multiple, default to most-recent and log which was used in triage-doc header.
- `--skill <name>`: filter parsed feedback to one skill only.

## 3. Source / inputs

- **Raw free-form text**: any prose feedback. Parser extracts skill names by scanning for `/<skill-name>` references and `pmos-toolkit:<skill-name>` mentions; if none found, asks user via AskUserQuestion which skill(s) the feedback applies to.
- **`/retro` paste-back**: structured markdown (`### Retro: /<skill-name>` blocks with `**Findings:**` lists tagged `[blocker]` / `[friction]` / `[nit]`). Parsed deterministically via shared regex in `reference/retro-parser.md`.
- **File path**: same content, read from disk.
- **Triage doc resume**: re-invoking with a path that has the triage-doc header marker → load existing dispositions and pipeline-status table; resume at next `pending` row.
- **No input**: AskUserQuestion prompt for paste; if user declines, exit no-op.
- **Skill source context**: for each affected skill detected, read `plugins/pmos-toolkit/skills/<name>/SKILL.md` and **only** the `reference/*.md` files cited by name in the feedback. If no reference cited, SKILL.md alone.
- **Scope**: pmos-toolkit skills only. Out-of-scope skill mentions are logged in triage doc and a one-time warning is shown to the user before Phase 6 triage starts.

## 4. Output

- **Triage doc** (always written when ≥1 finding parsed): path resolved via the shared `_shared/pipeline-setup.md` resolver — `{docs_path}/features/{YYYY-MM-DD}_update-skills-<slug>/00_triage.md` where `{docs_path}` comes from `.pmos/settings.yaml`. Missing settings file triggers first-run setup per pipeline-setup Section A. Contains: parsed findings table; per-finding critique (already-handled detection, classification: bug/UX-friction/new-capability/nit, keep-drop recommendation with one-line rationale); user disposition log (Apply/Modify/Skip-with-reason/Defer); approved-changes set grouped by skill; per-skill tier assignment; pipeline-status table per skill (phase | status | artifact path | timestamp); out-of-scope skill mentions; transcript-source note when `--from-retro` was used.
- **Per-skill pipeline artifacts**: produced by invoked pipeline skills (`/requirements`, `/spec`, `/plan`, `/execute`, `/verify`), each landing in their own feature folders per pipeline-setup conventions.
- **In-conversation**: triage summary, AskUserQuestion batches for keep/drop, per-skill tier confirmation, pipeline progress markers, failure-recovery prompts.
- **Side effects**: dropped findings logged in triage doc with reason. No /backlog enqueue, no workstream enrichment.
- **Empty input**: if 0 findings parsed, print `No actionable findings detected in <input>. Exiting.` and exit before writing the triage doc.
- **Happy path output**: "Processed N findings across M skills → K approved → pipeline complete. Triage doc: <path>. Per-skill changes: <list>."

## 5. Phases

| #  | Phase                          | Purpose                                                                                       | Gate                          |
|----|--------------------------------|-----------------------------------------------------------------------------------------------|-------------------------------|
| 0  | Pipeline setup + Load Learnings | Inline `_shared/pipeline-setup.md`; resolve `{docs_path}` and create feature folder; read `~/.pmos/learnings.md` `## /update-skills` entries | none                          |
| 1  | Resolve input                  | Parse arg; detect raw-text / file / triage-resume / `--from-retro`; if no arg, prompt for paste | none                          |
| 2  | Parse findings                 | Extract `(skill, severity, finding, evidence, proposed-fix)` tuples; deterministic for /retro via shared parser, LLM-extraction for raw text | exit if 0 findings            |
| 3  | Read affected skill sources    | Load SKILL.md + cited reference files for each affected skill; flag out-of-scope and warn user once | warn-once if any out-of-scope  |
| 4  | Critique each finding          | Per finding: already-handled? classify (bug/UX-friction/new-capability/nit), recommend Apply/Modify/Skip/Defer with one-line rationale | none                          |
| 5  | Write triage doc (draft)       | Persist parsed findings + critique to triage path                                             | none                          |
| 6  | Triage approval (Findings Protocol) | Present findings via AskUserQuestion (≤4 per call, batched), capture dispositions; "Modify" triggers a sequential follow-up call to capture the modified text; Skip/Defer logged with reason | user approval per finding     |
| 7  | Group + auto-tier per skill    | Group approved changes by skill (cross-cutting findings fan into per-skill changes); auto-tier each group via /create-skill rules; surface tier per skill via AskUserQuestion | user approval per skill       |
| 8  | Pipeline dispatch (sequential per skill) | For each skill group: invoke /requirements with seed brief, then /spec, then /grill (Tier 3 only), then /plan, then /execute, then /verify. After each phase, Edit the pipeline-status table row. On any failure, halt and AskUserQuestion: continue-to-next / retry / abort-all. If /grill changes the approved-finding set (any add or drop), return to Phase 6 for re-approval before /plan. | external skill invocations + failure gate |
| 9  | Final summary                  | Print processed/approved/completed counts and triage doc path                                 | none                          |
| 10 | Capture Learnings              | Reflect on session and capture entries under `## /update-skills`                              | terminal                      |

## 6. Tier classification rationale

Tier 3. Auto-tier signals: 11 phases (>5), multi-source input, full-pipeline orchestration, cross-skill dependencies, structured findings/critique loop with per-item Findings Presentation Protocol, eval/critique semantics in Phase 4. User confirmed Tier 3 explicitly.

## 7. Asset inventory

| File | Purpose | Format | Invoked by |
|------|---------|--------|------------|
| (none) | — | — | — |

## 8. Reference inventory

| File | Purpose | Loaded by phase |
|------|---------|-----------------|
| `reference/triage-doc-template.md` | Markdown skeleton: header marker, findings table, critique table, disposition log, approved-changes-by-skill, per-skill tier, pipeline-status table, out-of-scope log | Phase 5; updated through Phases 6–8 |
| `reference/retro-parser.md` | Shared regex/parser snippet for extracting findings from `/retro` paste-back blocks; same extractor used by Phase 2 and any future audit step | Phase 2 |
| `reference/seed-requirements-template.md` | Template for the per-skill seed brief handed to `/requirements`: verbatim findings, current-skill excerpts, proposed direction | Phase 8 |

## 9. Pipeline / workstream integration

- **Pipeline position**: standalone orchestrator that drives the existing pipeline. Diagram:

```
/retro  ->  /update-skills (this skill)  ->  /requirements -> /spec -> [/grill] -> /plan -> /execute -> /verify
                                              (per affected skill, sequential)
```

- **Workstream awareness**: NO. Phase 0 inlines pipeline-setup for `{docs_path}` resolution but does not load or enrich workstream context. No Workstream Enrichment phase.
- **Cross-skill dependencies**: invokes `/requirements`, `/spec`, `/grill` (Tier 3 only), `/plan`, `/execute`, `/verify`. Optionally consumes `/retro` output. Reads SKILL.md + cited reference of arbitrary pmos-toolkit skills; does not modify them directly (modification happens through pipeline `/execute`).

## 10. Findings Presentation Protocol applicability

**Phase 6 (triage approval):**

- One question per parsed finding.
- `question`: severity tag + skill + one-sentence finding + recommended disposition.
- `options`: **Apply as recommended** / **Modify** / **Skip (drop with reason)** / **Defer to backlog**.
- Batch ≤4 per AskUserQuestion call; multiple sequential calls when more findings.
- "Modify" → second sequential AskUserQuestion call captures the modified finding text as a free-form follow-up.
- Findings cap: no hard cap; if >20 findings parsed, prompt user once whether to filter to blockers/friction only.

**Phase 7 (per-skill tier):**

- One question per affected skill.
- `question`: skill + summary of approved changes + recommended tier with rationale.
- `options`: **Recommended tier (Tier N)** / **Tier above** / **Tier below** / **Skip this skill**.

**Phase 8 (failure recovery):**

- On any pipeline-phase failure: AskUserQuestion with **Continue to next skill** / **Retry this phase** / **Abort all remaining**.
- On /grill changing approved-finding scope: re-run Phase 6 for the changed subset only.

**Platform fallback** (no AskUserQuestion): emit a numbered findings table with disposition column; user replies inline (`1=Apply, 2=Skip(reason), ...`). Same shape for tier and failure decisions. Never silently self-fix.

## 11. Platform fallbacks

- **AskUserQuestion → numbered table**: triage, tier, and failure dialogues degrade to inline tables with a disposition column. State assumption + log in triage doc when proceeding.
- **Subagents → sequential single-agent**: Phase 8 invokes pipeline skills inline, one at a time per skill group. No parallel fan-out (matches user choice).
- **Playwright / MCP → not used**.
- **TaskCreate / TodoWrite → platform-neutral phrasing**: SKILL.md says "use your agent's task-tracking tool".
- **Transcript access for `--from-retro`**: if jsonl unavailable, prompt user to paste the /retro output; document limitation in triage-doc header.
- **`.pmos/settings.yaml` missing**: `_shared/pipeline-setup.md` Section A first-run setup creates it. /update-skills must not silently default a path.

## 12. Anti-patterns

1. **Treating raw feedback as already-structured.** Skipping parse + critique and dumping every sentence into /requirements as a finding produces noise the user has to triage downstream.
2. **Self-approving the keep/drop set.** Phase 6 must use AskUserQuestion (or table fallback). Auto-applying every "[blocker]" without user sign-off violates the contract.
3. **Skipping the "already handled" check.** Proposing a change that's literally in the current SKILL.md wastes a pipeline run. Phase 4 must read skill source for every affected skill.
4. **Cross-skill spec contamination.** Bundling /spec changes and /plan changes into one /requirements doc because they "feel related". Group strictly by skill (Phase 7); only the user can opt to merge.
5. **Running the pipeline on Skip/Defer items.** Once dropped in Phase 6, a finding never reaches Phase 8. The triage doc's approved-changes section is the single source of truth handed to /requirements.
6. **Vague seed briefs to /requirements.** The seed must include verbatim findings, current-skill excerpts, and a proposed direction — not "see the triage doc". Phase 8 hands a self-contained brief per skill.
7. **Inferring severity from tone.** A user calling something "annoying" is not automatically [blocker]. Severity comes from the parsed input or is explicitly asked, not guessed.
8. **Continuing the pipeline after /grill rewrites the approved-finding set.** Any added or dropped finding triggers re-approval at Phase 6 for the changed subset before /plan.
9. **Skipping /verify because /execute looked clean.** /verify is part of the pipeline contract per skill; no opt-out.
10. **Hard-coding the triage-doc path.** Always resolve via `_shared/pipeline-setup.md`. Bypassing the resolver breaks repos with custom `docs_path` and fresh repos that need first-run setup.
11. **Reading every reference/ file for every affected skill.** Read SKILL.md plus only reference files cited by name in the feedback. Bulk-reading large reference sets (e.g., /spec, /artifact) blows context.

## 13. Release prerequisites

- README row under **Pipeline enhancers** (orchestrator that drives pipeline runs; not itself a pipeline stage). Paraphrase SKILL.md description with trigger phrases. Add to "standalone — invoke them at any point" line under the pipeline-flow diagram.
- Version bump: **minor** (`X.Y+1.0`) in BOTH `plugins/pmos-toolkit/.claude-plugin/plugin.json` and `plugins/pmos-toolkit/.codex-plugin/plugin.json`. Performed during /push.
- One-time bootstrap: none.
- Reference paths to verify resolve from save location: `learnings/learnings-capture.md`, `_shared/pipeline-setup.md` (siblings under `plugins/pmos-toolkit/skills/`).

## 14. Open questions

(All resolved during /grill — recorded as dispositions above.)

| # | Question | Disposition |
|---|----------|-------------|
| 1 | `--from-retro` disambiguation when multiple retros in session | Default to most-recent; log which was used in triage-doc header |
| 2 | Triage doc resolution precedence | Use shared `_shared/pipeline-setup.md` resolver; missing settings → first-run setup |
| 3 | Modify disposition payload capture | Sequential second AskUserQuestion call as free-form follow-up |
| 4 | Re-grill threshold after /grill rewrites spec | Any added or dropped approved finding |
| 5 | Cross-cutting finding affecting N skills | Fan into N per-skill changes during Phase 7 |
| 6 | Sequential pipeline failure recovery | Halt and AskUserQuestion: continue / retry / abort |
| 7 | Reading reference/ for large-reference skills | SKILL.md + only reference files cited by name in feedback |
| 8 | Pipeline-status section schema | Table per skill: phase \| status \| artifact path \| timestamp |
| 9 | Out-of-scope (non-pmos) skill mentions | Log in triage doc + one-time warning before Phase 6 |
| 10 | Resume-from-triage-doc support | Yes — re-invoking with triage-doc path resumes from pipeline-status table |
